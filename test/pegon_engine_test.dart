import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran2/models/conversion_result.dart';
import 'package:quran2/services/pegon_correction_service.dart';
import 'package:quran2/services/pegon_engine.dart';
import 'package:quran2/services/pegon_spelling_settings_service.dart';
import 'package:quran2/services/pegon_stemmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  late PegonEngine engine;

  setUpAll(() async {
    engine = PegonEngine.instance;
    await engine.load();
  });

  group('Skenario uji spesifikasi pegon_converter_app_specification.md', () {
    test('kata baku Arab diambil dari kamus pengecualian', () {
      final ConversionResult result = engine.convertWord('musyawarah');

      expect(result.output, 'مُشَاوَرَة');
      expect(result.source, ConversionSource.dictionary);
    });

    test("jamaah memakai 'ain (ع) dan ta marbutah (ة) dari kamus", () {
      for (final String word in <String>[
        "jama'ah",
        "jamaa'ah",
        'jamaah',
        'jama’ah',
        'jamaa’ah',
      ]) {
        final ConversionResult result = engine.convertWord(word);
        expect(result.output, 'جماعة', reason: word);
        expect(result.source, ConversionSource.dictionary, reason: word);
      }
      expect(engine.convertText('berjamaah di masjid'), 'بَرْجماعة دي مَسْجِد');
    });

    test('kata berimbuhan: awalan fonetis + kata dasar kamus', () {
      final ConversionResult result = engine.convertWord('bermusyawarah');

      // Awalan `ber` diterjemahkan fonetis berharakat, kata dasar
      // diambil dari kamus Arab.
      expect(result.output, 'بَرْمُشَاوَرَة');
      expect(result.source, ConversionSource.dictionaryWithAffix);
    });

    test('kalimat biasa diterjemahkan fonetis', () {
      // `p` dipetakan ke ڤ sesuai tabel aturan transliterasi fonetis
      // pada spesifikasi (contoh pada dokumen memakai ف).
      expect(engine.convertText('kepada bapak ibu'), 'كڤادا باڤاك ايبو');
    });
  });

  group('PegonStemmer', () {
    test('mengupas awalan dan akhiran', () {
      final StemResult result = PegonStemmer.instance.stem('dikitabkan');

      expect(result.root, 'kitab');
      expect(result.prefixes, <String>['di']);
      expect(result.suffixes, <String>['kan']);
    });

    test('kata pendek dikembalikan apa adanya', () {
      final StemResult result = PegonStemmer.instance.stem('ibu');

      expect(result.root, 'ibu');
      expect(result.hasAffix, isFalse);
    });
  });

  group('PegonEngine fonetis', () {
    test('vokal kembar dirapatkan', () {
      expect(engine.convertText('maaf'), 'ماف');
    });

    test('vokal di awal kata memakai alif pembawa', () {
      expect(engine.convertText('air'), 'اير');
    });

    test('e taling diperlakukan seperti i', () {
      expect(engine.phoneticConvert('enak'), 'ايناك');
      expect(engine.phoneticConvert('ejek'), 'ايجيك');
      expect(engine.phoneticConvert('daerah'), 'دايراه');
      expect(engine.phoneticConvert('faedah'), 'فايداه');
      expect(engine.convertText('sepak bola'), 'سيڤاك بلا');

      final ConversionResult result = engine.convertWord('nasehat');
      expect(result.output, 'نَصِيحَة');
      expect(result.source, ConversionSource.dictionary);
    });

    test('e pepet memakai kaidah lama', () {
      expect(engine.phoneticConvert('pegawai'), 'ڤڬاواي');
      expect(engine.phoneticConvert('emas'), 'اېماس');
      expect(engine.phoneticConvert('eram'), 'اېرام');
      expect(engine.phoneticConvert('enau'), 'اېناو');
      expect(engine.phoneticConvert('petugas'), 'ڤتوڬاس');
      expect(engine.phoneticConvert('pelamar'), 'ڤلامار');
      expect(engine.phoneticConvert('pelaku'), 'ڤلاكو');
      expect(engine.phoneticConvert('elang'), 'اېلاڠ');
      expect(engine.phoneticConvert('kereta'), 'كريتا');
      expect(engine.phoneticConvert('semasa'), 'سماسا');
      expect(engine.phoneticConvert('sejaman'), 'سجامان');
      expect(engine.phoneticConvert('sesuai'), 'سسواي');
    });

    test('kamus tetap memakai ejaan persis sebelum normalisasi e taling', () {
      final ConversionResult result = engine.convertWord('sebab');
      expect(result.output, 'سَبَب');
      expect(result.source, ConversionSource.dictionary);
    });

    test('huruf besar dan tanda baca ditangani', () {
      expect(engine.convertText('Bismillah.'), 'بِسْمِ اللَّه.');
    });

    test('teks kosong menghasilkan kosong', () {
      expect(engine.convertText('   '), '');
    });
  });

  group('Koreksi pengguna', () {
    test('koreksi mengalahkan kamus dan fonetis', () async {
      await engine.addUserCorrection('sejarah', 'سِيَرَة');

      final ConversionResult result = engine.convertWord('sejarah');
      expect(result.output, 'سِيَرَة');
      expect(result.source, ConversionSource.userCorrection);
      expect(engine.convertText('sejarah'), 'سِيَرَة');

      await engine.removeUserCorrection('sejarah');
      expect(engine.convertWord('sejarah').source, ConversionSource.phonetic);
    });

    test('varian apostrof koreksi sama dan tersimpan lokal', () async {
      await engine.addUserCorrection('ka’bah', 'كَعْبَة');

      expect(engine.convertWord("ka'bah").output, 'كَعْبَة');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString(PegonCorrectionService.storageKey)!),
        containsPair("ka'bah", 'كَعْبَة'),
      );

      await engine.removeUserCorrection("ka'bah");
    });

    test('koreksi akar kata ikut dipakai saat rekonstruksi imbuhan', () async {
      await engine.addUserCorrection('jamaah', 'جَمَاعَة');

      expect(engine.convertWord('berjamaah').output, 'بَرْجَمَاعَة');

      await engine.removeUserCorrection('jamaah');
      expect(engine.convertWord('berjamaah').output, 'بَرْجماعة');
    });
  });

  group('Varian ejaan Pegon pilihan pengguna', () {
    final PegonSpellingSettingsService settings =
        PegonSpellingSettingsService.instance;

    setUp(() async {
      await settings.setGSpelling(PegonGSpelling.kafDotAbove);
      await settings.setPSpelling(PegonPSpelling.veh);
    });

    tearDown(() async {
      await settings.setGSpelling(PegonGSpelling.kafDotAbove);
      await settings.setPSpelling(PegonPSpelling.veh);
    });

    test('ejaan bawaan tidak berubah', () {
      expect(engine.phoneticConvert('pegawai'), 'ڤڬاواي');
      expect(engine.convertText('kepada bapak ibu'), 'كڤادا باڤاك ايبو');
    });

    test('g bisa memakai kaf titik 3 bawah atau kaf titik 1 bawah', () async {
      await settings.setGSpelling(PegonGSpelling.kafThreeDotsBelow);
      expect(engine.phoneticConvert('pegawai'), 'ڤڮاواي');

      await settings.setGSpelling(PegonGSpelling.kafDotBelow);
      expect(engine.phoneticConvert('pegawai'), 'ڤࢴاواي');

      await settings.setGSpelling(PegonGSpelling.kehehDotAbove);
      expect(engine.phoneticConvert('pegawai'), 'ڤݢاواي');
    });

    test('p dan v mengikuti varian fa yang dipilih', () async {
      await settings.setPSpelling(PegonPSpelling.feh);
      expect(engine.phoneticConvert('pegawai'), 'فڬاواي');
      expect(engine.phoneticConvert('v'), 'ف');

      await settings.setPSpelling(PegonPSpelling.fehDotBelow);
      expect(engine.phoneticConvert('pegawai'), 'ڣڬاواي');
      expect(engine.phoneticConvert('v'), 'ڣ');

      await settings.setPSpelling(PegonPSpelling.fehDotMovedBelow);
      expect(engine.phoneticConvert('bapak'), 'باڢاك');
    });

    test('kamus dan koreksi pengguna tidak terpengaruh varian', () async {
      await settings.setGSpelling(PegonGSpelling.kafDotBelow);
      await settings.setPSpelling(PegonPSpelling.feh);

      expect(engine.convertWord('musyawarah').output, 'مُشَاوَرَة');
      expect(engine.convertWord('fakir').output, 'فَقِير');

      await engine.addUserCorrection('pegawai', 'ڤڬاواي');
      expect(engine.convertWord('pegawai').output, 'ڤڬاواي');
      await engine.removeUserCorrection('pegawai');
    });

    test('pilihan ejaan tersimpan di penyimpanan lokal', () async {
      await settings.setGSpelling(PegonGSpelling.kafThreeDotsBelow);
      await settings.setPSpelling(PegonPSpelling.fehDotBelow);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(PegonSpellingSettingsService.gSpellingKey),
        'kaf_three_dots_below',
      );
      expect(
        prefs.getString(PegonSpellingSettingsService.pSpellingKey),
        'feh_dot_below',
      );
    });
  });
}
