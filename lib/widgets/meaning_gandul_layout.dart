import 'package:flutter/material.dart';

import '../models/word_meaning.dart';
import '../services/meaning_settings_service.dart';

/// Menampilkan makna gandul di bawah kata-kata Arab sebuah ayat.
///
/// Kata yang tergabung dalam satu grup dirender sebagai satu blok makna,
/// sedangkan makna individual anggotanya disembunyikan.
class MeaningGandulLayout extends StatelessWidget {
  const MeaningGandulLayout({
    super.key,
    required this.words,
    required this.meanings,
    required this.displayScript,
    required this.meaningStyle,
    required this.showBaseMeaning,
    required this.onWordTap,
    required this.onGroupTap,
    this.maxWordWidth = 150,
  });

  final List<String> words;
  final List<WordMeaning> meanings;
  final DisplayScript displayScript;
  final MeaningStyle meaningStyle;
  final bool showBaseMeaning;
  final ValueChanged<int> onWordTap;
  final ValueChanged<WordMeaning> onGroupTap;
  final double maxWordWidth;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return const SizedBox.shrink();
    }

    final Map<int, WordMeaning> byIndex = <int, WordMeaning>{};
    for (final WordMeaning meaning in meanings) {
      if (!showBaseMeaning && meaning.sourceType == 'base') {
        continue;
      }
      byIndex[meaning.wordIndex] = meaning;
    }

    final List<_MeaningUnit> units = <_MeaningUnit>[];
    int index = 0;
    while (index < words.length) {
      final WordMeaning? meaning = byIndex[index];
      if (meaning != null && meaning.isGrouped) {
        if (meaning.isGroupPrimary) {
          final List<int> indices = meaning.joinedWordIndices
              .where((int value) => value >= 0 && value < words.length)
              .toList();
          if (indices.length >= 2) {
            units.add(
              _MeaningUnit(
                start: indices.first,
                end: indices.last,
                words: words.sublist(indices.first, indices.last + 1),
                meaning: meaning,
              ),
            );
            index = indices.last + 1;
            continue;
          }
        }
        // Anggota grup selain baris utama tidak dirender sendiri.
        index++;
        continue;
      }

      units.add(
        _MeaningUnit(
          start: index,
          end: index,
          words: <String>[words[index]],
          meaning: meaning,
        ),
      );
      index++;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: 6,
            runSpacing: 10,
            children: units.map((_MeaningUnit unit) {
              final bool longMeaning = unit.hasLongMeaning;
              final double desiredWidth = longMeaning
                  ? maxWordWidth * 2
                  : (unit.isGroup ? maxWordWidth * 1.8 : maxWordWidth);
              final double unitWidth = availableWidth.isFinite
                  ? desiredWidth.clamp(maxWordWidth, availableWidth).toDouble()
                  : desiredWidth;

              return _MeaningUnitView(
                unit: unit,
                displayScript: displayScript,
                meaningStyle: meaningStyle,
                maxWidth: unitWidth,
                meaningMaxLines: longMeaning ? 2 : null,
                onTap: () {
                  final WordMeaning? meaning = unit.meaning;
                  if (meaning != null && meaning.isGroupPrimary) {
                    onGroupTap(meaning);
                  } else {
                    onWordTap(unit.start);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _MeaningUnit {
  const _MeaningUnit({
    required this.start,
    required this.end,
    required this.words,
    required this.meaning,
  });

  final int start;
  final int end;
  final List<String> words;
  final WordMeaning? meaning;

  bool get isGroup => end > start;

  /// Makna dianggap sangat panjang bila melebihi dua kali panjang teks Arab
  /// (dengan batas minimal agar kata pendek tidak langsung dianggap panjang).
  bool get hasLongMeaning {
    final WordMeaning? value = meaning;
    if (value == null || !value.hasMeaning) {
      return false;
    }
    final int arabicLength = words.join().replaceAll(RegExp(r'\s+'), '').length;
    final int meaningLength =
        '${value.meaningPegon ?? ''}'
                '${value.meaningLatin ?? ''}'
            .replaceAll(RegExp(r'\s+'), '')
            .length;
    return meaningLength > 18 && meaningLength > arabicLength * 2;
  }
}

class _MeaningUnitView extends StatelessWidget {
  const _MeaningUnitView({
    required this.unit,
    required this.displayScript,
    required this.meaningStyle,
    required this.maxWidth,
    required this.onTap,
    this.meaningMaxLines,
  });

  final _MeaningUnit unit;
  final DisplayScript displayScript;
  final MeaningStyle meaningStyle;
  final double maxWidth;
  final VoidCallback onTap;
  final int? meaningMaxLines;

  static const List<String> _arabicFallbackFonts = <String>[
    'Noto Naskh Arabic',
    'Amiri',
    'Scheherazade New',
    'Noto Sans Arabic',
    'DejaVu Sans',
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final WordMeaning? meaning = unit.meaning;
    final String arabic = unit.words.join(' ');
    final bool hasMeaning = meaning?.hasMeaning ?? false;

    return Semantics(
      button: true,
      label: 'Makna kata $arabic',
      child: Material(
        color: unit.isGroup
            ? colors.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            width: maxWidth,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (unit.isGroup)
                  Text(
                    arabic,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 17,
                      height: 1.6,
                      fontFamilyFallback: _arabicFallbackFonts,
                    ),
                  )
                else
                  // Kata tunggal tidak boleh dipotong dengan elipsis; skala
                  // turunkan bila lebarnya melebihi sel makna.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      arabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 17,
                        height: 1.6,
                        fontFamilyFallback: _arabicFallbackFonts,
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                _buildMeaningContent(context, hasMeaning),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeaningContent(BuildContext context, bool hasMeaning) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final WordMeaning? meaning = unit.meaning;

    if (!hasMeaning) {
      return Text(
        unit.isGroup ? 'Makna gabungan' : 'Tambah makna',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.outline,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final List<Widget> texts = <Widget>[];
    final String? pegon = meaning?.meaningPegon?.trim();
    final String? latin = meaning?.meaningLatin?.trim();

    if (displayScript != DisplayScript.latin &&
        pegon != null &&
        pegon.isNotEmpty) {
      texts.add(
        Text(
          pegon,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          maxLines: meaningMaxLines,
          overflow: meaningMaxLines == null ? null : TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            height: 1.5,
            color: colors.onSurface,
          ),
        ),
      );
    }
    if (displayScript != DisplayScript.pegon &&
        latin != null &&
        latin.isNotEmpty) {
      if (texts.isNotEmpty) {
        texts.add(const SizedBox(height: 1));
      }
      texts.add(
        Text(
          latin,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: meaningMaxLines,
          overflow: meaningMaxLines == null ? null : TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            height: 1.4,
            color: colors.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: texts,
    );

    final int plainLength = '${pegon ?? ''}${latin ?? ''}'
        .replaceAll(RegExp(r'\s+'), '')
        .length;

    switch (meaningStyle) {
      case MeaningStyle.block:
        break;
      case MeaningStyle.indented:
        content = Padding(
          padding: const EdgeInsets.only(right: 10),
          child: content,
        );
        break;
      case MeaningStyle.italic45:
        // Teks panjang berisiko terpotong saat dimiringkan; fallback ke blok.
        if (plainLength > 18) {
          break;
        }
        content = Transform.rotate(
          angle: -0.785398,
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 11),
              child: content,
            ),
          ),
        );
    }

    return content;
  }
}
