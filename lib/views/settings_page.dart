import 'package:flutter/material.dart';
import 'package:jot_it/core/constants/colors.dart';
import 'package:jot_it/core/constants/sizes.dart';
import 'package:jot_it/core/utils/size_config.dart';
import 'package:jot_it/features/auth/view_model/auth_viewmodel.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final AuthViewModel authVM = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        leading: IconButton(
          onPressed: (){
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back),
          color: ZColors.white,
        ),
      ),
      body: SizedBox(
          width: SizeConfig.screenWidth, height: SizeConfig.screenHeight,
          child: Column(
            spacing: ZSizes.paddingSpaceMd,
            children: [

              // App lock
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceLg),
                child: GestureDetector(
                  onTap: (){
                    authVM.toggleAppLockChoice(context);
                  },
                  child: Container(
                    height: ZSizes.paddingSpaceXl * 2,
                    decoration: BoxDecoration(
                      color: ZColors.darkGrey,
                      borderRadius: BorderRadius.circular(ZSizes.borderRadiusMd),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceXl),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("App Lock", style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                          ),),
                          Container(
                            decoration: BoxDecoration(
                              color: authVM.isAppLock ? ZColors.success.withAlpha((255 * 0.1).toInt())
                                  : ZColors.error.withAlpha((255 * 0.1).toInt()),
                              borderRadius: BorderRadius.circular(ZSizes.borderRadiusMd)
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceLg,
                              vertical: ZSizes.paddingSpaceSm),
                              child: Row(
                                children: [
                                  Icon(Icons.circle, color: authVM.isAppLock ? ZColors.success
                                      : ZColors.error, size: 12,),
                                  SizedBox(width: ZSizes.paddingSpaceLg,),
                                  Text(authVM.isAppLock ? "Enabled" : "Disabled",
                                    style: TextStyle(
                                    color: authVM.isAppLock ? ZColors.success
                                    : ZColors.error
                                  ),),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Biometric login
              if(authVM.isAppLock)Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceLg),
                child: GestureDetector(
                  onTap: (){
                    authVM.saveBiometricEnabled(!authVM.isBiometricEnabled, context);
                  },
                  child: Container(
                    height: ZSizes.paddingSpaceXl * 2,
                    decoration: BoxDecoration(
                      color: ZColors.darkGrey,
                      borderRadius: BorderRadius.circular(ZSizes.borderRadiusMd),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceXl),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Biometric Login", style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                          ),),
                          Container(
                            decoration: BoxDecoration(
                              color: authVM.isBiometricEnabled ? ZColors.success.withAlpha((255 * 0.1).toInt())
                                  : ZColors.error.withAlpha((255 * 0.1).toInt()),
                              borderRadius: BorderRadius.circular(ZSizes.borderRadiusMd)
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceLg,
                              vertical: ZSizes.paddingSpaceSm),
                              child: Row(
                                children: [
                                  Icon(Icons.circle, color: authVM.isBiometricEnabled ? ZColors.success
                                      : ZColors.error, size: 12,),
                                  SizedBox(width: ZSizes.paddingSpaceLg,),
                                  Text(authVM.isBiometricEnabled ? "Enabled" : "Disabled",
                                    style: TextStyle(
                                    color: authVM.isBiometricEnabled ? ZColors.success
                                    : ZColors.error
                                  ),),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )),
    );
  }
}
