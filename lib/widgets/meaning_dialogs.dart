import 'package:flutter/material.dart';

import '../models/verse_note.dart';
import '../models/word_meaning.dart';
import '../services/database_service.dart';
import '../services/meaning_settings_service.dart';
import '../services/meaning_share_service.dart';
import 'pegon_toolbar.dart';

Future<bool?> showWordMeaningEditor({
  required BuildContext context,
  required int surah,
  required int ayah,
  required int wordIndex,
  required String word,
  required WordMeaning? existing,
  required MeaningSettingsService settings,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => _WordMeaningEditorDialog(
      surah: surah,
      ayah: ayah,
      wordIndex: wordIndex,
      word: word,
      existing: existing,
      settings: settings,
    ),
  );
}

Future<bool?> showGroupMeaningDialog({
  required BuildContext context,
  required int surah,
  required int ayah,
  required List<String> words,
  required List<WordMeaning> meanings,
  required MeaningSettingsService settings,
  WordMeaning? initialGroup,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => _GroupMeaningDialog(
      surah: surah,
      ayah: ayah,
      words: words,
      meanings: meanings,
      settings: settings,
      initialGroup: initialGroup,
    ),
  );
}

Future<void> showVerseNotesDialog({
  required BuildContext context,
  required int surah,
  required int ayah,
  required MeaningSettingsService settings,
  VoidCallback? onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => _VerseNotesDialog(
      surah: surah,
      ayah: ayah,
      settings: settings,
      onChanged: onChanged,
    ),
  );
}

Future<void> showMeaningSettingsDialog({
  required BuildContext context,
  required MeaningSettingsService settings,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) =>
        _MeaningSettingsDialog(settings: settings),
  );
}

Future<void> showMeaningExportImportDialog({
  required BuildContext context,
  required int surah,
  required int ayah,
  required VoidCallback onImported,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) =>
        _ExportImportDialog(surah: surah, ayah: ayah, onImported: onImported),
  );
}

class _WordMeaningEditorDialog extends StatefulWidget {
  const _WordMeaningEditorDialog({
    required this.surah,
    required this.ayah,
    required this.wordIndex,
    required this.word,
    required this.existing,
    required this.settings,
  });

  final int surah;
  final int ayah;
  final int wordIndex;
  final String word;
  final WordMeaning? existing;
  final MeaningSettingsService settings;

  @override
  State<_WordMeaningEditorDialog> createState() =>
      _WordMeaningEditorDialogState();
}

