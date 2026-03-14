import 'package:flutter/material.dart';
import 'package:jot_it/core/utils/l_printer.dart';
import 'package:jot_it/core/utils/size_config.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/sizes.dart';
import '../../features/auth/view_model/auth_viewmodel.dart';

class PinInputModal {
  static Future<bool> setPin(BuildContext context) async{
    bool resp = false;
    String pin1 = "";
    String pin2 = "";
    bool showMatched = false;
    bool isActive = true;

    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (context){

      return StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setState) {

          refreshScreen(){
            if(isActive) {
              setState(() {});
            }
          }

          Future<void> setShowMatched() async {
            showMatched = true;
            setState(() {});

            await Future.delayed(const Duration(seconds: 2), (){});

            showMatched = false;
            refreshScreen();
          }

          handlePinInput(String input) async{
            if (pin1.length < 4){
              pin1 += input;
              refreshScreen();
            }
            else if (pin2.length < 4){
                pin2 += input;
                refreshScreen();
            }
            if(pin2.length == 4){
              if (pin1 == pin2) {
                final authVM = context.read<AuthViewModel>();
                await authVM.saveAppLockPin(pin1);
                resp = true;
                await setShowMatched();
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop();
              } else {
                await setShowMatched();
                pin1 = "";
                pin2 = "";
              }
            }
            ZPrint("$pin1, $pin2");
          }
          void backspacePin(){
            if (pin2.isNotEmpty){
              pin2 = pin2.substring(0, pin2.length - 1);
              refreshScreen();
            }else if (pin1.isNotEmpty){
              pin1 = pin1.substring(0, pin1.length - 1);
              refreshScreen();
            }
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Enter security Pin text
              Text(
                pin1.length < 4 ? "SET A SECURITY PIN" : "CONFIRM YOUR PIN",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: ZColors.grey),
              ),

              const SizedBox(
                height: ZSizes.paddingSpaceXl,
              ),

              // input count feedback
              if (pin1.length < 4 ) Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                      (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.circle,
                      size: 20,
                      color: pin1.length >= index + 1
                          ? ZColors.primary
                          : ZColors.grey,
                    ),
                  ),
                ),
              ),
              if (pin1.length == 4 && !showMatched) Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                      (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.circle,
                      size: 20,
                      color: pin2.length >= index + 1
                          ? ZColors.primary
                          : ZColors.grey,
                    ),
                  ),
                ),
              ),

              if(showMatched)Container(
                decoration: BoxDecoration(
                  color: resp ? ZColors.success.withAlpha((255 * 0.1).toInt())
                      : ZColors.error.withAlpha((255 * 0.1).toInt()),
                  borderRadius: BorderRadius.circular(ZSizes.borderRadiusMd),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceXl,
                    vertical: ZSizes.paddingSpaceMd
                  ),
                  child: Text(
                    resp ? "Pin matched" : "Pin does not match", style: TextStyle(
                    color: resp ? ZColors.success : ZColors.error
                  ),),
                ),
              ),

              const SizedBox(
                height: ZSizes.paddingSpaceXl,
              ),

              // input buttons
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 300,
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
                            handlePinInput('${index + 1}');
                          } else {
                            handlePinInput('0');
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
                        ? Visibility(
                      visible: false,
                          child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                          IconButton(
                              style: ButtonStyle(
                                backgroundColor: const WidgetStatePropertyAll(
                                    ZColors.darkGrey),
                              ),
                              onPressed: null,
                              icon: Icon(
                                Icons.fingerprint,
                                color: ZColors.grey,
                                size: 40,
                              )),
                          const Text("Bio-ID", style: TextStyle(
                              color: ZColors.lightGrey
                          ),)
                                                ],
                                              ),
                        )
                    // Backspace button
                        : IconButton(
                        onPressed: () {
                          backspacePin();
                        },
                        icon: const Icon(Icons.backspace));
                  },
                ),
              ),

              const SizedBox(
                height: ZSizes.paddingSpaceXl,
              ),
            ],
          );
        },
      );
    }).whenComplete(() => isActive = false);
    return resp;
  }

  static Future<bool> removePin(BuildContext context) async{
    bool resp = false;

    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        constraints: BoxConstraints(
          maxHeight: SizeConfig.screenHeight * 0.35,
        ),
        builder: (context){

          return StatefulBuilder(
            builder: (BuildContext context, void Function(void Function()) setState) {

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  // Enter security Pin text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceXl),
                    child: Text(
                      "Are you sure you want to disable App Lock?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 25,
                          color: ZColors.lightGrey),
                    ),
                  ),

                  const SizedBox(
                    height: ZSizes.paddingSpaceXl,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceXl),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: ZSizes.paddingSpaceXl,
                      children: [
                        FilledButton(
                            onPressed: (){
                              Navigator.of(context).pop();
                            },
                            style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(ZColors.error)
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceXl),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Text("Cancel", style: TextStyle(
                                fontSize: 20
                              )),
                            ],
                          ),
                        )),
                        FilledButton(onPressed: (){
                          resp = true;
                          Navigator.of(context).pop();
                        }, child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceXl),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Text("Confirm", style: TextStyle(
                                fontSize: 20
                              )),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: ZSizes.paddingSpaceXl,
                  ),
                ],
              );
            },
          );
        });
    return resp;
  }

}