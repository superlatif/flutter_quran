import 'package:flutter/material.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';
import 'package:qcf_quran_plus/src/widgets/quran_page/quran_repository.dart';
import 'package:provider/provider.dart';

import '../../providers/quran_provider.dart';
import '../services/bookmark_service.dart';
import '../services/daily_log_service.dart';
import 'bookmark_tree_screen.dart';
import 'log_khatam_screen.dart';

/// Layar utama pembaca Mushaf Al-Qur'an (15 baris per halaman).
class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  @override
  Widget build(BuildContext context) {
    final QuranProvider provider = context.watch<QuranProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text('Alquran'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.bookmarks),
            tooltip: 'Bookmark',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => const BookmarkTreeScreen(),
                ),
              );
            },
          ),
          Switch(
            value: provider.isTajweed,
            onChanged: (_) => provider.toggleTajweed(),
          ),
          IconButton(
            icon: Icon(
              provider.dualPage ? Icons.grid_view : Icons.layers,
              color: provider.dualPage
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: provider.dualPage
                ? 'Mode 2 Halaman / Spread'
                : 'Mode 1 Halaman',
            onPressed: () => provider.setDualPage(!provider.dualPage),
          ),
        ],
      ),
      body: !QuranRepository.instance.isReady
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool twoPage =
                    provider.dualPage && constraints.maxWidth >= 750;
                return QuranPageView(
                  pageController: provider.pageController,
                  highlights: provider.highlights,
                  isDarkMode: isDark,
                  isTajweed: provider.isTajweed,
                  enableTwoPageLayout: twoPage,
                  deferNewPages: true,
                  deferDelay: const Duration(milliseconds: 50),
                  onPageChanged: (int? pageNumber) {
                    if (pageNumber != null) {
                      provider.handlePageChanged(pageNumber);
                    }
                  },
                  onLongPress:
                      (int surah, int ayah, LongPressStartDetails details) {
                        _showAyahMenu(surah, ayah);
                      },
                  topBar: _buildTopBar(context, provider),
                  bottomBar: _buildBottomBar(),
                );
              },
            ),
    );
  }

  Widget _buildTopBar(BuildContext context, QuranProvider provider) {
    return SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: provider.prevPage,
          ),
          Expanded(
            child: Center(
              child: Text(
                'Halaman ${provider.currentPage} / ${provider.totalPages}',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: provider.nextPage,
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.mosque),
            tooltip: 'Pilih Surah',
            onSelected: (int value) => provider.goToSurah(value),
            itemBuilder: (BuildContext context) => _buildSurahMenuItems(),
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.reorder),
            tooltip: 'Pilih Juz',
            onSelected: (int value) => provider.goToJuz(value),
            itemBuilder: (BuildContext context) => _buildJuzMenuItems(),
          ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<int>> _buildSurahMenuItems() {
    return <PopupMenuEntry<int>>[
      for (int i = 1; i <= 114; i++)
        PopupMenuItem<int>(value: i, child: Text(getSurahName(i))),
    ];
  }

  List<PopupMenuEntry<int>> _buildJuzMenuItems() {
    return <PopupMenuEntry<int>>[
      for (int i = 1; i <= 30; i++)
        PopupMenuItem<int>(value: i, child: Text('Juz $i')),
    ];
  }

  Widget _buildBottomBar() {
    final QuranProvider provider = context.watch<QuranProvider>();
    return SizedBox(
      height: 40,
      child: Center(
        child: Text('Tajwid: ${provider.isTajweed ? 'Aktif' : 'Mati'}'),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF0F766E)),
            child: Center(
              child: Text(
                'Alquran',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Log & Monitoring Khatam'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => const LogAndKhatamScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Bookmark'),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (BuildContext context) => const BookmarkTreeScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAyahMenu(int surah, int ayah) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: const Text('Tandai Akhir Bacaan Hari Ini'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _markReadingAsFinished(surah, ayah);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: const Text('Tambahkan ke Bookmark'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _addBookmark(context, surah, ayah);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markReadingAsFinished(int surah, int ayah) async {
    await DailyLogService.instance.markReadingAsFinished(
      surahId: surah,
      ayahId: ayah,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Log bacaan $surah:$ayah berhasil disimpan')),
    );
  }

  Future<void> _addBookmark(BuildContext context, int surah, int ayah) async {
    final List<dynamic> nodes = await BookmarkService.instance.getNodes();
    if (!mounted) {
      return;
    }

    final int? nodeId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Pilih Kategori Bookmark'),
              ),
              for (final dynamic node in nodes)
                ListTile(
                  title: Text(node.name.toString()),
                  onTap: () async {
                    Navigator.pop(context, node.id);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (nodeId != null) {
      final int pageNumber = getPageNumber(surah, ayah);
      await BookmarkService.instance.createItem(
        nodeId: nodeId,
        surahId: surah,
        ayahId: ayah,
        pageNumber: pageNumber,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ayat berhasil ditambahkan ke bookmark')),
      );
    }
  }
}
