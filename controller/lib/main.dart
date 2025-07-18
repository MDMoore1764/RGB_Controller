import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:controller/screens/color/color_screen.dart';
import 'package:controller/screens/connect/bluetooth_device_manager.dart';
import 'package:controller/screens/connect/connect.dart';
import 'package:controller/screens/control/control.dart';
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
  late BluetoothDeviceManager bluetoothController;

  int _pageIndex = 0;
  List<ScanResult> availableDevices = [];
  Color selectedColor = Colors.white;
  LightAnimationType animationType = LightAnimationType.Flat;
  late AnimationController animationController;
  late bool rainbowMode = false;

  int _offsetEvery = 1;
  double _timeDelay = 3.0;

  _ApplicationState() {}

  @override
  void initState() {
    super.initState();

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
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.

    final screens = [
      Connect(
        availableDevices: this.availableDevices,
        onAvailableDevicesChanged: _handleAvailableDevicesChanged,
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

  // List<ScanResult> get connectedDevices =>
  //     this.availableDevices.where((element) {
  //       return element.device.isConnected;
  //     }).toList();

  List<StreamSubscription> deviceServiceSubs = [];
  HashMap<String, HashMap<String, List<BluetoothCharacteristic>>>
  characteristicsByServiceByDeviceID =
      HashMap<String, HashMap<String, List<BluetoothCharacteristic>>>();

  Future<void> _handleAvailableDevicesChanged(List<ScanResult> devices) async {
    final connectedDevices = devices.where((element) {
      return element.device.isConnected;
    }).toList();

    //remove all old device subs.
    for (final sub in deviceServiceSubs) {
      await sub.cancel();
    }

    characteristicsByServiceByDeviceID.clear();

    deviceServiceSubs.clear();

    for (final result in connectedDevices) {
      //subscribe to services changed.
      final deviceServiceSub = result.device.onServicesReset.listen((d) async {
        final newServices = await result.device.discoverServices();
        _handleNewServices(result.device, newServices);
      });

      deviceServiceSubs.add(deviceServiceSub);

      final newServices = await result.device.discoverServices();
      _handleNewServices(result.device, newServices);
    }

    setState(() {
      this.availableDevices = [...devices];
    });
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
