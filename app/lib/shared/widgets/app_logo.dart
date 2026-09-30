import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showTagline;

  /// Full black brand mark with BagMandi text inside the image.
  static const assetPath = 'assets/images/bagmandi_logo.png';

  const AppLogo({
    super.key,
    this.size = 80,
    this.color,
    this.showTagline = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Compact logo for app bars / headers.
class AppLogoMark extends StatelessWidget {
  final double height;

  const AppLogoMark({super.key, this.height = 36});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height * 0.18),
      child: Image.asset(
        AppLogo.assetPath,
        height: height,
        width: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
