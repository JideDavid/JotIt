import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../constants/sizes.dart';

class TTextFormFieldTheme {
  TTextFormFieldTheme._();

  static InputDecorationTheme lightInputDecorationTheme = InputDecorationTheme(
    errorMaxLines: 3,
    prefixIconColor: ZColors.darkGrey,
    suffixIconColor: ZColors.darkGrey,
    isDense: true,
    filled: true,
    fillColor: ZColors.darkGrey.withAlpha((255 * 0.1).toInt()),
    // constraints: const BoxConstraints.expand(height: LSTSizes.inputFieldHeight),
    labelStyle: const TextStyle().copyWith(fontSize: ZSizes.fontSizeMd, color: ZColors.black),
    hintStyle: const TextStyle().copyWith(fontSize: ZSizes.fontSizeSm, color: Colors.black45),
    errorStyle: const TextStyle().copyWith(fontStyle: FontStyle.normal),
    floatingLabelStyle: const TextStyle().copyWith(color: ZColors.black.withAlpha((255 * 0.8).toInt())),
    border: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(ZSizes.inputFieldRadius),
      borderSide: const BorderSide(width: 0, color: ZColors.transparent),
    ),
    enabledBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(ZSizes.inputFieldRadius),
      borderSide: const BorderSide(width: 1, color: Colors.transparent),
    ),
    focusedBorder:const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(ZSizes.inputFieldRadius),
      borderSide: const BorderSide(width: 1, color: ZColors.primary),
    ),
    errorBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(ZSizes.inputFieldRadius),
      borderSide: const BorderSide(width: 1, color: ZColors.warning),
    ),
    focusedErrorBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(ZSizes.inputFieldRadius),
      borderSide: const BorderSide(width: 2, color: ZColors.warning),
    ),
  );

  static InputDecorationTheme darkInputDecorationTheme = InputDecorationTheme(
    errorMaxLines: 2,
    prefixIconColor: ZColors.darkGrey,
    suffixIconColor: ZColors.darkGrey,
    isDense: true,
    filled: true,
    // constraints: const BoxConstraints.expand(height: LSTSizes.inputFieldHeight),
    labelStyle: const TextStyle().copyWith(fontSize: ZSizes.fontSizeMd, color: ZColors.white),
    hintStyle: const TextStyle().copyWith(fontSize: ZSizes.fontSizeSm, color: ZColors.grey.withAlpha((255 * 0.3).toInt())),
    floatingLabelStyle: const TextStyle().copyWith(color: ZColors.darkerGrey),
    fillColor: ZColors.darkerGrey.withAlpha((255 * 0.2).toInt()),
    border: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(ZSizes.inputFieldRadius),
      borderSide: const BorderSide(width: 1, color: ZColors.lightGrey),
    ),
    enabledBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(ZSizes.inputFieldRadius),
      borderSide: const BorderSide(width: 1, color: ZColors.lightGrey),
    ),
    focusedBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(ZSizes.inputFieldRadius),
      borderSide: const BorderSide(width: 1, color: ZColors.primary),
    ),
    errorBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(ZSizes.inputFieldRadius),
      borderSide: const BorderSide(width: 1, color: ZColors.warning),
    ),
    focusedErrorBorder: const OutlineInputBorder().copyWith(
      borderRadius: BorderRadius.circular(ZSizes.inputFieldRadius),
      borderSide: const BorderSide(width: 2, color: ZColors.warning),
    ),
  );
}
