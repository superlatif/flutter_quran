# Alquran — Offline Mushaf Reader

Aplikasi Al-Qur'an digital 604 halaman (15 baris per halaman, pola standar tahfidz Madani)
berbasis Flutter, mengikuti spesifikasi pada `product_requirement_document.md`.

## Fitur Utama

| Fitur | Status |
|---|---|
| Mushaf offline 15 baris/halaman (font QCF Hafs `qcf_quran_plus`) | ✅ |
| Pewarnaan Tajwid (toggle on/off) | ✅ |
| Navigasi Juz (1–30), Surah (1–114), Halaman (1–604) | ✅ |
| Portrait: 1 halaman fit-to-screen; Landscape: swipe halaman | ✅ |
| Mode 2 halaman (spread) di layar lebar (≥750px) | ✅ |
| Log bacaan harian otomatis & manual (dengan validasi ketat) | ✅ |
| Analitik Khatam (total siklus + tanggal khatam) | ✅ |
| Bookmark pohon hierarkis hingga 3 kedalaman | ✅ |
| Notifikasi pengingat per jam jika belum membaca | ✅ |
| Download font on-demand (5 halaman pertama dimuat saat startup) | ✅ |
| Animasi page curl | ℹ️ memakai swipe halaman standar (lihat catatan di bawah) |

> **Catatan page curl:** paket `qcf_quran_plus 0.1.1` tidak menyediakan hook animasi
> flip pada `QuranPageView`, sehingga perpindahan halaman memakai swipe/scroll standar.
> Implementasi animasi "membalik kertas" memerlukan refactor pagination internal.

## Prasyarat

- Flutter SDK 3.x (dikembangkan di 3.47.9 / Dart 3.13.7)
- Android SDK untuk build APK
- Koneksi internet saat `flutter pub get` dan saat aplikasi **pertama kali** menyiapkan font

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

## perilaku Startup

1. Splash memuat font **5 halaman pertama** agar aplikasi cepat terbuka.
2. Jika font belum tersedia → dialog "Unduh Sekarang / Nanti".
3. Jika dibatalkan → layar error dengan tombol unduh ulang; aplikasi tidak masuk
   pembaca sampai font siap.
4. Setelah siap → `QuranRepository.instance.ensureLoaded(604)` memuat data halaman,
   lalu masuk ke layar pembaca.

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
│   ├── bookmark_node.dart        # node pohon bookmark (kategori/sub-kategori)
│   └── bookmark_item.dart        # ayat tersimpan dalam bookmark
├── providers/
│   └── quran_provider.dart       # state pembaca: halaman, tajwid, highlight
├── screens/
│   ├── splash_screen.dart        # muat font 5 halaman awal + dialog unduh
│   ├── quran_reader_screen.dart  # pembaca mushaf utama + long-press menu
│   ├── log_khatam_screen.dart    # log harian manual + analitik khatam
│   └── bookmark_tree_screen.dart # pohon bookmark 3 kedalaman
└── services/
    ├── database_service.dart     # SQLite: daily_logs, bookmark_nodes, bookmark_items
    ├── daily_log_service.dart    # log otomatis, aturan khatam, resolusi awal bacaan
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
