import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/reader_screen.dart';
import 'state/mushaf_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final controller = MushafController();
  // Fire initialization immediately
  controller.initialize();

  runApp(MushafApp(controller: controller));
}

class MushafApp extends StatelessWidget {
  final MushafController controller;

  const MushafApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MushafController>.value(
      value: controller,
      child: Consumer<MushafController>(
        builder: (context, ctrl, _) {
          final theme = ctrl.theme;
          return MaterialApp(
            title: 'مصحف الختمة - Khatma Mushaf',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: theme.brightness,
              scaffoldBackgroundColor: theme.scaffoldBackground,
              colorScheme: ColorScheme.fromSeed(
                seedColor: theme.ornamentPrimary,
                brightness: theme.brightness,
              ),
            ),
            home: ReaderScreen(controller: ctrl),
          );
        },
      ),
    );
  }
}
