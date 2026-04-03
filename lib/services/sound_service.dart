import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  static const _key = 'sound_enabled';
  bool _enabled = true;
  bool get enabled => _enabled;

  /// File paths for each sound (written to temp dir).
  final Map<String, String> _soundPaths = {};

  /// Pool of pre-created players for low-latency playback.
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

    // Generate WAV bytes and write to temp files (iOS needs file-based sources)
    final dir = await getTemporaryDirectory();
    final soundsDir = Directory('${dir.path}/desestres_sounds');
    if (!soundsDir.existsSync()) soundsDir.createSync();

    Future<void> writeSound(String name, Uint8List wav) async {
      final path = '${soundsDir.path}/$name.wav';
      await File(path).writeAsBytes(wav, flush: true);
      _soundPaths[name] = path;
    }

    await Future.wait([
      writeSound('pop', _generatePop()),
      writeSound('bell', _generateBell()),
      writeSound('click', _generateClick()),
      writeSound('whoosh', _generateWhoosh()),
      writeSound('softTone', _generateSoftTone()),
      writeSound('chime', _generateChime()),
      writeSound('breathIn', _generateBreathIn()),
      writeSound('breathOut', _generateBreathOut()),
      writeSound('squelch', _generateSquelch()),
      writeSound('squish', _generateSquish()),
      writeSound('splat', _generateSplat()),
    ]);
  }

  Future<void> toggle() async {
    _enabled = !_enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _enabled);
  }

  Future<void> playPop() => _play('pop');
  Future<void> playBell() => _play('bell');
  Future<void> playClick() => _play('click');
  Future<void> playWhoosh() => _play('whoosh');
  Future<void> playSoftTone() => _play('softTone');
  Future<void> playChime() => _play('chime');
  Future<void> playBreathIn() => _play('breathIn');
  Future<void> playBreathOut() => _play('breathOut');
  Future<void> playSquelch() => _play('squelch');
  Future<void> playSquish() => _play('squish');
  Future<void> playSplat() => _play('splat');

  int _poolIndex = 0;

  Future<void> _play(String name) async {
    if (!_enabled) return;
    final path = _soundPaths[name];
    if (path == null) return;
    try {
      final player = _pool[_poolIndex];
      _poolIndex = (_poolIndex + 1) % _poolSize;
      await player.stop();
      await player.play(DeviceFileSource(path));
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

  /// Squelch: wet squishy sound for starting to squeeze a pimple (150ms)
  /// Filtered noise burst with a low descending tone — like pressing wet skin.
  Uint8List _generateSquelch() {
    const duration = 0.18;
    final n = (_sampleRate * duration).round();
    final rng = Random(42);
    final noise = List<double>.generate(n, (_) => rng.nextDouble() * 2 - 1);
    // Heavy low-pass for wet quality
    for (int pass = 0; pass < 3; pass++) {
      for (int i = 1; i < n; i++) {
        noise[i] = noise[i - 1] * 0.88 + noise[i] * 0.12;
      }
    }
    final samples = List<double>.generate(n, (i) {
      final t = i / _sampleRate;
      final attack = (t < 0.005) ? t / 0.005 : 1.0;
      final release = exp(-t * 18);
      final envelope = attack * release;
      // Low descending tone for body
      final freq = 180 - 80 * (t / duration);
      final tone = sin(2 * pi * freq * t) * 0.4 +
          sin(2 * pi * freq * 0.5 * t) * 0.2;
      return (noise[i] * 0.6 + tone) * envelope * 0.28;
    });
    return _createWav(samples, _sampleRate);
  }

  /// Squish: pressure building sound for sustained squeeze (200ms)
  /// Deeper, wetter — like flesh being compressed. Used for blackhead taps too.
  Uint8List _generateSquish() {
    const duration = 0.22;
    final n = (_sampleRate * duration).round();
    final rng = Random(77);
    final noise = List<double>.generate(n, (_) => rng.nextDouble() * 2 - 1);
    // Very heavy filtering for thick wet texture
    for (int pass = 0; pass < 5; pass++) {
      for (int i = 1; i < n; i++) {
        noise[i] = noise[i - 1] * 0.93 + noise[i] * 0.07;
      }
    }
    final samples = List<double>.generate(n, (i) {
      final t = i / _sampleRate;
      final progress = t / duration;
      // Bell-shaped envelope peaking at 40%
      final envelope = exp(-pow((progress - 0.4) / 0.3, 2));
      // Two low tones that create a "squelching" beat
      final tone = sin(2 * pi * 120 * t) * 0.35 +
          sin(2 * pi * 155 * t) * 0.25 +
          sin(2 * pi * 90 * t) * 0.15;
      return (noise[i] * 0.5 + tone) * envelope * 0.25;
    });
    return _createWav(samples, _sampleRate);
  }

  /// Splat: juicy wet burst for popping a pimple (350ms)
  /// Satisfying combination: sharp attack + wet noise tail + low thump.
  /// Much more impactful than the gentle water-drop pop.
  Uint8List _generateSplat() {
    const duration = 0.38;
    final n = (_sampleRate * duration).round();
    final rng = Random(55);
    final noise = List<double>.generate(n, (_) => rng.nextDouble() * 2 - 1);
    // Medium filtering — not too clean, not too harsh
    for (int pass = 0; pass < 2; pass++) {
      for (int i = 1; i < n; i++) {
        noise[i] = noise[i - 1] * 0.85 + noise[i] * 0.15;
      }
    }
    final samples = List<double>.generate(n, (i) {
      final t = i / _sampleRate;
      // Sharp initial burst (first 30ms)
      final burstEnv = exp(-t * 35);
      // Wet tail that lingers
      final tailEnv = exp(-t * 6) * 0.5;
      // Low thump for impact
      final thumpFreq = 100 * exp(-t * 8);
      final thump = sin(2 * pi * thumpFreq * t) * burstEnv * 0.5;
      // Mid-range "splat" tone
      final splatFreq = 350 - 200 * (t / duration);
      final splatTone = sin(2 * pi * splatFreq * t) * 0.3 * burstEnv;
      // Higher transient for the "crack" of the pop
      final crack = sin(2 * pi * 900 * t) * exp(-t * 50) * 0.2;
      // Wet noise (the splash)
      final wetNoise = noise[i] * tailEnv;
      return (thump + splatTone + crack + wetNoise) * 0.32;
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
