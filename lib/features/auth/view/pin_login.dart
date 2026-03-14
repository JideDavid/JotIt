import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../view_model/auth_viewmodel.dart';

class PinLogin extends StatefulWidget {
  const PinLogin({super.key});

  @override
  State<PinLogin> createState() => _PinLoginState();
}

class _PinLoginState extends State<PinLogin> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthViewModel>().checkBiometricEnabled();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Stone School Bus App text
            const Text(
              "JotIt",
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
                  color: ZColors.grey),
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
                              authVM.unlockWithPin(context, '${index + 1}');
                            } else {
                              authVM.unlockWithPin(context, '0');
                            }
                          },
                          style: const ButtonStyle(
                              backgroundColor:
                                  WidgetStatePropertyAll(ZColors.darkGrey)),
                          child: Text(
                            '${index < 9 ? index + 1 : 0}',
                            style: const TextStyle(
                                fontSize: 30, color: ZColors.lightGrey),
                          ))
                      // Bio ID button
                      : index == 9
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                    style: ButtonStyle(
                                      backgroundColor: const WidgetStatePropertyAll(
                                              ZColors.darkGrey),
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
                                const Text("Bio-ID", style: TextStyle(
                                  color: ZColors.lightGrey
                                ),)
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
