import 'package:qcf_quran_plus/qcf_quran_plus.dart';

import '../models/daily_log.dart';
import 'database_service.dart';

class DailyLogService {
  DailyLogService._();

  static final DailyLogService instance = DailyLogService._();

  static const int khatamSurahId = 114;
  static const int khatamAyahId = 6;

  String get today {
    final DateTime now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${now.year.toString().padLeft(4, '0')}-${twoDigits(now.month)}-${twoDigits(now.day)}';
  }

  Future<DailyLog?> getLogForDate(String date) async {
    return DatabaseService.instance.getDailyLog(date);
  }

  Future<DailyLog?> getTodaysLog() async {
    return DatabaseService.instance.getDailyLog(today);
  }

  Future<void> upsertDailyLog({
    required String date,
    required int surahId,
    required int ayahId,
  }) async {
    await DatabaseService.instance.upsertDailyLog(
      date: date,
      surahId: surahId,
      ayahId: ayahId,
    );
  }

  Future<void> markReadingAsFinished({
    required int surahId,
    required int ayahId,
    String? date,
  }) async {
    await upsertDailyLog(date: date ?? today, surahId: surahId, ayahId: ayahId);
  }

  Future<List<DailyLog>> getLogHistory() async {
    return DatabaseService.instance.getDailyLogs();
  }

  Future<int> getTotalKhatams() async {
    final List<DailyLog> completions = await getKhatamCompletions();
    return completions.length;
  }

  Future<List<DailyLog>> getKhatamCompletions() async {
    final List<DailyLog> allLogs = await getLogHistory();
    final List<DailyLog> completions = <DailyLog>[];
    for (final DailyLog log in allLogs) {
      if (log.isKhatam) {
        completions.add(log);
      }
    }
    return completions;
  }

  DailyLog? resolveNextReadingStart(DailyLog? yesterdayLog) {
    if (yesterdayLog == null) {
      return null;
    }
    if (yesterdayLog.isKhatam) {
      return DailyLog(date: today, surahId: 1, ayahId: 1);
    }
    final int surahId = yesterdayLog.surahId;
    final int nextAyah = yesterdayLog.ayahId + 1;
    final int maxAyah = _maxAyahOfSurah(surahId);
    if (nextAyah > maxAyah) {
      final int nextSurahId = surahId + 1;
      if (nextSurahId > 114) {
        return DailyLog(date: today, surahId: 1, ayahId: 1);
      }
      return DailyLog(date: today, surahId: nextSurahId, ayahId: 1);
    }
    return DailyLog(date: today, surahId: surahId, ayahId: nextAyah);
  }

  int _maxAyahOfSurah(int surahId) {
    try {
      final int count = getVerseCount(surahId);
      if (count > 0) {
        return count;
      }
    } catch (_) {
      // fallback statistik sederhana
    }
    if (surahId == 1) return 7;
    if (surahId == 2 || surahId == 3) return 286;
    if (surahId == 113 || surahId == 114) return 6;
    return 8;
  }
}
