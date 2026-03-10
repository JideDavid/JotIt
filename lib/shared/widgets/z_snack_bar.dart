import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/sizes.dart';

class ZSnackBar{

 void success(BuildContext context, String successMessage){
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
       behavior: SnackBarBehavior.floating,
       margin: const EdgeInsets.all(ZSizes.paddingSpaceLg),
       content: Row(
         children: [
           const Icon(Icons.check_circle_outline, color: ZColors.white,),
           const SizedBox(width: ZSizes.paddingSpaceLg,),
           Text(successMessage, style: const TextStyle(color: ZColors.white),),
         ],
       ),
       backgroundColor: ZColors.primaryDark,
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(ZSizes.borderRadiusLg),
       ),
     ),
   );
 }

 void error(BuildContext context, String errorMessage){
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
       behavior: SnackBarBehavior.floating,
       margin: const EdgeInsets.all(ZSizes.paddingSpaceLg),
       content: Row(
         children: [
           const Icon(Icons.check_circle_outline, color: ZColors.white,),
           const SizedBox(width: ZSizes.paddingSpaceLg,),
           Text(errorMessage, style: const TextStyle(color: ZColors.white),),
         ],
       ),
       backgroundColor: ZColors.error,
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(ZSizes.borderRadiusLg),
       ),
     ),
   );
 }
}