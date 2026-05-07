import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final supabase = Supabase.instance.client;
  
  List<String> _kennzeichenAusDB = [];
  String? _ausgewaehltesFahrzeug;
  
  List<dynamic> _orte = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _ladeFahrzeuge();
  }

  Future<void> _ladeFahrzeuge() async {
    try {
      final data = await supabase.from('fahrzeuge').select('kennzeichen');
      setState(() {
        _kennzeichenAusDB = (data as List).map((item) => item['kennzeichen'].toString()).toList();
      });
    } catch (e) {
      debugPrint("Fehler Fahrzeuge: $e");
    }
  }

  Future<void> _ladeAuftraegeFuerFahrzeug(String kennzeichen) async {
    setState(() {
      _isLoading = true;
      _ausgewaehltesFahrzeug = kennzeichen;
    });
    try {
      // Wir laden jetzt explizit latitude und longitude aus der Tabelle 'orte'
      final data = await supabase
          .from('orte')
          .select('id, beschreibung_genau, latitude, longitude, massnahmen!inner(*), ausfuehrung(*)')
          .eq('massnahmen.kennzeichen', kennzeichen)
          .eq('massnahmen.beendet', false);

      setState(() {
        _orte = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Fehler beim Filtern: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _kennzeichenAusDB.isEmpty 
          ? const Text("Lade Fahrzeuge...") 
          : DropdownButton<String>(
              value: _ausgewaehltesFahrzeug,
              hint: const Text("Fahrzeug wählen"),
              isExpanded: true,
              items: _kennzeichenAusDB.map((String k) {
                return DropdownMenuItem<String>(value: k, child: Text(k));
              }).toList(),
              onChanged: (val) {
                if (val != null) _ladeAuftraegeFuerFahrzeug(val);
              },
            ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(50.2015, 10.0765), // Bad Kissingen
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.deinefirma.giessapp',
              ),
              MarkerLayer(
                markers: _orte.where((ort) => ort['latitude'] != null && ort['longitude'] != null).map((ort) {
                  final ausfuehrungen = ort['ausfuehrung'] as List?;
                  final bool schonGegossen = ausfuehrungen != null && ausfuehrungen.isNotEmpty;
                  
                  return Marker(
                    // DIREKTER ZUGRIFF OHNE PARSING
                    point: LatLng(
                      (ort['latitude'] as num).toDouble(), 
                      (ort['longitude'] as num).toDouble()
                    ),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showGiessenDialog(ort),
                      child: Icon(
                        Icons.location_on, 
                        color: schonGegossen ? Colors.green : Colors.red,
                        size: 40
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
    );
  }

  void _showGiessenDialog(dynamic ort) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ort['beschreibung_genau'] ?? "Unbekannter Ort", 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Fahrzeug: $_ausgewaehltesFahrzeug"),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              onPressed: () async {
                try {
                  await supabase.from('ausfuehrung').insert({
                    'ort_id': ort['id'],
                    'kennzeichen': _ausgewaehltesFahrzeug,
                    'status': 'erledigt', // DB-Constraint beachten (kleingeschrieben)
                    'erledigt': true,
                    'erledigt_am': DateTime.now().toIso8601String(),
                  });
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _ladeAuftraegeFuerFahrzeug(_ausgewaehltesFahrzeug!); 
                  }
                } catch (e) {
                  debugPrint("Speicherfehler: $e");
                }
              },
              child: const Text("Gießen bestätigen", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}