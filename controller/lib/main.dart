import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:controller/screens/color/color_screen.dart';
import 'package:controller/screens/connect/bluetooth_device_manager.dart';
import 'package:controller/screens/connect/connect.dart';
import 'package:controller/screens/control/control.dart';
import 'package:controller/utilities/bluetooth_device_utilities.dart';
import 'package:controller/utilities/light_animation_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canvas LED Controller',
      scrollBehavior: WebScrollBehavior(),
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        scaffoldBackgroundColor: Colors.black87,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 53, 9, 133),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white70,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 53, 9, 133),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: Application(),
    );
  }
}

class Application extends StatefulWidget {
  Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application>
    with SingleTickerProviderStateMixin {
  final HashSet<String> availableDeviceRemoteIDs = HashSet<String>();
  final HashSet<String> connectingDeviceRemoteIDs = HashSet<String>();
  final HashSet<String> disconnectingDeviceRemoteIDs = HashSet<String>();

  BluetoothAdapterState bleAdapterState = FlutterBluePlus.adapterStateNow;

  final List<StreamSubscription> baseSubscriptions = [];
  final List<StreamSubscription> deviceSubscriptions = [];

  late final HashMap<String, BluetoothConnectionState> deviceconnectionStates;

  late BluetoothDeviceManager bluetoothController;
  int _pageIndex = 0;
  List<ScanResult> availableDevices = [];
  Color selectedColor = Colors.white;
  LightAnimationType animationType = LightAnimationType.Flat;
  late AnimationController animationController;
  late bool rainbowMode = false;
  bool scanning = false;

  int _offsetEvery = 1;
  double _timeDelay = 3.0;

  _ApplicationState() {
    deviceconnectionStates = HashMap<String, BluetoothConnectionState>();
  }

  @override
  void initState() {
    super.initState();

    final adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      if (mounted) {
        setState(() {
          bleAdapterState = state;
        });
      }
    });

    final isScanningSub = FlutterBluePlus.isScanning.listen((isScanning) {
      if (!isScanning) {
        if (mounted) {
          setState(() {
            this.scanning = false;
          });
        }
      }
    });

    for (final device in this.availableDevices) {
      this.deviceconnectionStates[device.device.remoteId.str] =
          device.device.isConnected
          ? BluetoothConnectionState.connected
          : BluetoothConnectionState.disconnected;

      final deviceStateSub = device.device.connectionState.listen((
        connectionState,
      ) {
        handleConnectionStateChanged(device, connectionState);
      });

      deviceSubscriptions.add(deviceStateSub);
    }

    rainbowMode = false;

    animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _setPage(int pageIndex) {
    setState(() {
      _pageIndex = pageIndex;
    });
  }

