import 'dart:collection';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

class BluetoothDeviceManager {
  final HashSet<String> _locatedDeviceRemoteIDs = HashSet<String>();
  final HashSet<String> _connectedDeviceRemoteIDs = HashSet<String>();
  final List<BluetoothDevice> availableDevices = [];
  final List<BluetoothDevice> connectedDevices = [];
  final void Function(List<BluetoothDevice>)? onDeviceListChange;
  final void Function(List<BluetoothDevice>)? onConnectedDeviceListChange;
  final void Function(BluetoothAdapterState)? onBluetoothStateChange;
  bool isScanning = false;
  BluetoothAdapterState adapterState = BluetoothAdapterState.off;

  BluetoothDeviceManager({
    this.onDeviceListChange,
    this.onConnectedDeviceListChange,
    this.onBluetoothStateChange,
  }) {
    FlutterBluePlus.adapterState.listen((state) {
      adapterState = state;
      if (this.onBluetoothStateChange != null) {
        this.onBluetoothStateChange!(state);
      }
    });
  }

  Future<bool> turnOnBluetooth() async {
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
      return true;
    }

    return false;
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: true);
      if (!_connectedDeviceRemoteIDs.contains(device.remoteId.str)) {
        _connectedDeviceRemoteIDs.add(device.remoteId.str);
        if (onConnectedDeviceListChange != null) {
          onConnectedDeviceListChange!(connectedDevices);
        }
      }
    } catch (e) {
      _connectedDeviceRemoteIDs.remove(device.remoteId.str);
    }
  }

  Future<void> disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      _connectedDeviceRemoteIDs.remove(device.remoteId.str);
      this.connectedDevices.remove(device);

      // ignore: empty_catches
    } catch (e) {}
  }

  Future<void> sendCommandToCharacteristic(
    BluetoothCharacteristic characteristic,
    String command,
  ) async {
    // return characteristic.write(command.codeUnits);
  }
}
