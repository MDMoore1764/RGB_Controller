import 'dart:math';

import 'package:frame_control/utilities/light_animation_type.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frame_control/app_state.dart';

import 'light_animation.dart';

class Control extends StatelessWidget {
  const Control({super.key});

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
      LightAnimationType.Wave: Icons.water,
      LightAnimationType.Fire: Icons.local_fire_department,
      LightAnimationType.Sparkle: Icons.auto_awesome,
      LightAnimationType.Chase: Icons.directions_run,
      LightAnimationType.Twinkle: Icons.star_border,
      LightAnimationType.Meteor: Icons.shower,
      LightAnimationType.Scanner: Icons.scanner,
      LightAnimationType.Comet: Icons.travel_explore,
      LightAnimationType.Wipe: Icons.border_horizontal,
      LightAnimationType.Sweep: Icons.remove_red_eye,
      LightAnimationType.Fwerks: Icons.celebration,
      LightAnimationType.Confetti: Icons.party_mode,
      LightAnimationType.Ripple: Icons.waves,
      LightAnimationType.Noise: Icons.graphic_eq,
      LightAnimationType.ILY: Icons.favorite_outline_rounded,
      LightAnimationType.Neon: Icons.bolt,
      LightAnimationType.Blizzard: Icons.snowing,
      LightAnimationType.Apoca: Icons.blur_on,
    };

    return LightAnimationType.values.map((type) {
      return LightAnimation(type: type, icon: iconMap[type]!, onSend: onSend);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final animations = buildAnimations(send);
        animations.sort();

        final resultsWithConnectedDevices = appState.availableDevices.where((
          d,
        ) {
          return d.device.isConnected;
        }).toList();

        final notConnectedScanResults = appState.availableDevices.where((d) {
          return d.device.isDisconnected;
        }).toList();

        final timeDelayDisabled = resultsWithConnectedDevices.length <= 1;
        final everyXDevicesDisabledDueToOffset =
            timeDelayDisabled || appState.timeDelay < 0.1;

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
                                : "Offset: ${appState.timeDelay.toStringAsFixed(1)} s",
                          ),
                          SizedBox(
                            height: 50,
                            child: RotatedBox(
                              quarterTurns: 0,
                              child: Slider(
                                value: appState.timeDelay,
                                min: 0.0,
                                max: 5.0,
                                divisions: (5.0 / 0.1).toInt(),
                                label:
                                    "${appState.timeDelay.toStringAsFixed(1)} s",
                                onChanged: timeDelayDisabled
                                    ? null
                                    : (double newValue) {
                                        appState.setTimeDelay(newValue);
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
                                : "Offset every${appState.offsetEvery == 1 ? '' : ' ${appState.offsetEvery.toStringAsFixed(0)}'} device${appState.offsetEvery == 1 ? '' : 's'}",
                          ),
                          RotatedBox(
                            quarterTurns: 0,
                            child: Slider(
                              value: appState.offsetEvery.toDouble(),
                              min: 0,
                              max: 2,
                              divisions: 19,
                              label:
                                  "${appState.offsetEvery.toStringAsFixed(0)} devices",
                              onChanged:
                                  everyXDevicesDisabledDueToDeviceCount ||
                                      everyXDevicesDisabledDueToOffset
                                  ? null
                                  : (double newValue) {
                                      appState.setOffsetEvery(newValue.toInt());
                                    },
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
                          Text("Pattern Rate"),
                          RotatedBox(
                            quarterTurns: 0,
                            child: Slider(
                              value: appState.rate.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 98,
                              label: "${appState.rate.toStringAsFixed(2)}",
                              onChanged: (double newValue) {
                                appState.setRate(newValue);
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
                                    color: appState.selectedColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  appState.animationType.name,
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
                          itemCount: animations.length,
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
                            final animation = animations[index];
                            final icon = animation.icon;

                            final isSelected =
                                appState.animationType == animation.type;

                            return ElevatedButton(
                              onPressed: () {
                                appState.setAnimationType(animation.type);
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
                                  Text(
                                    animation.name,
                                    textAlign: TextAlign.center,
                                  ),
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
      },
    );
  }
}
