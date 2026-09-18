import '../entities/publishable_article.dart';
import '../params/publish_article_params.dart';

abstract class PublishArticleRepository {
  Future<PublishableArticle> publishArticle(PublishArticleParams params);
}
