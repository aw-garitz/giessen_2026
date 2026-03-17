import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:giessen_app/funktionen/fn_allgemein.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class MobileKarteView extends StatefulWidget {
  final int selectedKW;
  final String? selectedKFZ;
  final VoidCallback onJumpToScanner;

  const MobileKarteView({
    super.key, 
    required this.selectedKW, 
    this.selectedKFZ,
    required this.onJumpToScanner
  });

  @override
  State<MobileKarteView> createState() => _MobileKarteViewState();
}

class _MobileKarteViewState extends State<MobileKarteView> {
  final MapController _mapController = MapController();
  List<dynamic> _ausfuehrungen = [];
  bool _isLoading = false;
  bool _showSatellite = true;

  @override
  void initState() {
    super.initState();
    _ladeAusfuehrungen();
  }

  @override
  void didUpdateWidget(MobileKarteView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Wenn die KW oder das KFZ im Filter geändert wird, Daten neu laden
    if (oldWidget.selectedKW != widget.selectedKW || oldWidget.selectedKFZ != widget.selectedKFZ) {
      _ladeAusfuehrungen();
    }
  }

  Future<void> _ladeAusfuehrungen() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Nutzt die bestehende Ladelogik aus deiner fn_allgemein
      final daten = await GiesAppLogik.ladeAusfuehrungenProKW(widget.selectedKW);
      
      if (mounted) {
        setState(() {
          // Optional: Hier könnte man noch nach widget.selectedKFZ filtern, 
          // falls ladeAusfuehrungenProKW das noch nicht tut.
          _ausfuehrungen = daten;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Kartenfehler beim Laden: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEUE LOGIK FÜR STATUS-UPDATE AUF DER KARTE ---
  Future<void> _updateStatus(dynamic a, bool neuerStatus) async {
    setState(() => _isLoading = true);
    try {
      if (neuerStatus) {
        // 1. ERLEDIGEN & NEU PLANEN
        // Nutzt die zentrale Logik inkl. Saison-Berechnung bis 03.11.
        await GiesAppLogik.erledigenUndPlanen(
          a, 
          kfz: widget.selectedKFZ
        );
      } else {
        // 2. RESET / RÜCKGÄNGIG
        // Löscht die falsche Zukunft und stellt den alten Rhythmus wieder her
        await GiesAppLogik.resetToLastStatus(a);
      }

      if (mounted) {
        Navigator.pop(context); // BottomSheet schließen
        await _ladeAusfuehrungen(); // Karte aktualisieren
        
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
      debugPrint("Update Fehler Karte: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Marker-Liste generieren
    final List<Marker> markers = _ausfuehrungen
        .where((a) {
          final ort = a['orte'];
          return ort != null && 
                 ort['latitude'] != null && 
                 ort['longitude'] != null;
        })
        .map((a) {
          final bool done = a['erledigt'] ?? false;
          final double lat = double.tryParse(a['orte']['latitude'].toString()) ?? 0.0;
          final double lng = double.tryParse(a['orte']['longitude'].toString()) ?? 0.0;

          return Marker(
            point: LatLng(lat, lng),
            width: 45,
            height: 45,
            child: GestureDetector(
              onTap: () => _zeigeDetails(a),
              child: Icon(
                Icons.location_on,
                color: done ? Colors.green : Colors.redAccent,
                size: 40,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
              ),
            ),
          );
        }).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController, 
          options: const MapOptions(
            initialCenter: LatLng(50.2015, 10.0765),
            initialZoom: 15,
          ),
          children: [
            if (_showSatellite) ...[
              TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
            ] else
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),

            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 45,
                size: const Size(40, 40),
                alignment: Alignment.center,
                markers: markers,
                builder: (context, localMarkers) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withOpacity(0.9),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        localMarkers.length.toString(), 
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                          fontSize: 12
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        
        Positioned(
          bottom: 20, right: 20,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.white,
            onPressed: () => setState(() => _showSatellite = !_showSatellite),
            child: Icon(_showSatellite ? Icons.map : Icons.layers, color: Colors.blue[800]),
          ),
        ),
        
        if (_isLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  void _zeigeDetails(dynamic a) {
    final ort = a['orte'];
    final bool erledigt = a['erledigt'] ?? false;
    final String strasse = "${ort?['strassen']?['name'] ?? 'Unbekannt'} ${ort?['hausnummer'] ?? ''}";
    final String beschr = ort?['beschreibung_genau'] ?? 'Keine Details';
    final String taetigkeit = a['massnahmen']?['taetigkeiten']?['beschreibung_kurz'] ?? 'Pflege';
    
    final String geplant = a['geplant_am'] != null 
        ? DateFormat('dd.MM.yyyy').format(DateTime.parse(a['geplant_am'])) 
        : '---';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))
        ),
        padding: EdgeInsets.fromLTRB(25, 12, 25, MediaQuery.of(ctx).padding.bottom + 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            Text(strasse, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Details: $beschr", style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
            const Divider(height: 30),
            _infoItem(Icons.calendar_today, "Geplant", geplant),
            _infoItem(Icons.task_alt, "Aufgabe", taetigkeit),
            const SizedBox(height: 30),
            
            if (!erledigt) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700], foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () => _updateStatus(a, true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("ALS ERLEDIGT MARKIEREN", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () => _updateStatus(a, false),
                  icon: const Icon(Icons.undo),
                  label: const Text("ZURÜCKSETZEN"),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}