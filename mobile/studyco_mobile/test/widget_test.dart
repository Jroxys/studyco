import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/features/home/screens/counter_screen.dart';

void main() {
  testWidgets('Login is the initial screen and validates empty fields', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Hoş geldin!'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.ensureVisible(find.text('Giriş Yap'));
    await tester.tap(find.text('Giriş Yap'));
    await tester.pump();

    expect(find.text('E-posta adresinizi girin.'), findsOneWidget);
    expect(find.text('Şifrenizi girin.'), findsOneWidget);
  });

  testWidgets('Email validation and password visibility work', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(find.byType(TextFormField).first, 'invalid');
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.pump();

    expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Şifreyi göster'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Şifreyi gizle'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      'student@university.edu',
    );
    await tester.ensureVisible(find.text('Giriş Yap'));
    await tester.tap(find.text('Giriş Yap'));
    await tester.pump();
    expect(find.text('Geçerli bir e-posta adresi girin.'), findsNothing);
    expect(find.text('Giriş şu anda kullanılamıyor.'), findsOneWidget);
    expect(find.text('Hoş geldin!'), findsOneWidget);
  });

  testWidgets('Small screen with keyboard remains scrollable', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const MyApp());
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    await tester.ensureVisible(find.text('Giriş Yap'));
    await tester.tap(find.text('Giriş Yap'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Şifrenizi girin.'), findsOneWidget);
  });

  testWidgets(
    'Login coalesces rapid button and Done submissions and permits retry',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.enterText(
        find.byType(TextFormField).first,
        'student@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'secret');
      await tester.ensureVisible(find.byType(FilledButton));
      final submit =
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
      final done =
          tester
              .widget<TextField>(find.byType(TextField).last)
              .onSubmitted!;

      // Exercise stale callbacks before a rebuild can disable the button.
      submit();
      done('secret');
      submit();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Giriş şu anda kullanılamıyor.'), findsOneWidget);

      // A duplicate submission would queue another notification.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      submit();
      await tester.pumpAndSettle();
      expect(find.text('Giriş şu anda kullanılamıyor.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Login submission remains safe when its screen is removed', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(
      find.byType(TextFormField).first,
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    final submit =
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
    submit();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    submit();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Counter screen still increments', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MyHomePage(title: 'Flutter Demo Home Page')),
    );
    expect(find.text('0'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });
}
