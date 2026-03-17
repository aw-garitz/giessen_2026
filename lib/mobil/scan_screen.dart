import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../funktionen/fn_allgemein.dart';

class ScanScreen extends StatefulWidget {
  final int ausgewaehlteKW;
  final String ausgewaehltesKFZ;

  const ScanScreen({
    super.key,
    required this.ausgewaehlteKW,
    required this.ausgewaehltesKFZ,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isProcessing = false;
  DateTime? _lastScanTime;

  /// Verarbeitet den Scan-Vorgang
  Future<void> _onDetect(BarcodeCapture capture) async {
    final now = DateTime.now();

    // 1. 2-Sekunden-Sperre (Throttle)
    if (_lastScanTime != null && now.difference(_lastScanTime!).inSeconds < 2) {
      return;
    }
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.displayValue;
    if (code == null) return;

    setState(() {
      _isProcessing = true;
      _lastScanTime = now;
    });

    try {
      // Suche die passende Ausführung für diese Massnahme_ID in der aktuellen Woche
      final alleAusfuehrungen = await GiesAppLogik.ladeAusfuehrungenProKW(widget.ausgewaehlteKW);
      
      // Wir suchen den Eintrag, der zur gescannten Massnahme_ID passt und noch offen ist
      final passend = alleAusfuehrungen.firstWhere(
        (a) => a['massnahme_id'].toString() == code && a['erledigt'] == false,
        orElse: () => null,
      );

      if (passend != null) {
        await _zeigeBestaetigung(passend);
      } else {
        _zeigeFehler("Keine offene Aufgabe für ID $code in KW ${widget.ausgewaehlteKW} gefunden.");
      }
    } catch (e) {
      _zeigeFehler("Scan-Fehler: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Dialog zur Bestätigung vor dem Speichern
  Future<void> _zeigeBestaetigung(dynamic ausfuehrung) async {
    final ort = ausfuehrung['orte'];
    final String strasse = "${ort?['strassen']?['name'] ?? 'Unbekannt'} ${ort?['hausnummer'] ?? ''}";
    final String beschr = ort?['beschreibung_genau'] ?? '';

    return showDialog(
      context: context,
      barrierDismissible: false, // Nutzer MUSS drücken
      builder: (ctx) => AlertDialog(
        title: const Text("Scan erfolgreich"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strasse, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (beschr.isNotEmpty) Text(beschr),
            const SizedBox(height: 15),
            const Text("Soll dieser Ort als ERLEDIGT markiert werden?"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Abbrechen"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              await _bucheAb(ausfuehrung);
            },
            child: const Text("Bestätigen & Buchen"),
          ),
        ],
      ),
    );
  }

  /// Führt die eigentliche Logik (Status-Update + Neuplanung) aus
  Future<void> _bucheAb(dynamic ausfuehrung) async {
    try {
      // Nutzt die Logik aus fn_allgemein (die jetzt intervall_tage nutzt)
      await GiesAppLogik.erledigenUndPlanen(
        ausfuehrung,
        kfz: widget.ausgewaehltesKFZ,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erfolgreich gebucht!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      _zeigeFehler("Fehler beim Buchen: $e");
    }
  }

  void _zeigeFehler(String meldung) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(meldung), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          // Fadenkreuz / Overlay
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}