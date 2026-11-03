import '../models/ayah_translation.dart';
import 'database_service.dart';

class AyahTranslationService {
  AyahTranslationService._();

  static final AyahTranslationService instance = AyahTranslationService._();

  /// Memuat seluruh terjemahan milik [surahId] sebagai peta `ayahId -> teks`.
  Future<Map<int, String>> getTranslationsForSurah(int surahId) async {
    final List<AyahTranslation> translations = await DatabaseService.instance
        .getAyahTranslations(surahId: surahId);

    return <int, String>{
      for (final AyahTranslation translation in translations)
        translation.ayahId: translation.translation,
    };
  }

  Future<void> saveTranslation({
    required int surahId,
    required int ayahId,
    required String translation,
  }) {
    return DatabaseService.instance.upsertAyahTranslation(
      surahId: surahId,
      ayahId: ayahId,
      translation: translation,
    );
  }
}
