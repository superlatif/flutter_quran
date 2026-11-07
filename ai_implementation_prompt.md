# Prompt Instruksi AI: Implementasi Fitur Makna Gandul Pegon–Latin & Berbagi Catatan

> **Petunjuk Penggunaan:** Salin seluruh isi dokumen ini dan berikan kepada model AI (LLM) untuk meminta implementasi fitur Flutter sesuai spesifikasi teknis di bawah ini.

---

## 🎯 Peran & Tugas AI
Anda adalah seorang **Senior Flutter Developer** dan **Database Engineer**. Tugas Anda adalah mengimplementasikan fitur **Makna Gandul Pegon–Latin & Berbagi Catatan** pada aplikasi Flutter yang sudah berjalan.

---

## 🛠️ Lingkungan Pengkodingan (Tech Stack)
* **Framework:** Flutter (Dart)
* **Quran Package:** `qcf_quran_plus: ^0.1.1`
* **Local Database:** SQLite via `sqflite`
* **Preferences:** `shared_preferences`
* **File Handling & Sharing:** `share_plus`, `file_picker`, `path_provider` (atau paket standar terkait)

---

## 📌 PRINSIP UTAMA & BATASAN (NON-NEGOTIABLE)
1. **Mushaf Integrity:** DILARANG MERUBAH atau MENGANGGU teks Arab Al-Qur'an dan rendering dari `qcf_quran_plus`.
2. **Backward Compatibility:** Struktur data dan fitur lama (penanda, pencarian, bacaan mushaf) TIDAK BOLEH RUSAK. Database lama diperluas (*migration strategy*), bukan dihapus.
3. **Clean Code:** Pisahkan logika menjadi arsitektur yang rapi (Model, Service/Repository, State Management/Controller, UI Components).
4. perubahan hanya berkaitan dengan fitur mode terjemah, tidak merubah fitur lain

---

## 📄 SPESIFIKASI SPESIFIK & PERSYARATAN FITUR

### 1. Database & Migrasi (SQLite / sqflite)

Buat script migrasi SQLite untuk mendukung 2 tabel utama berikut:

```sql
-- 1. Tabel Makna Per Kata (Mendukung Makna Satuan & Gabungan)
CREATE TABLE IF NOT EXISTS user_word_meanings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  surah INTEGER NOT NULL,
  ayah INTEGER NOT NULL,
  word_index INTEGER NOT NULL,
  group_id TEXT,                     -- UUID / unique ID jika kata tergabung dalam grup
  words_joined TEXT,                 -- String indeks kata yang digabung (contoh: "3,4")
  meaning_pegon TEXT,
  meaning_latin TEXT,
  source_type TEXT NOT NULL DEFAULT 'user', -- 'base' = bawaan, 'user' = buatan pengguna
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT
);

-- 2. Tabel Catatan Per Ayat
CREATE TABLE IF NOT EXISTS user_verse_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  surah INTEGER NOT NULL,
  ayah INTEGER NOT NULL,
  note_type TEXT NOT NULL CHECK(note_type IN ('explanation', 'hadis', 'general')),
  content_pegon TEXT,
  content_latin TEXT,
  reference TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT
);
```

### 2. Pengaturan Pengguna (SharedPreferences)
Kelola *state* pengaturan dengan *key-value* berikut:

| Key | Type | Possible Values | Default | Keterangan |
| :--- | :--- | :--- | :--- | :--- |
| `display_script` | String | `'pegon'`, `'latin'`, `'both'` | `'both'` | Mode tampilan makna |
| `input_mode` | String | `'auto'`, `'pegon'`, `'latin'` | `'auto'` | Mode keyboard saat edit |
| `show_base_meaning`| bool | `true`, `false` | `true` | Tampilkan makna bawaan jika ada |
| `meaning_style` | String | `'block'`, `'indented'`, `'italic_45'` | `'block'` | Gaya tampilan makna gandul |

---

### 3. Tampilan & Layout Makna Gandul (UI Component)
Gaya penulisan makna di bawah kata Arab (`meaning_style`):

1. **`block` (Default):** Makna ditampilkan lurus tepat di bawah kata Arab secara vertikal, lebar terbungkus (*text wrap*).
2. **`indented`:** Makna ditampilkan dengan lekukan (*indent*) ke kanan di bawah kata.
3. **`italic_45`:**
   * Teks makna dimiringkan $\pm 45^\circ$ ke kanan/kiri (gaya khas Tafsir Al-Ibrīz).
   * Gunakan font size lebih kecil (11–12sp).
   * **Fallback Logic:** Jika panjang string makna > $N$ karakter (atau melebihi batas batas visual), otomatis beralih render ke mode `block` agar teks tidak terpotong.

---

### 4. Fitur Makna Gabungan (Mudhof + Mudhof Ilaih)

**Logika Bisnis:**
* Pengguna dapat memilih 2 atau lebih kata berurutan dalam 1 ayat yang sama lalu menekan tombol **"Gabungkan Makna"**.
* Sistem membuat satu `group_id` universal untuk kata-kata tersebut.
* Baris kata pertama menyimpan data utama (`words_joined` berisi contoh `"2,3"`).
* **Aturan Rendering:** Jika suatu kata memiliki `group_id`, render makna per kata individualnya DISEMBUNYIKAN. Sebagai gantinya, tampilkan 1 blok makna gabungan di bawah rentang kata-kata tersebut.
* **Fitur Un-group:** Menyediakan fungsi "Pisah Makna" untuk menghapus `group_id` dan mengembalikan makna ke individual per kata.

---

### 5. Input Mode & Virtual Keyboard Pegon

* **Mode Dynamic RTL/LTR:**
  * Teks Pegon: `TextDirection.rtl`
  * Teks Latin: `TextDirection.ltr`
* **Custom Pegon Keyboard Toolbar:**
  * Saat bidang input Pegon aktif, tampilkan baris tombol pintas (*quick-toolbar*) di atas keyboard bawaan HP.
  * Tombol berisi karakter-karakter khusus Pegon (contoh: ڠ, ۑ, ڨ, ڬ, ۏ, ڽ, ࢮ, dll.).
  * Mengetuk tombol tersebut akan menyisipkan karakter Pegon langsung ke posisi kursor `TextEditingController`.

---

### 6. Fitur Ekspor & Impor JSON (Share Notes)

* **Ekspor:**
  * Mengambil seluruh data dari `user_word_meanings` dan `user_verse_notes` (atau berdasarkan Surah/Ayat tertentu yang dipilih).
  * Mengonversi data ke format JSON terstruktur lengkap dengan *schema version*.
  * Menyediakan tombol **Share** menggunakan paket `share_plus` untuk dikirim via WhatsApp, Drive, dsb.
* **Impor:**
  * Mengunggah file `.json` cadangan.
  * Lakukan validasi skema JSON.
  * Opsi gabungkan (*Merge / Upsert*) ke database SQLite lokal tanpa merusak catatan buatan sendiri yang sudah ada.

---

## 🚀 TUGAS ANDA SEKARANG
1. Buat kode **Data Model** (Dart class) untuk `WordMeaning` dan `VerseNote`.
2. Buat **Database Helper / Repository** yang mencakup migrasi SQLite dan metode CRUD (termasuk logika *grouping* dan *upsert* data).
3. Buat **Settings Manager / Controller** menggunakan SharedPreferences.
4. Buat **UI Widgets**:
   * Layout renderer makna gandul (dengan penanganan 3 `meaning_style`).
   * Custom `PegonToolbar` untuk keyboard input.
   * Dialog / Screen untuk **Gabung Makna** dan **Ekspor-Impor**.