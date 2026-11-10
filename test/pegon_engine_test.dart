import 'package:flutter_test/flutter_test.dart';
import 'package:quran2/models/conversion_result.dart';
import 'package:quran2/services/pegon_engine.dart';
import 'package:quran2/services/pegon_stemmer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('huruf besar dan tanda baca ditangani', () {
      expect(engine.convertText('Bismillah.'), 'بِسْمِ اللَّه.');
    });

    test('teks kosong menghasilkan kosong', () {
      expect(engine.convertText('   '), '');
    });
  });
}
