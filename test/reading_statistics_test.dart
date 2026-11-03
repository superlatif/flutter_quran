import 'package:flutter_test/flutter_test.dart';
import 'package:quran2/models/daily_log.dart';
import 'package:quran2/models/reading_statistics.dart';
import 'package:quran2/services/reading_statistics_service.dart';

void main() {
  final ReadingStatisticsService service = ReadingStatisticsService.instance;

  DailyLog log(String date, int surahId, int ayahId) {
    return DailyLog(date: date, surahId: surahId, ayahId: ayahId);
  }

  test('membandingkan hari ini dengan kemarin dan menghitung log pertama', () {
    final ReadingStatistics stats = service.buildStatistics(
      range: StatisticsRange.today,
      now: DateTime(2026, 11, 3, 20, 30),
      logs: <DailyLog>[log('2026-11-03', 1, 7), log('2026-11-02', 1, 5)],
    );

    // Kemarin adalah log pertama, jadi dihitung dari Al-Fatihah ayat 1.
    expect(stats.previousAyahCount, 5);
    expect(stats.currentAyahCount, 2);
    expect(stats.ayahDifference, -3);
    expect(stats.percentageChange, closeTo(-60, 0.001));
    expect(stats.currentActiveDays, 1);
    expect(stats.previousActiveDays, 1);
    expect(stats.currentPeriod.dayCount, 1);
    expect(stats.previousPeriod.dayCount, 1);
    expect(formatIsoDate(stats.currentPeriod.start), '2026-11-03');
    expect(formatIsoDate(stats.previousPeriod.start), '2026-11-02');
    expect(stats.currentLastLog?.surahId, 1);
    expect(stats.currentLastLog?.ayahId, 7);
  });

  test(
    'membandingkan minggu berjalan dengan porsi minggu lalu yang setara',
    () {
      final ReadingStatistics stats = service.buildStatistics(
        range: StatisticsRange.week,
        now: DateTime(2026, 11, 4),
        logs: <DailyLog>[
          log('2026-11-04', 2, 1),
          log('2026-10-26', 1, 1),
          log('2026-11-02', 1, 5),
          log('2026-10-28', 1, 4),
          log('2026-10-27', 1, 3),
          log('2026-11-03', 1, 7),
        ],
      );

      // Minggu dimulai Senin: 2-4 November vs 26-28 Oktober.
      expect(formatIsoDate(stats.currentPeriod.start), '2026-11-02');
      expect(formatIsoDate(stats.currentPeriod.end), '2026-11-04');
      expect(formatIsoDate(stats.previousPeriod.start), '2026-10-26');
      expect(formatIsoDate(stats.previousPeriod.end), '2026-10-28');
      expect(stats.currentPeriod.dayCount, 3);
      expect(stats.previousPeriod.dayCount, 3);

      expect(stats.currentAyahCount, 4);
      expect(stats.previousAyahCount, 4);
      expect(stats.percentageChange, 0);
      expect(stats.currentActiveDays, 3);
      expect(stats.previousActiveDays, 3);
    },
  );

  test('membandingkan bulan dan membatasi akhir bulan pendek', () {
    final ReadingStatistics stats = service.buildStatistics(
      range: StatisticsRange.month,
      now: DateTime(2026, 3, 31),
      logs: <DailyLog>[log('2026-02-28', 1, 7), log('2026-03-31', 2, 1)],
    );

    expect(formatIsoDate(stats.currentPeriod.start), '2026-03-01');
    expect(formatIsoDate(stats.currentPeriod.end), '2026-03-31');
    expect(formatIsoDate(stats.previousPeriod.start), '2026-02-01');
    expect(formatIsoDate(stats.previousPeriod.end), '2026-02-28');
    expect(stats.previousPeriod.dayCount, 28);

    expect(stats.previousAyahCount, 7);
    expect(stats.currentAyahCount, 1);
    expect(stats.percentageChange, closeTo(-85.714, 0.01));
  });

  test('bulan pembanding hanya memakai porsi hari yang sudah berjalan', () {
    final ReadingStatistics stats = service.buildStatistics(
      range: StatisticsRange.month,
      now: DateTime(2026, 3, 10),
      logs: <DailyLog>[log('2026-02-10', 1, 7), log('2026-03-10', 2, 1)],
    );

    expect(formatIsoDate(stats.currentPeriod.start), '2026-03-01');
    expect(formatIsoDate(stats.currentPeriod.end), '2026-03-10');
    expect(formatIsoDate(stats.previousPeriod.start), '2026-02-01');
    expect(formatIsoDate(stats.previousPeriod.end), '2026-02-10');
    expect(stats.currentPeriod.dayCount, 10);
    expect(stats.previousPeriod.dayCount, 10);
  });

  test('setelah khatam bacaan dihitung ulang dari Al-Fatihah', () {
    final ReadingStatistics stats = service.buildStatistics(
      range: StatisticsRange.today,
      now: DateTime(2026, 11, 2),
      logs: <DailyLog>[log('2026-11-01', 114, 6), log('2026-11-02', 1, 1)],
    );

    expect(stats.previousAyahCount, 6236);
    expect(stats.currentAyahCount, 1);
    expect(stats.currentKhatamCount, 0);
    expect(stats.previousKhatamCount, 1);
    expect(stats.percentageChange, closeTo(-99.984, 0.001));
  });

  test('menangani riwayat kosong', () {
    final ReadingStatistics stats = service.buildStatistics(
      range: StatisticsRange.today,
      now: DateTime(2026, 11, 3),
      logs: const <DailyLog>[],
    );

    expect(stats.currentAyahCount, 0);
    expect(stats.previousAyahCount, 0);
    expect(stats.currentActiveDays, 0);
    expect(stats.previousActiveDays, 0);
    expect(stats.currentKhatamCount, 0);
    expect(stats.previousKhatamCount, 0);
    expect(stats.currentLastLog, isNull);
    expect(stats.previousLastLog, isNull);
    expect(stats.percentageChange, 0);
    expect(stats.hasPreviousData, isFalse);
    expect(stats.currentDays, hasLength(1));
    expect(stats.previousDays, hasLength(1));
  });

  test('log pertama dihitung dari awal Alquran', () {
    final ReadingStatistics stats = service.buildStatistics(
      range: StatisticsRange.today,
      now: DateTime(2026, 11, 3),
      logs: <DailyLog>[log('2026-11-03', 2, 255)],
    );

    // 7 ayat Al-Fatihah + 255 ayat Al-Baqarah.
    expect(stats.currentAyahCount, 262);
    expect(stats.previousAyahCount, 0);
    expect(stats.percentageChange, isNull);
    expect(stats.hasPreviousData, isFalse);
    expect(stats.currentActiveDays, 1);
  });

  test('kemunduran posisi tidak menghasilkan jumlah ayat negatif', () {
    final ReadingStatistics stats = service.buildStatistics(
      range: StatisticsRange.today,
      now: DateTime(2026, 11, 3),
      logs: <DailyLog>[log('2026-11-02', 2, 10), log('2026-11-03', 1, 1)],
    );

    expect(stats.previousAyahCount, 17);
    expect(stats.currentAyahCount, 0);
    expect(stats.currentActiveDays, 1);
    expect(stats.currentAveragePerActiveDay, 0);
    expect(stats.percentageChange, -100);
  });
}
