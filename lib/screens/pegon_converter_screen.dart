import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/conversion_result.dart';
import '../services/pegon_engine.dart';
import '../services/pegon_spelling_settings_service.dart';
import '../services/speech_input_service.dart';
import '../widgets/pegon_spelling_settings.dart';

/// Halaman konverter teks Bahasa Indonesia ke aksara Pegon.
///
/// Hasil konversi bisa disalin (copy) lalu ditempelkan pada kolom
/// "Makna Pegon" / catatan ayat di mode terjemah (Makna Gandul).
class PegonConverterScreen extends StatefulWidget {
  const PegonConverterScreen({super.key});

  @override
  State<PegonConverterScreen> createState() => _PegonConverterScreenState();
}

class _PegonConverterScreenState extends State<PegonConverterScreen> {
  final TextEditingController _inputController = TextEditingController();
  final PegonEngine _engine = PegonEngine.instance;
  final SpeechInputService _speech = SpeechInputService.instance;
  final PegonSpellingSettingsService _spelling =
      PegonSpellingSettingsService.instance;

  bool _isEngineReady = false;
  bool _isListening = false;
  bool _isStartingVoiceInput = false;
  bool _isFinalizingVoiceInput = false;
  String _voiceInputBase = '';
  String _output = '';

  static const String _correctionInputKey = 'pegon-correction-input';
  static const String _correctionSaveKey = 'pegon-correction-save';

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_convert);
    _spelling.addListener(_handleSpellingChanged);
    unawaited(_loadEngine());
  }

  /// Ejaan yang dipilih pengguna langsung dipakai mesin konversi, jadi
  /// tampilan perlu disegarkan saat pengaturan berubah.
  void _handleSpellingChanged() {
    if (mounted) {
      _convert();
    }
  }

  Future<void> _showSpellingSettings() async {
    await showPegonSpellingSettingsDialog(context: context);
    if (mounted) {
      _convert();
    }
  }

  Future<void> _loadEngine() async {
    await _engine.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _isEngineReady = true;
    });
    _convert();
  }

  void _convert() {
    final String text = _inputController.text;
    setState(() {
      _output = _engine.convertText(text);
    });
  }

  @override
  void dispose() {
    if (_speech.isListening || _isListening || _isFinalizingVoiceInput) {
      unawaited(_cancelSpeech());
    }
    _inputController.removeListener(_convert);
    _spelling.removeListener(_handleSpellingChanged);
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _cancelSpeech() async {
    try {
      await _speech.cancel();
    } on PlatformException catch (error) {
      debugPrint('Gagal menghentikan input suara: $error');
    }
  }

  Future<void> _copyOutput() async {
    if (_output.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _output));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Teks Pegon tersalin. Tempelkan pada kolom makna/catatan '
          'di mode terjemah.',
        ),
      ),
    );
  }

  void _clear() {
    _inputController.clear();
  }

  Future<String> _indonesianLocaleId() async {
    for (final locale in await _speech.locales()) {
      final String localeId = locale.localeId.toLowerCase().replaceAll(
        '_',
        '-',
      );
      if (localeId == 'id' || localeId.startsWith('id-')) {
        return locale.localeId;
      }
    }
    return 'id_ID';
  }

  Future<void> _toggleVoiceInput() async {
    if (_isStartingVoiceInput || _isFinalizingVoiceInput) {
      return;
    }

    if (_isListening || _speech.isListening) {
      try {
        await _speech.stop();
      } on PlatformException catch (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _isFinalizingVoiceInput = false;
          });
        }
        _showVoiceMessage('Gagal menghentikan input suara: $error');
      }
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isStartingVoiceInput = true;
      _isFinalizingVoiceInput = false;
    });

    try {
      final bool available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
      );
      if (!available) {
        _showVoiceMessage(
          'Pengenalan suara tidak tersedia. Periksa izin mikrofon dan '
          'layanan pengenalan suara Android.',
        );
        return;
      }

      if (!mounted) {
        return;
      }
      final String localeId = await _indonesianLocaleId();
      if (!mounted) {
        return;
      }

      _voiceInputBase = _inputController.text;
      await _speech.listen(onResult: _handleSpeechResult, localeId: localeId);
      if (!mounted) {
        await _cancelSpeech();
        return;
      }
      setState(() {
        _isListening = true;
      });
    } on ListenFailedException catch (error) {
      _showVoiceMessage(
        'Gagal memulai pengenalan suara: '
        '${error.message ?? error.details ?? 'layanan tidak merespons'}',
      );
    } on PlatformException catch (error) {
      _showVoiceMessage('Gagal mengakses pengenalan suara: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isStartingVoiceInput = false;
        });
      }
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isListening = status == 'listening';
      if (status == 'notListening') {
        _isFinalizingVoiceInput = true;
      } else if (status == 'done') {
        _isFinalizingVoiceInput = false;
        _isStartingVoiceInput = false;
      } else if (_isListening) {
        _isFinalizingVoiceInput = false;
        _isStartingVoiceInput = false;
      }
    });
  }

  void _handleSpeechError(String error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isListening = false;
      _isStartingVoiceInput = false;
      _isFinalizingVoiceInput = false;
    });

    final String message = switch (error) {
      'error_permission' => 'Izin mikrofon diperlukan untuk input suara.',
      'error_no_match' => 'Ucapan tidak dikenali. Silakan coba lagi.',
      'error_language_not_supported' || 'error_language_unavailable' =>
        'Bahasa Indonesia tidak didukung atau belum diunduh di perangkat.',
      _ => 'Pengenalan suara gagal: $error',
    };
    _showVoiceMessage(message);
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (!mounted || result.recognizedWords.trim().isEmpty) {
      return;
    }

    final bool needsSeparator =
        _voiceInputBase.isNotEmpty && !RegExp(r'\s$').hasMatch(_voiceInputBase);
    final String text =
        '$_voiceInputBase${needsSeparator ? ' ' : ''}'
        '${result.recognizedWords.trim()}';
    _inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    if (result.finalResult && mounted) {
      setState(() {
        _isListening = false;
        _isStartingVoiceInput = false;
        _isFinalizingVoiceInput = false;
      });
    }
  }

  void _showVoiceMessage(String message) => _showMessage(message);

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Menampilkan dialog koreksi untuk satu kata hasil konversi.
  Future<void> _showCorrectionDialog(String word) async {
    final ConversionResult result = _engine.convertWord(word);
    final _CorrectionResult? action = await showDialog<_CorrectionResult>(
      context: context,
      builder: (BuildContext context) =>
          _CorrectionDialog(word: word, result: result),
    );

    if (action == null) {
      return;
    }
    try {
      if (action.kind == _CorrectionKind.remove) {
        await _engine.removeUserCorrection(word);
        _showMessage('Koreksi dihapus.');
      } else {
        await _engine.addUserCorrection(word, action.value);
        _showMessage('Koreksi tersimpan untuk "$word".');
      }
    } catch (error) {
      _showMessage('Gagal menyimpan koreksi: $error');
      return;
    }
    if (mounted) {
      _convert();
    }
  }

  Future<void> _deleteCorrection(String word) async {
    try {
      await _engine.removeUserCorrection(word);
      _showMessage('Koreksi dihapus.');
      _convert();
    } catch (error) {
      _showMessage('Gagal menghapus koreksi: $error');
    }
  }

  List<Widget> _buildWordBreakdown() {
    final List<Widget> chips = <Widget>[];

    for (final RegExpMatch match in PegonEngine.wordPattern.allMatches(
      _inputController.text,
    )) {
      final String word = match.group(0)!;
      final ConversionResult result = _engine.convertWord(word);
      chips.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InputChip(
              label: Text(
                '${result.input} → ${result.output}',
                textDirection: TextDirection.rtl,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result.output));
                _showMessage(
                  '${result.output} (${result.source.label}) tersalin',
                );
              },
            ),
            IconButton(
              key: ValueKey<String>('pegon-fix-$word'),
              tooltip: 'Perbaiki konversi',
              icon: const Icon(Icons.edit_outlined, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => _showCorrectionDialog(word),
            ),
          ],
        ),
      );
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pegon'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('pegon-spelling-settings'),
            tooltip: 'Pengaturan ejaan Pegon',
            icon: const Icon(Icons.tune),
            onPressed: _showSpellingSettings,
          ),
        ],
      ),
      body: !_isEngineReady
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat kamus...'),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.swap_horiz,
                                  color: colors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Indonesia → Pegon',
                                  style: theme.textTheme.labelLarge,
                                ),
                                const Spacer(),
                                Text(
                                  'Kamus: ${_engine.dictionaryEntryCount} · '
                                  'Koreksi: ${_engine.userCorrections.length}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tulis teks Bahasa Indonesia, hasil konversi '
                              'Pegon muncul langsung di bawah dan bisa '
                              'disalin ke kolom makna atau catatan pada '
                              'mode terjemah. Varian ejaan (kaf/fa) bisa '
                              'diubah lewat ikon pengaturan di kanan atas.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey<String>('pegon-input'),
                      controller: _inputController,
                      readOnly:
                          _isListening ||
                          _isStartingVoiceInput ||
                          _isFinalizingVoiceInput,
                      maxLines: 5,
                      minLines: 3,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Teks Indonesia',
                        hintText: 'Contoh: kepada bapak ibu',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.keyboard),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed:
                              _inputController.text.isEmpty ||
                                  _isListening ||
                                  _isStartingVoiceInput ||
                                  _isFinalizingVoiceInput
                              ? null
                              : _clear,
                          icon: const Icon(Icons.backspace_outlined),
                          label: const Text('Bersihkan'),
                        ),
                        if (defaultTargetPlatform == TargetPlatform.android)
                          IconButton(
                            key: const ValueKey<String>('pegon-voice-input'),
                            tooltip: _isListening
                                ? 'Berhenti mendengarkan'
                                : 'Masukkan teks dengan suara',
                            onPressed:
                                _isStartingVoiceInput || _isFinalizingVoiceInput
                                ? null
                                : _toggleVoiceInput,
                            color: _isListening ? colors.error : colors.primary,
                            icon: Icon(
                              _isListening
                                  ? Icons.stop_circle_outlined
                                  : Icons.mic_none,
                            ),
                          ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _output.trim().isEmpty
                              ? null
                              : _copyOutput,
                          icon: const Icon(Icons.copy),
                          label: const Text('Salin'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Hasil Pegon', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 120),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: SelectableText(
                        _output.isEmpty ? '—' : _output,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 22,
                          height: 1.9,
                        ),
                      ),
                    ),
                    if (_output.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        'Rincian per kata',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildWordBreakdown(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ketuk chip untuk menyalin satu kata, atau ikon '
                        'pensil untuk memperbaiki konversinya. Sumber: '
                        'Kamus = ejaan Arab baku, Kamus + imbuhan = kata '
                        'dasar Arab + afiks fonetis, Fonetis = transliterasi '
                        'huruf demi huruf, Koreksi Anda = ejaan yang Anda '
                        'simpan di perangkat.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (_engine.userCorrections.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(
                        'Koreksi Anda (${_engine.userCorrections.length})',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final MapEntry<String, String> entry
                              in _engine.userCorrections.entries)
                            InputChip(
                              key: ValueKey<String>(
                                'pegon-saved-${entry.key}',
                              ),
                              label: Text(
                                '${entry.key} → ${entry.value}',
                                textDirection: TextDirection.rtl,
                              ),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () => _deleteCorrection(entry.key),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ketuk × untuk menghapus koreksi.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// Dialog yang mengelola controller-nya sendiri sehingga controller tidak
/// dibuang sebelum animasi tutup dialog selesai.
class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.word, required this.result});

  final String word;
  final ConversionResult result;

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.result.output);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasCorrection =
        widget.result.source == ConversionSource.userCorrection;

    return AlertDialog(
      title: const Text('Perbaiki konversi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${widget.word} → ${widget.result.output} '
            '(${widget.result.source.label})',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>(_PegonConverterScreenState._correctionInputKey),
            controller: _controller,
            autofocus: true,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'Ejaan Pegon yang benar',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (String value) => Navigator.pop(
              context,
              _CorrectionResult.save(value.trim()),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Koreksi disimpan di perangkat ini dan dipakai setiap kata '
            'ini muncul. Kamus bawaan tidak diubah.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        if (hasCorrection)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              const _CorrectionResult.remove(),
            ),
            child: const Text('Hapus koreksi'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const ValueKey<String>(_PegonConverterScreenState._correctionSaveKey),
          onPressed: () {
            final String value = _controller.text.trim();
            if (value.isEmpty) {
              return;
            }
            Navigator.pop(context, _CorrectionResult.save(value));
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

enum _CorrectionKind { save, remove }

/// Hasil dialog koreksi: ejaan baru atau permintaan hapus koreksi.
class _CorrectionResult {
  const _CorrectionResult.save(this.value) : kind = _CorrectionKind.save;

  const _CorrectionResult.remove() : value = '', kind = _CorrectionKind.remove;

  final _CorrectionKind kind;
  final String value;
}
