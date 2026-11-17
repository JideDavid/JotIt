import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NoteFont {
  const NoteFont(this.family, this.category, this.description, this.sourceSlug);

  final String family;
  final String category;
  final String description;
  final String sourceSlug;
}

class NoteFonts {
  NoteFonts._();

  static const families = [
    NoteFont(
      'Anton',
      'Display',
      'Tall, bold, and made for a statement',
      'anton',
    ),
    NoteFont(
      'Archivo Black',
      'Display',
      'Chunky lettering with a strong presence',
      'archivoblack',
    ),
    NoteFont(
      'Bungee',
      'Display',
      'Playful poster lettering with big energy',
      'bungee',
    ),
    NoteFont(
      'Righteous',
      'Display',
      'Rounded retro curves with personality',
      'righteous',
    ),
    NoteFont(
      'Space Grotesk',
      'Sans serif',
      'Geometric shapes with a modern edge',
      'spacegrotesk',
    ),
    NoteFont(
      'DM Sans',
      'Sans serif',
      'Clean, warm, and easy to read',
      'dmsans',
    ),
    NoteFont(
      'DM Serif Display',
      'Serif',
      'Sculpted serifs with editorial flair',
      'dmserifdisplay',
    ),
    NoteFont(
      'Playfair Display',
      'Serif',
      'Elegant contrast for expressive words',
      'playfairdisplay',
    ),
    NoteFont(
      'Lobster',
      'Handwriting',
      'Flowing script with a vintage feel',
      'lobster',
    ),
    NoteFont(
      'Caveat',
      'Handwriting',
      'Loose handwritten notes and little asides',
      'caveat',
    ),
  ];

  static bool _licensesRegistered = false;

  static void registerLicenses() {
    if (_licensesRegistered) return;
    _licensesRegistered = true;
    LicenseRegistry.addLicense(() async* {
      for (final font in families) {
        yield LicenseEntryWithLineBreaks(
          ['${font.family} (Google Fonts)'],
          await rootBundle.loadString(
            'assets/fonts/licenses/${font.sourceSlug}-OFL.txt',
          ),
        );
      }
    });
  }
}
