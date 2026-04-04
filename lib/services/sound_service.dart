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
  static const _poolSize = 6;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_key) ?? true;

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

    for (int i = 0; i < _poolSize; i++) {
      _pool.add(AudioPlayer());
    }

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
      writeSound('rewardDing', _generateRewardDing()),
      writeSound('ambientPad', _generateAmbientPad()),
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
  Future<void> playRewardDing() => _play('rewardDing');
  Future<void> playAmbientPad() => _play('ambientPad');

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
    } catch (_) {}
  }

  // ─── Synthesis helpers ─────────────────────────────────────

  static const _sr = 44100;

  /// Low-pass filter via simple IIR. Higher coeff = more filtering.
  List<double> _lowPass(List<double> s, double coeff, {int passes = 1}) {
    for (int p = 0; p < passes; p++) {
      for (int i = 1; i < s.length; i++) {
        s[i] = s[i - 1] * coeff + s[i] * (1 - coeff);
      }
    }
    return s;
  }

  /// ADSR envelope.
  double _adsr(double t, double a, double d, double sus, double r, double dur) {
    if (t < a) return t / a;
    if (t < a + d) return 1.0 - (1.0 - sus) * ((t - a) / d);
    if (t < dur - r) return sus;
    return sus * ((dur - t) / r).clamp(0.0, 1.0);
  }

  /// Soft clip (tanh-based) to avoid harsh digital clipping.
  double _softClip(double x) {
    const drive = 1.5;
    return (x * drive).clamp(-5.0, 5.0) / drive;
  }

  /// Seeded white noise.
  List<double> _noise(int length, {int seed = 0}) {
    final rng = Random(seed);
    return List.generate(length, (_) => rng.nextDouble() * 2 - 1);
  }

  // ─── Sound generators ─────────────────────────────────────

  /// Airy bubble pop — soft "pff" like a soap bubble bursting (250ms)
  Uint8List _generatePop() {
    const dur = 0.25;
    final n = (_sr * dur).round();
    final noise1 = _noise(n, seed: 10);
    _lowPass(noise1, 0.75, passes: 2); // band-limited air burst
    final noise2 = _noise(n, seed: 11);
    _lowPass(noise2, 0.92, passes: 3); // low body

    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      final env = exp(-t * 15) * (t < 0.001 ? t / 0.001 : 1.0);
      // Soft tonal anchor
      final tone = sin(2 * pi * 440 * t) * exp(-t * 20) * 0.3;
      // Air burst (brighter)
      final air = noise1[i] * env * 0.5;
      // Low body
      final body = noise2[i] * env * 0.25;
      return _softClip((tone + air + body) * 0.15);
    });
    return _createWav(samples, _sr);
  }

  /// Singing bowl — rich beating harmonics with long decay (2.0s)
  Uint8List _generateBell() {
    const dur = 2.0;
    final n = (_sr * dur).round();
    // Soft strike noise
    final strike = _noise(n, seed: 20);
    _lowPass(strike, 0.88, passes: 4);

    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      // Soft onset
      final onset = t < 0.01 ? sin(pi * t / 0.02) * sin(pi * t / 0.02) : 1.0;
      // Vibrato
      final vib = 1.0 + 0.005 * sin(2 * pi * 5 * t);

      // Detuned fundamental pair — creates characteristic singing bowl beating
      final f1a = sin(2 * pi * 396 * t * vib) * exp(-t * 1.5) * 0.30;
      final f1b = sin(2 * pi * 397.2 * t * vib) * exp(-t * 1.5) * 0.30;
      // Harmonics with individual decay rates
      final h1 = sin(2 * pi * 594 * t) * exp(-t * 2.0) * 0.18;
      final h2 = sin(2 * pi * 792 * t) * exp(-t * 2.8) * 0.12;
      final h3 = sin(2 * pi * 990 * t) * exp(-t * 3.5) * 0.06;
      final h4 = sin(2 * pi * 1188 * t) * exp(-t * 4.5) * 0.03;
      // Strike transient
      final str = strike[i] * exp(-t * 40) * 0.03;

      return _softClip((f1a + f1b + h1 + h2 + h3 + h4 + str) * onset * 0.35);
    });
    return _createWav(samples, _sr);
  }

  /// Warm wooden wind-chime tap — triangle wave, padded (120ms)
  Uint8List _generateClick() {
    const dur = 0.12;
    final n = (_sr * dur).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      final attack = min(t / 0.008, 1.0);
      final release = exp(-t * 18);
      final env = attack * release;
      // Triangle wave at 528 Hz (warmer than sine)
      final tri = sin(2 * pi * 528 * t) -
          sin(2 * pi * 528 * 3 * t) / 9 +
          sin(2 * pi * 528 * 5 * t) / 25;
      // Sub-octave for body
      final sub = sin(2 * pi * 264 * t) * 0.15;
      return (tri + sub) * env * 0.12;
    });
    return _createWav(samples, _sr);
  }

  /// Ocean wave whoosh — time-varying filtered noise with tonal undertone (800ms)
  Uint8List _generateWhoosh() {
    const dur = 0.80;
    final n = (_sr * dur).round();
    final noise1 = _noise(n, seed: 30);
    final noise2 = _noise(n, seed: 31);

    // Time-varying low-pass: filter opens during buildup, closes during recede
    for (int pass = 0; pass < 3; pass++) {
      for (int i = 1; i < n; i++) {
        final t = i / _sr;
        final progress = t / dur;
        // Filter coefficient varies: lower = more open, higher = more closed
        final coeff = progress < 0.35
            ? 0.95 - (progress / 0.35) * 0.15 // opens: 0.95 → 0.80
            : 0.80 + ((progress - 0.35) / 0.65) * 0.15; // closes: 0.80 → 0.95
        noise1[i] = noise1[i - 1] * coeff + noise1[i] * (1 - coeff);
      }
    }
    // Second layer with heavier filtering
    _lowPass(noise2, 0.93, passes: 4);

    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      final progress = t / dur;
      // Main wave envelope peaking at 35%
      final mainEnv = exp(-pow((progress - 0.35) / 0.25, 2));
      // Second subtle echo wave at 60%
      final echoEnv = exp(-pow((progress - 0.65) / 0.20, 2)) * 0.3;
      final env = mainEnv + echoEnv;
      // Tonal undertone — minor third chord, very subtle
      final tone = (sin(2 * pi * 174 * t) + sin(2 * pi * 220 * t)) * 0.03 * env;
      return _softClip((noise1[i] * 0.7 + noise2[i] * 0.3 + tone) * env * 0.14);
    });
    return _createWav(samples, _sr);
  }

  /// Zen brush pad — shimmering 528 Hz with airy texture (400ms)
  Uint8List _generateSoftTone() {
    const dur = 0.40;
    final n = (_sr * dur).round();
    final noise = _noise(n, seed: 40);
    _lowPass(noise, 0.90, passes: 3);

    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      final progress = t / dur;
      // Slow attack, cosine fade
      final attack = min(t / 0.06, 1.0);
      final fade = progress < 0.6 ? 1.0 : cos((progress - 0.6) / 0.4 * (pi / 2));
      final env = attack * fade;
      // Subtle tremolo
      final trem = 1.0 + 0.03 * sin(2 * pi * 6 * t);
      // Subtle pitch rise
      final freq = 528 + 8 * progress;
      // Detuned triple for warmth
      final tone = sin(2 * pi * (freq - 1) * t) * 0.35 +
          sin(2 * pi * freq * t) * 0.35 +
          sin(2 * pi * (freq + 1) * t) * 0.35;
      // Sub-octave
      final sub = sin(2 * pi * 264 * t) * 0.15;
      // Airy brush whisper
      final air = noise[i] * 0.03;
      return _softClip((tone + sub + air) * env * trem * 0.18);
    });
    return _createWav(samples, _sr);
  }

  /// Wind chime cascade — pentatonic at 432 Hz tuning with reverb tail (2.0s)
  Uint8List _generateChime() {
    const dur = 2.0;
    final n = (_sr * dur).round();
    // Pentatonic in A=432 Hz tuning
    const notes = [432.0, 486.0, 540.0, 648.0, 720.0];
    final samples = List<double>.filled(n, 0.0);

    for (int c = 0; c < notes.length; c++) {
      final noteStart = c * 0.15;
      final freq = notes[c];
      final freqB = freq + 0.5; // detuned pair
      for (int i = 0; i < n; i++) {
        final t = i / _sr;
        if (t < noteStart) continue;
        final tNote = t - noteStart;
        final onset = tNote < 0.005 ? tNote / 0.005 : 1.0;
        final decay = exp(-tNote * 2.2);
        final env = onset * decay;
        // Detuned pair + octave harmonic
        samples[i] += (sin(2 * pi * freq * tNote) * 0.5 +
                sin(2 * pi * freqB * tNote) * 0.5 +
                sin(2 * pi * freq * 2 * tNote) * 0.08) *
            env *
            0.10;
      }
    }
    // Reverb-like wash: sum of all notes at low level, slow decay from t=0.75s
    for (int i = 0; i < n; i++) {
      final t = i / _sr;
      if (t < 0.75) continue;
      final washEnv = exp(-(t - 0.75) * 1.8) * 0.15;
      for (final freq in notes) {
        samples[i] += sin(2 * pi * freq * 0.5 * t) * washEnv * 0.03;
      }
    }

    // Soft clip all
    for (int i = 0; i < n; i++) {
      samples[i] = _softClip(samples[i]);
    }
    return _createWav(samples, _sr);
  }

  /// Warm guided inhale — detuned chorus with breath noise (1.2s)
  Uint8List _generateBreathIn() {
    const dur = 1.2;
    final n = (_sr * dur).round();
    final noise = _noise(n, seed: 50);
    _lowPass(noise, 0.88, passes: 4);

    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      final progress = t / dur;
      // ADSR: 200ms attack, sustain, 100ms release
      final env = _adsr(t, 0.20, 0.05, 0.85, 0.10, dur);
      // Subtle amplitude vibrato
      final vib = 1.0 + 0.02 * sin(2 * pi * 4 * t);
      // Pitch glide: G3 (196) → C4 (262), perfect fourth
      final freq = 196 + 66 * progress;
      // Detuned triple oscillator for warm chorus
      final tone = sin(2 * pi * (freq - 0.5) * t) * 0.33 +
          sin(2 * pi * freq * t) * 0.34 +
          sin(2 * pi * (freq + 0.7) * t) * 0.33;
      // Odd harmonics for vowel-like "ahhh"
      final h3 = sin(2 * pi * freq * 3 * t) * 0.05;
      final h5 = sin(2 * pi * freq * 5 * t) * 0.02;
      // Breath noise layer (subtle air)
      final air = noise[i] * 0.05 * env;
      return _softClip((tone + h3 + h5 + air) * env * vib * 0.14);
    });
    return _createWav(samples, _sr);
  }

  /// Warm guided exhale — descending chorus with breathy fade (1.5s)
  Uint8List _generateBreathOut() {
    const dur = 1.5;
    final n = (_sr * dur).round();
    final noise = _noise(n, seed: 51);
    _lowPass(noise, 0.86, passes: 4);

    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      final progress = t / dur;
      // Slow cosine fade — steady release
      final env = cos(progress * pi * 0.5) * 0.85;
      // Pitch glide: C4 (262) → E3 (165), descending major sixth
      final freq = 262 - 97 * progress;
      // Detuned triple
      final tone = sin(2 * pi * (freq - 0.5) * t) * 0.33 +
          sin(2 * pi * freq * t) * 0.34 +
          sin(2 * pi * (freq + 0.7) * t) * 0.33;
      final h3 = sin(2 * pi * freq * 3 * t) * 0.04;
      // Breath noise increases as tone fades — simulates exhale trailing off
      final noiseLevel = 0.04 + progress * 0.06;
      final air = noise[i] * noiseLevel * (1.0 - progress * 0.3);
      return _softClip((tone + h3 + air) * env * 0.14);
    });
    return _createWav(samples, _sr);
  }

  /// Wet squelch — starting a squeeze (180ms)
  /// Satisfying but soft: no harsh transient, deep sub-bass thump.
  Uint8List _generateSquelch() {
    const dur = 0.18;
    final n = (_sr * dur).round();
    final noise = _noise(n, seed: 42);
    _lowPass(noise, 0.88, passes: 4);

    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      final attack = min(t / 0.010, 1.0); // softer attack (10ms)
      final release = exp(-t * 18);
      final env = attack * release;
      // Descending tone (lower starting freq)
      final freq = 150 - 70 * (t / dur);
      final tone = sin(2 * pi * freq * t) * 0.35 +
          sin(2 * pi * freq * 0.5 * t) * 0.2;
      // Sub-bass thump for chest feel
      final sub = sin(2 * pi * 60 * t) * exp(-t * 25) * 0.25;
      return _softClip((noise[i] * 0.5 + tone + sub) * env * 0.22);
    });
    return _createWav(samples, _sr);
  }

  /// Thick squish — pressure building / blackhead tap (220ms)
  /// Deep and muffled, with descending pitch bend.
  Uint8List _generateSquish() {
    const dur = 0.22;
    final n = (_sr * dur).round();
    final noise = _noise(n, seed: 77);
    _lowPass(noise, 0.93, passes: 6);

    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      final progress = t / dur;
      // Wider bell-shaped envelope peaking at 45%
      final env = exp(-pow((progress - 0.45) / 0.35, 2));
      // Deeper tones with pitch bend down
      final bend = 1.0 - progress * 0.15;
      final tone = sin(2 * pi * 100 * bend * t) * 0.30 +
          sin(2 * pi * 130 * bend * t) * 0.25 +
          sin(2 * pi * 75 * bend * t) * 0.15;
      return _softClip((noise[i] * 0.45 + tone) * env * 0.20);
    });
    return _createWav(samples, _sr);
  }

  /// Juicy splat — main pimple pop burst (380ms)
  /// Satisfying low thump + round mid pop + wet tail. No harsh high crack.
  Uint8List _generateSplat() {
    const dur = 0.38;
    final n = (_sr * dur).round();
    final noise = _noise(n, seed: 55);
    _lowPass(noise, 0.85, passes: 3);

    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      // Sharp initial burst envelope
      final burstEnv = exp(-t * 30);
      // Longer wet tail
      final tailEnv = exp(-t * 4) * 0.45;
      // Low thump (deeper: 80 Hz)
      final thumpFreq = 80 * exp(-t * 8);
      final thump = sin(2 * pi * thumpFreq * t) * burstEnv * 0.45;
      // Round mid pop (450 Hz, no harsh 900 Hz crack)
      final splatFreq = 450 - 250 * (t / dur);
      final popTone = sin(2 * pi * splatFreq * t) * 0.15 * burstEnv;
      // Sub-bass "oomph" that peaks at 50ms
      final oomph = sin(2 * pi * 60 * t) * exp(-pow((t - 0.05) / 0.04, 2)) * 0.08;
      // Wet noise splash
      final wet = noise[i] * tailEnv;
      return _softClip((thump + popTone + oomph + wet) * 0.26);
    });
    return _createWav(samples, _sr);
  }

  /// Reward ding — gentle ascending two-note chime for combos (400ms)
  Uint8List _generateRewardDing() {
    const dur = 0.40;
    final n = (_sr * dur).round();
    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      // Note 1: C5 (523 Hz) from t=0
      final onset1 = min(t / 0.008, 1.0);
      final n1a = sin(2 * pi * 523 * t) * 0.45;
      final n1b = sin(2 * pi * 523.5 * t) * 0.45; // detuned pair
      final n1h = sin(2 * pi * 1046 * t) * 0.06; // octave
      final env1 = onset1 * exp(-t * 4);

      // Note 2: E5 (659 Hz) from t=80ms
      double note2 = 0;
      if (t >= 0.08) {
        final t2 = t - 0.08;
        final onset2 = min(t2 / 0.008, 1.0);
        final env2 = onset2 * exp(-t2 * 4);
        note2 = (sin(2 * pi * 659 * t2) * 0.45 +
                sin(2 * pi * 659.5 * t2) * 0.45 +
                sin(2 * pi * 1318 * t2) * 0.06) *
            env2;
      }
      return _softClip(((n1a + n1b + n1h) * env1 + note2) * 0.12);
    });
    return _createWav(samples, _sr);
  }

  /// Ambient pad — low drone for breathing background (3.0s)
  Uint8List _generateAmbientPad() {
    const dur = 3.0;
    final n = (_sr * dur).round();
    final noise = _noise(n, seed: 60);
    _lowPass(noise, 0.95, passes: 6);

    final samples = List<double>.generate(n, (i) {
      final t = i / _sr;
      // Slow envelope: 500ms fade in, sustain, 500ms fade out
      double env;
      if (t < 0.5) {
        env = t / 0.5;
      } else if (t > dur - 0.5) {
        env = (dur - t) / 0.5;
      } else {
        env = 1.0;
      }
      // Slow filter sweep (brightness LFO)
      final brightness = 1.0 + 0.1 * sin(2 * pi * 0.3 * t);
      // Detuned drones at A2 (110 Hz)
      final d1 = sin(2 * pi * 110 * t) * 0.35;
      final d2 = sin(2 * pi * 110.3 * t) * 0.35;
      final d3 = sin(2 * pi * 110.7 * t) * 0.30;
      // Fifth above: E3 (165 Hz)
      final f1 = sin(2 * pi * 165 * t) * 0.20;
      final f2 = sin(2 * pi * 165.4 * t) * 0.20;
      // Very gentle noise
      final air = noise[i] * 0.02;
      return _softClip((d1 + d2 + d3 + f1 + f2 + air) * brightness * env * 0.06);
    });
    return _createWav(samples, _sr);
  }

  /// Build 16-bit mono PCM WAV from float samples [-1, 1].
  Uint8List _createWav(List<double> samples, int sampleRate) {
    final numSamples = samples.length;
    final dataSize = numSamples * 2;
    final fileSize = 44 + dataSize;
    final buf = ByteData(fileSize);

    buf.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    buf.setUint32(4, fileSize - 8, Endian.little);
    buf.setUint32(8, 0x57415645, Endian.big); // "WAVE"

    buf.setUint32(12, 0x666D7420, Endian.big); // "fmt "
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, 1, Endian.little);
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, sampleRate * 2, Endian.little);
    buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);

    buf.setUint32(36, 0x64617461, Endian.big); // "data"
    buf.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      buf.setInt16(44 + i * 2, (clamped * 32767).round(), Endian.little);
    }

    return buf.buffer.asUint8List();
  }
}
