import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../services/pegon_engine.dart';
import '../services/pegon_spelling_settings_service.dart';

/// Menampilkan dialog pengaturan varian ejaan Pegon hasil konversi.
Future<void> showPegonSpellingSettingsDialog({
  required BuildContext context,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => const _PegonSpellingSettingsDialog(),
  );
}

class _PegonSpellingSettingsDialog extends StatefulWidget {
  const _PegonSpellingSettingsDialog();

  @override
  State<_PegonSpellingSettingsDialog> createState() =>
      _PegonSpellingSettingsDialogState();
}

class _PegonSpellingSettingsDialogState
    extends State<_PegonSpellingSettingsDialog> {
  final PegonSpellingSettingsService _settings =
      PegonSpellingSettingsService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_settings.load());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pengaturan Ejaan Pegon'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Pilih bentuk huruf untuk hasil konversi Latin → Pegon. '
              'Kata yang berasal dari kamus dan koreksi Anda tetap '
              'menggunakan ejaan yang sudah tersimpan.',
            ),
            const SizedBox(height: 16),
            PegonSpellingSettingsControls(settings: _settings),
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
  }
}

/// Kontrol pengaturan yang bisa dipakai ulang, baik di dialog khusus
/// maupun di dalam "Pengaturan Makna".
class PegonSpellingSettingsControls extends StatelessWidget {
  const PegonSpellingSettingsControls({super.key, required this.settings});

  final PegonSpellingSettingsService settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (BuildContext context, _) {
        final ThemeData theme = Theme.of(context);
        final ColorScheme colors = theme.colorScheme;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DropdownButtonFormField<PegonGSpelling>(
              key: const ValueKey<String>('pegon-g-spelling'),
              initialValue: settings.gSpelling,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ejaan huruf g (kaf)',
                border: OutlineInputBorder(),
              ),
              items: PegonGSpelling.values
                  .map(
                    (PegonGSpelling value) =>
                        DropdownMenuItem<PegonGSpelling>(
                      value: value,
                      child: Text(value.optionLabel),
                    ),
                  )
                  .toList(),
              onChanged: (PegonGSpelling? value) {
                if (value != null) {
                  settings.setGSpelling(value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PegonPSpelling>(
              key: const ValueKey<String>('pegon-p-spelling'),
              initialValue: settings.pSpelling,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Ejaan huruf p / v (fa)',
                border: OutlineInputBorder(),
              ),
              items: PegonPSpelling.values
                  .map(
                    (PegonPSpelling value) =>
                        DropdownMenuItem<PegonPSpelling>(
                      value: value,
                      child: Text(value.optionLabel),
                    ),
                  )
                  .toList(),
              onChanged: (PegonPSpelling? value) {
                if (value != null) {
                  settings.setPSpelling(value);
                }
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Contoh: pegawai → '
                '${PegonEngine.instance.phoneticConvert('pegawai')}',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        );
      },
    );
  }
}
