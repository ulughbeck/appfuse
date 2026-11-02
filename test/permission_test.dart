import 'dart:async';

import 'package:appfuse/appfuse.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUpAppFuseMocks();

  Future<BuildContext> pumpScope(WidgetTester tester) => pumpApp(
    tester,
    themes: {
      Brightness.light: ThemeData.light(),
      Brightness.dark: ThemeData.dark(),
    },
    material: true,
  );

  testWidgets('check and request store the status in the state', (
    tester,
  ) async {
    mockPermissions(tester, status: PermissionStatus.denied);
    final context = await pumpScope(tester);

    expect(
      await context.fuse.checkPermissionStatus(Permission.camera),
      PermissionStatus.denied,
    );
    expect(
      context.fuse.state.permissions[Permission.camera],
      PermissionStatus.denied,
    );

    expect(
      await context.fuse.requestPermission(Permission.camera),
      PermissionStatus.granted,
    );
    expect(
      context.fuse.state.permissions[Permission.camera],
      PermissionStatus.granted,
    );
  });

  testWidgets('a theme change completes while a request waits for the user', (
    tester,
  ) async {
    final answer = Completer<PermissionStatus>();
    mockPermissions(
      tester,
      status: PermissionStatus.denied,
      request: () => answer.future,
    );
    final context = await pumpScope(tester);

    final request = context.fuse.requestPermission(Permission.camera);
    await context.fuse.changeThemeMode(ThemeMode.dark);
    expect(context.fuse.state.themeMode, ThemeMode.dark);

    answer.complete(PermissionStatus.granted);
    expect(await request, PermissionStatus.granted);
  });

  group('on resume', () {
    void resume(WidgetTester tester) => tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    testWidgets('stores the statuses that changed in the system settings', (
      tester,
    ) async {
      final mock = mockPermissions(tester, status: PermissionStatus.denied);
      final context = await pumpScope(tester);
      await context.fuse.checkPermissionStatus(Permission.camera);
      await context.fuse.checkPermissionStatus(Permission.microphone);

      mock.status = PermissionStatus.granted;
      resume(tester);
      await tester.pump();

      expect(context.fuse.state.permissions, {
        Permission.camera: PermissionStatus.granted,
        Permission.microphone: PermissionStatus.granted,
      });
    });

    testWidgets('does not notify when no status changed', (tester) async {
      mockPermissions(tester, status: PermissionStatus.denied);
      final context = await pumpScope(tester);
      await context.fuse.checkPermissionStatus(Permission.camera);
      var notifications = 0;
      context.fuse.addListener(() => notifications++);

      resume(tester);
      await tester.pump();

      expect(notifications, 0);
    });

    testWidgets('does not check when no permission is known', (tester) async {
      final mock = mockPermissions(tester, status: PermissionStatus.denied);
      final context = await pumpScope(tester);

      resume(tester);
      await tester.pump();

      expect(mock.calls, isEmpty);
      expect(context.fuse.state.permissions, isEmpty);
    });

    testWidgets('a failed check is reported and keeps the old status', (
      tester,
    ) async {
      final mock = mockPermissions(tester, status: PermissionStatus.denied);
      final errors = <Object>[];
      final context = await pumpApp(
        tester,
        material: true,
        onError: (error, _) => errors.add(error),
      );
      await context.fuse.checkPermissionStatus(Permission.camera);

      mock
        ..status = PermissionStatus.granted
        ..checkFails = true;
      resume(tester);
      await tester.pump();

      expect(errors.single, isA<PlatformException>());
      expect(
        context.fuse.state.permissions[Permission.camera],
        PermissionStatus.denied,
      );
    });
  });

  group('failures', () {
    testWidgets('a failed request is reported and rethrown', (tester) async {
      mockPermissions(
        tester,
        status: PermissionStatus.denied,
        request: () => throw PlatformException(code: 'request failed'),
      );
      final errors = <Object>[];
      final context = await pumpApp(
        tester,
        onError: (error, _) => errors.add(error),
      );

      await expectLater(
        context.fuse.requestPermission(Permission.camera),
        throwsA(isA<PlatformException>()),
      );
      expect(errors.single, isA<PlatformException>());
      expect(context.fuse.state.permissions, isEmpty);
    });

    testWidgets('a failed check is reported and rethrown', (tester) async {
      mockPermissions(
        tester,
        status: PermissionStatus.denied,
        checkFails: true,
      );
      final errors = <Object>[];
      final context = await pumpApp(
        tester,
        onError: (error, _) => errors.add(error),
      );

      await expectLater(
        context.fuse.checkPermissionStatus(Permission.camera),
        throwsA(isA<PlatformException>()),
      );
      expect(errors.single, isA<PlatformException>());
    });
  });

  group('askPermissionDialog', () {
    testWidgets('shows a title and the reason once', (tester) async {
      mockPermissions(tester, status: PermissionStatus.denied);
      final context = await pumpScope(tester);

      askPermissionDialog(
        context: context,
        permission: Permission.camera,
        reasonText: 'To scan codes.',
      ).ignore();
      await tester.pumpAndSettle();

      expect(find.text('Camera access'), findsOneWidget);
      expect(find.text('To scan codes.'), findsOneWidget);
    });

    testWidgets('"Not now" returns false', (tester) async {
      mockPermissions(tester, status: PermissionStatus.denied);
      final context = await pumpScope(tester);

      final result = askPermissionDialog(
        context: context,
        permission: Permission.camera,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a tap outside the dialog returns false', (tester) async {
      mockPermissions(tester, status: PermissionStatus.denied);
      final context = await pumpScope(tester);

      final result = askPermissionDialog(
        context: context,
        permission: Permission.camera,
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
    });

    testWidgets('a granted request returns true', (tester) async {
      mockPermissions(tester, status: PermissionStatus.denied);
      final context = await pumpScope(tester);

      final result = askPermissionDialog(
        context: context,
        permission: Permission.camera,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
    });

    testWidgets('a limited request counts as granted', (tester) async {
      mockPermissions(
        tester,
        status: PermissionStatus.denied,
        request: () => PermissionStatus.limited,
      );
      final context = await pumpScope(tester);

      final result = askPermissionDialog(
        context: context,
        permission: Permission.photos,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
    });

    testWidgets('a limited status returns true without a dialog', (
      tester,
    ) async {
      mockPermissions(tester, status: PermissionStatus.limited);
      final context = await pumpScope(tester);

      final result = askPermissionDialog(
        context: context,
        permission: Permission.photos,
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(await result, isTrue);
    });

    testWidgets('a permanently denied request switches to the settings view', (
      tester,
    ) async {
      mockPermissions(
        tester,
        status: PermissionStatus.denied,
        request: () => PermissionStatus.permanentlyDenied,
      );
      final context = await pumpScope(tester);

      final result = askPermissionDialog(
        context: context,
        permission: Permission.camera,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.text('You can go to app settings and enable permissions there.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await result, isFalse);
    });

    testWidgets('a second tap does not start a second request', (tester) async {
      final answer = Completer<PermissionStatus>();
      var requests = 0;
      mockPermissions(
        tester,
        status: PermissionStatus.denied,
        request: () {
          requests++;
          return answer.future;
        },
      );
      final context = await pumpScope(tester);

      final result = askPermissionDialog(
        context: context,
        permission: Permission.camera,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.tap(find.text('OK'), warnIfMissed: false);
      await tester.pump();

      expect(requests, 1);
      for (final label in ['OK', 'Not now']) {
        final button = find.widgetWithText(TextButton, label);
        expect(tester.widget<TextButton>(button).onPressed, isNull);
      }

      answer.complete(PermissionStatus.granted);
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('a failed request closes the dialog with false', (
      tester,
    ) async {
      mockPermissions(
        tester,
        status: PermissionStatus.denied,
        request: () => throw PlatformException(code: 'request failed'),
      );
      final errors = <Object>[];
      final context = await pumpApp(
        tester,
        material: true,
        onError: (error, _) => errors.add(error),
      );

      final result = askPermissionDialog(
        context: context,
        permission: Permission.camera,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(await result, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
      expect(errors.single, isA<PlatformException>());
    });

    testWidgets('a failed check returns false without a dialog', (
      tester,
    ) async {
      mockPermissions(
        tester,
        status: PermissionStatus.denied,
        checkFails: true,
      );
      final errors = <Object>[];
      final context = await pumpApp(
        tester,
        material: true,
        onError: (error, _) => errors.add(error),
      );

      final result = await askPermissionDialog(
        context: context,
        permission: Permission.camera,
      );

      expect(result, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
      expect(errors.single, isA<PlatformException>());
    });

    testWidgets('the settings view stays open when the settings do not open', (
      tester,
    ) async {
      mockPermissions(
        tester,
        status: PermissionStatus.denied,
        request: () => PermissionStatus.permanentlyDenied,
        settingsOpen: false,
      );
      final context = await pumpScope(tester);

      final result = askPermissionDialog(
        context: context,
        permission: Permission.camera,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Open Settings'),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });
  });

  group('without plugin support', () {
    for (final platform in [TargetPlatform.macOS, TargetPlatform.linux]) {
      testWidgets('${platform.name} reports granted without a plugin call', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          final mock = mockPermissions(
            tester,
            status: PermissionStatus.denied,
            checkFails: true,
            settingsOpen: true,
          );
          final context = await pumpScope(tester);

          expect(
            await context.fuse.checkPermissionStatus(Permission.camera),
            PermissionStatus.granted,
          );
          expect(
            await context.fuse.requestPermission(Permission.microphone),
            PermissionStatus.granted,
          );
          expect(context.fuse.state.permissions, {
            Permission.camera: PermissionStatus.granted,
            Permission.microphone: PermissionStatus.granted,
          });
          expect(await context.fuse.openSettings(), isFalse);

          final result = askPermissionDialog(
            context: context,
            permission: Permission.camera,
          );
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(await result, isTrue);

          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump();

          expect(mock.calls, isEmpty);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  });
}
