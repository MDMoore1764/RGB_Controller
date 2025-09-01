import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';

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

int compareBluetoothScanResults(ScanResult result1, ScanResult result2) {
  // Adv name first
  if (result1.device.advName.isNotEmpty) {
    if (result2.device.advName.isEmpty) {
      return -1;
    }

    return result1.device.advName.compareTo(result2.device.advName);
  }

  if (result2.device.advName.isNotEmpty) {
    return 1;
  }

  //Remote ID
  if (result1.device.remoteId.str.isNotEmpty) {
    if (result2.device.remoteId.str.isEmpty) {
      return -1;
    }

    return result1.device.remoteId.str.compareTo(result2.device.remoteId.str);
  }

  if (result2.device.remoteId.str.isNotEmpty) {
    return 1;
  }

  return 0;
}
