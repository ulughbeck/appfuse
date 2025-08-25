part of 'controller.dart';

extension $PermissionSettings on AppFuseController {
  List<Permission> get permissions => Permission.values;

  /// Checks the current status of a single [permission].
  Future<PermissionStatus> checkPermissionStatus(Permission permission) =>
      handle<PermissionStatus>(() => permission.status);

  /// Requests a single [permission] from the user.
  Future<PermissionStatus> requestPermission(Permission permission) =>
      handle<PermissionStatus>(() => permission.request());

  /// Opens the app's settings screen to allow the user to manually change permissions.
  Future<bool> openSettings() => openAppSettings();
}
