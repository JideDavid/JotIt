import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../view_model/auth_viewmodel.dart';

class PinLogin extends StatelessWidget {
  const PinLogin({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    Future.delayed(const Duration(seconds: 1), ()=>authVM.checkBiometricEnabled());
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: ZColors.lightScaffoldBackground,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Stone School Bus App text
            const Text(
              "Stone School Bus App",
              style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  color: ZColors.primary),
            ),

            const SizedBox(
              height: ZSizes.paddingSpaceXl,
            ),

            // Enter security Pin text
            const Text(
              "ENTER SECURITY PIN",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: ZColors.black),
            ),

            const SizedBox(
              height: ZSizes.paddingSpaceXl,
            ),

            // input count feedback
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.circle,
                    size: 20,
                    color: authVM.pin.length >= index + 1
                        ? ZColors.primary
                        : ZColors.grey,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: ZSizes.paddingSpaceXl,
            ),

            // input buttons
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 300, // 👈 minimum height
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: ZSizes.paddingSpaceLg * 3,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 25,
                  mainAxisSpacing: 25,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  return index < 9 || index == 10
                      // Number button
                      ? TextButton(
                          onPressed: () {
                            if (index < 9) {
                              authVM.loginWithPin(context, '${index + 1}');
                            } else {
                              authVM.loginWithPin(context, '0');
                            }
                          },
                          style: const ButtonStyle(
                              backgroundColor:
                                  WidgetStatePropertyAll(ZColors.white)),
                          child: Text(
                            '${index < 9 ? index + 1 : 0}',
                            style: const TextStyle(
                                fontSize: 30, color: ZColors.grey),
                          ))
                      // Bio ID button
                      : index == 9
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                    style: ButtonStyle(
                                      backgroundColor: authVM.isBiometricEnabled
                                          ? const WidgetStatePropertyAll(
                                          ZColors.primaryLight)
                                          : const WidgetStatePropertyAll(
                                          ZColors.lighterGrey),
                                    ),
                                    onPressed: !authVM.isBiometricEnabled
                                        ? null
                                        : (){
                                            authVM.loginWithBiometrics(context);
                                          },
                                    icon: Icon(
                                      Icons.fingerprint,
                                      color: authVM.isBiometricEnabled
                                          ? ZColors.primary
                                          : ZColors.grey,
                                      size: 40,
                                    )),
                                const Text("Bio-ID")
                              ],
                            )
                          // Backspace button
                          : IconButton(
                              onPressed: () {
                                authVM.backspacePin();
                              },
                              icon: const Icon(Icons.backspace));
                },
              ),
            ),

            const SizedBox(
              height: ZSizes.paddingSpaceXl,
            ),

            // forgot pin text
            const Text(
              "Forgot Your PIN Code?",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ZColors.grey),
            )
          ],
        ),
      ),
    );
  }
}
