import '../models/ayah_comment.dart';
import 'database_service.dart';

class AyahCommentService {
  AyahCommentService._();

  static final AyahCommentService instance = AyahCommentService._();

  Future<AyahComment?> getComment({required int surahId, required int ayahId}) {
    return DatabaseService.instance.getAyahComment(
      surahId: surahId,
      ayahId: ayahId,
    );
  }

  Future<void> saveComment({
    required int surahId,
    required int ayahId,
    required String comment,
  }) {
    return DatabaseService.instance.upsertAyahComment(
      surahId: surahId,
      ayahId: ayahId,
      comment: comment,
    );
  }
}
