import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

Future<void> selectLocaleDialog(
  BuildContext context, {
  String title = 'Language',
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
          children: context.supportedLanguages.keys
              .map(
                (locale) => _AppLocaleRadioButton(
                  title: context.supportedLanguages[locale]!,
                  value: locale,
                  onChanged: (locale) {
                    context.changeAppLocale(locale!);
                    Navigator.of(context).pop();
                  },
                ),
              )
              .toList(),
        ),
      ),
    );

class _AppLocaleRadioButton extends StatelessWidget {
  const _AppLocaleRadioButton({
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final Locale value;
  final void Function(Locale?)? onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        leading: Radio<Locale>(
          activeColor: Theme.of(context).colorScheme.primary,
          value: value,
          groupValue: context.currentLocale,
          onChanged: onChanged,
        ),
        onTap: () => onChanged?.call(value),
      );
}
