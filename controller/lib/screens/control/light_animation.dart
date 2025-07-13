import 'package:flutter/material.dart';

class LightAnimation implements Comparable<LightAnimation> {
  final String name;
  final String command;
  final IconData icon;

  final void Function(String) onSend;

  const LightAnimation({
    required this.name,
    required this.command,
    required this.icon,
    required this.onSend,
  });

  void send() {
    this.onSend(this.command);
  }
  
  @override
  int compareTo(LightAnimation other) {
    return this.name.compareTo(other.name);
  }
}
