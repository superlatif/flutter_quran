import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

class SurahSearchDialog extends StatefulWidget {
  const SurahSearchDialog({super.key});

  @override
  State<SurahSearchDialog> createState() => _SurahSearchDialogState();
}

class _SurahSearchDialogState extends State<SurahSearchDialog> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final String normalizedQuery = _normalizeSurahQuery(query);
    final List<int> surahNumbers =
        List<int>.generate(totalSurahCount, (int i) => i + 1).where((
          int surah,
        ) {
          final String name = getSurahName(surah);
          final String arabicName = getSurahNameArabic(surah);
          return _normalizeSurahQuery(name).contains(normalizedQuery) ||
              _normalizeSurahQuery(arabicName).contains(normalizedQuery) ||
              surah.toString() == query;
        }).toList();

    return AlertDialog(
      title: const Text('Cari Surah'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          children: <Widget>[
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Nama atau nomor surah',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: surahNumbers.isEmpty
                  ? const Center(child: Text('Surah tidak ditemukan.'))
                  : ListView.builder(
                      itemCount: surahNumbers.length,
                      itemBuilder: (BuildContext context, int index) {
                        final int surah = surahNumbers[index];
                        return ListTile(
                          title: Text(getSurahName(surah)),
                          subtitle: Text(getSurahNameArabic(surah)),
                          trailing: Text('$surah'),
                          onTap: () => Navigator.pop(context, surah),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

class QuranSearchMatch {
  const QuranSearchMatch({
    required this.surah,
    required this.ayah,
    required this.text,
  });

  final int surah;
  final int ayah;
  final String text;

  factory QuranSearchMatch.fromMap(Map<String, dynamic> map) {
    return QuranSearchMatch(
      surah: (map['sora'] as num).toInt(),
      ayah: (map['aya_no'] as num).toInt(),
      text: map['text'].toString(),
    );
  }
}

class QuranTextSearchDialog extends StatefulWidget {
  const QuranTextSearchDialog({super.key});

  @override
  State<QuranTextSearchDialog> createState() => _QuranTextSearchDialogState();
}

class _QuranTextSearchDialogState extends State<QuranTextSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<QuranSearchMatch> _matches = <QuranSearchMatch>[];
  bool _isSearching = false;
  String? _message;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final String query = _searchController.text.trim();
    if (query.isEmpty || _isSearching) {
      return;
    }

    setState(() {
      _isSearching = true;
      _matches = <QuranSearchMatch>[];
      _message = null;
    });

    try {
      final List<Map<String, dynamic>> results = await compute(
        searchQuranPhrase,
        query,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _matches = results.map(QuranSearchMatch.fromMap).toList();
        if (_matches.isEmpty) {
          _message = 'Kalimat tidak ditemukan. Coba kata Arab yang berbeda.';
        }
      });
    } catch (error) {
      debugPrint('Gagal mencari kalimat Al-Qur\'an: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _message = 'Pencarian belum berhasil. Silakan coba lagi.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cari Kalimat Al-Qur\'an'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _searchController,
              autofocus: true,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'Ketik potongan kalimat Arab',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            if (_isSearching) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_message!, textAlign: TextAlign.center),
              ),
            if (_matches.isNotEmpty)
              SizedBox(
                height: 280,
                child: ListView.builder(
                  itemCount: _matches.length,
                  itemBuilder: (BuildContext context, int index) {
                    final QuranSearchMatch match = _matches[index];
                    return ListTile(
                      title: Text(
                        match.text,
                        textDirection: TextDirection.rtl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${getSurahName(match.surah)} • Ayat ${match.ayah}',
                      ),
                      onTap: () => Navigator.pop(context, match),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        FilledButton.icon(
          onPressed: _isSearching ? null : _search,
          icon: const Icon(Icons.search),
          label: const Text('Cari'),
        ),
      ],
    );
  }
}

/// Menyamakan spasi, tanda hubung, dan apostrof agar pencarian nama surah
/// tidak sensitif terhadap perbedaan penulisan.
String _normalizeSurahQuery(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]'), '');
}

List<Map<String, dynamic>> searchQuranPhrase(String query) {
  final List<dynamic> results = searchWords(query, limit: 50)['result'] as List;
  return results
      .map((dynamic result) => Map<String, dynamic>.from(result as Map))
      .toList();
}
