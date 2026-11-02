import 'package:flutter/widgets.dart';

/// Shows the active config name in the top-start corner.
///
/// Without [onPressed] and [onLongPressed], taps pass through to the app.
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
  Widget build(BuildContext context) {
    final banner = SizedBox(
      height: 50,
      width: 50,
      child: Banner(
        location: BannerLocation.topStart,
        color: color,
        message: name,
        textDirection: Directionality.of(context),
        layoutDirection: Directionality.of(context),
      ),
    );
    if (onPressed == null && onLongPressed == null)
      return IgnorePointer(child: banner);
    return GestureDetector(
      onTap: onPressed,
      onLongPress: onLongPressed,
      child: banner,
    );
  }
}
