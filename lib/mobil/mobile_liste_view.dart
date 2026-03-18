import 'package:flutter/material.dart';
import 'package:giessen_app/funktionen/fn_allgemein.dart';
import 'package:intl/intl.dart';

class MobileTourListeView extends StatefulWidget {
  final int selectedKW;
  final String? selectedKFZ;
  final VoidCallback? onJumpToScanner;
  final ValueChanged<int>? onCountChanged;

  const MobileTourListeView({
    super.key,
    required this.selectedKW,
    this.selectedKFZ,
    this.onJumpToScanner,
    this.onCountChanged,
  });

  @override
  State<MobileTourListeView> createState() => _MobileTourListeViewState();
}

class _MobileTourListeViewState extends State<MobileTourListeView> {
  List<dynamic> _alleAusfuehrungen = [];
  List<dynamic> _gefilterteAusfuehrungen = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ladeDaten();
  }

  @override
  void didUpdateWidget(MobileTourListeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedKW != widget.selectedKW) {
      // KW geändert → neu laden
      _ladeDaten();
    } else if (oldWidget.selectedKFZ != widget.selectedKFZ) {
      // Nur KFZ geändert → nur filtern, kein neuer DB-Request
      _filterAnwenden();
    }
  }

  Future<void> _ladeDaten() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final daten = await GiesAppLogik.ladeAusfuehrungenProKW(widget.selectedKW);
      if (mounted) {
        setState(() {
          _alleAusfuehrungen = daten;
          _isLoading = false;
        });
        _filterAnwenden();
      }
    } catch (e) {
      debugPrint("Listenfehler beim Laden: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

void _filterAnwenden() {
  final kfz = widget.selectedKFZ;
  List<dynamic> gefiltert;

  if (kfz == null || kfz == "Alle") {
    gefiltert = List.from(_alleAusfuehrungen);
  } else {
    gefiltert = _alleAusfuehrungen
        .where((item) => item['kennzeichen']?.toString() == kfz)
        .toList();
  }

  setState(() => _gefilterteAusfuehrungen = gefiltert);

  // Callback NACH dem Build aufrufen – verhindert setState during build
  WidgetsBinding.instance.addPostFrameCallback((_) {
    widget.onCountChanged?.call(gefiltert.length);
  });
}

  Future<void> _updateStatus(dynamic item, bool neuerStatus) async {
    setState(() => _isLoading = true);
    try {
      if (neuerStatus) {
        await GiesAppLogik.erledigenUndPlanen(item, kfz: widget.selectedKFZ);
      } else {
        await GiesAppLogik.resetToLastStatus(item);
      }
      if (mounted) {
        await _ladeDaten();
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

  void _zeigeAktionsDialog(dynamic item) {
    final bool done = item['erledigt'] ?? false;
    final ort = item['massnahmen']?['orte'];
    final String strasse = "${ort?['strassen']?['name'] ?? ''} ${ort?['hausnummer'] ?? ''}".trim();
    final String beschreibung = ort?['beschreibung_genau'] ?? '';
    final String taetigkeit = item['massnahmen']?['taetigkeiten']?['beschreibung_kurz'] ?? 'Gießen';
    final String auftrag = (item['massnahmen']?['auftragsnummer'] ?? '').toString();

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
            if (beschreibung.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(beschreibung, style: const TextStyle(fontSize: 16, color: Colors.blueGrey))),
            const Divider(height: 30),
            _detailRow(Icons.task_alt, "Aufgabe", taetigkeit, Colors.black),
            if (auftrag.isNotEmpty)
              _detailRow(Icons.assignment, "Auftrag", auftrag, Colors.blueGrey),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 10),
        Text("$label: ", style: const TextStyle(fontSize: 14)),
        Expanded(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valColor))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_gefilterteAusfuehrungen.isEmpty) {
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: _gefilterteAusfuehrungen.length,
        itemBuilder: (ctx, i) {
          final item = _gefilterteAusfuehrungen[i];
          final bool done = item['erledigt'] ?? false;

          final ort = item['massnahmen']?['orte'];
          final strassenName = "${ort?['strassen']?['name'] ?? ''} ${ort?['hausnummer'] ?? ''}".trim();
          final beschreibungGenau = ort?['beschreibung_genau'] ?? '';
          final String taetigkeitKurz = item['massnahmen']?['taetigkeiten']?['beschreibung_kurz'] ?? 'Pflege';
          final String auftrag = (item['massnahmen']?['auftragsnummer'] ?? '').toString();
          final String datum = item['geplant_am'] != null
              ? DateFormat('dd.MM.').format(DateTime.parse(item['geplant_am']))
              : '';

          return Card(
            elevation: done ? 0 : 1,
            color: done ? Colors.green.shade50 : Colors.white,
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: done ? Colors.green.shade200 : Colors.grey.shade200),
            ),
            child: InkWell(
              onTap: () => _zeigeAktionsDialog(item),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: done ? Colors.green : Colors.grey.shade400,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strassenName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (beschreibungGenau.isNotEmpty)
                            Text(beschreibungGenau, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                child: Text(taetigkeitKurz, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                              ),
                              if (auftrag.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: Text(auftrag, style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade700)),
                                ),
                              ],
                              const Spacer(),
                              if (datum.isNotEmpty)
                                Text(datum, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
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