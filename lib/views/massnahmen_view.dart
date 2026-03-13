import 'package:flutter/material.dart';
import 'package:giessen_app/qr_pdf_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

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
        supabase.from('orte').select('id, beschreibung_genau, hausnummer, strassen(name)'),
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
          final strasse = (m['orte']?['strassen']?['name'] ?? '').toString().toLowerCase();
          final beschr = (m['orte']?['beschreibung_genau'] ?? '').toString().toLowerCase();
          final tat = (m['taetigkeiten']?['beschreibung_kurz'] ?? '').toString().toLowerCase();
          return strasse.contains(query.toLowerCase()) || 
                 beschr.contains(query.toLowerCase()) ||
                 tat.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _zeigeDruckDialog({required List<dynamic> daten, required String titel}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 50, color: Colors.blueGrey),
            const SizedBox(height: 15),
            Text("${daten.length} QR-Code(s) für den Druck vorbereiten?"),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              QrPdfService.generateQrLabels(daten);
            },
            icon: const Icon(Icons.print),
            label: const Text("Drucken"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Schließen")),
        ],
      ),
    );
  }

  void _zeigeMassnahmenDialog({Map<String, dynamic>? item}) {
    final bool isEdit = item != null;
    dynamic selectedOrtId = item?['ort_id'];
    dynamic selectedTaetigkeitId = item?['taetigkeit_id'];
    String? selectedKennzeichen = item?['kennzeichen'];
    
    String qrCodeId = item?['qr_code_id'] ?? const Uuid().v4(); 
    DateTime selectedDate = item != null ? DateTime.parse(item['start_datum']) : DateTime.now();

    final startController = TextEditingController(text: DateFormat('dd.MM.yyyy').format(selectedDate));

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
                  value: selectedOrtId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: "Ort / Baum"),
                  items: _orte.map((o) {
                    final hnr = o['hausnummer'];
                    final displayHnr = (hnr == null || hnr == 'null') ? "" : " $hnr";
                    return DropdownMenuItem<dynamic>(
                      value: o['id'],
                      child: Text("${o['strassen']?['name'] ?? ''}$displayHnr - ${o['beschreibung_genau'] ?? ''}"),
                    );
                  }).toList(),
                  onChanged: (val) => setDS(() => selectedOrtId = val),
                ),
                DropdownButtonFormField<dynamic>(
                  value: selectedTaetigkeitId,
                  decoration: const InputDecoration(labelText: "Tätigkeit"),
                  items: _taetigkeiten.map((t) => DropdownMenuItem<dynamic>(
                    value: t['id'],
                    child: Text("${t['beschreibung_kurz']}"),
                  )).toList(),
                  onChanged: (val) => setDS(() => selectedTaetigkeitId = val),
                ),
                DropdownButtonFormField<String>(
                  value: selectedKennzeichen,
                  decoration: const InputDecoration(labelText: "Standard-Fahrzeug"),
                  items: _fahrzeuge.map((f) => DropdownMenuItem<String>(
                    value: f['kennzeichen'],
                    child: Text("${f['kennzeichen']}"),
                  )).toList(),
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
                      lastDate: DateTime(2035)
                    );
                    if (p != null) {
                      setDS(() {
                        selectedDate = p;
                        startController.text = DateFormat('dd.MM.yyyy').format(p);
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Abbruch")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEdit ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (selectedOrtId == null || selectedTaetigkeitId == null) return;

                try {
                  final massnahmeData = {
                    'ort_id': selectedOrtId,
                    'taetigkeit_id': selectedTaetigkeitId,
                    'kennzeichen': selectedKennzeichen,
                    'qr_code_id': qrCodeId,
                    'start_datum': DateFormat('yyyy-MM-dd').format(selectedDate),
                  };

                  String mId;
                  if (isEdit) {
                    mId = item['id'].toString();
                    await supabase.from('ausfuehrung').delete()
                        .eq('massnahme_id', mId).eq('erledigt', false);
                    await supabase.from('massnahmen').update(massnahmeData).eq('id', mId);
                  } else {
                    final res = await supabase.from('massnahmen').insert(massnahmeData).select().single();
                    mId = res['id'].toString();
                  }

                  await Future.delayed(const Duration(milliseconds: 400));
                  final calcRes = await supabase
                      .from('view_massnahmen_planung')
                      .select('end_datum, reales_end_datum')
                      .eq('massnahme_id', mId)
                      .maybeSingle();

                  if (calcRes != null) {
                    await supabase.from('massnahmen').update({
                      'end_datum': calcRes['end_datum'],
                      'reales_end_datum': calcRes['reales_end_datum'],
                    }).eq('id', mId);
                  }

                  await supabase.from('ausfuehrung').upsert({
                    'massnahme_id': mId,
                    'geplant_am': DateFormat('yyyy-MM-dd').format(selectedDate),
                    'erledigt': false,
                    'kennzeichen': selectedKennzeichen,
                  }, onConflict: 'massnahme_id, geplant_am');

                  if (mounted) {
                    Navigator.of(ctx).pop();
                    await _loadAllData();
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler: $e")));
                }
              },
              child: Text(isEdit ? "Update & Planen" : "Speichern"),
            ),
          ],
        ),
      ),
    );
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
                    const Text("Maßnahmen", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.print, color: Colors.blueGrey),
                          onPressed: () => _zeigeDruckDialog(
                            daten: _filteredMassnahmen, 
                            titel: "Alle QR-Codes drucken"
                          ),
                          tooltip: "Alle gefilterten QR-Codes drucken",
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _zeigeMassnahmenDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text("Neu"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    
                    final bool istEingeplant = m['end_datum'] != null;
                    final bool hatRealesEnde = m['reales_end_datum'] != null;

                    // String für die eindeutige Anzeige zusammenbauen
                    final displayHnr = (ort?['hausnummer'] == null || ort?['hausnummer'] == 'null') ? "" : " ${ort?['hausnummer']}";
                    final displayFullOrt = "${ort?['strassen']?['name'] ?? ''}$displayHnr - ${ort?['beschreibung_genau'] ?? ''}";

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          Icons.park, 
                          color: istEingeplant ? Colors.green : Colors.grey,
                          size: 35,
                        ),
                        title: Text(displayFullOrt), // GEÄNDERT: Jetzt mit beschreibung_genau
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${m['taetigkeiten']?['beschreibung_kurz']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              hatRealesEnde 
                                ? "Abschluss der Maßnahme: ${DateFormat('dd.MM.yyyy').format(DateTime.parse(m['reales_end_datum']))}"
                                : "kein Ende festgelegt", 
                              style: const TextStyle(fontSize: 11, color: Colors.black54)
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code), 
                              onPressed: () => _zeigeDruckDialog(
                                daten: [m], 
                                titel: "$displayFullOrt drucken" // GEÄNDERT: Klarheit im Dialog
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _zeigeMassnahmenDialog(item: m)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _loescheMassnahme(m['id'])),
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

  Future<void> _loescheMassnahme(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Serie löschen?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Nein")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Ja", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await supabase.from('ausfuehrung').delete().eq('massnahme_id', id).eq('erledigt', false);
      await supabase.from('massnahmen').delete().eq('id', id);
      _loadAllData();
    }
  }
}