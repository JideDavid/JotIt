import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/image_strings.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/utils/size_config.dart';
import '../view_model/auth_viewmodel.dart';

class EnableBiometricPage extends StatelessWidget {
  const EnableBiometricPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthViewModel authVM = context.watch<AuthViewModel>();
    return Scaffold(
      body: Container(
        width: SizeConfig.screenWidth,
        height: SizeConfig.screenHeight,
        decoration: const BoxDecoration(
          color: ZColors.primary2
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Biometric", style: TextStyle(
              fontSize: 40, fontWeight: FontWeight.bold, color: ZColors.white
            ),),
            const SizedBox(height: ZSizes.paddingSpaceXl * 2,),
            Image.asset(ZImages.faceID3, width: SizeConfig.screenWidth * 0.4,),
            const SizedBox(height: ZSizes.paddingSpaceXl,),
            SizedBox( width: SizeConfig.screenWidth * 0.5,
              child: const Text('Enable biometric on your next transaction?',
                style: TextStyle(color: ZColors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: ZSizes.paddingSpaceXl * 2,),
            FilledButton(onPressed: () async{
              authVM.saveBiometricEnabled(!authVM.isBiometricEnabled, context);
              Future.delayed(const Duration(seconds: 1), (){
                // ignore: use_build_context_synchronously
                Navigator.pop(context);
              });
            },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceXl * 2),
                  child: Text(authVM.isBiometricEnabled ? "Disable" : "Enable",
                    style: const TextStyle(fontSize: 20),),
                )),
            const SizedBox(height: ZSizes.paddingSpaceXl,),
            GestureDetector(
              onTap: (){
                Navigator.pop(context);
              },
              child: const Text("Maybe next time", style: TextStyle(
                color: ZColors.white, fontWeight: FontWeight.bold, fontSize: 20
              ),),
            )
          ],
        ),
      ),
    );
  }
}
