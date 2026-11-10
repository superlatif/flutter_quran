import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/conversion_result.dart';
import '../services/pegon_engine.dart';

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

  bool _isEngineReady = false;
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
    _inputController.removeListener(_convert);
    _inputController.dispose();
    super.dispose();
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

  List<Widget> _buildWordBreakdown() {
    final RegExp wordPattern = RegExp("[A-Za-z']+");
    final List<Widget> chips = <Widget>[];

    for (final RegExpMatch match
        in wordPattern.allMatches(_inputController.text)) {
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
                          onPressed: _inputController.text.isEmpty
                              ? null
                              : _clear,
                          icon: const Icon(Icons.backspace_outlined),
                          label: const Text('Bersihkan'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _output.trim().isEmpty ? null : _copyOutput,
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
