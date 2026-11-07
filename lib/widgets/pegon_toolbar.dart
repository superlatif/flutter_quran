import 'package:flutter/material.dart';

/// Toolbar karakter khusus Pegon yang muncul di atas keyboard.
class PegonToolbar extends StatelessWidget {
  const PegonToolbar({
    super.key,
    required this.controller,
    this.characters = defaultCharacters,
  });

  final TextEditingController controller;
  final List<String> characters;

  static const List<String> defaultCharacters = <String>[
    'ڠ',
    'ۑ',
    'ڨ',
    'ڬ',
    'ۏ',
    'ڽ',
    'ࢮ',
    'ڎ',
    'ڊ',
    'ڃ',
    'ڄ',
    'څ',
    'چ',
    'ڤ',
    'ݢ',
    'ڮ',
    'ڠ',
    'ۅ',
    'ٱ',
    'ء',
    'ئ',
    'ؤ',
  ];

  void _insert(String character) {
    final TextEditingValue value = controller.value;
    final TextSelection selection = value.selection;
    final int start = selection.isValid ? selection.start : value.text.length;
    final int end = selection.isValid ? selection.end : value.text.length;
    final String newText = value.text.replaceRange(start, end, character);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + character.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: <Widget>[
            for (int index = 0; index < characters.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: 4),
              Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _insert(characters[index]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        characters[index],
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
