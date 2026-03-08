import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/sizes.dart';

/* -- Light & Dark Elevated Button Themes -- */
class TFilledButtonTheme {
  TFilledButtonTheme._(); //To avoid creating instances


  /* -- Light Theme -- */
  static final lightFilledButtonTheme  = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      alignment: Alignment.center,
      elevation: 0,
      foregroundColor: ZColors.white,
      backgroundColor: ZColors.primary,
      surfaceTintColor: ZColors.primary,
      disabledForegroundColor: ZColors.white,
      disabledBackgroundColor: ZColors.buttonDisabled,
      side: BorderSide(color: ZColors.grey.withAlpha(0), width:1),
      minimumSize: const Size(double.minPositive, 47),
      padding: const EdgeInsets.symmetric(vertical: 5),
      textStyle: const TextStyle(fontSize: 16, color: ZColors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZSizes.buttonRadius)),
    ),
  );

  /* -- Dark Theme -- */
  static final darkFilledButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      alignment: Alignment.center,
      elevation: 0,
      foregroundColor: ZColors.black,
      backgroundColor: ZColors.primary,
      surfaceTintColor: ZColors.primary,
      disabledForegroundColor: ZColors.black,
      disabledBackgroundColor: ZColors.buttonDisabledDark,
      side: BorderSide(color: ZColors.primary.withAlpha(0), width: 0),
      minimumSize: const Size(double.minPositive, 47),
      padding: const EdgeInsets.symmetric(vertical: 5),
      textStyle: const TextStyle(fontSize: 16, color: ZColors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZSizes.buttonRadius)),
    ),
  );
}
