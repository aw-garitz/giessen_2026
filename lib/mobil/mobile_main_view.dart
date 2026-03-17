import 'package:flutter/material.dart';
import 'mobile_karte_view.dart';
import 'mobile_liste_view.dart'; 
import 'scan_screen.dart';
import '../funktionen/fn_allgemein.dart';

class MobileMainView extends StatefulWidget {
  const MobileMainView({super.key});

  @override
  State<MobileMainView> createState() => _MobileMainViewState();
}

class _MobileMainViewState extends State<MobileMainView> {
  final PageController _pageController = PageController(initialPage: 1);
  int _currentIndex = 1;
  
  // WICHTIG: Wenn deine Testdaten in KW 14 liegen, 
  // setzen wir den Startwert fest auf 14, damit du sofort etwas siehst!
  int _selectedKW = GiesAppLogik.getISOWeek(DateTime.now());
  String _selectedKFZ = "Alle"; 
  List<String> _kfzListe = ["Alle"];
  bool _isLoadingKFZ = true;

  @override
  void initState() {
    super.initState();
_selectedKW = GiesAppLogik.getISOWeek(DateTime.now());
    _initialisiereFahrzeuge();
  }

  Future<void> _initialisiereFahrzeuge() async {
    try {
      final liste = await GiesAppLogik.ladeAlleKFZ(); 
      if (mounted) {
        setState(() {
          _kfzListe = ["Alle", ...liste];
          _isLoadingKFZ = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingKFZ = false);
    }
  }

  void _jumpToScanner() {
    _pageController.animateToPage(2, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gieß-App", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                items: _kfzListe.map((kfz) => DropdownMenuItem(value: kfz, child: Text(kfz))).toList(),
                onChanged: (val) => setState(() => _selectedKFZ = val!),
              ),
            ),
          const SizedBox(width: 6),
          _buildAppBarBadge(
            icon: Icons.calendar_month,
            child: DropdownButton<int>(
              value: _selectedKW,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
              items: List.generate(52, (i) => i + 1).map((kw) => DropdownMenuItem(value: kw, child: Text("KW $kw"))).toList(),
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
              selectedKFZ: _selectedKFZ, // Für späteres Filtern in der View
              onJumpToScanner: _jumpToScanner
            ),
            MobileTourListeView(
              selectedKW: _selectedKW,
              selectedKFZ: _selectedKFZ
            ), 
            ScanScreen(
              ausgewaehlteKW: _selectedKW,
              ausgewaehltesKFZ: _selectedKFZ
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
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Karte"),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Tour"),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: "Scan"),
        ],
      ),
    );
  }

  Widget _buildAppBarBadge({required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: Colors.blueGrey),
        const SizedBox(width: 4),
        DropdownButtonHideUnderline(child: child),
      ]),
    );
  }
}