  void _sendControllerColor() {
    final lightness = HSLColor.fromColor(this.selectedColor).lightness;

    final hue = 360 + this.animationController.value * -360;
    final color = HSLColor.fromAHSL(1.0, hue, 1.0, lightness);

    setState(() {
      this.selectedColor = color.toColor();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      Connect(
        availableDevices: this.availableDevices,
        bleAdapterState: this.bleAdapterState,
        connectingDeviceRemoteIDs: this.connectingDeviceRemoteIDs,
        deviceconnectionStates: this.deviceconnectionStates,
        disconnectingDeviceRemoteIDs: this.disconnectingDeviceRemoteIDs,
        handleToggleScan: this.toggleScan,
        handleTryConnect: this.handleTryConnect,
        handleTrydisconnect: this.handleTrydisconnect,
        scanning: this.scanning,
      ),
      ColorScreen(
        color: this.selectedColor,
        raindowMode: this.rainbowMode,
        onSetRainbowMode: (rainbowMode) {
          if (rainbowMode) {
            this.animationController.addListener(_sendControllerColor);
          } else {
            this.animationController.removeListener(_sendControllerColor);
          }

          setState(() {
            this.rainbowMode = rainbowMode;
          });
        },
        animationController: this.animationController,
        onColorSelected: (color) {
          setState(() {
            this.selectedColor = color;
          });
        },
      ),
      Control(
        color: this.selectedColor,
        availableDevices: this.availableDevices,
        offsetEvery: this._offsetEvery,
        timeDelay: this._timeDelay,
        onOffsetEveryChange: (offsetEvery) {
          setState(() {
            this._offsetEvery = offsetEvery;
          });
        },
        ontimeDelayChange: (delay) {
          setState(() {
            this._timeDelay = delay;
          });
        },
        onSelectAnimation: (type) {
          setState(() {
            this.animationType = type;
          });
        },
        selectedAnimation: this.animationType,
      ),
    ];
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: screens[_pageIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _pageIndex,
        onTap: _setPage,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth_connected_sharp),
            label: 'Connect',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.color_lens_sharp),
            label: 'Color',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_remote_outlined),
            label: 'Control',
          ),
        ],
      ),
    );
  }

  Future<void> handleTryConnect(BluetoothDevice device) async {
    if (this.connectingDeviceRemoteIDs.contains(device.remoteId.str)) {
      return;
    }

    try {
      if (mounted) {
        setState(() {
          this.connectingDeviceRemoteIDs.add(device.remoteId.str);
        });
      }
      await device.connect();

      // _handleAvailableDevicesChanged()
    } catch (e) {
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
          this.connectingDeviceRemoteIDs.remove(device.remoteId.str);
        });
      }
    }
  }

  Future<void> handleTrydisconnect(BluetoothDevice device) async {
    if (this.disconnectingDeviceRemoteIDs.contains(device.remoteId.str)) {
      return;
    }

    try {
      if (mounted) {
        setState(() {
          this.disconnectingDeviceRemoteIDs.add(device.remoteId.str);
        });
      }
      await device.disconnect();
    } catch (e) {
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
          this.disconnectingDeviceRemoteIDs.remove(device.remoteId.str);
        });
      }
    }
  }

  HashMap<String, StreamSubscription> deviceServiceSubs =
      HashMap<String, StreamSubscription>();
  HashMap<String, HashMap<String, List<BluetoothCharacteristic>>>
  characteristicsByServiceByDeviceID =
      HashMap<String, HashMap<String, List<BluetoothCharacteristic>>>();

  void handleConnectionStateChanged(
    ScanResult result,
    BluetoothConnectionState state,
  ) async {
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
          if (!deviceconnectionStates.containsKey(result.device.remoteId.str)) {
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

    //Handle tracking connection state
    if (mounted) {
      setState(() {
        connectingDeviceRemoteIDs.remove(result.device.remoteId.str);
        disconnectingDeviceRemoteIDs.remove(result.device.remoteId.str);
        deviceconnectionStates[result.device.remoteId.str] = state;
      });
    }

    //Handle tracking services and characteristics:

    //Remove old existing sub for device if not connected and return
    if (state != BluetoothConnectionState.connected) {
      final sub = deviceServiceSubs.containsKey(result.device.remoteId.str)
          ? deviceServiceSubs[result.device.remoteId.str]
          : null;

      await sub?.cancel();

      return;
    }

    //subscribe to services changed.
    final deviceServiceSub = result.device.onServicesReset.listen((d) async {
      if (result.device.isDisconnected) {
        return;
      }
      final newServices = await result.device.discoverServices();
      _handleNewServices(result.device, newServices);
    });

    deviceServiceSubs[result.device.remoteId.str] = deviceServiceSub;

    final newServices = await result.device.discoverServices();
    _handleNewServices(result.device, newServices);

    print(
      "************************* SERVICES DISCOVERED!!!!!!!!!!!!!!!!!!!!! *************************",
    );
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

    if (this.scanning) {
      await FlutterBluePlus.stopScan();
      setState(() {
        this.scanning = false;
      });
      return;
    }

    for (final deviceStateSubscription in this.deviceSubscriptions) {
      deviceStateSubscription.cancel();
    }

    //keep devices that are connecte, remove others.
    final connectedResults = this.availableDevices.where((d) {
      return d.device.isConnected;
    }).toList();

    final disconnectedDeviceIDs = this.availableDevices
        .where((device) {
          return !device.device.isConnected;
        })
        .map((d) {
          return d.device.remoteId.str;
        })
        .toSet();

    setState(() {
      this.availableDevices = connectedResults;
      scanning = true;

      availableDeviceRemoteIDs.removeWhere((id) {
        return disconnectedDeviceIDs.contains(id);
      });

      deviceSubscriptions.removeWhere((id) {
        return disconnectedDeviceIDs.contains(id);
      });

      deviceconnectionStates.removeWhere((id, state) {
        return disconnectedDeviceIDs.contains(id);
      });
    });

    scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      for (var result in results) {
        // Avoid duplicates
        if (!availableDeviceRemoteIDs.contains(result.device.remoteId.str)) {
          availableDeviceRemoteIDs.add(result.device.remoteId.str);

          final deviceStateSub = result.device.connectionState.listen((
            connectionState,
          ) {
            handleConnectionStateChanged(result, connectionState);
          });

          deviceSubscriptions.add(deviceStateSub);

          setState(() {
            this.availableDevices = [...this.availableDevices, result];
          });
        }
      }
    });

    await FlutterBluePlus.startScan(
      withServices: filterByServiceUuid != null ? [filterByServiceUuid] : [],
      timeout: Duration(seconds: scanDurationSeconds),
    );
  }

  void _handleNewServices(
    BluetoothDevice device,
    List<BluetoothService> services,
  ) {
    for (final service in services) {
      if (!characteristicsByServiceByDeviceID.containsKey(
        device.remoteId.str,
      )) {
        characteristicsByServiceByDeviceID[device.remoteId.str] =
            HashMap<String, List<BluetoothCharacteristic>>();
      }

      if (!characteristicsByServiceByDeviceID[device.remoteId.str]!.containsKey(
        service.serviceUuid.str,
      )) {
        characteristicsByServiceByDeviceID[device.remoteId.str]![service
                .serviceUuid
                .str] =
            [];
      }

      for (final characteristic in service.characteristics) {
        characteristicsByServiceByDeviceID[device.remoteId.str]![service
                .serviceUuid
                .str]!
            .add(characteristic);
      }
    }

    print("************* SErvices and chars gathered!!!");

    print(characteristicsByServiceByDeviceID);
  }

  Future<void> sendCommandToConnectedDevices() async {
    final connectedDevices = this.availableDevices.where((element) {
      return element.device.isConnected;
    });

    for (final connectedDevice in connectedDevices) {
      final deviceServices =
          this.characteristicsByServiceByDeviceID[connectedDevice
              .device
              .remoteId
              .str];

      if (deviceServices == null) {
        continue;
      }

      //TODO: find the appropriate service ID and the appropriate characteristic and send the command.
    }
  }
}

class WebScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}
