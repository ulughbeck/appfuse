import 'dart:async';

import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Replaces the values that the default storage reads.
void seedSavedValues(Map<String, Object> values) {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(values);
}

/// Resets the saved settings and the app info before each test.
///
/// With [mockAppInfo] set to `false`, the app info is not filled. A test file
/// that replaces `PackageInfoPlatform.instance` needs this, as the filled app
/// info is cached for the whole file.
void setUpAppFuseMocks({bool mockAppInfo = true}) {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    seedSavedValues(<String, Object>{});
    if (mockAppInfo) {
      PackageInfo.setMockInitialValues(
        appName: 'appfuse_test',
        packageName: 'dev.appfuse.test',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
    }
  });
}

/// A minimal config for testing, requiring no assets or network.
class TestConfig extends BaseConfig {
  const TestConfig({super.name = 'TEST', super.showBanner = false})
    : super(color: const Color(0xFFFF0000));

  @override
  Future<BaseConfig> init() async => this;

  @override
  T getConfigValue<T extends Object?>(String key) =>
      throw UnsupportedError('no values in TestConfig');
}

/// A config whose [init] waits for [delay], then fails when [fails] is `true`.
class SlowConfig extends BaseConfig {
  const SlowConfig({
    required super.name,
    this.delay = const Duration(seconds: 1),
    this.fails = false,
  });

  final Duration delay;
  final bool fails;

  @override
  Future<BaseConfig> init() async {
    await Future<void>.delayed(delay);
    if (fails) throw StateError('config failed');
    return this;
  }

  @override
  T getConfigValue<T extends Object?>(String key) =>
      throw UnsupportedError('no values');
}

/// Runs one step that records the config it sees, and counts [dispose] calls.
///
/// The step fails when the config is named [failsFor]. [dispose] throws [disposeError].
class RecordingInitialization with AppFuseInitialization {
  RecordingInitialization({this.failsFor, this.disposeError});

  final String? failsFor;
  final Object? disposeError;
  final seenConfigs = <String>[];
  int disposals = 0;

  @override
  Map<String, InitializationStep> get steps => {
    'record config': (state) async {
      if (state.config.name == failsFor) throw StateError('step failed');
      seenConfigs.add(state.config.name);
    },
  };

  @override
  void dispose() {
    disposals++;
    if (disposeError case final error?) throw error;
  }
}

/// Returns a factory for [RecordingInitialization] that adds each instance to [created].
RecordingInitialization Function() recordingFactory(
  List<RecordingInitialization> created, {
  String? failsFor,
  Object? disposeError,
}) => () {
  final init = RecordingInitialization(
    failsFor: failsFor,
    disposeError: disposeError,
  );
  created.add(init);
  return init;
};

/// Keeps values in memory and lists the key of each write in [writes]. Writes and removes of [failingKeys] throw.
class MemoryStorage implements IAppFuseStorage {
  MemoryStorage({Map<String, String>? values, this.failingKeys = const {}})
    : values = values ?? {};

  final Map<String, String> values;
  final Set<String> failingKeys;
  final writes = <String>[];

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failingKeys.contains(key)) throw StateError('failed to save "$key"');
    writes.add(key);
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (failingKeys.contains(key)) throw StateError('failed to remove "$key"');
    values.remove(key);
  }
}

/// Counts how many times its state is (re)created, to observe remounts.
class MountProbe extends StatefulWidget {
  const MountProbe({required this.onMount, super.key});

  final VoidCallback onMount;

  @override
  State<MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) =>
      const Text('app', textDirection: TextDirection.ltr);
}

/// Counts its builds and watches only [aspect].
class AspectProbe extends StatelessWidget {
  const AspectProbe({required this.aspect, required this.onBuild, super.key});

  final AppFuseAspect aspect;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    AppFuseScope.watch(context, aspect);
    onBuild();
    return const SizedBox.expand();
  }
}

/// Pumps an [AppFuseScope] and returns a context below it.
///
/// With [material], the context is below a [MaterialApp], so dialogs can open.
Future<BuildContext> pumpApp<T extends AppFuseInitialization>(
  WidgetTester tester, {
  List<BaseConfig>? configs,
  Map<Brightness, ThemeData>? themes,
  Map<Locale, String>? supportedLanguages,
  IAppFuseStorage? storage,
  T Function()? init,
  void Function(Object error, StackTrace stackTrace)? onError,
  bool material = false,
  Widget child = const SizedBox.expand(),
}) async {
  late BuildContext appContext;
  final app = Builder(
    builder: (context) {
      appContext = context;
      return child;
    },
  );
  await tester.pumpWidget(
    AppFuseScope(
      configs: configs,
      themes: themes,
      supportedLanguages: supportedLanguages,
      storage: storage,
      init: init,
      onError: onError,
      app: material ? MaterialApp(home: Scaffold(body: app)) : app,
    ),
  );
  await tester.pumpAndSettle();
  return appContext;
}

const permissionChannel = MethodChannel(
  'flutter.baseflow.com/permissions/methods',
);

/// The state of the mocked permission_handler. Change [status] between calls.
class PermissionsMock {
  PermissionsMock(this.status, {this.checkFails = false});

  PermissionStatus status;
  bool checkFails;

  /// The names of the channel methods that were called.
  final calls = <String>[];
}

/// Answers permission_handler calls.
///
/// Checks return the current [PermissionsMock.status], or fail while
/// [PermissionsMock.checkFails] is `true`. Requests return what [request]
/// returns, and fail when it throws. The settings screen opens when
/// [settingsOpen] is `true`, as `openAppSettings` reports.
PermissionsMock mockPermissions(
  WidgetTester tester, {
  required PermissionStatus status,
  FutureOr<PermissionStatus> Function()? request,
  bool checkFails = false,
  bool settingsOpen = true,
}) {
  final mock = PermissionsMock(status, checkFails: checkFails);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    permissionChannel,
    (call) async {
      mock.calls.add(call.method);
      return switch (call.method) {
        'checkPermissionStatus' =>
          mock.checkFails
              ? throw PlatformException(code: 'check failed')
              : mock.status.index,
        'requestPermissions' => {
          for (final permission in call.arguments as List<Object?>)
            permission:
                (await (request?.call() ?? PermissionStatus.granted)).index,
        },
        'openAppSettings' => settingsOpen,
        _ => null,
      };
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      permissionChannel,
      null,
    ),
  );
  return mock;
}
