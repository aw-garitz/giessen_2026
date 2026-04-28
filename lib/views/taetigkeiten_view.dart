import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaetigkeitenView extends StatefulWidget {
  const TaetigkeitenView({super.key});

  @override
  State<TaetigkeitenView> createState() => _TaetigkeitenViewState();
}

class _TaetigkeitenViewState extends State<TaetigkeitenView> {
  final supabase = Supabase.instance.client;
  List<dynamic> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('taetigkeiten')
          .select()
          .order('beschreibung_kurz', ascending: true);
      setState(() {
        _data = res;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Fehler: $e");
      setState(() => _isLoading = false);
    }
  }

  void _zeigeDialog({Map<String, dynamic>? item}) {
    final bool isEdit = item != null;
    final kurzController = TextEditingController(
      text: item?['beschreibung_kurz'] ?? "",
    );
    final langController = TextEditingController(
      text: item?['beschreibung_lang'] ?? "",
    );
    final intervallController = TextEditingController(
      text: item?['intervall_tage']?.toString() ?? "",
    );
    final literController = TextEditingController(
      text: item?['liter_soll']?.toString() ?? "",
    );
    // NEU: Controller für Dauer
    final dauerController = TextEditingController(
      text: item?['dauer_tage']?.toString() ?? "",
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? "Tätigkeit bearbeiten" : "Neue Tätigkeit"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: kurzController,
                decoration: const InputDecoration(
                  labelText: "Kurzbezeichnung (z.B. Jungbaumpflege)",
                ),
              ),
              TextField(
                controller: langController,
                decoration: const InputDecoration(
                  labelText: "Lange Beschreibung",
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: intervallController,
                      decoration: const InputDecoration(
                        labelText: "Intervall (Tage)",
                        hintText: "z.B. 21",
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: dauerController,
                      decoration: const InputDecoration(
                        labelText: "Gesamtdauer (Tage)",
                        hintText: "Leer = ∞",
                        helperText: "3 J. = 1095 T.",
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: literController,
                decoration: const InputDecoration(
                  labelText: "Liter Soll",
                  suffixText: "L",
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Abbrechen"),
          ),
          ElevatedButton(
            onPressed: () async {
              final map = {
                'beschreibung_kurz': kurzController.text,
                'beschreibung_lang': langController.text,
                'intervall_tage': int.tryParse(intervallController.text) ?? 0,
                'liter_soll': double.tryParse(literController.text) ?? 0.0,
                // NEU: Speichern der Dauer
                'dauer_tage': int.tryParse(dauerController.text),
              };

              try {
                if (isEdit) {
                  await supabase
                      .from('taetigkeiten')
                      .update(map)
                      .eq('id', item['id']);
                } else {
                  await supabase.from('taetigkeiten').insert(map);
                }
                if (mounted) Navigator.pop(ctx);
                if (mounted) _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Fehler beim Speichern: $e")),
                  );
                }
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
              const Text(
                "Tätigkeiten",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _zeigeDialog(),
                icon: const Icon(Icons.add_task),
                label: const Text("Tätigkeit erstellen"),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _data.length,
                  itemBuilder: (ctx, i) {
                    final t = _data[i];
                    final int? dauer = t['dauer_tage'];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.water_drop_outlined),
                        ),
                        title: Text(
                          t['beschreibung_kurz'] ?? "Unbekannt",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${t['intervall_tage']} Tage Intervall | ${t['liter_soll']} L Soll",
                            ),
                            Text(
                              dauer == null || dauer == 0
                                  ? "Laufzeit: Unendlich (Dauerpflege)"
                                  : "Laufzeit: $dauer Tage",
                              style: TextStyle(
                                fontSize: 12,
                                color: dauer == null
                                    ? Colors.green
                                    : Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _zeigeDialog(item: t),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () async {
                                final bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Löschen?"),
                                    content: const Text(
                                      "Möchten Sie diese Tätigkeit wirklich entfernen?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text("Abbrechen"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text("Löschen"),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await supabase
                                      .from('taetigkeiten')
                                      .delete()
                                      .eq('id', t['id']);
                                  _loadData();
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
