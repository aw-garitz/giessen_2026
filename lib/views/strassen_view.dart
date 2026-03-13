import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StrassenView extends StatefulWidget {
  const StrassenView({super.key});

  @override
  State<StrassenView> createState() => _StrassenViewState();
}

class _StrassenViewState extends State<StrassenView> {
  final supabase = Supabase.instance.client;
  List<dynamic> _strassen = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStrassen();
  }

  Future<void> _loadStrassen() async {
    setState(() => _isLoading = true);
    try {
      // Alphabetische Sortierung nach Name
      final data = await supabase
          .from('strassen')
          .select()
          .order('name', ascending: true);
      setState(() {
        _strassen = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Fehler beim Laden der Straßen: $e");
      setState(() => _isLoading = false);
    }
  }

  void _zeigeStrassenDialog({Map<String, dynamic>? strasse}) {
    final bool isEdit = strasse != null;
    final nameController = TextEditingController(text: strasse?['name'] ?? "");
    final stadtteilController = TextEditingController(text: strasse?['stadtteil'] ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? "Straße bearbeiten" : "Neue Straße anlegen"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Straßenname",
                hintText: "z.B. Ludwigstraße",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: stadtteilController,
              decoration: const InputDecoration(
                labelText: "Stadtteil",
                hintText: "z.B. Bad Kissingen (Kernstadt)",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abbrechen")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              
              final data = {
                'name': nameController.text,
                'stadtteil': stadtteilController.text,
              };

              try {
                if (isEdit) {
                  await supabase.from('strassen').update(data).eq('id', strasse['id']);
                } else {
                  await supabase.from('strassen').insert(data);
                }
                Navigator.pop(ctx);
                _loadStrassen();
              } catch (e) {
                debugPrint("Fehler beim Speichern: $e");
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Straßenverzeichnis", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _zeigeStrassenDialog(),
                icon: const Icon(Icons.add_road),
                label: const Text("Straße hinzufügen"),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _strassen.length,
                  itemBuilder: (ctx, i) {
                    final s = _strassen[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.map, color: Colors.white),
                        ),
                        title: Text(s['name'] ?? "Unbekannte Straße", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(s['stadtteil'] != null && s['stadtteil'].toString().isNotEmpty 
                          ? "Stadtteil: ${s['stadtteil']}" 
                          : "Kein Stadtteil hinterlegt"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _zeigeStrassenDialog(strasse: s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                // Sicherheitsabfrage vor dem Löschen
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Straße löschen?"),
                                    content: Text("Möchten Sie '${s['name']}' wirklich entfernen?"),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Nein")),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Ja, löschen")),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await supabase.from('strassen').delete().eq('id', s['id']);
                                  _loadStrassen();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}