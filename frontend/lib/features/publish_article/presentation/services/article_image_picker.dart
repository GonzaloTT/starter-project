import '../../domain/entities/article_thumbnail.dart';

abstract class ArticleImagePicker {
  Future<ArticleThumbnail?> pickImage();
}
