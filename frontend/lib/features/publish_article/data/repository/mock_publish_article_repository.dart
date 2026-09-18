import '../../domain/entities/publishable_article.dart';
import '../../domain/params/publish_article_params.dart';
import '../../domain/repository/publish_article_repository.dart';

/// Transitional publisher until the Firebase repository is connected.
/// Does not persist articles.
class MockPublishArticleRepository implements PublishArticleRepository {
  @override
  Future<PublishableArticle> publishArticle(PublishArticleParams params) async {
    final now = DateTime.now();
    final id = 'mock-${now.microsecondsSinceEpoch}';
    final objectPath = Uri.encodeComponent(
      'media/articles/$id/${params.thumbnail.fileName}',
    );
    return PublishableArticle(
      id: id,
      author: params.author,
      title: params.title,
      description: params.description,
      content: params.content,
      thumbnailUrl: 'https://firebasestorage.googleapis.com/v0/b/'
          'mock-publish-article.invalid/o/$objectPath?alt=media&token=mock',
      publishedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }
}
