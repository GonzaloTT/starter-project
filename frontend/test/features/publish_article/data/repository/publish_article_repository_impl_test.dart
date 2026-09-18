import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:news_app_clean_architecture/features/publish_article/data/data_sources/publication_data_source_exception.dart';
import 'package:news_app_clean_architecture/features/publish_article/data/models/publishable_article_model.dart';
import 'package:news_app_clean_architecture/features/publish_article/data/repository/publish_article_repository_impl.dart';
import 'package:news_app_clean_architecture/features/publish_article/domain/entities/publishable_article.dart';

import '../../support/publication_data_source_fakes.dart';

void main() {
  late List<String> events;
  late PublicationFirestoreFake firestore;
  late PublicationStorageFake storage;
  late PublishArticleRepositoryImpl repository;
  const path = 'media/articles/article-1/thumbnail.jpg';
  final writeError = dataError(PublicationDataSource.firestore,
      PublicationDataSourceOperation.createArticle, 'unavailable');
  final readError = dataError(PublicationDataSource.firestore,
      PublicationDataSourceOperation.getArticle, 'unavailable');
  final uploadError = dataError(PublicationDataSource.storage,
      PublicationDataSourceOperation.uploadThumbnail, 'retry-limit-exceeded');

  setUp(() {
    events = [];
    firestore = PublicationFirestoreFake(events);
    storage = PublicationStorageFake(events);
    repository = PublishArticleRepositoryImpl(firestore, storage);
  });

  for (final entry in {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp'
  }.entries) {
    test('publishes ${entry.key} with safe path, same ID and exact order',
        () async {
      final input = publicationInput(mime: entry.key);
      final entity = await repository.publishArticle(input);
      expect(events, [
        'id',
        'upload:media/articles/article-1/thumbnail.${entry.value}',
        'create:article-1',
        'get:article-1'
      ]);
      expect(entity.runtimeType, PublishableArticle);
      expect(entity, isNot(isA<PublishableArticleModel>()));
      expect(entity.id, 'article-1');
      expect(entity.author, input.author);
      expect(entity.title, input.title);
      expect(entity.description, input.description);
      expect(entity.content, input.content);
      expect(entity.thumbnailUrl, storage.objects.values.single);
      expect(entity.publishedAt, DateTime.utc(2020));
      expect(entity.createdAt, DateTime.utc(2021));
      expect(entity.updatedAt, DateTime.utc(2022));
      expect(firestore.receivedParams, same(input));
      expect(storage.receivedThumbnail, same(input.thumbnail));
    });
  }

  test('recovers an uncertain upload from the same path', () async {
    storage
      ..uploadError = uploadError
      ..storeBeforeError = true;
    final entity = await repository.publishArticle(publicationInput());
    expect(entity.id, 'article-1');
    expect(events, [
      'id',
      'upload:$path',
      'find:$path',
      'create:article-1',
      'get:article-1'
    ]);
  });
  test('recovers URL retrieval failure after upload', () async {
    storage
      ..uploadError = dataError(PublicationDataSource.storage,
          PublicationDataSourceOperation.getThumbnailDownloadUrl, 'unknown')
      ..storeBeforeError = true;
    await repository.publishArticle(publicationInput());
    expect(events.where((e) => e.startsWith('upload:')), hasLength(1));
    expect(events, contains('find:$path'));
  });
  test('missing image after uncertain upload propagates original error',
      () async {
    storage.uploadError = uploadError;
    await expectLater(repository.publishArticle(publicationInput()),
        throwsA(same(uploadError)));
    expect(events, ['id', 'upload:$path', 'find:$path']);
  });
  test(
      'retry with new equal params reuses ID and finds an already uploaded image',
      () async {
    storage
      ..uploadError = uploadError
      ..storeBeforeError = true
      ..lookupError = readError;
    await expectLater(repository.publishArticle(publicationInput()),
        throwsA(same(readError)));
    storage
      ..uploadError = null
      ..lookupError = null;
    final entity = await repository.publishArticle(publicationInput());
    expect(entity.id, 'article-1');
    expect(firestore.ids, 1);
    expect(events.where((e) => e.startsWith('upload:')), hasLength(1));
  });
  test('retry reuploads a confirmed absent image at the same path', () async {
    storage.uploadError = uploadError;
    await expectLater(repository.publishArticle(publicationInput()),
        throwsA(same(uploadError)));
    storage.uploadError = null;
    await repository.publishArticle(publicationInput());
    expect(firestore.ids, 1);
    expect(events.where((e) => e.startsWith('upload:')),
        ['upload:$path', 'upload:$path']);
  });
  test('reconciles a write which succeeded but returned an error', () async {
    firestore
      ..createError = writeError
      ..storeBeforeError = true;
    final entity = await repository.publishArticle(publicationInput());
    expect(entity.id, 'article-1');
    expect(events, ['id', 'upload:$path', 'create:article-1', 'get:article-1']);
  });
  test('write failure then retry reuses image and ID after confirming absence',
      () async {
    firestore.createError = writeError;
    await expectLater(repository.publishArticle(publicationInput()),
        throwsA(same(writeError)));
    firestore.createError = null;
    await repository.publishArticle(publicationInput());
    expect(events, [
      'id',
      'upload:$path',
      'create:article-1',
      'get:article-1',
      'get:article-1',
      'create:article-1',
      'get:article-1'
    ]);
  });
  test('unresolved write followed by confirmed document never writes twice',
      () async {
    firestore
      ..createError = writeError
      ..storeBeforeError = true;
    firestore.reads.add(readError);
    await expectLater(repository.publishArticle(publicationInput()),
        throwsA(same(writeError)));
    final entity = await repository.publishArticle(publicationInput());
    expect(entity.id, 'article-1');
    expect(firestore.ids, 1);
    expect(events.where((e) => e.startsWith('create:')), hasLength(1));
  });
  test('a failed confirmation is reconciled by one bounded read', () async {
    firestore.reads.add(readError);
    await repository.publishArticle(publicationInput());
    expect(events, [
      'id',
      'upload:$path',
      'create:article-1',
      'get:article-1',
      'get:article-1'
    ]);
  });
  test('failed confirmation keeps attempt for later read-only retry', () async {
    firestore.reads.addAll([readError, readError]);
    await expectLater(repository.publishArticle(publicationInput()),
        throwsA(same(readError)));
    final entity = await repository.publishArticle(publicationInput());
    expect(entity.id, 'article-1');
    expect(events.where((e) => e.startsWith('upload:')), hasLength(1));
    expect(events.where((e) => e.startsWith('create:')), hasLength(1));
    expect(firestore.ids, 1);
  });
  test('acknowledged write is not repeated even when retry reads not-found',
      () async {
    firestore.reads.addAll([readError, readError]);
    await expectLater(repository.publishArticle(publicationInput()),
        throwsA(same(readError)));
    firestore.documents.clear();
    await expectLater(
        repository.publishArticle(publicationInput()),
        throwsA(isA<PublicationDataSourceException>()
            .having((e) => e.code, 'code', 'not-found')));
    expect(events.where((e) => e.startsWith('create:')), hasLength(1));
    expect(firestore.ids, 1);
  });
  test('unavailable reconciliation on retry never creates another article',
      () async {
    firestore.createError = writeError;
    await expectLater(repository.publishArticle(publicationInput()),
        throwsA(same(writeError)));
    firestore.reads.add(readError);
    await expectLater(repository.publishArticle(publicationInput()),
        throwsA(same(readError)));
    expect(firestore.ids, 1);
    expect(events.where((e) => e.startsWith('create:')), hasLength(1));
  });
  test('definitive upload errors propagate without creating Firestore data',
      () async {
    final error = dataError(PublicationDataSource.storage,
        PublicationDataSourceOperation.uploadThumbnail, 'unauthorized');
    storage.uploadError = error;
    await expectLater(
        repository.publishArticle(publicationInput()), throwsA(same(error)));
    expect(events, ['id', 'upload:$path']);
  });
  test('definitive create errors propagate after checking the same document',
      () async {
    final error = dataError(PublicationDataSource.firestore,
        PublicationDataSourceOperation.createArticle, 'permission-denied');
    firestore.createError = error;
    await expectLater(
        repository.publishArticle(publicationInput()), throwsA(same(error)));
    expect(events.last, 'get:article-1');
    expect(firestore.ids, 1);
  });
  test('ID allocation failure propagates before uploading', () async {
    firestore.idError = writeError;
    await expectLater(repository.publishArticle(publicationInput()),
        throwsA(same(writeError)));
    expect(events, ['id']);
  });
  test('same input in parallel shares one publication', () async {
    storage.gate = Completer<void>();
    final first = repository.publishArticle(publicationInput());
    final second = repository.publishArticle(publicationInput());
    storage.gate!.complete();
    final entities = await Future.wait([first, second]);
    expect(entities[0].id, entities[1].id);
    expect(events, ['id', 'upload:$path', 'create:article-1', 'get:article-1']);
  });
  test(
      'changed input has its own ID and does not discard an older pending attempt',
      () async {
    firestore.createError = writeError;
    await expectLater(repository.publishArticle(publicationInput()),
        throwsA(same(writeError)));
    firestore.createError = null;
    expect(
        (await repository.publishArticle(publicationInput(bytes: [9, 8, 7])))
            .id,
        'article-2');
    expect(
        (await repository.publishArticle(publicationInput())).id, 'article-1');
    expect(firestore.ids, 2);
  });
  test(
      'confirmed attempts are released so a later deliberate publication gets a new ID',
      () async {
    expect(
        (await repository.publishArticle(publicationInput())).id, 'article-1');
    expect(
        (await repository.publishArticle(publicationInput())).id, 'article-2');
  });
  test('conflicting document is never accepted as a successful publication',
      () async {
    firestore.reads.addAll(List.generate(
        2,
        (_) => PublishableArticleModel(
            id: 'article-1',
            author: 'Someone else',
            title: 'Other title',
            description: 'Other',
            content: 'Other',
            thumbnailUrl: 'other',
            publishedAt: DateTime.utc(2020),
            createdAt: DateTime.utc(2020),
            updatedAt: DateTime.utc(2020))));
    await expectLater(
        repository.publishArticle(publicationInput()),
        throwsA(isA<PublicationDataSourceException>()
            .having((e) => e.code, 'code', 'publication-conflict')));
    expect(firestore.ids, 1);
  });
}
