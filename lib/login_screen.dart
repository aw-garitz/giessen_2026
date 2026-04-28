import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:giessen_app/profil_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
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
    if (message.contains('Invalid login credentials')) {
      return "E-Mail oder Passwort falsch.";
    }
    if (message.contains('Email not confirmed')) {
      return "Bitte E-Mail bestätigen.";
    }
    if (message.contains('User already registered')) {
      return "E-Mail bereits registriert.";
    }
    if (message.contains('Password should be')) return "Passwort zu schwach.";
    return message;
  }

  void _zeigeFehler(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _zeigeInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required double w,
    required double h,
    bool obscure = false,
    bool? obscureToggle,
    VoidCallback? onToggle,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onSubmit,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureToggle != null ? !obscureToggle : obscure,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: w * 0.04),
        onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: w * 0.035,
            color: Colors.grey.shade600,
          ),
          prefixIcon: Icon(
            icon,
            size: w * 0.05,
            color: const Color(0xFF2E7D32),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: w * 0.04,
            vertical: h * 0.018,
          ),
          suffixIcon: onToggle != null
              ? IconButton(
                  icon: Icon(
                    obscureToggle! ? Icons.visibility : Icons.visibility_off,
                    size: w * 0.05,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: onToggle,
                )
              : null,
        ),
      ),
    );
  }

  Widget _anmeldenButton({
    required double w,
    required double h,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: h * 0.02),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        onPressed: onPressed,
        child: _isLoading
            ? SizedBox(
                height: w * 0.05,
                width: w * 0.05,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: w * 0.042,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    // Auf Web ist w oft sehr groß – cap bei 420px für Berechnungen
    final rw = w.clamp(0.0, 420.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E7D32), Color(0xFF4CAF50), Color(0xFF81C784)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: w * 0.06,
              vertical: h * 0.04,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    padding: EdgeInsets.all(rw * 0.07),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.water_drop,
                      size: rw * 0.14,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  SizedBox(height: h * 0.025),
                  Text(
                    "BK Logistik",
                    style: TextStyle(
                      fontSize: rw * 0.075,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "Gieß-App 2026",
                    style: TextStyle(
                      fontSize: rw * 0.038,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  SizedBox(height: h * 0.04),

                  // Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // TabBar
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            labelColor: const Color(0xFF2E7D32),
                            unselectedLabelColor: Colors.grey.shade600,
                            indicatorColor: const Color(0xFF2E7D32),
                            indicatorWeight: 3,
                            labelStyle: TextStyle(
                              fontSize: rw * 0.042,
                              fontWeight: FontWeight.w600,
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontSize: rw * 0.038,
                            ),
                            tabs: const [
                              Tab(text: "Anmelden"),
                              Tab(text: "Registrieren"),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey.shade200),

                        // TabBarView – KEINE fixe Höhe, nutzt intrinsische Höhe der Tabs
                        SizedBox(
                          height: kIsWeb
                              ? (h * 0.55).clamp(350.0, 550.0) // Web: angepasst
                              : (h * 0.52).clamp(
                                  300.0,
                                  500.0,
                                ), // Mobil: angepasst
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // LOGIN TAB
                              SingleChildScrollView(
                                padding: EdgeInsets.all(rw * 0.06),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _inputField(
                                      controller: _loginEmailController,
                                      label: "E-Mail",
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      w: rw,
                                      h: h,
                                    ),
                                    SizedBox(height: h * 0.02),
                                    _inputField(
                                      controller: _loginPasswortController,
                                      label: "Passwort",
                                      icon: Icons.lock_outlined,
                                      obscureToggle: _loginPasswortSichtbar,
                                      onToggle: () => setState(
                                        () => _loginPasswortSichtbar =
                                            !_loginPasswortSichtbar,
                                      ),
                                      onSubmit: _login,
                                      w: rw,
                                      h: h,
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _passwortVergessen,
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF2E7D32,
                                          ),
                                        ),
                                        child: Text(
                                          "Passwort vergessen?",
                                          style: TextStyle(
                                            fontSize: rw * 0.033,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: h * 0.015),
                                    _anmeldenButton(
                                      w: rw,
                                      h: h,
                                      label: "Anmelden",
                                      onPressed: _isLoading ? null : _login,
                                    ),
                                  ],
                                ),
                              ),

                              // REGISTRIEREN TAB
                              SingleChildScrollView(
                                padding: EdgeInsets.all(rw * 0.06),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _inputField(
                                      controller: _regNameController,
                                      label: "Dein Name",
                                      icon: Icons.person_outlined,
                                      w: rw,
                                      h: h,
                                    ),
                                    SizedBox(height: h * 0.015),
                                    _inputField(
                                      controller: _regEmailController,
                                      label: "E-Mail",
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      w: rw,
                                      h: h,
                                    ),
                                    SizedBox(height: h * 0.015),
                                    _inputField(
                                      controller: _regPasswortController,
                                      label: "Passwort",
                                      icon: Icons.lock_outlined,
                                      obscureToggle: _regPasswortSichtbar,
                                      onToggle: () => setState(
                                        () => _regPasswortSichtbar =
                                            !_regPasswortSichtbar,
                                      ),
                                      w: rw,
                                      h: h,
                                    ),
                                    SizedBox(height: h * 0.015),
                                    _inputField(
                                      controller:
                                          _regPasswortWiederholungController,
                                      label: "Passwort wiederholen",
                                      icon: Icons.lock_outlined,
                                      obscure: true,
                                      onSubmit: _registrieren,
                                      w: rw,
                                      h: h,
                                    ),
                                    SizedBox(height: h * 0.025),
                                    _anmeldenButton(
                                      w: rw,
                                      h: h,
                                      label: "Registrieren",
                                      onPressed: _isLoading
                                          ? null
                                          : _registrieren,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
