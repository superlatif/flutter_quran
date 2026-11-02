# Product Requirement Document (PRD)

## 1. Identitas & Ringkasan Proyek

| Parameter | Spesifikasi / Nilai |
| :--- | :--- |
| **Nama Aplikasi** | Alquran |
| **Package Name / Application ID** | `com.mitrasolusi.alquran` |
| **Target Platform Target** | Android (APK Output) & Linux Desktop (Development / Emulasi) |
| **Framework UI** | Flutter (Dart) |
| **Library Utama Quran** | `qcf_quran_plus` (Font QCF Madani 15 Baris & Mode Tajwid) |
| **Penyimpanan Lokal** | SQLite / Hive / Isar (Offline storage) |

---

## 2. Tujuan & Ringkasan Aplikasi

Aplikasi **Alquran** adalah *Offline Mushaf Reader* digital 15 baris per halaman (pola standar tahfidz Madani) yang mengintegrasikan fitur pewarnaan Tajwid, fleksibilitas tampilan (*single/double page* & *responsive landscape zoom*), pelacakan/log bacaan harian otomatis & manual, analitik pencapaian Khatam, sistem Bookmark Pohon Hirarkis (hingga 3 kedalaman), animasi perpindahan halaman mirip lembar kertas (*page curl animation*), serta notifikasi pengingat per jam jika pengguna belum membaca Al-Qur'an pada hari bersangkutan.

---

## 3. Fitur Utama & Spesifikasi Fungsional

### 3.1. Pembaca Mushaf (Quran Reader)
* **Standardization:** Layout 15 baris per halaman (604 Halaman Mushaf Madani).
* **Library Integration:** Menggunakan `qcf_quran_plus` untuk kompatibilitas Font QCF (Quran Complex Font).
* **Opsi Pewarnaan Tajwid:** Sakelar (*toggle*) untuk mengaktifkan atau mematikan visualisasi Tajwid berwarna.
* **Navigasi Cepat:**
  * Berdasarkan **Juz** (1 - 30).
  * Berdasarkan **Surah** (1 - 114).
  * Berdasarkan **Halaman** (1 - 604).
* **Mode Tampilan Layar:**
  * **Portrait Mode:** 1 Halaman penuh terukur pas (*fit-to-screen*).
  * **Landscape Mode Options:**
    1. **1 Halaman (Zoom Mode):** Huruf diperbesar secara proporsional. Halaman menjadi dapat di-scroll vertikal (`SingleChildScrollView`) untuk melihat bagian bawah halaman.
    2. **2 Halaman (Dual Page Spread):** Menampilkan 2 halaman bersandingan layaknya Mushaf cetak terbuka.
* **Animasi Pembuka Lembar Halaman:** Menggunakan efek transisi skeuomorfik *page curl* (efek membalik kertas Mushaf nyata saat *swipe* halaman).

### 3.2. Penanganan Asset Offline & Download Manager
* **Offline First Approach:** Seluruh teks Uthmanic & struktur metadata tersimpan secara lokal.
* **Font/Tajwid Asset Manager:**
  * Aplikasi memeriksa font QCF setiap halaman pada penyimpanan lokal saat pembaca dibuka.
  * Indikator lingkaran di AppBar menunjukkan persentase halaman yang siap offline: hijau untuk halaman yang sudah tersimpan dan merah untuk halaman yang belum tersedia.
  * Pengguna dapat mengetuk indikator untuk menyiapkan seluruh font halaman yang belum tersedia secara bertahap tanpa mengunci pembaca. Proses dapat dilanjutkan setelah gagal.
  * Font QCF disimpan di ruang penyimpanan lokal (*Local Application Storage*) agar seluruh halaman dapat dibaca offline.

### 3.3. Log Bacaan Harian & Analitik Khatam

#### A. Logika & Mekanisme Log Bacaan Harian:
1. **Model Data Sederhana:** Setiap hari aplikasi cukup mencatat titik akhir bacaan (`SurahID`, `AyahID`, `Timestamp`).
2. **Kalkulasi Otomatis:**
   * **Awal Bacaan Hari Ini** = (Akhir Bacaan Kemarin) + 1 Ayat.
   * *Pengecualian Khatam:* Jika akhir bacaan kemarin adalah Surah An-Nas ayat 6 (Khatam), maka awal bacaan hari ini otomatis diset kembali ke Surah Al-Fatihah ayat 1.
