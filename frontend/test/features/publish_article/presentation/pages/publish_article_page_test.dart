import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_app_clean_architecture/config/routes/routes.dart';
import 'package:news_app_clean_architecture/features/publish_article/domain/use_cases/publish_article_use_case.dart';
import 'package:news_app_clean_architecture/features/publish_article/presentation/cubit/publish_article_cubit.dart';
import 'package:news_app_clean_architecture/features/publish_article/presentation/pages/publish_article_page.dart';
import 'package:news_app_clean_architecture/injection_container.dart';

Widget buildPage(PublishArticleCubit cubit) {
  return MaterialApp(
    home: BlocProvider<PublishArticleCubit>.value(
      value: cubit,
      child: const PublishArticlePage(),
    ),
  );
}

void configurePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('PublishArticlePage', () {
    testWidgets('renders the publication form', (tester) async {
      configurePhoneSize(tester);
      final cubit = PublishArticleCubit(PublishArticleUseCase());

      await tester.pumpWidget(buildPage(cubit));

      expect(
        find.byKey(const Key('publishArticleTitleField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('publishArticleAuthorField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('publishArticleDescriptionField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('publishArticleContentField')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('publishArticleAttachImageButton')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('publishArticleSubmitButton')),
        findsOneWidget,
      );
      expect(find.text('Publish Article'), findsOneWidget);

      final attachButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('publishArticleAttachImageButton')),
      );
      expect(attachButton.onPressed, isNull);

      await cubit.close();
    });

    testWidgets('sends text field changes to the cubit', (tester) async {
      configurePhoneSize(tester);
      final cubit = PublishArticleCubit(PublishArticleUseCase());

      await tester.pumpWidget(buildPage(cubit));

      await tester.enterText(
        find.byKey(const Key('publishArticleTitleField')),
        'Article title',
      );
      await tester.enterText(
        find.byKey(const Key('publishArticleAuthorField')),
        'Jane Doe',
      );
      await tester.enterText(
        find.byKey(const Key('publishArticleDescriptionField')),
        'Article summary',
      );

      final contentField = find.byKey(const Key('publishArticleContentField'));
      await tester.ensureVisible(contentField);
      await tester.enterText(contentField, 'Article content');

      expect(cubit.state.title, 'Article title');
      expect(cubit.state.author, 'Jane Doe');
      expect(cubit.state.description, 'Article summary');
      expect(cubit.state.content, 'Article content');

      await cubit.close();
    });

    testWidgets('shows domain validation errors after an empty submission',
        (tester) async {
      configurePhoneSize(tester);
      final cubit = PublishArticleCubit(PublishArticleUseCase());

      await tester.pumpWidget(buildPage(cubit));

      await tester.tap(
        find.byKey(const Key('publishArticleSubmitButton')),
      );
      await tester.pumpAndSettle();

      expect(cubit.state.validationErrors, hasLength(7));
      expect(find.text('Required.'), findsNWidgets(4));
      expect(find.text('Image bytes are required.'), findsOneWidget);

      await cubit.close();
    });
  });

  group('PublishArticle route', () {
    setUp(() async {
      await sl.reset();
      sl.registerFactory<PublishArticleCubit>(
        () => PublishArticleCubit(PublishArticleUseCase()),
      );
    });

    tearDown(() async {
      await sl.reset();
    });

    testWidgets('opens the publication page and returns with the back button',
        (tester) async {
      configurePhoneSize(tester);

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRoutes.onGenerateRoutes,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    key: const Key('openPublishArticleButton'),
                    onPressed: () {
                      Navigator.pushNamed(context, '/PublishArticle');
                    },
                    child: const Text('Open publication form'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('openPublishArticleButton')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PublishArticlePage), findsOneWidget);
      expect(
        find.byKey(const Key('publishArticleTitleField')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('publishArticleBackButton')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PublishArticlePage), findsNothing);
      expect(find.text('Open publication form'), findsOneWidget);
    });
  });
}
