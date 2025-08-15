import 'dart:math';

import 'package:controller/utilities/light_animation_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'light_animation.dart';

class Control extends StatefulWidget {
  final Color color;
  final List<ScanResult> availableDevices;

  final double timeDelay;
  final int offsetEvery;
  final LightAnimationType selectedAnimation;
  final void Function(LightAnimationType) onSelectAnimation;

  void Function(double) ontimeDelayChange;
  void Function(int) onOffsetEveryChange;

  Control({
    super.key,
    required this.color,
    required this.availableDevices,
    required this.timeDelay,
    required this.offsetEvery,
    required this.onOffsetEveryChange,
    required this.ontimeDelayChange,
    required this.onSelectAnimation,
    required this.selectedAnimation,
  });

  @override
  State<Control> createState() => _ControlState();
}

class _ControlState extends State<Control> {
  final List<LightAnimation> _animations = [];
  _ControlState() {
    _animations.addAll(buildAnimations(send));
    _animations.sort();
  }

  @override
  void initState() {
    super.initState();
  }

  void sendPattern(String patternName) {
    debugPrint('Sending pattern: $patternName');
  }

  void send(String pattern) {}

  List<LightAnimation> buildAnimations(void Function(String) onSend) {
    final iconMap = {
      LightAnimationType.Flat: Icons.light_mode,
      LightAnimationType.Glow: Icons.wb_incandescent,
      LightAnimationType.Pulse: Icons.favorite,
      LightAnimationType.Strobe: Icons.flash_on,
      LightAnimationType.Fade: Icons.blur_on,
      LightAnimationType.Rainbow: Icons.gradient,
      LightAnimationType.Cycle: Icons.autorenew,
      LightAnimationType.Breathe: Icons.air,
      LightAnimationType.Wave: Icons.water,
      LightAnimationType.Fire: Icons.local_fire_department,
      LightAnimationType.Sparkle: Icons.auto_awesome,
      LightAnimationType.Flash: Icons.bolt,
      LightAnimationType.Chase: Icons.directions_run,
      LightAnimationType.Twinkle: Icons.star_border,
      LightAnimationType.Meteor: Icons.shower,
      LightAnimationType.Scanner: Icons.scanner,
      LightAnimationType.Comet: Icons.travel_explore,
      LightAnimationType.Wipe: Icons.border_horizontal,
      LightAnimationType.Larson: Icons.remove_red_eye,
      LightAnimationType.Fireworks: Icons.celebration,
      LightAnimationType.Confetti: Icons.party_mode,
      LightAnimationType.Ripple: Icons.waves,
      LightAnimationType.Noise: Icons.graphic_eq,
      LightAnimationType.ILY: Icons.favorite_outline_rounded,
      LightAnimationType.Neon: Icons.bolt,
      LightAnimationType.Sine: Icons.ssid_chart,
      LightAnimationType.Blizzard: Icons.snowing,
      LightAnimationType.Apoca: Icons.blur_on,
    };

    return LightAnimationType.values.map((type) {
      return LightAnimation(type: type, icon: iconMap[type]!, onSend: onSend);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final resultsWithConnectedDevices = widget.availableDevices.where((d) {
      return d.device.isConnected;
    }).toList();

    final notConnectedScanResults = widget.availableDevices.where((d) {
      return d.device.isDisconnected;
    }).toList();

    final timeDelayDisabled = resultsWithConnectedDevices.length <= 1;
    final everyXDevicesDisabledDueToOffset =
        timeDelayDisabled || widget.timeDelay < 0.1;

    final everyXDevicesDisabledDueToDeviceCount =
        resultsWithConnectedDevices.length < 3;

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        timeDelayDisabled
                            ? "Two or more devices required for time offset"
                            : "Offset: ${widget.timeDelay.toStringAsFixed(1)} s",
                      ),
                      SizedBox(
                        height: 50,
                        child: RotatedBox(
                          quarterTurns: 0,
                          child: Slider(
                            value: widget.timeDelay,
                            min: 0.0,
                            max: 5.0,
                            divisions: (5.0 / 0.1).toInt(),
                            label: "${widget.timeDelay.toStringAsFixed(1)} s",

                            onChanged: timeDelayDisabled
                                ? null
                                : (double newValue) {
                                    widget.ontimeDelayChange(newValue);
                                  },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        everyXDevicesDisabledDueToDeviceCount
                            ? "At least three devices required for device skip"
                            : everyXDevicesDisabledDueToOffset
                            ? "Offset required for device skip"
                            : "Offset every${widget.offsetEvery == 1 ? '' : ' ${widget.offsetEvery.toStringAsFixed(0)}'} device${widget.offsetEvery == 1 ? '' : 's'}",
                      ),
                      RotatedBox(
                        quarterTurns: 0,
                        child: Slider(
                          value: widget.offsetEvery.toDouble(),

                          min: min(
                            resultsWithConnectedDevices.length.toDouble(),
                            1,
                          ),
                          max: max(
                            resultsWithConnectedDevices.length.toDouble() - 1,
                            1,
                          ),
                          divisions: max(
                            resultsWithConnectedDevices.length.toDouble() - 1,
                            1,
                          ).toInt(),
                          label:
                              "${widget.offsetEvery.toStringAsFixed(0)} devices",

                          onChanged:
                              everyXDevicesDisabledDueToDeviceCount ||
                                  everyXDevicesDisabledDueToOffset
                              ? null
                              : (double newValue) {
                                  setState(() {
                                    widget.onOffsetEveryChange(
                                      newValue.toInt(),
                                    );
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

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
                                color: widget.color,
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              widget.selectedAnimation.name,
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
                            widget.selectedAnimation == animation.type;

                        return ElevatedButton(
                          onPressed: () {
                            widget.onSelectAnimation(animation.type);
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
