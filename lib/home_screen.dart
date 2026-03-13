import 'package:flutter/material.dart';
import 'package:giessen_app/map_screen.dart';
import 'add_ort_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Hier definieren wir die Seiten, zwischen denen gewechselt wird
  static const List<Widget> _pages = [
    MapScreen(), // Deine Karte (muss in map_scren.dart so heißen)
    Center(child: Text("Liste der Aufgaben (folgt)")), 
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Karte'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Aufgaben'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800],
        onTap: _onItemTapped,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddOrtScreen()),
          );
        },
        child: const Icon(Icons.add_location_alt),
        backgroundColor: Colors.green,
      ),
    );
  }
}