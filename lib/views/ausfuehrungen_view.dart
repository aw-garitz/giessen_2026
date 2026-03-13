import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AusfuehrungenView extends StatefulWidget {
  const AusfuehrungenView({super.key});

  @override
  State<AusfuehrungenView> createState() => _AusfuehrungenViewState();
}

class _AusfuehrungenViewState extends State<AusfuehrungenView> {
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  // Daten-Listen
  List<dynamic> _allData = []; 
  List<dynamic> _filteredData = []; 
  final Set<String> _selectedIds = {}; 
  
  // Status-Variablen
  bool _isLoading = true;
  int _selectedKW = 1;
  String _selectedKennzeichen = "Alle KFZ";
  String _selectedStadtteil = "Alle Stadtteile";
  String _selectedStatus = "Alle"; 
  String _searchQuery = "";
  int _mapMode = 1; // 1 = Satellit (Hybrid) als Standard

  final LatLng _badKissingen = const LatLng(50.2015, 10.0765);

  @override
  void initState() {
    super.initState();
    _selectedKW = _getISOWeek(DateTime.now());
    _loadData();
  }

  // --- HILFSFUNKTIONEN ---
  int _getISOWeek(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    return ((dayOfYear - date.weekday + 10) / 7).floor();
  }

  DateTime _getStartOfKW(int kw) {
    return DateTime(2026, 1, 1).add(Duration(days: (kw - 1) * 7 - 3));
  }