3. **Pencatatan Melalui Long Press:**
   * Saat pengguna membaca Mushaf dan melakukan *Long Press* pada ayat tertentu, muncul menu dialog dengan opsi utama: **"Tandai Akhir Bacaan Hari Ini"**.
   * Menandai ini akan langsung memperbarui (*upsert*) log bacaan pada tanggal hari ini.
4. **Pencatatan Manual:**
   * Tersedia formulir input manual bagi pengguna untuk memasukkan log bacaan (Pilih Surah dan Rentang Ayat dari .. s.d ..).
   * **Validasi Input:** Sistem memvalidasi secara ketat agar `AyahID` yang diinput tidak melebihi jumlah ayat maksimal dalam surah terkait (contoh: Al-Baqarah max 286 ayat, Al-Fatihah max 7 ayat).

#### B. Analitik Khatam (Monitoring):
* **Jumlah Khatam:** Menghitung total siklus penyelesaian bacaan dari Al-Fatihah hingga An-Nas.
* **Durasi Khatam:** Menghitung durasi hari/bulan yang dibutuhkan untuk satu siklus Khatam (dihitung dari `Tanggal Awal Baca Al-Fatihah` hingga `Tanggal Penyelesaian An-Nas`).

### 3.4. Sistem Bookmark Hirarkis (Node Tree up to 3 Levels)
Struktur Bookmark fleksibel dinamis hingga 3 tingkat kedalaman:
* **Kedalaman 1:** Kategori Utama (Contoh: *Doa-Doa Pilihan*, *Hukum Fiqh*).
* **Kedalaman 2:** Sub-Kategori / Kategori Anak (Contoh: *Doa Para Nabi*, *Hukum Jual Beli*).
* **Kedalaman 3:** Ayat Terkait (Detail Ayat Al-Qur'an).

*Catatan:* Struktur tidak wajib selalu 3 tingkat. Bisa tersimpan pada kedalaman 1 tingkat (Kategori -> Ayat) atau 2 tingkat sesuai kebutuhan pengguna.

#### Akses Bookmark:
1. **Via Halaman Bookmark:** Pengguna dapat membuat/mengedit/menghapus hirarki folder/kategori terlebih dahulu.
2. **Via Long Press di Mushaf:** Menampilkan menu kontekstual **"Tambah ke Bookmark"**, lalu menampilkan *bottom sheet/pop-up* pemilih kategori tempat ayat tersebut akan dimasukkan.

### 3.5. Notifikasi Pengingat Harian (Hourly Reminder)
* **Sistem Notifikasi Lokal:** Mengecek status log bacaan hari ini.
* **Kondisi:** Jika hingga jam berjalan pengguna **belum** mencatat log bacaan pada hari tersebut, sistem akan memicu notifikasi pengingat setiap 1 jam sekali (misal: "Yuk sempatkan membaca Al-Qur'an hari ini!").
* **Stop Trigger:** Begitu pengguna mencatat log bacaan hari ini (via *long press* atau manual), notifikasi berkala untuk hari bersangkutan akan dihentikan otomatis hingga berganti hari berikutnya.

---

## 4. Struktur Arsitektur Data (Database Schema)

```sql
-- Tabel Log Bacaan Harian
CREATE TABLE daily_logs (
    date TEXT PRIMARY KEY, -- Format: YYYY-MM-DD
    surah_id INTEGER NOT NULL,
    ayah_id INTEGER NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabel Kategori Bookmark (Node Tree)
CREATE TABLE bookmark_nodes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id INTEGER NULL, -- NULL jika Kategori Utama (Depth 1)
    name TEXT NOT NULL,
    depth INTEGER NOT NULL CHECK (depth IN (1, 2)),
    FOREIGN KEY (parent_id) REFERENCES bookmark_nodes(id) ON DELETE CASCADE
);

-- Tabel Bookmark Ayat (Depth 2 atau 3)
CREATE TABLE bookmark_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    node_id INTEGER NOT NULL, -- Merujuk ke bookmark_nodes
    surah_id INTEGER NOT NULL,
    ayah_id INTEGER NOT NULL,
    page_number INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (node_id) REFERENCES bookmark_nodes(id) ON DELETE CASCADE
);
```

---

## 5. Instruksi Konfigurasi Build & Perizinan (Untuk Agent AI & Pengembang)

Instruksi ini digunakan oleh Agent AI / Developer saat melakukan konfigurasi lingkungan build Flutter untuk menghasilkan APK Android & pengujian di Linux Desktop.

### 5.1. Perizinan Android (`AndroidManifest.xml`)
Buka file `android/app/src/main/AndroidManifest.xml` dan tambahkan izin-izin berikut di luar tag `<application>`:

```xml
<!-- Akses Internet untuk mengunduh aset Font QCF / Tajwid jika belum ada -->
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

<!-- Perizinan Notifikasi Pengingat Per Jam (Android 13+ / API 33+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Perizinan Alarm Presisi untuk Penjadwalan Notifikasi Per Jam -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

### 5.2. Konfigurasi Signing Key Android (Release Build)

1. **Perintah Generate Keystore (JSR/PKCS12):**
   Jalankan perintah berikut pada terminal Linux untuk membuat file `key.jks`:

   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
           -keysize 2048 -validity 10000 -alias key \
           -dname "CN=Mitra Solusi, OU=Development, O=Mitra Solusi, L=Jakarta, ST=Jakarta, C=ID"
   ```

2. **File Konfigurasi Key (`android/key.properties`):**
   Buat file `android/key.properties` dengan isi:

   ```properties
   storePassword=<PASSWORD_KEYSTORE_ANDA>
   keyPassword=<PASSWORD_KEY_ANDA>
   keyAlias=key
   storeFile=/home/<USERNAME>/upload-keystore.jks
   ```

3. **Integrasi ke `android/app/build.gradle`:**
   Sesuaikan bagian `defaultConfig` dan `buildTypes` pada `build.gradle`:

   ```groovy
   def localProperties = new Properties()
   def localPropertiesFile = rootProject.file('local.properties')
   if (localPropertiesFile.exists()) {
       localPropertiesFile.withReader('UTF-8') { reader ->
           localProperties.load(reader)
       }
   }

   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }

   android {
       namespace "com.mitrasolusi.alquran"
       compileSdkVersion flutter.compileSdkVersion
       ndkVersion flutter.ndkVersion

       defaultConfig {
           applicationId "com.mitrasolusi.alquran"
           minSdkVersion 21
           targetSdkVersion flutter.targetSdkVersion
           versionCode flutterVersionCode.toInteger()
           versionName flutterVersionName
       }

       signingConfigs {
           release {
               if (keystorePropertiesFile.exists()) {
                   keyAlias keystoreProperties['keyAlias']
                   keyPassword keystoreProperties['keyPassword']
                   storeFile file(keystoreProperties['storeFile'])
                   storePassword keystoreProperties['storePassword']
               }
           }
       }

       buildTypes {
           release {
               signingConfig signingConfigs.release
               minifyEnabled true
               proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
           }
       }
   }
   ```

### 5.3. Perintah Emulasi & Build

* **Menjalankan Emulasi Desktop di Linux (Development & Testing):**
  ```bash
  flutter config --enable-linux-desktop
  flutter run -d linux
  ```

* **Build Output APK (Release Target):**
  ```bash
  flutter build apk --release
  ```
  *Output APK terletak di:* `build/app/outputs/flutter-apk/app-release.apk`

---

## 6. Kebutuhan Library / Package Flutter (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Quran & Font QCF
  qcf_quran_plus: ^latest_version
  
  # Page Curl Animation
  page_flip_builder: ^latest_version # atau page_turn / flutter_carousel_slider

  # Local Notifications & Alarm
  flutter_local_notifications: ^latest_version
  android_alarm_manager_plus: ^latest_version
  timezone: ^latest_version

  # Local Storage & State Management
  sqflite: ^latest_version
  path: ^latest_version
  provider: ^latest_version # atau flutter_bloc / riverpod

  # Network & Download Manager
  dio: ^latest_version
  path_provider: ^latest_version

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^latest_version
```

---

## 7. Rencana Desain Antarmuka (UX Flow)

```
[ Splash Screen / Download Check Asset ]
                  │
                  ▼
          [ Main Quran Reader Screen (15 Baris / Page Flip) ]
          ├── Header: Selector Surah, Juz, Halaman, Toggle Tajwid, Opsi 1/2 Halaman
          ├── Body: Quran Pages (Page Curl Animation)
          │     └── On Long Press Ayat:
          │           ├── Menu 1: Tandai Akhir Bacaan Hari Ini (Log)
          │           └── Menu 2: Tambahkan ke Bookmark (Tree Picker)
          │
          ├── Tab / Navigation Drawer:
          │     ├── [ Log & Monitoring Khatam ]
          │     │     ├── Status Baca Harian (Manual Entry / Validasi Ayat)
          │     │     └── Statistik Durasi & Total Khatam
          │     │
          │     └── [ Bookmark Tree Manager ]
          │           ├── Depth 1: Kategori Utama
          │           ├── Depth 2: Sub-Kategori
          │           └── Depth 3: List Ayat Terkait (Jump to Page)
```