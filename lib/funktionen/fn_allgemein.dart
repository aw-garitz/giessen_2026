import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GiesAppLogik {
  static final supabase = Supabase.instance.client;

  /// Hilfsfunktion: Berechnet den Start einer KW
  static DateTime _getStartOfKW(int kw) {
    return DateTime(2026, 1, 1).add(Duration(days: (kw - 1) * 7 - 3));
  }

  /// Lädt alle Ausführungen einer KW – wird von Web UND Mobile verwendet
  /// orte kommt über massnahmen (nicht mehr direkt über ausfuehrung)
  static Future<List<dynamic>> ladeAusfuehrungenProKW(int kw) async {
    try {
      final start = _getStartOfKW(kw);
      final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));

      debugPrint("🔍 Suche Zeitraum: ${start.toIso8601String()} bis ${end.toIso8601String()}");

      final res = await supabase.from('ausfuehrung').select('''
        id, erledigt, geplant_am, kennzeichen, massnahme_id,
        massnahmen (
          id,
          auftragsnummer,
          orte (
            id, beschreibung_genau, hausnummer, latitude, longitude,
            strassen:strasse_id (name, stadtteil)
          ),
          taetigkeiten:taetigkeit_id (beschreibung_kurz, intervall_tage)
        )
      ''')
      .gte('geplant_am', start.toIso8601String())
      .lte('geplant_am', end.toIso8601String())
      .order('geplant_am');

      final liste = res as List<dynamic>;
      debugPrint("🚀 Erfolg: ${liste.length} Einträge gefunden.");
      return liste;
    } catch (e) {
      debugPrint("❌ DB-Fehler bei ladeAusfuehrungen: $e");
      return [];
    }
  }

  /// Planung einer kompletten Saison ab einem Startdatum
  static Future<void> planeSaison({
    required String massnahmeId,
    required DateTime startDatum,
    required int intervall,
    required String? kennzeichen,
    bool loescheOffene = true,
  }) async {
    try {
      final int jahr = startDatum.year;
      final DateTime saisonEnde = DateTime(jahr, 11, 30, 23, 59);

      if (loescheOffene) {
        await supabase
            .from('ausfuehrung')
            .delete()
            .eq('massnahme_id', massnahmeId)
            .eq('erledigt', false);
      }

      // Bereits vorhandene Termine laden um Duplikate zu vermeiden
      final bereitsVorhanden = await supabase
          .from('ausfuehrung')
          .select('geplant_am')
          .eq('massnahme_id', massnahmeId);

      final Set<String> vorhandeneDaten = (bereitsVorhanden as List)
          .map((e) => e['geplant_am'].toString().substring(0, 10))
          .toSet();

      List<Map<String, dynamic>> neueTermine = [];
      DateTime naechsterTermin = startDatum;

      while (naechsterTermin.isBefore(saisonEnde) || naechsterTermin.isAtSameMomentAs(saisonEnde)) {
        final datumStr = DateFormat('yyyy-MM-dd').format(naechsterTermin);
        if (!vorhandeneDaten.contains(datumStr)) {
          neueTermine.add({
            'massnahme_id': massnahmeId,
            'geplant_am': datumStr,
            'erledigt': false,
            'kennzeichen': kennzeichen,
          });
        }
        naechsterTermin = naechsterTermin.add(Duration(days: intervall));
      }

      if (neueTermine.isNotEmpty) {
        await supabase.from('ausfuehrung').insert(neueTermine);
      }

      debugPrint("📅 ${neueTermine.length} Termine bis 30.11.$jahr geplant (Intervall: $intervall Tage).");
    } catch (e) {
      debugPrint("❌ Fehler in planeSaison: $e");
      throw "Fehler beim Planen der Saison: $e";
    }
  }

  /// Fahrzeuge laden
  static Future<List<String>> ladeAlleKFZ() async {
    try {
      final res = await supabase.from('fahrzeuge').select('kennzeichen').order('kennzeichen');
      return (res as List).map((e) => e['kennzeichen'].toString()).toList();
    } catch (e) { return []; }
  }

  /// Erledigen und Saison neu planen
  static Future<void> erledigenUndPlanen(dynamic ausfuehrung, {String? kfz, String? quelle}) async {
    try {
      final nun = DateTime.now();
      final massnahmeId = ausfuehrung['massnahme_id'];
      final int jahr = nun.year;
      final DateTime saisonEnde = DateTime(jahr, 11, 30, 23, 59);

      String? bereinigtesKfz = (kfz == null || kfz == "Alle" || kfz.trim().isEmpty)
                               ? null
                               : kfz;

      // 1. Aktuellen Termin als erledigt markieren
      await supabase.from('ausfuehrung').update({
        'erledigt': true,
        'ausgefuehrt_am': nun.toIso8601String(),
        'kennzeichen': bereinigtesKfz,
      }).eq('id', ausfuehrung['id']);

      // 2. Alle zukünftigen offenen Termine löschen
      await supabase
          .from('ausfuehrung')
          .delete()
          .eq('massnahme_id', massnahmeId)
          .eq('erledigt', false)
          .gt('geplant_am', nun.toIso8601String())
          .lte('geplant_am', DateTime(jahr, 12, 31).toIso8601String());

      // 3. Bereits vorhandene Termine laden um Duplikate zu vermeiden
      final bereitsVorhanden = await supabase
          .from('ausfuehrung')
          .select('geplant_am')
          .eq('massnahme_id', massnahmeId);

      final Set<String> vorhandeneDaten = (bereitsVorhanden as List)
          .map((e) => e['geplant_am'].toString().substring(0, 10))
          .toSet();

      // 4. Saison neu berechnen
      final int intervall = ausfuehrung['massnahmen']?['taetigkeiten']?['intervall_tage'] ?? 7;
      List<Map<String, dynamic>> neueTermine = [];
      DateTime naechsterCheck = nun.add(Duration(days: intervall));

      while (naechsterCheck.isBefore(saisonEnde) || naechsterCheck.isAtSameMomentAs(saisonEnde)) {
        final datumStr = DateFormat('yyyy-MM-dd').format(naechsterCheck);
        if (!vorhandeneDaten.contains(datumStr)) {
          neueTermine.add({
            'massnahme_id': massnahmeId,
            'geplant_am': datumStr,
            'erledigt': false,
            'kennzeichen': bereinigtesKfz,
          });
        }
        naechsterCheck = naechsterCheck.add(Duration(days: intervall));
      }

      // 5. Neue Termine einfügen
      if (neueTermine.isNotEmpty) {
        await supabase.from('ausfuehrung').insert(neueTermine);
      }

      debugPrint("🧹 Saison für Maßnahme $massnahmeId bereinigt.");
      debugPrint("🚀 ${neueTermine.length} neue Termine bis 30.11. (Intervall: $intervall Tage) erstellt.");

    } catch (e) {
      debugPrint("❌ Kritischer Fehler in erledigenUndPlanen: $e");
      throw "Fehler beim Re-Kalibrieren der Saison: $e";
    }
  }

  /// Einzelnen Termin auf offen setzen
  static Future<void> setzeAufOffen(dynamic ausfuehrung) async {
    await supabase.from('ausfuehrung').update({
      'erledigt': false,
      'ausgefuehrt_am': null,
    }).eq('id', ausfuehrung['id']);
  }

  /// Berechnet die aktuelle Kalenderwoche nach ISO-Standard
  static int getISOWeek(DateTime date) {
    final int dayOfYear = int.parse(DateFormat("D").format(date));
    final int woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (woy < 1) return 52;
    if (woy > 52) return 1;
    return woy;
  }

  /// Reset: Letzten Status wiederherstellen und Saison neu aufbauen
  static Future<void> resetToLastStatus(dynamic ausfuehrung) async {
    try {
      final massnahmeId = ausfuehrung['massnahme_id'];
      final int jahr = DateTime.now().year;
      final DateTime saisonEnde = DateTime(jahr, 11, 30, 23, 59);

      // 1. Falsche Zukunft löschen
      await supabase
          .from('ausfuehrung')
          .delete()
          .eq('massnahme_id', massnahmeId)
          .eq('erledigt', false)
          .gt('geplant_am', DateTime.now().toIso8601String());

      // 2. Aktuellen Termin wieder auf offen setzen
      await supabase.from('ausfuehrung').update({
        'erledigt': false,
        'ausgefuehrt_am': null,
      }).eq('id', ausfuehrung['id']);

      // 3. Letzten erledigten Termin suchen
      final letzteErledigtRes = await supabase
          .from('ausfuehrung')
          .select('ausgefuehrt_am')
          .eq('massnahme_id', massnahmeId)
          .eq('erledigt', true)
          .lt('ausgefuehrt_am', DateTime.now().toIso8601String())
          .order('ausgefuehrt_am', ascending: false)
          .limit(1)
          .maybeSingle();

      // 4. Startpunkt bestimmen
      DateTime basisDatum;
      if (letzteErledigtRes != null && letzteErledigtRes['ausgefuehrt_am'] != null) {
        basisDatum = DateTime.parse(letzteErledigtRes['ausgefuehrt_am']);
      } else {
        basisDatum = DateTime.parse(ausfuehrung['geplant_am']);
      }

      // 5. Bereits vorhandene Termine laden um Duplikate zu vermeiden
      final bereitsVorhanden = await supabase
          .from('ausfuehrung')
          .select('geplant_am')
          .eq('massnahme_id', massnahmeId);

      final Set<String> vorhandeneDaten = (bereitsVorhanden as List)
          .map((e) => e['geplant_am'].toString().substring(0, 10))
          .toSet();

      // 6. Kette wiederherstellen
      final int intervall = ausfuehrung['massnahmen']?['taetigkeiten']?['intervall_tage'] ?? 7;
      List<Map<String, dynamic>> wiederhergestellteTermine = [];
      DateTime naechsterCheck = basisDatum.add(Duration(days: intervall));

      if (naechsterCheck.isBefore(DateTime.now())) {
        naechsterCheck = naechsterCheck.add(Duration(days: intervall));
      }

      while (naechsterCheck.isBefore(saisonEnde)) {
        final datumStr = DateFormat('yyyy-MM-dd').format(naechsterCheck);
        if (!vorhandeneDaten.contains(datumStr)) {
          wiederhergestellteTermine.add({
            'massnahme_id': massnahmeId,
            'geplant_am': datumStr,
            'erledigt': false,
            'kennzeichen': ausfuehrung['kennzeichen'],
          });
        }
        naechsterCheck = naechsterCheck.add(Duration(days: intervall));
      }

      // 7. In die Datenbank schreiben
      if (wiederhergestellteTermine.isNotEmpty) {
        await supabase.from('ausfuehrung').insert(wiederhergestellteTermine);
      }

      debugPrint("🔄 Rollback erfolgreich: Kette ab $basisDatum wiederhergestellt.");
    } catch (e) {
      debugPrint("❌ Fehler beim Reset: $e");
      throw "Reset fehlgeschlagen: $e";
    }
  }
}