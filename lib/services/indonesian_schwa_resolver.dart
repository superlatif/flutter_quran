import 'package:flutter/services.dart' show rootBundle;

/// Resolves Indonesian `e` vowels to schwa or taling using an offline lexicon
/// and productive prefix rules.
class IndonesianSchwaResolver {
  static const String _assetPath = 'assets/data/indonesian_schwa.tsv';

  static const List<String> _prefixes = <String>[
    'memper',
    'member',
    'seper',
    'meng',
    'meny',
    'mem',
    'men',
    'peng',
    'peny',
    'pem',
    'pen',
    'ber',
    'bel',
    'ter',
    'tel',
    'per',
    'pel',
    'me',
    'pe',
    'be',
    'te',
    'se',
    'ke',
    'di',
  ];

  static const List<String> _suffixesShortestFirst = <String>[
    'i',
    'an',
    'nya',
    'kan',
    'lah',
    'kah',
    'pun',
    'kannya',
    'annya',
  ];

  static final RegExp _rootOnset = RegExp(
    r'^([aiueo]|ng[aiueo]|ny[aiueo]|sy[aiueo]|kh[aiueo]|'
    r'[pbtdkgfsr]r[aiueo]|[pbkgf]l[aiueo]|s[ptkw][aiueo]|'
    r'[bcdfghjklmnpqrstvwxyz][aiueoy])',
  );

  final Map<String, int> _schwaMasks = <String, int>{};
  bool _isLoaded = false;

  /// Loads the packaged pronunciation masks.
  Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    final String packed = await rootBundle.loadString(_assetPath);
    final Map<String, int> masks = <String, int>{};
    for (final String rawLine in packed.split('\n')) {
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final int separator = line.lastIndexOf(' ');
      if (separator <= 0) {
        throw FormatException('Invalid Indonesian schwa entry: $line');
      }
      masks[line.substring(0, separator)] = int.parse(
        line.substring(separator + 1),
        radix: 16,
      );
    }

    _schwaMasks
      ..clear()
      ..addAll(masks);
    _isLoaded = true;
  }

  /// Keeps schwa `e`s and turns unmarked/taling `e`s into `i`.
  String mapTalingToI(String word) {
    final int? mask = _maskForWord(word);
    final int schwaMask = mask ?? 0;
    final StringBuffer result = StringBuffer();
    int eIndex = 0;

    for (int i = 0; i < word.length; i++) {
      final String character = word[i];
      if (character != 'e') {
        result.write(character);
        continue;
      }

      result.write((schwaMask & (1 << eIndex)) != 0 ? 'e' : 'i');
      eIndex++;
    }
    return result.toString();
  }

  int? _maskForWord(String word, [int depth = 0]) {
    final int? knownMask = _schwaMasks[word];
    if (knownMask != null || _schwaMasks.containsKey(word)) {
      return knownMask;
    }
    return _affixSchwaMask(word, depth);
  }

  int? _affixSchwaMask(String word, int depth) {
    if (depth >= 3) {
      return null;
    }

    for (final String suffix in _suffixesShortestFirst) {
      if (!word.endsWith(suffix) || word.length < suffix.length + 3) {
        continue;
      }
      final String stem = word.substring(0, word.length - suffix.length);
      if (_schwaMasks.containsKey(stem)) {
        return _schwaMasks[stem];
      }
    }

    for (final String prefix in _prefixes) {
      if (!word.startsWith(prefix) || word.length <= prefix.length + 1) {
        continue;
      }

      final String root = word.substring(prefix.length);
      if (!_rootOnset.hasMatch(root)) {
        continue;
      }

      final int prefixSchwaCount = 'e'.allMatches(prefix).length;
      final int prefixMask = (1 << prefixSchwaCount) - 1;
      final int? rootMask = _resolveRoot(root, depth);
      return rootMask == null
          ? prefixMask
          : prefixMask | (rootMask << prefixSchwaCount);
    }

    return null;
  }

  int? _resolveRoot(String root, int depth) {
    final int? directMask =
        _schwaMasks[root] ?? _affixSchwaMask(root, depth + 1);
    if (directMask != null) {
      return directMask;
    }

    for (final String suffix in _suffixesShortestFirst) {
      if (!root.endsWith(suffix) || root.length <= suffix.length + 1) {
        continue;
      }

      final String stem = root.substring(0, root.length - suffix.length);
      final int? stemMask =
          _schwaMasks[stem] ?? _affixSchwaMask(stem, depth + 1);
      if (stemMask != null) {
        return stemMask;
      }
    }
    return null;
  }
}
