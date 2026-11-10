# Spesifikasi Teknis & Panduan Pengembangan: Aplikasi Konverter Teks Indonesia-Pegon (Offline Flutter)

Dokumen ini berisi panduan teknis, spesifikasi arsitektur, dan aturan logika yang dirancang untuk AI model dalam membangun aplikasi **Konverter Teks Bahasa Indonesia ke Aksara Pegon** berbasis **Flutter** yang berjalan secara **offline**.

## 1. Visi & Tujuan Aplikasi

Membangun aplikasi mobile (Android/iOS) menggunakan Flutter yang mampu menerjemahkan teks Latin Bahasa Indonesia ke aksara Pegon dengan menerapkan dua pendekatan utama:

1. **Pengecualian Kata Baku Arab (Whitelist Dictionary):** Kata-kata yang berasal dari serapan bahasa Arab murni (seperti *musyawarah*, *kitab*, *syarat*, *ilmu*) ditulis menggunakan ejaan Arab/Pegon aslinya yang benar.

2. **Konversi Fonetis & Penanganan Imbuhan (Rule-Based & Stemming):** Kata-kata non-Arab serta kata berimbuhan (afiksasi) diproses menggunakan algoritma *stemming* ringan dan pemetaan fonetik karakter demi karakter ke aksara Pegon secara offline.

## 2. Arsitektur & Struktur Proyek (Flutter)

Aplikasi harus berjalan secara mandiri (*offline-first*) dengan memanfaatkan aset lokal untuk kamus pengecualian.

### Struktur Folder Rekomendasi:

```
lib/
│
├── models/
│   └── conversion_result.dart
│
├── services/
│   ├── exception_database.dart   # Mengelola file JSON kamus lokal
│   ├── pegon_stemmer.dart        # Algoritma kupas awalan/akhiran (afiksasi)
│   └── pegon_engine.dart         # Mesin utama transliterasi fonetis & gabungan
│
├── views/
│   └── home_screen.dart          # Antarmuka utama (Live Preview Input-Output)
│
└── main.dart

assets/
└── data/
    └── exceptions.json           # Database JSON kata baku Arab & pengecualian kustom

```

## 3. Spesifikasi Komponen Inti

### A. Database Pengecualian (`assets/data/exceptions.json`)

File JSON ini menyimpan daftar kata dasar pengecualian yang dipetakan langsung ke aksara Pegon dengan ejaan baku yang benar (menggunakan huruf yang tepat seperti *Syin* `ش` untuk kata serapan Arab yang sesuai).

```json
{
  "arabic_baku": {
    "musyawarah": "مُشَاوَرَة",
    "kitab": "كِتَاب",
    "syarat": "شَرْط",
    "ilmu": "عِلْم",
    "asma": "أَسْمَاء"
  },
  "custom_exceptions": {
    "allah": "اللَّه",
    "insyaallah": "إِنْ شَاءَ اللَّه"
  }
}
```

*Catatan: Daftarkan file ini di dalam `pubspec.yaml` pada bagian `flutter: assets:`.*

### B. Modul Stemming & Morfologi (`PegonStemmer`)

Sebelum dicocokkan dengan database, kata berimbuhan (misal: *bermusyawarah*, *dikitabkan*) harus diurai untuk menemukan kata dasarnya.

* **Awalan (Prefixes):** `ber`, `me`, `pe`, `di`, `ke`, `se`, `ter`, `per`

* **Akhiran (Suffixes):** `kan`, `an`, `i`, `nya`, `lah`, `kah`, `tah`

* **Logika:** Kupas akhiran dulu $\rightarrow$ cek database $\rightarrow$ kupas awalan $\rightarrow$ cek database $\rightarrow$ jika ditemukan, rekonstruksi hasil akhir dengan menggabungkan hasil konversi awalan/akhiran fonetis dan kata dasar Arab aslinya.

### C. Modul Transliterasi Fonetis (`PegonEngine`)

Untuk kata-kata biasa (non-Arab), gunakan pemetaan karakter fonetis standar Nusantara-Pegon:

* `b` $\rightarrow$ ب

* `p` $\rightarrow$ ڤ

* `t` $\rightarrow$ ت

* `j` $\rightarrow$ ج

* `ch` / `kh` $\rightarrow$ خ

* `d` $\rightarrow$ د

* `r` $\rightarrow$ ر

* `s` $\rightarrow$ س

* `sy` $\rightarrow$ ش

* `ng` $\rightarrow$ ڠ

* `ny` $\rightarrow$ ڽ

* `k` $\rightarrow$ ك

* `h` $\rightarrow$ ه

* `l` $\rightarrow$ ل

* `m` $\rightarrow$ م

* `n` $\rightarrow$ ن

* `w` $\rightarrow$ و

* `y` $\rightarrow$ ي

* `a, i, u, e, o` $\rightarrow$ Diatur berdasarkan posisi (awal, tengah, akhir) atau disesuaikan dengan kaidah Pegon gundul standar.

## 4. Panduan Implementasi Antarmuka (UI) untuk AI

AI yang mengimplementasikan kode harus membuat halaman utama (`HomeScreen`) dengan kriteria berikut:

1. **StatefulWidget** yang mendengarkan input teks secara *real-time* (`TextField` dengan `onChanged`).

2. Menampilkan tombol **Salin (Copy to Clipboard)** untuk hasil konversi teks Pegon.

3. Menampilkan indikator status pemuatan kamus (*Loading asset...* / *Ready*).

4. Desain responsif, bersih, menggunakan komponen Material Design 3.

## 5. Contoh Skenario Uji (Test Cases)

AI harus memastikan kode lulus skenario uji berikut:

* **Input:** `"musyawarah"` $\rightarrow$ **Output:** `مُشَاوَرَة` (Mengambil langsung dari kamus Arab dengan ejaan huruf *Syin* yang benar).

* **Input:** `"bermusyawarah"` $\rightarrow$ **Output:** `بَرْمُشَاوَرَة` (Awalan diterjemahkan fonetis, kata dasar diambil dari kamus Arab).

* **Input:** `"kepada bapak ibu"` $\rightarrow$ **Output:** `كفادا بافاك ايبو` (Diterjemahkan secara fonetis karena tidak ada di kamus Arab).