  // --- DATEN LADEN ---
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { 
      _isLoading = true; 
      _selectedIds.clear(); 
    });
    try {
      final start = _getStartOfKW(_selectedKW);
      final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));

      final res = await supabase.from('ausfuehrung').select('''
        id, 
        erledigt, 
        liter_ist, 
        geplant_am,
        kennzeichen,
        orte (
          id, 
          beschreibung_genau, 
          hausnummer, 
          latitude, 
          longitude,
          strassen (name, stadtteil)
        ), 
        massnahmen (
          taetigkeiten (beschreibung_kurz)
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
      _filteredData = _allData.where((item) {
        final kfz = item['kennzeichen'] ?? "Ohne KFZ";
        final stadtteil = item['orte']?['strassen']?['stadtteil'] ?? "Unbekannt";
        final strasse = (item['orte']?['strassen']?['name'] ?? "").toString().toLowerCase();
        final hnr = (item['orte']?['hausnummer'] ?? "").toString().toLowerCase();
        final beschr = (item['orte']?['beschreibung_genau'] ?? "").toString().toLowerCase();
        final bool done = item['erledigt'] ?? false;
        
        bool matchesKfz = _selectedKennzeichen == "Alle KFZ" || kfz == _selectedKennzeichen;
        bool matchesStadtteil = _selectedStadtteil == "Alle Stadtteile" || stadtteil == _selectedStadtteil;
        
        // Suche erweitert auf Hausnummer und Beschreibung
        bool matchesSearch = _searchQuery.isEmpty || 
                            strasse.contains(_searchQuery.toLowerCase()) || 
                            hnr.contains(_searchQuery.toLowerCase()) || 
                            beschr.contains(_searchQuery.toLowerCase());
        
        bool matchesStatus = true;
        if (_selectedStatus == "Offen") matchesStatus = !done;
        if (_selectedStatus == "Erledigt") matchesStatus = done;
        
        return matchesKfz && matchesStadtteil && matchesStatus && matchesSearch;
      }).toList();
    });
  }

  // --- ACTIONS ---
  Future<void> _bulkUpdate(bool markAsDone) async {
    if (_selectedIds.isEmpty) return;
    
    final actionText = markAsDone ? "erledigen (0 Liter)" : "auf OFFEN zurücksetzen";
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Sammel-Aktion"),
        content: Text("${_selectedIds.length} Einträge wirklich $actionText?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Abbruch")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(
              backgroundColor: markAsDone ? Colors.blue : Colors.orange, 
              foregroundColor: Colors.white
            ),
            child: Text(markAsDone ? "Ausführen" : "Resetten"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('ausfuehrung').update({
          'erledigt': markAsDone,
          'liter_ist': markAsDone ? 0 : null,
          'bemerkung': markAsDone ? 'Sammelbuchung' : null
        }).filter('id', 'in', _selectedIds.toList());
        
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Einträge aktualisiert.")));
      } catch (e) {
        debugPrint("Fehler beim Bulk-Update: $e");
      }
    }
  }

  Future<void> _einzelBuchung(Map<String, dynamic> item) async {
    final controller = TextEditingController(text: item['liter_ist']?.toString() ?? "100");
    final ort = item['orte'];
    final hnr = (ort?['hausnummer'] == null || ort?['hausnummer'] == 'null') ? "" : " ${ort['hausnummer']}";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${ort?['strassen']?['name'] ?? 'Unbekannt'}$hnr"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Liter IST", suffixText: "L"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abbruch")),
          ElevatedButton(
            onPressed: () async {
              await supabase.from('ausfuehrung').update({
                'erledigt': true,
                'liter_ist': double.tryParse(controller.text.replaceAll(',', '.')) ?? 0,
              }).eq('id', item['id']);
              if (!mounted) return;
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text("Speichern"),
          )
        ],
      ),
    );
  }

  // --- UI KOMPONENTEN ---
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
              avatar: const Icon(Icons.undo, color: Colors.white, size: 16),
              label: const Text("Reset", style: TextStyle(color: Colors.white)),
              onPressed: () => _bulkUpdate(false),
            ),
            const SizedBox(width: 8),
            ActionChip(
              backgroundColor: Colors.blue.shade800,
              avatar: const Icon(Icons.done_all, color: Colors.white, size: 16),
              label: Text("${_selectedIds.length} erledigen", style: const TextStyle(color: Colors.white)),
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
            items: List.generate(52, (i) {
              int kw = i + 1;
              bool isCurrent = kw == currentKW;
              return DropdownMenuItem(
                value: kw,
                child: Text(
                  isCurrent ? "KW $kw (*)" : "KW $kw",
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? Colors.blue.shade900 : Colors.black,
                  ),
                ),
              );
            }),
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
                          hintText: "Nach Straße, Hnr. oder Merkmal suchen...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (v) {
                          setState(() {
                            _searchQuery = v;
                            _applyFilter();
                          });
                        },
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
    return ListView.builder(
      itemCount: _filteredData.length,
      itemBuilder: (ctx, i) {
        final item = _filteredData[i];
        final ort = item['orte'];
        final idStr = item['id'].toString();
        final done = item['erledigt'] ?? false;
        
        final String strasse = ort?['strassen']?['name'] ?? 'Unbekannt';
        final String hnr = (ort?['hausnummer'] == null || ort?['hausnummer'] == 'null') ? "" : " ${ort['hausnummer']}";
        final String stadtteil = ort?['strassen']?['stadtteil'] ?? 'Unbekannt';
        final String beschreibung = ort?['beschreibung_genau'] ?? ''; // <--- NEU
        final String taetigkeit = item['massnahmen']?['taetigkeiten']?['beschreibung_kurz'] ?? 'Gießen';
        final String datum = DateFormat('dd.MM.yyyy').format(DateTime.parse(item['geplant_am']));

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          elevation: 2,
          color: _selectedIds.contains(idStr) ? Colors.blue.shade50 : (done ? Colors.green.shade50 : Colors.white),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: Checkbox(
              value: _selectedIds.contains(idStr),
              onChanged: (v) => setState(() => v! ? _selectedIds.add(idStr) : _selectedIds.remove(idStr)),
            ),
            title: Text("$strasse$hnr", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                // Tätigkeit und Beschreibung kombiniert
                Text("$taetigkeit | $stadtteil", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                if (beschreibung.isNotEmpty) ...[
                   const SizedBox(height: 2),
                   Text("📍 $beschreibung", style: TextStyle(color: Colors.blueGrey.shade700, fontStyle: FontStyle.italic, fontSize: 13)),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(datum, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    const SizedBox(width: 10),
                    const Icon(Icons.car_repair, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(item['kennzeichen'] ?? "-", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(done ? Icons.check_circle : Icons.water_drop, color: done ? Colors.green : Colors.red, size: 28),
              onPressed: () => _einzelBuchung(item),
            ),
            onTap: () {
              if (ort['latitude'] != null) {
                _mapController.move(LatLng(ort['latitude'], ort['longitude']), 17.5);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildMapPart() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: _badKissingen, initialZoom: 14.5),
          children: [
            TileLayer(
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            ),
            if (_mapMode == 1)
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
            if (_mapMode == 0)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
            MarkerLayer(
              markers: _filteredData.where((e) => e['orte']?['latitude'] != null).map((item) {
                final ort = item['orte'];
                final idStr = item['id'].toString();
                final bool isSelected = _selectedIds.contains(idStr);
                final bool done = item['erledigt'] ?? false;

                return Marker(
                  point: LatLng(ort['latitude'], ort['longitude']),
                  width: 45, height: 45,
                  child: GestureDetector(
                    onTap: () => setState(() => isSelected ? _selectedIds.remove(idStr) : _selectedIds.add(idStr)),
                    child: Icon(
                      isSelected ? Icons.check_box : Icons.location_on,
                      color: isSelected ? Colors.blue : (done ? Colors.green : Colors.red),
                      size: isSelected ? 30 : 40,
                    ),
                  ),
                );
              }).toList(),
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