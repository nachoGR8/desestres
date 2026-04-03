import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  static const _key = 'sound_enabled';
  bool _enabled = true;
  bool get enabled => _enabled;

  late final Uint8List _popSound;
  late final Uint8List _bellSound;
  late final Uint8List _clickSound;
  late final Uint8List _whooshSound;
  late final Uint8List _softToneSound;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? true;

    _popSound = _generatePop();
    _bellSound = _generateBell();
    _clickSound = _generateClick();
    _whooshSound = _generateWhoosh();
    _softToneSound = _generateSoftTone();
  }

  Future<void> toggle() async {
    _enabled = !_enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _enabled);
  }

  Future<void> playPop() => _play(_popSound);
  Future<void> playBell() => _play(_bellSound);
  Future<void> playClick() => _play(_clickSound);
  Future<void> playWhoosh() => _play(_whooshSound);
  Future<void> playSoftTone() => _play(_softToneSound);

  Future<void> _play(Uint8List wav) async {
    if (!_enabled) return;
    try {
      final player = AudioPlayer();
      await player.play(BytesSource(wav));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (_) {
      // Silently fail — sounds are non-critical
    }
  }

  // --- WAV synthesis ---

  /// Bubble pop: descending pitch burst (80ms)
  Uint8List _generatePop() {
    const sampleRate = 22050;
    const duration = 0.08;
    final n = (sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / sampleRate;
      final freq = 800 - t * 4000;
      final envelope = exp(-t * 40);
      return sin(2 * pi * freq * t) * envelope * 0.5;
    });
    return _createWav(samples, sampleRate);
  }

  /// Breathing bell: harmonic mix with soft decay (400ms)
  Uint8List _generateBell() {
    const sampleRate = 22050;
    const duration = 0.4;
    final n = (sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / sampleRate;
      final envelope = exp(-t * 5);
      final tone = sin(2 * pi * 880 * t) * 0.5 +
          sin(2 * pi * 1320 * t) * 0.25 +
          sin(2 * pi * 1760 * t) * 0.125;
      return tone * envelope * 0.3;
    });
    return _createWav(samples, sampleRate);
  }

  /// Mandala tap: very short click (20ms)
  Uint8List _generateClick() {
    const sampleRate = 22050;
    const duration = 0.02;
    final n = (sampleRate * duration).round();
    final rng = Random(42);
    final samples = List<double>.generate(n, (i) {
      final t = i / sampleRate;
      final envelope = exp(-t * 200);
      return (rng.nextDouble() * 2 - 1) * envelope * 0.3;
    });
    return _createWav(samples, sampleRate);
  }

  /// Worry dissolve: gentle noise sweep (300ms)
  Uint8List _generateWhoosh() {
    const sampleRate = 22050;
    const duration = 0.3;
    final n = (sampleRate * duration).round();
    final rng = Random(99);
    final samples = List<double>.generate(n, (i) {
      final t = i / sampleRate;
      final envelope = sin(pi * t / duration);
      return (rng.nextDouble() * 2 - 1) * envelope * 0.15;
    });
    return _createWav(samples, sampleRate);
  }

  /// Zen draw start: soft sine tone (150ms)
  Uint8List _generateSoftTone() {
    const sampleRate = 22050;
    const duration = 0.15;
    final n = (sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / sampleRate;
      final envelope = sin(pi * t / duration);
      return sin(2 * pi * 528 * t) * envelope * 0.2;
    });
    return _createWav(samples, sampleRate);
  }

  /// Build 16-bit mono PCM WAV from float samples [-1, 1].
  Uint8List _createWav(List<double> samples, int sampleRate) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2;
    final fileSize = 44 + dataSize;
    final buf = ByteData(fileSize);

    // RIFF header
    buf.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    buf.setUint32(4, fileSize - 8, Endian.little);
    buf.setUint32(8, 0x57415645, Endian.big); // "WAVE"

    // fmt chunk
    buf.setUint32(12, 0x666D7420, Endian.big); // "fmt "
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little); // PCM
    buf.setUint16(22, 1, Endian.little); // mono
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buf.setUint16(32, 2, Endian.little); // block align
    buf.setUint16(34, 16, Endian.little); // bits per sample

    // data chunk
    buf.setUint32(36, 0x64617461, Endian.big); // "data"
    buf.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      buf.setInt16(44 + i * 2, (clamped * 32767).round(), Endian.little);
    }

    return buf.buffer.asUint8List();
  }
}
