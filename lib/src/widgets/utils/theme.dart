import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

Future<void> selectThemeDialog(
  BuildContext context, {
  String title = 'Theme',
}) =>
    showDialog<void>(
      useRootNavigator: true,
      barrierColor: Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(124),
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: context.supportedThemes
              .map(
                (theme) => _AppThemeRadioButton(
                  themeMode: theme,
                  onChanged: (locale) {
                    context.changeAppThemeMode(theme);
                    Navigator.of(context).pop();
                  },
                ),
              )
              .toList(),
        ),
      ),
    );

class _AppThemeRadioButton extends StatelessWidget {
  const _AppThemeRadioButton({
    required this.themeMode,
    required this.onChanged,
  });
  final ThemeMode themeMode;
  final void Function(ThemeMode?)? onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(
          themeMode.name,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        leading: Radio<ThemeMode>(
          activeColor: Theme.of(context).colorScheme.primary,
          value: themeMode,
          groupValue: context.currentThemeMode,
          onChanged: onChanged,
        ),
        onTap: () => onChanged?.call(themeMode),
      );
}
