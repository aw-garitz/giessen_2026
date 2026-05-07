import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:giessen_app/funktionen/fn_allgemein.dart';

class MassnahmenView extends StatefulWidget {
  const MassnahmenView({super.key});

  @override
  State<MassnahmenView> createState() => _MassnahmenViewState();
}

class _MassnahmenViewState extends State<MassnahmenView> {
  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _allMassnahmen = [];
  List<dynamic> _filteredMassnahmen = [];
  List<dynamic> _orte = [];
  List<dynamic> _taetigkeiten = [];
  List<dynamic> _fahrzeuge = [];

  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;

    double currentOffset = 0;
    if (_scrollController.hasClients) {
      currentOffset = _scrollController.offset;
    }

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        supabase.from('massnahmen').select('''
          *,
          orte(id, beschreibung_genau, hausnummer, strassen(name)),
          taetigkeiten(*)
        '''),
        supabase
            .from('orte')
            .select('id, beschreibung_genau, hausnummer, strassen(name)'),
        supabase.from('taetigkeiten').select('*'),
        supabase.from('fahrzeuge').select('kennzeichen, bezeichnung'),
      ]);

      setState(() {
        _allMassnahmen = results[0];
        _allMassnahmen.sort((a, b) {
          String nameA = a['orte']?['strassen']?['name'] ?? '';
          String nameB = b['orte']?['strassen']?['name'] ?? '';
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
        });

        _filteredMassnahmen = List.from(_allMassnahmen);
        _orte = results[1];
        _taetigkeiten = results[2];
        _fahrzeuge = results[3];
        _isLoading = false;
      });

      _filterList(_searchController.text);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(currentOffset);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterList(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMassnahmen = _allMassnahmen;
      } else {
        _filteredMassnahmen = _allMassnahmen.where((m) {
          final strasse = (m['orte']?['strassen']?['name'] ?? '')
              .toString()
              .toLowerCase();
          final beschr = (m['orte']?['beschreibung_genau'] ?? '')
              .toString()
              .toLowerCase();
          final tat = (m['taetigkeiten']?['beschreibung_kurz'] ?? '')
              .toString()
              .toLowerCase();
          return strasse.contains(query.toLowerCase()) ||
              beschr.contains(query.toLowerCase()) ||
              tat.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _zeigeMassnahmenDialog({Map<String, dynamic>? item}) {
    final bool isEdit = item != null;
    dynamic selectedOrtId = item?['ort_id'];
    dynamic selectedTaetigkeitId = item?['taetigkeit_id'];
    String? selectedKennzeichen = item?['kennzeichen'];
    bool beendet = item?['beendet'] ?? false;

    DateTime selectedDate = item != null
        ? DateTime.parse(item['start_datum'])
        : DateTime.now();

    final startController = TextEditingController(
      text: DateFormat('dd.MM.yyyy').format(selectedDate),
    );
    final auftragnummerController = TextEditingController(
      text: item?['auftragsnummer'] ?? '',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDS) => AlertDialog(
          title: Text(isEdit ? "Massnahme anpassen" : "Neue Serie anlegen"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<dynamic>(
                  initialValue: selectedOrtId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: "Ort / Baum"),
                  items: _orte.map((o) {
                    final hnr = o['hausnummer'];
                    final displayHnr = (hnr == null || hnr == 'null')
                        ? ""
                        : " $hnr";
                    return DropdownMenuItem<dynamic>(
                      value: o['id'],
                      child: Text(
                        "${o['strassen']?['name'] ?? ''}$displayHnr - ${o['beschreibung_genau'] ?? ''}",
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setDS(() => selectedOrtId = val),
                ),
                DropdownButtonFormField<dynamic>(
                  initialValue: selectedTaetigkeitId,
                  decoration: const InputDecoration(labelText: "Tätigkeit"),
                  items: _taetigkeiten
                      .map(
                        (t) => DropdownMenuItem<dynamic>(
                          value: t['id'],
                          child: Text("${t['beschreibung_kurz']}"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setDS(() => selectedTaetigkeitId = val),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedKennzeichen,
                  decoration: const InputDecoration(
                    labelText: "Standard-Fahrzeug",
                  ),
                  items: _fahrzeuge
                      .map(
                        (f) => DropdownMenuItem<String>(
                          value: f['kennzeichen'],
                          child: Text("${f['kennzeichen']}"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setDS(() => selectedKennzeichen = val),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: startController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Bezugs- / Startdatum",
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    DateTime? p = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2035),
                    );
                    if (p != null) {
                      setDS(() {
                        selectedDate = p;
                        startController.text = DateFormat(
                          'dd.MM.yyyy',
                        ).format(p);
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: auftragnummerController,
                  decoration: const InputDecoration(
                    labelText: "Auftragsnummer",
                    suffixIcon: Icon(Icons.assignment),
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text("Maßnahme beendet"),
                  subtitle: const Text(
                    "Deaktiviert die Planung und blendet die Tour für Fahrer aus.",
                  ),
                  value: beendet,
                  activeColor: Colors.red,
                  onChanged: (val) => setDS(() => beendet = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Abbruch"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEdit ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (selectedOrtId == null || selectedTaetigkeitId == null) {
                  return;
                }

                try {
                  final massnahmeData = {
                    'ort_id': selectedOrtId,
                    'taetigkeit_id': selectedTaetigkeitId,
                    'kennzeichen': selectedKennzeichen,
                    'beendet': beendet,
                    'start_datum': DateFormat(
                      'yyyy-MM-dd',
                    ).format(selectedDate),
                    'auftragsnummer':
                        auftragnummerController.text.trim().isEmpty
                        ? null
                        : auftragnummerController.text.trim(),
                  };

                  // Intervall aus gewählter Tätigkeit holen
                  final tatInfo = _taetigkeiten.firstWhere(
                    (t) => t['id'] == selectedTaetigkeitId,
                  );
                  final int intervall = tatInfo['intervall_tage'] ?? 7;

                  String mId;
                  if (isEdit) {
                    mId = item['id'].toString();
                    await supabase
                        .from('massnahmen')
                        .update(massnahmeData)
                        .eq('id', mId);
                  } else {
                    final res = await supabase
                        .from('massnahmen')
                        .insert(massnahmeData)
                        .select()
                        .single();
                    mId = res['id'].toString();
                  }

                  if (beendet) {
                    // Wenn beendet, löschen wir nur noch alle offenen Termine
                    await supabase
                        .from('ausfuehrung')
                        .delete()
                        .eq('massnahme_id', mId)
                        .eq('erledigt', false);
                  } else {
                    // Wenn aktiv (oder wiedererweckt), planen wir die Saison neu
                    await GiesAppLogik.planeSaison(
                      massnahmeId: mId,
                      startDatum: selectedDate,
                      intervall: intervall,
                      kennzeichen: selectedKennzeichen,
                      loescheOffene: true,
                    );
                  }

                  if (mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    await _loadAllData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Fehler: $e")));
                  }
                }
              },
              child: Text(
                isEdit ? "Update & Neu Planen" : "Speichern & Planen",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loescheMassnahme(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Serie löschen?"),
        content: const Text(
          "Dies löscht die Maßnahme und alle noch offenen Termine.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Nein"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ja", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await supabase
          .from('ausfuehrung')
          .delete()
          .eq('massnahme_id', id)
          .eq('erledigt', false);
      await supabase.from('massnahmen').delete().eq('id', id);
      _loadAllData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Maßnahmen",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _zeigeMassnahmenDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text("Neu"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: _filterList,
                  decoration: InputDecoration(
                    hintText: "Suchen...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _filteredMassnahmen.length,
                    controller: _scrollController,
                    itemBuilder: (ctx, i) {
                      final m = _filteredMassnahmen[i];
                      final ort = m['orte'];
                      final bool beendet = m['beendet'] ?? false;

                      final bool istEingeplant = m['end_datum'] != null;
                      final bool hatRealesEnde = m['reales_end_datum'] != null;

                      final displayHnr =
                          (ort?['hausnummer'] == null ||
                              ort?['hausnummer'] == 'null')
                          ? ""
                          : " ${ort?['hausnummer']}";
                      final displayFullOrt =
                          "${ort?['strassen']?['name'] ?? ''}$displayHnr - ${ort?['beschreibung_genau'] ?? ''}";

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        color: beendet ? Colors.grey.shade100 : null,
                        child: ListTile(
                          leading: Icon(
                            beendet ? Icons.block : Icons.park,
                            color: beendet
                                ? Colors.grey
                                : (istEingeplant ? Colors.green : Colors.grey),
                            size: 35,
                          ),
                          title: Text(
                            displayFullOrt,
                            style: TextStyle(
                              color: beendet ? Colors.grey : Colors.black,
                              decoration: beendet
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${m['taetigkeiten']?['beschreibung_kurz']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if ((m['auftragsnummer'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                                Text(
                                  "Auftrag: ${m['auftragsnummer']}",
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              Text(
                                beendet
                                    ? "STATUS: BEENDET"
                                    : (hatRealesEnde
                                        ? "Abschluss: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(m['reales_end_datum']))}"
                                        : "kein Ende festgelegt"),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: beendet ? Colors.red : Colors.black54,
                                  fontWeight: beendet ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () =>
                                    _zeigeMassnahmenDialog(item: m),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _loescheMassnahme(m['id']),
                              ),
                            ],
                          ),
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
