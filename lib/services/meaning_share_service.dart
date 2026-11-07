import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/verse_note.dart';
import '../models/word_meaning.dart';
import 'database_service.dart';

class MeaningImportResult {
  const MeaningImportResult({
    required this.wordMeanings,
    required this.notes,
    required this.skippedNotes,
  });

  final int wordMeanings;
  final int notes;
  final int skippedNotes;
}

/// Layanan ekspor/impor catatan makna gandul dalam format JSON.
class MeaningShareService {
  MeaningShareService._();

  static final MeaningShareService instance = MeaningShareService._();

  static const int schemaVersion = 1;

  Future<String> buildExportJson({int? surah, int? ayah}) async {
    final List<WordMeaning> meanings = surah == null
        ? await DatabaseService.instance.getAllWordMeanings()
        : ayah == null
        ? await DatabaseService.instance.getWordMeaningsForSurah(surah)
        : await DatabaseService.instance.getWordMeanings(
            surah: surah,
            ayah: ayah,
          );

    final List<VerseNote> notes = surah == null
        ? await DatabaseService.instance.getAllVerseNotes()
        : ayah == null
        ? await DatabaseService.instance.getVerseNotesForSurah(surah)
        : await DatabaseService.instance.getVerseNotes(
            surah: surah,
            ayah: ayah,
          );

    final Map<String, dynamic> payload = <String, dynamic>{
      'schema_version': schemaVersion,
      'app': 'quran2',
      'exported_at': DateTime.now().toIso8601String(),
      'scope': <String, dynamic>{'surah': surah, 'ayah': ayah},
      'word_meanings': meanings
          .map((WordMeaning meaning) => meaning.toExportMap())
          .toList(),
      'verse_notes': notes.map((VerseNote note) => note.toExportMap()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<ShareResult> shareExport({
    int? surah,
    int? ayah,
    Rect? sharePositionOrigin,
    String? subject,
  }) async {
    final String json = await buildExportJson(surah: surah, ayah: ayah);
    final Directory directory = await getTemporaryDirectory();
    final String timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final File file = File('${directory.path}/makna_gandul_$timestamp.json');
    await file.writeAsString(json, flush: true);

    return SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'application/json')],
        subject: subject ?? 'Cadangan Makna Gandul',
        text: 'Cadangan makna gandul dan catatan ayat.',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<MeaningImportResult?> pickAndImport() async {
    final PlatformFile? picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    if (picked == null) {
      return null;
    }

    final String content;
    try {
      content = utf8.decode(await picked.readAsBytes());
    } catch (_) {
      throw const FormatException('Berkas JSON tidak dapat dibaca.');
    }

    return importFromJson(content);
  }

  Future<MeaningImportResult> importFromJson(String content) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      throw const FormatException('Berkas bukan JSON yang valid.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Struktur berkas JSON tidak dikenali.');
    }

    final Object? versionValue = decoded['schema_version'];
    final int version = versionValue is num
        ? versionValue.toInt()
        : (decoded['schemaVersion'] is num
              ? (decoded['schemaVersion'] as num).toInt()
              : -1);
    if (version < 1 || version > schemaVersion) {
      throw FormatException(
        'Versi skema ($version) tidak didukung. Versi aplikasi ini: '
        '$schemaVersion.',
      );
    }

    final Object? meaningsValue =
        decoded['word_meanings'] ?? decoded['wordMeanings'];
    final Object? notesValue = decoded['verse_notes'] ?? decoded['verseNotes'];
    if (meaningsValue != null && meaningsValue is! List) {
      throw const FormatException('Bagian word_meanings harus berupa daftar.');
    }
    if (notesValue != null && notesValue is! List) {
      throw const FormatException('Bagian verse_notes harus berupa daftar.');
    }

    int importedMeanings = 0;
    int importedNotes = 0;
    int skippedNotes = 0;

    for (final Object? item in (meaningsValue as List?) ?? const <Object?>[]) {
      if (item is! Map) {
        continue;
      }
      final WordMeaning? meaning = _parseMeaning(item);
      if (meaning == null) {
        continue;
      }
      await DatabaseService.instance.importWordMeaning(meaning);
      importedMeanings++;
    }

    for (final Object? item in (notesValue as List?) ?? const <Object?>[]) {
      if (item is! Map) {
        continue;
      }
      final VerseNote? note = _parseNote(item);
      if (note == null) {
        continue;
      }
      final bool inserted = await DatabaseService.instance.importVerseNote(
        note,
      );
      if (inserted) {
        importedNotes++;
      } else {
        skippedNotes++;
      }
    }

    return MeaningImportResult(
      wordMeanings: importedMeanings,
      notes: importedNotes,
      skippedNotes: skippedNotes,
    );
  }

  WordMeaning? _parseMeaning(Map<dynamic, dynamic> map) {
    final Map<String, dynamic> json = map.map<String, dynamic>(
      (dynamic key, dynamic value) => MapEntry<String, dynamic>('$key', value),
    );
    final int? surah = _asInt(json['surah']);
    final int? ayah = _asInt(json['ayah']);
    final int? wordIndex = _asInt(json['word_index'] ?? json['wordIndex']);
    if (surah == null || ayah == null || wordIndex == null) {
      return null;
    }
    return WordMeaning(
      surah: surah,
      ayah: ayah,
      wordIndex: wordIndex,
      groupId: (json['group_id'] ?? json['groupId']) as String?,
      wordsJoined: (json['words_joined'] ?? json['wordsJoined']) as String?,
      meaningPegon: (json['meaning_pegon'] ?? json['meaningPegon']) as String?,
      meaningLatin: (json['meaning_latin'] ?? json['meaningLatin']) as String?,
      sourceType:
          ((json['source_type'] ?? json['sourceType']) as String?) ?? 'user',
      createdAt: _asDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _asDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  VerseNote? _parseNote(Map<dynamic, dynamic> map) {
    final Map<String, dynamic> json = map.map<String, dynamic>(
      (dynamic key, dynamic value) => MapEntry<String, dynamic>('$key', value),
    );
    final int? surah = _asInt(json['surah']);
    final int? ayah = _asInt(json['ayah']);
    if (surah == null || ayah == null) {
      return null;
    }
    return VerseNote(
      surah: surah,
      ayah: ayah,
      noteType: VerseNoteType.fromValue(
        (json['note_type'] ?? json['noteType']) as String?,
      ),
      contentPegon: (json['content_pegon'] ?? json['contentPegon']) as String?,
      contentLatin: (json['content_latin'] ?? json['contentLatin']) as String?,
      reference: json['reference'] as String?,
      createdAt: _asDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _asDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  int? _asInt(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  DateTime? _asDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
