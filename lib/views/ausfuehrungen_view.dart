import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:giessen_app/funktionen/fn_allgemein.dart';

class AusfuehrungenView extends StatefulWidget {
  const AusfuehrungenView({super.key});

  @override
  State<AusfuehrungenView> createState() => _AusfuehrungenViewState();
}

class _AusfuehrungenViewState extends State<AusfuehrungenView> {
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
    return GiesAppLogik.getISOWeek(date);
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await GiesAppLogik.ladeAusfuehrungenProKW(_selectedKW);
      setState(() {
        _allData = data;
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

  Future<void> _bulkUpdate(bool markAsDone) async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      for (var id in _selectedIds) {
        final item = _allData.firstWhere((e) => e['id'].toString() == id);
        if (markAsDone) {
          String? kfz = _selectedKennzeichen == "Alle KFZ" ? null : _selectedKennzeichen;
          await GiesAppLogik.erledigenUndPlanen(item, kfz: kfz);
        } else {
          await GiesAppLogik.resetToLastStatus(item);
        }
      }
      _selectedIds.clear();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${markAsDone ? 'Erledigt' : 'Reset'} für ${_selectedIds.length} Orte durchgeführt.")));
      }
    } catch (e) {
      debugPrint("Bulk Fehler: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler: $e")));
      setState(() => _isLoading = false);
    }
  }

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

  // Hilfsmethode: einheitliches Filter-Dropdown
  Widget _filterDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required void Function(T) onChanged,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.blueGrey),
            const SizedBox(width: 6),
          ],
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
              items: items.map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item)),
              )).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<String> kfzListe, List<String> stadtteilListe, int currentKW) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Bulk-Aktionen wenn Auswahl aktiv
            if (_selectedIds.isNotEmpty) ...[
              ActionChip(
                avatar: const Icon(Icons.undo, size: 16, color: Colors.white),
                backgroundColor: Colors.orange.shade700,
                label: Text("Reset (${_selectedIds.length})", style: const TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () => _bulkUpdate(false),
              ),
              const SizedBox(width: 6),
              ActionChip(
                avatar: const Icon(Icons.check, size: 16, color: Colors.white),
                backgroundColor: Colors.blue.shade800,
                label: Text("Erledigen (${_selectedIds.length})", style: const TextStyle(color: Colors.white, fontSize: 12)),
                onPressed: () => _bulkUpdate(true),
              ),
              const SizedBox(width: 12),
              const SizedBox(height: 32, child: VerticalDivider(width: 1)),
              const SizedBox(width: 12),
            ],

            // Filter-Dropdowns
            _filterDropdown<String>(
              label: "Status",
              icon: Icons.filter_list,
              value: _selectedStatus,
              items: ["Alle", "Offen", "Erledigt"],
              itemLabel: (s) => s,
              onChanged: (v) => setState(() { _selectedStatus = v; _applyFilter(); }),
            ),
            const SizedBox(width: 8),
            _filterDropdown<String>(
              label: "Stadtteil",
              icon: Icons.location_city,
              value: _selectedStadtteil,
              items: stadtteilListe,
              itemLabel: (s) => s,
              onChanged: (v) => setState(() { _selectedStadtteil = v; _applyFilter(); }),
            ),
            const SizedBox(width: 8),
            _filterDropdown<String>(
              label: "Fahrzeug",
              icon: Icons.local_shipping,
              value: _selectedKennzeichen,
              items: kfzListe,
              itemLabel: (k) => k,
              onChanged: (v) => setState(() { _selectedKennzeichen = v; _applyFilter(); }),
            ),
            const SizedBox(width: 8),
            _filterDropdown<int>(
              label: "KW",
              icon: Icons.calendar_today,
              value: _selectedKW,
              items: List.generate(52, (i) => i + 1),
              itemLabel: (kw) => "KW $kw${kw == currentKW ? ' ✦' : ''}",
              onChanged: (v) => setState(() { _selectedKW = v; _loadData(); }),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.blueGrey),
              tooltip: "Neu laden",
              onPressed: _loadData,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kfzListe = ["Alle KFZ", ..._allData.map((e) => e['kennzeichen']?.toString()).whereType<String>().toSet()].toList()..sort();
    final stadtteilListe = ["Alle Stadtteile", ..._allData.map((e) => e['orte']?['strassen']?['stadtteil']?.toString()).whereType<String>().toSet()].toList()..sort();
    final int currentKW = _getISOWeek(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gießplan 2026"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // LINKE LISTE
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Suchen...",
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (v) { _searchQuery = v; _applyFilter(); },
                        ),
                      ),
                      Expanded(child: _buildListPart()),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                // RECHTE KARTE mit Filterleiste
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _buildFilterBar(kfzListe, stadtteilListe, currentKW),
                      Expanded(child: _buildMapPart()),
                    ],
                  ),
                ),
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
          shape: isSelected
              ? RoundedRectangleBorder(side: BorderSide(color: Colors.blue.shade700, width: 2), borderRadius: BorderRadius.circular(8))
              : null,
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
                if ((item['massnahmen']?['auftragsnummer'] ?? '').toString().isNotEmpty)
  Text(
    "Auftrag: ${item['massnahmen']?['auftragsnummer']}",
    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
  ),
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
            if (_mapMode == 1)
              TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}{r}.png', subdomains: const ['a', 'b', 'c', 'd']),
            MarkerLayer(
              markers: List.generate(_filteredData.length, (index) {
                final item = _filteredData[index];
                final idStr = item['id'].toString();
                final bool done = item['erledigt'] ?? false;
                final bool isSelected = _selectedIds.contains(idStr);

                final double baseLat = item['orte']['latitude'];
                final double baseLng = item['orte']['longitude'];
                final String coordKey = "${baseLat}_$baseLng";

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