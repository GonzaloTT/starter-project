import '../../domain/entities/publishable_article.dart';
import '../../domain/params/publish_article_params.dart';
import '../../domain/repository/publish_article_repository.dart';
import '../data_sources/article_firestore_data_source.dart';
import '../data_sources/article_storage_data_source.dart';
import '../data_sources/publication_data_source_exception.dart';
import '../models/publishable_article_model.dart';

class PublishArticleRepositoryImpl implements PublishArticleRepository {
  final ArticleFirestoreDataSource _firestore;
  final ArticleStorageDataSource _storage;
  // Only unresolved attempts are retained, for the lifetime of this repository.
  final _pending = <_PublicationAttempt>[];

  PublishArticleRepositoryImpl(this._firestore, this._storage);

  @override
  Future<PublishableArticle> publishArticle(PublishArticleParams params) async {
    final attempt = _pending.firstWhere(
      (attempt) => attempt.matches(params),
      orElse: () {
        const names = {
          'image/jpeg': 'thumbnail.jpg',
          'image/png': 'thumbnail.png',
          'image/webp': 'thumbnail.webp',
        };
        final name = names[params.thumbnail.mimeType];
        if (name == null) {
          throw ArgumentError(
              'Publication parameters must be validated first.');
        }
        final id = _firestore.createArticleId();
        final attempt =
            _PublicationAttempt(params, id, 'media/articles/$id/$name');
        _pending.add(attempt);
        return attempt;
      },
    );
    // Multiple callers with equal input share the same in-flight operation.
    if (attempt.inFlight != null) return attempt.inFlight!;
    final operation = _publish(attempt);
    attempt.inFlight = operation;
    try {
      final entity = await operation;
      _pending.remove(attempt);
      return entity;
    } finally {
      attempt.inFlight = null;
    }
  }

  Future<PublishableArticle> _publish(_PublicationAttempt attempt) async {
    if (attempt.writeAttempted) {
      final existing = await _findArticle(attempt);
      if (existing != null) return existing.toEntity();
      if (attempt.writeAcknowledged) {
        // Never repeat an acknowledged write just because confirmation failed.
        throw const PublicationDataSourceException(
          source: PublicationDataSource.firestore,
          operation: PublicationDataSourceOperation.getArticle,
          code: 'not-found',
          message: 'The acknowledged publication could not be confirmed.',
        );
      }
    }

    await _ensureThumbnail(attempt);
    attempt.writeAttempted = true;
    try {
      await _firestore.createArticle(
        articleId: attempt.id,
        params: attempt.params,
        thumbnailUrl: attempt.thumbnailUrl!,
      );
      attempt.writeAcknowledged = true;
    } catch (_) {
      // A rejected/uncertain write may refer to an earlier successful request.
      try {
        final existing = await _findArticle(attempt);
        if (existing != null) return existing.toEntity();
      } catch (_) {
        // Keep the original write error and retain the attempt for a later retry.
      }
      rethrow;
    }

    try {
      return (await _readConfirmed(attempt)).toEntity();
    } catch (_) {
      // One bounded reconciliation read, never another upload or write.
      return (await _readConfirmed(attempt)).toEntity();
    }
  }

  Future<void> _ensureThumbnail(_PublicationAttempt attempt) async {
    if (attempt.thumbnailUrl != null) return;
    if (attempt.uploadAttempted) {
      attempt.thumbnailUrl =
          await _storage.findThumbnailDownloadUrl(attempt.path);
      if (attempt.thumbnailUrl != null) return;
    }
    attempt.uploadAttempted = true;
    try {
      attempt.thumbnailUrl = await _storage.uploadThumbnail(
          storagePath: attempt.path, thumbnail: attempt.params.thumbnail);
    } on PublicationDataSourceException catch (error) {
      const definitiveUploadErrors = {
        'unauthorized',
        'unauthenticated',
        'bucket-not-found',
        'project-not-found',
        'quota-exceeded',
        'invalid-argument',
      };
      if (error.operation == PublicationDataSourceOperation.uploadThumbnail &&
          definitiveUploadErrors.contains(error.code)) {
        rethrow;
      }
      // Includes failures obtaining the URL after a successful upload.
      attempt.thumbnailUrl =
          await _storage.findThumbnailDownloadUrl(attempt.path);
      if (attempt.thumbnailUrl == null) rethrow;
    }
  }

  Future<PublishableArticleModel?> _findArticle(
      _PublicationAttempt attempt) async {
    try {
      return await _readConfirmed(attempt);
    } on PublicationDataSourceException catch (error) {
      if (error.source == PublicationDataSource.firestore &&
          error.operation == PublicationDataSourceOperation.getArticle &&
          error.code == 'not-found') {
        return null;
      }
      rethrow;
    }
  }

  Future<PublishableArticleModel> _readConfirmed(
      _PublicationAttempt attempt) async {
    final model = await _firestore.getArticleById(attempt.id);
    final params = attempt.params;
    if (model.id != attempt.id ||
        model.author != params.author ||
        model.title != params.title ||
        model.description != params.description ||
        model.content != params.content ||
        model.thumbnailUrl != attempt.thumbnailUrl) {
      throw const PublicationDataSourceException(
        source: PublicationDataSource.firestore,
        operation: PublicationDataSourceOperation.getArticle,
        code: 'publication-conflict',
        message: 'The stored document does not match this publication attempt.',
      );
    }
    return model;
  }
}

class _PublicationAttempt {
  final PublishArticleParams params;
  final String id;
  final String path;
  String? thumbnailUrl;
  bool uploadAttempted = false;
  bool writeAttempted = false;
  bool writeAcknowledged = false;
  Future<PublishableArticle>? inFlight;

  _PublicationAttempt(this.params, this.id, this.path);

  bool matches(PublishArticleParams other) {
    if (params.author != other.author ||
        params.title != other.title ||
        params.description != other.description ||
        params.content != other.content ||
        params.thumbnail.fileName != other.thumbnail.fileName ||
        params.thumbnail.mimeType != other.thumbnail.mimeType ||
        params.thumbnail.bytes.length != other.thumbnail.bytes.length) {
      return false;
    }
    for (var i = 0; i < params.thumbnail.bytes.length; i++) {
      if (params.thumbnail.bytes[i] != other.thumbnail.bytes[i]) return false;
    }
    return true;
  }
}
