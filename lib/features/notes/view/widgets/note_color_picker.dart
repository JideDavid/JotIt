import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/quiet_palette.dart';
import '../../model/note_card_color.dart';
import '../../view-model/note_view_model.dart';

Future<int?> showNoteColorPicker(BuildContext context, NoteViewModel notes) =>
    showDialog<int>(
      context: context,
      useRootNavigator: false,
      builder: (_) => _NoteColorPicker(notes: notes),
    );

class _NoteColorPicker extends StatefulWidget {
  const _NoteColorPicker({required this.notes});
  final NoteViewModel notes;

  @override
  State<_NoteColorPicker> createState() => _NoteColorPickerState();
}

class _NoteColorPickerState extends State<_NoteColorPicker> {
  late int _selection = widget.notes.selectedColor;
  late HSVColor _hsv = HSVColor.fromColor(Color(_actualColor));
  late final _hex = TextEditingController(
    text: NoteCardColor.hex(_actualColor),
  );
  bool _saving = false;
  String? _error;
  bool _valid = true;

  int get _actualColor => NoteCardColor.isCustom(_selection)
      ? _selection
      : QuietPalette.light.markers[_selection].toARGB32();

  void _select(int color) {
    setState(() {
      _selection = color;
      _hsv = HSVColor.fromColor(Color(_actualColor));
      _hex.text = NoteCardColor.hex(_actualColor);
      _valid = true;
      _error = null;
    });
  }

  void _adjust(HSVColor color) => _select(color.toColor().toARGB32());

  Future<void> _favorite() async {
    if (!widget.notes.favoriteColors.contains(_actualColor) &&
        widget.notes.favoriteColors.length >= NoteCardColor.maxFavorites) {
      setState(
        () => _error = 'You have 24 favorites. Remove one to save another.',
      );
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.notes.toggleFavoriteColor(_actualColor);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = saved ? null : 'Could not save favorites. Please try again.';
    });
  }

  Widget _swatch(int color, String label) => Semantics(
    selected: _selection == color,
    child: Tooltip(
      message: label,
      child: OutlinedButton(
        onPressed: _saving ? null : () => _select(color),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          fixedSize: const Size(48, 48),
          side: BorderSide(
            color: _selection == color
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: _selection == color ? 2 : 1,
          ),
        ),
        child: Semantics(
          label: label,
          child: ExcludeSemantics(
            child: Icon(
              _selection == color ? Icons.check_circle : Icons.circle,
              color: QuietPalette.of(context).cardMarker(color),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = QuietPalette.of(context);
    final favorite = widget.notes.favoriteColors.contains(_actualColor);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: const Text('Note card color'),
        content: SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose a tint for this note in your library.'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.cardSurface(_selection),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 12,
                      color: palette.cardMarker(_selection),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Note card preview')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Presets', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (
                    var index = 0;
                    index < NoteCardColor.presetCount;
                    index++
                  )
                    _swatch(index, 'Color ${index + 1}'),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Custom color',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = math.min(220.0, constraints.maxWidth);
                    void choose(Offset offset) {
                      final relative = offset - Offset(side / 2, side / 2);
                      final hue =
                          (math.atan2(relative.dy, relative.dx) *
                                  180 /
                                  math.pi +
                              360) %
                          360;
                      _adjust(
                        _hsv
                            .withHue(hue)
                            .withSaturation(
                              (relative.distance / (side / 2)).clamp(0, 1),
                            ),
                      );
                    }

                    return Center(
                      child: Semantics(
                        label:
                            'Color wheel. Hue and saturation sliders are below.',
                        child: GestureDetector(
                          key: const ValueKey('note-color-wheel'),
                          onPanDown: _saving
                              ? null
                              : (details) => choose(details.localPosition),
                          onPanUpdate: _saving
                              ? null
                              : (details) => choose(details.localPosition),
                          child: CustomPaint(
                            size: Size.square(side),
                            painter: _ColorWheel(_hsv),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _slider(
                'Brightness',
                _hsv.value,
                (value) => _adjust(_hsv.withValue(value)),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Precise controls'),
                children: [
                  _slider(
                    'Hue',
                    _hsv.hue / 360,
                    (value) => _adjust(_hsv.withHue(value * 359.99)),
                  ),
                  _slider(
                    'Saturation',
                    _hsv.saturation,
                    (value) => _adjust(_hsv.withSaturation(value)),
                  ),
                ],
              ),
              TextField(
                controller: _hex,
                enabled: !_saving,
                maxLength: 7,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Hex color',
                  helperText: 'Six hex digits, for example #38764C',
                  helperMaxLines: 3,
                  errorMaxLines: 3,
                  errorText: _valid ? null : 'Enter six hex digits.',
                ),
                onChanged: (value) {
                  final parsed = NoteCardColor.parseHex(value);
                  setState(() {
                    _valid = parsed != null;
                    if (parsed != null) {
                      _selection = parsed;
                      _hsv = HSVColor.fromColor(Color(parsed));
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              Text('Favorites', style: Theme.of(context).textTheme.titleSmall),
              if (widget.notes.favoriteColors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final color in widget.notes.favoriteColors)
                        _swatch(color, 'Favorite ${NoteCardColor.hex(color)}'),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _saving || !_valid ? null : _favorite,
                icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
                label: Text(
                  _saving
                      ? 'Saving…'
                      : favorite
                      ? 'Remove favorite'
                      : 'Save favorite',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Favorites are saved on this device. Apply a color, then save the note to keep its tint.',
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving || !_valid
                ? null
                : () => Navigator.pop(context, _selection),
            child: const Text('Apply color'),
          ),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          Semantics(
            label: label,
            child: Slider(
              value: value,
              semanticFormatterCallback: (value) =>
                  '${(value * 100).round()} percent',
              onChanged: _saving ? null : onChanged,
            ),
          ),
        ],
      );

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }
}

class _ColorWheel extends CustomPainter {
  _ColorWheel(this.color);
  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Offset.zero & size;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = SweepGradient(
          colors: [
            for (var hue = 0; hue <= 360; hue += 60)
              HSVColor.fromAHSV(1, hue.toDouble(), 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Colors.transparent],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.black.withValues(alpha: 1 - color.value),
    );
    final angle = color.hue * math.pi / 180;
    final marker =
        center +
        Offset(math.cos(angle), math.sin(angle)) *
            color.saturation *
            (radius - 4);
    canvas.drawCircle(marker, 7, Paint()..color = Colors.black);
    canvas.drawCircle(marker, 5, Paint()..color = Colors.white);
    canvas.drawCircle(marker, 3, Paint()..color = color.toColor());
  }

  @override
  bool shouldRepaint(_ColorWheel oldDelegate) => color != oldDelegate.color;
}
