import 'dart:ui';

import 'package:controller/screens/connect/connect.dart';
import 'package:controller/screens/control.dart';
import 'package:flutter/material.dart';

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
      home: const Application(),
    );
  }
}

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  int _pageIndex = 0;

  final List<Widget> _screens = [
    Connect(devices: ["Hello", "bellow", "Zellow", "Kellogs!"]),
    Control(),
  ];

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
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _screens[_pageIndex],
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
