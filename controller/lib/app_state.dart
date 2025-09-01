// app_state.dart - Create this as a separate file
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:frame_control/Services/color_service.dart';
import 'package:frame_control/screens/presets/preset.dart';
import 'package:frame_control/utilities/bluetooth_device_utilities.dart';
import 'package:frame_control/utilities/light_animation_type.dart';
import 'package:frame_control/utilities/rainbow_mode_utilities.dart';
import 'package:frame_control/utilities/throttle.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  static const String _presetsKey = 'presets';
  // Bluetooth related state
  final HashSet<String> _availableDeviceRemoteIDs = HashSet<String>();
  final HashSet<String> _connectingDeviceRemoteIDs = HashSet<String>();
  final HashSet<String> _disconnectingDeviceRemoteIDs = HashSet<String>();

  BluetoothAdapterState _bleAdapterState = BluetoothAdapterState.on;
  List<ScanResult> _availableDevices = [];
  bool _scanning = false;
  late HashMap<String, BluetoothConnectionState> _deviceConnectionStates;

  // UI State
  int _pageIndex = 0;

  // Color and animation state
  Color _selectedColor = Colors.white;
  LightAnimationType _animationType = LightAnimationType.Flat;
  bool _rainbowMode = false;
  double _rate = 5.5;
  int _offsetEvery = 1;
  double _timeDelay = 3.0;
  String _activePreset = "";

  // Animation controller (needs to be set from outside)
  late AnimationController _animationController;

  // Subscriptions and streams
  final List<StreamSubscription> _baseSubscriptions = [];
  final List<StreamSubscription> _deviceSubscriptions = [];
  HashMap<String, StreamSubscription> _deviceServiceSubs =
      HashMap<String, StreamSubscription>();
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Throttled functions
  late void Function(Color) _throttledColor;
  late void Function(bool) _throttledRainbowMode;
  late void Function(String) _throttledColorPattern;
  late void Function(double) _throttledRate;

  AppState() {
    _deviceConnectionStates = HashMap<String, BluetoothConnectionState>();
    _initializeThrottledFunctions();
  }

  void _initializeThrottledFunctions() {
    _throttledColor = throttle<Color>(
      (c) => sendColorToConnectedDevices(c),
      Duration(milliseconds: 100),
    );

    _throttledRainbowMode = throttle<bool>(
      (rainbowMode) => sendRainbowModeToConnectedDevices(rainbowMode),
      Duration(milliseconds: 100),
    );

    _throttledColorPattern = throttle<String>(
      (pattern) => sendColorPatternToConnectedDevices(pattern),
      Duration(milliseconds: 100),
    );

    _throttledRate = throttle<double>(
      (rate) => sendRateToConnectedDevices(rate),
      Duration(milliseconds: 100),
    );
  }

  List<Preset> _presets = [];

  List<Preset> get presets => _presets;

  //Presets state
  Future<void> loadPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = prefs.getString(_presetsKey) ?? '[]';
    final List<dynamic> presetsList = json.decode(presetsJson);
    _presets = presetsList.map((json) => Preset.fromJson(json)).toList();
    notifyListeners();
  }

  Future<void> savePresets() async {
    final prefs = await SharedPreferences.getInstance();
    final presetsJson = json.encode(_presets.map((p) => p.toJson()).toList());
    await prefs.setString(_presetsKey, presetsJson);
  }

  void addPreset(String name) {
    final preset = Preset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      color: _selectedColor,
      pattern: _animationType,
      rainbowMode: _rainbowMode,
      createdAt: DateTime.now(),
    );

    _presets.add(preset);
    _activePreset = preset.id;
    notifyListeners();
    savePresets();
  }

  void removePreset(String presetId) {
    _presets.removeWhere((preset) => preset.id == presetId);
    notifyListeners();
    savePresets();
  }

  void applyPreset(Preset preset) {
    setSelectedColor(preset.color);
    setAnimationType(preset.pattern);
    setRainbowMode(preset.rainbowMode);
    this._activePreset = preset.id;
    notifyListeners();
  }

  // Getters
  HashSet<String> get availableDeviceRemoteIDs => _availableDeviceRemoteIDs;
  HashSet<String> get connectingDeviceRemoteIDs => _connectingDeviceRemoteIDs;
  HashSet<String> get disconnectingDeviceRemoteIDs =>
      _disconnectingDeviceRemoteIDs;
  BluetoothAdapterState get bleAdapterState => _bleAdapterState;
  List<ScanResult> get availableDevices => _availableDevices;
  bool get scanning => _scanning;
  HashMap<String, BluetoothConnectionState> get deviceConnectionStates =>
      _deviceConnectionStates;
  int get pageIndex => _pageIndex;
  Color get selectedColor => _selectedColor;
  LightAnimationType get animationType => _animationType;
  bool get rainbowMode => _rainbowMode;
  double get rate => _rate;
  int get offsetEvery => _offsetEvery;
  double get timeDelay => _timeDelay;
  String get activePreset => _activePreset;
  AnimationController get animationController => _animationController;

  // Setters
  void setAnimationController(AnimationController controller) {
    _animationController = controller;
    notifyListeners();
  }

  void setBleAdapterState(BluetoothAdapterState state) {
    _bleAdapterState = state;
    notifyListeners();
  }

  void setScanning(bool scanning) {
    _scanning = scanning;
    notifyListeners();
  }

  void setPageIndex(int index) {
    _pageIndex = index;
    notifyListeners();
  }

  void setSelectedColor(Color color) {
    _selectedColor = color;
    _activePreset = "";
    notifyListeners();
    _throttledColor(color);
  }

  void setRainbowMode(bool rainbowMode) {
    if (rainbowMode && _animationController != null) {
      _animationController!.addListener(_sendControllerColor);
    } else if (_animationController != null) {
      _animationController!.removeListener(_sendControllerColor);
      sendColorToConnectedDevices(_selectedColor);
    }

    _activePreset = "";
    _rainbowMode = rainbowMode;
    notifyListeners();
    _throttledRainbowMode(rainbowMode);
  }

  void setAnimationType(LightAnimationType type) {
    _animationType = type;
    _activePreset = "";
    notifyListeners();
    _throttledColorPattern(type.command);
  }

  void setRate(double rate) {
    _rate = rate;
    _activePreset = "";
    notifyListeners();
    _throttledRate(rate);
  }

  void setOffsetEvery(int offsetEvery) {
    _offsetEvery = offsetEvery;
    _activePreset = "";
    notifyListeners();
  }

  void setTimeDelay(double timeDelay) {
    _timeDelay = timeDelay;
    _activePreset = "";
    notifyListeners();
  }

  void _sendControllerColor() {
    if (_animationController == null) return;

    final lightness = HSLColor.fromColor(_selectedColor).lightness;
    _selectedColor = calculateCurrentRainbowColor(
      _animationController!.value,
      lightness,
    );

    notifyListeners();
  }

  void initialize() {
    final adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      setBleAdapterState(state);
    });

    final isScanningSub = FlutterBluePlus.isScanning.listen((isScanning) {
      if (!isScanning) {
        setScanning(false);
      }
    });

    _baseSubscriptions.addAll([adapterStateSub, isScanningSub]);

    for (final device in _availableDevices) {
      _deviceConnectionStates[device.device.remoteId.str] =
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

  Future<void> handleTryConnect(BluetoothDevice device) async {
    if (_connectingDeviceRemoteIDs.contains(device.remoteId.str)) {
      return;
    }

    try {
      _connectingDeviceRemoteIDs.add(device.remoteId.str);
      notifyListeners();

      await device.connect();
    } catch (e) {
      rethrow;
    } finally {
      _connectingDeviceRemoteIDs.remove(device.remoteId.str);
      notifyListeners();
    }
  }

  Future<void> handleTryDisconnect(BluetoothDevice device) async {
    if (_disconnectingDeviceRemoteIDs.contains(device.remoteId.str)) {
      return;
    }

    try {
      _disconnectingDeviceRemoteIDs.add(device.remoteId.str);
      notifyListeners();

      await device.disconnect();
    } catch (e) {
      // Handle error
      rethrow;
    } finally {
      _disconnectingDeviceRemoteIDs.remove(device.remoteId.str);
      notifyListeners();
    }
  }

  void handleConnectionStateChanged(
    ScanResult result,
    BluetoothConnectionState state,
  ) async {
    switch (state) {
      case BluetoothConnectionState.connected:
        break;
      case BluetoothConnectionState.disconnected:
        if (!_deviceConnectionStates.containsKey(result.device.remoteId.str)) {
          break;
        }
        break;
      default:
        break;
    }

    _connectingDeviceRemoteIDs.remove(result.device.remoteId.str);
    _disconnectingDeviceRemoteIDs.remove(result.device.remoteId.str);
    _deviceConnectionStates[result.device.remoteId.str] = state;
    notifyListeners();

    if (state != BluetoothConnectionState.connected) {
      final sub = _deviceServiceSubs.containsKey(result.device.remoteId.str)
          ? _deviceServiceSubs[result.device.remoteId.str]
          : null;

      await sub?.cancel();
      return;
    }

    final deviceServiceSub = result.device.onServicesReset.listen((d) async {
      if (result.device.isDisconnected) {
        return;
      }
      final newServices = await _discoverDeviceServicesOrDisconnect(
        result.device,
      );
      _handleNewServices(result.device, newServices);
    });

    _deviceServiceSubs[result.device.remoteId.str] = deviceServiceSub;

    final newServices = await _discoverDeviceServicesOrDisconnect(
      result.device,
    );
    _handleNewServices(result.device, newServices);
  }

  Future<List<BluetoothService>> _discoverDeviceServicesOrDisconnect(
    BluetoothDevice device,
  ) async {
    try {
      return await device.discoverServices();
    } catch (e) {
      await device.disconnect();
      return [];
    }
  }

  Future<void> toggleScan({
    int scanDurationSeconds = 10,
    Guid? filterByServiceUuid,
  }) async {
    if (_scanSubscription != null) {
      _scanSubscription!.cancel();
    }

    if (_scanning) {
      await FlutterBluePlus.stopScan();
      setScanning(false);
      return;
    }

    for (final deviceStateSubscription in _deviceSubscriptions) {
      deviceStateSubscription.cancel();
    }

    final connectedResults = _availableDevices.where((d) {
      return d.device.isConnected;
    }).toList();

    final disconnectedDeviceIDs = _availableDevices
        .where((device) {
          return !device.device.isConnected;
        })
        .map((d) {
          return d.device.remoteId.str;
        })
        .toSet();

    _availableDevices = connectedResults;
    setScanning(true);

    _availableDeviceRemoteIDs.removeWhere((id) {
      return disconnectedDeviceIDs.contains(id);
    });

    _deviceSubscriptions.removeWhere((id) {
      return disconnectedDeviceIDs.contains(id);
    });

    _deviceConnectionStates.removeWhere((id, state) {
      return disconnectedDeviceIDs.contains(id);
    });

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        if (!_availableDeviceRemoteIDs.contains(result.device.remoteId.str)) {
          _availableDeviceRemoteIDs.add(result.device.remoteId.str);

          final deviceStateSub = result.device.connectionState.listen((
            connectionState,
          ) {
            handleConnectionStateChanged(result, connectionState);
          });

          _deviceSubscriptions.add(deviceStateSub);
          _availableDevices = [..._availableDevices, result];
          notifyListeners();
        }
      }
    });

    await FlutterBluePlus.startScan(
      withServices: [colorServiceUUID],
      timeout: Duration(seconds: scanDurationSeconds),
    );
  }

  Future<void> _handleNewServices(
    BluetoothDevice device,
    List<BluetoothService> services,
  ) async {
    if (!device.isConnected) {
      return;
    }

    final authChar = services
        .where((s) => s.serviceUuid == securityServiceUUID)
        .firstOrNull
        ?.characteristics
        .where((c) => c.characteristicUuid == authenticateCharacteristicUUID)
        .firstOrNull;

    if (authChar == null) {
      return;
    }

    try {
      await authChar.write(
        authenticatePasswordUUID.str.codeUnits,
        withoutResponse: false,
      );

      authChar.setNotifyValue(true);
      final authCharStream = authChar.lastValueStream.listen((value) {
        final response = String.fromCharCodes(value);
        if (response != "OK" && response != authenticatePasswordUUID.str) {
          device.disconnect();
          return;
        }

        try {
          for (final service in services) {
            for (final characteristic in service.characteristics) {
              _handleCharacteristic(device, characteristic);
            }
          }
        } catch (e) {
          device.disconnect();
          return;
        }
      });
    } catch (e) {
      device.disconnect();
      return;
    }
  }

  void _handleCharacteristic(
    BluetoothDevice device,
    BluetoothCharacteristic characteristic,
  ) {
    if (characteristic.serviceUuid == colorServiceUUID &&
        characteristic.characteristicUuid == rainbowModeCharacteristicUUID) {
      characteristic
          .read()
          .then((value) {
            final firstValue = value[0];
            _rainbowMode = firstValue > 0;
            notifyListeners();
          })
          .catchError((e) {});

      if (characteristic.isNotifying) {
        characteristic.setNotifyValue(true);
        final rainbowModeCharStream = characteristic.lastValueStream.listen((
          value,
        ) {
          final firstValue = value[0];
          _rainbowMode = firstValue > 0;
          notifyListeners();
        });

        device.cancelWhenDisconnected(rainbowModeCharStream);
      }
    }

    if (characteristic.serviceUuid == colorServiceUUID &&
        characteristic.characteristicUuid == colorCharacteristicUUID) {
      characteristic
          .read()
          .then((value) {
            final b = value[0];
            final g = value[1];
            final r = value[2];
            _selectedColor = Color.fromARGB(255, r, g, b);
            notifyListeners();
          })
          .catchError((e) {});

      if (characteristic.isNotifying) {
        characteristic.setNotifyValue(true);
        final colorModeCharStream = characteristic.lastValueStream.listen((
          value,
        ) {
          final b = value[0];
          final g = value[1];
          final r = value[2];
          _selectedColor = Color.fromARGB(255, r, g, b);
          notifyListeners();
        });

        device.cancelWhenDisconnected(colorModeCharStream);
      }
    }

    if (characteristic.serviceUuid == colorServiceUUID &&
        characteristic.characteristicUuid == patternCharacteristicUUID) {
      characteristic
          .read()
          .then((value) {
            final stringValue = String.fromCharCodes(value);
            _animationType = LightAnimationType.values.firstWhere(
              (element) => element.command == stringValue,
              orElse: () => LightAnimationType.Flat,
            );
            notifyListeners();
          })
          .catchError((e) {});

      if (characteristic.isNotifying) {
        characteristic.setNotifyValue(true);
        final patternCharStream = characteristic.lastValueStream.listen((
          value,
        ) {
          final stringValue = String.fromCharCodes(value);
          _animationType = LightAnimationType.values.firstWhere(
            (element) => element.command == stringValue,
            orElse: () => LightAnimationType.Flat,
          );
          notifyListeners();
        });

        device.cancelWhenDisconnected(patternCharStream);
      }
    }

    if (characteristic.serviceUuid == colorServiceUUID &&
        characteristic.characteristicUuid == rateCharacteristicUUID) {
      characteristic
          .read()
          .then((value) {
            final stringValue = String.fromCharCodes(value);
            print("Rate: $stringValue");
          })
          .catchError((e) {});

      if (characteristic.isNotifying) {
        characteristic.setNotifyValue(true);
        final rateCharStream = characteristic.lastValueStream.listen((value) {
          print("Rate: ${String.fromCharCodes(value)}");
        });

        device.cancelWhenDisconnected(rateCharStream);
      }
    }
  }

  Future<void> sendColorToConnectedDevices(Color color) async {
    final connectedDevices = _availableDevices.where((element) {
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
    final connectedDevices = _availableDevices.where((element) {
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
    final connectedDevices = _availableDevices.where((element) {
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
    final connectedDevices = _availableDevices.where((element) {
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

  @override
  void dispose() {
    for (final subscription in _baseSubscriptions) {
      subscription.cancel();
    }
    for (final subscription in _deviceSubscriptions) {
      subscription.cancel();
    }
    for (final subscription in _deviceServiceSubs.values) {
      subscription.cancel();
    }
    _scanSubscription?.cancel();
    super.dispose();
  }
}
