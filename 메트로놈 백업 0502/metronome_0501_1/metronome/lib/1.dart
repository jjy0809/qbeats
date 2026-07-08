import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF202020),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
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

class MemoryPreset {
  final int bpm;
  final int beats;
  final int notes;

  const MemoryPreset({
    required this.bpm,
    required this.beats,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {'bpm': bpm, 'beats': beats, 'notes': notes};

  static MemoryPreset fromJson(Map<String, dynamic> j) {
    return MemoryPreset(
      bpm: (j['bpm'] as num?)?.toInt() ?? 120,
      beats: (j['beats'] as num?)?.toInt() ?? 4,
      notes: (j['notes'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MemoryPreset && other.bpm == bpm && other.beats == beats && other.notes == notes;

  @override
  int get hashCode => Object.hash(bpm, beats, notes);
}

class _Snapshot {
  final int bpm;
  final int beats;
  final int notes;
  final List<int> levels;

  const _Snapshot({
    required this.bpm,
    required this.beats,
    required this.notes,
    required this.levels,
  });
}

enum ClickType {
  dgit1('디지털 1', 'assets/sound/dgit1.wav'),
  dgit2('디지털 2', 'assets/sound/dgit2.wav'),
  dgit3('디지털 3', 'assets/sound/dgit3.wav'),
  anal1('아날로그 1', 'assets/sound/anal1.wav'),
  anal2('아날로그 2', 'assets/sound/anal2.wav'),
  anal3('아날로그 3', 'assets/sound/anal3.wav');

  final String label;
  final String asset;
  const ClickType(this.label, this.asset);
}

class ThemeItem {
  final String name;
  final Color color;
  const ThemeItem(this.name, this.color);
}

const List<ThemeItem> kThemes = <ThemeItem>[
  ThemeItem('하늘', Color(0xFF18A8F1)),
  ThemeItem('파랑', Color(0xFF5D6DBE)),
  ThemeItem('빨강', Color(0xFFFC5230)),
  ThemeItem('주황', Color(0xFFFD9F28)),
  ThemeItem('노랑', Color(0xFFFDEB28)),
  ThemeItem('초록', Color(0xFF2FA599)),
  ThemeItem('연두', Color(0xFF7DB249)),
  ThemeItem('보라', Color(0xFF9A30AE)),
  ThemeItem('민트', Color(0xFF03EFD7)),
  ThemeItem('핑크', Color(0xFFF369FF)),
];

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> with WidgetsBindingObserver {
  // ====== UI/STATE ======
  double bpm = 140;
  int beatCount = 4;
  int noteCount = 1;
  bool isPlaying = false;

  final List<int> beatLevels = List<int>.filled(8, 1);

  bool isMemoryExpanded = false;

  // ====== SETTINGS ======
  ClickType clickType = ClickType.dgit3;
  int themeIndex = 0; // kThemes index
  double volumeMul = 1.0; // 0.0 ~ 3.0 (0%~300%)
  double balance = 0.0; // -1.0(left) ~ 1.0(right)
  bool keepScreenOn = false;
  bool soundMix = false;
  bool backgroundPlay = false;

  // ====== MEMORY ======
  // 40개(4x10)
  late List<MemoryPreset> allPresets;

  // ====== UNDO HISTORY (session only) ======
  final List<_Snapshot> _history = <_Snapshot>[];

  // ====== AUDIO ======
  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _clickSource;
  final Set<SoundHandle> _playingHandles = <SoundHandle>{};

  // ====== TIMER ======
  Timer? _tickTimer;
  Stopwatch? _stopwatch;
  int _tickCount = 0;
  int _activeBeatIndex = -1;
  int _pulseToken = 0;

  // ====== CONSTANTS ======
  static const _bpmMin = 40.0;
  static const _bpmMax = 260.0;

  // ====== PREF KEYS ======
  static const _kPrefBpm = 'bpm';
  static const _kPrefBeats = 'beats';
  static const _kPrefNotes = 'notes';
  static const _kPrefLevels = 'levels';
  static const _kPrefPresets = 'presets40';
  static const _kPrefClickType = 'clickType';
  static const _kPrefTheme = 'themeIndex';
  static const _kPrefVolume = 'volumeMul';
  static const _kPrefBalance = 'balance';
  static const _kPrefKeepOn = 'keepScreenOn';
  static const _kPrefMix = 'soundMix';
  static const _kPrefBg = 'backgroundPlay';

  Color get cBg => const Color(0xFF202020);
  Color get cPanel => const Color(0xFF4A4A4A);
  Color get cText => const Color(0xFFEEEEEE);
  Color get cPrimary => kThemes[themeIndex].color;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAll();
  }

  Future<void> _initAll() async {
    await _loadPrefs();
    await _initAudio();
    await _applyWakelock();
    await _applyAudioSession();
    setState(() {});
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
    if (!backgroundPlay) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        if (isPlaying) {
          _stopMetronome();
          setState(() => isPlaying = false);
        }
      }
    }
  }

  // ====== PREFS ======
  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();

    bpm = (sp.getDouble(_kPrefBpm) ?? 140.0).clamp(_bpmMin, _bpmMax);
    beatCount = (sp.getInt(_kPrefBeats) ?? 4).clamp(1, 8);
    noteCount = (sp.getInt(_kPrefNotes) ?? 1).clamp(1, 6);

    final levels = sp.getStringList(_kPrefLevels);
    if (levels != null && levels.length == 8) {
      for (int i = 0; i < 8; i++) {
        beatLevels[i] = int.tryParse(levels[i])?.clamp(1, 3) ?? 1;
      }
    } else {
      for (int i = 0; i < 8; i++) {
        beatLevels[i] = 1;
      }
    }

    final presetsJson = sp.getString(_kPrefPresets);
    if (presetsJson != null) {
      try {
        final list = (jsonDecode(presetsJson) as List).cast<Map<String, dynamic>>();
        allPresets = list.map(MemoryPreset.fromJson).toList(growable: false);
      } catch (_) {
        allPresets = List<MemoryPreset>.filled(40, const MemoryPreset(bpm: 120, beats: 4, notes: 1));
      }
    } else {
      allPresets = List<MemoryPreset>.filled(40, const MemoryPreset(bpm: 120, beats: 4, notes: 1));
    }
    if (allPresets.length != 40) {
      allPresets = List<MemoryPreset>.filled(40, const MemoryPreset(bpm: 120, beats: 4, notes: 1));
    }

    final ct = sp.getInt(_kPrefClickType) ?? ClickType.dgit3.index;
    clickType = ClickType.values[ct.clamp(0, ClickType.values.length - 1)];

    themeIndex = (sp.getInt(_kPrefTheme) ?? 0).clamp(0, kThemes.length - 1);

    volumeMul = (sp.getDouble(_kPrefVolume) ?? 1.0).clamp(0.0, 3.0);
    balance = (sp.getDouble(_kPrefBalance) ?? 0.0).clamp(-1.0, 1.0);

    keepScreenOn = sp.getBool(_kPrefKeepOn) ?? false;
    soundMix = sp.getBool(_kPrefMix) ?? false;
    backgroundPlay = sp.getBool(_kPrefBg) ?? false;
  }

  Future<void> _savePrefs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble(_kPrefBpm, bpm);
    await sp.setInt(_kPrefBeats, beatCount);
    await sp.setInt(_kPrefNotes, noteCount);
    await sp.setStringList(_kPrefLevels, beatLevels.map((e) => '$e').toList(growable: false));
    await sp.setString(_kPrefPresets, jsonEncode(allPresets.map((e) => e.toJson()).toList(growable: false)));
    await sp.setInt(_kPrefClickType, clickType.index);
    await sp.setInt(_kPrefTheme, themeIndex);
    await sp.setDouble(_kPrefVolume, volumeMul);
    await sp.setDouble(_kPrefBalance, balance);
    await sp.setBool(_kPrefKeepOn, keepScreenOn);
    await sp.setBool(_kPrefMix, soundMix);
    await sp.setBool(_kPrefBg, backgroundPlay);
  }

  // ====== AUDIO INIT ======
  Future<void> _initAudio() async {
    try {
      await _soloud.init(bufferSize: 256, channels: Channels.stereo);
      await _loadClickSource(clickType.asset);
    } catch (_) {}
  }

  Future<void> _loadClickSource(String asset) async {
    try {
      if (_clickSource != null) {
        _soloud.disposeSource(_clickSource!);
      }
      _clickSource = await _soloud.loadAsset(asset);
    } catch (_) {}
  }

  Future<void> _applyWakelock() async {
    try {
      if (keepScreenOn) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  Future<void> _applyAudioSession() async {
    try {
      final s = await AudioSession.instance;
      final config = AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: soundMix ? AVAudioSessionCategoryOptions.mixWithOthers : null,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            soundMix ? AndroidAudioFocusGainType.gainTransientMayDuck : AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: !soundMix,
      );
      await s.configure(config);
      await s.setActive(true);
    } catch (_) {}
  }

  // ====== HISTORY ======
  void _pushHistory() {
    _history.add(_Snapshot(
      bpm: bpm.round(),
      beats: beatCount,
      notes: noteCount,
      levels: List<int>.from(beatLevels),
    ));
  }

  bool get _canUndo => _history.isNotEmpty;

  void _undo() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    setState(() {
      bpm = last.bpm.toDouble();
      beatCount = last.beats;
      noteCount = last.notes;
      for (int i = 0; i < 8; i++) {
        beatLevels[i] = last.levels[i].clamp(1, 3);
      }
    });
    _savePrefs();
    if (isPlaying) _restartMetronome();
  }

  // ====== METRONOME CONTROL ======
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
    final targetUs = (_tickCount + 1) * intervalUs;
    final nowUs = sw.elapsedMicroseconds;
    final delayUs = math.max(0, targetUs - nowUs);

    _tickTimer = Timer(Duration(microseconds: delayUs), () {
      _onTick();
      _tickCount++;
      _scheduleNextTick();
    });
  }

