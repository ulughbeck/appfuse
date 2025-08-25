import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

void showAppFuseMenu(
  BuildContext context, {
  Widget? children,
  VoidCallback? onClose,
  Color? backgroundColor,
}) {
  if (MediaQuery.of(context).size.width > 750) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (context) => ConfigSettings.dialog(
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      builder: (context) => ConfigSettings.sheet(
        onClose: onClose,
        children: children,
      ),
    );
  }
}

enum RenderMode { sheet, dialog }

@immutable
class ConfigSettings extends StatelessWidget {
  const ConfigSettings._({
    required this.mode,
    super.key,
    this.children,
    this.onClose,
  });

  factory ConfigSettings.sheet({
    Key? key,
    VoidCallback? onClose,
    Widget? children,
  }) =>
      ConfigSettings._(
        key: key,
        onClose: onClose,
        mode: RenderMode.sheet,
        children: children,
      );

  factory ConfigSettings.dialog({
    Key? key,
    VoidCallback? onClose,
    Widget? children,
  }) =>
      ConfigSettings._(
        key: key,
        onClose: onClose,
        mode: RenderMode.dialog,
        children: children,
      );

  final Widget? children;
  final VoidCallback? onClose;
  final RenderMode mode;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppFuseState>(
        valueListenable: context.fuse,
        builder: (context, state, _) {
          if (state.isProcessing) return const _SettingsLoader();

          switch (mode) {
            case RenderMode.sheet:
              return _SettingsBody(
                onClose: onClose,
                fuseState: state,
                mode: mode,
                children: children,
              );

            case RenderMode.dialog:
              return Dialog(
                insetPadding: const EdgeInsets.only(top: 35, left: 35, right: 35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: _SettingsBody(
                    onClose: onClose,
                    fuseState: state,
                    mode: mode,
                    children: children,
                  ),
                ),
              );
          }
        },
      );
}

@immutable
class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.fuseState,
    required this.mode,
    this.onClose,
    this.children,
  });
  final VoidCallback? onClose;
  final Widget? children;
  final AppFuseState fuseState;
  final RenderMode mode;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Header(onClose: onClose),
          const SizedBox(height: 20),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height - 80,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (children != null) ...[
                      children!,
                      const Divider(thickness: 1),
                    ],
                    if (fuseState.config is! EmptyConfig)
                      SettingTile(
                        icon: Icons.cloud_rounded,
                        label: 'Config',
                        value: fuseState.config.name,
                        onPressed: () => selectConfigDialog(context),
                      ),
                    const Divider(),
                    if (mode == RenderMode.sheet) const SizedBox(height: 50) else const SizedBox(height: 10)
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}

@immutable
class Header extends StatelessWidget {
  const Header({
    super.key,
    this.onClose,
  });
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const Align(
            alignment: Alignment.center,
            child: Text(
              'Config Debug',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          if (onClose != null) ...[
            Positioned(
              top: 0,
              left: 10,
              child: InkWell(
                onTap: onClose,
                customBorder: const CircleBorder(),
                child: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ],
      );
}

@immutable
class _SettingsLoader extends StatelessWidget {
  const _SettingsLoader();

  @override
  Widget build(BuildContext context) => const Center(child: Text('...'));
}

@immutable
class SettingTile extends StatelessWidget {
  const SettingTile({
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
  Widget build(BuildContext context) => InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 16,
          ),
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
      );
}
