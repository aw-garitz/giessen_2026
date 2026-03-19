import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:giessen_app/funktionen/fn_allgemein.dart';

/// Ein einzelner offline gespeicherter Vorgang
class OfflineVorgang {
  final String id;
  final String massnahmeId;
  final String? kfz;
  final DateTime zeitpunkt;
  final String typ; // 'erledigt' oder 'reset'
  final Map<String, dynamic> ausfuehrungData;

  OfflineVorgang({
    required this.id,
    required this.massnahmeId,
    required this.zeitpunkt,
    required this.typ,
    required this.ausfuehrungData,
    this.kfz,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'massnahme_id': massnahmeId,
    'kfz': kfz,
    'zeitpunkt': zeitpunkt.toIso8601String(),
    'typ': typ,
    'ausfuehrung_data': ausfuehrungData,
  };

  factory OfflineVorgang.fromJson(Map<String, dynamic> json) => OfflineVorgang(
    id: json['id'],
    massnahmeId: json['massnahme_id'],
    kfz: json['kfz'],
    zeitpunkt: DateTime.parse(json['zeitpunkt']),
    typ: json['typ'],
    ausfuehrungData: Map<String, dynamic>.from(json['ausfuehrung_data']),
  );
}

class OfflineSyncService {
  static const String _queueKey = 'offline_queue';

  /// Prüft ob WLAN verfügbar ist (nur WLAN zählt als online)
  static Future<bool> istOnline() async {
    try {
      // Erst WLAN-Check
      final connectivityResult = await Connectivity().checkConnectivity();
      final hatWlan = connectivityResult == ConnectivityResult.wifi;
      if (!hatWlan) return false;

      // WLAN aktiv → zusätzlich prüfen ob Internet wirklich erreichbar
      final lookup = await InternetAddress.lookup('supabase.co');
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Stream für automatischen Sync bei WLAN-Verbindung
  static Stream<bool> get wlanStream => Connectivity()
      .onConnectivityChanged
      .map((result) => result == ConnectivityResult.wifi);

  /// Vorgang zur lokalen Warteschlange hinzufügen
  static Future<void> speichereLokal({
    required dynamic ausfuehrung,
    required String typ,
    String? kfz,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = _ladeQueue(prefs);

      final vorgang = OfflineVorgang(
        id: ausfuehrung['id'].toString(),
        massnahmeId: ausfuehrung['massnahme_id'].toString(),
        kfz: kfz,
        zeitpunkt: DateTime.now(),
        typ: typ,
        ausfuehrungData: Map<String, dynamic>.from(ausfuehrung),
      );

      // Duplikat vermeiden
      queue.removeWhere((v) => v.id == vorgang.id);
      queue.add(vorgang);

      await _speichereQueue(prefs, queue);
      debugPrint("💾 Offline gespeichert: ${vorgang.typ} für ${vorgang.id}");
    } catch (e) {
      debugPrint("❌ Fehler beim lokalen Speichern: $e");
    }
  }

  /// Anzahl der ausstehenden Vorgänge
  static Future<int> anzahlAusstehend() async {
    final prefs = await SharedPreferences.getInstance();
    return _ladeQueue(prefs).length;
  }

  /// Sync: alle lokalen Vorgänge zu Supabase hochladen
  static Future<SyncErgebnis> syncZuSupabase() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _ladeQueue(prefs);

    if (queue.isEmpty) return SyncErgebnis(erfolgreich: 0, fehlgeschlagen: 0);

    int erfolgreich = 0;
    int fehlgeschlagen = 0;
    final List<OfflineVorgang> nochAusstehend = [];

    for (final vorgang in queue) {
      try {
        if (vorgang.typ == 'erledigt') {
          await GiesAppLogik.erledigenUndPlanen(
            vorgang.ausfuehrungData,
            kfz: vorgang.kfz,
          );
        } else if (vorgang.typ == 'reset') {
          await GiesAppLogik.resetToLastStatus(vorgang.ausfuehrungData);
        }
        erfolgreich++;
        debugPrint("✅ Sync erfolgreich: ${vorgang.id}");
      } catch (e) {
        debugPrint("❌ Sync fehlgeschlagen für ${vorgang.id}: $e");
        fehlgeschlagen++;
        nochAusstehend.add(vorgang);
      }
    }

    await _speichereQueue(prefs, nochAusstehend);
    return SyncErgebnis(erfolgreich: erfolgreich, fehlgeschlagen: fehlgeschlagen);
  }

  /// Warteschlange leeren
  static Future<void> leereQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }

  // --- Private Hilfsmethoden ---

  static List<OfflineVorgang> _ladeQueue(SharedPreferences prefs) {
    final raw = prefs.getString(_queueKey);
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => OfflineVorgang.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _speichereQueue(SharedPreferences prefs, List<OfflineVorgang> queue) async {
    final encoded = jsonEncode(queue.map((v) => v.toJson()).toList());
    await prefs.setString(_queueKey, encoded);
  }
}

/// Ergebnis eines Sync-Vorgangs
class SyncErgebnis {
  final int erfolgreich;
  final int fehlgeschlagen;
  const SyncErgebnis({required this.erfolgreich, required this.fehlgeschlagen});
  bool get hatFehler => fehlgeschlagen > 0;
  bool get alleErfolgreich => fehlgeschlagen == 0 && erfolgreich > 0;
}