  void _onTick() async {
    if (_clickSource == null || !mounted || !isPlaying) return;

    final beatIndex = ((_tickCount ~/ noteCount) % beatCount);
    final subIndex = (_tickCount % noteCount);

    final level = beatLevels[beatIndex].clamp(1, 3);
    double base = switch (level) { 1 => 1.0, 2 => 0.5, _ => 0.0 };
    if (subIndex > 0) base *= 0.5;

    final vol = (base * volumeMul).clamp(0.0, 3.0);
    if (vol > 0.0) {
      try {
        final handle = await _soloud.play(
          _clickSource!,
          volume: vol,
          pan: balance.clamp(-1.0, 1.0),
        );
        _playingHandles.add(handle);
      } catch (_) {}
    }

    final token = ++_pulseToken;
    setState(() => _activeBeatIndex = beatIndex);
    Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (_pulseToken != token) return;
      setState(() => _activeBeatIndex = -1);
    });
  }

  // ====== STATE SETTERS ======
  void _setBeatCount(int v) {
    _pushHistory();
    setState(() {
      beatCount = v.clamp(1, 8);
      for (int i = 0; i < 8; i++) {
        if (i >= beatCount) {
          beatLevels[i] = 1;
        }
      }
    });
    _savePrefs();
    if (isPlaying) _restartMetronome();
  }

  void _setNoteCount(int v) {
    _pushHistory();
    setState(() => noteCount = v.clamp(1, 6));
    _savePrefs();
    if (isPlaying) _restartMetronome();
  }

  void _cycleBeatLevel(int index) {
    _pushHistory();
    setState(() {
      final cur = beatLevels[index].clamp(1, 3);
      beatLevels[index] = (cur % 3) + 1;
    });
    _savePrefs();
  }

  void _setBpm(double v, {bool push = false}) {
    final next = v.clamp(_bpmMin, _bpmMax);
    if (push) _pushHistory();
    setState(() => bpm = next);
    _savePrefs();
    if (isPlaying) _restartMetronome();
  }

  void _changeBpmBy(int delta) => _setBpm(bpm + delta, push: true);

  bool _isPresetActive(MemoryPreset p) {
    return bpm.round() == p.bpm && beatCount == p.beats && noteCount == p.notes;
  }

  void _applyPreset(MemoryPreset p) {
    _pushHistory();
    setState(() {
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
      allPresets[index] = p;
    });
    _savePrefs();
  }

  // ====== SHEETS ======
  Future<void> _openTapSheet() async {
    final before = bpm.round();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _TapSheet(
          accent: cPrimary,
          text: cText,
          panel: cPanel,
          bpm: bpm.round(),
          onBpm: (v) {
            setState(() => bpm = v.toDouble().clamp(_bpmMin, _bpmMax));
            _savePrefs();
            if (isPlaying) _restartMetronome();
          },
        );
      },
    );
    final after = bpm.round();
    if (after != before) {
      _pushHistory();
    }
  }

  Future<void> _openSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SettingsSheet(
          accent: cPrimary,
          text: cText,
          panel: cPanel,
          clickType: clickType,
          themeIndex: themeIndex,
          volumeMul: volumeMul,
          balance: balance,
          keepScreenOn: keepScreenOn,
          soundMix: soundMix,
          backgroundPlay: backgroundPlay,
          onClickType: (v) async {
            setState(() => clickType = v);
            await _loadClickSource(clickType.asset);
            _savePrefs();
          },
          onTheme: (idx) {
            setState(() => themeIndex = idx);
            _savePrefs();
            SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
              statusBarColor: const Color(0xFF202020),
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Platform.isIOS ? Brightness.dark : Brightness.dark,
            ));
          },
          onVolume: (v) {
            setState(() => volumeMul = v.clamp(0.0, 3.0));
            _savePrefs();
          },
          onBalance: (v) {
            setState(() => balance = v.clamp(-1.0, 1.0));
            _savePrefs();
          },
          onKeepOn: (v) async {
            setState(() => keepScreenOn = v);
            await _applyWakelock();
            _savePrefs();
          },
          onMix: (v) async {
            setState(() => soundMix = v);
            await _applyAudioSession();
            _savePrefs();
          },
          onBg: (v) {
            setState(() => backgroundPlay = v);
            _savePrefs();
          },
        );
      },
    );
  }

  // ====== UI BUILD ======
  @override
  Widget build(BuildContext context) {
    const designW = 1000.0;

    final pressOverlay = cText.withValues(alpha: 0.08);
    final mainPresets = allPresets.take(3).toList(growable: false);

    final undoOpacity = _canUndo ? 1.0 : 0.6;

    final bpmText = bpm.round().toString().padLeft(3, '0');

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: designW,
            child: Stack(
              children: [
                // ====== TOP (BEATS) ======
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                  top: isMemoryExpanded ? -420 : 60,
                  left: 0,
                  right: 0,
                  child: _BeatArea(
                    accent: cPrimary,
                    beatCount: beatCount,
                    activeIndex: _activeBeatIndex,
                    levels: beatLevels,
                    onTapBeat: _cycleBeatLevel,
                  ),
                ),

                // ====== DROPDOWNS ======
                Positioned(
                  top: isMemoryExpanded ? 90 : 420,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 240),
                    opacity: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 70),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _AnchorDropdown<int>(
                            width: 160,
                            value: beatCount,
                            items: List<int>.generate(8, (i) => i + 1),
                            itemLabel: (v) => '$v',
                            textStyle: TextStyle(
                              color: cText,
                              fontSize: 56,
                              fontWeight: FontWeight.w700,
                            ),
                            arrowColor: cText,
                            bg: cBg,
                            menuBg: cBg,
                            onChanged: (v) => _setBeatCount(v),
                          ),
                          Row(
                            children: [
                              Image.asset(
                                'assets/icons/light/note.png',
                                width: 70,
                                height: 70,
                                color: cText,
                              ),
                              const SizedBox(width: 18),
                              _AnchorDropdown<int>(
                                width: 160,
                                value: noteCount,
                                items: List<int>.generate(6, (i) => i + 1),
                                itemLabel: (v) => '$v',
                                textStyle: TextStyle(
                                  color: cText,
                                  fontSize: 56,
                                  fontWeight: FontWeight.w700,
                                ),
                                arrowColor: cText,
                                bg: cBg,
                                menuBg: cBg,
                                onChanged: (v) => _setNoteCount(v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ====== BOTTOM PANEL ======
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeInOutCubic,
                  bottom: 0,
                  left: 0,
                  right: 0,
                  top: isMemoryExpanded ? 200 : 520,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cPanel,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(70),
                        topRight: Radius.circular(70),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(70, 70, 70, 40),
                    child: Column(
                      children: [
                        // presets row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  _MemoryButton(
                                    preset: mainPresets[0],
                                    accent: cPrimary,
                                    text: cText,
                                    active: _isPresetActive(mainPresets[0]),
                                    onTap: () => _applyPreset(mainPresets[0]),
                                    onLongPress: () => _savePreset(0),
                                  ),
                                  const SizedBox(width: 35),
                                  _MemoryButton(
                                    preset: mainPresets[1],
                                    accent: cPrimary,
                                    text: cText,
                                    active: _isPresetActive(mainPresets[1]),
                                    onTap: () => _applyPreset(mainPresets[1]),
                                    onLongPress: () => _savePreset(1),
                                  ),
                                  const SizedBox(width: 35),
                                  _MemoryButton(
                                    preset: mainPresets[2],
                                    accent: cPrimary,
                                    text: cText,
                                    active: _isPresetActive(mainPresets[2]),
                                    onTap: () => _applyPreset(mainPresets[2]),
                                    onLongPress: () => _savePreset(2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 30),
                            Column(
                              children: [
                                _SquareIconButton(
                                  size: 150,
                                  radius: 34,
                                  bg: cPrimary.withValues(alpha: 0.6),
                                  asset: 'assets/icons/light/grid.png',
                                  iconColor: cText,
                                  overlayColor: pressOverlay,
                                  opacity: 1.0,
                                  onTap: () {
                                    setState(() => isMemoryExpanded = true);
                                  },
                                ),
                                const SizedBox(height: 25),
                                _SquareIconButton(
                                  size: 150,
                                  radius: 34,
                                  bg: cPrimary.withValues(alpha: 0.6),
                                  asset: 'assets/icons/light/back.png',
                                  iconColor: cText,
                                  overlayColor: pressOverlay,
                                  opacity: undoOpacity,
                                  onTap: _canUndo ? _undo : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // expanded memory grid
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 320),
                          crossFadeState: isMemoryExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                          firstCurve: Curves.easeInOutCubic,
                          secondCurve: Curves.easeInOutCubic,
                          firstChild: Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: Scrollbar(
                                thumbVisibility: false,
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 10, bottom: 18),
                                    child: _MemoryGrid(
                                      presets: allPresets,
                                      accent: cPrimary,
                                      text: cText,
                                      isActive: _isPresetActive,
                                      onTap: (i) => _applyPreset(allPresets[i]),
                                      onLong: (i) => _savePreset(i),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          secondChild: const SizedBox(height: 1),
                        ),

                        const SizedBox(height: 30),

                        // BPM row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  'assets/icons/light/arrows.png',
                                  width: 90,
                                  height: 90,
                                  color: cText,
                                ),
                                const SizedBox(width: 30),
                                GestureDetector(
                                  onTap: () => _changeBpmBy(-1),
                                  child: Image.asset(
                                    'assets/icons/light/minus.png',
                                    width: 80,
                                    height: 80,
                                    color: cText,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              bpmText,
                              style: TextStyle(
                                color: cText,
                                fontSize: 140,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _changeBpmBy(1),
                                  child: Image.asset(
                                    'assets/icons/light/plus.png',
                                    width: 80,
                                    height: 80,
                                    color: cText,
                                  ),
                                ),
                                const SizedBox(width: 30),
                                Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                                  child: Image.asset(
                                    'assets/icons/light/arrows.png',
                                    width: 90,
                                    height: 90,
                                    color: cText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        // BPM slider
                        _ThinSlider(
                          accent: cPrimary,
                          inactive: cText.withValues(alpha: 0.35),
                          value: bpm,
                          min: _bpmMin,
                          max: _bpmMax,
                          onChanged: (v) => _setBpm(v, push: false),
                          onChangeEnd: (v) => _setBpm(v, push: true),
                        ),

                        const SizedBox(height: 30),

                        // bottom buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: _openSettingsSheet,
                              child: Image.asset(
                                'assets/icons/light/setting.png',
                                width: 90,
                                height: 90,
                                color: cText,
                              ),
                            ),
                            GestureDetector(
                              onTap: _togglePlay,
                              child: Container(
                                width: 210,
                                height: 210,
                                decoration: BoxDecoration(
                                  color: cPrimary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Image.asset(
                                    isPlaying ? 'assets/icons/light/stop.png' : 'assets/icons/light/play.png',
                                    width: 110,
                                    height: 110,
                                    color: cText,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: isMemoryExpanded
                                  ? () => setState(() => isMemoryExpanded = false)
                                  : _openTapSheet,
                              child: Image.asset(
                                isMemoryExpanded ? 'assets/icons/light/exit.png' : 'assets/icons/light/hand.png',
                                width: 95,
                                height: 95,
                                color: cText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

// ======================= BEATS AREA =======================
class _BeatArea extends StatelessWidget {
  final Color accent;
  final int beatCount;
  final int activeIndex;
  final List<int> levels;
  final void Function(int index) onTapBeat;

  const _BeatArea({
    required this.accent,
    required this.beatCount,
    required this.activeIndex,
    required this.levels,
    required this.onTapBeat,
  });

  @override
  Widget build(BuildContext context) {
    final circles = List<Widget>.generate(beatCount, (i) {
      final level = levels[i].clamp(1, 3);
      final baseAlpha = switch (level) { 1 => 1.0, 2 => 0.55, _ => 0.0 };
      final isActive = i == activeIndex;
      final alpha = isActive ? 1.0 : baseAlpha;
      final scale = isActive ? 1.06 : 1.0;

      return GestureDetector(
        onTap: () => onTapBeat(i),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          scale: scale,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: alpha,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.95),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    });

    // 1~4개면 "세로 가운데" 느낌으로 내려오는 배치
    if (beatCount <= 4) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 70),
              ..._withGaps(circles, 55),
              const SizedBox(width: 70),
            ],
          ),
        ),
      );
    }

    final topRow = circles.take(4).toList(growable: false);
    final botRow = circles.skip(4).toList(growable: false);

    return SizedBox(
      height: 520,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 70),
              ..._withGaps(topRow, 55),
              const SizedBox(width: 70),
            ],
          ),
          const SizedBox(height: 70),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 70),
              ..._withGaps(botRow, 55),
              const SizedBox(width: 70),
            ],
          ),
        ],
      ),
    );
  }

  static List<Widget> _withGaps(List<Widget> items, double gap) {
    final out = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) out.add(SizedBox(width: gap));
    }
    return out;
  }
}

