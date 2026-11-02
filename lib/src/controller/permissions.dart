part of 'controller.dart';

/// Permission calls do not wait for queued writes, and writes do not wait for an open OS prompt.
mixin _PermissionMixin<T extends AppFuseInitialization>
    on _AppFuseBase<T>, WidgetsBindingObserver {
  /// Checks the permissions in [AppFuseState.permissions] again when the app resumes.
  ///
  /// The user can change them in the system settings. A failed check goes to [onError].
  /// Does nothing where the plugin has no support.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    super.didChangeAppLifecycleState(lifecycle);
    if (lifecycle == .resumed) _refreshPermissions().ignore();
  }

  /// True where `permission_handler` has code. Elsewhere its calls throw `MissingPluginException`.
  bool get _permissionsSupported =>
      kIsWeb ||
      switch (defaultTargetPlatform) {
        .android || .iOS || .windows => true,
        .macOS || .linux || .fuchsia => false,
      };

  /// Updates the statuses that changed, with one state change. It never throws.
  Future<void> _refreshPermissions() async {
    if (!_permissionsSupported) return;
    final results = await Future.wait([
      for (final permission in state.permissions.keys) _recheck(permission),
    ]);
    final changed = {
      for (final (permission, status) in results.nonNulls)
        if (state.permissions[permission] != status) permission: status,
    };
    if (changed.isEmpty) return;
    _setState(
      state.copyWith(
        permissions: Map.unmodifiable({...state.permissions, ...changed}),
      ),
    );
  }

  Future<(Permission, PermissionStatus)?> _recheck(
    Permission permission,
  ) async {
    try {
      return (permission, await permission.status);
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace);
      return null;
    }
  }

  /// Checks the current status of a single [permission] and stores it in [AppFuseState.permissions].
  ///
  /// A failure goes to [onError], and the returned future completes with it.
  /// Where the plugin has no support (macOS, Linux, Fuchsia), it stores and returns
  /// [PermissionStatus.granted] without a plugin call.
  Future<PermissionStatus> checkPermissionStatus(Permission permission) =>
      _reported(
        () async => _setPermissionStatus(
          permission,
          _permissionsSupported ? await permission.status : .granted,
        ),
      );

  /// Requests a single [permission] from the user and stores the result in [AppFuseState.permissions].
  ///
  /// Fails and behaves the same way as [checkPermissionStatus].
  Future<PermissionStatus> requestPermission(Permission permission) =>
      _reported(
        () async => _setPermissionStatus(
          permission,
          _permissionsSupported ? await permission.request() : .granted,
        ),
      );

  /// Opens the app's settings screen to allow the user to manually change permissions.
  ///
  /// Returns `false` when the screen did not open, always on web and where the plugin has no support.
  /// Fails the same way as [checkPermissionStatus].
  Future<bool> openSettings() => _reported(
    () async => _permissionsSupported ? await openAppSettings() : false,
  );

  /// Runs [action]. A failure also goes to [onError].
  Future<R> _reported<R>(Future<R> Function() action) async {
    try {
      return await action();
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace);
      rethrow;
    }
  }

  PermissionStatus _setPermissionStatus(
    Permission permission,
    PermissionStatus status,
  ) {
    _setState(
      state.copyWith(
        permissions: Map.unmodifiable({
          ...state.permissions,
          permission: status,
        }),
      ),
    );
    return status;
  }
}
