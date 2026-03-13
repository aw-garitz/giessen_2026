import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class QrPdfService {
  static Future<void> generateQrLabels(List<dynamic> massnahmen) async {
    final pdf = pw.Document();

    for (var i = 0; i < massnahmen.length; i += 15) {
      final chunk = massnahmen.sublist(
        i, 
        i + 15 > massnahmen.length ? massnahmen.length : i + 15
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.GridView(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: chunk.map((m) {
                final String qrData = m['qr_code_id'] ?? 'Keine ID';
                final String strasse = m['orte']?['strassen']?['name'] ?? 'Unbekannt';
                final String hausnummer = m['orte']?['hausnummer'] ?? '';
                final String beschreibung = m['orte']?['beschreibung_genau'] ?? '';
                final String taetigkeit = m['taetigkeiten']?['beschreibung_kurz'] ?? '';

                return pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                        width: 70,
                        height: 70,
                      ),
                      pw.SizedBox(height: 6),
                      // STRASSE
                      pw.Text(
                        "$strasse $hausnummer",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        maxLines: 1,
                      ),
                      pw.SizedBox(height: 2),
                      // BESCHREIBUNG (Die neue Zeile)
                      pw.Text(
                        beschreibung,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
                        maxLines: 2, // Erlaubt zwei Zeilen für lange Beschreibungen
                      ),
                      pw.SizedBox(height: 4),
                      // TÄTIGKEIT
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        child: pw.Text(
                          taetigkeit,
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.black),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'QR_Labels_Bewaesserung.pdf',
    );
  }
}