import 'package:frame_control/utilities/light_animation_type.dart';
import 'package:flutter/material.dart';

class LightAnimation implements Comparable<LightAnimation> {
  final IconData icon;
  final LightAnimationType type;
  final void Function(String) onSend;

  const LightAnimation({
    required this.type,
    required this.icon,
    required this.onSend,
  });

  void send() {
    this.onSend(this.command);
  }

  String get name => this.type.name;
  String get command => this.type.command;

  @override
  int compareTo(LightAnimation other) {
    return this.name.compareTo(other.name);
  }
}
