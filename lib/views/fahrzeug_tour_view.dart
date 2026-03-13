import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      massnahmen!inner(kennzeichen), 
      orte(name, strasse)
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
                  child: _tourDaten.isEmpty
                      ? const Center(child: Text("Keine offenen Aufgaben für dieses Fahrzeug."))
                      : ListView.builder(
                          itemCount: _tourDaten.length,
                          itemBuilder: (context, index) {
                            final item = _tourDaten[index];
                            final ort = item['orte'];
                            return ListTile(
                              leading: const Icon(Icons.water_drop, color: Colors.blue),
                              title: Text(ort['name'] ?? "Unbekannter Baum"),
                              subtitle: Text("${ort['strasse'] ?? ''} - geplant: ${item['geplant_am']}"),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // Hier könnte man zur Detailansicht navigieren
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}