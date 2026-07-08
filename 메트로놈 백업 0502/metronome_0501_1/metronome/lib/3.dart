import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  runApp(const MetronomeApp());
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
  final int bpm;
  final int beats;
  final int notes;

  const MemoryPreset({
    required this.bpm,
    required this.beats,
    required this.notes,
  });

  @override
  bool operator ==(Object other) {
    return other is MemoryPreset && other.bpm == bpm && other.beats == beats && other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(bpm, beats, notes);
}

class SettingSnapshot {
  final int bpm;
  final int beats;
  final int notes;
  final List<int> levels;

  const SettingSnapshot({
    required this.bpm,
    required this.beats,
    required this.notes,
    required this.levels,
  });

  bool sameAs(SettingSnapshot other) {
    if (bpm != other.bpm || beats != other.beats || notes != other.notes) return false;
    if (levels.length != other.levels.length) return false;
    for (int i = 0; i < levels.length; i++) {
      if (levels[i] != other.levels[i]) return false;
    }
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

class _MetronomeScreenState extends State<MetronomeScreen> with WidgetsBindingObserver {
  double bpm = 140;
  int beatCount = 8;
  int noteCount = 1;
  bool isPlaying = false;

  bool _showMemoryGrid = false;

  final List<int> beatLevels = List<int>.filled(8, 1);
  int _lastBpmInt = 140;

  late List<MemoryPreset> memoryPresets = List<MemoryPreset>.generate(
    40,
    (_) => const MemoryPreset(bpm: 120, beats: 4, notes: 1),
  );

  final List<SettingSnapshot> _history = <SettingSnapshot>[];

  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _clickSource;
  final Set<SoundHandle> _playingHandles = <SoundHandle>{};

  Timer? _tickTimer;
  Stopwatch? _stopwatch;
  int _tickCount = 0;

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

  ClickKind _clickKind = ClickKind.dgit1;

  // 1.0 = 100%, 2.0 = 200%, 3.0 = 300%
  double _masterVolume = 1.0;

  double _balance = 0.0;

  bool _keepScreenOn = true;
  bool _soundMix = true;
  bool _backgroundPlay = true;

  static const List<ThemeOption> _themes = <ThemeOption>[
    ThemeOption('하늘', Color(0xFF18A8F1)),
    ThemeOption('파랑', Color(0xFF5D6DBE)),
    ThemeOption('빨강', Color(0xFFFC5230)),
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
    if (_clickSource != null) {
      _soloud.disposeSource(_clickSource!);
    }
    _soloud.deinit();
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
      _activeBeatIndex = -1;
      _pulseToken = 0;
    });
    _savePrefs();
    if (isPlaying) _restartMetronome();
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

      final List<int>? savedLevels = (savedLevelsStr == null)
          ? null
          : (jsonDecode(savedLevelsStr) as List).map((e) => (e as num).toInt()).toList();

      final List<int>? savedPresetInts = (savedPresetsStr == null)
          ? null
          : (jsonDecode(savedPresetsStr) as List).map((e) => (e as num).toInt()).toList();

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

        if (savedPresetInts != null && savedPresetInts.length >= 40 * 3) {
          final next = <MemoryPreset>[];
          for (int i = 0; i < 40; i++) {
            final b = savedPresetInts[i * 3 + 0];
            final beats = savedPresetInts[i * 3 + 1];
            final notes = savedPresetInts[i * 3 + 2];
            next.add(
              MemoryPreset(
                bpm: b.clamp(_bpmMin.toInt(), _bpmMax.toInt()),
                beats: beats.clamp(1, 8),
                notes: notes.clamp(1, 6),
              ),
            );
          }
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

        // 기존 0.0~1.0 → 0.0~3.0 확장 (기존 저장값 호환)
        if (savedMasterVol != null) _masterVolume = savedMasterVol.clamp(0.0, 3.0);

        if (savedBalance != null) _balance = savedBalance.clamp(-1.0, 1.0);
        if (savedKeepOn != null) _keepScreenOn = savedKeepOn;
        if (savedMix != null) _soundMix = savedMix;
        if (savedBg != null) _backgroundPlay = savedBg;
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

      final flat = <int>[];
      for (final p in memoryPresets) {
        flat.add(p.bpm);
        flat.add(p.beats);
        flat.add(p.notes);
      }
      await sp.setString(_kPrefMemoryPresets, jsonEncode(flat));

      await sp.setString(_kPrefClickKind, _clickKind.name);
      await sp.setString(_kPrefThemeName, _theme.name);

      // 0.0~3.0 저장
      await sp.setDouble(_kPrefMasterVol, _masterVolume);

      await sp.setDouble(_kPrefBalance, _balance);
      await sp.setBool(_kPrefKeepOn, _keepScreenOn);
      await sp.setBool(_kPrefMix, _soundMix);
      await sp.setBool(_kPrefBg, _backgroundPlay);
    } catch (_) {}
  }

