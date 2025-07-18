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
  // final Future<void> Function(BluetoothDevice) connectToDevice;
  // final Future<void> Function(BluetoothDevice) disconnectFromDevice;
  // final bool isScanning;
  // final bool bluetoothIsOn;
  // final bool canActivateBluetooth;
  // final bool bluetoothIsLoading
  // final Future<bool> Function() activateBluetooth;
  late double listHeight;

  final List<ScanResult> availableDevices;
  void Function(List<ScanResult>) onAvailableDevicesChanged;

  Connect({
    super.key,
    required this.availableDevices,
    required this.onAvailableDevicesChanged,
  }) {
    this.listHeight = 150;
  }

  @override
  State<Connect> createState() => _ConnectState();
}

class _ConnectState extends State<Connect> {
  // final List<BluetoothDevice> _availableDevices = [];
  // final List<BluetoothDevice> _connectedDevices = [];
  final HashSet<String> _availableDeviceRemoteIDs = HashSet<String>();
  final HashSet<String> _connectingDeviceRemoteIDs = HashSet<String>();
  final HashSet<String> _disconnectingDeviceRemoteIDs = HashSet<String>();

  BluetoothAdapterState _bleAdapterState = FlutterBluePlus.adapterStateNow;

  final List<StreamSubscription> _baseSubscriptions = [];
  final List<StreamSubscription> _deviceSubscriptions = [];

  late final HashMap<String, BluetoothConnectionState> _deviceconnectionStates;

  bool _scanning = false;

  _ConnectState() {
    _deviceconnectionStates = HashMap<String, BluetoothConnectionState>();
  }

