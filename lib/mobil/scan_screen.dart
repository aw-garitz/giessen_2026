import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:giessen_app/funktionen/fn_allgemein.dart';
import 'package:giessen_app/funktionen/offline_sync_service.dart';

class ScanScreen extends StatefulWidget {
  final int ausgewaehlteKW;
  final String ausgewaehltesKFZ;
  final VoidCallback? onOfflineVorgangGespeichert;

  const ScanScreen({
    super.key,
    required this.ausgewaehlteKW,
    required this.ausgewaehltesKFZ,
    this.onOfflineVorgangGespeichert,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isProcessing = false;
  DateTime? _lastScanTime;

  Future<void> _onDetect(BarcodeCapture capture) async {
    final now = DateTime.now();
    if (_lastScanTime != null && now.difference(_lastScanTime!).inSeconds < 2) return;
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.displayValue;
    if (code == null) return;

    if (widget.ausgewaehltesKFZ == "Alle KFZ" || widget.ausgewaehltesKFZ.isEmpty) {
      _zeigeFehler("Bitte erst ein Fahrzeug auswählen!");
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScanTime = now;
    });

    try {
      final alleAusfuehrungen = await GiesAppLogik.ladeAusfuehrungenProKW(widget.ausgewaehlteKW);

      final treffer = alleAusfuehrungen.where(
        (a) => a['massnahme_id'].toString() == code && a['erledigt'] == false
      ).toList();

      if (treffer.isNotEmpty) {
        await _zeigeBestaetigung(treffer.first);
      } else {
        final schonFertig = alleAusfuehrungen.any(
          (a) => a['massnahme_id'].toString() == code && a['erledigt'] == true
        );
        if (schonFertig) {
          _zeigeInfo("KW ${widget.ausgewaehlteKW}: bereits erledigt.");
        } else {
          _zeigeFehler("KW ${widget.ausgewaehlteKW}: nicht im Plan.");
        }
      }
    } catch (e) {
      _zeigeFehler("Fehler: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _zeigeBestaetigung(dynamic ausfuehrung) async {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    final ort = ausfuehrung['massnahmen']?['orte'];
    final String strasse = "${ort?['strassen']?['name'] ?? 'Unbekannt'} ${ort?['hausnummer'] ?? ''}".trim();
    final String beschr = ort?['beschreibung_genau'] ?? '';
    final String taetigkeit = ausfuehrung['massnahmen']?['taetigkeiten']?['beschreibung_kurz'] ?? 'Gießen';

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.blue, size: w * 0.06),
            SizedBox(width: w * 0.025),
            Text("Ort bestätigt", style: TextStyle(fontSize: w * 0.045)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strasse, style: TextStyle(fontSize: w * 0.045, fontWeight: FontWeight.bold)),
            if (beschr.isNotEmpty)
              Text(beschr, style: TextStyle(fontSize: w * 0.035, color: Colors.blueGrey)),
            Divider(height: h * 0.04),
            Text("Aktion: $taetigkeit", style: TextStyle(fontSize: w * 0.038, fontWeight: FontWeight.bold)),
            SizedBox(height: h * 0.01),
            Text("Fahrzeug: ${widget.ausgewaehltesKFZ}", style: TextStyle(fontSize: w * 0.035)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Abbrechen", style: TextStyle(fontSize: w * 0.035)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: w * 0.05, vertical: h * 0.015),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _bucheAb(ausfuehrung);
            },
            child: Text("Jetzt buchen", style: TextStyle(fontSize: w * 0.038)),
          ),
        ],
      ),
    );
  }

  Future<void> _bucheAb(dynamic ausfuehrung) async {
    setState(() => _isProcessing = true);
    try {
      final online = await OfflineSyncService.istOnline();

      if (online) {
        await GiesAppLogik.erledigenUndPlanen(
          ausfuehrung,
          kfz: widget.ausgewaehltesKFZ,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Gebucht & synchronisiert ✅"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await OfflineSyncService.speichereLokal(
          ausfuehrung: ausfuehrung,
          typ: 'erledigt',
          kfz: widget.ausgewaehltesKFZ,
        );
        widget.onOfflineVorgangGespeichert?.call();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Offline gespeichert – sync bei WLAN"),
              backgroundColor: Colors.blueGrey,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      _zeigeFehler("Fehler: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _zeigeFehler(String meldung) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(meldung), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _zeigeInfo(String meldung) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(meldung), backgroundColor: Colors.blueGrey, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text("QR-Code scannen", style: TextStyle(fontSize: w * 0.045)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
              facing: CameraFacing.back,
            ),
            onDetect: _onDetect,
          ),
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.blue,
                borderRadius: 20,
                borderLength: w * 0.08,
                borderWidth: w * 0.015,
                cutOutSize: w * 0.65,
              ),
            ),
          ),
          // Info-Badge oben
          Positioned(
            top: h * 0.04,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: w * 0.04, vertical: h * 0.012),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "KW ${widget.ausgewaehlteKW} | ${widget.ausgewaehltesKFZ}",
                  style: TextStyle(color: Colors.white, fontSize: w * 0.035),
                ),
              ),
            ),
          ),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderRadius = 10,
    this.borderLength = 40,
    this.borderWidth = 10,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final cutOutRect = Rect.fromLTWH(
      rect.left + (width - cutOutSize) / 2,
      rect.top + (height - cutOutSize) / 2,
      cutOutSize,
      cutOutSize,
    );

    final backgroundPaint = Paint()..color = Colors.black54;
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius))),
      ),
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path()
      ..moveTo(cutOutRect.left, cutOutRect.top + borderLength)
      ..lineTo(cutOutRect.left, cutOutRect.top)
      ..lineTo(cutOutRect.left + borderLength, cutOutRect.top)
      ..moveTo(cutOutRect.right - borderLength, cutOutRect.top)
      ..lineTo(cutOutRect.right, cutOutRect.top)
      ..lineTo(cutOutRect.right, cutOutRect.top + borderLength)
      ..moveTo(cutOutRect.right, cutOutRect.bottom - borderLength)
      ..lineTo(cutOutRect.right, cutOutRect.bottom)
      ..lineTo(cutOutRect.right - borderLength, cutOutRect.bottom)
      ..moveTo(cutOutRect.left + borderLength, cutOutRect.bottom)
      ..lineTo(cutOutRect.left, cutOutRect.bottom)
      ..lineTo(cutOutRect.left, cutOutRect.bottom - borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) => QrScannerOverlayShape();
}