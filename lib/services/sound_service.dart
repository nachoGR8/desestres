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
  late final Uint8List _chimeSound;
  late final Uint8List _breathInSound;
  late final Uint8List _breathOutSound;

  /// Pool of pre-created players to avoid iOS cold-start latency.
  final List<AudioPlayer> _pool = [];
  static const _poolSize = 4;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? true;

    // Configure global audio context for iOS:
    // - Play even when silent switch is on
    // - Mix with other audio (music, etc.)
    final audioContext = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        audioMode: AndroidAudioMode.normal,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
    );
    AudioPlayer.global.setAudioContext(audioContext);

    // Pre-create player pool for low-latency playback
    for (int i = 0; i < _poolSize; i++) {
      _pool.add(AudioPlayer());
    }

    _popSound = _generatePop();
    _bellSound = _generateBell();
    _clickSound = _generateClick();
    _whooshSound = _generateWhoosh();
    _softToneSound = _generateSoftTone();
    _chimeSound = _generateChime();
    _breathInSound = _generateBreathIn();
    _breathOutSound = _generateBreathOut();
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
  Future<void> playChime() => _play(_chimeSound);
  Future<void> playBreathIn() => _play(_breathInSound);
  Future<void> playBreathOut() => _play(_breathOutSound);

  int _poolIndex = 0;

  Future<void> _play(Uint8List wav) async {
    if (!_enabled) return;
    try {
      // Round-robin through pre-created players for low latency
      final player = _pool[_poolIndex];
      _poolIndex = (_poolIndex + 1) % _poolSize;
      await player.stop(); // Stop any previous sound on this player
      await player.play(BytesSource(wav));
    } catch (_) {
      // Silently fail — sounds are non-critical
    }
  }

  // --- Relaxing WAV synthesis ---
  // All sounds tuned to soothing frequencies, soft envelopes,
  // longer durations. Think spa / meditation.

  static const _sampleRate = 44100;

  /// Soft bubble pop: gentle water droplet (200ms)
  /// Tuned to a major pentatonic interval — pleasant, not aggressive.
  Uint8List _generatePop() {
    const duration = 0.22;
    final n = (_sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / _sampleRate;
      // Gentle descending tone - like a water drop ripple
      final freq = 600 + 200 * exp(-t * 12);
      final envelope = exp(-t * 8) * sin(pi * t / duration).clamp(0.0, 1.0);
      // Mix fundamental with soft octave above
      final tone = sin(2 * pi * freq * t) * 0.6 +
          sin(2 * pi * freq * 1.5 * t) * 0.2 +
          sin(2 * pi * freq * 2 * t) * 0.1;
      return tone * envelope * 0.25;
    });
    return _createWav(samples, _sampleRate);
  }

  /// Singing bowl bell: rich harmonics with long decay (1.2s)
  /// Inspired by Tibetan singing bowls — deeply calming.
  Uint8List _generateBell() {
    const duration = 1.2;
    final n = (_sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / _sampleRate;
      // Slow exponential fade
      final envelope = exp(-t * 2.5);
      // Singing bowl harmonics (fundamental + partials)
      // Using 396 Hz — the "liberating" solfeggio frequency
      final tone = sin(2 * pi * 396 * t) * 0.35 +
          sin(2 * pi * 594 * t) * 0.20 + // Perfect fifth
          sin(2 * pi * 792 * t) * 0.15 + // Octave
          sin(2 * pi * 990 * t) * 0.08 + // Major third above octave
          sin(2 * pi * 1188 * t) * 0.04; // Two octaves minus step
      // Subtle vibrato for richness
      final vibrato = 1.0 + 0.002 * sin(2 * pi * 5.5 * t);
      return tone * vibrato * envelope * 0.35;
    });
    return _createWav(samples, _sampleRate);
  }

  /// Soft tap: warm, padded click for coloring (60ms)
  /// Like tapping a wooden xylophone bar gently.
  Uint8List _generateClick() {
    const duration = 0.08;
    final n = (_sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / _sampleRate;
      // Quick attack, gentle release
      final attack = (t < 0.003) ? t / 0.003 : 1.0;
      final release = exp(-t * 30);
      final envelope = attack * release;
      // Warm wooden tone — 440 Hz with soft harmonics
      final tone = sin(2 * pi * 440 * t) * 0.5 +
          sin(2 * pi * 660 * t) * 0.2 +
          sin(2 * pi * 880 * t) * 0.05;
      return tone * envelope * 0.18;
    });
    return _createWav(samples, _sampleRate);
  }

  /// Ocean whoosh: gentle wave washing away (600ms)
  /// Noise filtered through a slow envelope — like a small wave.
  Uint8List _generateWhoosh() {
    const duration = 0.65;
    final n = (_sampleRate * duration).round();
    final rng = Random(99);
    // Pre-generate noise
    final noise = List<double>.generate(n, (_) => rng.nextDouble() * 2 - 1);
    // Simple low-pass filter
    for (int i = 1; i < n; i++) {
      noise[i] = noise[i - 1] * 0.92 + noise[i] * 0.08;
    }
    final samples = List<double>.generate(n, (i) {
      final t = i / _sampleRate;
      // Bell-shaped envelope that peaks at 30%
      final peak = duration * 0.3;
      final envelope = exp(-pow((t - peak) / (duration * 0.25), 2));
      // Add a very subtle carried tone
      final tone = sin(2 * pi * 180 * t) * 0.05;
      return (noise[i] + tone) * envelope * 0.12;
    });
    return _createWav(samples, _sampleRate);
  }

  /// Zen tone: warm sine pad (300ms)
  /// 528 Hz — the "transformation" solfeggio frequency.
  /// Soft attack and release for drawing strokes.
  Uint8List _generateSoftTone() {
    const duration = 0.32;
    final n = (_sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / _sampleRate;
      // Slow attack (50ms) + sine release
      final attack = min(t / 0.05, 1.0);
      final release = cos((t / duration) * (pi / 2));
      final envelope = attack * release;
      // Warm 528 Hz with subtle octave below for body
      final tone = sin(2 * pi * 528 * t) * 0.45 +
          sin(2 * pi * 264 * t) * 0.25 +
          sin(2 * pi * 792 * t) * 0.08;
      return tone * envelope * 0.2;
    });
    return _createWav(samples, _sampleRate);
  }

  /// Wind chime: cascading crystal tones (1.5s)
  /// For achievement unlocks, mandala completion — celebratory but gentle.
  Uint8List _generateChime() {
    const duration = 1.5;
    final n = (_sampleRate * duration).round();
    // Pentatonic notes (in Hz) — always pleasant
    const notes = [523.25, 587.33, 659.26, 783.99, 880.0];
    final samples = List<double>.filled(n, 0.0);

    for (int c = 0; c < notes.length; c++) {
      final noteStart = c * 0.12; // Stagger each note
      final freq = notes[c];
      for (int i = 0; i < n; i++) {
        final t = i / _sampleRate;
        if (t < noteStart) continue;
        final tNote = t - noteStart;
        final envelope = exp(-tNote * 3.5) *
            (tNote < 0.005 ? tNote / 0.005 : 1.0);
        samples[i] += sin(2 * pi * freq * tNote) * envelope * 0.12 +
            sin(2 * pi * freq * 2 * tNote) * envelope * 0.04;
      }
    }
    return _createWav(samples, _sampleRate);
  }

  /// Breath in: gentle rising tone (1.2s)
  /// A soft "ahhh" rising pad to guide inhalation.
  Uint8List _generateBreathIn() {
    const duration = 1.2;
    final n = (_sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / _sampleRate;
      final progress = t / duration;
      // Slow attack + sustain — no harsh onset
      final envelope = sin(progress * pi * 0.5) * 0.8;
      // Gently rising pitch from 200 to 280 Hz
      final freq = 200 + 80 * progress;
      final tone = sin(2 * pi * freq * t) * 0.35 +
          sin(2 * pi * freq * 1.5 * t) * 0.15 +
          sin(2 * pi * freq * 2 * t) * 0.05;
      return tone * envelope * 0.12;
    });
    return _createWav(samples, _sampleRate);
  }

  /// Breath out: gentle descending tone (1.5s)
  /// A soft falling pad to guide exhalation — slightly longer.
  Uint8List _generateBreathOut() {
    const duration = 1.5;
    final n = (_sampleRate * duration).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / _sampleRate;
      final progress = t / duration;
      // Fade out gently
      final envelope = cos(progress * pi * 0.5) * 0.8;
      // Gently falling pitch from 280 to 180 Hz
      final freq = 280 - 100 * progress;
      final tone = sin(2 * pi * freq * t) * 0.35 +
          sin(2 * pi * freq * 1.5 * t) * 0.15 +
          sin(2 * pi * freq * 2 * t) * 0.05;
      return tone * envelope * 0.12;
    });
    return _createWav(samples, _sampleRate);
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
