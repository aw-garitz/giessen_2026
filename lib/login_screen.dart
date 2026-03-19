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

  final _loginEmailController = TextEditingController();
  final _loginPasswortController = TextEditingController();
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
    } on AuthException catch (e) {
      _zeigeFehler(_uebersetzeFehler(e.message));
    } catch (e) {
      _zeigeFehler("Unbekannter Fehler: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      _zeigeFehler("Passwort mindestens 6 Zeichen.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await supabase.auth.signUp(email: email, password: passwort);
      if (res.user != null) {
        await ProfilService.erstelleProfil(
          userId: res.user!.id,
          displayName: name,
          rolle: 'fahrer',
        );
      }
      if (mounted) {
        _zeigeInfo("Registrierung erfolgreich!");
        _tabController.animateTo(0);
      }
    } on AuthException catch (e) {
      _zeigeFehler(_uebersetzeFehler(e.message));
    } catch (e) {
      _zeigeFehler("Fehler: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _passwortVergessen() async {
    final email = _loginEmailController.text.trim();
    if (email.isEmpty) {
      _zeigeFehler("Bitte zuerst E-Mail eingeben.");
      return;
    }
    setState(() => _isLoading = true);
    try {
      await supabase.auth.resetPasswordForEmail(email);
      if (mounted) _zeigeInfo("Reset-Link wurde an $email gesendet.");
    } on AuthException catch (e) {
      _zeigeFehler(_uebersetzeFehler(e.message));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _uebersetzeFehler(String message) {
    if (message.contains('Invalid login credentials')) return "E-Mail oder Passwort falsch.";
    if (message.contains('Email not confirmed')) return "Bitte E-Mail bestätigen.";
    if (message.contains('User already registered')) return "E-Mail bereits registriert.";
    if (message.contains('Password should be')) return "Passwort zu schwach.";
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
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(w * 0.06),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Icon(Icons.water_drop, size: w * 0.16, color: const Color(0xFF2E7D32)),
                SizedBox(height: h * 0.015),
                Text(
                  "BK Logistik",
                  style: TextStyle(fontSize: w * 0.07, fontWeight: FontWeight.bold, color: const Color(0xFF2E7D32)),
                ),
                Text(
                  "Gieß-App 2026",
                  style: TextStyle(fontSize: w * 0.035, color: Colors.black54),
                ),
                SizedBox(height: h * 0.05),

                // Card mit Tabs
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF2E7D32),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF2E7D32),
                        labelStyle: TextStyle(fontSize: w * 0.038),
                        tabs: const [
                          Tab(text: "Anmelden"),
                          Tab(text: "Registrieren"),
                        ],
                      ),
                      const Divider(height: 1),

                      SizedBox(
                        height: h * 0.45,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // LOGIN TAB
                            Padding(
                              padding: EdgeInsets.all(w * 0.06),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextField(
                                    controller: _loginEmailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: TextStyle(fontSize: w * 0.038),
                                    decoration: InputDecoration(
                                      labelText: "E-Mail",
                                      labelStyle: TextStyle(fontSize: w * 0.035),
                                      prefixIcon: Icon(Icons.email_outlined, size: w * 0.05),
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                  SizedBox(height: h * 0.02),
                                  TextField(
                                    controller: _loginPasswortController,
                                    obscureText: !_loginPasswortSichtbar,
                                    style: TextStyle(fontSize: w * 0.038),
                                    onSubmitted: (_) => _login(),
                                    decoration: InputDecoration(
                                      labelText: "Passwort",
                                      labelStyle: TextStyle(fontSize: w * 0.035),
                                      prefixIcon: Icon(Icons.lock_outlined, size: w * 0.05),
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: Icon(_loginPasswortSichtbar ? Icons.visibility_off : Icons.visibility, size: w * 0.05),
                                        onPressed: () => setState(() => _loginPasswortSichtbar = !_loginPasswortSichtbar),
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _isLoading ? null : _passwortVergessen,
                                      child: Text("Passwort vergessen?", style: TextStyle(fontSize: w * 0.033)),
                                    ),
                                  ),
                                  SizedBox(height: h * 0.01),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E7D32),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: h * 0.018),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: _isLoading ? null : _login,
                                    child: _isLoading
                                        ? SizedBox(height: w * 0.05, width: w * 0.05, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text("Anmelden", style: TextStyle(fontSize: w * 0.04)),
                                  ),
                                ],
                              ),
                            ),

                            // REGISTRIEREN TAB
                            Padding(
                              padding: EdgeInsets.all(w * 0.06),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: _regNameController,
                                      style: TextStyle(fontSize: w * 0.038),
                                      decoration: InputDecoration(
                                        labelText: "Dein Name",
                                        labelStyle: TextStyle(fontSize: w * 0.035),
                                        prefixIcon: Icon(Icons.person_outlined, size: w * 0.05),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                    SizedBox(height: h * 0.015),
                                    TextField(
                                      controller: _regEmailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: TextStyle(fontSize: w * 0.038),
                                      decoration: InputDecoration(
                                        labelText: "E-Mail",
                                        labelStyle: TextStyle(fontSize: w * 0.035),
                                        prefixIcon: Icon(Icons.email_outlined, size: w * 0.05),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                    SizedBox(height: h * 0.015),
                                    TextField(
                                      controller: _regPasswortController,
                                      obscureText: !_regPasswortSichtbar,
                                      style: TextStyle(fontSize: w * 0.038),
                                      decoration: InputDecoration(
                                        labelText: "Passwort",
                                        labelStyle: TextStyle(fontSize: w * 0.035),
                                        prefixIcon: Icon(Icons.lock_outlined, size: w * 0.05),
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          icon: Icon(_regPasswortSichtbar ? Icons.visibility_off : Icons.visibility, size: w * 0.05),
                                          onPressed: () => setState(() => _regPasswortSichtbar = !_regPasswortSichtbar),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: h * 0.015),
                                    TextField(
                                      controller: _regPasswortWiederholungController,
                                      obscureText: true,
                                      style: TextStyle(fontSize: w * 0.038),
                                      onSubmitted: (_) => _registrieren(),
                                      decoration: InputDecoration(
                                        labelText: "Passwort wiederholen",
                                        labelStyle: TextStyle(fontSize: w * 0.035),
                                        prefixIcon: Icon(Icons.lock_outlined, size: w * 0.05),
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                    SizedBox(height: h * 0.02),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E7D32),
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(vertical: h * 0.018),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: _isLoading ? null : _registrieren,
                                      child: _isLoading
                                          ? SizedBox(height: w * 0.05, width: w * 0.05, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : Text("Registrieren", style: TextStyle(fontSize: w * 0.04)),
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