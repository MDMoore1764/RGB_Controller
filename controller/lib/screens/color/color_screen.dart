import 'package:frame_control/screens/color/components/rainbow_checkbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';
import 'package:frame_control/app_state.dart'; // Import your AppState

class ColorScreen extends StatelessWidget {
  const ColorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Card(
              elevation: 1,
              child: ColorPicker(
                pickerColor: appState.selectedColor,
                onColorChanged: (color) {
                  appState.setSelectedColor(color);
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
              onColorSelected: appState.setSelectedColor,
              color: appState.selectedColor,
              animationController: appState.animationController!,
              onSetRainbowMode: appState.setRainbowMode,
              rainbowMode: appState.rainbowMode,
            ),
          ],
        );
      },
    );
  }
}
