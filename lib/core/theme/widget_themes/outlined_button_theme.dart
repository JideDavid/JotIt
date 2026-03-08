import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/sizes.dart';

/* -- Light & Dark Outlined Button Themes -- */
class TOutlinedButtonTheme {
  TOutlinedButtonTheme._(); //To avoid creating instances


  /* -- Light Theme -- */
  static final lightOutlinedButtonTheme  = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      elevation: 0,
      foregroundColor: ZColors.black,
      side: const BorderSide(color: ZColors.grey),
      textStyle: const TextStyle(fontSize: 16, color: ZColors.black, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(vertical: ZSizes.buttonHeight, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZSizes.buttonRadius)),
    ),
  );

  /* -- Dark Theme -- */
  static final darkOutlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: ZColors.white,
      side: const BorderSide(color: ZColors.grey),
      textStyle: const TextStyle(fontSize: 16, color: ZColors.white, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(vertical: ZSizes.buttonHeight, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZSizes.buttonRadius)),
    ),
  );
}
