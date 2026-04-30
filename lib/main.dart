import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/loader_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(fileName: '.env');
  // Supabase uses Web Crypto API on web, which requires HTTPS or localhost.
  // On HTTP from a local IP the browser blocks it — catch and warn, app continues.
  try {
    await Supabase.initialize(
      url:     dotenv.env['SUPABASE_URL']   ?? '',
      anonKey: dotenv.env['SUPABASE_TOKEN'] ?? '',
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Supabase] init failed — likely HTTP non-localhost context: $e');
      debugPrint('[Supabase] Image upload will not work until served over HTTPS or localhost.');
    }
  }
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('es'), Locale('bg')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DanceWithMe',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7C5CFC)),
        useMaterial3: true,
      ),
      home: LoaderScreen(nextScreen: const LoginScreen()),
    );
  }
}
