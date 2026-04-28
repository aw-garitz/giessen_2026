import 'package:flutter/material.dart';
import 'package:giessen_app/views/ausfuehrungen_view.dart';
import 'package:giessen_app/views/fahrzeuge_view.dart';
import 'package:giessen_app/views/massnahmen_view.dart';
import 'package:giessen_app/views/orte_view.dart';
import 'package:giessen_app/views/strassen_view.dart';
import 'package:giessen_app/views/taetigkeiten_view.dart';
import 'package:giessen_app/views/mitarbeiter_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:giessen_app/funktionen/fn_allgemein.dart';
import 'package:intl/intl.dart';

class AdminDesktopScreen extends StatefulWidget {
  final String userName;

  const AdminDesktopScreen({super.key, required this.userName});

  @override
  State<AdminDesktopScreen> createState() => _AdminDesktopScreenState();
}

class _AdminDesktopScreenState extends State<AdminDesktopScreen> {
  int _selectedIndex = 0;
  bool _stammdatenExpanded = false;

  Future<void> _exportToExcel(int kw) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await GiesAppLogik.ladeAusfuehrungenProKW(kw);

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Status KW $kw'];

      sheetObject.appendRow([
        TextCellValue('ID'),
        TextCellValue('Erledigt'),
        TextCellValue('Geplant am'),
        TextCellValue('Kennzeichen'),
        TextCellValue('Auftragsnummer'),
        TextCellValue('Ort Beschreibung'),
        TextCellValue('Hausnummer'),
        TextCellValue('Straße'),
        TextCellValue('Stadtteil'),
        TextCellValue('Tätigkeit'),
        TextCellValue('Intervall (Tage)'),
        TextCellValue('Breitengrad (lat)'),
        TextCellValue('Längengrad (lng)'),
        TextCellValue('Genauigkeit (m)'),
      ]);

