import 'package:flutter/material.dart';
import 'package:giessen_app/funktionen/fn_allgemein.dart';
import 'package:giessen_app/funktionen/offline_sync_service.dart';
import 'package:intl/intl.dart';

class MobileTourListeView extends StatefulWidget {
  final int selectedKW;
  final String? selectedKFZ;
  final ValueChanged<int>? onCountChanged;
  final VoidCallback? onOfflineVorgangGespeichert;

  const MobileTourListeView({
    super.key,
    required this.selectedKW,
    this.selectedKFZ,
    this.onCountChanged,
    this.onOfflineVorgangGespeichert,
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
      _ladeDaten();
    } else if (oldWidget.selectedKFZ != widget.selectedKFZ) {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCountChanged?.call(gefiltert.length);
    });
  }

  Future<void> _updateStatus(dynamic item, bool neuerStatus) async {
    setState(() => _isLoading = true);
    try {
      final online = await OfflineSyncService.istOnline();

      if (online) {
        if (neuerStatus) {
          await GiesAppLogik.erledigenUndPlanen(item, kfz: widget.selectedKFZ);
        } else {
          await GiesAppLogik.resetToLastStatus(item);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(neuerStatus ? "Erledigt & neu geplant" : "Zurückgesetzt"),
              backgroundColor: neuerStatus ? Colors.green : Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await OfflineSyncService.speichereLokal(
          ausfuehrung: item,
          typ: neuerStatus ? 'erledigt' : 'reset',
          kfz: widget.selectedKFZ,
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

      if (mounted) await _ladeDaten();
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

  void _zeigeAktionsDialog(dynamic item, double w, double h) {
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
        padding: EdgeInsets.fromLTRB(w * 0.06, h * 0.02, w * 0.06, MediaQuery.of(ctx).padding.bottom + h * 0.04),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: w * 0.12, height: h * 0.006,
              margin: EdgeInsets.only(bottom: h * 0.025),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            )),
            Text(strasse, style: TextStyle(fontSize: w * 0.055, fontWeight: FontWeight.bold)),
            if (beschreibung.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: h * 0.01),
                child: Text(beschreibung, style: TextStyle(fontSize: w * 0.04, color: Colors.blueGrey)),
              ),
            Divider(height: h * 0.04),
            _detailRow(Icons.task_alt, "Aufgabe", taetigkeit, Colors.black, w),
            if (auftrag.isNotEmpty)
              _detailRow(Icons.assignment, "Auftrag", auftrag, Colors.blueGrey, w),
            SizedBox(height: h * 0.04),
            if (!done) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700], foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: h * 0.022),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () { Navigator.pop(ctx); _updateStatus(item, true); },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text("JETZT ERLEDIGEN", style: TextStyle(fontSize: w * 0.04, fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800], foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: h * 0.022),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () { Navigator.pop(ctx); _updateStatus(item, false); },
                  icon: const Icon(Icons.settings_backup_restore),
                  label: Text("AUF OFFEN ZURÜCKSETZEN", style: TextStyle(fontSize: w * 0.038, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color valColor, double w) {
    return Padding(
      padding: EdgeInsets.only(bottom: w * 0.02),
      child: Row(children: [
        Icon(icon, size: w * 0.045, color: Colors.grey),
        SizedBox(width: w * 0.025),
        Text("$label: ", style: TextStyle(fontSize: w * 0.035)),
        Expanded(child: Text(value, style: TextStyle(fontSize: w * 0.035, fontWeight: FontWeight.bold, color: valColor))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_gefilterteAusfuehrungen.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: w * 0.15, color: Colors.grey[300]),
            SizedBox(height: h * 0.015),
            Text("Keine Aufgaben für KW ${widget.selectedKW} gefunden.",
                style: TextStyle(fontSize: w * 0.035)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _ladeDaten,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: w * 0.025, vertical: h * 0.01),
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
            margin: EdgeInsets.only(bottom: h * 0.008),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: done ? Colors.green.shade200 : Colors.grey.shade200),
            ),
            child: InkWell(
              onTap: () => _zeigeAktionsDialog(item, w, h),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.03, vertical: h * 0.012),
                child: Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: done ? Colors.green : Colors.grey.shade400,
                      size: w * 0.055,
                    ),
                    SizedBox(width: w * 0.025),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(strassenName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: w * 0.038)),
                          if (beschreibungGenau.isNotEmpty)
                            Text(beschreibungGenau, style: TextStyle(fontSize: w * 0.03, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                          SizedBox(height: h * 0.005),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: w * 0.015, vertical: h * 0.003),
                                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                child: Text(taetigkeitKurz, style: TextStyle(fontSize: w * 0.025, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                              ),
                              if (auftrag.isNotEmpty) ...[
                                SizedBox(width: w * 0.015),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: w * 0.015, vertical: h * 0.003),
                                  decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: Text(auftrag, style: TextStyle(fontSize: w * 0.025, color: Colors.blueGrey.shade700)),
                                ),
                              ],
                              const Spacer(),
                              if (datum.isNotEmpty)
                                Text(datum, style: TextStyle(fontSize: w * 0.028, color: Colors.grey.shade500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey, size: w * 0.045),
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