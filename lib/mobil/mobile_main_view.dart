import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mobile_karte_view.dart';
import 'mobile_liste_view.dart';
import 'scan_screen.dart';
import '../funktionen/fn_allgemein.dart';

class MobileMainView extends StatefulWidget {
  final String userName;

  const MobileMainView({super.key, required this.userName});

  @override
  State<MobileMainView> createState() => _MobileMainViewState();
}

class _MobileMainViewState extends State<MobileMainView> {
  final PageController _pageController = PageController(initialPage: 1);
  int _currentIndex = 1;

  int _selectedKW = GiesAppLogik.getISOWeek(DateTime.now());
  String _selectedKFZ = "Alle";
  List<String> _kfzListe = ["Alle"];
  bool _isLoadingKFZ = true;
  int _tourCount = 0;

  static const String _kfzPrefKey = 'selected_kfz';

  @override
  void initState() {
    super.initState();
    _selectedKW = GiesAppLogik.getISOWeek(DateTime.now());
    _ladeGespeichertesKFZ();
  }

  /// Gespeichertes KFZ laden, dann Fahrzeugliste holen
  Future<void> _ladeGespeichertesKFZ() async {
    final prefs = await SharedPreferences.getInstance();
    final gespeichertesKFZ = prefs.getString(_kfzPrefKey) ?? "Alle";

    try {
      final liste = await GiesAppLogik.ladeAlleKFZ();
      if (mounted) {
        final alleKFZ = ["Alle", ...liste];
        setState(() {
          _kfzListe = alleKFZ;
          // Gespeichertes KFZ nur setzen wenn es noch in der Liste existiert
          _selectedKFZ = alleKFZ.contains(gespeichertesKFZ) ? gespeichertesKFZ : "Alle";
          _isLoadingKFZ = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingKFZ = false);
    }
  }

  /// KFZ ändern und persistent speichern
  Future<void> _setzeKFZ(String kfz) async {
    setState(() => _selectedKFZ = kfz);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kfzPrefKey, kfz);
  }

  void _jumpToScanner() {
    _pageController.animateToPage(2,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Hallo, ${widget.userName}",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        elevation: 2,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (!_isLoadingKFZ)
            _buildAppBarBadge(
              icon: Icons.local_shipping,
              child: DropdownButton<String>(
                value: _selectedKFZ,
                underline: const SizedBox(),
                dropdownColor: Colors.white,
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
                items: _kfzListe
                    .map((kfz) =>
                        DropdownMenuItem(value: kfz, child: Text(kfz)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) _setzeKFZ(val);
                },
              ),
            ),
          const SizedBox(width: 6),
          _buildAppBarBadge(
            icon: Icons.calendar_month,
            child: DropdownButton<int>(
              value: _selectedKW,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              items: List.generate(52, (i) => i + 1)
                  .map((kw) =>
                      DropdownMenuItem(value: kw, child: Text("KW $kw")))
                  .toList(),
              onChanged: (val) => setState(() => _selectedKW = val!),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          children: [
            MobileKarteView(
              selectedKW: _selectedKW,
              selectedKFZ: _selectedKFZ,
              onJumpToScanner: _jumpToScanner,
            ),
            MobileTourListeView(
              selectedKW: _selectedKW,
              selectedKFZ: _selectedKFZ,
              onJumpToScanner: _jumpToScanner,
              onCountChanged: (count) {
                if (mounted) setState(() => _tourCount = count);
              },
            ),
            ScanScreen(
              ausgewaehlteKW: _selectedKW,
              ausgewaehltesKFZ: _selectedKFZ,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          _pageController.jumpToPage(index);
        },
        selectedItemColor: Colors.green[800],
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: "Karte",
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(
                "$_tourCount",
                style: const TextStyle(fontSize: 10),
              ),
              isLabelVisible: _tourCount > 0,
              child: const Icon(Icons.list_alt),
            ),
            label: "Tour",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: "Scan",
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarBadge({required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: Colors.blueGrey),
        const SizedBox(width: 4),
        DropdownButtonHideUnderline(child: child),
      ]),
    );
  }
}