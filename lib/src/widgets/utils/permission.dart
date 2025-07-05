// ignore_for_file: use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../controller/controller.dart';
import '../foundation/scope.dart';

Future<bool> askPermissionDialog({
  required BuildContext context,
  required Permission permission,
  String goToSettingsText = 'You can go to app settings and enable permissions there.',
  String goToSettingsBtnText = 'Open Settings',
  String? reasonText,
}) async {
  final status = await context.fuse.checkPermissionStatus(permission);
  if (status == PermissionStatus.granted) return true;

  String permissionName(Permission permission) {
    final name = permission.toString().replaceAll('Permission.', '');
    if (name.contains('location')) return 'Location';
    return name[0].toUpperCase() + name.substring(1);
  }

  final reason = reasonText ?? 'App needs permission for accessing ${permissionName(permission)} to work further.';

  final result = await showDialog<PermissionStatus>(
    barrierDismissible: false,
    context: context,
    builder: (context) => _AskPermissionDialog(
      permission: permission,
      status: status,
      reasonText: reason,
      goToSettingsText: goToSettingsText,
      goToSettingsBtnText: goToSettingsBtnText,
    ),
  );

  return result == PermissionStatus.granted;
}

class _AskPermissionDialog extends StatelessWidget {
  const _AskPermissionDialog({
    required this.permission,
    required this.status,
    required this.reasonText,
    required this.goToSettingsText,
    required this.goToSettingsBtnText,
  });
  final Permission permission;
  final PermissionStatus status;
  final String reasonText;
  final String goToSettingsText;
  final String goToSettingsBtnText;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Theme.of(context).textTheme.titleLarge?.color ?? Colors.black;

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 10),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 20),
            Icon(Icons.device_unknown, size: 50, color: secondaryColor),
            const SizedBox(height: 20),
            _AskPermissionDialogText(
              reasonText,
              isTitle: true,
              color: secondaryColor,
            ),
            const SizedBox(height: 20),
            _AskPermissionDialogText(
              reasonText,
              color: secondaryColor,
            ),
            if (status == PermissionStatus.permanentlyDenied)
              _AskPermissionDialogText(
                goToSettingsText,
                color: secondaryColor,
              ),
            const SizedBox(height: 20),
            Container(
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: secondaryColor.withAlpha(50),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: <Widget>[
                  if (status != PermissionStatus.permanentlyDenied)
                    _AskPermissionDialogButton(
                      'OK',
                      color: primaryColor,
                      onTap: () => _requestPermission(context),
                    )
                  else
                    _AskPermissionDialogButton(
                      goToSettingsBtnText,
                      color: primaryColor,
                      onTap: () => _openSettings(context),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPermission(BuildContext context) async {
    final result = await context.fuse.requestPermission(permission);
    if (!context.mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _openSettings(BuildContext context) async {
    final result = await context.fuse.openSettings();
    if (!context.mounted) return;
    if (result) Navigator.of(context).pop();
  }
}

class _AskPermissionDialogText extends StatelessWidget {
  const _AskPermissionDialogText(
    this.text, {
    required this.color,
    this.isTitle = false,
  });
  final String text;
  final bool isTitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontSize: isTitle ? 20.0 : 16.0,
                fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
              ),
          textAlign: TextAlign.center,
        ),
      );
}

class _AskPermissionDialogButton extends StatelessWidget {
  const _AskPermissionDialogButton(
    this.name, {
    required this.onTap,
    required this.color,
  });
  final String name;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 13),
        onPressed: onTap,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Text(
            name,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      );
}
