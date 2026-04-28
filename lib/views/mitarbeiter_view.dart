import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MitarbeiterView extends StatefulWidget {
  const MitarbeiterView({super.key});

  @override
  State<MitarbeiterView> createState() => _MitarbeiterViewState();
}

class _MitarbeiterViewState extends State<MitarbeiterView> {
  final supabase = Supabase.instance.client;
  List<dynamic> _mitarbeiter = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMitarbeiter();
  }

  Future<void> _fetchMitarbeiter() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final data = await supabase
          .from('mitarbeiter')
          .select()
          .order('nachname', ascending: true);

      if (mounted) {
        setState(() {
          _mitarbeiter = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  // Dialog für Hinzufügen & Bearbeiten
  void _zeigeEditor({Map<String, dynamic>? person}) {
    final isEdit = person != null;
    final vornameController = TextEditingController(
      text: person?['vorname'] ?? '',
    );
    final nachnameController = TextEditingController(
      text: person?['nachname'] ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Mitarbeiter bearbeiten' : 'Neuer Mitarbeiter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: vornameController,
              decoration: const InputDecoration(labelText: 'Vorname'),
              autofocus: true,
            ),
            TextField(
              controller: nachnameController,
              decoration: const InputDecoration(labelText: 'Nachname'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final vName = vornameController.text.trim();
              final nName = nachnameController.text.trim();

              if (vName.isEmpty || nName.isEmpty) return;

              try {
                if (isEdit) {
                  await supabase
                      .from('mitarbeiter')
                      .update({'vorname': vName, 'nachname': nName})
                      .eq('mitarbeiter_id', person['mitarbeiter_id']);
                } else {
                  await supabase.from('mitarbeiter').insert({
                    'vorname': vName,
                    'nachname': nName,
                  });
                }
                if (mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  _fetchMitarbeiter();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fehler beim Speichern: $e')),
                  );
                }
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  // Sicherheitsabfrage zum Löschen
  Future<void> _loeschen(dynamic id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Löschen bestätigen'),
        content: Text('Mitarbeiter "$name" wirklich entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nein'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('mitarbeiter').delete().eq('mitarbeiter_id', id);
        _fetchMitarbeiter();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mitarbeiter-Verwaltung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMitarbeiter,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mitarbeiter.isEmpty
          ? const Center(child: Text('Keine Mitarbeiter gefunden.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mitarbeiter.length,
              itemBuilder: (context, index) {
                final m = _mitarbeiter[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(m['nachname'][0].toUpperCase()),
                    ),
                    title: Text('${m['vorname']} ${m['nachname']}'),
                    subtitle: Text(
                      'ID: ${m['mitarbeiter_id'].toString().split('-')[0]}...',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _zeigeEditor(person: m),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _loeschen(
                            m['mitarbeiter_id'],
                            '${m['vorname']} ${m['nachname']}',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _zeigeEditor(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}
