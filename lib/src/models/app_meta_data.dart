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
    required this.processorsCount,
    required this.systemLocale,
    required this.deviceVersion,
    required this.appLaunchedTimestamp,
    required this.appFirstLaunchTimestamp,
  });

  factory AppMetaData.none() => AppMetaData(
        isWeb: kIsWeb,
        isRelease: !kDebugMode,
        isFirstLaunch: true,
        appVersion: '',
        appBuildNumber: '',
        appPackageName: '',
        appName: '',
        operatingSystem: '',
        processorsCount: 0,
        systemLocale: '',
        deviceVersion: '',
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

  /// Operating system
  final String operatingSystem;

  /// Processors count
  final int processorsCount;

  /// Locale
  final String systemLocale;

  /// Device representation
  final String deviceVersion;

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
        'X-Meta-Processors-Count': processorsCount.toString(),
        'X-Meta-Device-Locale': systemLocale,
        'X-Meta-Device-Version': deviceVersion,
        'X-Meta-App-First-Launched-Timestamp': appFirstLaunchTimestamp.millisecondsSinceEpoch.toString(),
        'X-Meta-App-Launched-Timestamp': appLaunchedTimestamp.millisecondsSinceEpoch.toString(),
      };

  @override
  bool operator ==(covariant AppMetaData other) {
    if (identical(this, other)) return true;

    return other.isWeb == isWeb &&
        other.isRelease == isRelease &&
        other.isFirstLaunch == isFirstLaunch &&
        other.appVersion == appVersion &&
        other.appBuildNumber == appBuildNumber &&
        other.appPackageName == appPackageName &&
        other.appName == appName &&
        other.operatingSystem == operatingSystem &&
        other.processorsCount == processorsCount &&
        other.systemLocale == systemLocale &&
        other.deviceVersion == deviceVersion &&
        other.appLaunchedTimestamp == appLaunchedTimestamp &&
        other.appFirstLaunchTimestamp == appFirstLaunchTimestamp;
  }

  @override
  int get hashCode =>
      isWeb.hashCode ^
      isRelease.hashCode ^
      isFirstLaunch.hashCode ^
      appVersion.hashCode ^
      appBuildNumber.hashCode ^
      appPackageName.hashCode ^
      appName.hashCode ^
      operatingSystem.hashCode ^
      processorsCount.hashCode ^
      systemLocale.hashCode ^
      deviceVersion.hashCode ^
      appLaunchedTimestamp.hashCode ^
      appFirstLaunchTimestamp.hashCode;
}
