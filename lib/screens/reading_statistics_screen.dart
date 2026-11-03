import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

import '../models/daily_log.dart';
import '../models/reading_statistics.dart';
import '../services/reading_statistics_service.dart';

/// Laporan statistik bacaan dengan perbandingan per hari, minggu, dan bulan.
class ReadingStatisticsScreen extends StatefulWidget {
  const ReadingStatisticsScreen({super.key});

  @override
  State<ReadingStatisticsScreen> createState() =>
      _ReadingStatisticsScreenState();
}

class _ReadingStatisticsScreenState extends State<ReadingStatisticsScreen> {
  StatisticsRange _range = StatisticsRange.today;
  ReadingStatistics? _statistics;
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final ReadingStatistics statistics = await ReadingStatisticsService
          .instance
          .load(_range);
      if (!mounted) {
        return;
      }
      setState(() {
        _statistics = statistics;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = error;
      });
    }
  }

  void _changeRange(StatisticsRange range) {
    if (range == _range) {
      return;
    }
    setState(() {
      _range = range;
      _statistics = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistik Bacaan'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => _load(showLoading: false),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(showLoading: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            SegmentedButton<StatisticsRange>(
              segments: <ButtonSegment<StatisticsRange>>[
                for (final StatisticsRange range in StatisticsRange.values)
                  ButtonSegment<StatisticsRange>(
                    value: range,
                    label: Text(range.selectorLabel),
                  ),
              ],
              selected: <StatisticsRange>{_range},
              onSelectionChanged: (Set<StatisticsRange> selection) {
                _changeRange(selection.first);
              },
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const _LoadingCard()
            else if (_error != null)
              _ErrorCard(onRetry: _load)
            else if (_statistics != null)
              ..._buildContent(_statistics!),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(ReadingStatistics statistics) {
    return <Widget>[
      _SummaryCard(statistics: statistics),
      const SizedBox(height: 16),
      _StatisticsDetails(statistics: statistics),
      const SizedBox(height: 16),
      _DailyBreakdown(statistics: statistics),
      const SizedBox(height: 16),
      const _EstimationNote(),
    ];
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(Icons.error_outline, size: 40, color: scheme.error),
            const SizedBox(height: 12),
            const Text(
              'Gagal memuat statistik bacaan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Periksa kembali data bacaan lalu coba lagi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.statistics});

  final ReadingStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int maxCount =
        statistics.currentAyahCount > statistics.previousAyahCount
        ? statistics.currentAyahCount
        : statistics.previousAyahCount;

    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    statistics.range.comparisonLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _DeltaChip(statistics: statistics),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              statistics.currentPeriod.formattedRange,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _formatNumber(statistics.currentAyahCount),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'ayat',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${statistics.range.currentLabel} • '
              '${statistics.currentActiveDays} hari aktif',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 20),
            _ComparisonBar(
              label: statistics.range.currentLabel,
              value: statistics.currentAyahCount,
              maxValue: maxCount,
              color: scheme.primary,
              trackColor: scheme.primary.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 12),
            _ComparisonBar(
              label: statistics.range.previousLabel,
              value: statistics.previousAyahCount,
              maxValue: maxCount,
              color: scheme.secondary,
              trackColor: scheme.secondary.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            Text(
              statistics.hasPreviousData
                  ? '${statistics.range.previousLabel}: '
                        '${_formatNumber(statistics.previousAyahCount)} ayat • '
                        '${statistics.previousActiveDays} hari aktif'
                  : 'Belum ada data pembanding pada periode sebelumnya.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.statistics});

  final ReadingStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final int difference = statistics.ayahDifference;
    final double? percentage = statistics.percentageChange;

    final Color foreground;
    final IconData icon;
    final String text;

    if (difference == 0) {
      foreground = theme.colorScheme.onPrimaryContainer;
      icon = Icons.trending_flat;
      text = 'Sama';
    } else if (difference > 0) {
      foreground = isDark ? Colors.green.shade300 : Colors.green.shade800;
      icon = Icons.trending_up;
      final String percent = percentage == null
          ? ''
          : ' (${percentage.toStringAsFixed(1).replaceAll('.', ',')}%)';
      text = '+${_formatNumber(difference)}$percent';
    } else {
      foreground = isDark ? Colors.red.shade300 : Colors.red.shade700;
      icon = Icons.trending_down;
      final String percent = percentage == null
          ? ''
          : ' (${percentage.abs().toStringAsFixed(1).replaceAll('.', ',')}%)';
      text = '−${_formatNumber(difference.abs())}$percent';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.trackColor,
  });

  final String label;
  final int value;
  final int maxValue;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.colorScheme.onPrimaryContainer;
    final double progress = maxValue == 0 ? 0 : value / maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: textColor),
              ),
            ),
            Text(
              '${_formatNumber(value)} ayat',
              style: theme.textTheme.labelMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: trackColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _StatisticsDetails extends StatelessWidget {
  const _StatisticsDetails({required this.statistics});

  final ReadingStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final DailyLog? lastLog = statistics.currentLastLog;
    final DailyLog? previousLastLog = statistics.previousLastLog;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _StatRow(
            icon: Icons.event_available,
            label: 'Hari aktif',
            value: '${statistics.currentActiveDays} hari',
            comparison: 'Sebelumnya ${statistics.previousActiveDays} hari',
          ),
          const Divider(height: 1),
          _StatRow(
            icon: Icons.functions,
            label: 'Rata-rata per hari aktif',
            value:
                '${_formatDecimal(statistics.currentAveragePerActiveDay)} ayat',
            comparison:
                'Sebelumnya '
                '${_formatDecimal(statistics.previousAveragePerActiveDay)} ayat',
          ),
          const Divider(height: 1),
          _StatRow(
            icon: Icons.verified_outlined,
            label: 'Khatam',
            value: '${statistics.currentKhatamCount} kali',
            comparison: 'Sebelumnya ${statistics.previousKhatamCount} kali',
          ),
          const Divider(height: 1),
          _StatRow(
            icon: Icons.place_outlined,
            label: 'Posisi terakhir',
            value: _logPosition(lastLog),
            comparison: previousLastLog == null
                ? 'Belum ada posisi pembanding'
                : 'Sebelumnya ${_logPosition(previousLastLog)}',
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.comparison,
  });

  final IconData icon;
  final String label;
  final String value;
  final String comparison;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  comparison,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBreakdown extends StatelessWidget {
  const _DailyBreakdown({required this.statistics});

  final ReadingStatistics statistics;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          _PeriodExpansion(
            title: 'Rincian ${statistics.range.currentLabel.toLowerCase()}',
            activeDays: statistics.currentActiveDays,
            dayCount: statistics.currentPeriod.dayCount,
            days: statistics.currentDays,
          ),
          const Divider(height: 1),
          _PeriodExpansion(
            title: 'Rincian ${statistics.range.previousLabel.toLowerCase()}',
            activeDays: statistics.previousActiveDays,
            dayCount: statistics.previousPeriod.dayCount,
            days: statistics.previousDays,
          ),
        ],
      ),
    );
  }
}

