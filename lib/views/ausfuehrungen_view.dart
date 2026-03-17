import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
// WICHTIG: Pfad zu deiner Logik-Datei prüfen!
import 'package:giessen_app/funktionen/fn_allgemein.dart'; 

class AusfuehrungenView extends StatefulWidget {
  const AusfuehrungenView({super.key});

  @override
  State<AusfuehrungenView> createState() => _AusfuehrungenViewState();
}

class _AusfuehrungenViewState extends State<AusfuehrungenView> {
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _allData = []; 
  List<dynamic> _filteredData = []; 
  final Set<String> _selectedIds = {}; 
  
  bool _isLoading = true;
  int _selectedKW = 1;
  String _selectedKennzeichen = "Alle KFZ";
  String _selectedStadtteil = "Alle Stadtteile";
  String _selectedStatus = "Alle"; 
  String _searchQuery = "";
  int _mapMode = 1; 

  final LatLng _badKissingen = const LatLng(50.2015, 10.0765);

  @override
  void initState() {
    super.initState();
    _selectedKW = _getISOWeek(DateTime.now());
    _loadData();
  }

  int _getISOWeek(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  DateTime _getStartOfKW(int kw) {
    // Bezug auf das aktuelle Jahr 2026
    return DateTime(2026, 1, 1).add(Duration(days: (kw - 1) * 7 - 3));
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final start = _getStartOfKW(_selectedKW);
      final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));

      // Erweiterte Abfrage, um die Intervall-Tage für die Neuplanung parat zu haben
      final res = await supabase.from('ausfuehrung').select('''
        id, erledigt, geplant_am, kennzeichen, massnahme_id,
        orte (
          id, beschreibung_genau, hausnummer, latitude, longitude, 
          strassen:strasse_id (name, stadtteil)
        ), 
        massnahmen (
          id,
          taetigkeiten (beschreibung_kurz, intervall_tage)
        )
      ''')
      .gte('geplant_am', start.toIso8601String())
      .lte('geplant_am', end.toIso8601String())
      .order('geplant_am');
      
