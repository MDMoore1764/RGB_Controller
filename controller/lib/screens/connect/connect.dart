import 'dart:io';
import 'dart:math';

import 'package:controller/screens/connect/bluetooth_controller.dart';
import 'package:controller/screens/connect/device_card.dart';
import 'package:controller/screens/connect/scan_button_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Connect extends StatefulWidget {
  // final Future<void> Function(BluetoothDevice) connectToDevice;
  // final Future<void> Function(BluetoothDevice) disconnectFromDevice;
  // final bool isScanning;
  // final bool bluetoothIsOn;
  // final bool canActivateBluetooth;
  // final bool bluetoothIsLoading
  // final Future<bool> Function() activateBluetooth;
  final BluetoothController bluetoothController;
  late double listHeight;

  Connect({super.key, required this.bluetoothController}) {
    this.listHeight = 150;
  }

  @override
  State<Connect> createState() => _ConnectState();
}

class _ConnectState extends State<Connect> {
  late double _timeDelay;
  late int _offsetEvery;

  _ConnectState() {
    _timeDelay = 0;
    _offsetEvery = 1;
  }

  @override
  Widget build(BuildContext context) {
    final connectedDevices = widget.bluetoothController.availableDevices.where((
      d,
    ) {
      return d.isConnected;
    }).toList();

    final notConnectedDevices = widget.bluetoothController.availableDevices
        .where((d) {
          return !d.isConnected;
        })
        .toList();

    final timeDelayDisabled = connectedDevices.length <= 1;
    final everyXDevicesDisabled = timeDelayDisabled || _timeDelay < 0.1;

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
                  final device = notConnectedDevices[index];

                  return GestureDetector(
                    onTap: () {
                      //How to check loading/connecting in progress? Hm...

                      if (!device.isDisconnected) {
                        return;
                      }

                      widget.bluetoothController.connectToDevice(device);
                    },
                    child: DeviceCard(name: device.advName, selected: false),
                  );
                },
                itemCount: notConnectedDevices.length,
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
                  final device = connectedDevices[index];

                  return GestureDetector(
                    onTap: () {
                      //How to check loading/disconnecting in progress? Hm...

                      if (!device.isConnected) {
                        return;
                      }

                      widget.bluetoothController.disconnectFromDevice(device);
                    },
                    child: DeviceCard(name: device.advName, selected: true),
                  );
                },
                itemCount: connectedDevices.length,
              ),
            ),

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
                                : "Offset: ${_timeDelay.toStringAsFixed(1)} s",
                          ),
                          SizedBox(
                            height: 50,
                            child: RotatedBox(
                              quarterTurns: 0,
                              child: Slider(
                                value: _timeDelay,
                                min: 0.0,
                                max: 5.0,
                                divisions: (5.0 / 0.1).toInt(),
                                label: "${_timeDelay.toStringAsFixed(1)} s",

                                onChanged: timeDelayDisabled
                                    ? null
                                    : (double newValue) {
                                        setState(() {
                                          _timeDelay = newValue;
                                        });
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
                            everyXDevicesDisabled
                                ? "Offset required for device skip"
                                : "Offset every${_offsetEvery == 1.0 ? ' other' : ' ${_offsetEvery.toStringAsFixed(0)}'} device${_offsetEvery == 1.0 ? '' : 's'}",
                          ),
                          RotatedBox(
                            quarterTurns: 0,
                            child: Slider(
                              value: _offsetEvery.toDouble(),

                              min: min(connectedDevices.length.toDouble(), 1),
                              max: max(connectedDevices.length.toDouble(), 1),
                              divisions: max(
                                connectedDevices.length.toDouble(),
                                1,
                              ).toInt(),
                              label:
                                  "${_offsetEvery.toStringAsFixed(0)} devices",

                              onChanged: everyXDevicesDisabled
                                  ? null
                                  : (double newValue) {
                                      setState(() {
                                        _offsetEvery = newValue.toInt();
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
    if (widget.bluetoothController.isScanning) {
      return ScanButtonState(
        text: "Scanning...",
        action: widget.bluetoothController.toggleScan,
      );
    }

    if (widget.bluetoothController.adapterState ==
        BluetoothAdapterState.turningOn) {
      return ScanButtonState(text: "Activating...", action: null);
    }

    if (widget.bluetoothController.adapterState != BluetoothAdapterState.on) {
      return ScanButtonState(
        text: "Activate Bluetooth",
        action: Platform.isAndroid
            ? widget.bluetoothController.turnOnBluetooth
            : null,
      );
    }

    return ScanButtonState(
      text: "Scan for Devices",
      action: widget.bluetoothController.toggleScan,
    );
  }
}
