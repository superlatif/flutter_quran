import 'dart:math' as math;

import 'package:qcf_quran_plus/qcf_quran_plus.dart';

import '../models/daily_log.dart';
import '../models/reading_statistics.dart';
import 'daily_log_service.dart';

/// Service untuk menghitung laporan statistik bacaan dari `daily_logs`.
///
/// Database hanya menyimpan titik akhir bacaan per tanggal, bukan titik awal.
/// Karena itu jumlah ayat harian di sini adalah estimasi dari selisih posisi
/// akhir antar hari yang memiliki log.
class ReadingStatisticsService {
  ReadingStatisticsService._();

  static final ReadingStatisticsService instance = ReadingStatisticsService._();

  /// Memuat riwayat log lalu menghitung statistik untuk [range].
  Future<ReadingStatistics> load(StatisticsRange range, {DateTime? now}) async {
    final List<DailyLog> logs = await DailyLogService.instance.getLogHistory();
    return buildStatistics(range: range, logs: logs, now: now);
  }

  /// Menghitung statistik secara murni (tanpa akses database).
  ///
  /// [now] dapat diisi pada pengujian untuk menentukan tanggal acuan.
  ReadingStatistics buildStatistics({
    required StatisticsRange range,
    required List<DailyLog> logs,
    DateTime? now,
  }) {
    final DateTime today = dateOnly(now ?? DateTime.now());
    final Map<String, DailyLog> logsByDate = _logsByDate(logs);
    final Map<String, int> dailyAyahCounts = _dailyAyahCounts(logsByDate);

    final DatePeriod currentPeriod = _currentPeriod(range, today);
    final DatePeriod previousPeriod = _previousPeriod(
      range,
      today,
      currentPeriod,
    );

    final _PeriodTotals current = _aggregate(
      currentPeriod,
      logsByDate,
      dailyAyahCounts,
    );
    final _PeriodTotals previous = _aggregate(
      previousPeriod,
      logsByDate,
      dailyAyahCounts,
    );

    return ReadingStatistics(
      range: range,
      currentPeriod: currentPeriod,
      previousPeriod: previousPeriod,
      currentAyahCount: current.ayahCount,
      previousAyahCount: previous.ayahCount,
      currentActiveDays: current.activeDays,
      previousActiveDays: previous.activeDays,
      currentKhatamCount: current.khatamCount,
      previousKhatamCount: previous.khatamCount,
      currentLastLog: current.lastLog,
      previousLastLog: previous.lastLog,
      currentDays: current.days,
      previousDays: previous.days,
    );
  }

  /// Mengubah daftar log menjadi peta `tanggal -> log`.
  ///
  /// Tanggal dinormalisasi agar tetap cocok dengan format `YYYY-MM-DD`.
  Map<String, DailyLog> _logsByDate(List<DailyLog> logs) {
    final Map<String, DailyLog> result = <String, DailyLog>{};
    for (final DailyLog log in logs) {
      if (log.isEmpty) {
        continue;
      }
      final DateTime? parsed = DateTime.tryParse(log.date);
      if (parsed == null) {
        continue;
      }
      result[formatIsoDate(dateOnly(parsed))] = log;
    }
    return result;
  }

  /// Menghitung estimasi jumlah ayat untuk setiap tanggal yang memiliki log.
  Map<String, int> _dailyAyahCounts(Map<String, DailyLog> logsByDate) {
    final List<String> dates = logsByDate.keys.toList()..sort();
    final Map<String, int> counts = <String, int>{};

    DailyLog? previousLog;
    for (final String date in dates) {
      final DailyLog log = logsByDate[date]!;
      final int? currentOrdinal = _ordinalOf(log);
      if (currentOrdinal == null) {
        previousLog = log;
        continue;
      }

      final int count;
      if (previousLog == null) {
        // Log pertama dianggap dimulai dari Al-Fatihah ayat 1.
        count = currentOrdinal;
      } else if (previousLog.isKhatam) {
        // Setelah khatam, bacaan dimulai lagi dari Al-Fatihah ayat 1.
        count = currentOrdinal;
      } else {
        final int? previousOrdinal = _ordinalOf(previousLog);
        count = previousOrdinal == null
            ? currentOrdinal
            : math.max(0, currentOrdinal - previousOrdinal);
      }

      counts[date] = count;
      previousLog = log;
    }

    return counts;
  }

