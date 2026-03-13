import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Diese beiden Imports lösen die Fehler um "Position" und "LocationPermission"
import 'package:geolocator/geolocator.dart'; 

class AddOrtScreen extends StatefulWidget {
  const AddOrtScreen({super.key});

  @override
  State<AddOrtScreen> createState() => _AddOrtScreenState();
}

class _AddOrtScreenState extends State<AddOrtScreen> {
  final _strasseController = TextEditingController();
  final _beschreibungController = TextEditingController();
  
  double? _lat;
  double? _lng;
  bool _isLocating = false;

  // Diese Funktion nutzt die Klassen aus dem geolocator-Paket
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      // LocationPermission ist ein Typ aus dem geolocator Paket
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Standortberechtigung wurde dauerhaft abgelehnt.");
        return;
      }

      // Position ist ebenfalls ein Typ aus dem Paket
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
    } catch (e) {
      _showSnackBar("Fehler: $e");
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _speichern() async {
    if (_lat == null || _strasseController.text.isEmpty) {
      _showSnackBar("Bitte Straße angeben und Standort erfassen!");
      return;
    }

    final supabase = Supabase.instance.client;
    try {
      // WICHTIG: Kein qr_code_id mehr hier, da es jetzt in 'taetigkeiten' liegt!
      await supabase.from('orte').insert({
        'strasse': _strasseController.text.trim(),
        'beschreibung_genau': _beschreibungController.text.trim(),
        'geom': 'POINT($_lng $_lat)', // PostGIS Format
      });

      if (mounted) {
        _showSnackBar("Ort erfolgreich gespeichert!");
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar("Datenbankfehler: $e");
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Neuen Ort erfassen')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _strasseController, decoration: const InputDecoration(labelText: 'Straße')),
            TextField(controller: _beschreibungController, decoration: const InputDecoration(labelText: 'Zusatzinfo')),
            const SizedBox(height: 20),
            if (_lat != null) Text("📍 Erfasst: $_lat, $_lng"),
            ElevatedButton.icon(
              onPressed: _isLocating ? null : _getCurrentLocation,
              icon: const Icon(Icons.location_on),
              label: Text(_isLocating ? "Suche GPS..." : "Standort erfassen"),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _speichern,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('SPEICHERN'),
            ),
          ],
        ),
      ),
    );
  }
}