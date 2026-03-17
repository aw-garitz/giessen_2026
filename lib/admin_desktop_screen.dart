import 'package:flutter/material.dart';
import 'package:giessen_app/views/ausfuehrungen_view.dart';
import 'package:giessen_app/views/fahrzeuge_view.dart';
import 'package:giessen_app/views/massnahmen_view.dart';
import 'package:giessen_app/views/orte_view.dart';
import 'package:giessen_app/views/strassen_view.dart';
import 'package:giessen_app/views/taetigkeiten_view.dart';
import 'package:giessen_app/views/mitarbeiter_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDesktopScreen extends StatefulWidget {
  const AdminDesktopScreen({super.key});

  @override
  State<AdminDesktopScreen> createState() => _AdminDesktopScreenState();
}

class _AdminDesktopScreenState extends State<AdminDesktopScreen> {
  int _selectedIndex = 0;
  bool _stammdatenExpanded = false;

  // Index-Mapping:
  // 0 = Standorte/Karte
  // 1 = Straßenverzeichnis  (Stammdaten)
  // 2 = Fuhrpark            (Stammdaten)
  // 3 = Mitarbeiter         (Stammdaten)
  // 4 = Tätigkeiten
  // 5 = Maßnahmen-Planung
  // 6 = Protokoll/Ausführung

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: return const OrteView();
      case 1: return const StrassenView();
      case 2: return const FahrzeugeView();
      case 3: return const MitarbeiterView();
      case 4: return const TaetigkeitenView();
      case 5: return const MassnahmenView();
      case 6: return const AusfuehrungenView();
      default: return const OrteView();
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
        padding: EdgeInsets.only(left: leftPadding, right: 12, top: 10, bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? _activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? _activeColor : _inactiveColor.withOpacity(0.7),
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _activeColor : _inactiveColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
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
            padding: const EdgeInsets.only(top: 30, bottom: 40, left: 24),
            child: Row(
              children: const [
                Icon(Icons.location_city, size: 32, color: _activeColor),
                SizedBox(width: 12),
                Text(
                  "BK LOGISTIK",
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

          // Standorte / Karte
          _navItem(
            index: 0,
            icon: Icons.map_outlined,
            selectedIcon: Icons.map,
            label: 'Standorte / Karte',
          ),

          // STAMMDATEN - ausklappbar
          InkWell(
            onTap: () => setState(() => _stammdatenExpanded = !_stammdatenExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.only(left: 16, right: 12, top: 10, bottom: 10),
              decoration: BoxDecoration(
                color: stammdatenActive ? _activeColor.withOpacity(0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    color: stammdatenActive ? _activeColor : _inactiveColor.withOpacity(0.7),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Stammdaten',
                      style: TextStyle(
                        color: stammdatenActive ? _activeColor : _inactiveColor,
                        fontWeight: stammdatenActive ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    _stammdatenExpanded ? Icons.expand_less : Icons.expand_more,
                    color: _inactiveColor.withOpacity(0.7),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Stammdaten Untermenü
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

          // Tätigkeiten
          _navItem(
            index: 4,
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment,
            label: 'Tätigkeiten',
          ),

          // Maßnahmen-Planung
          _navItem(
            index: 5,
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
            label: 'Maßnahmen-Planung',
          ),

          // Protokoll / Ausführung
          _navItem(
            index: 6,
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check,
            label: 'Protokoll / Ausführung',
          ),

          const Spacer(),

          // FOOTER: Abmelden
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 24),
            child: TextButton.icon(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
              },
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
              label: const Text(
                "Abmelden",
                style: TextStyle(color: Colors.redAccent, fontSize: 14),
              ),
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