import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'l10n/l10n.dart';
import 'screens/reader_screen.dart';
import 'state/mushaf_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Start in portrait; the controller enables landscape after loading
  // the user's "rotate to landscape" preference.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
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
            locale: L10n.locale,
            supportedLocales: const [Locale('ar'), Locale('en'), Locale('ur')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => Directionality(
              textDirection: L10n.dir,
              child: child ?? const SizedBox.shrink(),
            ),
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
