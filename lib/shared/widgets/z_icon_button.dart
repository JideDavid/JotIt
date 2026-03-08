import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/sizes.dart';

class ZIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback action;
  const ZIconButton({super.key, required this.icon, required this.action});

  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: action,
        color: ZColors.grey.withAlpha((255 * 0.5).toInt()),
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(ZColors.grey.withAlpha((255 * 0.4).toInt())),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZSizes.borderRadiusMd))),
        ),
        icon: Icon(icon, color: ZColors.white, size: 30,));
  }
}
