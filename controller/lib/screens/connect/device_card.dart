import 'package:frame_control/utilities/bluetooth_device_utilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceCard extends StatelessWidget {
  final bool selected;
  final ScanResult scanResult;
  final bool connecting;
  final bool disconnecting;

  DeviceCard({
    super.key,
    required this.scanResult,
    required this.selected,
    required this.connecting,
    required this.disconnecting,
  });

  @override
  Widget build(BuildContext context) {
    final deviceText = getDeviceDisplayName(scanResult.device);

    final signalStrengthText =
        this.scanResult.advertisementData.txPowerLevel == null
        ? ""
        : "${this.scanResult.advertisementData.txPowerLevel} dBm";

    return Container(
      margin: EdgeInsets.symmetric(vertical: 0, horizontal: 5),
      child: SizedBox(
        width: 145,
        child: Card(
          surfaceTintColor: this.selected
              ? Theme.of(context).focusColor
              : Theme.of(context).cardColor,
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  deviceText,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  this.disconnecting
                      ? "Disconnecting..."
                      : this.connecting
                      ? "Connecting..."
                      : this.scanResult.device.isConnected
                      ? "Connected"
                      : "Disconnected",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  signalStrengthText,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