class _PeriodExpansion extends StatelessWidget {
  const _PeriodExpansion({
    required this.title,
    required this.activeDays,
    required this.dayCount,
    required this.days,
  });

  final String title;
  final int activeDays;
  final int dayCount;
  final List<DailyReading> days;

  @override
  Widget build(BuildContext context) {
    final List<DailyReading> reversed = days.reversed.toList();
    return ExpansionTile(
      leading: const Icon(Icons.calendar_view_day),
      title: Text(title),
      subtitle: Text('$activeDays hari aktif dari $dayCount hari'),
      children: <Widget>[
        for (final DailyReading day in reversed) _DailyReadingRow(day: day),
      ],
    );
  }
}

class _DailyReadingRow extends StatelessWidget {
  const _DailyReadingRow({required this.day});

  final DailyReading day;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DailyLog? log = day.log;
    final DateTime date = DateTime.parse(day.date);

    final Color iconColor;
    final IconData icon;
    if (log == null) {
      iconColor = scheme.outline;
      icon = Icons.remove_circle_outline;
    } else if (day.isKhatam) {
      iconColor = scheme.tertiary;
      icon = Icons.verified;
    } else {
      iconColor = scheme.primary;
      icon = Icons.check_circle;
    }

    return ListTile(
      dense: true,
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(formatWeekdayDate(date)),
      subtitle: Text(
        log == null
            ? 'Tidak ada log'
            : 'Surah ${log.surahId}:${log.ayahId}'
                  '${day.isKhatam ? ' • Khatam' : ''}',
      ),
      trailing: Text(
        day.hasLog ? '${_formatNumber(day.ayahCount)} ayat' : '—',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: day.hasLog ? scheme.onSurface : scheme.outline,
        ),
      ),
    );
  }
}

class _EstimationNote extends StatelessWidget {
  const _EstimationNote();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Jumlah ayat adalah estimasi dari selisih titik akhir bacaan '
                'antar hari yang memiliki log. Log pertama dihitung dari '
                'Al-Fatihah ayat 1, dan setelah khatam bacaan dianggap dimulai '
                'lagi dari Al-Fatihah. Periode pembanding memakai porsi waktu '
                'yang setara dengan periode berjalan.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _logPosition(DailyLog? log) {
  if (log == null) {
    return '—';
  }
  String surahName;
  try {
    surahName = getSurahName(log.surahId);
  } catch (_) {
    surahName = 'Surah ${log.surahId}';
  }
  return '$surahName ${log.surahId}:${log.ayahId}';
}

String _formatNumber(int value) {
  final String sign = value < 0 ? '−' : '';
  final String digits = value.abs().toString();
  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[index]);
  }
  return '$sign$buffer';
}

String _formatDecimal(double value) {
  if (value == 0) {
    return '0';
  }
  final double rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.05) {
    return _formatNumber(rounded.toInt());
  }
  return value.toStringAsFixed(1).replaceAll('.', ',');
}
