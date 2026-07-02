import 'dart:io';
import 'package:image/image.dart' as img;

img.Image roundedBg(int size, img.ColorRgba8 color, double radiusFrac) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
  img.fillRect(
    image,
    x1: 0,
    y1: 0,
    x2: size - 1,
    y2: size - 1,
    color: color,
    radius: size * radiusFrac,
  );
  return image;
}

void save(img.Image image, String name) {
  final large = img.copyResize(image, width: 1024, height: 1024, interpolation: img.Interpolation.cubic);
  final outFile = File('D:/Projects/DV1520/app/assets/icon/previews/$name.png');
  outFile.createSync(recursive: true);
  outFile.writeAsBytesSync(img.encodePng(large));
  print('Wrote $name');
}

void main() {
  const size = 256;
  final blue = img.ColorRgba8(0x00, 0x93, 0xC7, 255);
  final white = img.ColorRgba8(255, 255, 255, 255);

  // Variant A: current — rounded square, DV centered, arial48
  final a = roundedBg(size, blue, 0.22);
  img.drawString(a, 'DV', font: img.arial48, color: white);
  save(a, 'A_rounded_square_DV');

  // Variant B: circle badge instead of rounded square
  final b = img.Image(width: size, height: size, numChannels: 4);
  img.fill(b, color: img.ColorRgba8(0, 0, 0, 0));
  img.fillCircle(b, x: size ~/ 2, y: size ~/ 2, radius: size ~/ 2, color: blue);
  img.drawString(b, 'DV', font: img.arial48, color: white);
  save(b, 'B_circle_DV');

  // Variant C: rounded square, smaller radius (sharper corners), DV
  final c = roundedBg(size, blue, 0.12);
  img.drawString(c, 'DV', font: img.arial48, color: white);
  save(c, 'C_sharp_square_DV');

  // Variant D: rounded square with "DV" + small "1520" below
  final d = roundedBg(size, blue, 0.22);
  img.drawString(d, 'DV', font: img.arial48, y: 68, color: white);
  img.drawString(d, '1520', font: img.arial24, y: 150, color: white);
  save(d, 'D_DV_1520_stacked');

  // Variant E: inverted colors — white bg, blue DV, thin blue border
  final e = roundedBg(size, white, 0.22);
  img.drawRect(e, x1: 4, y1: 4, x2: size - 5, y2: size - 5, color: blue, radius: (size * 0.20), thickness: 6);
  img.drawString(e, 'DV', font: img.arial48, color: blue);
  save(e, 'E_inverted_white_bg');

  // Variant F: darker blue background variant using secondary theme color
  final darkBlue = img.ColorRgba8(0x00, 0x72, 0x9B, 255);
  final f = roundedBg(size, darkBlue, 0.22);
  img.drawString(f, 'DV', font: img.arial48, color: white);
  save(f, 'F_dark_blue_DV');

  print('Done');
}
