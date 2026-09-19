import 'dart:io';
import 'package:image/image.dart';
import 'package:path/path.dart' as p;

void main() {
  final root = Directory.current.path;
  final candidates = [
    p.join(root, 'assets/brand/logo-64x64.png'),
    p.join(root, 'assets/brand/logo.png'),
  ];
  late File src;
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      src = file;
      break;
    }
  }
  final decoded = decodeImage(src.readAsBytesSync());
  if (decoded == null) throw StateError('decode failed');
  final resized = copyResize(decoded, width: 22, height: 22, interpolation: Interpolation.average);
  final template = Image(width: 22, height: 22, numChannels: 4);
  for (final pixel in resized) {
    template.setPixelRgba(pixel.x, pixel.y, 0, 0, 0, pixel.a.toInt());
  }
  final out = File(p.join(root, 'assets/brand/tray_icon_template.png'));
  out.writeAsBytesSync(encodePng(template));
  stdout.writeln('wrote ${out.path}');
}
