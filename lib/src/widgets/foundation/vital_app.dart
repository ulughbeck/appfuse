import 'package:flutter/material.dart';

/// Bare minimum [Widget] for the placeholder and error screens.
///
/// It has a [Theme], a background, and a default text style, but no
/// `MaterialApp` and no `Navigator`.
@immutable
class VitalApp extends StatelessWidget {
  /// creates [VitalApp]
  const VitalApp({required this.home, required this.theme, super.key});

  /// [Widget] to be displayed
  final Widget home;

  /// The theme for [home]. Its colors and body text style apply.
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Theme(
      data: theme,
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: DefaultTextStyle(
          style: theme.textTheme.bodyMedium ?? const TextStyle(),
          child: home,
        ),
      ),
    ),
  );
}