// ======================= MEMORY BUTTONS =======================
class _MemoryButton extends StatelessWidget {
  final MemoryPreset preset;
  final Color accent;
  final Color text;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MemoryButton({
    required this.preset,
    required this.accent,
    required this.text,
    required this.active,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bg = accent.withValues(alpha: active ? 1.0 : 0.6);
    final bottom = '${preset.beats} / ${preset.notes}';
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 230,
        height: 325,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(54),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${preset.bpm}',
                style: TextStyle(color: text, fontSize: 86, fontWeight: FontWeight.w700, height: 1.0),
              ),
              const SizedBox(height: 10),
              Text(
                bottom,
                style: TextStyle(color: text, fontSize: 62, fontWeight: FontWeight.w700, height: 1.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryGrid extends StatelessWidget {
  final List<MemoryPreset> presets;
  final Color accent;
  final Color text;
  final bool Function(MemoryPreset p) isActive;
  final void Function(int i) onTap;
  final void Function(int i) onLong;

  const _MemoryGrid({
    required this.presets,
    required this.accent,
    required this.text,
    required this.isActive,
    required this.onTap,
    required this.onLong,
  });

  @override
  Widget build(BuildContext context) {
    const cols = 4;
    final rows = (presets.length / cols).ceil();
    return Column(
      children: List<Widget>.generate(rows, (r) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(cols, (c) {
              final idx = r * cols + c;
              if (idx >= presets.length) return const SizedBox(width: 230);
              final p = presets[idx];
              final active = isActive(p);
              final bg = accent.withValues(alpha: active ? 1.0 : 0.6);
              return GestureDetector(
                onTap: () => onTap(idx),
                onLongPress: () => onLong(idx),
                child: Container(
                  width: 230,
                  height: 175,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${p.bpm}',
                          style: TextStyle(color: text, fontSize: 56, fontWeight: FontWeight.w700, height: 1.0),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${p.beats} / ${p.notes}',
                          style: TextStyle(color: text, fontSize: 42, fontWeight: FontWeight.w700, height: 1.0),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

// ======================= ICON BUTTON =======================
class _SquareIconButton extends StatelessWidget {
  final double size;
  final double radius;
  final Color bg;
  final String asset;
  final Color iconColor;
  final Color overlayColor;
  final double opacity;
  final VoidCallback? onTap;

  const _SquareIconButton({
    required this.size,
    required this.radius,
    required this.bg,
    required this.asset,
    required this.iconColor,
    required this.overlayColor,
    required this.opacity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        overlayColor: WidgetStatePropertyAll(overlayColor),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: Image.asset(
              asset,
              width: size * 0.55,
              height: size * 0.55,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= THIN SLIDER =======================
class _ThinSlider extends StatelessWidget {
  final Color accent;
  final Color inactive;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _ThinSlider({
    required this.accent,
    required this.inactive,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 8,
        activeTrackColor: accent,
        inactiveTrackColor: inactive,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        thumbShape: const _OvalThumbShape(width: 30, height: 72),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

class _OvalThumbShape extends SliderComponentShape {
  final double width;
  final double height;
  const _OvalThumbShape({required this.width, required this.height});

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
    final canvas = context.canvas;
    final paint = Paint()..color = sliderTheme.thumbColor ?? Colors.white;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: width, height: height),
      const Radius.circular(999),
    );
    canvas.drawRRect(r, paint);
  }
}

// ======================= ANCHOR DROPDOWN =======================
class _AnchorDropdown<T> extends StatefulWidget {
  final double width;
  final T value;
  final List<T> items;
  final String Function(T v) itemLabel;
  final TextStyle textStyle;
  final Color arrowColor;
  final Color bg;
  final Color menuBg;
  final void Function(T v) onChanged;

  const _AnchorDropdown({
    required this.width,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.textStyle,
    required this.arrowColor,
    required this.bg,
    required this.menuBg,
    required this.onChanged,
  });

  @override
  State<_AnchorDropdown<T>> createState() => _AnchorDropdownState<T>();
}

class _AnchorDropdownState<T> extends State<_AnchorDropdown<T>> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  void _toggle() {
    if (_entry != null) {
      _close();
      return;
    }
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: const Offset(0, 92), // "바로 아래"에 위치
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: widget.width * 0.85, // 더 날씬하게
                  decoration: BoxDecoration(
                    color: widget.menuBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.items.map((it) {
                      final selected = it == widget.value;
                      return InkWell(
                        onTap: () {
                          _close();
                          widget.onChanged(it);
                        },
                        child: SizedBox(
                          height: 70,
                          child: Center(
                            child: Text(
                              widget.itemLabel(it),
                              style: widget.textStyle.copyWith(
                                fontSize: 52,
                                color: widget.textStyle.color,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _toggle,
        child: SizedBox(
          width: widget.width,
          height: 80,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.width - 46,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.itemLabel(widget.value),
                    style: widget.textStyle,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 34, // 더 작게
                color: widget.arrowColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= TAP SHEET =======================
class _TapSheet extends StatefulWidget {
  final Color accent;
  final Color text;
  final Color panel;
  final int bpm;
  final void Function(int bpm) onBpm;

  const _TapSheet({
    required this.accent,
    required this.text,
    required this.panel,
    required this.bpm,
    required this.onBpm,
  });

  @override
  State<_TapSheet> createState() => _TapSheetState();
}

class _TapSheetState extends State<_TapSheet> {
  final List<int> _taps = <int>[];
  int _bpm = 120;

  @override
  void initState() {
    super.initState();
    _bpm = widget.bpm;
  }

  void _tap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _taps.add(now);
    if (_taps.length > 8) _taps.removeAt(0);

    if (_taps.length >= 2) {
      final diffs = <int>[];
      for (int i = 1; i < _taps.length; i++) {
        diffs.add(_taps[i] - _taps[i - 1]);
      }
      final avgMs = diffs.reduce((a, b) => a + b) / diffs.length;
      final next = (60000.0 / avgMs).round().clamp(40, 260);
      setState(() => _bpm = next);
      widget.onBpm(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handle = widget.accent.withValues(alpha: 0.6);
    final tapOpacity = 0.8;

    return SafeArea(
      top: false,
      child: Container(
        height: 520, // 전체 높이 더 낮춤
        decoration: BoxDecoration(
          color: widget.panel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              width: 140,
              height: 10,
              decoration: BoxDecoration(
                color: handle,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'BPM: $_bpm',
                  style: TextStyle(
                    color: widget.text,
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
                child: Opacity(
                  opacity: tapOpacity,
                  child: GestureDetector(
                    onTap: _tap,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(44),
                      ),
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: tapOpacity,
                        child: Image.asset(
                          'assets/icons/light/hand.png',
                          width: 140,
                          height: 140,
                          color: widget.text,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= SETTINGS SHEET =======================
class _SettingsSheet extends StatefulWidget {
  final Color accent;
  final Color text;
  final Color panel;

  final ClickType clickType;
  final int themeIndex;
  final double volumeMul;
  final double balance;

  final bool keepScreenOn;
  final bool soundMix;
  final bool backgroundPlay;

  final void Function(ClickType v) onClickType;
  final void Function(int idx) onTheme;
  final void Function(double v) onVolume;
  final void Function(double v) onBalance;
  final void Function(bool v) onKeepOn;
  final void Function(bool v) onMix;
  final void Function(bool v) onBg;

  const _SettingsSheet({
    required this.accent,
    required this.text,
    required this.panel,
    required this.clickType,
    required this.themeIndex,
    required this.volumeMul,
    required this.balance,
    required this.keepScreenOn,
    required this.soundMix,
    required this.backgroundPlay,
    required this.onClickType,
    required this.onTheme,
    required this.onVolume,
    required this.onBalance,
    required this.onKeepOn,
    required this.onMix,
    required this.onBg,
  });

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late ClickType _clickType;
  late int _themeIndex;
  late double _volumeMul;
  late double _balance;

  late bool _keepOn;
  late bool _mix;
  late bool _bg;

  @override
  void initState() {
    super.initState();
    _clickType = widget.clickType;
    _themeIndex = widget.themeIndex;
    _volumeMul = widget.volumeMul;
    _balance = widget.balance;
    _keepOn = widget.keepScreenOn;
    _mix = widget.soundMix;
    _bg = widget.backgroundPlay;
  }

  double _snapVolume(double v) {
    double out = v.clamp(0.0, 3.0);
    final pct = (out * 100).round();
    if ((pct - 100).abs() <= 2) out = 1.0;
    if ((pct - 200).abs() <= 2) out = 2.0;
    return out;
  }

  double _snapBalance(double v) {
    double out = v.clamp(-1.0, 1.0);
    if (out.abs() <= 0.06) out = 0.0;
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final handle = widget.accent.withValues(alpha: 0.6);

    final volPct = (_volumeMul * 100).round().clamp(0, 300);

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          color: widget.panel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              width: 140,
              height: 10,
              decoration: BoxDecoration(
                color: handle,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 26),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(26, 10, 26, 30),
                child: Column(
                  children: [
                    _RowLabelDropdown(
                      label: '클릭 종류',
                      text: widget.text,
                      accent: widget.accent,
                      valueText: _clickType.label,
                      onTap: () async {
                        final v = await _selectClickType(context, _clickType, widget);
                        if (v == null) return;
                        setState(() => _clickType = v);
                        widget.onClickType(v);
                      },
                    ),
                    const SizedBox(height: 26),
                    _RowThemeDropdown(
                      label: '테마',
                      text: widget.text,
                      accent: widget.accent,
                      themeIndex: _themeIndex,
                      onTap: () async {
                        final idx = await _selectTheme(context, _themeIndex, widget.text);
                        if (idx == null) return;
                        setState(() => _themeIndex = idx);
                        widget.onTheme(idx);
                      },
                    ),
                    const SizedBox(height: 34),

                    // volume
                    _RowTitle(
                      title: '소리 크기: $volPct%',
                      text: widget.text,
                    ),
                    const SizedBox(height: 10),
                    _SliderWithIconsAndMarks(
                      accent: widget.accent,
                      inactive: widget.text.withValues(alpha: 0.35),
                      text: widget.text,
                      leftAsset: 'assets/icons/light/mute.png',
                      rightAsset: 'assets/icons/light/volume.png',
                      value: _volumeMul,
                      min: 0.0,
                      max: 3.0,
                      marks: const [1.0, 2.0],
                      centerMark: null,
                      onChanged: (v) {
                        setState(() => _volumeMul = v);
                        widget.onVolume(_volumeMul);
                      },
                      onChangeEnd: (v) {
                        final snapped = _snapVolume(v);
                        setState(() => _volumeMul = snapped);
                        widget.onVolume(_volumeMul);
                      },
                    ),

                    const SizedBox(height: 34),

                    // balance
                    _RowTitle(title: '소리 밸런스', text: widget.text),
                    const SizedBox(height: 10),
                    _SliderWithIconsAndMarks(
                      accent: widget.accent,
                      inactive: widget.text.withValues(alpha: 0.35),
                      text: widget.text,
                      leftAsset: 'assets/icons/light/arrows.png',
                      rightAsset: 'assets/icons/light/arrows.png',
                      leftMirror: true,
                      value: _balance,
                      min: -1.0,
                      max: 1.0,
                      marks: const [],
                      centerMark: 0.0,
                      onChanged: (v) {
                        setState(() => _balance = v);
                        widget.onBalance(_balance);
                      },
                      onChangeEnd: (v) {
                        final snapped = _snapBalance(v);
                        setState(() => _balance = snapped);
                        widget.onBalance(_balance);
                      },
                    ),

                    const SizedBox(height: 30),

                    _RowSwitch(
                      label: '화면 켜짐 유지',
                      text: widget.text,
                      value: _keepOn,
                      onChanged: (v) {
                        setState(() => _keepOn = v);
                        widget.onKeepOn(v);
                      },
                    ),
                    const SizedBox(height: 18),
                    _RowSwitch(
                      label: '소리 혼합',
                      text: widget.text,
                      value: _mix,
                      onChanged: (v) {
                        setState(() => _mix = v);
                        widget.onMix(v);
                      },
                    ),
                    const SizedBox(height: 18),
                    _RowSwitch(
                      label: '백그라운드 재생',
                      text: widget.text,
                      value: _bg,
                      onChanged: (v) {
                        setState(() => _bg = v);
                        widget.onBg(v);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<ClickType?> _selectClickType(BuildContext context, ClickType cur, _SettingsSheet widget) async {
    return showModalBottomSheet<ClickType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: widget.panel,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 140,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                ...ClickType.values.map((e) {
                  final selected = e == cur;
                  return ListTile(
                    title: Center(
                      child: Text(
                        e.label,
                        style: TextStyle(
                          color: widget.text,
                          fontSize: 42,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, e),
                  );
                }),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int?> _selectTheme(BuildContext context, int cur, Color text) async {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF4A4A4A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 140,
                  height: 10,
                  decoration: BoxDecoration(
                    color: kThemes[cur].color.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                ...List<int>.generate(kThemes.length, (i) => i).map((i) {
                  final selected = i == cur;
                  return ListTile(
                    leading: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: kThemes[i].color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      kThemes[i].name,
                      style: TextStyle(
                        color: text,
                        fontSize: 40,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, i),
                  );
                }),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RowTitle extends StatelessWidget {
  final String title;
  final Color text;

  const _RowTitle({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          color: text,
          fontSize: 40,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RowSwitch extends StatelessWidget {
  final String label;
  final Color text;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RowSwitch({
    required this.label,
    required this.text,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: text, fontSize: 38, fontWeight: FontWeight.w700),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RowLabelDropdown extends StatelessWidget {
  final String label;
  final Color text;
  final Color accent;
  final String valueText;
  final VoidCallback onTap;

  const _RowLabelDropdown({
    required this.label,
    required this.text,
    required this.accent,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: text, fontSize: 38, fontWeight: FontWeight.w700),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF202020).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Text(
                  valueText,
                  style: TextStyle(color: text, fontSize: 36, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Icon(Icons.keyboard_arrow_down_rounded, color: text, size: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RowThemeDropdown extends StatelessWidget {
  final String label;
  final Color text;
  final Color accent;
  final int themeIndex;
  final VoidCallback onTap;

  const _RowThemeDropdown({
    required this.label,
    required this.text,
    required this.accent,
    required this.themeIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = kThemes[themeIndex];
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: text, fontSize: 38, fontWeight: FontWeight.w700),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF202020).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 12),
                Text(
                  item.name,
                  style: TextStyle(color: text, fontSize: 36, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Icon(Icons.keyboard_arrow_down_rounded, color: text, size: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SliderWithIconsAndMarks extends StatelessWidget {
  final Color accent;
  final Color inactive;
  final Color text;
  final String leftAsset;
  final String rightAsset;
  final bool leftMirror;

  final double value;
  final double min;
  final double max;
  final List<double> marks;
  final double? centerMark;

  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _SliderWithIconsAndMarks({
    required this.accent,
    required this.inactive,
    required this.text,
    required this.leftAsset,
    required this.rightAsset,
    required this.value,
    required this.min,
    required this.max,
    required this.marks,
    required this.centerMark,
    required this.onChanged,
    required this.onChangeEnd,
    this.leftMirror = false,
  });

  @override
  Widget build(BuildContext context) {
    final trackH = 8.0;
    final thumbW = 28.0;
    final thumbH = 66.0;

    return Row(
      children: [
        leftMirror
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
                child: Image.asset(leftAsset, width: 54, height: 54, color: text),
              )
            : Image.asset(leftAsset, width: 54, height: 54, color: text),
        const SizedBox(width: 16),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // marks
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (ctx, c) {
                    final w = c.maxWidth;
                    final List<Widget> ws = [];

                    for (final m in marks) {
                      final t = ((m - min) / (max - min)).clamp(0.0, 1.0);
                      ws.add(Positioned(
                        left: w * t - 1,
                        child: Container(
                          width: 2,
                          height: 16,
                          color: const Color(0xFFB0B0B0).withValues(alpha: 0.6),
                        ),
                      ));
                    }

                    if (centerMark != null) {
                      final t = ((centerMark! - min) / (max - min)).clamp(0.0, 1.0);
                      ws.add(Positioned(
                        left: w * t - 1.5,
                        child: Container(
                          width: 3,
                          height: 18,
                          color: const Color(0xFFB0B0B0).withValues(alpha: 0.75),
                        ),
                      ));
                    }

                    return Stack(children: ws);
                  },
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: trackH,
                  activeTrackColor: accent,
                  inactiveTrackColor: inactive,
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
                  thumbShape: _OvalThumbShape(width: thumbW, height: thumbH),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Image.asset(rightAsset, width: 54, height: 54, color: text),
      ],
    );
  }
}