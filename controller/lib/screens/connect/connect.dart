import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:controller/screens/connect/device_card.dart';
import 'package:controller/screens/connect/scan_button_state.dart';
import 'package:controller/utilities/bluetooth_device_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Connect extends StatefulWidget {
  late double listHeight;

  final List<ScanResult> availableDevices;
  final bool scanning;
  final HashMap<String, BluetoothConnectionState> deviceconnectionStates;
  final HashSet<String> connectingDeviceRemoteIDs;
  final HashSet<String> disconnectingDeviceRemoteIDs;
  final BluetoothAdapterState bleAdapterState;
  final Function() handleToggleScan;
  final Function(BluetoothDevice) handleTryConnect;
  final Function(BluetoothDevice) handleTrydisconnect;

  Connect({
    super.key,
    required this.availableDevices,
    required this.scanning,
    required this.deviceconnectionStates,
    required this.connectingDeviceRemoteIDs,
    required this.disconnectingDeviceRemoteIDs,
    required this.bleAdapterState,
    required this.handleToggleScan,
    required this.handleTryConnect,
    required this.handleTrydisconnect,
  }) {
    this.listHeight = 150;
  }

  @override
  State<Connect> createState() => _ConnectState();
}

class _ConnectState extends State<Connect> {
  _ConnectState() {}

  @override
  initState() {
    super.initState();
  }

  Future<void> activateBluetooth() async {
    if (!Platform.isAndroid) {
      return;
    }

    await FlutterBluePlus.turnOn();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAvailableDevices = widget.availableDevices.where((device) {
      //TODO: Undo this later once things are finished up.
      // return device.advName.isNotEmpty;
      return true;
    }).toList();

    filteredAvailableDevices.sort(compareBluetoothScanResults);

    final resultsWithConnectedDevices = filteredAvailableDevices.where((d) {
      return widget.deviceconnectionStates.containsKey(d.device.remoteId.str) &&
          widget.deviceconnectionStates[d.device.remoteId.str] ==
              BluetoothConnectionState.connected;
    }).toList();

    final notConnectedScanResults = filteredAvailableDevices.where((d) {
      return !widget.deviceconnectionStates.containsKey(
            d.device.remoteId.str,
          ) ||
          widget.deviceconnectionStates[d.device.remoteId.str] !=
              BluetoothConnectionState.connected;
    }).toList();

    ScanButtonState scanButtonState = getScanbuttonState();

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
              margin: EdgeInsets.only(left: 0, right: 0, top: 10, bottom: 40),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withAlpha(80),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              height: this.widget.listHeight,
              child: ListView.builder(
                physics: BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final scanResult = notConnectedScanResults[index];

                  return GestureDetector(
                    onTap: () {
                      //How to check loading/connecting in progress? Hm...

                      if (!scanResult.device.isDisconnected) {
                        return;
                      }

                      widget.handleTryConnect(scanResult.device);
                    },
                    child: DeviceCard(
                      scanResult: scanResult,
                      selected: false,
                      connecting: widget.connectingDeviceRemoteIDs.contains(
                        scanResult.device.remoteId.str,
                      ),
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
              margin: EdgeInsets.only(left: 0, right: 0, top: 10, bottom: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withAlpha(80),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              height: this.widget.listHeight,
              child: ListView.builder(
                physics: BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final scanResult = resultsWithConnectedDevices[index];

                  return GestureDetector(
                    onTap: () {
                      //How to check loading/disconnecting in progress? Hm...

                      if (!scanResult.device.isConnected) {
                        return;
                      }

                      widget.handleTrydisconnect(scanResult.device);
                    },
                    child: DeviceCard(
                      scanResult: scanResult,
                      selected: true,
                      connecting: false,
                      disconnecting: widget.disconnectingDeviceRemoteIDs
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
  }

  ScanButtonState getScanbuttonState() {
    if (widget.scanning) {
      return ScanButtonState(
        text: "Scanning...",
        action: widget.handleToggleScan,
      );
    }

    if (widget.bleAdapterState == BluetoothAdapterState.turningOn) {
      return ScanButtonState(text: "Activating...", action: null);
    }

    if (widget.bleAdapterState != BluetoothAdapterState.on) {
      return ScanButtonState(
        text: "Activate Bluetooth",
        action: Platform.isAndroid ? this.activateBluetooth : null,
      );
    }

    return ScanButtonState(
      text: "Scan for Devices",
      action: widget.handleToggleScan,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
