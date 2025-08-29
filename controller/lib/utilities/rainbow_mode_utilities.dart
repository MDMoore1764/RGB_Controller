import 'dart:ui';

import 'package:flutter/material.dart';

Color calculateCurrentRainbowColor(double colorProgression, double lightness) {
  final hue = 360 + colorProgression * -360;
  final color = HSLColor.fromAHSL(1.0, hue, 1.0, lightness);
  return color.toColor();
}
