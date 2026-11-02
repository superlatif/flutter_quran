import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';
import 'package:provider/provider.dart';

import '../../providers/quran_provider.dart';
import '../services/daily_log_service.dart';
import '../models/daily_log.dart';

/// Layar Log Bacaan Harian & Monitoring Analitik Khatam.
class LogAndKhatamScreen extends StatefulWidget {
  const LogAndKhatamScreen({super.key});

  @override
  State<LogAndKhatamScreen> createState() => _LogAndKhatamScreenState();
}

class _LogAndKhatamScreenState extends State<LogAndKhatamScreen> {
  DailyLog? _todayLog;
  DailyLog? _yesterdayLog;
  bool _isLoading = true;
  int _totalKhatams = 0;
  List<DailyLog> _khatamCompletions = <DailyLog>[];

  int _selectedSurah = 1;
  final TextEditingController _startAyahController = TextEditingController(
    text: '1',
  );
  final TextEditingController _endAyahController = TextEditingController(
    text: '1',
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final DailyLog? todayLog = await DailyLogService.instance.getTodaysLog();
    final DailyLog? yesterdayLog = await DailyLogService.instance.getLogForDate(
      _yesterdayDate(),
    );
    final List<DailyLog> completions = await DailyLogService.instance
        .getKhatamCompletions();
    final int totalKhatams = await DailyLogService.instance.getTotalKhatams();

    if (!mounted) {
      return;
    }

    setState(() {
      _todayLog = todayLog;
      _yesterdayLog = yesterdayLog;
      _khatamCompletions = completions;
      _totalKhatams = totalKhatams;
      _isLoading = false;
    });
  }

  String _yesterdayDate() {
    final DateTime now = DateTime.now();
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${yesterday.year.toString().padLeft(4, '0')}-${twoDigits(yesterday.month)}-${twoDigits(yesterday.day)}';
  }

  @override
  void dispose() {
    _startAyahController.dispose();
    _endAyahController.dispose();
    super.dispose();
  }

  Future<void> _saveManualLog() async {
    final int? startAyah = int.tryParse(_startAyahController.text);
    final int? endAyah = int.tryParse(_endAyahController.text);

    if (startAyah == null || endAyah == null) {
      _showSnackBar('Isi rentang ayat dengan angka yang valid');
      return;
    }

    final int maxAyah = getVerseCount(_selectedSurah);

    if (startAyah < 1 || endAyah < startAyah || endAyah > maxAyah) {
      _showSnackBar(
        'Validasi gagal. Rentang ayat harus antara 1 sampai $maxAyah pada Surah ini.',
      );
      return;
    }

    await DailyLogService.instance.markReadingAsFinished(
      surahId: _selectedSurah,
      ayahId: endAyah,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _todayLog = DailyLog(
        date: DailyLogService.instance.today,
        surahId: _selectedSurah,
        ayahId: endAyah,
      );
    });

    _showSnackBar('Log bacaan berhasil disimpan');
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final QuranProvider provider = context.watch<QuranProvider>();

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Log & Monitoring Khatam')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Status Bacaan Hari Ini',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_todayLog == null)
                      const Text('Belum ada log bacaan hari ini.')
                    else
                      Text(
                        'Terakhir dibaca: Surah ${_todayLog!.surahId}, Ayat ${_todayLog!.ayahId}'
                        '${_todayLog!.isKhatam ? ' (Khatam)' : ''}',
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Awal bacaan hari ini (otomatis): ${_getNextReadingStartText(provider)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Input Log Manual',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedSurah,
                      items: <DropdownMenuItem<int>>[
                        for (int i = 1; i <= 114; i++)
                          DropdownMenuItem<int>(
                            value: i,
                            child: Text('Surah $i'),
                          ),
                      ],
                      onChanged: (int? value) {
                        setState(() {
                          _selectedSurah = value ?? 1;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Surah'),
                    ),
                    TextField(
                      controller: _startAyahController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Dari Ayat'),
                    ),
                    TextField(
                      controller: _endAyahController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sampai Ayat',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _saveManualLog,
                      child: const Text('Simpan Log'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Analitik Khatam',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Total Siklus Khatam: $_totalKhatams'),
                    const SizedBox(height: 8),
                    ..._khatamCompletions.map<Widget>(
                      (DailyLog log) => ListTile(
                        title: Text(
                          'Khatam pada ${log.date} (Surah ${log.surahId}:${log.ayahId})',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getNextReadingStartText(QuranProvider provider) {
    final DailyLog? nextStart = DailyLogService.instance
        .resolveNextReadingStart(_yesterdayLog);
    if (nextStart == null) {
      return 'Awal bacaan hari ini belum ditentukan (belum ada bacaan kemarin).';
    }
    if (nextStart.isKhatam) {
      return 'Awal bacaan hari ini: Al-Fatihah ayat 1 (karena kemarin adalah khatam).';
    }
    return 'Awal bacaan hari ini: Surah ${nextStart.surahId}, Ayat ${nextStart.ayahId}.';
  }
}
