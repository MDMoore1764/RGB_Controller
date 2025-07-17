import 'dart:ui';

import 'package:controller/screens/color/color_screen.dart';
import 'package:controller/screens/connect/bluetooth_device_manager.dart';
import 'package:controller/screens/connect/connect.dart';
import 'package:controller/screens/control/control.dart';
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
  late AnimationController animationController;

  _ApplicationState() {}

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  void _setPage(int pageIndex) {
    setState(() {
      _pageIndex = pageIndex;
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
        onAvailableDevicesChanged: (devices) => setState(() {
          this.availableDevices = [...devices];
        }),
      ),
      ColorScreen(
        color: this.selectedColor,
        animationController: this.animationController,
        onColorSelected: (color) {
          setState(() {
            this.selectedColor = color;
          });
        },
      ),
      Control(color: this.selectedColor),
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
