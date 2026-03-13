import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> druckeQrBogen(int startNummer) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          return pw.GridView(
            crossAxisCount: 4, // 4 Spalten
            childAspectRatio: 1,
            children: List.generate(20, (index) {
              final id = "ID-${startNummer + index}";
              return pw.Container(
                margin: const pw.EdgeInsets.all(5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text("Gieß-Liste", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: id,
                      width: 70,
                      height: 70,
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(id, style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}