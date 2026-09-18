import '../../../../core/usecase/usecase.dart';
import '../entities/publishable_article.dart';
import '../params/publish_article_params.dart';
import 'publish_article_result.dart';

class PublishArticleUseCase
    implements UseCase<PublishArticleResult, PublishArticleParams> {
  final DateTime Function() _clock;
  final String Function() _generateId;

  PublishArticleUseCase({
    DateTime Function()? clock,
    String Function()? generateId,
  })  : _clock = clock ?? DateTime.now,
        _generateId = generateId ??
            (() => 'mock-${DateTime.now().microsecondsSinceEpoch}');

  @override
  Future<PublishArticleResult> call({PublishArticleParams? params}) async {
    if (params == null) {
      throw ArgumentError.notNull('params');
    }

    final author = params.author.trim();
    final title = params.title.trim();
    final description = params.description.trim();
    final content = params.content.trim();
    final fileName = params.thumbnail.fileName.trim();
    final errors = <PublishArticleValidationError>[];

    _validateText(author, PublishArticleField.author, 100, errors);
    _validateText(title, PublishArticleField.title, 200, errors);
    _validateText(description, PublishArticleField.description, 500, errors);
    _validateText(content, PublishArticleField.content, 50000, errors);

    if (fileName.isEmpty) {
      errors.add(const PublishArticleValidationError(
        PublishArticleField.thumbnailFileName,
        'File name is required.',
      ));
    }
    if (!const ['image/jpeg', 'image/png', 'image/webp']
        .contains(params.thumbnail.mimeType)) {
      errors.add(const PublishArticleValidationError(
        PublishArticleField.thumbnailMimeType,
        'Use JPEG, PNG or WebP.',
      ));
    }
    if (params.thumbnail.bytes.isEmpty) {
      errors.add(const PublishArticleValidationError(
        PublishArticleField.thumbnailBytes,
        'Image bytes are required.',
      ));
    } else if (params.thumbnail.bytes.length > 5 * 1024 * 1024) {
      errors.add(const PublishArticleValidationError(
        PublishArticleField.thumbnailBytes,
        'Image must not exceed 5 MiB.',
      ));
    }

    if (errors.isNotEmpty) {
      return PublishArticleResult.validationFailure(errors);
    }

    final id = _generateId();
    final now = _clock();
    final objectPath = Uri.encodeComponent('media/articles/$id/$fileName');
    return PublishArticleResult.success(PublishableArticle(
      id: id,
      author: author,
      title: title,
      description: description,
      content: content,
      thumbnailUrl: 'https://firebasestorage.googleapis.com/v0/b/'
          'mock-publish-article.invalid/o/$objectPath?alt=media&token=mock',
      publishedAt: now,
      createdAt: now,
      updatedAt: now,
    ));
  }

  void _validateText(
    String value,
    PublishArticleField field,
    int maximum,
    List<PublishArticleValidationError> errors,
  ) {
    if (value.isEmpty) {
      errors.add(PublishArticleValidationError(field, 'Required.'));
    } else if (value.length > maximum) {
      errors.add(PublishArticleValidationError(
        field,
        'Must not exceed $maximum characters.',
      ));
    }
  }
}
