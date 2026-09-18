import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:news_app_clean_architecture/features/daily_news/data/data_sources/remote/news_api_service.dart';
import 'package:news_app_clean_architecture/features/daily_news/data/repository/article_repository_impl.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/repository/article_repository.dart';
import 'package:news_app_clean_architecture/features/daily_news/domain/usecases/get_article.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_bloc.dart';
import 'features/daily_news/data/data_sources/local/app_database.dart';
import 'features/daily_news/domain/usecases/get_saved_article.dart';
import 'features/daily_news/domain/usecases/remove_article.dart';
import 'features/daily_news/domain/usecases/save_article.dart';
import 'features/daily_news/presentation/bloc/article/local/local_article_bloc.dart';
import 'features/publish_article/domain/use_cases/publish_article_use_case.dart';
import 'features/publish_article/domain/repository/publish_article_repository.dart';
import 'features/publish_article/data/repository/mock_publish_article_repository.dart';
import 'features/publish_article/presentation/cubit/publish_article_cubit.dart';
import 'features/publish_article/presentation/services/article_image_picker.dart';
import 'features/publish_article/presentation/services/gallery_article_image_picker.dart';

final sl = GetIt.instance;

Future<void> initializeDependencies() async {
  final database =
      await $FloorAppDatabase.databaseBuilder('app_database.db').build();
  sl.registerSingleton<AppDatabase>(database);

  // Dio
  sl.registerSingleton<Dio>(Dio());

  // Dependencies
  sl.registerSingleton<NewsApiService>(NewsApiService(sl()));

  sl.registerSingleton<ArticleRepository>(ArticleRepositoryImpl(sl(), sl()));

  //UseCases
  sl.registerSingleton<GetArticleUseCase>(GetArticleUseCase(sl()));

  sl.registerSingleton<GetSavedArticleUseCase>(GetSavedArticleUseCase(sl()));

  sl.registerSingleton<SaveArticleUseCase>(SaveArticleUseCase(sl()));

  sl.registerSingleton<RemoveArticleUseCase>(RemoveArticleUseCase(sl()));

  sl.registerSingleton<PublishArticleRepository>(MockPublishArticleRepository());
  sl.registerSingleton<PublishArticleUseCase>(PublishArticleUseCase(sl()));

  sl.registerLazySingleton<ArticleImagePicker>(
    () => GalleryArticleImagePicker(),
  );

  //Blocs
  sl.registerFactory<RemoteArticlesBloc>(() => RemoteArticlesBloc(sl()));

  sl.registerFactory<LocalArticleBloc>(
      () => LocalArticleBloc(sl(), sl(), sl()));

  sl.registerFactory<PublishArticleCubit>(
    () => PublishArticleCubit(sl()),
  );
}
