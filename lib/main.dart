import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/notification_service.dart';
import 'ui/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await NotificationService().init();

  runApp(const OrtuConnectApp());
}

class OrtuConnectApp extends StatelessWidget {
  const OrtuConnectApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrtuConnect',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'FontStandar',
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'FontUtama'),
          titleMedium: TextStyle(fontFamily: 'FontUtama'),
          titleSmall: TextStyle(fontFamily: 'FontUtama'),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      locale: const Locale('id', 'ID'),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
