import 'package:frame_control/screens/color/components/rainbow_checkbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorScreen extends StatefulWidget {
  void Function(Color) onColorSelected;
  void Function(bool) onSetRainbowMode;

  final bool raindowMode;
  final Color color;
  final AnimationController animationController;

  ColorScreen({
    super.key,
    required this.onColorSelected,
    required this.color,
    required this.animationController,
    required this.onSetRainbowMode,
    required this.raindowMode,
  });

  @override
  State<ColorScreen> createState() => _ColorScreenState();
}

class _ColorScreenState extends State<ColorScreen> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Card(
          elevation: 1,
          child: ColorPicker(
            pickerColor: widget.color,
            onColorChanged: (color) {
              widget.onColorSelected(color);
            },
            paletteType: PaletteType.hueWheel,
            enableAlpha: false,
            showLabel: false,
            portraitOnly: true,
            displayThumbColor: false,
            pickerAreaHeightPercent: 1.0,
          ),
        ),
        const SizedBox(height: 20),
        AnimatedRainbowCheckbox(
          onColorSelected: widget.onColorSelected,
          color: widget.color,
          animationController: widget.animationController,
          onSetRainbowMode: widget.onSetRainbowMode,
          rainbowMode: widget.raindowMode,
        ),
      ],
    );
  }
}
