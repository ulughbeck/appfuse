import 'dart:async';

import 'package:appfuse/appfuse.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus_platform_interface/package_info_data.dart';
import 'package:package_info_plus_platform_interface/package_info_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'helpers.dart';

/// An app info platform whose [getAll] runs [onGetAll].
class _FakePackageInfoPlatform extends PackageInfoPlatform
    with MockPlatformInterfaceMixin {
  _FakePackageInfoPlatform(this.onGetAll);

  final Future<PackageInfoData> Function() onGetAll;

  @override
  Future<PackageInfoData> getAll({String? baseUrl}) => onGetAll();
}

void main() {
  const appKey = Key('app');
  setUpAppFuseMocks(mockAppInfo: false);

  testWidgets('a failed app info read is reported and startup continues', (
    tester,
  ) async {
    final failure = StateError('no app info');
    PackageInfoPlatform.instance = _FakePackageInfoPlatform(
      () async => throw failure,
    );
    final errors = <Object>[];

    final context = await pumpApp(
      tester,
      onError: (error, _) => errors.add(error),
    );

    final state = context.fuse.state;
    expect(state.phase, isA<AppFuseReady>());
    expect(errors, [failure]);
    expect(state.metaData.appVersion, '');
    expect(state.metaData.appName, '');
    expect(state.metaData.appPackageName, '');
    expect(state.metaData.appBuildNumber, '');
    expect(state.metaData.operatingSystem, isNotEmpty);
    expect(state.metaData.isFirstLaunch, isTrue);
  });

  testWidgets('a slow app info read times out after 5 seconds', (tester) async {
    PackageInfoPlatform.instance = _FakePackageInfoPlatform(
      () => Completer<PackageInfoData>().future,
    );
    final errors = <Object>[];

    await tester.pumpWidget(
      AppFuseScope(
        onError: (error, _) => errors.add(error),
        app: const SizedBox.expand(key: appKey),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(appKey), findsNothing);
    expect(errors, isEmpty);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final state = AppFuseScope.read(tester.element(find.byKey(appKey)));
    expect(state.phase, isA<AppFuseReady>());
    expect(errors, [isA<TimeoutException>()]);
    expect(state.metaData.appVersion, '');
    expect(state.metaData.appName, '');
    expect(state.metaData.operatingSystem, isNotEmpty);
  });
}
