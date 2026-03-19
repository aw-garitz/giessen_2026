import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mobile_karte_view.dart';
import 'mobile_liste_view.dart';
import 'scan_screen.dart';
import '../funktionen/fn_allgemein.dart';
import '../funktionen/offline_sync_service.dart';

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
  int _offlineCount = 0;
  bool _isSyncing = false;

  StreamSubscription<bool>? _wlanSubscription;
  static const String _kfzPrefKey = 'selected_kfz';

  @override
  void initState() {
    super.initState();
    _selectedKW = GiesAppLogik.getISOWeek(DateTime.now());
    _ladeGespeichertesKFZ();
    _ladeOfflineCount();
    _startAutoSync();
  }

  @override
  void dispose() {
    _wlanSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _ladeGespeichertesKFZ() async {
    final prefs = await SharedPreferences.getInstance();
    final gespeichertesKFZ = prefs.getString(_kfzPrefKey) ?? "Alle";
    try {
      final liste = await GiesAppLogik.ladeAlleKFZ();
      if (mounted) {
        final alleKFZ = ["Alle", ...liste];
        setState(() {
          _kfzListe = alleKFZ;
          _selectedKFZ = alleKFZ.contains(gespeichertesKFZ) ? gespeichertesKFZ : "Alle";
          _isLoadingKFZ = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingKFZ = false);
    }
  }

  Future<void> _ladeOfflineCount() async {
    final count = await OfflineSyncService.anzahlAusstehend();
    if (mounted) setState(() => _offlineCount = count);
  }

  void _startAutoSync() {
    _wlanSubscription = OfflineSyncService.wlanStream.listen((hatWlan) async {
      if (hatWlan && _offlineCount > 0 && mounted) {
        await _syncDurchfuehren(automatisch: true);
      }
    });
  }

  Future<void> _setzeKFZ(String kfz) async {
    setState(() => _selectedKFZ = kfz);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kfzPrefKey, kfz);
  }

  Future<void> _syncDurchfuehren({bool automatisch = false}) async {
    if (_isSyncing || _offlineCount == 0) return;
    setState(() => _isSyncing = true);
    try {
      final ergebnis = await OfflineSyncService.syncZuSupabase();
      await _ladeOfflineCount();
      if (mounted && !automatisch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ergebnis.alleErfolgreich
                ? "${ergebnis.erfolgreich} Vorgänge synchronisiert ✅"
                : "${ergebnis.erfolgreich} OK, ${ergebnis.fehlgeschlagen} fehlgeschlagen"),
            backgroundColor: ergebnis.alleErfolgreich ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _jumpToScanner() {
    _pageController.animateToPage(2,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: h * 0.07,
        title: Text(
          "Hallo, ${widget.userName}",
          style: TextStyle(fontSize: w * 0.04, fontWeight: FontWeight.bold),
        ),
        elevation: 2,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          // Offline-Sync Badge + Button
          if (_offlineCount > 0)
            Padding(
              padding: EdgeInsets.symmetric(vertical: h * 0.012, horizontal: w * 0.01),
              child: Badge(
                label: Text("$_offlineCount", style: TextStyle(fontSize: w * 0.025)),
                child: IconButton(
                  iconSize: w * 0.06,
                  icon: _isSyncing
                      ? SizedBox(
                          width: w * 0.05, height: w * 0.05,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                        )
                      : const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
                  tooltip: "Offline-Vorgänge synchronisieren",
                  onPressed: _isSyncing ? null : () => _syncDurchfuehren(),
                ),
              ),
            ),
          if (!_isLoadingKFZ)
            _buildAppBarBadge(
              icon: Icons.local_shipping,
              w: w, h: h,
              child: DropdownButton<String>(
                value: _selectedKFZ,
                underline: const SizedBox(),
                dropdownColor: Colors.white,
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: w * 0.032),
                items: _kfzListe.map((kfz) => DropdownMenuItem(value: kfz, child: Text(kfz))).toList(),
                onChanged: (val) { if (val != null) _setzeKFZ(val); },
              ),
            ),
          SizedBox(width: w * 0.015),
          _buildAppBarBadge(
            icon: Icons.calendar_month,
            w: w, h: h,
            child: DropdownButton<int>(
              value: _selectedKW,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: w * 0.032),
              items: List.generate(52, (i) => i + 1)
                  .map((kw) => DropdownMenuItem(value: kw, child: Text("KW $kw")))
                  .toList(),
              onChanged: (val) => setState(() => _selectedKW = val!),
            ),
          ),
          SizedBox(width: w * 0.025),
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
              onOfflineVorgangGespeichert: _ladeOfflineCount,
            ),
            MobileTourListeView(
              selectedKW: _selectedKW,
              selectedKFZ: _selectedKFZ,
              onJumpToScanner: _jumpToScanner,
              onCountChanged: (count) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _tourCount = count);
                });
              },
              onOfflineVorgangGespeichert: _ladeOfflineCount,
            ),
            ScanScreen(
              ausgewaehlteKW: _selectedKW,
              ausgewaehltesKFZ: _selectedKFZ,
              onOfflineVorgangGespeichert: _ladeOfflineCount,
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        iconSize: w * 0.06,
        selectedFontSize: w * 0.03,
        unselectedFontSize: w * 0.028,
        onTap: (index) {
          setState(() => _currentIndex = index);
          _pageController.jumpToPage(index);
        },
        selectedItemColor: Colors.green[800],
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.map), label: "Karte"),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text("$_tourCount", style: TextStyle(fontSize: w * 0.025)),
              isLabelVisible: _tourCount > 0,
              child: const Icon(Icons.list_alt),
            ),
            label: "Tour",
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: "Scan"),
        ],
      ),
    );
  }

  Widget _buildAppBarBadge({required IconData icon, required Widget child, required double w, required double h}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: w * 0.02),
      margin: EdgeInsets.symmetric(vertical: h * 0.012),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: w * 0.038, color: Colors.blueGrey),
        SizedBox(width: w * 0.01),
        DropdownButtonHideUnderline(child: child),
      ]),
    );
  }
}