import 'package:flutter_blue_plus/flutter_blue_plus.dart';

String getDeviceDisplayName(BluetoothDevice device) {
  if (device.advName.isNotEmpty) {
    return device.advName;
  } else if (device.platformName.isNotEmpty) {
    return device.platformName;
  } else if (device.remoteId.str.isNotEmpty) {
    return device.remoteId.str;
  }

  return "Unknown";
}

int compareBluetoothDevices(BluetoothDevice device1, BluetoothDevice device2) {
  // Adv name first
  if (device1.advName.isNotEmpty) {
    if (device2.advName.isEmpty) {
      return -1;
    }

    return device1.advName.compareTo(device2.advName);
  }

  if (device2.advName.isNotEmpty) {
    return 1;
  }

  //Remote ID
  if (device1.remoteId.str.isNotEmpty) {
    if (device2.remoteId.str.isEmpty) {
      return -1;
    }

    return device1.remoteId.str.compareTo(device2.remoteId.str);
  }

  if (device2.remoteId.str.isNotEmpty) {
    return 1;
  }

  return 0;
}
