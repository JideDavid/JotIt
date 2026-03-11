import 'package:flutter/material.dart';
import 'package:jot_it/core/constants/image_strings.dart';
import 'package:jot_it/core/utils/size_config.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/utils/l_printer.dart';
import '../../../shared/widgets/z_icon_button.dart';
import '../../../views/settings_page.dart';
import '../view-model/note_view_model.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

int? selectedIndex;

class _HomepageState extends State<Homepage> {

  @override
  void initState() {
    super.initState();
    // post frame callback
    WidgetsBinding.instance.addPostFrameCallback((_){
      context.read<NoteViewModel>().getNotesFromLocalStorage();
    });
  }
  @override
  Widget build(BuildContext context) {
    final noteVM = context.watch<NoteViewModel>();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: (){
          noteVM.openNote(context, null);
        },
        backgroundColor: ZColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZSizes.borderRadiusLg)),
      child: Icon(Icons.add, color: ZColors.white),),
      body: SafeArea(
        child: SizedBox(
          width: SizeConfig.screenWidth,
          height: SizeConfig.screenHeight,
          child: Column(
            children: [
              // App bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceLg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text("Notes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40, color: ZColors.white),),
                    // leading icons
                    Row(
                      children: [
                        // search
                        ZIconButton(icon: Icons.search, action: (){
                          ZPrint('search');
                        }),
                        SizedBox(width: ZSizes.paddingSpaceMd,),
                        // info
                        ZIconButton(icon: Icons.settings, action: (){
                          Navigator.push(context, MaterialPageRoute(builder: (context)=> const SettingsPage()));
                        }),
                      ],
                    )
                  ],
                ),
              ),

              // Body

              // Empty list
              noteVM.allNotes.isEmpty ? Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(ZImages.emptyList),
                  SizedBox(height: ZSizes.paddingSpaceMd,),
                  Text('Create your first note !', style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ZColors.white, fontSize: 20
                  ),),
                ],
              ))

              // Note list
              : Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: ZSizes.paddingSpaceMd),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ...List.generate(noteVM.allNotes.length, (index) {
                          final note = noteVM.allNotes[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceLg, vertical: ZSizes.paddingSpaceSm),
                            child: GestureDetector(
                              onTap: (){
                                noteVM.openNote(context, note);
                              },
                              onLongPress: (){
                                setState(() {
                                  selectedIndex = index;
                                });
                              },
                              child: Container(
                                constraints: BoxConstraints(
                                  minHeight: SizeConfig.screenHeight * 0.1,
                                ),
                                width: SizeConfig.screenWidth,
                                decoration: BoxDecoration(
                                  color: selectedIndex == index ? ZColors.error : noteVM.colors[note.color],
                                  borderRadius: BorderRadius.circular(ZSizes.borderRadiusMd),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: ZSizes.paddingSpaceLg, vertical: ZSizes.paddingSpaceMd),
                                  child: selectedIndex == index
                                  ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ZIconButton(icon: Icons.delete, action: (){
                                        noteVM.deleteNote(noteVM.allNotes[index].id);
                                        setState(() {
                                          selectedIndex = null;
                                        });
                                      }),
                                      SizedBox(width: ZSizes.paddingSpaceMd,),
                                      ZIconButton(icon: Icons.cancel, action: (){
                                        setState(() {
                                          selectedIndex = null;
                                        });
                                      })
                                    ])

                                  : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(note.title.isEmpty ? note.body : note.title,
                                          style: TextStyle(fontSize: 20),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        })
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
