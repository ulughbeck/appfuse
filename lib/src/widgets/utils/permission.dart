import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../foundation/scope.dart';

/// Asks for [permission] with a dialog that explains [reasonText] first.
///
/// Returns `true` when the permission is granted, limited, or provisional.
/// When the permission is permanently denied, the dialog shows
/// [goToSettingsText], offers the app settings, and returns `false`, because
/// the user changes it outside the app. The dialog closes only when the
/// settings open. While a request or the settings call runs, the buttons are
/// off. A failed check or request returns `false`, and [AppFuseController]
/// reports the error to `onError`. Where the plugin has no support (macOS,
/// Linux, Fuchsia), it returns `true` without a dialog.
Future<bool> askPermissionDialog({
  required BuildContext context,
  required Permission permission,
  String goToSettingsText =
      'You can go to app settings and enable permissions there.',
  String goToSettingsBtnText = 'Open Settings',
  String cancelBtnText = 'Not now',
  String okBtnText = 'OK',
  String? titleText,
  String? reasonText,
}) async {
  final PermissionStatus status;
  try {
    status = await context.fuse.checkPermissionStatus(permission);
  } on Object {
    return false;
  }
  if (_isUsable(status)) return true;
  if (!context.mounted) return false;

  final name = _permissionName(permission);
  final granted = await showDialog<bool>(
    context: context,
    builder: (context) => _AskPermissionDialog(
      permission: permission,
      status: status,
      titleText: titleText ?? '$name access',
      reasonText:
          reasonText ??
          'App needs permission for accessing $name to work further.',
      goToSettingsText: goToSettingsText,
      goToSettingsBtnText: goToSettingsBtnText,
      cancelBtnText: cancelBtnText,
      okBtnText: okBtnText,
    ),
  );
  return granted ?? false;
}

bool _isUsable(PermissionStatus status) => switch (status) {
  PermissionStatus.granted ||
  PermissionStatus.limited ||
  PermissionStatus.provisional => true,
  PermissionStatus.denied ||
  PermissionStatus.restricted ||
  PermissionStatus.permanentlyDenied => false,
};

String _permissionName(Permission permission) {
  final name = permission.toString().replaceAll('Permission.', '');
  if (name.contains('location')) return 'Location';
  return name[0].toUpperCase() + name.substring(1);
}

class _AskPermissionDialog extends StatefulWidget {
  const _AskPermissionDialog({
    required this.permission,
    required this.status,
    required this.titleText,
    required this.reasonText,
    required this.goToSettingsText,
    required this.goToSettingsBtnText,
    required this.cancelBtnText,
    required this.okBtnText,
  });
  final Permission permission;
  final PermissionStatus status;
  final String titleText;
  final String reasonText;
  final String goToSettingsText;
  final String goToSettingsBtnText;
  final String cancelBtnText;
  final String okBtnText;

  @override
  State<_AskPermissionDialog> createState() => _AskPermissionDialogState();
}

class _AskPermissionDialogState extends State<_AskPermissionDialog> {
  late PermissionStatus _status = widget.status;
  bool _busy = false;

  bool get _needsSettings => _status == PermissionStatus.permanentlyDenied;

  /// Runs [action] with the buttons off.
  ///
  /// A result closes the dialog with it, `null` keeps the dialog open, and an
  /// error closes it with `false`. The controller already reported the error.
  Future<void> _run(Future<bool?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    bool? result;
    try {
      result = await action();
    } on Object {
      result = false;
    }
    if (!mounted) return;
    if (result == null) {
      setState(() => _busy = false);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  /// On Android the status is `denied` until a request returns
  /// `permanentlyDenied`, so the dialog then shows the settings view.
  Future<void> _request() => _run(() async {
    final result = await context.fuse.requestPermission(widget.permission);
    if (result != PermissionStatus.permanentlyDenied) return _isUsable(result);
    if (mounted) setState(() => _status = result);
    return null;
  });

  /// Closes the dialog only when the settings open. Web never opens them.
  Future<void> _openSettings() => _run(() async {
    final opened = await context.fuse.openSettings();
    return opened ? false : null;
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        Icons.device_unknown,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(widget.titleText, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.reasonText, textAlign: TextAlign.center),
          if (_needsSettings) ...[
            const SizedBox(height: 8),
            Text(widget.goToSettingsText, textAlign: TextAlign.center),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(widget.cancelBtnText),
        ),
        if (_needsSettings)
          TextButton(
            onPressed: _busy ? null : _openSettings,
            child: Text(widget.goToSettingsBtnText),
          )
        else
          TextButton(
            onPressed: _busy ? null : _request,
            child: Text(widget.okBtnText),
          ),
      ],
    );
  }
}