class _WordMeaningEditorDialogState extends State<_WordMeaningEditorDialog> {
  late final TextEditingController _pegonController;
  late final TextEditingController _latinController;
  late final FocusNode _pegonFocus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pegonController = TextEditingController(
      text: widget.existing?.meaningPegon ?? '',
    );
    _latinController = TextEditingController(
      text: widget.existing?.meaningLatin ?? '',
    );
    _pegonFocus = FocusNode()..addListener(_handleFocus);
  }

  @override
  void dispose() {
    _pegonFocus
      ..removeListener(_handleFocus)
      ..dispose();
    _pegonController.dispose();
    _latinController.dispose();
    super.dispose();
  }

  void _handleFocus() => setState(() {});

  bool get _showPegonToolbar =>
      _pegonFocus.hasFocus &&
      widget.settings.inputMode != MeaningInputMode.latin;

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });
    try {
      await DatabaseService.instance.saveWordMeaning(
        surah: widget.surah,
        ayah: widget.ayah,
        wordIndex: widget.wordIndex,
        meaningPegon: _pegonController.text.trim(),
        meaningLatin: _latinController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan makna: $error')));
    }
  }

  Future<void> _delete() async {
    setState(() {
      _isSaving = true;
    });
    try {
      await DatabaseService.instance.deleteWordMeaning(
        surah: widget.surah,
        ayah: widget.ayah,
        wordIndex: widget.wordIndex,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus makna: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Makna Kata'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.word,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 22, height: 1.7),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _PegonTextField(
              controller: _pegonController,
              focusNode: _pegonFocus,
              label: 'Makna Pegon',
              hint: 'Tulis makna dengan huruf Pegon...',
            ),
            if (_showPegonToolbar)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: PegonToolbar(controller: _pegonController),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _latinController,
              textDirection: TextDirection.ltr,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Makna Latin',
                hintText: 'Tulis makna dengan huruf Latin...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.existing?.hasMeaning ?? false)
          TextButton.icon(
            onPressed: _isSaving ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus'),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

class _GroupMeaningDialog extends StatefulWidget {
  const _GroupMeaningDialog({
    required this.surah,
    required this.ayah,
    required this.words,
    required this.meanings,
    required this.settings,
    this.initialGroup,
  });

  final int surah;
  final int ayah;
  final List<String> words;
  final List<WordMeaning> meanings;
  final MeaningSettingsService settings;
  final WordMeaning? initialGroup;

  @override
  State<_GroupMeaningDialog> createState() => _GroupMeaningDialogState();
}

class _GroupMeaningDialogState extends State<_GroupMeaningDialog> {
  late Set<int> _selected;
  late final TextEditingController _pegonController;
  late final TextEditingController _latinController;
  late final FocusNode _pegonFocus;
  WordMeaning? _editingGroup;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editingGroup = widget.initialGroup;
    _selected = <int>{...?widget.initialGroup?.joinedWordIndices};
    _pegonController = TextEditingController(
      text: widget.initialGroup?.meaningPegon ?? '',
    );
    _latinController = TextEditingController(
      text: widget.initialGroup?.meaningLatin ?? '',
    );
    _pegonFocus = FocusNode()..addListener(_handleFocus);
  }

  void _loadGroupForEditing(WordMeaning group) {
    setState(() {
      _editingGroup = group;
      _selected = <int>{...group.joinedWordIndices};
      _pegonController.text = group.meaningPegon ?? '';
      _latinController.text = group.meaningLatin ?? '';
      _error = null;
    });
  }

  @override
  void dispose() {
    _pegonFocus
      ..removeListener(_handleFocus)
      ..dispose();
    _pegonController.dispose();
    _latinController.dispose();
    super.dispose();
  }

  void _handleFocus() => setState(() {});

  bool get _showPegonToolbar =>
      _pegonFocus.hasFocus &&
      widget.settings.inputMode != MeaningInputMode.latin;

  void _toggle(int index, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(index);
      } else {
        _selected.remove(index);
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final List<int> indices = _selected.toList()..sort();
    if (indices.length < 2) {
      setState(() {
        _error = 'Pilih minimal 2 kata untuk digabungkan.';
      });
      return;
    }
    for (int i = 1; i < indices.length; i++) {
      if (indices[i] != indices[i - 1] + 1) {
        setState(() {
          _error = 'Kata yang digabung harus berurutan dalam satu ayat.';
        });
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await DatabaseService.instance.saveGroupedMeaning(
        surah: widget.surah,
        ayah: widget.ayah,
        wordIndices: indices,
        meaningPegon: _pegonController.text.trim(),
        meaningLatin: _latinController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _error = 'Gagal menyimpan makna gabungan: $error';
      });
    }
  }

  Future<void> _ungroup() async {
    final String? groupId = _editingGroup?.groupId;
    if (groupId == null) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await DatabaseService.instance.ungroupMeaning(
        surah: widget.surah,
        ayah: widget.ayah,
        groupId: groupId,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _error = 'Gagal memisahkan makna: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<WordMeaning> groups = widget.meanings
        .where((WordMeaning meaning) => meaning.isGroupPrimary)
        .toList();

    return AlertDialog(
      title: Text(
        _editingGroup == null ? 'Gabungkan Makna' : 'Edit Makna Gabungan',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (groups.isNotEmpty) ...<Widget>[
                Text(
                  'Makna gabungan saat ini',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                ...groups
                    .where(
                      (WordMeaning group) =>
                          group.groupId != _editingGroup?.groupId,
                    )
                    .map(
                      (WordMeaning group) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.link),
                        title: Text(
                          _groupWordsLabel(group),
                          textDirection: TextDirection.rtl,
                        ),
                        subtitle: Text(
                          group.meaningLatin?.isNotEmpty ?? false
                              ? group.meaningLatin!
                              : (group.meaningPegon ?? ''),
                        ),
                        onTap: _isSaving
                            ? null
                            : () => _loadGroupForEditing(group),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Edit Makna Gabungan',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: _isSaving
                                  ? null
                                  : () => _loadGroupForEditing(group),
                            ),
                            IconButton(
                              tooltip: 'Pisah Makna',
                              icon: const Icon(Icons.link_off),
                              onPressed: _isSaving
                                  ? null
                                  : () {
                                      showDialog<void>(
                                        context: context,
                                        builder: (BuildContext context) =>
                                            AlertDialog(
                                              title: const Text('Pisah Makna'),
                                              content: const Text(
                                                'Kembalikan kata-kata ini '
                                                'menjadi makna individual?',
                                              ),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(),
                                                  child: const Text('Batal'),
                                                ),
                                                FilledButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                    _ungroupGroup(group);
                                                  },
                                                  child: const Text('Pisah'),
                                                ),
                                              ],
                                            ),
                                      );
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                const Divider(),
              ],
              Text(
                _editingGroup == null
                    ? 'Tulis makna gabungan:'
                    : 'Ubah teks makna gabungan:',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _PegonTextField(
                controller: _pegonController,
                focusNode: _pegonFocus,
                label: 'Makna Gabungan (Pegon)',
                hint: 'Contoh: عَبْدُ اللهِ',
              ),
              if (_showPegonToolbar)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: PegonToolbar(controller: _pegonController),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _latinController,
                textDirection: TextDirection.ltr,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Makna Gabungan (Latin)',
                  hintText: 'Contoh: hamba Allah',
                  border: OutlineInputBorder(),
                ),
              ),
              const Divider(height: 24),
              Text('Pilih kata berurutan:', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              ...List<Widget>.generate(widget.words.length, (int index) {
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _selected.contains(index),
                  onChanged: _isSaving
                      ? null
                      : (bool? value) => _toggle(index, value ?? false),
                  title: Text(
                    widget.words[index],
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 18),
                  ),
                  secondary: Text('${index + 1}'),
                );
              }),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        if (_editingGroup != null)
          TextButton.icon(
            onPressed: _isSaving ? null : _ungroup,
            icon: const Icon(Icons.link_off),
            label: const Text('Pisah Makna'),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_editingGroup == null ? 'Gabungkan' : 'Simpan'),
        ),
      ],
    );
  }

  String _groupWordsLabel(WordMeaning group) {
    final List<int> indices = group.joinedWordIndices;
    return indices
        .where((int index) => index >= 0 && index < widget.words.length)
        .map((int index) => widget.words[index])
        .join(' ');
  }

  Future<void> _ungroupGroup(WordMeaning group) async {
    final String? groupId = group.groupId;
    if (groupId == null) {
      return;
    }
    try {
      await DatabaseService.instance.ungroupMeaning(
        surah: widget.surah,
        ayah: widget.ayah,
        groupId: groupId,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memisahkan makna: $error';
        });
      }
    }
  }
}

