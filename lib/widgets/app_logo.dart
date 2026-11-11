import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  static const backgroundColor = Color(0xFF0A665E);
  static const ringAssetName = 'assets/branding/loading_rings.svg';
  static const receiptAssetName = 'assets/branding/loading_receipt.svg';

  const AppLogo({
    super.key,
    required this.size,
    this.semanticLabel,
  });

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          SvgPicture.asset(
            ringAssetName,
            width: size,
            height: size,
            excludeFromSemantics: true,
          ),
          SvgPicture.asset(
            receiptAssetName,
            width: size,
            height: size,
            colorFilter: ColorFilter.mode(
              Theme.of(context).colorScheme.onSurface,
              BlendMode.srcIn,
            ),
            semanticsLabel: semanticLabel,
            excludeFromSemantics: semanticLabel == null,
          ),
        ],
      ),
    );
  }
}
