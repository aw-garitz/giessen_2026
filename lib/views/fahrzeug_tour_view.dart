import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:giessen_app/funktionen/fn_allgemein.dart';
import 'package:giessen_app/funktionen/offline_sync_service.dart';

class FahrzeugTourScreen extends StatefulWidget {
  const FahrzeugTourScreen({super.key});

  @override
  State<FahrzeugTourScreen> createState() => _FahrzeugTourScreenState();
}

class _FahrzeugTourScreenState extends State<FahrzeugTourScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _tourDaten = [];
  bool _isLoading = true;
  String? _kennzeichen;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _ladeTour();
  }

  Future<void> _ladeTour() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final kz = prefs.getString('gewaehltes_kennzeichen');

    if (kz == null) {
      setState(() { _isLoading = false; _kennzeichen = null; });
      return;
    }

    try {
      // Wir laden die Ausführungen PLUS die Details zum Ort (Name/Strasse)
      // Gefiltert nach dem Kennzeichen der Massnahme und 'nicht erledigt'
      final data = await supabase
    .from('ausfuehrung')
    .select('''
      *,
      massnahmen!inner(
        kennzeichen,
        orte(name, strasse, latitude, longitude)
      )
    ''')
    .eq('erledigt', false)
    .eq('massnahmen.kennzeichen', kz) // Hier greift der Filter auf die verknüpfte Tabelle
    .order('geplant_am', ascending: true);

      setState(() {
        _tourDaten = data;
        _kennzeichen = kz;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Fehler beim Laden der Tour: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _bestaetigeEinsatz(dynamic item) async {
    final ort = item['massnahmen']?['orte'];
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Einsatz bestätigen"),
        content: Text(
          "Möchten Sie den Einsatz in der ${ort['strasse'] ?? 'unbekannten Straße'} jetzt als erledigt markieren? Ihr Standort wird dabei erfasst.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Abbrechen")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("JA, ERLEDIGT")),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      // 1. Standort ermitteln
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      Position? position;
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      }

      // 2. Online/Offline Check
      final online = await OfflineSyncService.istOnline();

      if (online) {
        await GiesAppLogik.erledigenUndPlanen(
          item,
          kfz: _kennzeichen,
          lat: position?.latitude,
          lng: position?.longitude,
          accuracy: position?.accuracy,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Einsatz erfolgreich gebucht ✅"), backgroundColor: Colors.green),
          );
        }
      } else {
        await OfflineSyncService.speichereLokal(
          ausfuehrung: item,
          typ: 'erledigt',
          kfz: _kennzeichen,
          lat: position?.latitude,
          lng: position?.longitude,
          accuracy: position?.accuracy,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Offline gespeichert – Sync erfolgt bei WLAN"), backgroundColor: Colors.orange),
          );
        }
      }
      
      _ladeTour(); // Liste aktualisieren
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_kennzeichen ?? "Tour wählen"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _ladeTour,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Die gewünschte Anzeige der Anzahl der Datensätze
                Container(
                  width: double.infinity,
                  color: Colors.blueGrey[50],
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Offene Einsätze:", style: TextStyle(fontWeight: FontWeight.bold)),
                      CircleAvatar(
                        backgroundColor: Colors.blueGrey[800],
                        radius: 14,
                        child: Text("${_tourDaten.length}", 
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading ? const Center(child: CircularProgressIndicator()) : _tourDaten.isEmpty
                      ? const Center(child: Text("Keine offenen Aufgaben für dieses Fahrzeug."))
                      : ListView.builder(
                          itemCount: _tourDaten.length,
                          itemBuilder: (context, index) {
                            final item = _tourDaten[index];
                            final ort = item['massnahmen']?['orte'];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              child: ListTile(
                                leading: const Icon(Icons.water_drop, color: Colors.blue),
                                title: Text(ort['name'] ?? "Unbekannter Baum"),
                                subtitle: Text("${ort['strasse'] ?? ''} - geplant: ${item['geplant_am']}"),
                                trailing: _isProcessing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
                                onTap: _isProcessing ? null : () => _bestaetigeEinsatz(item),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}