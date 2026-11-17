import 'package:flutter/material.dart';

import 'quiet_palette.dart';

class LSTAppTheme {
  LSTAppTheme._();

  static const amber = Color(0xfff5b840);
  static const amberInk = Color(0xff2b210f);
  static final ThemeData lightTheme = _theme(Brightness.light);
  static final ThemeData darkTheme = _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final canvas = Color(dark ? 0xff17191c : 0xfff7f5f0);
    final surface = Color(dark ? 0xff22252a : 0xffffffff);
    final ink = Color(dark ? 0xfff3f1eb : 0xff23262b);
    final muted = Color(dark ? 0xffb2b5ba : 0xff62666c);
    final line = Color(dark ? 0xff3b4048 : 0xffdddcd7);
    final soft = Color(dark ? 0xff2c3036 : 0xffeeece6);
    final link = Color(dark ? 0xfff2c56a : 0xff835400);
    final scheme =
        ColorScheme.fromSeed(seedColor: amber, brightness: brightness).copyWith(
          primary: link,
          onPrimary: dark ? amberInk : Colors.white,
          primaryContainer: Color(dark ? 0xff4a3b1c : 0xfffff0bd),
          onPrimaryContainer: ink,
          secondary: link,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          surfaceContainer: soft,
          surfaceContainerLow: canvas,
          surfaceContainerHighest: soft,
          surfaceContainerLowest: canvas,
          outline: Color(dark ? 0xff818893 : 0xff898882),
          outlineVariant: line,
          error: Color(dark ? 0xffff9aa8 : 0xffae2939),
          onError: dark ? const Color(0xff4e1620) : Colors.white,
          errorContainer: Color(dark ? 0xff4e1620 : 0xffffe5e9),
          onErrorContainer: Color(dark ? 0xffffd9df : 0xff72192a),
        );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme
        .apply(bodyColor: ink, displayColor: ink)
        .copyWith(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.8,
            color: ink,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -0.6,
            color: ink,
          ),
          titleLarge: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: ink,
          ),
          titleMedium: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: ink,
          ),
          bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
          bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: ink),
          bodySmall: TextStyle(fontSize: 12, height: 1.5, color: muted),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      textTheme: text,
      extensions: [dark ? QuietPalette.dark : QuietPalette.light],
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleMedium,
        iconTheme: IconThemeData(color: ink),
      ),
      iconTheme: IconThemeData(color: ink, size: 22),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: ink,
          highlightColor: scheme.primaryContainer,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: amber,
          foregroundColor: amberInk,
          minimumSize: const Size(48, 48),
          shape: rounded,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: amber,
          foregroundColor: amberInk,
          minimumSize: const Size(48, 48),
          shape: rounded,
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: link,
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
          shape: rounded,
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: soft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: link, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        errorMaxLines: 3,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded,
        textStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: canvas),
        actionTextColor: dark
            ? const Color(0xff835400)
            : const Color(0xfff2c56a),
        behavior: SnackBarBehavior.floating,
        shape: rounded,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: amber,
        foregroundColor: amberInk,
        elevation: 0,
        shape: rounded,
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: link,
        selectionColor: link.withValues(alpha: 0.25),
        selectionHandleColor: link,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: link),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: scheme.primaryContainer,
        labelStyle: text.labelMedium?.copyWith(color: ink),
        checkmarkColor: link,
        side: BorderSide(color: line),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? amber : soft,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? amberInk : muted,
        ),
        trackOutlineColor: WidgetStatePropertyAll(line),
      ),
    );
  }
}
