import 'package:flutter/material.dart';
import 'package:frame_control/utilities/light_animation_type.dart';

class Preset {
  final String id;
  final String name;
  final Color color;
  final LightAnimationType pattern;
  final bool rainbowMode;
  final DateTime createdAt;
  final double rate;

  String get displayName {
    return name
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Preset({
    required this.id,
    required this.name,
    required this.color,
    required this.pattern,
    required this.rainbowMode,
    required this.createdAt,
    required this.rate,
  });

  Map<String, String> toJson() {
    return {
      'id': id,
      'name': name,
      'color': "${color.r},${color.g},${color.b},${color.a}",
      'pattern': pattern.name,
      'rainbowMode': rainbowMode.toString(),
      'createdAt': createdAt.toIso8601String(),
      'rate': rate.toStringAsFixed(2),
    };
  }

  factory Preset.fromJson(Map<String, dynamic> json) {
    var colorParts = (json['color'] as String)
        .split(',')
        .map(double.parse)
        .toList();
    return Preset(
      id: json['id'],
      name: json['name'],
      color: Color.fromARGB(
        (colorParts[0] * 255).floor(),
        (colorParts[1] * 255).floor(),
        (colorParts[2] * 255).floor(),
        (colorParts[3] * 255).floor(),
      ),
      pattern: LightAnimationType.values.firstWhere(
        (e) => e.name == json['pattern'],
        orElse: () => LightAnimationType.Flat,
      ),
      rainbowMode: bool.parse(json['rainbowMode']),
      createdAt: DateTime.parse(json['createdAt']),
      rate: double.parse(json['rate']),
    );
  }

  String get colorRGBA {
    return 'RGBA(${color.r}, ${color.g}, ${color.b}, ${(color.a / 255).toStringAsFixed(2)})';
  }
}
