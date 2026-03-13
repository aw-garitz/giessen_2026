import 'package:flutter/material.dart';
import 'package:giessen_app/views/fahrzeug_tour_view.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final supabase = Supabase.instance.client;
  bool _isProcessing = false;
  
  String? _mitarbeiterName;
  String? _gewaehltesKennzeichen;
  List<String> _alleKennzeichen = [];
  
  final MobileScannerController cameraController = MobileScannerController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialisiereDaten();
  }

  Future<void> _initialisiereDaten() async {
    await _ladeFahrzeuge();
    await _loadStoredData();
  }

  Future<void> _ladeFahrzeuge() async {
    try {
      final data = await supabase.from('fahrzeuge').select('kennzeichen');
      setState(() {
        _alleKennzeichen = List<String>.from(data.map((f) => f['kennzeichen']));
      });
    } catch (e) {
      debugPrint("Fehler Fahrzeuge laden: $e");
    }
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mitarbeiterName = prefs.getString('mitarbeiter_name');
      _gewaehltesKennzeichen = prefs.getString('gewaehltes_kennzeichen');
    });
    // Anmeldung erzwingen, wenn Daten fehlen
    if (_mitarbeiterName == null || _gewaehltesKennzeichen == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _zeigeAnmeldung());
    }
  }

  Future<void> _saveSettings(String name, String? kennzeichen) async {
    if (name.trim().isEmpty || kennzeichen == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mitarbeiter_name', name.trim());
    await prefs.setString('gewaehltes_kennzeichen', kennzeichen);
    setState(() {
      _mitarbeiterName = name.trim();
      _gewaehltesKennzeichen = kennzeichen;
    });
    Navigator.pop(context);
  }

  void _zeigeAnmeldung() {
    _nameController.text = _mitarbeiterName ?? "";
    String? tempKennzeichen = _gewaehltesKennzeichen;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Anmeldung Mitarbeiter"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name / Kürzel", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: tempKennzeichen,
                decoration: const InputDecoration(labelText: "Fahrzeug wählen", border: OutlineInputBorder()),
                items: _alleKennzeichen.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (val) => setDialogState(() => tempKennzeichen = val),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => _saveSettings(_nameController.text, tempKennzeichen), 
              child: const Text("STARTEN")
            ),
          ],
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_mitarbeiterName == null || _gewaehltesKennzeichen == null) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      if (_isProcessing) return;
      final String massnahmeId = barcodes.first.rawValue!;
      setState(() => _isProcessing = true);
      _zeigeEingabeDialog(massnahmeId);
    }
  }

  void _zeigeEingabeDialog(String mId) {
    final literController = TextEditingController(text: "100");
    final statusController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: SizedBox(width: 40, child: Divider(thickness: 4, color: Colors.grey))),
            Text("LKW: $_gewaehltesKennzeichen | 👤 $_mitarbeiterName", 
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Gießvorgang bestätigen", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: literController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Gegossene Liter", suffixText: "L", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: statusController,
              decoration: const InputDecoration(labelText: "Zustand/Besonderheiten", hintText: "Optional", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60), 
                backgroundColor: Colors.green[800]
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _speichereInDatenbank(
                  mId, 
                  double.tryParse(literController.text.replaceAll(',', '.')) ?? 100.0, 
                  statusController.text
                );
              },
              child: const Text("JETZT SPEICHERN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ).then((_) => Future.delayed(const Duration(seconds: 1), () { 
      if (mounted) setState(() => _isProcessing = false); 
    }));
  }

  Future<void> _speichereInDatenbank(String mId, double liter, String info) async {
    try {
      final List<dynamic> termine = await supabase
          .from('ausfuehrung')
          .select()
          .eq('massnahme_id', mId)
          .eq('erledigt', false)
          .order('geplant_am', ascending: true)
          .limit(1);

      if (termine.isEmpty) {
        _showFeedback("❌ Keine offene Maßnahme gefunden!", Colors.orange);
        return;
      }

      await supabase.from('ausfuehrung').update({
        'erledigt': true,
        'erledigt_am': DateTime.now().toIso8601String(),
        'mitarbeiter': _mitarbeiterName,
        'kennzeichen': _gewaehltesKennzeichen,
        'liter_ist': liter,
        'status': info.isEmpty ? 'erledigt' : info,
      }).eq('id', termine.first['id']);

      _showFeedback("✅ Erfolg für $_gewaehltesKennzeichen", Colors.green);
    } catch (e) {
      _showFeedback("❌ Datenbankfehler: $e", Colors.red);
    }
  }

  void _showFeedback(String msg, Color col) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: col));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Der Scanner füllt den Hintergrund
            MobileScanner(controller: cameraController, onDetect: _onDetect),
            
            // Fokus-Rahmen in der Mitte
            Center(
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2), 
                  borderRadius: BorderRadius.circular(30)
                ),
              ),
            ),

            // Oben Rechts: Info & Fahrzeug wechseln
            Positioned(
              top: 15, right: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _zeigeAnmeldung,
                    child: Chip(
                      avatar: const Icon(Icons.local_shipping, size: 16),
                      label: Text(_gewaehltesKennzeichen ?? "LKW wählen"),
                      backgroundColor: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  Text("👤 $_mitarbeiterName", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 5)])),
                ],
              ),
            ),

            // Oben Links: Zur TOUR-LISTE wechseln (statt Absturz-Button)
            Positioned(
              top: 10, left: 10,
              child: IconButton(
                icon: const CircleAvatar(
                  backgroundColor: Colors.black45, 
                  child: Icon(Icons.list_alt, color: Colors.white)
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FahrzeugTourScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}