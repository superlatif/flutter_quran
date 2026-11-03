import 'daily_log.dart';

/// Periode perbandingan yang tersedia pada laporan statistik bacaan.
enum StatisticsRange { today, week, month }

extension StatisticsRangeLabels on StatisticsRange {
  /// Label pendek untuk pemilih periode.
  String get selectorLabel => switch (this) {
    StatisticsRange.today => 'Hari',
    StatisticsRange.week => 'Minggu',
    StatisticsRange.month => 'Bulan',
  };

  /// Label lengkap untuk judul perbandingan.
  String get comparisonLabel => switch (this) {
    StatisticsRange.today => 'Hari ini vs kemarin',
    StatisticsRange.week => 'Minggu ini vs minggu lalu',
    StatisticsRange.month => 'Bulan ini vs bulan lalu',
  };

  /// Nama periode berjalan.
  String get currentLabel => switch (this) {
    StatisticsRange.today => 'Hari ini',
    StatisticsRange.week => 'Minggu ini',
    StatisticsRange.month => 'Bulan ini',
  };

  /// Nama periode pembanding.
  String get previousLabel => switch (this) {
    StatisticsRange.today => 'Kemarin',
    StatisticsRange.week => 'Minggu lalu',
    StatisticsRange.month => 'Bulan lalu',
  };
}

/// Rentang tanggal inklusif yang dipakai untuk agregasi statistik.
class DatePeriod {
  const DatePeriod({required this.start, required this.end});

  /// Tanggal awal (inklusif), dinormalisasi ke tengah malam lokal.
  final DateTime start;

  /// Tanggal akhir (inklusif), dinormalisasi ke tengah malam lokal.
  final DateTime end;

  int get dayCount => _inclusiveDayCount(start, end);

  bool contains(String date) {
    final String startKey = formatIsoDate(start);
    final String endKey = formatIsoDate(end);
    return date.compareTo(startKey) >= 0 && date.compareTo(endKey) <= 0;
  }

  String get formattedRange => formatDatePeriod(this);

  @override
  String toString() => '${formatIsoDate(start)} s.d. ${formatIsoDate(end)}';
}

/// Satu hari di dalam periode laporan.
class DailyReading {
  const DailyReading({
    required this.date,
    required this.log,
    required this.ayahCount,
  });

  /// Tanggal dalam format `YYYY-MM-DD`.
  final String date;

  /// Log bacaan pada tanggal tersebut, atau `null` jika tidak ada log.
  final DailyLog? log;

  /// Estimasi jumlah ayat yang dibaca pada tanggal tersebut.
  final int ayahCount;

  bool get hasLog => log != null;

  bool get isKhatam => log?.isKhatam ?? false;
}

/// Hasil agregasi statistik bacaan untuk satu periode beserta pembandingnya.
class ReadingStatistics {
  const ReadingStatistics({
    required this.range,
    required this.currentPeriod,
    required this.previousPeriod,
    required this.currentAyahCount,
    required this.previousAyahCount,
    required this.currentActiveDays,
    required this.previousActiveDays,
    required this.currentKhatamCount,
    required this.previousKhatamCount,
    required this.currentLastLog,
    required this.previousLastLog,
    required this.currentDays,
    required this.previousDays,
  });

  final StatisticsRange range;
  final DatePeriod currentPeriod;
  final DatePeriod previousPeriod;

  final int currentAyahCount;
  final int previousAyahCount;

  final int currentActiveDays;
  final int previousActiveDays;

  final int currentKhatamCount;
  final int previousKhatamCount;

  final DailyLog? currentLastLog;
  final DailyLog? previousLastLog;

  final List<DailyReading> currentDays;
  final List<DailyReading> previousDays;

  int get ayahDifference => currentAyahCount - previousAyahCount;

  double get currentAveragePerActiveDay =>
      currentActiveDays == 0 ? 0 : currentAyahCount / currentActiveDays;

  double get previousAveragePerActiveDay =>
      previousActiveDays == 0 ? 0 : previousAyahCount / previousActiveDays;

  /// Persentase perubahan dibanding periode sebelumnya.
  ///
  /// Mengembalikan `null` jika periode sebelumnya belum memiliki bacaan,
  /// sehingga persentase tidak bermakna.
  double? get percentageChange {
    if (previousAyahCount == 0) {
      return currentAyahCount == 0 ? 0 : null;
    }
    return (ayahDifference / previousAyahCount) * 100;
  }

  bool get hasPreviousData => previousAyahCount > 0 || previousActiveDays > 0;
}

const List<String> _monthNames = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

const List<String> _weekdayNames = <String>[
  'Sen',
  'Sel',
  'Rab',
  'Kam',
  'Jum',
  'Sab',
  'Min',
];

/// Menormalisasi [date] menjadi tanggal lokal tanpa komponen waktu.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Menambah [days] hari dengan aman dari pergeseran DST.
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Format tanggal yang sama dengan yang disimpan di database (`YYYY-MM-DD`).
String formatIsoDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-'
      '${twoDigits(date.month)}-${twoDigits(date.day)}';
}

String formatShortDate(DateTime date) =>
    '${date.day} ${_monthNames[date.month - 1]}';

String formatShortDateWithYear(DateTime date) =>
    '${formatShortDate(date)} ${date.year}';

String formatWeekdayDate(DateTime date) =>
    '${_weekdayNames[date.weekday - 1]}, ${formatShortDate(date)}';

String formatDatePeriod(DatePeriod period) {
  final DateTime start = period.start;
  final DateTime end = period.end;

  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return formatShortDateWithYear(start);
  }

  if (start.year == end.year && start.month == end.month) {
    return '${start.day}–${end.day} ${_monthNames[end.month - 1]} ${end.year}';
  }

  if (start.year == end.year) {
    return '${formatShortDate(start)} – ${formatShortDateWithYear(end)}';
  }

  return '${formatShortDateWithYear(start)} – ${formatShortDateWithYear(end)}';
}

int _inclusiveDayCount(DateTime start, DateTime end) {
  final DateTime startUtc = DateTime.utc(start.year, start.month, start.day);
  final DateTime endUtc = DateTime.utc(end.year, end.month, end.day);
  return endUtc.difference(startUtc).inDays + 1;
}
