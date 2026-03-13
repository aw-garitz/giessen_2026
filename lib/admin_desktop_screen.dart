import 'package:flutter/material.dart';
import 'package:giessen_app/views/ausfuehrungen_view.dart';
import 'package:giessen_app/views/fahrzeuge_view.dart';
import 'package:giessen_app/views/massnahmen_view.dart';
import 'package:giessen_app/views/orte_view.dart';
import 'package:giessen_app/views/strassen_view.dart';
import 'package:giessen_app/views/taetigkeiten_view.dart';
import 'package:giessen_app/views/mitarbeiter_view.dart'; // NEU
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDesktopScreen extends StatefulWidget {
  const AdminDesktopScreen({super.key});

  @override
  State<AdminDesktopScreen> createState() => _AdminDesktopScreenState();
}

class _AdminDesktopScreenState extends State<AdminDesktopScreen> {
  int _selectedIndex = 0;

  // Inhalts-Umschalter
  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const OrteView();
      case 1:
        return const StrassenView();
      case 2:
        return const FahrzeugeView();
      case 3:
        return const TaetigkeitenView();
      case 4:
        return const MitarbeiterView(); // NEU an Position 4
      case 5:
        return const MassnahmenView();
      case 6:
        return const AusfuehrungenView();
      default:
        return const OrteView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // --- SIDEBAR (NavigationRail) ---
          NavigationRail(
            extended: true,
            minExtendedWidth: 240,
            backgroundColor: Colors.white,
            groupAlignment: -1.0,
            unselectedIconTheme: const IconThemeData(color: Colors.blueGrey, opacity: 0.7),
            selectedIconTheme: const IconThemeData(color: Color(0xFF2E7D32), size: 24),
            unselectedLabelTextStyle: const TextStyle(color: Colors.blueGrey, fontSize: 14),
            selectedLabelTextStyle: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            // HEADER
            leading: Padding(
              padding: const EdgeInsets.only(top: 30, bottom: 40, left: 16),
              child: Row(
                children: [
                  const Icon(Icons.location_city, size: 32, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 12),
                  const Text(
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
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: Text('Standorte / Karte'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.edit_road_outlined),
                selectedIcon: Icon(Icons.edit_road),
                label: Text('Straßenverzeichnis'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: Text('Fuhrpark'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: Text('Tätigkeiten'),
              ),
              // NEUER PUNKT: Mitarbeiter
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Mitarbeiter'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: Text('Maßnahmen-Planung'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: Text('Protokoll / Ausführung'),
              ),
            ],
            // FOOTER: Abmelden (Sicherer positioniert ohne Expanded-Fehler)
            trailing: Padding(
              padding: const EdgeInsets.only(left: 8, top: 40),
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
          ),
          
          const VerticalDivider(thickness: 1, width: 1),

          // --- HAUPTBEREICH ---
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