  @override
  initState() {
    super.initState();

    //start listening to ble adapter state.

    final adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          _bleAdapterState = state;
        });
      }
    });

    final isScanningSub = FlutterBluePlus.isScanning.listen((isScanning) {
      if (!isScanning) {
        if (mounted) {
          setState(() {
            _scanning = false;
          });
        }
      }
    });

    _baseSubscriptions.add(adapterStateSub);
    _baseSubscriptions.add(isScanningSub);

    for (final device in widget.availableDevices) {
      _deviceconnectionStates[device.device.remoteId.str] =
          device.device.isConnected
          ? BluetoothConnectionState.connected
          : BluetoothConnectionState.disconnected;

      final deviceStateSub = device.device.connectionState.listen((
        connectionState,
      ) {
        handleConnectionStateChanged(device, connectionState);
      });

      _deviceSubscriptions.add(deviceStateSub);
    }
  }

  Future<void> activateBluetooth() async {
    if (!Platform.isAndroid) {
      return;
    }

    await FlutterBluePlus.turnOn();
  }

  StreamSubscription<List<ScanResult>>? scanSubscription = null;

  /// Starts scanning for BLE devices.
  /// If already scanning, it stops.
  /// [filterByServiceUuid] optionally restricts scanning to devices advertising a specific service UUID.
  Future<void> toggleScan({
    int scanDurationSeconds = 10,
    Guid? filterByServiceUuid,
  }) async {
    if (scanSubscription != null) {
      scanSubscription!.cancel();
    }

    if (_scanning) {
      await FlutterBluePlus.stopScan();
      setState(() {
        this._scanning = false;
      });
      return;
    }

    for (final deviceStateSubscription in _deviceSubscriptions) {
      deviceStateSubscription.cancel();
    }

    //keep devices that are connecte, remove others.
    final connectedResults = widget.availableDevices.where((d) {
      return d.device.isConnected;
    }).toList();

    final disconnectedDeviceIDs = widget.availableDevices
        .where((device) {
          return !device.device.isConnected;
        })
        .map((d) {
          return d.device.remoteId.str;
        })
        .toSet();

    _availableDeviceRemoteIDs.removeWhere((id) {
      return disconnectedDeviceIDs.contains(id);
    });

    _deviceSubscriptions.removeWhere((id) {
      return disconnectedDeviceIDs.contains(id);
    });

    _deviceconnectionStates.removeWhere((id, state) {
      return disconnectedDeviceIDs.contains(id);
    });

    widget.onAvailableDevicesChanged(connectedResults);

    if (mounted) {
      setState(() {
        _scanning = true;
      });
    }

    scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (var result in results) {
        // Avoid duplicates
        if (!_availableDeviceRemoteIDs.contains(result.device.remoteId.str)) {
          _availableDeviceRemoteIDs.add(result.device.remoteId.str);

          final deviceStateSub = result.device.connectionState.listen((
            connectionState,
          ) {
            handleConnectionStateChanged(result, connectionState);
          });

          _deviceSubscriptions.add(deviceStateSub);

          widget.onAvailableDevicesChanged([
            ...widget.availableDevices,
            result,
          ]);
        }
      }
    });

    await FlutterBluePlus.startScan(
      withServices: filterByServiceUuid != null ? [filterByServiceUuid] : [],
      timeout: Duration(seconds: scanDurationSeconds),
    );
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
      return _deviceconnectionStates.containsKey(d.device.remoteId.str) &&
          _deviceconnectionStates[d.device.remoteId.str] ==
              BluetoothConnectionState.connected;
    }).toList();

    final notConnectedScanResults = filteredAvailableDevices.where((d) {
      return !_deviceconnectionStates.containsKey(d.device.remoteId.str) ||
          _deviceconnectionStates[d.device.remoteId.str] !=
              BluetoothConnectionState.connected;
    }).toList();

    ScanButtonState scanButtonState = getScanbuttonState();

    print(_deviceconnectionStates);

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

                      handleTryConnect(scanResult.device);
                    },
                    child: DeviceCard(
                      scanResult: scanResult,
                      selected: false,
                      connecting: this._connectingDeviceRemoteIDs.contains(
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

                      scanResult.device.disconnect();
                    },
                    child: DeviceCard(
                      scanResult: scanResult,
                      selected: true,
                      connecting: false,
                      disconnecting: this._disconnectingDeviceRemoteIDs
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

  Future<void> handleTryConnect(BluetoothDevice device) async {
    if (_connectingDeviceRemoteIDs.contains(device.remoteId.str)) {
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _connectingDeviceRemoteIDs.add(device.remoteId.str);
        });
      }
      await device.connect();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to connect to ${getDeviceDisplayName(device)}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _connectingDeviceRemoteIDs.remove(device.remoteId.str);
        });
      }
    }
  }

  Future<void> handleTrydisconnect(BluetoothDevice device) async {
    if (_disconnectingDeviceRemoteIDs.contains(device.remoteId.str)) {
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _disconnectingDeviceRemoteIDs.add(device.remoteId.str);
        });
      }
      await device.disconnect();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to disconnect from ${getDeviceDisplayName(device)}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _disconnectingDeviceRemoteIDs.remove(device.remoteId.str);
        });
      }
    }
  }

  void handleConnectionStateChanged(
    ScanResult result,
    BluetoothConnectionState state,
  ) {
    print(
      "*****************************STATE CHANGED*****************************",
    );

    print(
      "Device: ${getDeviceDisplayName(result.device)} | State: ${state.toString()}",
    );

    print(
      "*****************************END STATE CHANGED*****************************",
    );

    switch (state) {
      case BluetoothConnectionState.connected:
        {
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text('✅ Connected to ${result.device.platformName}'),
          //   ),
          // );

          break;
        }

      case BluetoothConnectionState.disconnected:
        {
          if (!_deviceconnectionStates.containsKey(
            result.device.remoteId.str,
          )) {
            break;
          }

          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text(
          //       '🔌 Disconnected from ${result.device.platformName}',
          //     ),
          //   ),
          // );

          break;
        }

      default:
        {
          break;
        }
    }

    if (mounted) {
      setState(() {
        _connectingDeviceRemoteIDs.remove(result.device.remoteId.str);
        _disconnectingDeviceRemoteIDs.remove(result.device.remoteId.str);
        _deviceconnectionStates[result.device.remoteId.str] = state;
      });
    }
  }

  ScanButtonState getScanbuttonState() {
    if (this._scanning) {
      return ScanButtonState(text: "Scanning...", action: this.toggleScan);
    }

    if (this._bleAdapterState == BluetoothAdapterState.turningOn) {
      return ScanButtonState(text: "Activating...", action: null);
    }

    if (this._bleAdapterState != BluetoothAdapterState.on) {
      return ScanButtonState(
        text: "Activate Bluetooth",
        action: Platform.isAndroid ? this.activateBluetooth : null,
      );
    }

    return ScanButtonState(text: "Scan for Devices", action: this.toggleScan);
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    // _baseSubscriptions.forEach((s) {
    //   s.cancel();
    // });

    // _deviceSubscriptions.forEach((s) {
    //   s.cancel();
    // });

    super.dispose();
  }
}
