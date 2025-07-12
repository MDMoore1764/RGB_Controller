import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class Control extends StatefulWidget {
  const Control({super.key});

  @override
  State<Control> createState() => _ControlState();
}

class _ControlState extends State<Control> {
  Color currentColor = Colors.blue;

  void changeColor(Color color) => setState(() => currentColor = color);

  void sendPattern(String patternName) {
    debugPrint('Sending pattern: $patternName');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Card(
          elevation: 4,
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: (color) => setState(() => currentColor = color),
            paletteType: PaletteType.hueWheel,
            enableAlpha: false,
            showLabel: false,
            portraitOnly: true,
            displayThumbColor: false,
            pickerAreaHeightPercent: 1.0,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
