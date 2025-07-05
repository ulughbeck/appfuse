part of 'controller.dart';

extension $PermissionSettings on AppFuseController {
  List<Permission> get permissions => Permission.values;

  /// Checks the status of all available permissions during app initialization.
  Future<void> _checkPermissions() async {
    final permissions = <Permission, PermissionStatus>{};

    for (final perm in Permission.values) {
      try {
        final status = await perm.status;
        permissions[perm] = status;
      } catch (e) {
        //ignore
      }
    }
    _onProgress('Permissions: $permissions');
    setState(state.copyWith(permissions: permissions));
  }

  /// Checks the current status of a single [permission].
  Future<PermissionStatus> checkPermissionStatus(Permission permission) => permission.status;

  /// Requests a single [permission] from the user.
  Future<PermissionStatus> requestPermission(Permission permission) => permission.request();

  /// Opens the app's settings screen to allow the user to manually change permissions.
  Future<bool> openSettings() => openAppSettings();
}
