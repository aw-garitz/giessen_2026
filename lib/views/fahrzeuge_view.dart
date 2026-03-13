import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FahrzeugeView extends StatefulWidget {
  const FahrzeugeView({super.key});

  @override
  State<FahrzeugeView> createState() => _FahrzeugeViewState();
}

class _FahrzeugeViewState extends State<FahrzeugeView> {
  final supabase = Supabase.instance.client;
  List<dynamic> _fahrzeuge = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFahrzeuge();
  }

  Future<void> _loadFahrzeuge() async {
    setState(() => _isLoading = true);
    try {
      // Sortierung nach Bezeichnung
      final data = await supabase
          .from('fahrzeuge')
          .select()
          .order('bezeichnung', ascending: true);
      setState(() {
        _fahrzeuge = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Fehler beim Laden: $e");
      setState(() => _isLoading = false);
    }
  }

  void _zeigeFahrzeugDialog({Map<String, dynamic>? fahrzeug}) {
    final bool isEdit = fahrzeug != null;
    final bezeichnungController = TextEditingController(text: fahrzeug?['bezeichnung'] ?? "");
    final kennzeichenController = TextEditingController(text: fahrzeug?['kennzeichen'] ?? "");
    bool istAktiv = fahrzeug?['aktiv'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder( // Nötig, um die Checkbox im Dialog zu aktualisieren
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? "Fahrzeug bearbeiten" : "Neues Fahrzeug"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bezeichnungController,
                decoration: const InputDecoration(labelText: "Bezeichnung (z.B. LKW klein)"),
              ),
              TextField(
                controller: kennzeichenController,
                decoration: const InputDecoration(labelText: "Kennzeichen"),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text("Aktiv"),
                value: istAktiv,
                onChanged: (val) => setDialogState(() => istAktiv = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abbrechen")),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'bezeichnung': bezeichnungController.text,
                  'kennzeichen': kennzeichenController.text,
                  'aktiv': istAktiv,
                };
                if (isEdit) {
                  await supabase.from('fahrzeuge').update(data).eq('id', fahrzeug['id']);
                } else {
                  await supabase.from('fahrzeuge').insert(data);
                }
                Navigator.pop(ctx);
                _loadFahrzeuge();
              },
              child: const Text("Speichern"),
            ),
          ],
        ),
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
              const Text("Fuhrpark", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _zeigeFahrzeugDialog(),
                icon: const Icon(Icons.add),
                label: const Text("Fahrzeug hinzufügen"),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _fahrzeuge.length,
                  itemBuilder: (ctx, i) {
                    final f = _fahrzeuge[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(Icons.local_shipping, color: f['aktiv'] ? Colors.green : Colors.grey),
                        title: Text(f['bezeichnung'] ?? "Ohne Namen"),
                        subtitle: Text("Kennzeichen: ${f['kennzeichen'] ?? '-'}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _zeigeFahrzeugDialog(fahrzeug: f),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                await supabase.from('fahrzeuge').delete().eq('id', f['id']);
                                _loadFahrzeuge();
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