  Future<void> _initAudio() async {
    try {
      await _soloud.init(bufferSize: 256, channels: Channels.stereo);
      await _reloadClickSource();
    } catch (_) {}
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
        avAudioSessionCategoryOptions: _soundMix ? AVAudioSessionCategoryOptions.mixWithOthers : null,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            _soundMix ? AndroidAudioFocusGainType.gainTransientMayDuck : AndroidAudioFocusGainType.gain,
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

  Future<void> _reloadClickSource() async {
    try {
      final nextAsset = _clickAssetForKind(_clickKind);

      if (_clickSource != null) {
        _soloud.disposeSource(_clickSource!);
        _clickSource = null;
      }

      _clickSource = await _soloud.loadAsset(nextAsset);
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
    setState(() {
      _lastBpmInt = bpm.round();
      bpm = next;
    });
    _savePrefs();
    if (isPlaying) _restartMetronome();
  }

  void _changeBpmBy(int delta) => _setBpm(bpm + delta, recordHistory: true);

  bool _isPresetActive(MemoryPreset p) {
    return bpm.round() == p.bpm && beatCount == p.beats && noteCount == p.notes;
  }

  void _applyPreset(MemoryPreset p, {bool recordHistory = true}) {
    if (recordHistory) _pushHistoryIfNeeded(_currentSnapshot());
    setState(() {
      _lastBpmInt = bpm.round();
      bpm = p.bpm.toDouble();
      beatCount = p.beats.clamp(1, 8);
      noteCount = p.notes.clamp(1, 6);
      for (int i = 0; i < 8; i++) {
        beatLevels[i] = 1;
      }
    });
    _savePrefs();
    if (isPlaying) _restartMetronome();
  }

  void _savePreset(int index) {
    final p = MemoryPreset(bpm: bpm.round(), beats: beatCount, notes: noteCount);
    setState(() {
      memoryPresets[index] = p;
    });
    _savePrefs();
  }

  void _openMemoryGrid() {
    setState(() => _showMemoryGrid = true);
  }

  void _closeMemoryGrid() {
    setState(() => _showMemoryGrid = false);
  }

  Future<void> _togglePlay() async {
    if (isPlaying) {
      _stopMetronome();
      setState(() => isPlaying = false);
      return;
    }
    setState(() => isPlaying = true);
    await _startMetronome();
  }

  Future<void> _restartMetronome() async {
    if (!isPlaying) return;
    _stopMetronome();
    await _startMetronome();
  }

  Future<void> _startMetronome() async {
    if (_clickSource == null) return;
    _tickTimer?.cancel();
    _stopwatch?.stop();
    _stopwatch = Stopwatch()..start();
    _tickCount = 0;
    _activeBeatIndex = -1;
    _pulseToken = 0;
    _scheduleNextTick();
  }

  void _stopMetronome() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    _activeBeatIndex = -1;
    _pulseToken = 0;
    _stopAllSounds();
  }

  Future<void> _stopAllSounds() async {
    try {
      for (final h in _playingHandles) {
        await _soloud.stop(h);
      }
    } catch (_) {}
    _playingHandles.clear();
  }

  void _scheduleNextTick() {
    final sw = _stopwatch;
    if (sw == null || !isPlaying) return;

    final intervalUs = (60000000.0 / bpm / noteCount).round();
    final targetUs = _tickCount * intervalUs;
    final delayUs = targetUs - sw.elapsedMicroseconds;
    final d = Duration(microseconds: delayUs > 0 ? delayUs : 0);

    _tickTimer = Timer(d, () async {
      if (!mounted || !isPlaying) return;

      final beatIndex = (_tickCount ~/ noteCount) % beatCount;
      final subIndex = _tickCount % noteCount;

      if (subIndex == 0) {
        setState(() {
          _activeBeatIndex = beatIndex;
          _pulseToken++;
        });
      }

      final level = beatLevels[beatIndex];
      final baseVol = (level == 1) ? 1.0 : (level == 2) ? 0.5 : 0.0;

      // _masterVolume: 0.0~3.0
      final vol = baseVol * (subIndex == 0 ? 1.0 : 0.5) * _masterVolume;

      if (vol > 0 && _clickSource != null) {
        try {
          final h = await _soloud.play(_clickSource!, volume: vol);
          _playingHandles.add(h);

          final dyn = _soloud as dynamic;
          try {
            dyn.setPan(h, _balance);
          } catch (_) {}
        } catch (_) {}
      }

      _tickCount++;
      _scheduleNextTick();
    });
  }

  Future<void> _openTapTempoSheet() async {
    final cPrimary = _theme.color;
    const cPanel = Color(0xFF303030);
    const cBg = Color(0xFF202020);
    const cText = Color(0xFFEEEEEE);

    final pressOverlay = cText.withValues(alpha: 0.10);

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
                    // 기존 Expanded 탭 버튼을 "기존 대비 70%" 느낌으로 더 줄이기 위해 남는 높이를 계산 후 고정
                    // (시트 자체가 70%로 줄어든 상태에서, 탭 버튼도 한 번 더 70%로 줄임)
                    const fixedTop = 6.0 + 18.0 + 22.0 + 14.0; // 핸들(6) + 간격 + 텍스트(대략) + 간격
                    const fixedBottom = 12.0 + 30.0; // 아래 간격 + 하단 더미
                    final avail = (cs.maxHeight - fixedTop - fixedBottom).clamp(0.0, cs.maxHeight);
                    final tapH = avail * 0.8;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 56,
                            height: 6,
                            decoration: BoxDecoration(
                              // 테마색(강조색) 기반
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
                            // 탭 버튼 배경 불투명도 80%
                            color: cPrimary.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(26),
                            child: InkWell(
                              onTap: () => registerTap(setSheet),
                              borderRadius: BorderRadius.circular(26),
                              overlayColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.pressed)) return pressOverlay;
                                return Colors.transparent;
                              }),
                              child: Center(
                                child: Image.asset(
                                  'assets/icons/light/hand.png',
                                  width: 90,
                                  height:90,
                                  // 아이콘 불투명도 80%
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
    final cPrimary = _theme.color;
    const cPanel = Color(0xFF303030);
    const cBg = Color(0xFF202020);
    const cText = Color(0xFFEEEEEE);

    final pressOverlay = cText.withValues(alpha: 0.10);

    ClickKind localClickKind = _clickKind;
    ThemeOption localTheme = _theme;
    double localVol = _masterVolume;
    double localBal = _balance;
    bool localKeep = _keepScreenOn;
    bool localMix = _soundMix;
    bool localBg = _backgroundPlay;

    double snapVolume(double v) {
      // 100%, 200% 근접(±2%)이면 보정
      if ((v - 1.0).abs() <= 0.05) return 1.0;
      if ((v - 2.0).abs() <= 0.05) return 2.0;
      return v;
    }

    double snapBalance(double v) {
      // 중앙(0) 근접(±0.05)이면 보정
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
      });

      await _savePrefs();
      await _applyKeepScreenOn();
      await _applyAudioSessionConfig();
      await _reloadClickSource();

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
                          // 테마색(강조색) 기반
                          color: localTheme.color.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // "설정" 텍스트 제거

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // 클릭 종류: 라벨(좌) + 드롭박스(우)
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

                            // 테마: 라벨(좌) + 드롭박스(우)
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

                            // 소리 크기: 텍스트 옆에 현재 % 표시
                            sectionTitle('메트로놈 음량: $volPct%'),
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
                                      // 더 얇고 작게
                                      trackHeight: 6,
                                      activeTrackColor: localTheme.color,
                                      inactiveTrackColor: cText.withValues(alpha: 0.7),
                                      thumbColor: localTheme.color,
                                      overlayColor: localTheme.color.withValues(alpha: 0.18),
                                      thumbShape: const TallOvalThumbShape(width: 19.5, height: 34.5),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),

