import 'package:flutter/material.dart';

/// Isi halaman "Tentang Kami".
///
/// Tambah, ubah, atau hapus entri di daftar ini untuk menyesuaikan teks yang
/// ditampilkan. Setiap entri dirender sebagai satu paragraf.
const List<String> _aboutParagraphs = <String>[
  'Alquran adalah aplikasi mushaf digital yang membantu Anda membaca '
      'Al-Qur\'an, memahami makna, dan memantau progres bacaan harian.',
  'Tambahkan baris teks berikutnya di sini. Anda dapat menambahkan '
      'sebanyak yang diperlukan.',
  'Aplikasi Al-Qur\'an digital 604 halaman (15 baris per halaman, '
      'pola standar tahfidz Madani)',
  'Aplikasi ini juga menyediakan fitur-fitur tambahan seperti '
      'pencarian ayat, bookmark, catatan, dan pencatat siklus khotaman untuk '
      'membantu Anda tetap konsisten dalam membaca Al-Qur\'an.',
  'Fitur tambahan berupa mode terjemah dimana anda dapat memberikan terjemah '
      'per kata dan keterangan ayat',
  'Fitur Pegon membantu mengonversi teks Bahasa Indonesia menjadi aksara '
      'Pegon yang bisa disalin ke kolom makna atau keterangan ayat pada mode '
      'terjemah',
  'Kami berkomitmen untuk terus meningkatkan aplikasi ini berdasarkan masukan dari pengguna. '
      'Jika Anda memiliki saran atau menemukan bug, silakan hubungi kami ',
  'melalui email di abdulatifrokhman@gmail.com, phone 085259647790',
];

/// Halaman statis berisi informasi tentang aplikasi.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _appIconAsset = 'assets/images/icon.png';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tentang Kami')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        children: <Widget>[
          Center(
            child: Container(
              width: 120,
              height: 120,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceContainerHighest,
                border: Border.all(color: colors.outlineVariant),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Image.asset(
                _appIconAsset,
                fit: BoxFit.cover,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) => Icon(Icons.menu_book, size: 56, color: colors.primary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Alquran',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mushaf digital & pendamping ibadah harian',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          ..._aboutParagraphs.map(
            (String paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                paragraph,
                textAlign: TextAlign.justify,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
