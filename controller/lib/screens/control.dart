import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'control/light_animation.dart';

class Control extends StatefulWidget {
  const Control({super.key});

  @override
  State<Control> createState() => _ControlState();
}

class _ControlState extends State<Control> {
  Color currentColor = Colors.blue;
  String selectedAnimation = "";
  final List<LightAnimation> _animations = [];
  _ControlState() {
    _animations.addAll(buildAnimations(send));
    _animations.sort();

    selectedAnimation = _animations.first.name;
  }

  void changeColor(Color color) => setState(() => currentColor = color);

  void sendPattern(String patternName) {
    debugPrint('Sending pattern: $patternName');
  }

  void send(String pattern) {}

  List<LightAnimation> buildAnimations(void Function(String) onSend) {
    return [
      LightAnimation(
        name: "Glow",
        command: "glow",
        icon: Icons.wb_incandescent,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Pulse",
        command: "pulse",
        icon: Icons.favorite,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Strobe",
        command: "strobe",
        icon: Icons.flash_on,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Fade",
        command: "fade",
        icon: Icons.blur_on,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Rainbow",
        command: "rainbow",
        icon: Icons.gradient,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Cycle",
        command: "cycle",
        icon: Icons.autorenew,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Breathe",
        command: "breathe",
        icon: Icons.air,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Wave",
        command: "wave",
        icon: Icons.water,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Fire",
        command: "fire",
        icon: Icons.local_fire_department,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Sparkle",
        command: "sparkle",
        icon: Icons.auto_awesome,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Flash",
        command: "flash",
        icon: Icons.bolt,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Chase",
        command: "chase",
        icon: Icons.directions_run,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Twinkle",
        command: "twinkle",
        icon: Icons.star_border,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Meteor",
        command: "meteor",
        icon: Icons.shower,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Scanner",
        command: "scanner",
        icon: Icons.scanner,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Comet",
        command: "comet",
        icon: Icons.travel_explore,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Wipe",
        command: "wipe",
        icon: Icons.border_horizontal,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Larson",
        command: "larson",
        icon: Icons.remove_red_eye,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Fireworks",
        command: "fireworks",
        icon: Icons.celebration,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Confetti",
        command: "confetti",
        icon: Icons.party_mode,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Ripple",
        command: "ripple",
        icon: Icons.waves,
        onSend: onSend,
      ),
      LightAnimation(
        name: "Noise",
        command: "noise",
        icon: Icons.graphic_eq,
        onSend: onSend,
      ),
      LightAnimation(
        name: "ILY",
        command: "ily",
        icon: Icons.favorite_outline_rounded,
        onSend: onSend,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Card(
          elevation: 1,
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
        Expanded(
          child: Card(
            elevation: 1,

            // padding: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: currentColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              selectedAnimation,
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: GridView.builder(
                      physics: BouncingScrollPhysics(),
                      itemCount: _animations.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                4, // 👈 adjust column count as needed
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 12,
                            childAspectRatio:
                                0.8, // Adjust spacing of icon to text
                          ),
                      itemBuilder: (context, index) {
                        final animation = _animations[index];
                        final icon = animation.icon;

                        final isSelected =
                            this.selectedAnimation == animation.name;

                        return ElevatedButton(
                          onPressed: () {
                            setState(() {
                              selectedAnimation = animation.name;
                            });

                            animation.send();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(0),
                            elevation: 4,
                            shape: const CircleBorder(),
                            backgroundColor: isSelected
                                ? Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer
                                      .withAlpha(255)
                                : Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer
                                      .withAlpha(100),
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),

                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, size: 32),
                              const SizedBox(height: 8),
                              Text(animation.name, textAlign: TextAlign.center),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
