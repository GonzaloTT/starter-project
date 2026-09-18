import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:news_app_clean_architecture/features/publish_article/domain/entities/article_thumbnail.dart';
import 'package:news_app_clean_architecture/features/publish_article/domain/entities/publishable_article.dart';
import 'package:news_app_clean_architecture/features/publish_article/domain/params/publish_article_params.dart';
import 'package:news_app_clean_architecture/features/publish_article/domain/use_cases/publish_article_result.dart';
import 'package:news_app_clean_architecture/features/publish_article/domain/use_cases/publish_article_use_case.dart';
import 'package:news_app_clean_architecture/features/publish_article/presentation/cubit/publish_article_cubit.dart';
import 'package:news_app_clean_architecture/features/publish_article/presentation/cubit/publish_article_state.dart';

class ControlledPublishArticleUseCase extends PublishArticleUseCase {
  final Future<PublishArticleResult> Function(PublishArticleParams params)
      handler;

  ControlledPublishArticleUseCase(this.handler);

  @override
  Future<PublishArticleResult> call({PublishArticleParams? params}) {
    if (params == null) {
      throw ArgumentError.notNull('params');
    }

    return handler(params);
  }
}

ArticleThumbnail validThumbnail() {
  return ArticleThumbnail(
    fileName: 'thumbnail.jpg',
    mimeType: 'image/jpeg',
    bytes: const [1, 2, 3],
  );
}

PublishableArticle publishedArticle() {
  final instant = DateTime.utc(2026, 9, 18, 12);

  return PublishableArticle(
    id: 'article-123',
    author: 'Jane Doe',
    title: 'Article title',
    description: 'Article summary',
    content: 'Article content',
    thumbnailUrl: 'https://example.com/thumbnail.jpg',
    publishedAt: instant,
    createdAt: instant,
    updatedAt: instant,
  );
}

void completeValidForm(PublishArticleCubit cubit) {
  cubit.authorChanged('Jane Doe');
  cubit.titleChanged('Article title');
  cubit.descriptionChanged('Article summary');
  cubit.contentChanged('Article content');
  cubit.thumbnailSelected(validThumbnail());
}

void main() {
  group('PublishArticleCubit', () {
    test('starts with an empty initial state', () async {
      final cubit = PublishArticleCubit(PublishArticleUseCase());

      expect(cubit.state, PublishArticleState());

      await cubit.close();
    });

    test('updates each text field independently', () async {
      final cubit = PublishArticleCubit(PublishArticleUseCase());

      cubit.authorChanged('Jane Doe');
      expect(cubit.state.author, 'Jane Doe');
      expect(cubit.state.title, isEmpty);

      cubit.titleChanged('Article title');
      expect(cubit.state.title, 'Article title');

      cubit.descriptionChanged('Article summary');
      expect(cubit.state.description, 'Article summary');

      cubit.contentChanged('Article content');
      expect(cubit.state.content, 'Article content');

      await cubit.close();
    });

    test('selects and removes a thumbnail', () async {
      final cubit = PublishArticleCubit(PublishArticleUseCase());
      final thumbnail = validThumbnail();

      cubit.thumbnailSelected(thumbnail);
      expect(cubit.state.thumbnail, same(thumbnail));

      cubit.thumbnailRemoved();
      expect(cubit.state.thumbnail, isNull);

      await cubit.close();
    });

    test('emits submitting and success for valid input', () async {
      final article = publishedArticle();
      PublishArticleParams? receivedParams;
      final useCase = ControlledPublishArticleUseCase((params) async {
        receivedParams = params;
        return PublishArticleResult.success(article);
      });
      final cubit = PublishArticleCubit(useCase);

      completeValidForm(cubit);

      final expectation = expectLater(
        cubit.stream.map((state) => state.status),
        emitsInOrder([
          PublishArticleStatus.submitting,
          PublishArticleStatus.success,
        ]),
      );

      await cubit.publish();
      await expectation;

      expect(cubit.state.publishedArticle, same(article));
      expect(cubit.state.validationErrors, isEmpty);
      expect(cubit.state.failureMessage, isNull);
      expect(receivedParams, isNotNull);
      expect(receivedParams!.author, 'Jane Doe');
      expect(receivedParams!.title, 'Article title');
      expect(receivedParams!.description, 'Article summary');
      expect(receivedParams!.content, 'Article content');
      expect(receivedParams!.thumbnail.fileName, 'thumbnail.jpg');

      await cubit.close();
    });

    test('exposes every domain validation error for empty input', () async {
      final cubit = PublishArticleCubit(PublishArticleUseCase());

      final expectation = expectLater(
        cubit.stream.map((state) => state.status),
        emitsInOrder([
          PublishArticleStatus.submitting,
          PublishArticleStatus.validationFailure,
        ]),
      );

      await cubit.publish();
      await expectation;

      expect(
        cubit.state.validationErrors.map((error) => error.field),
        PublishArticleField.values,
      );
      expect(cubit.state.publishedArticle, isNull);
      expect(cubit.state.failureMessage, isNull);

      await cubit.close();
    });

    test('editing a field clears only its validation error', () async {
      final cubit = PublishArticleCubit(PublishArticleUseCase());

      await cubit.publish();
      expect(cubit.state.validationErrors, hasLength(7));

      cubit.authorChanged('Jane Doe');

      expect(cubit.state.status, PublishArticleStatus.initial);
      expect(
        cubit.state.errorFor(PublishArticleField.author),
        isNull,
      );
      expect(cubit.state.validationErrors, hasLength(6));
      expect(
        cubit.state.errorFor(PublishArticleField.title),
        'Required.',
      );

      await cubit.close();
    });

    test('selecting a thumbnail clears all thumbnail validation errors',
        () async {
      final cubit = PublishArticleCubit(PublishArticleUseCase());

      await cubit.publish();
      cubit.thumbnailSelected(validThumbnail());

      expect(cubit.state.thumbnailError, isNull);
      expect(
        cubit.state.validationErrors.map((error) => error.field),
        [
          PublishArticleField.author,
          PublishArticleField.title,
          PublishArticleField.description,
          PublishArticleField.content,
        ],
      );

      await cubit.close();
    });

    test('emits failure when the use case throws unexpectedly', () async {
      final useCase = ControlledPublishArticleUseCase(
        (_) => Future<PublishArticleResult>.error(
          StateError('Unexpected failure'),
        ),
      );
      final cubit = PublishArticleCubit(useCase);

      completeValidForm(cubit);

      final expectation = expectLater(
        cubit.stream.map((state) => state.status),
        emitsInOrder([
          PublishArticleStatus.submitting,
          PublishArticleStatus.failure,
        ]),
      );

      await cubit.publish();
      await expectation;

      expect(
        cubit.state.failureMessage,
        'Unable to publish the article. Please try again.',
      );
      expect(cubit.state.publishedArticle, isNull);

      await cubit.close();
    });

    test('ignores a second publish while a request is in progress', () async {
      final completer = Completer<PublishArticleResult>();
      var calls = 0;
      final useCase = ControlledPublishArticleUseCase((_) {
        calls++;
        return completer.future;
      });
      final cubit = PublishArticleCubit(useCase);

      completeValidForm(cubit);

      final firstPublish = cubit.publish();
      final secondPublish = cubit.publish();

      expect(calls, 1);
      expect(cubit.state.status, PublishArticleStatus.submitting);

      completer.complete(
        PublishArticleResult.success(publishedArticle()),
      );

      await Future.wait([firstPublish, secondPublish]);

      expect(calls, 1);
      expect(cubit.state.status, PublishArticleStatus.success);

      await cubit.close();
    });
  });
}
