import 'package:flutter/foundation.dart';

@immutable
class AppMetaData {
  const AppMetaData({
    required this.isWeb,
    required this.isRelease,
    required this.isFirstLaunch,
    required this.appVersion,
    required this.appBuildNumber,
    required this.appPackageName,
    required this.appName,
    required this.operatingSystem,
    required this.systemLocale,
    required this.appLaunchedTimestamp,
    required this.appFirstLaunchTimestamp,
  });

  factory AppMetaData.none() => AppMetaData(
    isWeb: kIsWeb,
    isRelease: kReleaseMode,
    isFirstLaunch: true,
    appVersion: '',
    appBuildNumber: '',
    appPackageName: '',
    appName: '',
    operatingSystem: '',
    systemLocale: '',
    appLaunchedTimestamp: DateTime.now(),
    appFirstLaunchTimestamp: DateTime.now(),
  );

  /// Is web platform
  final bool isWeb;

  /// Is release build
  final bool isRelease;

  /// Is first run
  final bool isFirstLaunch;

  /// App version
  final String appVersion;

  /// App build timestamp
  final String appBuildNumber;

  /// Package name
  final String appPackageName;

  /// App name
  final String appName;

  /// The name of the [TargetPlatform], for example `android` or `iOS`
  final String operatingSystem;

  /// Locale
  final String systemLocale;

  /// App launched timestamp
  final DateTime appLaunchedTimestamp;

  /// App first launched timestamp
  final DateTime appFirstLaunchTimestamp;

  /// Convert to headers
  Map<String, String> toHeaders() => <String, String>{
    'X-Meta-Is-Web': isWeb ? 'true' : 'false',
    'X-Meta-Is-Release': isRelease ? 'true' : 'false',
    'X-Meta-App-Version': appVersion,
    'X-Meta-App-Build-Number': appBuildNumber,
    'X-Meta-App-Package-Name': appPackageName,
    'X-Meta-App-Name': appName,
    'X-Meta-Operating-System': operatingSystem,
    'X-Meta-Device-Locale': systemLocale,
    'X-Meta-App-First-Launched-Timestamp': appFirstLaunchTimestamp
        .millisecondsSinceEpoch
        .toString(),
    'X-Meta-App-Launched-Timestamp': appLaunchedTimestamp.millisecondsSinceEpoch
        .toString(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppMetaData &&
          other.isWeb == isWeb &&
          other.isRelease == isRelease &&
          other.isFirstLaunch == isFirstLaunch &&
          other.appVersion == appVersion &&
          other.appBuildNumber == appBuildNumber &&
          other.appPackageName == appPackageName &&
          other.appName == appName &&
          other.operatingSystem == operatingSystem &&
          other.systemLocale == systemLocale &&
          other.appLaunchedTimestamp == appLaunchedTimestamp &&
          other.appFirstLaunchTimestamp == appFirstLaunchTimestamp;

  @override
  int get hashCode => Object.hash(
    isWeb,
    isRelease,
    isFirstLaunch,
    appVersion,
    appBuildNumber,
    appPackageName,
    appName,
    operatingSystem,
    systemLocale,
    appLaunchedTimestamp,
    appFirstLaunchTimestamp,
  );
}