      setState(() {
        _allData = res as List<dynamic>;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Ladefehler: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      var temp = _allData.where((item) {
        if (item['orte'] == null) return false;

        final kfz = item['kennzeichen'] ?? "Ohne KFZ";
        final stadtteil = item['orte']['strassen']?['stadtteil'] ?? "Unbekannt";
        final strasse = (item['orte']['strassen']?['name'] ?? "").toString().toLowerCase();
        final hnr = (item['orte']['hausnummer'] ?? "").toString().toLowerCase();
        final beschr = (item['orte']['beschreibung_genau'] ?? "").toString().toLowerCase();
        final bool done = item['erledigt'] ?? false;
        
        bool matchesKfz = _selectedKennzeichen == "Alle KFZ" || kfz == _selectedKennzeichen;
        bool matchesStadtteil = _selectedStadtteil == "Alle Stadtteile" || stadtteil == _selectedStadtteil;
        bool matchesSearch = _searchQuery.isEmpty || 
                            strasse.contains(_searchQuery.toLowerCase()) || 
                            hnr.contains(_searchQuery.toLowerCase()) || 
                            beschr.contains(_searchQuery.toLowerCase());
        
        bool matchesStatus = true;
        if (_selectedStatus == "Offen") matchesStatus = !done;
        if (_selectedStatus == "Erledigt") matchesStatus = done;
        
        return matchesKfz && matchesStadtteil && matchesStatus && matchesSearch;
      }).toList();

      temp.sort((a, b) {
        bool aDone = a['erledigt'] ?? false;
        bool bDone = b['erledigt'] ?? false;
        if (aDone != bDone) return aDone ? 1 : -1;
        String nameA = (a['orte']['strassen']?['name'] ?? a['orte']['beschreibung_genau'] ?? "").toString();
        String nameB = (b['orte']['strassen']?['name'] ?? b['orte']['beschreibung_genau'] ?? "").toString();
        return nameA.compareTo(nameB);
      });

      _filteredData = temp;
    });
  }

  void _onMarkerTap(String id, LatLng point, int index) {
    setState(() {
      _selectedIds.clear();
      _selectedIds.add(id);
    });
    _mapController.move(point, 18.0);
    _itemScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  // --- NEUE LOGIK FÜR MASSEN-UPDATE ---
  Future<void> _bulkUpdate(bool markAsDone) async {
    if (_selectedIds.isEmpty) return;
    
    // UI Feedback: Ladeanzeige starten
    setState(() => _isLoading = true);

    try {
      for (var id in _selectedIds) {
        // Das entsprechende Item in der Liste finden
        final item = _allData.firstWhere((e) => e['id'].toString() == id);
        
        if (markAsDone) {
          // KFZ-Übergabe: Wenn "Alle KFZ" gewählt ist, nutzen wir null/Standard
          String? kfz = _selectedKennzeichen == "Alle KFZ" ? null : _selectedKennzeichen;
          await GiesAppLogik.erledigenUndPlanen(item, kfz: kfz);
        } else {
          await GiesAppLogik.resetToLastStatus(item);
        }
      }
      
      _selectedIds.clear();
      await _loadData(); // Liste neu laden, um Änderungen zu sehen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${markAsDone ? 'Erledigt' : 'Reset'} für ${_selectedIds.length} Orte durchgeführt."))
        );
      }
    } catch (e) {
      debugPrint("Bulk Fehler: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler beim Massen-Update: $e")));
      }
      setState(() => _isLoading = false);
    }
  }

  // --- NEUE LOGIK FÜR EINZEL-UPDATE ---
  Future<void> _toggleStatus(Map<String, dynamic> item) async {
    final bool isDone = item['erledigt'] ?? false;
    final ort = item['orte'];
    final String name = ort['strassen']?['name'] ?? ort['beschreibung_genau'] ?? 'Ort';
    final hnr = (ort['hausnummer'] == null || ort['hausnummer'] == 'null') ? "" : " ${ort['hausnummer']}";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("$name$hnr"),
        content: Text(isDone 
          ? "Status auf OFFEN setzen und Saison-Planung wiederherstellen?" 
          : "Als ERLEDIGT markieren und restliche Saison neu berechnen?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Abbruch")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDone ? Colors.orange : Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isDone ? "Reset" : "Erledigt"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        if (!isDone) {
          String? kfz = _selectedKennzeichen == "Alle KFZ" ? null : _selectedKennzeichen;
          await GiesAppLogik.erledigenUndPlanen(item, kfz: kfz);
        } else {
          await GiesAppLogik.resetToLastStatus(item);
        }
        await _loadData();
      } catch (e) {
        debugPrint("Update Fehler: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kfzListe = ["Alle KFZ", ..._allData.map((e) => e['kennzeichen']?.toString()).whereType<String>().toSet()].toList()..sort();
    final stadtteilListe = ["Alle Stadtteile", ..._allData.map((e) => e['orte']?['strassen']?['stadtteil']?.toString()).whereType<String>().toSet()].toList()..sort();
    final int currentKW = _getISOWeek(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gießplan 2026"),
        actions: [
          if (_selectedIds.isNotEmpty) ...[
            ActionChip(
              backgroundColor: Colors.orange.shade700,
              label: Text("Reset (${_selectedIds.length})", style: const TextStyle(color: Colors.white)),
              onPressed: () => _bulkUpdate(false),
            ),
            const SizedBox(width: 8),
            ActionChip(
              backgroundColor: Colors.blue.shade800,
              label: Text("Erledigen (${_selectedIds.length})", style: const TextStyle(color: Colors.white)),
              onPressed: () => _bulkUpdate(true),
            ),
            const SizedBox(width: 8),
          ],
          DropdownButton<String>(
            value: _selectedStatus,
            items: ["Alle", "Offen", "Erledigt"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) { setState(() { _selectedStatus = v!; _applyFilter(); }); },
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedStadtteil,
            items: stadtteilListe.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) { setState(() { _selectedStadtteil = v!; _applyFilter(); }); },
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedKennzeichen,
            items: kfzListe.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
            onChanged: (v) { setState(() { _selectedKennzeichen = v!; _applyFilter(); }); },
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedKW,
            items: List.generate(52, (i) => DropdownMenuItem(value: i + 1, child: Text("KW ${i + 1}${i + 1 == currentKW ? ' (*)' : ''}"))),
            onChanged: (v) { setState(() { _selectedKW = v!; _loadData(); }); },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Row(
            children: [
              Expanded(
                flex: 4, 
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Suchen...", 
                          prefixIcon: const Icon(Icons.search), 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        onChanged: (v) { _searchQuery = v; _applyFilter(); },
                      ),
                    ),
                    Expanded(child: _buildListPart()),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(flex: 6, child: _buildMapPart()),
            ],
          ),
    );
  }

  Widget _buildListPart() {
    if (_filteredData.isEmpty) return const Center(child: Text("Keine Einträge gefunden."));
    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemCount: _filteredData.length,
      itemBuilder: (ctx, i) {
        final item = _filteredData[i];
        final idStr = item['id'].toString();
        final done = item['erledigt'] ?? false;
        final isSelected = _selectedIds.contains(idStr);
        
        final String rawStrasse = item['orte']['strassen']?['name'] ?? '';
        final String hnr = (item['orte']['hausnummer'] == null || item['orte']['hausnummer'] == 'null') ? "" : " ${item['orte']['hausnummer']}";
        final String beschr = item['orte']['beschreibung_genau'] ?? '';
        final String taetigkeit = item['massnahmen']?['taetigkeiten']?['beschreibung_kurz'] ?? 'Gießen';

        String title = rawStrasse.isNotEmpty ? "$rawStrasse$hnr" : (beschr.isNotEmpty ? beschr : "Ort ID: $idStr");

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: isSelected ? Colors.blue.shade100 : (done ? Colors.green.shade50 : Colors.white),
          elevation: isSelected ? 8 : 1,
          shape: isSelected ? RoundedRectangleBorder(side: BorderSide(color: Colors.blue.shade700, width: 2), borderRadius: BorderRadius.circular(8)) : null,
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (v) => setState(() => v! ? _selectedIds.add(idStr) : _selectedIds.remove(idStr)),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rawStrasse.isNotEmpty && beschr.isNotEmpty) 
                  Text(beschr, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                Text("$taetigkeit | ${DateFormat('dd.MM.').format(DateTime.parse(item['geplant_am']))} | ${item['kennzeichen'] ?? '-'}"),
              ],
            ),
            trailing: IconButton(
              icon: Icon(done ? Icons.check_circle : Icons.panorama_fish_eye, color: done ? Colors.green : Colors.grey, size: 30),
              onPressed: () => _toggleStatus(item),
            ),
            onTap: () {
              setState(() {
                _selectedIds.clear();
                _selectedIds.add(idStr);
              });
              _mapController.move(LatLng(item['orte']['latitude'], item['orte']['longitude']), 18.0);
            },
          ),
        );
      },
    );
  }

  Widget _buildMapPart() {
    Map<String, int> coordCounter = {};
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: _badKissingen, initialZoom: 14.5),
          children: [
            TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
            if (_mapMode == 1) TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd']),
            MarkerLayer(
              markers: List.generate(_filteredData.length, (index) {
                final item = _filteredData[index];
                final idStr = item['id'].toString();
                final bool done = item['erledigt'] ?? false;
                final bool isSelected = _selectedIds.contains(idStr);

                final double baseLat = item['orte']['latitude'];
                final double baseLng = item['orte']['longitude'];
                final String coordKey = "$baseLat\_$baseLng";
                
                int count = coordCounter[coordKey] ?? 0;
                coordCounter[coordKey] = count + 1;
                final double finalLat = baseLat + (count * 0.0002);
                final LatLng point = LatLng(finalLat, baseLng);

                return Marker(
                  point: point,
                  width: isSelected ? 70 : 50,
                  height: isSelected ? 70 : 50,
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onTap: () => _onMarkerTap(idStr, point, index),
                    child: Icon(
                      isSelected ? Icons.location_on : (done ? Icons.check_circle : Icons.location_on),
                      color: isSelected ? Colors.blue.shade700 : (done ? Colors.green : Colors.red),
                      size: isSelected ? 60 : 40,
                      shadows: isSelected ? [const Shadow(color: Colors.black45, blurRadius: 12)] : null,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        Positioned(
          bottom: 20, right: 10,
          child: FloatingActionButton.small(
            backgroundColor: Colors.white,
            onPressed: () => setState(() => _mapMode = _mapMode == 0 ? 1 : 0),
            child: Icon(_mapMode == 1 ? Icons.map : Icons.satellite_alt, color: Colors.blue),
          ),
        ),
      ],
    );
  }
}