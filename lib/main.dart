import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:giessen_app/profil_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'login_screen.dart';
import 'admin_desktop_screen.dart';
import 'mobil/mobile_main_view.dart';

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
  bool _isLoading = true;
  String _userName = 'Benutzer';

  @override
  void initState() {
    super.initState();
    _init();

    // Auf Login / Logout reagieren
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) _init();
    });
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // Name aus Profil laden
      final profil = await ProfilService.ladeProfil();
      if (mounted) {
        setState(() {
          _userName = profil?['display_name'] ?? 'Benutzer';
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _userName = 'Benutzer';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = Supabase.instance.client.auth.currentSession;

    // Nicht eingeloggt → Login
    if (session == null) {
      return const LoginScreen();
    }

    // Gerät entscheidet die Ansicht
    if (kIsWeb) {
      return AdminDesktopScreen(userName: _userName);
    } else {
      return MobileMainView(userName: _userName);
    }
  }
}