                                      // 100, 200 마커
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
                                      max: 3.0, // 300%
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
                                      // 더 얇고 작게
                                      trackHeight: 6,
                                      activeTrackColor: localTheme.color,
                                      inactiveTrackColor: cText.withValues(alpha: 0.7),
                                      thumbColor: localTheme.color,
                                      overlayColor: localTheme.color.withValues(alpha: 0.18),
                                      thumbShape: const TallOvalThumbShape(width: 19.5, height: 34.5),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),

                                      // 0 마커
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
  }

  @override
  Widget build(BuildContext context) {
    final cPrimary = _theme.color;
    const cPanel = Color(0xFF404040);
    const cBg = Color(0xFF202020);
    const cText = Color(0xFFEEEEEE);

    final pressOverlay = cText.withValues(alpha: 0.10);

    const designW = 1080.0;
    const designH = 2280.0;

    final bpmInt = bpm.round();
    final bool canUndo = _history.isNotEmpty;

    final beatAreaH = _showMemoryGrid ? 0.0 : null;
    final midGapH = _showMemoryGrid ? 0.0 : 104.0;
    final panelH = _showMemoryGrid ? 2000.0 : 1600.0;

    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, cs) {
            final scale = math.min(cs.maxWidth / designW, cs.maxHeight / designH);

            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: designW,
                  height: designH,
                  child: Container(
                    color: cBg,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 70, right: 70, top: 60),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOutCubic,
                            height: beatAreaH,
                            child: beatAreaH == 0
                                ? const SizedBox.shrink()
                                : BeatCircles(
                                    count: beatCount,
                                    areaWidth: designW - 140,
                                    primary: cPrimary,
                                    baseOverlay: cPrimary.withValues(alpha: 0.16),
                                    levels: beatLevels,
                                    activeIndex: _activeBeatIndex,
                                    pulseToken: _pulseToken,
                                    onTapBeat: _cycleBeatLevel,
                                  ),
                          ),
                        ),
                        SizedBox(height: midGapH),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 90),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Transform.translate(
                                offset: const Offset(18, 0),
                                child: PopupNumberSelect(
                                  value: beatCount,
                                  items: const [1, 2, 3, 4, 5, 6, 7, 8],
                                  scale: scale,
                                  color: cText,
                                  overlayColor: pressOverlay,
                                  onChanged: (v) => _setBeatCount(v, recordHistory: true),
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(-18, 0),
                                child: PopupNoteSelect(
                                  value: noteCount,
                                  items: const [1, 2, 3, 4, 5, 6],
                                  scale: scale,
                                  color: cText,
                                  overlayColor: pressOverlay,
                                  noteAsset: 'assets/icons/light/note.png',
                                  onChanged: (v) => _setNoteCount(v, recordHistory: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 34),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOutCubic,
                              width: designW,
                              height: panelH,
                              decoration: const BoxDecoration(
                                color: cPanel,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(70),
                                  topRight: Radius.circular(70),
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(70, 70, 70, 60),
                              child: Column(
                                children: [
                                  if (!_showMemoryGrid)
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 760,
                                          child: Row(
                                            children: [
                                              PresetButton(
                                                width: 230,
                                                height: 325,
                                                bg: cPrimary.withValues(
                                                  alpha: _isPresetActive(memoryPresets[0]) ? 1.0 : 0.6,
                                                ),
                                                radius: const Radius.circular(54),
                                                top: '${memoryPresets[0].bpm}',
                                                bottom: '${memoryPresets[0].beats} / ${memoryPresets[0].notes}',
                                                topSize: 86,
                                                bottomSize: 76,
                                                color: cText,
                                                overlayColor: pressOverlay,
                                                onTap: () => _applyPreset(memoryPresets[0], recordHistory: true),
                                                onLongPress: () => _savePreset(0),
                                              ),
                                              const SizedBox(width: 35),
                                              PresetButton(
                                                width: 230,
                                                height: 325,
                                                bg: cPrimary.withValues(
                                                  alpha: _isPresetActive(memoryPresets[1]) ? 1.0 : 0.6,
                                                ),
                                                radius: const Radius.circular(54),
                                                top: '${memoryPresets[1].bpm}',
                                                bottom: '${memoryPresets[1].beats} / ${memoryPresets[1].notes}',
                                                topSize: 86,
                                                bottomSize: 76,
                                                color: cText,
                                                overlayColor: pressOverlay,
                                                onTap: () => _applyPreset(memoryPresets[1], recordHistory: true),
                                                onLongPress: () => _savePreset(1),
                                              ),
                                              const SizedBox(width: 35),
                                              PresetButton(
                                                width: 230,
                                                height: 325,
                                                bg: cPrimary.withValues(
                                                  alpha: _isPresetActive(memoryPresets[2]) ? 1.0 : 0.6,
                                                ),
                                                radius: const Radius.circular(54),
                                                top: '${memoryPresets[2].bpm}',
                                                bottom: '${memoryPresets[2].beats} / ${memoryPresets[2].notes}',
                                                topSize: 86,
                                                bottomSize: 76,
                                                color: cText,
                                                overlayColor: pressOverlay,
                                                onTap: () => _applyPreset(memoryPresets[2], recordHistory: true),
                                                onLongPress: () => _savePreset(2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 30),
                                        Column(
                                          children: [
                                            SquareIconButton(
                                              size: 150,
                                              radius: const Radius.circular(34),
                                              bg: cPrimary,
                                              asset: 'assets/icons/light/grid.png',
                                              iconColor: cText,
                                              overlayColor: pressOverlay,
                                              onTap: _openMemoryGrid,
                                            ),
                                            const SizedBox(height: 25),
                                            SquareIconButton(
                                              size: 150,
                                              radius: const Radius.circular(34),
                                              bg: cPrimary.withValues(alpha: canUndo ? 1.0 : 0.6),
                                              asset: 'assets/icons/light/back.png',
                                              iconColor: cText,
                                              overlayColor: pressOverlay,
                                              onTap: canUndo ? _undo : () {},
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  if (_showMemoryGrid)
                                    SizedBox(
                                      height: 980,
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: GridView.builder(
                                              padding: EdgeInsets.zero,
                                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 4,
                                                crossAxisSpacing: 28,
                                                mainAxisSpacing: 28,
                                                childAspectRatio: 1.05,
                                              ),
                                              itemCount: 40,
                                              itemBuilder: (context, i) {
                                                final p = memoryPresets[i];
                                                return PresetButton(
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  bg: cPrimary.withValues(alpha: _isPresetActive(p) ? 1.0 : 0.6),
                                                  radius: const Radius.circular(54),
                                                  top: '${p.bpm}',
                                                  bottom: '${p.beats} / ${p.notes}',
                                                  topSize: 62,
                                                  bottomSize: 56,
                                                  color: cText,
                                                  overlayColor: pressOverlay,
                                                  onTap: () => _applyPreset(p, recordHistory: true),
                                                  onLongPress: () => _savePreset(i),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  SizedBox(height: _showMemoryGrid ? 70 : 220),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()..rotateY(math.pi),
                                        child: IconAssetButton(
                                          asset: 'assets/icons/light/arrows.png',
                                          size: 110,
                                          color: cText,
                                          overlayColor: pressOverlay,
                                          onTap: () => _changeBpmBy(-10),
                                        ),
                                      ),
                                      const SizedBox(width: 25),
                                      IconAssetButton(
                                        asset: 'assets/icons/light/minus.png',
                                        size: 95,
                                        color: cText,
                                        overlayColor: pressOverlay,
                                        onTap: () => _changeBpmBy(-1),
                                      ),
                                      const SizedBox(width: 35),
                                      RollingBpmText(
                                        value: bpmInt,
                                        previous: _lastBpmInt,
                                        fontSize: 150,
                                        color: cText,
                                      ),
                                      const SizedBox(width: 35),
                                      IconAssetButton(
                                        asset: 'assets/icons/light/plus.png',
                                        size: 95,
                                        color: cText,
                                        overlayColor: pressOverlay,
                                        onTap: () => _changeBpmBy(1),
                                      ),
                                      const SizedBox(width: 25),
                                      IconAssetButton(
                                        asset: 'assets/icons/light/arrows.png',
                                        size: 110,
                                        color: cText,
                                        overlayColor: pressOverlay,
                                        onTap: () => _changeBpmBy(10),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 55),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 10,
                                        activeTrackColor: cPrimary,
                                        inactiveTrackColor: cText,
                                        thumbColor: cPrimary,
                                        overlayColor: cPrimary.withValues(alpha: 0.22),
                                        thumbShape: const TallOvalThumbShape(width: 44, height: 78),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 30),
                                      ),
                                      child: Slider(
                                        min: _bpmMin,
                                        max: _bpmMax,
                                        value: bpm.clamp(_bpmMin, _bpmMax),
                                        onChanged: (v) {
                                          setState(() {
                                            _lastBpmInt = bpm.round();
                                            bpm = v.clamp(_bpmMin, _bpmMax);
                                          });
                                        },
                                        onChangeEnd: (v) {
                                          _setBpm(v, recordHistory: true);
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 90),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconAssetButton(
                                        asset: 'assets/icons/light/setting.png',
                                        size: 120,
                                        color: cText,
                                        overlayColor: pressOverlay,
                                        onTap: _openSettingsSheet,
                                      ),
                                      CircleActionButton(
                                        diameter: 220,
                                        bg: cPrimary,
                                        asset: isPlaying ? 'assets/icons/light/stop.png' : 'assets/icons/light/play.png',
                                        iconSize: 120,
                                        iconColor: cText,
                                        overlayColor: pressOverlay,
                                        onTap: _togglePlay,
                                      ),
                                      IconAssetButton(
                                        asset: _showMemoryGrid ? 'assets/icons/light/exit.png' : 'assets/icons/light/hand.png',
                                        size: 120,
                                        color: cText,
                                        overlayColor: pressOverlay,
                                        onTap: _showMemoryGrid ? _closeMemoryGrid : _openTapTempoSheet,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
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
            activeColor: primary,
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
    const gap = 70.0;

    Widget beatCircle(int index, bool visible) {
      if (!visible) return SizedBox(width: cell, height: cell);

      final level = levels[index];
      final d = (level == 1) ? bigD : (level == 2) ? smallD : tinyD;

      final bool isActive = index == activeIndex;
      final double alphaBase = (level == 1) ? 0.7 : (level == 2) ? 0.6 : 0.3;
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
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
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
                    if (states.contains(WidgetState.pressed)) return baseOverlay;
                    if (states.contains(WidgetState.hovered)) return baseOverlay.withValues(alpha: 0.08);
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
          const SizedBox(height: gap),
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
      fontSize: 90,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
    );

    final menuStyle = TextStyle(
      fontSize: 38 * scale.clamp(0.75, 1.2),
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
    );

    final itemH = (44.0 * scale.clamp(0.75, 1.2)).clamp(30.0, 54.0);

    return PopupSelectButton<int>(
      value: value,
      items: items,
      overlayColor: overlayColor,
      itemHeight: itemH,
      menuTextStyle: menuStyle,
      menuBg: const Color(0xFF202020),
      anchorWidth: 160,
      menuMinWidth: 110,
      menuMaxWidth: 130,
      buildSelected: (ctx, v) => Center(child: Text('$v', style: selectedStyle)),
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
      fontSize: 74,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
    );

    final menuStyle = TextStyle(
      fontSize: 38 * scale.clamp(0.75, 1.2),
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.0,
    );

    final noteSelected = 95.0;
    final noteMenu = (40.0 * scale.clamp(0.75, 1.2)).clamp(28.0, 48.0);
    final itemH = (44.0 * scale.clamp(0.75, 1.2)).clamp(30.0, 54.0);

    Widget row({required double noteSize, required TextStyle ts, required int v}) {
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
          const SizedBox(width: 12),
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
      anchorWidth: 230,
      menuMinWidth: 150,
      menuMaxWidth: 170,
      buildSelected: (ctx, v) => Center(child: row(noteSize: noteSelected, ts: selectedNumStyle, v: v)),
      buildItem: (ctx, v) => Center(child: row(noteSize: noteMenu, ts: menuStyle, v: v)),
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
    required this.buildSelected,
    required this.buildItem,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const cText = Color(0xFFEEEEEE);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;

          final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
          final pos = box.localToGlobal(Offset.zero, ancestor: overlay);

          final rect = Rect.fromLTWH(
            pos.dx,
            pos.dy + box.size.height,
            box.size.width,
            box.size.height,
          );

          final selected = await showMenu<T>(
            context: context,
            color: menuBg,
            constraints: BoxConstraints(minWidth: menuMinWidth, maxWidth: menuMaxWidth),
            position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
            items: items
                .map(
                  (e) => PopupMenuItem<T>(
                    value: e,
                    height: itemHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.center,
                      child: DefaultTextStyle(style: menuTextStyle, child: buildItem(context, e)),
                    ),
                  ),
                )
                .toList(),
          );

          if (selected != null) onChanged(selected);
        },
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return overlayColor;
          if (states.contains(WidgetState.hovered)) return overlayColor.withValues(alpha: 0.07);
          return Colors.transparent;
        }),
        child: SizedBox(
          width: anchorWidth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(child: buildSelected(context, value)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_drop_down, size: 80, color: cText),
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
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

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
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.all(radius),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.all(radius),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayColor;
            if (states.contains(WidgetState.hovered)) return overlayColor.withValues(alpha: 0.07);
            return Colors.transparent;
          }),
          child: Center(
            child: Column(
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
            if (states.contains(WidgetState.hovered)) return overlayColor.withValues(alpha: 0.07);
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

  const IconAssetButton({
    super.key,
    required this.asset,
    required this.size,
    required this.color,
    required this.overlayColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return overlayColor;
          if (states.contains(WidgetState.hovered)) return overlayColor.withValues(alpha: 0.07);
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
            if (states.contains(WidgetState.hovered)) return overlayColor.withValues(alpha: 0.07);
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

class _RollingDigitState extends State<RollingDigit> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late Animation<double> _idxAnim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this);
    _rebuildAnim(from: widget.oldDigit, to: widget.newDigit, increasing: widget.increasing);
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
    _rebuildAnim(from: widget.oldDigit, to: widget.newDigit, increasing: widget.increasing);
    _c.forward(from: 0.0);
  }

  void _rebuildAnim({required int from, required int to, required bool increasing}) {
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
    final ringR = RRect.fromRectAndRadius(ringRect, Radius.circular((width + 18 * t) / 2));
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