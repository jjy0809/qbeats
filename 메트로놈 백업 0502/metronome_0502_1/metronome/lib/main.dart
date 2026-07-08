import 'dart:collection';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
part 'main_layout.dart';

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await _initSvc();
  runApp(const MetronomeApp());
}

Future<void> _initSvc() async {

  return;
}

class MetronomeApp extends StatelessWidget {
  const MetronomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF202020);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: bg,
        useMaterial3: true,
      ),
      home: const MetronomeScreen(),
    );
  }
}

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class MemoryPreset {
  final int? bpm;
  final int? beats;
  final int? notes;

  const MemoryPreset({
    this.bpm,
    this.beats,
    this.notes,
  });

  const MemoryPreset.empty()
      : bpm = null,
        beats = null,
        notes = null;

  bool get hasValue =>
      bpm != null && beats != null && notes != null;

  @override
  bool operator ==(Object other) {
    return other is MemoryPreset &&
        other.bpm == bpm &&
        other.beats == beats &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(bpm, beats, notes);
}

MemoryPreset _defMem(int i) => switch (i) {
      0 => const MemoryPreset(bpm: 60, beats: 4, notes: 1),
      1 => const MemoryPreset(bpm: 90, beats: 4, notes: 1),
      2 => const MemoryPreset(bpm: 120, beats: 4, notes: 1),
      _ => const MemoryPreset.empty(),
    };

List<MemoryPreset> _defMemLst() =>
    List<MemoryPreset>.generate(40, _defMem);

class SettingSnapshot {
  final int bpm;
  final int beats;
  final int notes;
  final List<int> levels;
  final List<MemoryPreset> memories;
  final int? focusIndex;

  const SettingSnapshot({
    required this.bpm,
    required this.beats,
    required this.notes,
    required this.levels,
    required this.memories,
    required this.focusIndex,
  });

  bool sameAs(SettingSnapshot other) {
    if (bpm != other.bpm || beats != other.beats || notes != other.notes)
      return false;
    if (levels.length != other.levels.length) return false;
    for (int i = 0; i < levels.length; i++) {
      if (levels[i] != other.levels[i]) return false;
    }
    if (memories.length != other.memories.length) return false;
    for (int i = 0; i < memories.length; i++) {
      if (memories[i] != other.memories[i]) return false;
    }
    if (focusIndex != other.focusIndex) return false;
    return true;
  }
}

enum ClickKind {
  dgit1,
  dgit2,
  dgit3,
  anal1,
  anal2,
  anal3,
}

class ThemeOption {
  final String name;
  final Color color;

  const ThemeOption(this.name, this.color);
}

class _MetronomeScreenState extends State<MetronomeScreen>
    with WidgetsBindingObserver {
  double bpm = 89;
  int beatCount = 8;
  int noteCount = 1;
  bool isPlaying = false;

  bool _showMemoryGrid = false;
  bool _memCls = false;

  final List<int> beatLevels = List<int>.filled(8, 1);
  int _lastBpmInt = 89;
  int? _memFocusIdx;

  late List<MemoryPreset> memoryPresets = List<MemoryPreset>.generate(
    40,
    _defMem,
  );

  final List<SettingSnapshot> _history = <SettingSnapshot>[];

  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _clickSource;
  final ListQueue<SoundHandle> _hQ =
      ListQueue<SoundHandle>();

  Timer? _tickTimer;
  Timer? _undoTm;
  Timer? _bpmTm;
  Timer? _memDelTm;
  Stopwatch? _stopwatch;
  bool _memDelRan = false;

  int _activeBeatIndex = -1;
  int _pulseToken = 0;

  static const _bpmMin = 40.0;
  static const _bpmMax = 260.0;

  static const _kPrefBpm = 'bpm';
  static const _kPrefBeatCount = 'beatCount';
  static const _kPrefNoteCount = 'noteCount';
  static const _kPrefBeatLevels = 'beatLevels';
  static const _kPrefMemoryPresets = 'memoryPresets';
  static const _kPrefClickKind = 'clickKind';
  static const _kPrefThemeName = 'themeName';
  static const _kPrefMasterVol = 'masterVol';
  static const _kPrefBalance = 'balance';
  static const _kPrefKeepOn = 'keepScreenOn';
  static const _kPrefMix = 'soundMix';
  static const _kPrefBg = 'backgroundPlay';
  static const _kPrefFastBpmStep = 'fastBpmStep';
  static const _kPrefVibeClick = 'vibeClick';

  ClickKind _clickKind = ClickKind.dgit1;

  double _masterVolume = 1.0;
  double _balance = 0.0;

  bool _keepScreenOn = true;
  bool _soundMix = true;
  bool _backgroundPlay = true;
  int _fastBpmStep = 10;
  bool _vibeClick = false;

  static const List<ThemeOption> _themes = <ThemeOption>[
    ThemeOption('하늘', Color(0xFF18A8F1)),
    ThemeOption('파랑', Color(0xFF5D6DBE)),
    ThemeOption('빨강', Color(0xFFFF7048)),
    ThemeOption('주황', Color(0xFFFD9F28)),
    ThemeOption('노랑', Color(0xFFFDEB28)),
    ThemeOption('초록', Color(0xFF2FA599)),
    ThemeOption('연두', Color(0xFF7DB249)),
    ThemeOption('보라', Color(0xFF9A30AE)),
    ThemeOption('민트', Color(0xFF03EFD7)),
    ThemeOption('핑크', Color(0xFFF369FF)),
  ];

  ThemeOption _theme = _themes.first;

  AudioSession? _audioSession;
  bool _audOk = false;
  int _audSeq = 0;
  int _visSeq = 0;
  double _baseUs = 0.0;
  double _baseSeq = 0.0;
  double _stepUs = 0.0;

  static const int _audLeadUs = 8000;
  static const int _schMinUs = 1200;
  static const int _schMaxUs = 6000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF202020),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    _loadPrefs();
    _initAudio();
    _initAudioSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopMetronome();
    _undoTm?.cancel();
    _undoTm = null;
    _bpmTm?.cancel();
    _bpmTm = null;
    _memDelTm?.cancel();
    _memDelTm = null;
    if (_audOk && _clickSource != null) {

      try {

        _soloud.disposeSource(_clickSource!);
      } catch (_) {}
    }
    if (_audOk) {

      try {

        _soloud.deinit();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_backgroundPlay && state == AppLifecycleState.paused) {
      if (isPlaying) {
        _stopMetronome();
        setState(() => isPlaying = false);
      }
    }
  }

  SettingSnapshot _currentSnapshot() {
    return SettingSnapshot(
      bpm: bpm.round(),
      beats: beatCount,
      notes: noteCount,
      levels: List<int>.from(beatLevels),
      memories: List<MemoryPreset>.from(memoryPresets),
      focusIndex: _memFocusIdx,
    );
  }

  void _pushHistoryIfNeeded(SettingSnapshot snap) {
    if (_history.isNotEmpty && _history.last.sameAs(snap)) return;
    _history.add(snap);
    setState(() {});
  }

  void _undo() {
    if (_history.isEmpty) return;
    final s = _history.removeLast();
    setState(() {
      _lastBpmInt = bpm.round();
      bpm = s.bpm.toDouble().clamp(_bpmMin, _bpmMax);
      beatCount = s.beats.clamp(1, 8);
      noteCount = s.notes.clamp(1, 6);
      for (int i = 0; i < 8; i++) {
        beatLevels[i] = s.levels[i].clamp(1, 3);
      }
      memoryPresets = List<MemoryPreset>.from(s.memories);
      _memFocusIdx = s.focusIndex;
      _activeBeatIndex = -1;
      _pulseToken = 0;
    });
    _savePrefs();
    if (isPlaying) _restartMetronome();
  }

  void _stUndoHold() {

    if (_history.isEmpty) return;
    _undoTm?.cancel();
    _undoTm = null;
    _undo();
    _undoTm = Timer.periodic(const Duration(milliseconds: 200), (tm) {

      if (_history.isEmpty) {

        tm.cancel();
        if (identical(_undoTm, tm))
          _undoTm = null;
        return;
      }
      _undo();
    });
  }

  void _edUndoHold() {

    _undoTm?.cancel();
    _undoTm = null;
  }

  void _stBpmHold(int delta) {

    _bpmTm?.cancel();
    _bpmTm = null;
    _pushHistoryIfNeeded(_currentSnapshot());
    _setBpm(bpm + delta, recordHistory: false);
    _bpmTm = Timer.periodic(const Duration(milliseconds: 250), (_) {

      _setBpm(bpm + delta, recordHistory: false);
    });
  }

  void _edBpmHold() {

    _bpmTm?.cancel();
    _bpmTm = null;
  }

  Future<void> _loadPrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();

      final savedBpm = sp.getDouble(_kPrefBpm);
      final savedBeatCount = sp.getInt(_kPrefBeatCount);
      final savedNoteCount = sp.getInt(_kPrefNoteCount);

      final savedLevelsStr = sp.getString(_kPrefBeatLevels);
      final savedPresetsStr = sp.getString(_kPrefMemoryPresets);

      final savedClickKind = sp.getString(_kPrefClickKind);
      final savedThemeName = sp.getString(_kPrefThemeName);
      final savedMasterVol = sp.getDouble(_kPrefMasterVol);
      final savedBalance = sp.getDouble(_kPrefBalance);
      final savedKeepOn = sp.getBool(_kPrefKeepOn);
      final savedMix = sp.getBool(_kPrefMix);
      final savedBg = sp.getBool(_kPrefBg);
      final savedFastStep = sp.getInt(_kPrefFastBpmStep);
      final savedVibeClick = sp.getBool(_kPrefVibeClick);

      final List<int>? savedLevels = (savedLevelsStr == null)
          ? null
          : (jsonDecode(savedLevelsStr) as List)
              .map((e) => (e as num).toInt())
              .toList();

      final savedPresetRaw = savedPresetsStr == null
          ? null
          : jsonDecode(savedPresetsStr);

      if (!mounted) return;

      setState(() {
        if (savedBpm != null) {
          _lastBpmInt = bpm.round();
          bpm = savedBpm.clamp(_bpmMin, _bpmMax);
        }
        if (savedBeatCount != null) beatCount = savedBeatCount.clamp(1, 8);
        if (savedNoteCount != null) noteCount = savedNoteCount.clamp(1, 6);

        if (savedLevels != null && savedLevels.length == 8) {
          for (int i = 0; i < 8; i++) {
            beatLevels[i] = savedLevels[i].clamp(1, 3);
          }
        }

        if (savedPresetRaw is List) {
          final next = _defMemLst();
          if (savedPresetRaw.isNotEmpty &&
              savedPresetRaw.first is num &&
              savedPresetRaw.length >= 40 * 3) {
            bool sameOldDefault = true;
            for (int i = 0; i < 40; i++) {
              final b = (savedPresetRaw[i * 3 + 0] as num).toInt();
              final beats = (savedPresetRaw[i * 3 + 1] as num).toInt();
              final notes = (savedPresetRaw[i * 3 + 2] as num).toInt();
              if (b != 120 || beats != 4 || notes != 1) {
                sameOldDefault = false;
                break;
              }
            }
            if (sameOldDefault) {
              memoryPresets = next;
            } else {
              for (int i = 0; i < 40; i++) {
                final b = (savedPresetRaw[i * 3 + 0] as num).toInt();
                final beats = (savedPresetRaw[i * 3 + 1] as num).toInt();
                final notes = (savedPresetRaw[i * 3 + 2] as num).toInt();
                next[i] = MemoryPreset(
                  bpm: b.clamp(_bpmMin.toInt(), _bpmMax.toInt()),
                  beats: beats.clamp(1, 8),
                  notes: notes.clamp(1, 6),
                );
              }
              memoryPresets = next;
            }
          } else {
            for (int i = 0; i < math.min(savedPresetRaw.length, 40); i++) {
              final raw = savedPresetRaw[i];
              if (raw is! Map) continue;
              final bpmRaw = raw['bpm'];
              final beatsRaw = raw['beats'];
              final notesRaw = raw['notes'];
              if (bpmRaw is! num || beatsRaw is! num || notesRaw is! num)
                continue;
              next[i] = MemoryPreset(
                bpm: bpmRaw.toInt().clamp(_bpmMin.toInt(), _bpmMax.toInt()),
                beats: beatsRaw.toInt().clamp(1, 8),
                notes: notesRaw.toInt().clamp(1, 6),
              );
            }
          }
          if (!(savedPresetRaw.isNotEmpty &&
              savedPresetRaw.first is num &&
              savedPresetRaw.length >= 40 * 3))
            memoryPresets = next;
        }

        if (savedClickKind != null) {
          _clickKind = ClickKind.values.firstWhere(
            (e) => e.name == savedClickKind,
            orElse: () => ClickKind.dgit1,
          );
        }

        if (savedThemeName != null) {
          _theme = _themes.firstWhere(
            (t) => t.name == savedThemeName,
            orElse: () => _themes.first,
          );
        }

        if (savedMasterVol != null)
          _masterVolume = savedMasterVol.clamp(0.0, 3.0);

        if (savedBalance != null) _balance = savedBalance.clamp(-1.0, 1.0);
        if (savedKeepOn != null) _keepScreenOn = savedKeepOn;
        if (savedMix != null) _soundMix = savedMix;
        if (savedBg != null) _backgroundPlay = savedBg;
        if (savedFastStep != null)
          _fastBpmStep = savedFastStep.clamp(2, 100);
        if (savedVibeClick != null) _vibeClick = savedVibeClick;
      });

      _applyKeepScreenOn();
      _applyAudioSessionConfig();
      await _reloadClickSource();
    } catch (_) {}
  }

  Future<void> _savePrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();

      await sp.setDouble(_kPrefBpm, bpm);
      await sp.setInt(_kPrefBeatCount, beatCount);
      await sp.setInt(_kPrefNoteCount, noteCount);

      await sp.setString(_kPrefBeatLevels, jsonEncode(beatLevels));

      final mem = memoryPresets.map((p) {
        if (!p.hasValue) return null;
        return {
          'bpm': p.bpm,
          'beats': p.beats,
          'notes': p.notes,
        };
      }).toList();
      await sp.setString(_kPrefMemoryPresets, jsonEncode(mem));

      await sp.setString(_kPrefClickKind, _clickKind.name);
      await sp.setString(_kPrefThemeName, _theme.name);

      await sp.setDouble(_kPrefMasterVol, _masterVolume);

      await sp.setDouble(_kPrefBalance, _balance);
      await sp.setBool(_kPrefKeepOn, _keepScreenOn);
      await sp.setBool(_kPrefMix, _soundMix);
      await sp.setBool(_kPrefBg, _backgroundPlay);
      await sp.setInt(_kPrefFastBpmStep, _fastBpmStep);
      await sp.setBool(_kPrefVibeClick, _vibeClick);
    } catch (_) {}
  }

  Future<void> _initAudio() async {

    try {

      await _soloud.init(
          sampleRate: 48000,
          bufferSize: 256,
          channels: Channels.stereo);
      _audOk = true;
      await _reloadClickSource();
    } catch (_) {

      _audOk = false;
    }
  }

  Future<void> _initAudioSession() async {
    try {
      _audioSession = await AudioSession.instance;
      await _applyAudioSessionConfig();
    } catch (_) {}
  }

  Future<void> _applyAudioSessionConfig() async {
    try {
      final s = _audioSession;
      if (s == null) return;

      final config = AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            _soundMix ? AVAudioSessionCategoryOptions.mixWithOthers : null,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: _soundMix
            ? AndroidAudioFocusGainType.gainTransientMayDuck
            : AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: !_soundMix,
      );

      await s.configure(config);
      await s.setActive(true);
    } catch (_) {}
  }

  Future<void> _applyKeepScreenOn() async {
    try {
      if (_keepScreenOn) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  String _clickAssetForKind(ClickKind k) {
    switch (k) {
      case ClickKind.dgit1:
        return 'assets/sound/dgit1.wav';
      case ClickKind.dgit2:
        return 'assets/sound/dgit2.wav';
      case ClickKind.dgit3:
        return 'assets/sound/dgit3.wav';
      case ClickKind.anal1:
        return 'assets/sound/anal1.wav';
      case ClickKind.anal2:
        return 'assets/sound/anal2.wav';
      case ClickKind.anal3:
        return 'assets/sound/anal3.wav';
    }
  }

  String _clickLabel(ClickKind k) {
    switch (k) {
      case ClickKind.dgit1:
        return '디지털 1';
      case ClickKind.dgit2:
        return '디지털 2';
      case ClickKind.dgit3:
        return '디지털 3';
      case ClickKind.anal1:
        return '아날로그 1';
      case ClickKind.anal2:
        return '아날로그 2';
      case ClickKind.anal3:
        return '아날로그 3';
    }
  }

  Duration _clickTrimForKind(ClickKind k) {

    switch (k) {

      case ClickKind.dgit1:
        return const Duration(milliseconds: 135);
      case ClickKind.dgit2:
        return const Duration(milliseconds: 23);
      case ClickKind.dgit3:
        return const Duration(milliseconds: 83);
      case ClickKind.anal1:
        return const Duration(milliseconds: 128);
      case ClickKind.anal2:
        return const Duration(milliseconds: 130);
      case ClickKind.anal3:
        return const Duration(milliseconds: 110);
    }
  }

  double _calcStepUs({double? bpmVal, int? noteVal}) {

    final bpmNum = bpmVal ?? bpm;
    final noteNum = noteVal ?? noteCount;
    return 60000000.0 / bpmNum / noteNum;
  }

  void _retimeBpm(double nextBpm) {

    final sw = _stopwatch;
    if (!isPlaying || sw == null || _stepUs <= 0)
      return;
    final nowUs =
        sw.elapsedMicroseconds.toDouble();
    final pos =
        _baseSeq + ((nowUs - _baseUs) / _stepUs);
    _baseUs = nowUs;
    _baseSeq = pos;
    _stepUs = _calcStepUs(
        bpmVal: nextBpm, noteVal: noteCount);
    _tickTimer?.cancel();
    _runTickLoop();
  }

  Uint8List _trimWav(Uint8List src, Duration cut) {

    if (src.length < 44 || cut <= Duration.zero)
      return src;
    final bd = ByteData.sublistView(src);
    if (String.fromCharCodes(src.sublist(0, 4)) != 'RIFF')
      return src;
    if (String.fromCharCodes(src.sublist(8, 12)) != 'WAVE')
      return src;
    int fmtOff = -1;
    int dataOff = -1;
    int dataLen = -1;
    int off = 12;
    while (off + 8 <= src.length) {

      final id =
          String.fromCharCodes(src.sublist(off, off + 4));
      final len = bd.getUint32(off + 4, Endian.little);
      final bodyOff = off + 8;
      if (id == 'fmt ') fmtOff = bodyOff;
      if (id == 'data') {

        dataOff = bodyOff;
        dataLen = len;
        break;
      }
      off = bodyOff + len + (len.isOdd ? 1 : 0);
    }
    if (fmtOff < 0 || dataOff < 0 || dataLen <= 0)
      return src;
    final sampleRate = bd.getUint32(fmtOff + 4, Endian.little);
    final blockAlign =
        bd.getUint16(fmtOff + 12, Endian.little);
    if (sampleRate <= 0 || blockAlign <= 0)
      return src;
    final cutBytes =
        (((cut.inMicroseconds * sampleRate) / 1000000).floor() * blockAlign)
            .clamp(0, dataLen);
    if (cutBytes <= 0 || cutBytes >= dataLen)
      return src;
    final headLen = dataOff;
    final newDataLen = dataLen - cutBytes;
    final out = Uint8List(headLen + newDataLen);
    out.setRange(0, headLen, src);
    out.setRange(
        headLen,
        headLen + newDataLen,
        src.sublist(
            dataOff + cutBytes, dataOff + dataLen));
    final outBd = ByteData.sublistView(out);
    outBd.setUint32(
        4, out.length - 8, Endian.little);
    outBd.setUint32(dataOff - 4, newDataLen,
        Endian.little);
    return out;
  }

  Future<void> _reloadClickSource() async {

    if (!_audOk) return;
    try {

      final nextAsset =
          _clickAssetForKind(_clickKind);
      if (_clickSource != null) {

        _soloud.disposeSource(_clickSource!);
        _clickSource = null;
      }
      final raw = await rootBundle.load(nextAsset);
      final buf = Uint8List.sublistView(raw);
      final trim = _trimWav(
          buf, _clickTrimForKind(_clickKind));
      _clickSource =
          await _soloud.loadMem(nextAsset, trim);
    } catch (_) {}
  }

  void _setBeatCount(int v, {bool recordHistory = true}) {
    if (recordHistory) _pushHistoryIfNeeded(_currentSnapshot());
    final prev = beatCount;
    setState(() {
      beatCount = v.clamp(1, 8);
      if (beatCount > prev) {
        for (int i = prev; i < beatCount; i++) {
          beatLevels[i] = 1;
        }
      }
    });
    _savePrefs();
    if (isPlaying) _restartMetronome();
  }

  void _setNoteCount(int v, {bool recordHistory = true}) {
    if (recordHistory) _pushHistoryIfNeeded(_currentSnapshot());
    setState(() => noteCount = v.clamp(1, 6));
    _savePrefs();
    if (isPlaying) _restartMetronome();
  }

  void _cycleBeatLevel(int index) {
    _pushHistoryIfNeeded(_currentSnapshot());
    setState(() {
      final cur = beatLevels[index];
      beatLevels[index] = (cur % 3) + 1;
    });
    _savePrefs();
  }

  void _setBpm(double v, {bool recordHistory = true}) {
    if (recordHistory) _pushHistoryIfNeeded(_currentSnapshot());
    final next = v.clamp(_bpmMin, _bpmMax);
    final prevInt = bpm.round();
    final nextInt = next.round();
    setState(() {
      if (nextInt != prevInt)
        _lastBpmInt = prevInt;
      bpm = next;
    });
    if (isPlaying) _retimeBpm(next);
    _savePrefs();
  }

  void _previewBpm(double v) {

    final next = v.clamp(_bpmMin, _bpmMax);
    final prevInt = bpm.round();
    final nextInt = next.round();
    setState(() {

      if (nextInt != prevInt)
        _lastBpmInt = prevInt;
      bpm = next;
    });
    if (isPlaying) _retimeBpm(next);
  }

  void _changeBpmBy(int delta, {bool recordHistory = true}) =>
      _setBpm(bpm + delta, recordHistory: recordHistory);

  bool _isPresetActive(MemoryPreset p) {
    if (!p.hasValue) return false;
    return bpm.round() == p.bpm &&
        beatCount == p.beats &&
        noteCount == p.notes;
  }

  void _applyPreset(MemoryPreset p,
      {bool recordHistory = true, int? index}) {
    if (!p.hasValue) return;
    if (recordHistory) _pushHistoryIfNeeded(_currentSnapshot());
    final idx = memoryPresets.indexOf(p);
    setState(() {
      _lastBpmInt = bpm.round();
      bpm = p.bpm!.toDouble();
      beatCount = p.beats!.clamp(1, 8);
      noteCount = p.notes!.clamp(1, 6);
      _memFocusIdx = index ?? (idx >= 0 ? idx : _memFocusIdx);
      for (int i = 0; i < 8; i++) {
        beatLevels[i] = 1;
      }
    });
    _savePrefs();
    if (isPlaying) _restartMetronome();
  }

  void _savePreset(int index) {
    _pushHistoryIfNeeded(_currentSnapshot());
    final p =
        MemoryPreset(bpm: bpm.round(), beats: beatCount, notes: noteCount);
    setState(() {
      memoryPresets[index] = p;
      _memFocusIdx = index;
    });
    unawaited(HapticFeedback.lightImpact());
    _savePrefs();
  }

  void _resetPresetAt(int index) {
    if (index < 0 || index >= memoryPresets.length - 1) return;
    _pushHistoryIfNeeded(_currentSnapshot());
    setState(() {
      memoryPresets[index] = _defMem(index);
      if (_memFocusIdx == index)
        _memFocusIdx = null;
    });
    _savePrefs();
  }

  void _resetAllPresets() {
    _pushHistoryIfNeeded(_currentSnapshot());
    setState(() {
      memoryPresets = _defMemLst();
      _memFocusIdx = null;
    });
    _savePrefs();
    unawaited(HapticFeedback.mediumImpact());
  }

  void _tapDeletePreset() {
    final idx = _memFocusIdx;
    if (idx == null) return;
    _resetPresetAt(idx);
  }

  void _stDeletePresetHold() {
    _memDelTm?.cancel();
    _memDelTm = null;
    _memDelRan = false;
    _memDelTm = Timer(const Duration(seconds: 1), () {
      _memDelTm = null;
      _memDelRan = true;
      _resetAllPresets();
    });
  }

  void _edDeletePresetHold({required bool allowTap}) {
    final ran = _memDelRan;
    _memDelTm?.cancel();
    _memDelTm = null;
    _memDelRan = false;
    if (allowTap && !ran) _tapDeletePreset();
  }

  void _fireHpt(int lvl, int subIdx) {
    if (!_vibeClick) return;
    if (!isPlaying) return;
    if (lvl >= 3) return;
    final lvlMul = lvl == 1 ? 1.0 : 0.55;
    final subMul = subIdx == 0
        ? 1.0
        : (1.0 / noteCount).clamp(0.22, 0.55);
    final volMul = (_masterVolume / 3.0).clamp(0.0, 1.0);
    final pow = (lvlMul * subMul * volMul).clamp(0.0, 1.0);
    if (pow <= 0) return;
    if (pow >= 0.62) {
      unawaited(HapticFeedback.mediumImpact());
      return;
    }
    if (pow >= 0.28) {
      unawaited(HapticFeedback.lightImpact());
      return;
    }
    unawaited(HapticFeedback.selectionClick());
  }

  void _openMemoryGrid() {
    setState(() {
      _memCls = false;
      _showMemoryGrid = true;
    });
  }

  void _closeMemoryGrid() {
    if (!_showMemoryGrid || _memCls) return;
    setState(() => _memCls = true);
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _showMemoryGrid = false;
        _memCls = false;
      });
    });
  }

  Future<void> _togglePlay() async {

    if (isPlaying) {

      _stopMetronome();
      setState(() => isPlaying = false);
      return;
    }
    setState(() => isPlaying = true);
    final ok = await _startMetronome();
    if (!ok && mounted) {

      setState(() => isPlaying = false);
    }
  }

  Future<void> _restartMetronome() async {

    if (!isPlaying) return;
    _stopMetronome();
    final ok = await _startMetronome();
    if (!ok && mounted) {

      setState(() => isPlaying = false);
    }
  }

  Future<bool> _startMetronome() async {

    if (_clickSource == null) {

      await _reloadClickSource();
    }
    if (_clickSource == null) return false;
    _tickTimer?.cancel();
    _stopwatch?.stop();
    _stopwatch = Stopwatch()..start();
    _hQ.clear();
    _stepUs =
        _calcStepUs(bpmVal: bpm, noteVal: noteCount);
    _baseUs = _stopwatch!.elapsedMicroseconds
        .toDouble();
    _baseSeq = 0.0;
    _audSeq = 1;
    _visSeq = 1;
    _activeBeatIndex = -1;
    _pulseToken = 0;
    _fireAud(0);
    _fireVis(0);
    _runTickLoop();
    return true;
  }

  void _stopMetronome() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    _baseUs = 0.0;
    _baseSeq = 0.0;
    _stepUs = 0.0;
    _activeBeatIndex = -1;
    _pulseToken = 0;
    _stopAllSounds();
  }

  Future<void> _stopAllSounds() async {

    if (!_audOk) {

      _hQ.clear();
      return;
    }
    final lst = _hQ.toList(growable: false);
    _hQ.clear();
    try {

      for (final h in lst) {

        unawaited(_soloud.stop(h));
      }
    } catch (_) {}
  }

  void _runTickLoop() {

    final sw = _stopwatch;
    if (sw == null || !isPlaying || !mounted) return;
    final nowUs =
        sw.elapsedMicroseconds.toDouble();
    if (_stepUs <= 0)
      _stepUs = _calcStepUs(
          bpmVal: bpm, noteVal: noteCount);
    while (_audSeq <= _visSeq + 1) {

      final tgtUs = _baseUs +
          ((_audSeq - _baseSeq) * _stepUs);
      if (nowUs + _audLeadUs < tgtUs) break;
      _fireAud(_audSeq);
      _audSeq++;
    }
    while (true) {

      final tgtUs = _baseUs +
          ((_visSeq - _baseSeq) * _stepUs);
      if (nowUs < tgtUs) break;
      _fireVis(_visSeq);
      _visSeq++;
    }
    final nextAudUs = (_baseUs + ((_audSeq - _baseSeq) * _stepUs)) -
        _audLeadUs;
    final nextVisUs =
        _baseUs + ((_visSeq - _baseSeq) * _stepUs);
    final nextUs = math.min(nextAudUs, nextVisUs);
    final waitUs = (nextUs - sw.elapsedMicroseconds)
        .clamp(_schMinUs.toDouble(), _schMaxUs.toDouble())
        .round();
    _tickTimer?.cancel();
    _tickTimer = Timer(Duration(microseconds: waitUs),
        _runTickLoop);
  }

  void _fireVis(int seq) {

    final beatIdx = (seq ~/ noteCount) % beatCount;
    final subIdx = seq % noteCount;
    if (subIdx != 0) return;
    if (!mounted) return;
    setState(() {

      _activeBeatIndex = beatIdx;
      _pulseToken++;
    });
  }

  void _fireAud(int seq) {

    final src = _clickSource;
    if (!_audOk || src == null || !isPlaying) return;
    final beatIdx = (seq ~/ noteCount) % beatCount;
    final subIdx = seq % noteCount;
    final lvl = beatLevels[beatIdx];
    final baseVol = (lvl == 1)
        ? 1.0
        : (lvl == 2)
            ? 0.5
            : 0.0;
    final vol = baseVol *
        (subIdx == 0 ? 1.0 : 0.5) *
        _masterVolume;
    if (vol <= 0) return;
    _fireHpt(lvl, subIdx);
    unawaited(_playClick(src, vol));
  }

  Future<void> _playClick(AudioSource src, double vol) async {

    try {

      final h = await _soloud.play(src,
          volume: vol, pan: _balance);
      _hQ.addLast(h);
      while (_hQ.length > 8) {

        _hQ.removeFirst();
      }
    } catch (_) {}
  }

  Future<void> _openTapTempoSheet() async {
    final cPrimary = _theme.color;
    const cPanel = Color(0xFF303030);
    const cText = Color(0xFFEEEEEE);

    final pressOverlay = cPrimary.withValues(alpha: 0.18);

    final taps = <int>[];
    bool pushed = false;

    void registerTap(StateSetter setSheet) {
      final now = DateTime.now().millisecondsSinceEpoch;

      if (taps.isNotEmpty && now - taps.last > 2000) {
        taps.clear();
      }
      taps.add(now);

      if (taps.length < 2) {
        setSheet(() {});
        return;
      }

      final intervals = <int>[];
      for (int i = math.max(1, taps.length - 7); i < taps.length; i++) {
        intervals.add(taps[i] - taps[i - 1]);
      }

      final avg = intervals.reduce((a, b) => a + b) / intervals.length;
      if (avg <= 0) return;

      final calc = (60000.0 / avg).clamp(_bpmMin, _bpmMax);

      if (!pushed) {
        _pushHistoryIfNeeded(_currentSnapshot());
        pushed = true;
      }

      setState(() {
        _lastBpmInt = bpm.round();
        bpm = calc;
      });
      _savePrefs();
      if (isPlaying) _restartMetronome();

      setSheet(() {});
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final shownBpm = bpm.round();

            final screenH = MediaQuery.of(context).size.height;
            final sheetH = screenH * 0.55 * 0.7;

            return SafeArea(
              top: false,
              child: Container(
                height: sheetH,
                decoration: const BoxDecoration(
                  color: cPanel,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(34),
                    topRight: Radius.circular(34),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: LayoutBuilder(
                  builder: (context, cs) {
                    const fixedTop = 6.0 + 18.0 + 22.0 + 14.0;
                    const fixedBottom = 12.0 + 30.0;
                    final avail = (cs.maxHeight - fixedTop - fixedBottom)
                        .clamp(0.0, cs.maxHeight);
                    final tapH = avail * 0.8;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 56,
                            height: 6,
                            decoration: BoxDecoration(
                              color: cPrimary.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'BPM: $shownBpm',
                          style: const TextStyle(
                            color: cText,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 25),
                        SizedBox(
                          height: tapH,
                          child: Material(
                            color: cPrimary.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(26),
                            child: InkWell(
                              onTap: () => registerTap(setSheet),
                              borderRadius: BorderRadius.circular(26),
                              overlayColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.pressed))
                                  return pressOverlay;
                                return Colors.transparent;
                              }),
                              child: Center(
                                child: Image.asset(
                                  'assets/icons/light/hand.png',
                                  width: 90,
                                  height: 90,
                                  color: cText.withValues(alpha: 0.6),
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 30,
                          child: Opacity(
                            opacity: 0.0,
                            child: Material(
                              child: Container(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSettingsSheet() async {
    const cPanel = Color(0xFF303030);
    const cBg = Color(0xFF202020);
    const cText = Color(0xFFEEEEEE);

    ClickKind localClickKind = _clickKind;
    ThemeOption localTheme = _theme;
    double localVol = _masterVolume;
    double localBal = _balance;
    bool localKeep = _keepScreenOn;
    bool localMix = _soundMix;
    bool localBg = _backgroundPlay;
    int localFastStep = _fastBpmStep;
    bool localVibeClick = _vibeClick;
    final fastCtrl = TextEditingController(text: '$localFastStep');

    double snapVolume(double v) {
      if ((v - 1.0).abs() <= 0.05) return 1.0;
      if ((v - 2.0).abs() <= 0.05) return 2.0;
      return v;
    }

    double snapBalance(double v) {
      if (v.abs() <= 0.05) return 0.0;
      return v;
    }

    Future<void> applyAll(StateSetter setSheet) async {
      setState(() {
        _clickKind = localClickKind;
        _theme = localTheme;
        _masterVolume = localVol;
        _balance = localBal;
        _keepScreenOn = localKeep;
        _soundMix = localMix;
        _backgroundPlay = localBg;
        _fastBpmStep = localFastStep;
        _vibeClick = localVibeClick;
      });

      await _savePrefs();
      await _applyKeepScreenOn();
      await _applyAudioSessionConfig();
      await _reloadClickSource();

      setSheet(() {});
    }

    Future<void> syncFast(StateSetter setSheet) async {
      final raw = fastCtrl.text.trim();
      final next = int.tryParse(raw);
      if (next == null || next < 2 || next > 100) {
        fastCtrl.text = '$localFastStep';
        fastCtrl.selection = TextSelection.collapsed(
            offset: fastCtrl.text.length);
        setSheet(() {});
        return;
      }
      if (next == localFastStep) {
        fastCtrl.text = '$localFastStep';
        fastCtrl.selection = TextSelection.collapsed(
            offset: fastCtrl.text.length);
        return;
      }
      localFastStep = next;
      await applyAll(setSheet);
      fastCtrl.text = '$localFastStep';
      fastCtrl.selection = TextSelection.collapsed(
          offset: fastCtrl.text.length);
      setSheet(() {});
    }

    Future<void> stepFast(int delta, StateSetter setSheet) async {
      final next = (localFastStep + delta).clamp(2, 100);
      if (next == localFastStep) return;
      localFastStep = next;
      fastCtrl.text = '$localFastStep';
      fastCtrl.selection = TextSelection.collapsed(
          offset: fastCtrl.text.length);
      await applyAll(setSheet);
      setSheet(() {});
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final pressOverlay =
                localTheme.color.withValues(alpha: 0.18);
            Widget sectionTitle(String t) {
              return Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: cText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }

            Widget rowTile({required Widget left, required Widget right}) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: left),
                    const SizedBox(width: 16),
                    right,
                  ],
                ),
              );
            }

            final volPct = (localVol.clamp(0.0, 3.0) * 100).round();

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.68,
                decoration: const BoxDecoration(
                  color: cPanel,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(34),
                    topRight: Radius.circular(34),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 6,
                        decoration: BoxDecoration(
                          color: localTheme.color.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            rowTile(
                              left: const Text(
                                '클릭 종류',
                                style: TextStyle(
                                  color: cText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              right: PopupSelectButton<ClickKind>(
                                value: localClickKind,
                                items: ClickKind.values,
                                overlayColor: pressOverlay,
                                itemHeight: 48,
                                menuTextStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: cText,
                                  height: 1.0,
                                ),
                                menuBg: cBg,
                                anchorWidth: 280,
                                menuMinWidth: 220,
                                menuMaxWidth: 260,
                                buildSelected: (ctx, v) => Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _clickLabel(v),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: cText,
                                    ),
                                  ),
                                ),
                                buildItem: (ctx, v) => Center(
                                  child: Text(
                                    _clickLabel(v),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: cText,
                                    ),
                                  ),
                                ),
                                onChanged: (v) async {
                                  localClickKind = v;
                                  await applyAll(setSheet);
                                },
                              ),
                            ),
                            rowTile(
                              left: const Text(
                                '테마',
                                style: TextStyle(
                                  color: cText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              right: PopupSelectButton<ThemeOption>(
                                value: localTheme,
                                items: _themes,
                                overlayColor: pressOverlay,
                                itemHeight: 48,
                                menuTextStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: cText,
                                  height: 1.0,
                                ),
                                menuBg: cBg,
                                anchorWidth: 280,
                                menuMinWidth: 220,
                                menuMaxWidth: 260,
                                menuMaxHeight:
                                    MediaQuery.of(context).size.height * 0.34,
                                buildSelected: (ctx, v) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: v.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        v.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: cText,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                                buildItem: (ctx, v) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: v.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        v.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: cText,
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                                onChanged: (v) async {
                                  localTheme = v;
                                  await applyAll(setSheet);
                                },
                              ),
                            ),
                            const SizedBox(height: 18),
                            sectionTitle('클릭 음량: $volPct%'),
                            Row(
                              children: [
                                Image.asset(
                                  'assets/icons/light/mute.png',
                                  width: 34,
                                  height: 34,
                                  color: cText,
                                  filterQuality: FilterQuality.high,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 6,
                                      activeTrackColor: localTheme.color,
                                      inactiveTrackColor: cText.withValues(alpha: 0.7),
                                      thumbColor: localTheme.color,
                                      overlayColor: localTheme.color.withValues(alpha: 0.18),
                                      thumbShape: const TallOvalThumbShape(width: 19.5, height: 34.5),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                                      trackShape: MarkedSliderTrackShape(
                                        min: 0.0,
                                        max: 3.0,
                                        marks: const [1.0, 2.0],
                                        markColor: cText.withValues(alpha: 0.7),
                                        markWidth: 4.5,
                                      ),
                                    ),
                                    child: Slider(
                                      min: 0.0,
                                      max: 3.0,
                                      value: localVol.clamp(0.0, 3.0),
                                      onChanged: (v) {
                                        final next = snapVolume(v.clamp(0.0, 3.0));
                                        setSheet(() => localVol = next);
                                      },
                                      onChangeEnd: (v) async {
                                        final snapped = snapVolume(v.clamp(0.0, 3.0));
                                        localVol = snapped;
                                        await applyAll(setSheet);
                                        setSheet(() => localVol = snapped);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Image.asset(
                                  'assets/icons/light/volume.png',
                                  width: 34,
                                  height: 34,
                                  color: cText,
                                  filterQuality: FilterQuality.high,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            sectionTitle('좌우 소리 균형'),
                            Row(
                              children: [
                                Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..rotateY(math.pi),
                                  child: Image.asset(
                                    'assets/icons/light/arrows.png',
                                    width: 34,
                                    height: 34,
                                    color: cText,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 6,
                                      activeTrackColor: localTheme.color,
                                      inactiveTrackColor: cText.withValues(alpha: 0.7),
                                      thumbColor: localTheme.color,
                                      overlayColor: localTheme.color.withValues(alpha: 0.18),
                                      thumbShape: const TallOvalThumbShape(width: 19.5, height: 34.5),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                                      trackShape: MarkedSliderTrackShape(
                                        min: -1.0,
                                        max: 1.0,
                                        marks: const [0.0],
                                        markColor: cText.withValues(alpha: 0.7),
                                        markWidth: 4.5,
                                      ),
                                    ),
                                    child: Slider(
                                      min: -1.0,
                                      max: 1.0,
                                      value: localBal.clamp(-1.0, 1.0),
                                      onChanged: (v) {
                                        final next = snapBalance(v.clamp(-1.0, 1.0));
                                        setSheet(() => localBal = next);
                                      },
                                      onChangeEnd: (v) async {
                                        final snapped = snapBalance(v.clamp(-1.0, 1.0));
                                        localBal = snapped;
                                        await applyAll(setSheet);
                                        setSheet(() => localBal = snapped);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Image.asset(
                                  'assets/icons/light/arrows.png',
                                  width: 34,
                                  height: 34,
                                  color: cText,
                                  filterQuality: FilterQuality.high,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            rowTile(
                              left: const Text(
                                '빠른 BPM 조정',
                                style: TextStyle(
                                  color: cText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              right: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _StepValueButton(
                                    asset: 'assets/icons/light/minus.png',
                                    bg: cBg,
                                    color: cText,
                                    overlayColor: pressOverlay,
                                    borderColor:
                                        localTheme.color.withValues(alpha: 0.38),
                                    onTap: () async {
                                      await stepFast(-1, setSheet);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 122,
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        textSelectionTheme:
                                            TextSelectionThemeData(
                                          cursorColor: localTheme.color,
                                          selectionColor: localTheme.color
                                              .withValues(alpha: 0.28),
                                          selectionHandleColor:
                                              localTheme.color,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: fastCtrl,
                                        cursorColor: localTheme.color,
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        style: const TextStyle(
                                          color: cText,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14, vertical: 12),
                                          filled: true,
                                          fillColor: cBg,
                                          hintText: '2~100',
                                          hintStyle: TextStyle(
                                            color: cText.withValues(alpha: 0.42),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color: localTheme.color
                                                  .withValues(alpha: 0.38),
                                              width: 1.2,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color: localTheme.color,
                                              width: 1.4,
                                            ),
                                          ),
                                        ),
                                        onSubmitted: (_) async {
                                          await syncFast(setSheet);
                                        },
                                        onTapOutside: (_) async {
                                          FocusScope.of(context).unfocus();
                                          await syncFast(setSheet);
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _StepValueButton(
                                    asset: 'assets/icons/light/plus.png',
                                    bg: cBg,
                                    color: cText,
                                    overlayColor: pressOverlay,
                                    borderColor:
                                        localTheme.color.withValues(alpha: 0.38),
                                    onTap: () async {
                                      await stepFast(1, setSheet);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _SettingSwitchRow(
                              title: '화면 유지',
                              value: localKeep,
                              primary: localTheme.color,
                              onChanged: (v) async {
                                setSheet(() => localKeep = v);
                                await applyAll(setSheet);
                              },
                            ),
                            _SettingSwitchRow(
                              title: '소리 혼합',
                              value: localMix,
                              primary: localTheme.color,
                              onChanged: (v) async {
                                setSheet(() => localMix = v);
                                await applyAll(setSheet);
                              },
                            ),
                            _SettingSwitchRow(
                              title: '백그라운드',
                              value: localBg,
                              primary: localTheme.color,
                              onChanged: (v) async {
                                setSheet(() => localBg = v);
                                await applyAll(setSheet);
                              },
                            ),
                            _SettingSwitchRow(
                              title: '진동 클릭',
                              value: localVibeClick,
                              primary: localTheme.color,
                              onChanged: (v) async {
                                setSheet(() => localVibeClick = v);
                                await applyAll(setSheet);
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 30,
                              child: Opacity(
                                opacity: 0.0,
                                child: Material(child: Container()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    fastCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return _buildRspScf(context);
  }
}

class _SettingSwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final Color primary;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchRow({
    required this.title,
    required this.value,
    required this.primary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const cText = Color(0xFFEEEEEE);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: cText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class BeatCircles extends StatelessWidget {
  final int count;
  final double areaWidth;
  final Color primary;
  final Color baseOverlay;
  final List<int> levels;
  final int activeIndex;
  final int pulseToken;
  final void Function(int index) onTapBeat;

  const BeatCircles({
    super.key,
    required this.count,
    required this.areaWidth,
    required this.primary,
    required this.baseOverlay,
    required this.levels,
    required this.activeIndex,
    required this.pulseToken,
    required this.onTapBeat,
  });

  @override
  Widget build(BuildContext context) {
    final cell = areaWidth / 4.0;
    final bigD = cell * 0.80;
    final smallD = cell * 0.63;
    final tinyD = cell * 0.52;
    final gap = (cell * 0.22).clamp(16.0, 56.0);

    Widget beatCircle(int index, bool visible) {
      if (!visible) return SizedBox(width: cell, height: cell);

      final level = levels[index];
      final d = (level == 1)
          ? bigD
          : (level == 2)
              ? smallD
              : tinyD;

      final bool isActive = index == activeIndex;
      final double alphaBase = (level == 1)
          ? 0.7
          : (level == 2)
              ? 0.6
              : 0.3;
      final color = primary.withValues(alpha: isActive ? 1.0 : alphaBase);

      return SizedBox(
        width: cell,
        height: cell,
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey('b$index-${isActive ? pulseToken : 0}'),
            tween: Tween<double>(begin: isActive ? 1.12 : 1.0, end: 1.0),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            builder: (context, s, child) =>
                Transform.scale(scale: s, child: child),
            child: SizedBox(
              width: d,
              height: d,
              child: Material(
                color: color,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => onTapBeat(index),
                  customBorder: const CircleBorder(),
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed))
                      return baseOverlay;
                    if (states.contains(WidgetState.hovered))
                      return baseOverlay.withValues(alpha: 0.08);
                    return Colors.transparent;
                  }),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final row1 = <Widget>[
      beatCircle(0, count >= 1),
      beatCircle(1, count >= 2),
      beatCircle(2, count >= 3),
      beatCircle(3, count >= 4),
    ];

    final row2 = <Widget>[
      beatCircle(4, count >= 5),
      beatCircle(5, count >= 6),
      beatCircle(6, count >= 7),
      beatCircle(7, count >= 8),
    ];

    final totalH = cell * 2 + gap;

    if (count <= 4) {
      return SizedBox(
        width: areaWidth,
        height: totalH,
        child: Column(
          children: [
            const Spacer(),
            Row(children: row1),
            const Spacer(),
          ],
        ),
      );
    }

    return SizedBox(
      width: areaWidth,
      height: totalH,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: row1),
          SizedBox(height: gap),
          Row(children: row2),
        ],
      ),
    );
  }
}

class PopupNumberSelect extends StatelessWidget {
  final int value;
  final List<int> items;
  final double scale;
  final Color color;
  final Color overlayColor;
  final ValueChanged<int> onChanged;

  const PopupNumberSelect({
    super.key,
    required this.value,
    required this.items,
    required this.scale,
    required this.color,
    required this.overlayColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedStyle = TextStyle(
      fontSize: (48.0 * scale.clamp(0.76, 1.06))
          .clamp(34.0, 56.0),
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
    );

    final menuStyle = TextStyle(
      fontSize: 26 * scale.clamp(0.70, 1.0),
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
    );

    final itemH = (38.0 * scale.clamp(0.70, 1.0))
        .clamp(28.0, 42.0);

    return PopupSelectButton<int>(
      value: value,
      items: items,
      overlayColor: overlayColor,
      itemHeight: itemH,
      menuTextStyle: menuStyle,
      menuBg: const Color(0xFF202020),
      anchorWidth: (116.0 * scale.clamp(0.78, 1.08))
          .clamp(92.0, 132.0),
      menuMinWidth: (88.0 * scale.clamp(0.78, 1.08))
          .clamp(80.0, 106.0),
      menuMaxWidth: (108.0 * scale.clamp(0.78, 1.08))
          .clamp(94.0, 124.0),
      buildSelected: (ctx, v) =>
          Center(child: Text('$v', style: selectedStyle)),
      buildItem: (ctx, v) => Center(child: Text('$v', style: menuStyle)),
      onChanged: onChanged,
    );
  }
}

class PopupNoteSelect extends StatelessWidget {
  final int value;
  final List<int> items;
  final double scale;
  final Color color;
  final Color overlayColor;
  final String noteAsset;
  final ValueChanged<int> onChanged;

  const PopupNoteSelect({
    super.key,
    required this.value,
    required this.items,
    required this.scale,
    required this.color,
    required this.overlayColor,
    required this.noteAsset,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedNumStyle = TextStyle(
      fontSize: (40.0 * scale.clamp(0.76, 1.06))
          .clamp(30.0, 48.0),
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
    );

    final menuStyle = TextStyle(
      fontSize: 26 * scale.clamp(0.70, 1.0),
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
    );

    final noteSelected = (46.0 * scale.clamp(0.76, 1.06))
        .clamp(32.0, 56.0);
    final noteMenu = (24.0 * scale.clamp(0.70, 1.0))
        .clamp(18.0, 28.0);
    final itemH = (38.0 * scale.clamp(0.70, 1.0))
        .clamp(28.0, 42.0);

    Widget row(
        {required double noteSize, required TextStyle ts, required int v}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            noteAsset,
            width: noteSize,
            height: noteSize,
            color: color,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 8),
          Text('$v', style: ts),
        ],
      );
    }

    return PopupSelectButton<int>(
      value: value,
      items: items,
      overlayColor: overlayColor,
      itemHeight: itemH,
      menuTextStyle: menuStyle,
      menuBg: const Color(0xFF202020),
      anchorWidth: (154.0 * scale.clamp(0.78, 1.08))
          .clamp(126.0, 182.0),
      menuMinWidth: (114.0 * scale.clamp(0.78, 1.08))
          .clamp(98.0, 138.0),
      menuMaxWidth: (134.0 * scale.clamp(0.78, 1.08))
          .clamp(110.0, 154.0),
      buildSelected: (ctx, v) => Center(
          child: row(noteSize: noteSelected, ts: selectedNumStyle, v: v)),
      buildItem: (ctx, v) =>
          Center(child: row(noteSize: noteMenu, ts: menuStyle, v: v)),
      onChanged: onChanged,
    );
  }
}

class PopupSelectButton<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final Color overlayColor;
  final double itemHeight;
  final TextStyle menuTextStyle;
  final Color menuBg;
  final double anchorWidth;
  final double menuMinWidth;
  final double menuMaxWidth;
  final double? menuMaxHeight;
  final Widget Function(BuildContext, T) buildSelected;
  final Widget Function(BuildContext, T) buildItem;
  final ValueChanged<T> onChanged;

  const PopupSelectButton({
    super.key,
    required this.value,
    required this.items,
    required this.overlayColor,
    required this.itemHeight,
    required this.menuTextStyle,
    required this.menuBg,
    required this.anchorWidth,
    required this.menuMinWidth,
    required this.menuMaxWidth,
    this.menuMaxHeight,
    required this.buildSelected,
    required this.buildItem,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const cText = Color(0xFFEEEEEE);
    final arrSz =
        (itemHeight * 1.28).clamp(34.0, 52.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;

          final overlay =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          final pos = box.localToGlobal(Offset.zero, ancestor: overlay);

          final rect = Rect.fromLTWH(

            pos.dx,
            pos.dy,
            box.size.width,
            box.size.height,
          );

          final selected = await _showSlidePopupMenu<T>(

            context: context,
            rect: rect,
            overlaySize: overlay.size,
            items: items,
            value: value,
            itemHeight: itemHeight,
            menuTextStyle: menuTextStyle,
            menuBg: menuBg,
            menuMinWidth: menuMinWidth,
            menuMaxWidth: menuMaxWidth,
            menuMaxHeight: menuMaxHeight,
            buildItem: buildItem,
          );

          if (selected != null) onChanged(selected);
        },
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return overlayColor;
          if (states.contains(WidgetState.hovered))
            return overlayColor.withValues(alpha: 0.07);
          return Colors.transparent;
        }),
        child: SizedBox(
          width: anchorWidth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(child: buildSelected(context, value)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down,
                  size: arrSz, color: cText),
            ],
          ),
        ),
      ),
    );
  }
}

class PresetButton extends StatelessWidget {
  final double width;
  final double height;
  final Color bg;
  final Radius radius;
  final String top;
  final String bottom;
  final double topSize;
  final double bottomSize;
  final Color color;
  final Color overlayColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? hint;
  final double? hintSize;
  final Color? hintColor;

  const PresetButton({
    super.key,
    required this.width,
    required this.height,
    required this.bg,
    required this.radius,
    required this.top,
    required this.bottom,
    required this.topSize,
    required this.bottomSize,
    required this.color,
    required this.overlayColor,
    required this.onTap,
    this.onLongPress,
    this.hint,
    this.hintSize,
    this.hintColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.all(radius),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.all(radius),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.all(radius),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) return overlayColor;
              if (states.contains(WidgetState.hovered))
                return overlayColor.withValues(alpha: 0.07);
              return Colors.transparent;
            }),
            child: Center(
              child: (hint != null && top.isEmpty && bottom.isEmpty)
                  ? Text(
                      hint!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: hintSize ?? topSize,
                        fontWeight: FontWeight.w700,
                        color: hintColor ?? color.withValues(alpha: 0.22),
                        height: 1.0,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          top,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: topSize,
                            fontWeight: FontWeight.w700,
                            color: color,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          bottom,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: bottomSize,
                            fontWeight: FontWeight.w700,
                            color: color,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepValueButton extends StatelessWidget {
  final String asset;
  final Color bg;
  final Color color;
  final Color overlayColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _StepValueButton({
    required this.asset,
    required this.bg,
    required this.color,
    required this.overlayColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayColor;
            if (states.contains(WidgetState.hovered))
              return overlayColor.withValues(alpha: 0.07);
            return Colors.transparent;
          }),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Center(
              child: Image.asset(
                asset,
                width: 18,
                height: 18,
                color: color,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PresetIconButton extends StatelessWidget {
  final Color bg;
  final Radius radius;
  final String asset;
  final Color iconColor;
  final Color overlayColor;
  final double iconSize;
  final VoidCallback onTap;

  const PresetIconButton({
    super.key,
    required this.bg,
    required this.radius,
    required this.asset,
    required this.iconColor,
    required this.overlayColor,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.all(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.all(radius),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayColor;
            if (states.contains(WidgetState.hovered))
              return overlayColor.withValues(alpha: 0.07);
            return Colors.transparent;
          }),
          child: Center(
            child: Image.asset(
              asset,
              width: iconSize,
              height: iconSize,
              color: iconColor,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class SquareIconButton extends StatelessWidget {
  final double size;
  final Radius radius;
  final Color bg;
  final String asset;
  final Color iconColor;
  final Color overlayColor;
  final VoidCallback onTap;

  const SquareIconButton({
    super.key,
    required this.size,
    required this.radius,
    required this.bg,
    required this.asset,
    required this.iconColor,
    required this.overlayColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.all(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.all(radius),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayColor;
            if (states.contains(WidgetState.hovered))
              return overlayColor.withValues(alpha: 0.07);
            return Colors.transparent;
          }),
          child: Center(
            child: Image.asset(
              asset,
              width: size * 0.55,
              height: size * 0.55,
              color: iconColor,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class IconAssetButton extends StatelessWidget {
  final String asset;
  final double size;
  final Color color;
  final Color overlayColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onLongPressEnd;

  const IconAssetButton({
    super.key,
    required this.asset,
    required this.size,
    required this.color,
    required this.overlayColor,
    required this.onTap,
    this.onLongPress,
    this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onLongPressUp: onLongPressEnd,
        onTapCancel: onLongPressEnd,
        borderRadius: BorderRadius.circular(size),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return overlayColor;
          if (states.contains(WidgetState.hovered))
            return overlayColor.withValues(alpha: 0.07);
          return Colors.transparent;
        }),
        child: Padding(
          padding: EdgeInsets.all(size * 0.10),
          child: Image.asset(
            asset,
            width: size,
            height: size,
            color: color,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class CircleActionButton extends StatelessWidget {
  final double diameter;
  final Color bg;
  final String asset;
  final double iconSize;
  final Color iconColor;
  final Color overlayColor;
  final VoidCallback onTap;

  const CircleActionButton({
    super.key,
    required this.diameter,
    required this.bg,
    required this.asset,
    required this.iconSize,
    required this.iconColor,
    required this.overlayColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayColor;
            if (states.contains(WidgetState.hovered))
              return overlayColor.withValues(alpha: 0.07);
            return Colors.transparent;
          }),
          child: Center(
            child: Image.asset(
              asset,
              width: iconSize,
              height: iconSize,
              color: iconColor,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class RollingBpmText extends StatelessWidget {
  final int value;
  final int previous;
  final double fontSize;
  final Color color;

  const RollingBpmText({
    super.key,
    required this.value,
    required this.previous,
    required this.fontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final inc = value >= previous;

    int h(int v) => (v ~/ 100) % 10;
    int t(int v) => (v ~/ 10) % 10;
    int o(int v) => v % 10;

    final newH = h(value), newT = t(value), newO = o(value);
    final oldH = h(previous), oldT = t(previous), oldO = o(previous);

    final w = fontSize * 0.78;
    final hgt = fontSize * 1.05;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DigitSlot(
          visible: true,
          width: w,
          height: hgt,
          fontSize: fontSize,
          color: color,
          oldDigit: oldH,
          newDigit: newH,
          increasing: inc,
        ),
        DigitSlot(
          visible: true,
          width: w,
          height: hgt,
          fontSize: fontSize,
          color: color,
          oldDigit: oldT,
          newDigit: newT,
          increasing: inc,
        ),
        DigitSlot(
          visible: true,
          width: w,
          height: hgt,
          fontSize: fontSize,
          color: color,
          oldDigit: oldO,
          newDigit: newO,
          increasing: inc,
        ),
      ],
    );
  }
}

class DigitSlot extends StatelessWidget {
  final bool visible;
  final double width;
  final double height;
  final double fontSize;
  final Color color;
  final int oldDigit;
  final int newDigit;
  final bool increasing;

  const DigitSlot({
    super.key,
    required this.visible,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.color,
    required this.oldDigit,
    required this.newDigit,
    required this.increasing,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return SizedBox(width: width, height: height);

    if (oldDigit == newDigit) {
      return SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Text(
            '$newDigit',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.0,
            ),
          ),
        ),
      );
    }

    return RollingDigit(
      width: width,
      height: height,
      fontSize: fontSize,
      color: color,
      oldDigit: oldDigit,
      newDigit: newDigit,
      increasing: increasing,
    );
  }
}

class RollingDigit extends StatefulWidget {
  final double width;
  final double height;
  final double fontSize;
  final Color color;
  final int oldDigit;
  final int newDigit;
  final bool increasing;

  const RollingDigit({
    super.key,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.color,
    required this.oldDigit,
    required this.newDigit,
    required this.increasing,
  });

  @override
  State<RollingDigit> createState() => _RollingDigitState();
}

class _RollingDigitState extends State<RollingDigit>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late Animation<double> _idxAnim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this);
    _rebuildAnim(
        from: widget.oldDigit,
        to: widget.newDigit,
        increasing: widget.increasing);
    _c.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant RollingDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.oldDigit == oldWidget.oldDigit &&
        widget.newDigit == oldWidget.newDigit &&
        widget.increasing == oldWidget.increasing) {
      return;
    }
    _rebuildAnim(
        from: widget.oldDigit,
        to: widget.newDigit,
        increasing: widget.increasing);
    _c.forward(from: 0.0);
  }

  void _rebuildAnim(
      {required int from, required int to, required bool increasing}) {
    int steps;
    if (increasing) {
      steps = (to - from) % 10;
      if (steps < 0) steps += 10;
    } else {
      steps = (from - to) % 10;
      if (steps < 0) steps += 10;
      steps = -steps;
    }

    final startIndex = 10 + from;
    final endIndex = startIndex + steps;

    final ms = (26 * steps.abs()).clamp(120, 260).toInt();
    _c.duration = Duration(milliseconds: ms);

    _idxAnim = Tween<double>(
      begin: startIndex.toDouble(),
      end: endIndex.toDouble(),
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget digitText(int d) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(
          child: Text(
            '$d',
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w700,
              color: widget.color,
              height: 1.0,
            ),
          ),
        ),
      );
    }

    return ClipRect(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _idxAnim,
          builder: (context, _) {
            final offsetY = -_idxAnim.value * widget.height;
            return Transform.translate(
              offset: Offset(0, offsetY),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 30; i++) digitText(i % 10),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class TallOvalThumbShape extends SliderComponentShape {
  final double width;
  final double height;

  const TallOvalThumbShape({
    required this.width,
    required this.height,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final base = sliderTheme.thumbColor ?? const Color(0xFF18A8F1);

    final t = Curves.easeOutCubic.transform(activationAnimation.value);
    final fill = Paint()..color = base;

    final rect = Rect.fromCenter(center: center, width: width, height: height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(width / 2));
    context.canvas.drawRRect(rrect, fill);

    final ring = Paint()
      ..color = base.withValues(alpha: 0.28 * t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0 * t;

    final ringRect = Rect.fromCenter(
      center: center,
      width: width + 18 * t,
      height: height + 24 * t,
    );
    final ringR = RRect.fromRectAndRadius(
        ringRect, Radius.circular((width + 18 * t) / 2));
    context.canvas.drawRRect(ringR, ring);
  }
}

class MarkedSliderTrackShape extends RoundedRectSliderTrackShape {
  final double min;
  final double max;
  final List<double> marks;
  final Color markColor;
  final double markWidth;

  const MarkedSliderTrackShape({
    required this.min,
    required this.max,
    required this.marks,
    required this.markColor,
    this.markWidth = 1.0,
  });

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );

    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final paint = Paint()
      ..color = markColor
      ..strokeWidth = markWidth;

    final denom = (max - min);
    if (denom == 0) return;

    for (final m in marks) {
      final t = ((m - min) / denom).clamp(0.0, 1.0);
      final dx = rect.left + rect.width * t;
      context.canvas.drawLine(
        Offset(dx, rect.top),
        Offset(dx, rect.bottom),
        paint,
      );
    }
  }
}
