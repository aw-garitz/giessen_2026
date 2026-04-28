import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class OrteView extends StatefulWidget {
  const OrteView({super.key});

  @override
  State<OrteView> createState() => _OrteViewState();
}

class _OrteViewState extends State<OrteView> {
  final supabase = Supabase.instance.client;
  final MapController _mapController = MapController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  List<dynamic> _orte = [];
  List<dynamic> _gefilterteOrte = [];
  List<Map<String, dynamic>> _alleStrassen = [];

  final _sucheController = TextEditingController();
  bool _isLoading = true;
  int _mapMode = 2;
  LatLng? _markerVorschau;
  Map<String, dynamic>? _selectedItem;

  final LatLng _badKissingenZentrum = const LatLng(50.1992, 10.0781);

  final String _streetUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  final String _satelliteUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  final String _labelUrl =
      'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}{r}.png';

  @override
  void initState() {
    super.initState();
    _ladeBasisDaten();
    _sucheController.addListener(_filtereListe);
  }

  @override
  void dispose() {
    _sucheController.dispose();
    super.dispose();
  }

  Future<void> _ladeBasisDaten() async {
    setState(() => _isLoading = true);
    try {
      final strassenData = await supabase
          .from('strassen')
          .select('id, name')
          .order('name');
      final orteData = await supabase
          .from('orte')
          .select('*, strassen(name, stadtteil)');

      List<dynamic> sortierteOrte = List.from(orteData);
      sortierteOrte.sort((a, b) {
        String strasseA = (a['strassen']?['name'] ?? '').toLowerCase();
        String strasseB = (b['strassen']?['name'] ?? '').toLowerCase();
        int comp = strasseA.compareTo(strasseB);
        if (comp != 0) return comp;

        // Numerische Sortierung für Hausnummern falls möglich
        String hnrA = (a['hausnummer'] ?? '');
        String hnrB = (b['hausnummer'] ?? '');
        return hnrA.compareTo(hnrB);
      });

      setState(() {
        _alleStrassen = List<Map<String, dynamic>>.from(strassenData);
        _orte = sortierteOrte;
        _gefilterteOrte = sortierteOrte;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Ladefehler: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filtereListe() {
    final query = _sucheController.text.toLowerCase();
    setState(() {
      _gefilterteOrte = _orte.where((o) {
        final strasse = (o['strassen']?['name'] ?? '').toString().toLowerCase();
        final beschr = (o['beschreibung_genau'] ?? '').toString().toLowerCase();
        final stadtteil = (o['strassen']?['stadtteil'] ?? '')
            .toString()
            .toLowerCase();
        final hnr = (o['hausnummer'] ?? '').toString().toLowerCase();
        return strasse.contains(query) ||
            beschr.contains(query) ||
            stadtteil.contains(query) ||
            hnr.contains(query);
      }).toList();
    });
  }

  bool _hatGps(Map<String, dynamic>? o) {
    if (o == null) return false;
    return o['latitude'] != null &&
        o['latitude'] != 0 &&
        o['longitude'] != null &&
        o['longitude'] != 0;
  }

  void _fokussiereOrt(Map<String, dynamic> o, int index) {
    setState(() => _selectedItem = o);
    if (_hatGps(o)) {
      _mapController.move(LatLng(o['latitude'], o['longitude']), 18);
    }
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.1, // Scrollt so, dass das Item oben im Sichtfeld ist
      );
    }
  }

  void _zeigeOrteDialog({Map<String, dynamic>? editItem}) {
    final bool isEdit = editItem != null;
    LatLng? positionFuerSpeichern =
        _markerVorschau ??
        (isEdit && _hatGps(editItem)
            ? LatLng(editItem['latitude'], editItem['longitude'])
            : null);

    final hnrController = TextEditingController(
      text: editItem?['hausnummer'] ?? "",
    );
    final beschrController = TextEditingController(
      text: editItem?['beschreibung_genau'] ?? "",
    );
    final strasseInputController = TextEditingController(
      text: editItem?['strassen']?['name'] ?? "",
    );
    String? selectedStrasseId = editItem?['strasse_id']?.toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(isEdit ? "📍 Standort anpassen" : "🆕 Neuer Standort"),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_markerVorschau != null)
                  Card(
                    color: Colors.blue.shade100,
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text(
                        "Info: Die neue Position vom blauen Marker wird übernommen.",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  )
                else if (positionFuerSpeichern == null)
                  Card(
                    color: Colors.orange.shade100,
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text(
                        "Keine GPS-Daten! Setze erst einen Marker. Lang auf die Karte klicken.",
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ),
                Autocomplete<Map<String, dynamic>>(
                  displayStringForOption: (option) => option['name'],
                  initialValue: TextEditingValue(
                    text: strasseInputController.text,
                  ),
                  optionsBuilder: (val) => _alleStrassen.where(
                    (s) => s['name'].toLowerCase().contains(
                      val.text.toLowerCase(),
                    ),
                  ),
                  onSelected: (s) => selectedStrasseId = s['id'].toString(),
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: "Straße suchen...",
                          ),
                        );
                      },
                ),
                TextField(
                  controller: hnrController,
                  decoration: const InputDecoration(labelText: "Hausnummer"),
                ),
                TextField(
                  controller: beschrController,
                  decoration: const InputDecoration(
                    labelText: "Beschreibung (z.B. Beet neben Springbrunnen)",
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: positionFuerSpeichern != null
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        positionFuerSpeichern != null
                            ? Icons.check_circle
                            : Icons.gps_off,
                        color: positionFuerSpeichern != null
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        positionFuerSpeichern != null
                            ? "GPS bereit"
                            : "GPS fehlt",
                        style: TextStyle(
                          color: positionFuerSpeichern != null
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Abbruch"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedStrasseId == null || positionFuerSpeichern == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Bitte Straße wählen und GPS-Punkt setzen!"),
                  ),
                );
                return;
              }
              final data = {
                'strasse_id': int.parse(selectedStrasseId!),
                'hausnummer': hnrController.text,
                'beschreibung_genau': beschrController.text,
                'latitude': positionFuerSpeichern.latitude,
                'longitude': positionFuerSpeichern.longitude,
              };
              try {
                if (isEdit) {
                  await supabase
                      .from('orte')
                      .update(data)
                      .eq('id', editItem['id']);
                } else {
                  await supabase.from('orte').insert(data);
                }
                if (mounted) {
                  Navigator.pop(ctx);
                  setState(() {
                    _markerVorschau = null;
                    _selectedItem = null;
                  });
                  _ladeBasisDaten();
                }
              } catch (e) {
                debugPrint("Fehler: $e");
              }
            },
            child: const Text("Speichern"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Column(
              children: [
                _buildHeader(),
                const Divider(height: 1),
                _buildListenBereich(),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _badKissingenZentrum,
                    initialZoom: 15,
                    onTap: (_, __) => setState(() => _selectedItem = null),
                    onLongPress: (tapPos, point) =>
                        setState(() => _markerVorschau = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _mapMode == 0 ? _streetUrl : _satelliteUrl,
                    ),
                    if (_mapMode == 2)
                      TileLayer(
                        urlTemplate: _labelUrl,
                        subdomains: const ['a', 'b', 'c', 'd'],
                      ),
                    MarkerLayer(
                      markers: [
                        ..._gefilterteOrte
                            .asMap()
                            .entries
                            .where((e) => _hatGps(e.value))
                            .map((entry) {
                              final int idx = entry.key;
                              final dynamic o = entry.value;
                              final bool isSelected =
                                  _selectedItem != null &&
                                  _selectedItem!['id'] == o['id'];
                              return Marker(
                                point: LatLng(o['latitude'], o['longitude']),
                                width: isSelected ? 80 : 40,
                                height: isSelected ? 80 : 40,
                                alignment: Alignment.bottomCenter,
                                child: GestureDetector(
                                  onTap: () => _fokussiereOrt(o, idx),
                                  child: Icon(
                                    Icons.location_on,
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.red,
                                    size: isSelected ? 65 : 30,
                                    shadows: isSelected
                                        ? [
                                            const Shadow(
                                              color: Colors.black45,
                                              blurRadius: 10,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            }),
                        if (_markerVorschau != null)
                          Marker(
                            point: _markerVorschau!,
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.add_location_alt,
                              color: Colors.blueAccent,
                              size: 55,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 15,
                  right: 15,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    onPressed: () =>
                        setState(() => _mapMode = (_mapMode + 1) % 3),
                    child: Icon(
                      _mapMode == 0
                          ? Icons.map
                          : (_mapMode == 1
                                ? Icons.satellite_alt
                                : Icons.layers),
                      color: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            "Standort-Verwaltung",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _zeigeOrteDialog(),
              icon: const Icon(Icons.add_location),
              label: const Text("NEUEN ORT ANLEGEN"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListenBereich() {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _sucheController,
              decoration: InputDecoration(
                hintText: "Nach Straße oder Stadtteil suchen...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          Expanded(
            child: ScrollablePositionedList.builder(
              itemScrollController: _itemScrollController,
              itemPositionsListener: _itemPositionsListener,
              itemCount: _gefilterteOrte.length,
              itemBuilder: (ctx, i) {
                final o = _gefilterteOrte[i];
                final bool gpsDa = _hatGps(o);
                final bool isSelected =
                    _selectedItem != null && _selectedItem!['id'] == o['id'];

                final strasse = o['strassen']?['name'] ?? 'Unbekannte Straße';
                final stadtteil = o['strassen']?['stadtteil'] ?? '';
                final hnr = o['hausnummer'] ?? '';
                final beschr = o['beschreibung_genau'] ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  elevation: isSelected ? 8 : 1,
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: isSelected
                          ? Colors.blue.shade700
                          : (gpsDa
                                ? Colors.transparent
                                : Colors.orange.shade300),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: gpsDa
                          ? (isSelected ? Colors.blue : Colors.green.shade50)
                          : Colors.orange.shade50,
                      child: Icon(
                        gpsDa ? Icons.location_on : Icons.location_off,
                        color: gpsDa
                            ? (isSelected ? Colors.white : Colors.green)
                            : Colors.orange,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      "$strasse $hnr",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (beschr.isNotEmpty)
                          Text(
                            beschr,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        if (stadtteil.isNotEmpty)
                          Text(
                            stadtteil,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _zeigeOrteDialog(editItem: o),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () =>
                              _loescheOrt(o['id'], "$strasse $hnr"),
                        ),
                      ],
                    ),
                    onTap: () => _fokussiereOrt(o, i),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loescheOrt(dynamic id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ort löschen?"),
        content: Text("Möchtest du '$name' wirklich permanent entfernen?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Abbruch"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Löschen"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await supabase.from('orte').delete().eq('id', id);
        _ladeBasisDaten();
      } catch (e) {
        debugPrint("Löschfehler: $e");
      }
    }
  }
}
