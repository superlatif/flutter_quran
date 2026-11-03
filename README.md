# Alquran — Offline Mushaf Reader

Aplikasi Al-Qur'an digital 604 halaman (15 baris per halaman, pola standar tahfidz Madani)
berbasis Flutter, mengikuti spesifikasi pada `product_requirement_document.md`.

## Fitur Utama

| Fitur | Status |
|---|---|
| Mushaf offline 15 baris/halaman (font QCF Hafs `qcf_quran_plus`) | ✅ |
| Nama surah & juz sejajar dengan judul pembaca; semua kontrol tampil/hilang saat halaman diketuk (toggle) | ✅ |
| Pewarnaan Tajwid (toggle on/off) | ✅ |
| Cari Juz (1–30), Surah (1–114), Halaman (1–604), dan kalimat Al-Qur'an | ✅ |
| Portrait: 1 halaman fit-to-screen; Landscape: swipe halaman | ✅ |
| Mode 2 halaman (spread) di layar lebar (≥750px) | ✅ |
| Log bacaan harian otomatis & manual (dengan validasi ketat) | ✅ |
| Analitik Khatam (total siklus + tanggal khatam) | ✅ |
| Statistik bacaan: hari ini vs kemarin, minggu ini vs minggu lalu, bulan ini vs bulan lalu | ✅ |
| Bookmark pohon hierarkis hingga 3 kedalaman | ✅ |
| Notifikasi pengingat per jam jika belum membaca | ✅ |
| Indikator progres 604 halaman offline; ketuk untuk menyiapkan seluruh font di latar belakang | ✅ |
| Animasi page curl | ℹ️ memakai swipe halaman standar (lihat catatan di bawah) |

> **Catatan page curl:** paket `qcf_quran_plus 0.1.1` tidak menyediakan hook animasi
> flip pada `QuranPageView`, sehingga perpindahan halaman memakai swipe/scroll standar.
> Implementasi animasi "membalik kertas" memerlukan refactor pagination internal.

## Prasyarat

- Flutter SDK 3.x (dikembangkan di 3.47.9 / Dart 3.13.7)
- Android SDK untuk build APK
- Koneksi internet saat `flutter pub get`; aset font Mushaf ikut dikemas dan dapat disiapkan tanpa internet

## Menjalankan Aplikasi

```bash
flutter pub get

# Desktop Linux (untuk pengujian cepat)
flutter run -d linux

# Android
flutter run -d <device-id>
```

> **Linux/Windows/macOS:** database menggunakan `sqflite_common_ffi`
> (diinisialisasi otomatis di `lib/main.dart`), jadi bookmark & log khatam berfungsi penuh.

## Perilaku Startup

1. Pembaca langsung terbuka. Data Mushaf bawaan aplikasi diproses kembali di
   memori setiap kali aplikasi dimulai; ini pemuatan lokal, bukan unduhan internet.
2. Sambil data lokal disiapkan, indikator offline tetap terlihat di AppBar.
   Halaman pertama dan data Mushaf disiapkan bersamaan.
3. Indikator lingkaran kecil menunjukkan persentase halaman yang font-nya
   sudah tersimpan di perangkat: hijau berarti siap offline, merah berarti
   belum tersimpan. Persentase diperiksa kembali setiap aplikasi dibuka.
4. Ketuk indikator untuk menyiapkan semua halaman yang belum tersedia. Proses
   berjalan bertahap tanpa mengunci pembaca, terus berjalan saat berpindah ke
   layar lain, dan dapat dilanjutkan setelah aplikasi dibuka kembali.
5. Membuka halaman baru menyiapkan font halaman itu secara otomatis. Font
   halaman berikutnya dan sebelumnya juga disiapkan di latar belakang agar
   pergantian halaman tidak tertahan. Pencarian kalimat dijalankan di isolate
   agar tidak menghambat tampilan.

## Build APK

```bash
# Debug
flutter build apk --debug

# Release
flutter build apk --release
```

### Menandatangani APK release (opsional)

1. Buat keystore:

```bash
keytool -genkey -v -keystore ~/alquran-key.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias alquran
```

2. Buat file `android/key.properties`:

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=alquran
storeFile=/path/ke/keystore/alquran-key.jks
```

3. Konfigurasi `android/app/build.gradle.kts` untuk membaca `key.properties`
   dan memakai `signingConfig` saat release (lihat dokumentasi Flutter
   "Android deployment").
4. Build release yang ditandatangani:

```bash
flutter build apk --release
```

## Struktur Kode

```
lib/
├── main.dart                     # entry: provider + inisialisasi sqflite FFI desktop
├── models/
│   ├── daily_log.dart            # model log bacaan harian
│   ├── quran_page_info.dart      # nama surah & juz untuk judul pembaca
│   ├── reading_statistics.dart   # model periode, harian, dan hasil statistik
│   ├── bookmark_node.dart        # node pohon bookmark (kategori/sub-kategori)
│   └── bookmark_item.dart        # ayat tersimpan dalam bookmark
├── providers/
│   └── quran_provider.dart       # state pembaca: halaman, tajwid, highlight
├── screens/
│   ├── quran_reader_screen.dart  # pembaca mushaf utama + long-press menu
│   ├── log_khatam_screen.dart    # log harian manual + analitik khatam
│   ├── reading_statistics_screen.dart # laporan statistik & perbandingan periode
│   └── bookmark_tree_screen.dart # pohon bookmark 3 kedalaman
└── services/
    ├── database_service.dart     # SQLite: daily_logs, bookmark_nodes, bookmark_items
    ├── daily_log_service.dart    # log otomatis, aturan khatam, resolusi awal bacaan
    ├── reading_statistics_service.dart # agregasi estimasi ayat per periode
    ├── bookmark_service.dart     # operasi pohon bookmark
    └── notification_service.dart # pengingat per jam (flutter_local_notifications)
```

## Aturan Log Bacaan (PRD §3.4)

- Bacaan hari ini otomatis dimulai dari **posisi terakhir kemarin + 1 ayat**.
- **Exception khatam:** jika kemarin berakhir di An-Nas:6, hari ini dimulai dari
  Al-Fatihah:1 dan siklus khatam bertambah.
- **Long-press ayat** di mushaf → "Tandai Akhir Bacaan Hari Ini".
- **Input manual** oleh admin dengan validasi ketat: rentang ayat harus
  `1 ≤ start ≤ end ≤ jumlah ayat surah`.

## Statistik Bacaan

Menu **Statistik Bacaan** di drawer menampilkan perbandingan:

- hari ini vs kemarin,
- minggu ini vs minggu lalu (minggu dimulai Senin),
- bulan ini vs bulan lalu.

Karena `daily_logs` hanya menyimpan titik akhir bacaan per tanggal, jumlah ayat
dihitung sebagai estimasi dari selisih posisi akhir antar hari yang memiliki log.
Log pertama dihitung dari Al-Fatihah:1; jika log sebelumnya adalah khatam
(An-Nas:6), bacaan dianggap dimulai lagi dari Al-Fatihah:1. Periode pembanding
memakai porsi waktu yang setara dengan periode berjalan (misalnya sampai hari
yang sama pada minggu/bulan lalu), sehingga perbandingan tetap adil saat periode
berjalan belum selesai.
