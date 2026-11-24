import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechInputService {
  SpeechInputService._();

  static final SpeechInputService instance = SpeechInputService._();

  final SpeechToText _speech = SpeechToText();
  void Function(String status)? _onStatus;
  void Function(String error)? _onError;

  bool get isAvailable => _speech.isAvailable;
  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;
    if (_speech.isAvailable) {
      return true;
    }

    return _speech.initialize(
      onStatus: (String status) => _onStatus?.call(status),
      onError: (error) => _onError?.call(error.errorMsg),
      options: <SpeechConfigOption>[SpeechToText.androidNoBluetooth],
    );
  }

  Future<List<LocaleName>> locales() => _speech.locales();

  Future<void> listen({
    required void Function(SpeechRecognitionResult result) onResult,
    required String localeId,
  }) {
    return _speech.listen(
      onResult: onResult,
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        localeId: localeId,
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}
