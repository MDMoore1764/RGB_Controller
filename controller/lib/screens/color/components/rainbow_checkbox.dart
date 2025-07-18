import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedRainbowCheckbox extends StatefulWidget {
  void Function(Color) onColorSelected;
  final Color color;
  final AnimationController animationController;
  final bool rainbowMode;
  final void Function(bool) onSetRainbowMode;

  AnimatedRainbowCheckbox({
    super.key,
    required this.onColorSelected,
    required this.color,
    required this.animationController,
    required this.rainbowMode,
    required this.onSetRainbowMode,
  });

  @override
  _AnimatedRainbowCheckboxState createState() =>
      _AnimatedRainbowCheckboxState();
}

class _AnimatedRainbowCheckboxState extends State<AnimatedRainbowCheckbox> {
  @override
  void initState() {
    super.initState();

    // _controller = AnimationController(
    //   vsync: this,
    //   duration: Duration(milliseconds: 3000),
    // )..repeat();

    // if (isChecked) {
    //   _controller.repeat();
    //   return;
    // }

    // _controller.stop();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onRainbowToggled(bool? value) {
    final firmValue = value ?? false;

    widget.onSetRainbowMode(firmValue);
  }

  @override
  Widget build(BuildContext context) {
    final rainbowText = Text(
      'Rainbow',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white, // this gets tinted by shader
      ),
    );

    return AnimatedBuilder(
      animation: widget.animationController,
      builder: (context, _) {
        return CheckboxListTile(
          value: widget.rainbowMode,
          tileColor: Theme.of(context).colorScheme.surface,
          onChanged: _onRainbowToggled,
          controlAffinity: ListTileControlAffinity.leading,
          title: !widget.rainbowMode
              ? rainbowText
              : ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      colors: [
                        Colors.purple,
                        Colors.indigo,
                        Colors.blue,
                        Colors.green,
                        Colors.yellow,
                        Colors.orange,
                        Colors.red,
                      ],
                      stops: [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0],
                      begin: Alignment(
                        1 + 4 * widget.animationController.value,
                        0,
                      ),
                      end: Alignment(
                        -1 + 4 * widget.animationController.value,
                        0,
                      ),
                      tileMode: TileMode.mirror,
                    ).createShader(bounds);
                  },
                  child: rainbowText,
                ),
        );
      },
    );
  }
}
