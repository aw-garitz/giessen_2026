import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:giessen_app/views/fahrzeug_tour_view.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Deine Dateimporte
import 'login_screen.dart';
import 'admin_desktop_screen.dart'; 
      

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce, 
      ),
    );
  } catch (e) {
    debugPrint("Initialisierungsfehler: $e");
  }

  runApp(const GiessenApp());
}

class GiessenApp extends StatelessWidget {
  const GiessenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gieß-Logistik Bad Kissingen',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de', 'DE')],
      locale: const Locale('de', 'DE'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthCheck(),
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() {}); 
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    // 1. Nicht eingeloggt -> Login
    if (session == null) {
      return const LoginScreen();
    }

    // 2. Eingeloggt -> Weiche
    if (kIsWeb) {
      return const AdminDesktopScreen();
    } else {
      // GEÄNDERT: Mobile Nutzer starten jetzt in der Tour-Übersicht
      return const FahrzeugTourScreen(); 
    }
  }
}