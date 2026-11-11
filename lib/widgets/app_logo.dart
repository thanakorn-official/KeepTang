import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  static const backgroundColor = Color(0xFF0A665E);
  static const assetName = 'assets/branding/logo.svg';

  const AppLogo({
    super.key,
    required this.size,
    this.withBackground = false,
    this.semanticLabel,
  });

  final double size;
  final bool withBackground;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final logo = SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );

    return SizedBox.square(
      dimension: size,
      child: withBackground
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(size * 0.24),
              ),
              child: Padding(
                padding: EdgeInsets.all(size * 0.14),
                child: logo,
              ),
            )
          : logo,
    );
  }
}