  _PeriodTotals _aggregate(
    DatePeriod period,
    Map<String, DailyLog> logsByDate,
    Map<String, int> dailyAyahCounts,
  ) {
    int ayahCount = 0;
    int activeDays = 0;
    int khatamCount = 0;
    DailyLog? lastLog;
    final List<DailyReading> days = <DailyReading>[];

    for (
      DateTime date = period.start;
      !date.isAfter(period.end);
      date = addDays(date, 1)
    ) {
      final String key = formatIsoDate(date);
      final DailyLog? log = logsByDate[key];
      final int count = dailyAyahCounts[key] ?? 0;

      days.add(DailyReading(date: key, log: log, ayahCount: count));

      if (log != null) {
        activeDays++;
        ayahCount += count;
        if (log.isKhatam) {
          khatamCount++;
        }
        lastLog = log;
      }
    }

    return _PeriodTotals(
      ayahCount: ayahCount,
      activeDays: activeDays,
      khatamCount: khatamCount,
      lastLog: lastLog,
      days: days,
    );
  }

  DatePeriod _currentPeriod(StatisticsRange range, DateTime today) {
    switch (range) {
      case StatisticsRange.today:
        return DatePeriod(start: today, end: today);
      case StatisticsRange.week:
        final DateTime monday = addDays(today, -(today.weekday - 1));
        return DatePeriod(start: monday, end: today);
      case StatisticsRange.month:
        return DatePeriod(
          start: DateTime(today.year, today.month, 1),
          end: today,
        );
    }
  }

  DatePeriod _previousPeriod(
    StatisticsRange range,
    DateTime today,
    DatePeriod current,
  ) {
    switch (range) {
      case StatisticsRange.today:
        final DateTime yesterday = addDays(today, -1);
        return DatePeriod(start: yesterday, end: yesterday);
      case StatisticsRange.week:
        // Bandingkan porsi minggu lalu yang setara dengan hari ini.
        final DateTime previousStart = addDays(current.start, -7);
        return DatePeriod(
          start: previousStart,
          end: addDays(previousStart, current.dayCount - 1),
        );
      case StatisticsRange.month:
        // Bandingkan tanggal yang sama di bulan lalu, dibatasi akhir bulan.
        final DateTime previousStart = DateTime(today.year, today.month - 1, 1);
        final DateTime previousMonthEnd = DateTime(today.year, today.month, 0);
        final DateTime candidate = addDays(previousStart, today.day - 1);
        return DatePeriod(
          start: previousStart,
          end: candidate.isAfter(previousMonthEnd)
              ? previousMonthEnd
              : candidate,
        );
    }
  }

  /// Posisi akhir bacaan dalam hitungan ayat dari awal Alquran.
  int? _ordinalOf(DailyLog log) {
    if (log.surahId < 1 || log.surahId > 114 || log.ayahId < 1) {
      return null;
    }
    final int verseCount = _verseCounts[log.surahId - 1];
    final int ayah = math.min(log.ayahId, verseCount);
    return _surahOffsets[log.surahId - 1] + ayah;
  }

  static final List<int> _verseCounts = List<int>.unmodifiable(
    List<int>.generate(114, (int index) => getVerseCount(index + 1)),
  );

  static final List<int> _surahOffsets = List<int>.unmodifiable(() {
    final List<int> offsets = List<int>.filled(114, 0);
    int total = 0;
    for (int index = 0; index < 114; index++) {
      offsets[index] = total;
      total += _verseCounts[index];
    }
    return offsets;
  }());
}

class _PeriodTotals {
  const _PeriodTotals({
    required this.ayahCount,
    required this.activeDays,
    required this.khatamCount,
    required this.lastLog,
    required this.days,
  });

  final int ayahCount;
  final int activeDays;
  final int khatamCount;
  final DailyLog? lastLog;
  final List<DailyReading> days;
}
