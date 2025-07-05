import 'package:flutter/widgets.dart';

/// Bare Minimum [Widget] to be used as a root widget for `runApp()` function
@immutable
class VitalApp extends StatelessWidget {
  /// creates [VitalApp]
  const VitalApp({required this.home, super.key});

  /// [Widget] to be displayed
  final Widget home;

  @override
  Widget build(BuildContext context) => MediaQuery(
        data: MediaQueryData.fromView(View.of(context)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Color(0x00000000),
              fontFamily: 'Roboto',
              fontSize: 14,
            ),
            child: home,
          ),
        ),
      );
}
