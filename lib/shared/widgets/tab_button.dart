import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/sizes.dart';
import '../../core/utils/l_printer.dart';

class TabButton extends StatefulWidget {
  final String title;
  final int buttonIndex;
  final int activeIndex;
  final void Function(int) setIndex;
  const TabButton({super.key,required this.title, required this.buttonIndex, required this.activeIndex, required this.setIndex });

  @override
  State<TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<TabButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (){
        widget.setIndex(widget.buttonIndex);
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.buttonIndex == widget.activeIndex
              ? ZColors.primaryLight.withAlpha(100)
              : ZColors.transparent,
          borderRadius:
          BorderRadius.circular(ZSizes.borderRadiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ZSizes.paddingSpaceLg,
            vertical: ZSizes.paddingSpaceSm,
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 16,
              color: widget.buttonIndex == widget.activeIndex
                  ? ZColors.primary
                  : ZColors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
