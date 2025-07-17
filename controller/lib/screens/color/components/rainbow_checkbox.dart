import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedRainbowCheckbox extends StatefulWidget {
  void Function(Color) onColorSelected;
  final Color color;
  final AnimationController animationController;

  AnimatedRainbowCheckbox({
    super.key,
    required this.onColorSelected,
    required this.color,
    required this.animationController,
  });

  @override
  _AnimatedRainbowCheckboxState createState() =>
      _AnimatedRainbowCheckboxState();
}

class _AnimatedRainbowCheckboxState extends State<AnimatedRainbowCheckbox> {
  bool isChecked = false;

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

  void _sendControllerColor() {
    final lightness = HSLColor.fromColor(widget.color).lightness;

    final hue = 360 + widget.animationController.value * -360;
    var color = HSLColor.fromAHSL(1.0, hue, 1.0, lightness);

    widget.onColorSelected(color.toColor());
  }

  void _onRainbowToggled(bool? value) {
    final firmValue = value ?? false;

    if (firmValue) {
      widget.animationController.addListener(_sendControllerColor);
    } else {
      widget.animationController.removeListener(_sendControllerColor);
    }

    setState(() {
      isChecked = firmValue;
    });
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
          value: isChecked,
          tileColor: Theme.of(context).colorScheme.surface,
          onChanged: _onRainbowToggled,
          controlAffinity: ListTileControlAffinity.leading,
          title: !isChecked
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
