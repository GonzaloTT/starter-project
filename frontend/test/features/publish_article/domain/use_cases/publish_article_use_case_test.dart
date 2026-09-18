import 'package:flutter_test/flutter_test.dart';
import 'package:news_app_clean_architecture/features/publish_article/domain/entities/article_thumbnail.dart';
import 'package:news_app_clean_architecture/features/publish_article/domain/params/publish_article_params.dart';
import 'package:news_app_clean_architecture/features/publish_article/domain/use_cases/publish_article_result.dart';
import 'package:news_app_clean_architecture/features/publish_article/domain/use_cases/publish_article_use_case.dart';

PublishArticleParams input({
  Map<PublishArticleField, String> text = const {},
  String fileName = 'thumbnail.jpg',
  String mimeType = 'image/jpeg',
  List<int> bytes = const [1, 2, 3],
}) {
  return PublishArticleParams(
    author: text[PublishArticleField.author] ?? 'Jane Doe',
    title: text[PublishArticleField.title] ?? 'Article title',
    description: text[PublishArticleField.description] ?? 'Article summary',
    content: text[PublishArticleField.content] ?? 'Article content',
    thumbnail: ArticleThumbnail(
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    ),
  );
}

void expectFailure(
  PublishArticleResult result,
  PublishArticleField field,
  String message,
) {
  expect(result.article, isNull);
  expect(result.errors, hasLength(1));
  expect(result.errors.single.field, field);
  expect(result.errors.single.message, message);
}

void main() {
  late PublishArticleUseCase useCase;
  final instant = DateTime.utc(2026, 9, 17, 12);

  setUp(() {
    useCase = PublishArticleUseCase(
      clock: () => instant,
      generateId: () => 'article-123',
    );
  });

  test('valid input succeeds with normalized user data and injected values',
      () async {
    var clockCalls = 0;
    var idCalls = 0;
    final controlled = PublishArticleUseCase(
      clock: () {
        clockCalls++;
        return instant;
      },
      generateId: () {
        idCalls++;
        return 'article-123';
      },
    );
    final result = await controlled(
        params: input(
      text: {
        PublishArticleField.author: '  Jane Doe  ',
        PublishArticleField.title: '\tArticle title\n',
        PublishArticleField.description: ' Article summary ',
        PublishArticleField.content: '\nArticle content\n',
      },
      fileName: ' thumbnail image.jpg ',
    ));
    expect(result.errors, isEmpty);
    final article = result.article!;
    expect(article.author, 'Jane Doe');
    expect(article.title, 'Article title');
    expect(article.description, 'Article summary');
    expect(article.content, 'Article content');
    expect(article.id, 'article-123');
    expect(article.publishedAt, instant);
    expect(article.createdAt, instant);
    expect(article.updatedAt, instant);
    expect(clockCalls, 1);
    expect(idCalls, 1);
    final url = Uri.parse(article.thumbnailUrl);
    expect(url.scheme, 'https');
    expect(url.host, 'firebasestorage.googleapis.com');
    expect(url.pathSegments, [
      'v0',
      'b',
      'mock-publish-article.invalid',
      'o',
      'media/articles/article-123/thumbnail image.jpg',
    ]);
    expect(url.queryParameters, {'alt': 'media', 'token': 'mock'});
  });

  const limits = {
    PublishArticleField.author: 100,
    PublishArticleField.title: 200,
    PublishArticleField.description: 500,
    PublishArticleField.content: 50000,
  };
  for (final entry in limits.entries) {
    for (final value in ['', '   ']) {
      test('${entry.key} rejects ${value.isEmpty ? 'empty' : 'spaces'}',
          () async {
        final result = await useCase(params: input(text: {entry.key: value}));
        expectFailure(result, entry.key, 'Required.');
      });
    }
    test('${entry.key} accepts exactly its maximum after trim', () async {
      final value = List.filled(entry.value, 'a').join();
      final result =
          await useCase(params: input(text: {entry.key: ' $value '}));
      expect(result.article, isNotNull);
      expect(result.errors, isEmpty);
    });
    test('${entry.key} rejects maximum plus one', () async {
      final value = List.filled(entry.value + 1, 'a').join();
      final result = await useCase(params: input(text: {entry.key: value}));
      expectFailure(
          result, entry.key, 'Must not exceed ${entry.value} characters.');
    });
  }

  for (final mime in ['image/jpeg', 'image/png', 'image/webp']) {
    test('accepts $mime', () async {
      final result = await useCase(params: input(mimeType: mime));
      expect(result.article, isNotNull);
      expect(result.errors, isEmpty);
    });
  }
  for (final mime in ['image/gif', 'IMAGE/JPEG', ' image/png ', '']) {
    test('rejects unsupported or non-exact MIME "$mime"', () async {
      final result = await useCase(params: input(mimeType: mime));
      expectFailure(result, PublishArticleField.thumbnailMimeType,
          'Use JPEG, PNG or WebP.');
    });
  }
  for (final name in ['', '   ']) {
    test('rejects ${name.isEmpty ? 'empty' : 'blank'} file name', () async {
      final result = await useCase(params: input(fileName: name));
      expectFailure(result, PublishArticleField.thumbnailFileName,
          'File name is required.');
    });
  }
  test('rejects empty bytes', () async {
    final result = await useCase(params: input(bytes: []));
    expectFailure(result, PublishArticleField.thumbnailBytes,
        'Image bytes are required.');
  });
  test('accepts exactly 5 MiB', () async {
    final result =
        await useCase(params: input(bytes: List.filled(5 * 1024 * 1024, 0)));
    expect(result.article, isNotNull);
    expect(result.errors, isEmpty);
  });
  test('rejects 5 MiB plus one byte', () async {
    final result = await useCase(
        params: input(bytes: List.filled(5 * 1024 * 1024 + 1, 0)));
    expectFailure(result, PublishArticleField.thumbnailBytes,
        'Image must not exceed 5 MiB.');
  });
  test('accumulates all invalid fields without generating an article',
      () async {
    final validating = PublishArticleUseCase(
      clock: () => throw StateError('Clock must not be called.'),
      generateId: () => throw StateError('ID must not be generated.'),
    );
    final result = await validating(
        params: input(
      text: {for (final field in limits.keys) field: ' '},
      fileName: ' ',
      mimeType: 'image/gif',
      bytes: [],
    ));
    expect(result.article, isNull);
    expect(
        result.errors.map((error) => error.field), PublishArticleField.values);
  });
  test('missing params produces ArgumentError', () async {
    await expectLater(useCase(), throwsArgumentError);
  });
  test('explicit null params produces ArgumentError', () async {
    await expectLater(useCase(params: null), throwsArgumentError);
  });
  test('defaults work without Firebase or global DI', () async {
    final result = await PublishArticleUseCase()(params: input());
    expect(result.article, isNotNull);
    expect(result.article!.id, startsWith('mock-'));
    expect(result.errors, isEmpty);
  });
}