class _VerseNotesDialog extends StatefulWidget {
  const _VerseNotesDialog({
    required this.surah,
    required this.ayah,
    required this.settings,
    this.onChanged,
  });

  final int surah;
  final int ayah;
  final MeaningSettingsService settings;
  final VoidCallback? onChanged;

  @override
  State<_VerseNotesDialog> createState() => _VerseNotesDialogState();
}

class _VerseNotesDialogState extends State<_VerseNotesDialog> {
  List<VerseNote> _notes = const <VerseNote>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<VerseNote> notes = await DatabaseService.instance.getVerseNotes(
      surah: widget.surah,
      ayah: widget.ayah,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  Future<void> _edit([VerseNote? note]) async {
    final VerseNote? result = await showDialog<VerseNote>(
      context: context,
      builder: (BuildContext context) => _NoteEditorDialog(
        surah: widget.surah,
        ayah: widget.ayah,
        existing: note,
        settings: widget.settings,
      ),
    );
    if (result == null) {
      return;
    }
    await DatabaseService.instance.saveVerseNote(result);
    await _load();
    widget.onChanged?.call();
  }

  Future<void> _delete(VerseNote note) async {
    final int? id = note.id;
    if (id == null) {
      return;
    }
    await DatabaseService.instance.deleteVerseNote(id);
    await _load();
    widget.onChanged?.call();
  }

  Widget _buildNoteTile(VerseNote note) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Chip(label: Text(note.noteType.label)),
      title: Text(
        note.contentLatin?.isNotEmpty ?? false
            ? note.contentLatin!
            : (note.contentPegon ?? ''),
      ),
      subtitle: note.reference?.isNotEmpty ?? false
          ? Text(note.reference!)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(note),
          ),
          IconButton(
            tooltip: 'Hapus',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(note),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Catatan Ayat ${widget.ayah}'),
      content: SizedBox(
        width: 460,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _notes.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Belum ada catatan untuk ayat ini.',
                  textAlign: TextAlign.center,
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < _notes.length;
                        index++
                      ) ...<Widget>[
                        if (index > 0) const Divider(height: 1),
                        _buildNoteTile(_notes[index]),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        FilledButton.icon(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Catatan'),
        ),
      ],
    );
  }
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({
    required this.surah,
    required this.ayah,
    required this.existing,
    required this.settings,
  });

  final int surah;
  final int ayah;
  final VerseNote? existing;
  final MeaningSettingsService settings;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  late VerseNoteType _type;
  late final TextEditingController _pegonController;
  late final TextEditingController _latinController;
  late final TextEditingController _referenceController;
  late final FocusNode _pegonFocus;

  @override
  void initState() {
    super.initState();
    _type = widget.existing?.noteType ?? VerseNoteType.explanation;
    _pegonController = TextEditingController(
      text: widget.existing?.contentPegon ?? '',
    );
    _latinController = TextEditingController(
      text: widget.existing?.contentLatin ?? '',
    );
    _referenceController = TextEditingController(
      text: widget.existing?.reference ?? '',
    );
    _pegonFocus = FocusNode()..addListener(_handleFocus);
  }

  @override
  void dispose() {
    _pegonFocus
      ..removeListener(_handleFocus)
      ..dispose();
    _pegonController.dispose();
    _latinController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _handleFocus() => setState(() {});

  bool get _showPegonToolbar =>
      _pegonFocus.hasFocus &&
      widget.settings.inputMode != MeaningInputMode.latin;

  void _submit() {
    Navigator.of(context).pop(
      VerseNote(
        id: widget.existing?.id,
        surah: widget.surah,
        ayah: widget.ayah,
        noteType: _type,
        contentPegon: _pegonController.text.trim(),
        contentLatin: _latinController.text.trim(),
        reference: _referenceController.text.trim(),
        createdAt: widget.existing?.createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Tambah Catatan' : 'Edit Catatan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DropdownButtonFormField<VerseNoteType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Jenis Catatan',
                border: OutlineInputBorder(),
              ),
              items: VerseNoteType.values
                  .map(
                    (VerseNoteType type) => DropdownMenuItem<VerseNoteType>(
                      value: type,
                      child: Text(type.label),
                    ),
                  )
                  .toList(),
              onChanged: (VerseNoteType? value) {
                if (value != null) {
                  setState(() {
                    _type = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            _PegonTextField(
              controller: _pegonController,
              focusNode: _pegonFocus,
              label: 'Isi Catatan (Pegon)',
              hint: 'Tulis catatan Pegon...',
              maxLines: 4,
            ),
            if (_showPegonToolbar)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: PegonToolbar(controller: _pegonController),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _latinController,
              textDirection: TextDirection.ltr,
              minLines: 2,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Isi Catatan (Latin)',
                hintText: 'Tulis catatan Latin...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'Referensi',
                hintText: 'Contoh: QS. Al-Baqarah: 2 / HR. Bukhari',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

class _MeaningSettingsDialog extends StatelessWidget {
  const _MeaningSettingsDialog({required this.settings});

  final MeaningSettingsService settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (BuildContext context, _) {
        return AlertDialog(
          title: const Text('Pengaturan Makna'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DropdownButtonFormField<DisplayScript>(
                  initialValue: settings.displayScript,
                  decoration: const InputDecoration(
                    labelText: 'Tampilan Skrip',
                    border: OutlineInputBorder(),
                  ),
                  items: DisplayScript.values
                      .map(
                        (DisplayScript value) =>
                            DropdownMenuItem<DisplayScript>(
                              value: value,
                              child: Text(value.label),
                            ),
                      )
                      .toList(),
                  onChanged: (DisplayScript? value) {
                    if (value != null) {
                      settings.setDisplayScript(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MeaningInputMode>(
                  initialValue: settings.inputMode,
                  decoration: const InputDecoration(
                    labelText: 'Mode Input',
                    border: OutlineInputBorder(),
                  ),
                  items: MeaningInputMode.values
                      .map(
                        (MeaningInputMode value) =>
                            DropdownMenuItem<MeaningInputMode>(
                              value: value,
                              child: Text(value.label),
                            ),
                      )
                      .toList(),
                  onChanged: (MeaningInputMode? value) {
                    if (value != null) {
                      settings.setInputMode(value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MeaningStyle>(
                  initialValue: settings.meaningStyle,
                  decoration: const InputDecoration(
                    labelText: 'Gaya Makna Gandul',
                    border: OutlineInputBorder(),
                  ),
                  items: MeaningStyle.values
                      .map(
                        (MeaningStyle value) => DropdownMenuItem<MeaningStyle>(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (MeaningStyle? value) {
                    if (value != null) {
                      settings.setMeaningStyle(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tampilkan makna bawaan'),
                  value: settings.showBaseMeaning,
                  onChanged: settings.setShowBaseMeaning,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Selesai'),
            ),
          ],
        );
      },
    );
  }
}

class _ExportImportDialog extends StatefulWidget {
  const _ExportImportDialog({
    required this.surah,
    required this.ayah,
    required this.onImported,
  });

  final int surah;
  final int ayah;
  final VoidCallback onImported;

  @override
  State<_ExportImportDialog> createState() => _ExportImportDialogState();
}

enum _ExportScope { all, surah, ayah }

class _ExportImportDialogState extends State<_ExportImportDialog> {
  _ExportScope _scope = _ExportScope.surah;
  bool _isBusy = false;
  late final TextEditingController _ayahController;

  @override
  void initState() {
    super.initState();
    _ayahController = TextEditingController(text: '${widget.ayah}');
  }

  @override
  void dispose() {
    _ayahController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final int? ayah = _scope == _ExportScope.ayah
        ? int.tryParse(_ayahController.text.trim())
        : null;
    if (_scope == _ExportScope.ayah && (ayah == null || ayah < 1)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nomor ayat tidak valid.')));
      return;
    }

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _isBusy = true;
    });
    try {
      await MeaningShareService.instance.shareExport(
        surah: _scope == _ExportScope.all ? null : widget.surah,
        ayah: ayah,
        sharePositionOrigin: origin,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal mengekspor: $error')));
    }
  }

  Future<void> _import() async {
    setState(() {
      _isBusy = true;
    });
    try {
      final MeaningImportResult? result = await MeaningShareService.instance
          .pickAndImport();
      if (!mounted) {
        return;
      }
      if (result == null) {
        setState(() {
          _isBusy = false;
        });
        return;
      }
      widget.onImported();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impor selesai: ${result.wordMeanings} makna, '
            '${result.notes} catatan '
            '(${result.skippedNotes} duplikat dilewati).',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBusy = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal mengimpor: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Berbagi Catatan'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('Pilih cakupan data yang akan diekspor:'),
            RadioGroup<_ExportScope>(
              groupValue: _scope,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _scope = value);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const RadioListTile<_ExportScope>(
                    contentPadding: EdgeInsets.zero,
                    value: _ExportScope.ayah,
                    title: Text('Ayat tertentu'),
                  ),
                  if (_scope == _ExportScope.ayah)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: TextField(
                        controller: _ayahController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nomor ayat',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  const RadioListTile<_ExportScope>(
                    contentPadding: EdgeInsets.zero,
                    value: _ExportScope.surah,
                    title: Text('Seluruh surah ini'),
                  ),
                  const RadioListTile<_ExportScope>(
                    contentPadding: EdgeInsets.zero,
                    value: _ExportScope.all,
                    title: Text('Semua data'),
                  ),
                ],
              ),
            ),
            const Divider(),
            const Text(
              'Impor akan menggabungkan data JSON ke database lokal tanpa '
              'menghapus catatan yang sudah ada.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        TextButton.icon(
          onPressed: _isBusy ? null : _import,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Impor'),
        ),
        FilledButton.icon(
          onPressed: _isBusy ? null : _export,
          icon: _isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share),
          label: const Text('Ekspor'),
        ),
      ],
    );
  }
}

class _PegonTextField extends StatelessWidget {
  const _PegonTextField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    this.maxLines = 3,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      minLines: 1,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 18, height: 1.8),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
