import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Deine Desktop/Web Importe
import 'login_screen.dart';
import 'admin_desktop_screen.dart'; 

// Deine Mobile Importe
// Falls deine mobile Hauptansicht MobileMainView heißt:
import 'mobil/mobile_main_view.dart'; 
// Falls du den FahrzeugTourScreen als Zwischenschritt nutzt:
import 'views/fahrzeug_tour_view.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    

    await Supabase.initialize(
      url: 'https://sekahpqggcbvmhhxxtjg.supabase.co',
      anonKey: 'sb_publishable_lIOp5PSekv5aaouBj6U8Ng_vxyEFneS',
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
      // Browser-Ansicht (Admin)
      return const AdminDesktopScreen();
    } else {
      // Mobile-Ansicht (Fahrer)
      // Hier kannst du entscheiden: Direkt MobileMainView oder FahrzeugTourScreen
      return const MobileMainView(); 
    }
  }
}