import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:frame_control/Services/color_service.dart';
import 'package:frame_control/screens/color/color_screen.dart';
import 'package:frame_control/screens/connect/bluetooth_device_manager.dart';
import 'package:frame_control/screens/connect/connect.dart';
import 'package:frame_control/screens/control/control.dart';
import 'package:frame_control/utilities/bluetooth_device_utilities.dart';
import 'package:frame_control/utilities/light_animation_type.dart';
import 'package:frame_control/utilities/throttle.dart';
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

  double _rate = 5.5;

  int _offsetEvery = 1;
  double _timeDelay = 3.0;
  late void Function(Color) throttledColor;
  late void Function(bool) throttledRainbowMode;
  late void Function(String) throttledColorPattern;
  late void Function(double) throttledRate;

  _ApplicationState() {
    deviceconnectionStates = HashMap<String, BluetoothConnectionState>();
    throttledColor = throttle<Color>(
      (c) => sendColorToConnectedDevices(c),
      Duration(milliseconds: 100),
    );

    throttledRainbowMode = throttle<bool>(
      (rainbowMode) => sendRainbowModeToConnectedDevices(rainbowMode),
      Duration(milliseconds: 100),
    );

    throttledColorPattern = throttle<String>(
      (pattern) => sendColorPatternToConnectedDevices(pattern),
      Duration(milliseconds: 100),
    );

    throttledRate = throttle<double>(
      (rate) => sendRateToConnectedDevices(rate),
      Duration(milliseconds: 100),
    );
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
            sendColorToConnectedDevices(this.selectedColor);
          }

          setState(() {
            this.rainbowMode = rainbowMode;
          });

          throttledRainbowMode(rainbowMode);
        },
        animationController: this.animationController,
        onColorSelected: (color) {
          setState(() {
            this.selectedColor = color;
          });

          throttledColor(color);
        },
      ),
      Control(
        color: this.selectedColor,
        availableDevices: this.availableDevices,
        offsetEvery: this._offsetEvery,
        timeDelay: this._timeDelay,
        rate: this._rate,
        onRateChange: (newRate) {
          setState(() {
            this._rate = newRate;
          });

          throttledRate(newRate);
        },
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

          throttledColorPattern(type.command);
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
  // HashMap<String, HashMap<String, List<BluetoothCharacteristic>>>
  // characteristicsByServiceByDeviceID =
  //     HashMap<String, HashMap<String, List<BluetoothCharacteristic>>>();

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
      final newServices = await _discoverDeviceServicesOrDisconnect(
        result.device,
      );
      _handleNewServices(result.device, newServices);
    });

    deviceServiceSubs[result.device.remoteId.str] = deviceServiceSub;

    final newServices = await _discoverDeviceServicesOrDisconnect(
      result.device,
    );
    _handleNewServices(result.device, newServices);

    print(
      "************************* SERVICES DISCOVERED!!!!!!!!!!!!!!!!!!!!! *************************",
    );
  }

  Future<List<BluetoothService>> _discoverDeviceServicesOrDisconnect(
    BluetoothDevice device,
  ) async {
    try {
      return await device.discoverServices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to discover services for ${getDeviceDisplayName(device)}: $e',
            ),
          ),
        );
      }

      await device.disconnect();

      return [];
    }

    throw Exception("Unreachable code error");
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
      withServices: [colorServiceUUID],
      timeout: Duration(seconds: scanDurationSeconds),
    );
  }

  void _handleNewServices(
    BluetoothDevice device,
    List<BluetoothService> services,
  ) {
    if (!device.isConnected) {
      return;
    }

    try {
      //Subscribe to services that notify, aka both the rainbow char and the color char of the color service:
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.serviceUuid == colorServiceUUID &&
              characteristic.characteristicUuid ==
                  rainbowModeCharacteristicUUID) {
            //Subscribe!

            //First read, then sub to the value.
            characteristic
                .read()
                .then((value) {
                  if (mounted) {
                    setState(() {
                      final firstValue = value[0];
                      if (mounted) {
                        setState(() {
                          this.rainbowMode = firstValue > 0;
                        });
                      }
                    });
                  }
                })
                .catchError((e) {});

            if (characteristic.isNotifying) {
              characteristic.setNotifyValue(true);
              final rainbowModeCharStream = characteristic.lastValueStream
                  .listen((value) {
                    final firstValue = value[0];
                    if (mounted) {
                      setState(() {
                        this.rainbowMode = firstValue > 0;
                      });
                    }
                  });

              device.cancelWhenDisconnected(rainbowModeCharStream);
            }

            continue;
          }

          if (characteristic.serviceUuid == colorServiceUUID &&
              characteristic.characteristicUuid == colorCharacteristicUUID) {
            //First read, then sub.
            characteristic
                .read()
                .then((value) {
                  final b = value[0];
                  final g = value[1];
                  final r = value[2];
                  if (mounted) {
                    setState(() {
                      this.selectedColor = Color.fromARGB(255, r, g, b);
                    });
                  }
                })
                .catchError((e) {});

            if (characteristic.isNotifying) {
              //Subscribe!
              characteristic.setNotifyValue(true);
              final colorModeCharStream = characteristic.lastValueStream.listen(
                (value) {
                  final b = value[0];
                  final g = value[1];
                  final r = value[2];
                  if (mounted) {
                    setState(() {
                      this.selectedColor = Color.fromARGB(255, r, g, b);
                    });
                  }
                },
              );

              device.cancelWhenDisconnected(colorModeCharStream);
            }

            continue;
          }

          if (characteristic.serviceUuid == colorServiceUUID &&
              characteristic.characteristicUuid == patternCharacteristicUUID) {
            //First read, then sub
            characteristic
                .read()
                .then((value) {
                  if (mounted) {
                    final stringValue = String.fromCharCodes(value);
                    setState(() {
                      this.animationType = LightAnimationType.values.firstWhere(
                        (element) {
                          return element.command == stringValue;
                        },
                        orElse: () {
                          return LightAnimationType.Flat;
                        },
                      );
                    });
                  }
                })
                .catchError((e) {});

            if (characteristic.isNotifying) {
              //Subscribe!
              characteristic.setNotifyValue(true);
              final patternCharStream = characteristic.lastValueStream.listen((
                value,
              ) {
                if (mounted) {
                  final stringValue = String.fromCharCodes(value);
                  setState(() {
                    this.animationType = LightAnimationType.values.firstWhere(
                      (element) {
                        return element.command == stringValue;
                      },
                      orElse: () {
                        return LightAnimationType.Flat;
                      },
                    );
                  });
                }
              });

              device.cancelWhenDisconnected(patternCharStream);
            }

            continue;
          }

          if (characteristic.serviceUuid == colorServiceUUID &&
              characteristic.characteristicUuid == rateCharacteristicUUID) {
            //First read, then sub
            characteristic
                .read()
                .then((value) {
                  if (mounted) {
                    final stringValue = String.fromCharCodes(value);
                    // setState(() {
                    //   this.animationType = LightAnimationType.values.firstWhere(
                    //     (element) {
                    //       return element.command == stringValue;
                    //     },
                    //     orElse: () {
                    //       return LightAnimationType.Flat;
                    //     },
                    //   );
                    // });
                  }
                })
                .catchError((e) {});

            if (characteristic.isNotifying) {
              //Subscribe!
              characteristic.setNotifyValue(true);
              final patternCharStream = characteristic.lastValueStream.listen((
                value,
              ) {
                // if (mounted) {
                //   final stringValue = String.fromCharCodes(value);
                //   setState(() {
                //     this.animationType = LightAnimationType.values.firstWhere(
                //       (element) {
                //         return element.command == stringValue;
                //       },
                //       orElse: () {
                //         return LightAnimationType.Flat;
                //       },
                //     );
                //   });
                // }
              });

              device.cancelWhenDisconnected(patternCharStream);
            }

            continue;
          }
        }
      }
    } catch (e) {
      //do nothing, it's cool :)
    }
  }

  Future<void> sendColorToConnectedDevices(Color color) async {
    final connectedDevices = this.availableDevices.where((element) {
      return element.device.isConnected;
    });
    try {
      for (final connectedDevice in connectedDevices) {
        for (final service in connectedDevice.device.servicesList) {
          for (final characteristic in service.characteristics) {
            if (characteristic.serviceUuid == colorServiceUUID &&
                characteristic.characteristicUuid == colorCharacteristicUUID) {
              final r = (color.r * 255).floor();
              final b = (color.b * 255).floor();
              final g = (color.g * 255).floor();
              await characteristic.write([r, g, b]);
              return;
            }
          }
        }
      }
    } catch (e) {}
  }

  Future<void> sendRainbowModeToConnectedDevices(bool rainbowModeActive) async {
    final connectedDevices = this.availableDevices.where((element) {
      return element.device.isConnected;
    });

    for (final connectedDevice in connectedDevices) {
      for (final service in connectedDevice.device.servicesList) {
        for (final characteristic in service.characteristics) {
          if (characteristic.serviceUuid == colorServiceUUID &&
              characteristic.characteristicUuid ==
                  rainbowModeCharacteristicUUID) {
            await characteristic.write(
              rainbowModeActive ? "1".codeUnits : "0".codeUnits,
            );
            return;
          }
        }
      }
    }
  }

  Future<void> sendColorPatternToConnectedDevices(String colorPattern) async {
    final connectedDevices = this.availableDevices.where((element) {
      return element.device.isConnected;
    });
    try {
      for (final connectedDevice in connectedDevices) {
        for (final service in connectedDevice.device.servicesList) {
          for (final characteristic in service.characteristics) {
            if (characteristic.serviceUuid == colorServiceUUID &&
                characteristic.characteristicUuid ==
                    patternCharacteristicUUID) {
              await characteristic.write(colorPattern.codeUnits);
              return;
            }
          }
        }
      }
    } catch (e) {}
  }

  Future<void> sendRateToConnectedDevices(double rate) async {
    final connectedDevices = this.availableDevices.where((element) {
      return element.device.isConnected;
    });

    try {
      for (final connectedDevice in connectedDevices) {
        for (final service in connectedDevice.device.servicesList) {
          for (final characteristic in service.characteristics) {
            if (characteristic.serviceUuid == colorServiceUUID &&
                characteristic.characteristicUuid == rateCharacteristicUUID) {
              final byteData = ByteData(8);

              final adjustedRate = pow(2, (rate - 5.5) / 1.5).toDouble();
              byteData.setFloat64(0, adjustedRate, Endian.little);
              await characteristic.write(byteData.buffer.asInt8List());
              return;
            }
          }
        }
      }
    } catch (e) {}
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
