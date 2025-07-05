import 'package:flutter/widgets.dart';

@immutable
class ConfigBanner extends StatelessWidget {
  const ConfigBanner({
    required this.name,
    required this.color,
    super.key,
    this.onPressed,
    this.onLongPressed,
  });
  final String name;
  final Color color;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: onLongPressed,
        onTap: onPressed,
        child: SizedBox(
          height: 50,
          width: 50,
          child: Banner(
            location: BannerLocation.topStart,
            color: color,
            message: name,
            textDirection: Directionality.of(context),
            layoutDirection: Directionality.of(context),
          ),
        ),
      );
}
