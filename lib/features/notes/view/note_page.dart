import 'package:flutter/material.dart';
import 'package:jot_it/core/utils/l_printer.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/utils/size_config.dart';
import '../../../shared/widgets/z_icon_button.dart';
import '../view-model/note_view_model.dart';

class NotePage extends StatefulWidget {
  const NotePage({super.key,});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {

  void handlePagePop(BuildContext context) async {

    // Pop if title and body are empty
    if (Provider.of<NoteViewModel>(
          context,
          listen: false,
        ).titleController.text.isEmpty &&
        Provider.of<NoteViewModel>(
          context,
          listen: false,
        ).bodyController.text.isEmpty) {
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      ZPrint("Title and body is empty");
      return;
    }

    // Pop if note is updated
    if(Provider.of<NoteViewModel>(context, listen: false).isUpdated()){
      ZPrint("Note is updated");
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, color: ZColors.warning, size: 40),
              SizedBox(height: ZSizes.paddingSpaceMd),
              const Text("Same changes ?"),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Discard"),
            ),
            TextButton(
              onPressed: (){
                Provider.of<NoteViewModel>(context, listen: false).saveNote();
                Navigator.pop(context, true);},
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (shouldLeave ?? false) {
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    NoteViewModel noteVM = context.watch<NoteViewModel>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        handlePagePop(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: SizedBox(
            width: SizeConfig.screenWidth,
            height: SizeConfig.screenHeight,
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZSizes.paddingSpaceLg,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ZIconButton(
                        icon: Icons.arrow_back,
                        action: () {
                          handlePagePop(context);
                        },
                      ),

                      Row(
                        children: [
                          ZIconButton(icon: Icons.save, action: () {
                            noteVM.saveNote();
                          }),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: ZSizes.paddingSpaceLg),

                // Color Picker
                SizedBox(
              width: SizeConfig.screenWidth,
              height: SizeConfig.screenHeight * 0.1,
              child: ListView.builder(
                  scrollDirection: Axis.horizontal, itemCount: noteVM.colors.length, itemBuilder: (context, index){
                return GestureDetector(
                  onTap: (){
                    noteVM.selectColor(index);
                  },
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceMd),
                      child: Icon(Icons.circle, color: noteVM.colors[index],size: noteVM.selectedColor == index ? 50 : 30,)
                  ),
                );}),
            ),

                SizedBox(height: ZSizes.paddingSpaceLg),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZSizes.paddingSpaceLg,
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: SizeConfig.screenHeight * 0.1,
                      maxHeight: SizeConfig.screenHeight * 0.2,
                    ),
                    child: TextField(
                      controller: noteVM.titleController,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: TextStyle(fontSize: 25, color: ZColors.grey),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                // SizedBox(height: ZSizes.paddingSpaceLg,),

                // body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZSizes.paddingSpaceLg,
                    ),
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: SizeConfig.screenHeight * 0.1,
                      ),
                      child: TextField(
                        controller: noteVM.bodyController,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.normal,
                        ),
                        maxLines: null,
                        minLines: null,
                        expands: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Type Something...',
                          hintStyle: TextStyle(
                            fontSize: 18,
                            color: ZColors.grey,
                          ),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


