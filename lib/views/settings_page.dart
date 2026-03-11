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
          child: Stack(
            children: [
              Padding(
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
                          Text("Biometric Login"),
                          Text(authVM.isBiometricEnabled ? "enabled" : "disabled",
                            style: TextStyle(
                            color: authVM.isBiometricEnabled ? ZColors.success
                            : ZColors.error
                          ),),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(ZSizes.paddingSpaceLg),
                    child: FilledButton(onPressed: (){
                      authVM.logout(context);
                    },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Text("Logout")],
                        )
                    ),
                  )
                ],
              ),
            ],
          )),
    );
  }
}
