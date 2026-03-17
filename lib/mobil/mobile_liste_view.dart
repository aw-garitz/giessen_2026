import 'package:flutter/material.dart';
import 'package:giessen_app/funktionen/fn_allgemein.dart';
import 'package:intl/intl.dart';

class MobileTourListeView extends StatefulWidget {
  final int selectedKW;
  final String? selectedKFZ; 
  final VoidCallback? onJumpToScanner; 

  const MobileTourListeView({
    super.key, 
    required this.selectedKW, 
    this.selectedKFZ, 
    this.onJumpToScanner
  });

  @override
  State<MobileTourListeView> createState() => _MobileTourListeViewState();
}

class _MobileTourListeViewState extends State<MobileTourListeView> {
  List<dynamic> _ausfuehrungen = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ladeDaten();
  }

  @override
  void didUpdateWidget(MobileTourListeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedKW != widget.selectedKW || 
        oldWidget.selectedKFZ != widget.selectedKFZ) {
      _ladeDaten();
    }
  }

  Future<void> _ladeDaten() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final daten = await GiesAppLogik.ladeAusfuehrungenProKW(widget.selectedKW);
      
      if (mounted) {
        setState(() {
          _ausfuehrungen = daten; 
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Listenfehler beim Laden: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEUE LOGIK FÜR STATUS-UPDATE IN DER LISTE ---
  Future<void> _updateStatus(dynamic item, bool neuerStatus) async {
    setState(() => _isLoading = true);
    try {
      if (neuerStatus) {
        // 1. ERLEDIGEN & SAISON NEU PLANEN
        // Nutzt das gewählte KFZ aus dem Filter für die Protokollierung
        await GiesAppLogik.erledigenUndPlanen(
          item, 
          kfz: widget.selectedKFZ
        );
      } else {
        // 2. RESET / RÜCKGÄNGIG
        // Löscht die falsche Zukunft und stellt den alten Rhythmus wieder her
        await GiesAppLogik.resetToLastStatus(item);
      }
      
      if (mounted) {
        await _ladeDaten(); // Liste mit neuem Planungsstand aktualisieren
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(neuerStatus 
              ? "Erledigt & Saison neu geplant" 
              : "Status zurückgesetzt & Rhythmus wiederhergestellt"),
            backgroundColor: neuerStatus ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Update Fehler Liste: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- UI Methoden ---

  void _zeigeAktionsDialog(dynamic item) {
    final bool done = item['erledigt'] ?? false;
    final String strasse = "${item['orte']?['strassen']?['name'] ?? ''} ${item['orte']?['hausnummer'] ?? ''}";
    final String beschreibung = item['orte']?['beschreibung_genau'] ?? '';
    final String taetigkeit = item['massnahmen']?['taetigkeiten']?['beschreibung_kurz'] ?? 'Gießen';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: EdgeInsets.fromLTRB(25, 15, 25, MediaQuery.of(ctx).padding.bottom + 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 45, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            Text(strasse, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            if (beschreibung.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(beschreibung, style: const TextStyle(fontSize: 16, color: Colors.blueGrey))),
            const Divider(height: 30),
            
            _detailRow(Icons.task_alt, "Aufgabe", taetigkeit, Colors.black),

            const SizedBox(height: 35),

            if (!done) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700], foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () { Navigator.pop(ctx); _updateStatus(item, true); },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("JETZT ERLEDIGEN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () { 
                    Navigator.pop(ctx); 
                    if (widget.onJumpToScanner != null) widget.onJumpToScanner!(); 
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text("SCANNER ÖFFNEN"),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800], foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () { Navigator.pop(ctx); _updateStatus(item, false); },
                  icon: const Icon(Icons.settings_backup_restore),
                  label: const Text("AUF OFFEN ZURÜCKSETZEN", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color valColor) {
    return Row(children: [
      Icon(icon, size: 20, color: Colors.grey),
      const SizedBox(width: 10),
      Text("$label: ", style: const TextStyle(fontSize: 16)),
      Expanded(child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valColor))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    if (_ausfuehrungen.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text("Keine Aufgaben für KW ${widget.selectedKW} gefunden."),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _ladeDaten,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _ausfuehrungen.length,
        itemBuilder: (ctx, i) {
          final item = _ausfuehrungen[i];
          final bool done = item['erledigt'] ?? false;
          
          final strassenName = "${item['orte']?['strassen']?['name'] ?? ''} ${item['orte']?['hausnummer'] ?? ''}";
          final beschreibungGenau = item['orte']?['beschreibung_genau'] ?? '';
          final String taetigkeitKurz = item['massnahmen']?['taetigkeiten']?['beschreibung_kurz'] ?? 'Pflege';

          return Card(
            elevation: done ? 0 : 3,
            color: done ? Colors.green.shade50 : Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: done ? Colors.green.shade200 : Colors.grey.shade200),
            ),
            child: InkWell(
              onTap: () => _zeigeAktionsDialog(item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(strassenName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                        Icon(done ? Icons.check_circle : Icons.chevron_right, color: done ? Colors.green : Colors.grey),
                      ],
                    ),
                    if (beschreibungGenau.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(beschreibungGenau, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                          child: Text(taetigkeitKurz, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}