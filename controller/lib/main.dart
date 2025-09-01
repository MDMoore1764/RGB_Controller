// main.dart - Updated main file
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frame_control/app_state.dart';
import 'package:frame_control/screens/presets/presets_screen.dart';
import 'package:provider/provider.dart';
import 'package:frame_control/screens/color/color_screen.dart';
import 'package:frame_control/screens/connect/connect.dart';
import 'package:frame_control/screens/control/control.dart';
import 'package:window_size/window_size.dart' as window_size;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    window_size.setWindowTitle('Frame Controller');
    window_size.setWindowFrame(const Rect.fromLTWH(100, 100, 600, 1000));
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(
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
      ),
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
  late AnimationController animationController;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3000),
    )..repeat();

    // Initialize the app state with animation controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setAnimationController(animationController);
      appState.initialize();
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final screens = [Connect(), ColorScreen(), Control(), PresetsScreen()];

        return Scaffold(
          appBar: null,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: screens[appState.pageIndex],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            useLegacyColorScheme: true,
            selectedItemColor: Theme.of(context).colorScheme.onSurface,
            unselectedItemColor: Theme.of(
              context,
            ).colorScheme.onSurface.withAlpha(125),
            currentIndex: appState.pageIndex,
            onTap: (index) => appState.setPageIndex(index),
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
              BottomNavigationBarItem(
                icon: Icon(Icons.bookmark),
                label: 'Presets',
              ),
            ],
          ),
        );
      },
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
