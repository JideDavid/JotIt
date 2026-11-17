import 'dart:typed_data';
import 'dart:ui' as ui;

Future<Uint8List> samplePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 2, 2),
    ui.Paint()..color = const ui.Color(0xff38764c),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image.dispose();
    picture.dispose();
  }
}
