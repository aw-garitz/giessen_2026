import 'package:flutter/material.dart';
import 'package:giessen_app/profil_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  // Login
  final _loginEmailController = TextEditingController();
  final _loginPasswortController = TextEditingController();

  // Registrierung
  final _regEmailController = TextEditingController();
  final _regNameController = TextEditingController();
  final _regPasswortController = TextEditingController();
  final _regPasswortWiederholungController = TextEditingController();

  bool _isLoading = false;
  bool _loginPasswortSichtbar = false;
  bool _regPasswortSichtbar = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswortController.dispose();
    _regEmailController.dispose();
    _regNameController.dispose();
    _regPasswortController.dispose();
    _regPasswortWiederholungController.dispose();
    super.dispose();
  }

  // --- LOGIN ---
  Future<void> _login() async {
    final email = _loginEmailController.text.trim();
    final passwort = _loginPasswortController.text.trim();

    if (email.isEmpty || passwort.isEmpty) {
      _zeigeFehler("Bitte E-Mail und Passwort eingeben.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithPassword(email: email, password: passwort);
      // AuthCheck in main.dart reagiert automatisch auf den Login
    } on AuthException catch (e) {
      _zeigeFehler(_uebersetzeFehler(e.message));
    } catch (e) {
      _zeigeFehler("Unbekannter Fehler: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REGISTRIERUNG ---
  Future<void> _registrieren() async {
    final email = _regEmailController.text.trim();
    final name = _regNameController.text.trim();
    final passwort = _regPasswortController.text.trim();
    final wiederholung = _regPasswortWiederholungController.text.trim();

    if (email.isEmpty || name.isEmpty || passwort.isEmpty) {
      _zeigeFehler("Bitte alle Felder ausfüllen.");
      return;
    }
    if (passwort != wiederholung) {
      _zeigeFehler("Passwörter stimmen nicht überein.");
      return;
    }
    if (passwort.length < 6) {
      _zeigeFehler("Passwort muss mindestens 6 Zeichen haben.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await supabase.auth.signUp(email: email, password: passwort);

      if (res.user != null) {
        // Profil anlegen mit dem eingegebenen Namen
        await ProfilService.erstelleProfil(
          userId: res.user!.id,
          displayName: name,
          rolle: 'fahrer', // Neue User sind standardmäßig Fahrer
        );
      }

      if (mounted) {
        _zeigeInfo("Registrierung erfolgreich! Bitte E-Mail bestätigen falls erforderlich.");
        _tabController.animateTo(0); // Zurück zum Login-Tab
      }
    } on AuthException catch (e) {
      _zeigeFehler(_uebersetzeFehler(e.message));
    } catch (e) {
      _zeigeFehler("Unbekannter Fehler: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- PASSWORT VERGESSEN ---
  Future<void> _passwortVergessen() async {
    final email = _loginEmailController.text.trim();

    if (email.isEmpty) {
      _zeigeFehler("Bitte zuerst die E-Mail Adresse eingeben.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(email);
      if (mounted) {
        _zeigeInfo("Reset-Link wurde an $email gesendet.");
      }
    } on AuthException catch (e) {
      _zeigeFehler(_uebersetzeFehler(e.message));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FEHLER ÜBERSETZEN ---
  String _uebersetzeFehler(String message) {
    if (message.contains('Invalid login credentials')) return "E-Mail oder Passwort falsch.";
    if (message.contains('Email not confirmed')) return "Bitte zuerst die E-Mail bestätigen.";
    if (message.contains('User already registered')) return "Diese E-Mail ist bereits registriert.";
    if (message.contains('Password should be')) return "Passwort zu schwach. Mindestens 6 Zeichen.";
    return message;
  }

  void _zeigeFehler(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _zeigeInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Header
                const Icon(Icons.water_drop, size: 64, color: Color(0xFF2E7D32)),
                const SizedBox(height: 12),
                const Text(
                  "BK Logistik",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                ),
                const Text(
                  "Gieß-App 2026",
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 40),

                // Card mit Tabs
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      // Tab-Bar
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF2E7D32),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF2E7D32),
                        tabs: const [
                          Tab(text: "Anmelden"),
                          Tab(text: "Registrieren"),
                        ],
                      ),
                      const Divider(height: 1),

                      // Tab-Inhalt
                      SizedBox(
                        height: 360,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // --- LOGIN TAB ---
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _loginEmailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: "E-Mail",
                                      prefixIcon: Icon(Icons.email_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _loginPasswortController,
                                    obscureText: !_loginPasswortSichtbar,
                                    onSubmitted: (_) => _login(),
                                    decoration: InputDecoration(
                                      labelText: "Passwort",
                                      prefixIcon: const Icon(Icons.lock_outlined),
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: Icon(_loginPasswortSichtbar ? Icons.visibility_off : Icons.visibility),
                                        onPressed: () => setState(() => _loginPasswortSichtbar = !_loginPasswortSichtbar),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _isLoading ? null : _passwortVergessen,
                                      child: const Text("Passwort vergessen?"),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: _isLoading ? null : _login,
                                    child: _isLoading
                                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Text("Anmelden", style: TextStyle(fontSize: 16)),
                                  ),
                                ],
                              ),
                            ),

                            // --- REGISTRIEREN TAB ---
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: _regNameController,
                                      decoration: const InputDecoration(
                                        labelText: "Dein Name",
                                        prefixIcon: Icon(Icons.person_outlined),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _regEmailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: "E-Mail",
                                        prefixIcon: Icon(Icons.email_outlined),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _regPasswortController,
                                      obscureText: !_regPasswortSichtbar,
                                      decoration: InputDecoration(
                                        labelText: "Passwort",
                                        prefixIcon: const Icon(Icons.lock_outlined),
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          icon: Icon(_regPasswortSichtbar ? Icons.visibility_off : Icons.visibility),
                                          onPressed: () => setState(() => _regPasswortSichtbar = !_regPasswortSichtbar),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _regPasswortWiederholungController,
                                      obscureText: true,
                                      onSubmitted: (_) => _registrieren(),
                                      decoration: const InputDecoration(
                                        labelText: "Passwort wiederholen",
                                        prefixIcon: Icon(Icons.lock_outlined),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E7D32),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: _isLoading ? null : _registrieren,
                                      child: _isLoading
                                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Text("Registrieren", style: TextStyle(fontSize: 16)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}