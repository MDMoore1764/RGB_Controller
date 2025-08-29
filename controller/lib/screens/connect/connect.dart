import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:frame_control/screens/connect/device_card.dart';
import 'package:frame_control/screens/connect/scan_button_state.dart';
import 'package:frame_control/utilities/bluetooth_device_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:frame_control/app_state.dart'; // Import your AppState

class Connect extends StatelessWidget {
  static const double listHeight = 150;

  const Connect({super.key});

  Future<void> activateBluetooth() async {
    if (!Platform.isAndroid) {
      return;
    }

    await FlutterBluePlus.turnOn();
  }

  ScanButtonState getScanbuttonState(AppState appState) {
    if (appState.scanning) {
      return ScanButtonState(text: "Scanning...", action: appState.toggleScan);
    }

    if (appState.bleAdapterState == BluetoothAdapterState.turningOn) {
      return ScanButtonState(text: "Activating...", action: null);
    }

    if (appState.bleAdapterState != BluetoothAdapterState.on) {
      return ScanButtonState(
        text: "Activate Bluetooth",
        action: Platform.isAndroid ? activateBluetooth : null,
      );
    }

    return ScanButtonState(
      text: "Scan for Devices",
      action: appState.toggleScan,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final filteredAvailableDevices = appState.availableDevices.where((
          device,
        ) {
          //TODO: Undo this later once things are finished up.
          // return device.advName.isNotEmpty;
          return true;
        }).toList();

        filteredAvailableDevices.sort(compareBluetoothScanResults);

        final resultsWithConnectedDevices = filteredAvailableDevices.where((d) {
          return appState.deviceConnectionStates.containsKey(
                d.device.remoteId.str,
              ) &&
              appState.deviceConnectionStates[d.device.remoteId.str] ==
                  BluetoothConnectionState.connected;
        }).toList();

        final notConnectedScanResults = filteredAvailableDevices.where((d) {
          return !appState.deviceConnectionStates.containsKey(
                d.device.remoteId.str,
              ) ||
              appState.deviceConnectionStates[d.device.remoteId.str] !=
                  BluetoothConnectionState.connected;
        }).toList();

        ScanButtonState scanButtonState = getScanbuttonState(appState);

        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text(
                  "Available Devices",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Container(
                  margin: EdgeInsets.only(
                    left: 0,
                    right: 0,
                    top: 10,
                    bottom: 40,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withAlpha(80),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  height: listHeight,
                  child: ListView.builder(
                    physics: BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final scanResult = notConnectedScanResults[index];

                      return GestureDetector(
                        onTap: () async {
                          //How to check loading/connecting in progress? Hm...
                          if (!scanResult.device.isDisconnected) {
                            return;
                          }

                          try {
                            await appState.handleTryConnect(scanResult.device);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '❌ Failed to connect to ${getDeviceDisplayName(scanResult.device)}: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: DeviceCard(
                          scanResult: scanResult,
                          selected: false,
                          connecting: appState.connectingDeviceRemoteIDs
                              .contains(scanResult.device.remoteId.str),
                          disconnecting: false,
                        ),
                      );
                    },
                    itemCount: notConnectedScanResults.length,
                  ),
                ),

                const Text(
                  "Connected Devices",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Container(
                  margin: EdgeInsets.only(
                    left: 0,
                    right: 0,
                    top: 10,
                    bottom: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withAlpha(80),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  height: listHeight,
                  child: ListView.builder(
                    physics: BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final scanResult = resultsWithConnectedDevices[index];

                      return GestureDetector(
                        onTap: () async {
                          //How to check loading/disconnecting in progress? Hm...
                          if (!scanResult.device.isConnected) {
                            return;
                          }

                          try {
                            await appState.handleTryDisconnect(
                              scanResult.device,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '❌ Failed to disconnect from ${getDeviceDisplayName(scanResult.device)}: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: DeviceCard(
                          scanResult: scanResult,
                          selected: true,
                          connecting: false,
                          disconnecting: appState.disconnectingDeviceRemoteIDs
                              .contains(scanResult.device.remoteId.str),
                        ),
                      );
                    },
                    itemCount: resultsWithConnectedDevices.length,
                  ),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  child: Container(
                    // margin: EdgeInsets.only(bottom: 30),
                    child: FloatingActionButton.extended(
                      onPressed: scanButtonState.action,
                      icon: Icon(Icons.add),
                      label: Text(scanButtonState.text),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
