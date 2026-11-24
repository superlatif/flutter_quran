import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/conversion_result.dart';
import '../services/pegon_engine.dart';
import '../services/speech_input_service.dart';

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

  bool _isEngineReady = false;
  bool _isListening = false;
  bool _isStartingVoiceInput = false;
  bool _isFinalizingVoiceInput = false;
  String _voiceInputBase = '';
  String _output = '';

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_convert);
    unawaited(_loadEngine());
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

  void _showVoiceMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<Widget> _buildWordBreakdown() {
    final RegExp wordPattern = RegExp("[A-Za-z']+");
    final List<Widget> chips = <Widget>[];

    for (final RegExpMatch match in wordPattern.allMatches(
      _inputController.text,
    )) {
      final ConversionResult result = _engine.convertWord(match.group(0)!);
      chips.add(
        InputChip(
          label: Text(
            '${result.input} → ${result.output}',
            textDirection: TextDirection.rtl,
          ),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: result.output));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${result.output} (${result.source.label}) tersalin',
                ),
              ),
            );
          },
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
      appBar: AppBar(title: const Text('Pegon')),
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
                                  'Kamus: ${_engine.dictionaryEntryCount} kata',
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
                              'mode terjemah.',
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
                        'Ketuk chip untuk menyalin satu kata. '
                        'Sumber: Kamus = ejaan Arab baku, '
                        'Kamus + imbuhan = kata dasar Arab + afiks fonetis, '
                        'Fonetis = transliterasi huruf demi huruf.',
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