      for (var item in data) {
        final massnahme = item['massnahmen'];
        final ort = massnahme?['orte'];
        final strasse = ort?['strassen'];
        final taetigkeit = massnahme?['taetigkeiten'];

        sheetObject.appendRow([
          TextCellValue(item['id']?.toString() ?? ''),
          TextCellValue(item['erledigt']?.toString() ?? ''),
          TextCellValue(
            item['geplant_am'] != null
                ? DateFormat(
                    'dd.MM.yyyy',
                  ).format(DateTime.parse(item['geplant_am']))
                : '',
          ),
          TextCellValue(item['kennzeichen'] ?? ''),
          TextCellValue(massnahme?['auftragsnummer'] ?? ''),
          TextCellValue(ort?['beschreibung_genau'] ?? ''),
          TextCellValue(ort?['hausnummer'] ?? ''),
          TextCellValue(strasse?['name'] ?? ''),
          TextCellValue(strasse?['stadtteil'] ?? ''),
          TextCellValue(taetigkeit?['beschreibung_kurz'] ?? ''),
          TextCellValue(taetigkeit?['intervall_tage']?.toString() ?? ''),
          TextCellValue(item['lat']?.toString() ?? ''),
          TextCellValue(item['lng']?.toString() ?? ''),
          TextCellValue(item['accuracy']?.toString() ?? ''),
        ]);
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Status_KW_$kw.xlsx';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(excel.encode()!);
      await Share.shareXFiles([XFile(file.path)], text: 'Status Export KW $kw');

      messenger.showSnackBar(
        SnackBar(content: Text('Export erfolgreich: $fileName')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Fehler beim Export: $e')));
    }
  }

  Future<void> _showExportDialog() async {
    int selectedKW = GiesAppLogik.getISOWeek(DateTime.now());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excel Export'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Kalenderwoche für den Export:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: selectedKW,
              items: List.generate(52, (index) => index + 1)
                  .map(
                    (kw) => DropdownMenuItem(value: kw, child: Text('KW $kw')),
                  )
                  .toList(),
              onChanged: (value) => selectedKW = value ?? selectedKW,
              decoration: const InputDecoration(labelText: 'Kalenderwoche'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exportToExcel(selectedKW);
            },
            child: const Text('Exportieren'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const OrteView();
      case 1:
        return const StrassenView();
      case 2:
        return const FahrzeugeView();
      case 3:
        return const MitarbeiterView();
      case 4:
        return const TaetigkeitenView();
      case 5:
        return const MassnahmenView();
      case 6:
        return const AusfuehrungenView();
      default:
        return const OrteView();
    }
  }

  static const Color _activeColor = Color(0xFF2E7D32);
  static const Color _inactiveColor = Colors.blueGrey;

  Widget _navItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    double leftPadding = 16,
  }) {
    final bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: EdgeInsets.only(
          left: leftPadding,
          right: 12,
          top: 10,
          bottom: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? _activeColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected
                  ? _activeColor
                  : _inactiveColor.withValues(alpha: 0.7),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? _activeColor : _inactiveColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final bool stammdatenActive = [1, 2, 3].contains(_selectedIndex);

    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.only(top: 30, bottom: 16, left: 24),
            child: Row(
              children: const [
                Icon(Icons.location_city, size: 32, color: _activeColor),
                SizedBox(width: 12),
                Text(
                  "SB Gießliste",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.8,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Begrüßung – Expanded verhindert Overflow bei langen Namen
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 24),
            child: Row(
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 18,
                  color: _inactiveColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Hallo, ${widget.userName}",
                    style: const TextStyle(fontSize: 13, color: _inactiveColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          _navItem(
            index: 0,
            icon: Icons.map_outlined,
            selectedIcon: Icons.map,
            label: 'Standorte / Karte',
          ),

          // STAMMDATEN - ausklappbar
          InkWell(
            onTap: () =>
                setState(() => _stammdatenExpanded = !_stammdatenExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.only(
                left: 16,
                right: 12,
                top: 10,
                bottom: 10,
              ),
              decoration: BoxDecoration(
                color: stammdatenActive
                    ? _activeColor.withValues(alpha: 0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    color: stammdatenActive
                        ? _activeColor
                        : _inactiveColor.withValues(alpha: 0.7),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Stammdaten',
                      style: TextStyle(
                        color: stammdatenActive ? _activeColor : _inactiveColor,
                        fontWeight: stammdatenActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _stammdatenExpanded ? Icons.expand_less : Icons.expand_more,
                    color: _inactiveColor.withValues(alpha: 0.7),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                _navItem(
                  index: 1,
                  icon: Icons.edit_road_outlined,
                  selectedIcon: Icons.edit_road,
                  label: 'Straßenverzeichnis',
                  leftPadding: 32,
                ),
                _navItem(
                  index: 2,
                  icon: Icons.local_shipping_outlined,
                  selectedIcon: Icons.local_shipping,
                  label: 'Fuhrpark',
                  leftPadding: 32,
                ),
                _navItem(
                  index: 3,
                  icon: Icons.people_outline,
                  selectedIcon: Icons.people,
                  label: 'Mitarbeiter',
                  leftPadding: 32,
                ),
              ],
            ),
            crossFadeState: _stammdatenExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),

          _navItem(
            index: 4,
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment,
            label: 'Tätigkeiten',
          ),
          _navItem(
            index: 5,
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
            label: 'Maßnahmen-Planung',
          ),
          _navItem(
            index: 6,
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check,
            label: 'Protokoll / Ausführung',
          ),

          const Spacer(),

          // FOOTER: Export und Abmelden – vertikal gestapelt damit kein Overflow
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: _showExportDialog,
                  icon: const Icon(Icons.download, color: Colors.blue),
                  label: const Text(
                    "Excel Export",
                    style: TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async =>
                      await Supabase.instance.client.auth.signOut(),
                  icon: const Icon(
                    Icons.logout,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  label: const Text(
                    "Abmelden",
                    style: TextStyle(color: Colors.redAccent, fontSize: 14),
                  ),
                ),
              ],
            ),
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
          _buildSidebar(),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey<int>(_selectedIndex),
                color: Colors.grey[50],
                child: _buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
