import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../foundation/scope.dart';
import 'dialogs.dart';

/// Screens wider than this show the menu as a dialog, else as a bottom sheet.
const _kDialogBreakpoint = 750.0;

/// Shows [ConfigSettings] as a dialog on wide screens and as a bottom sheet on narrow ones.
void showAppFuseMenu(
  BuildContext context, {
  Widget? children,
  VoidCallback? onClose,
  Color? backgroundColor,
}) {
  if (MediaQuery.sizeOf(context).width > _kDialogBreakpoint) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => ConfigSettings.dialog(
        backgroundColor: backgroundColor,
        children: children,
        onClose: () {
          onClose?.call();
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
  } else {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      builder: (context) =>
          ConfigSettings.sheet(onClose: onClose, children: children),
    );
  }
}

enum _RenderMode { sheet, dialog }

/// Shows the active config and [children]. Rebuilds only on config changes.
@immutable
class ConfigSettings extends StatelessWidget {
  const ConfigSettings._({
    required _RenderMode mode,
    super.key,
    this.children,
    this.onClose,
    this.backgroundColor,
  }) : _mode = mode;

  factory ConfigSettings.sheet({
    Key? key,
    VoidCallback? onClose,
    Widget? children,
  }) => ConfigSettings._(
    key: key,
    onClose: onClose,
    mode: _RenderMode.sheet,
    children: children,
  );

  factory ConfigSettings.dialog({
    Key? key,
    VoidCallback? onClose,
    Widget? children,
    Color? backgroundColor,
  }) => ConfigSettings._(
    key: key,
    onClose: onClose,
    mode: _RenderMode.dialog,
    backgroundColor: backgroundColor,
    children: children,
  );

  final Widget? children;
  final VoidCallback? onClose;
  final _RenderMode _mode;

  /// The dialog background. `null` uses the theme color. The sheet background is set by [showAppFuseMenu].
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final body = _SettingsBody(
      mode: _mode,
      onClose: onClose,
      children: children,
    );
    return switch (_mode) {
      _RenderMode.sheet => body,
      _RenderMode.dialog => Dialog(
        backgroundColor: backgroundColor,
        insetPadding: const EdgeInsets.only(top: 35, left: 35, right: 35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: body,
        ),
      ),
    };
  }
}

@immutable
class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.mode, this.onClose, this.children});
  final VoidCallback? onClose;
  final Widget? children;
  final _RenderMode mode;

  @override
  Widget build(BuildContext context) {
    final config = AppFuseScope.watch(context, AppFuseAspect.config).config;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        AppFuseSettingsHeader(onClose: onClose),
        const SizedBox(height: 20),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height - 80,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ?children,
                  if (children != null) const Divider(thickness: 1),
                  if (config is! EmptyConfig)
                    AppFuseSettingTile(
                      icon: Icons.cloud_rounded,
                      label: 'Config',
                      value: config.name,
                      onPressed: () => selectConfigDialog(context),
                    ),
                  const Divider(),
                  SizedBox(
                    height: switch (mode) {
                      _RenderMode.sheet =>
                        MediaQuery.viewPaddingOf(context).bottom + 16,
                      _RenderMode.dialog => 10,
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The title row of [ConfigSettings], with a close button when [onClose] is given.
@immutable
class AppFuseSettingsHeader extends StatelessWidget {
  const AppFuseSettingsHeader({super.key, this.onClose});
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Text(
          'Config Debug',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        if (onClose case final onClose?)
          PositionedDirectional(
            start: 4,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              tooltip: Localizations.of<MaterialLocalizations>(
                context,
                MaterialLocalizations,
              )?.closeButtonTooltip,
            ),
          ),
      ],
    ),
  );
}

/// A tappable row with an [icon], a [label], and its current [value].
@immutable
class AppFuseSettingTile extends StatelessWidget {
  const AppFuseSettingTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
    this.onPressed,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      button: true,
      enabled: onPressed != null,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
