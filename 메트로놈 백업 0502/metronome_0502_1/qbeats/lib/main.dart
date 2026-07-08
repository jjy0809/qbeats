import 'dart:collection'; // 최근 재생 핸들을 짧게 관리하기 위한 큐를 불러옵니다.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data'; // 오디오 바이트 가공을 위한 타입을 불러옵니다.

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
part 'main_layout.dart'; // 반응형 레이아웃과 슬라이드 팝업 파트를 연결합니다.

Future<void> main() async { // 앱 시작 진입점을 정의합니다.
  WidgetsFlutterBinding.ensureInitialized(); // 플러터 바인딩을 먼저 초기화합니다.
  await _initSvc(); // 외부 서비스를 안전하게 초기화합니다.
  runApp(const MetronomeApp()); // 루트 앱을 실행합니다.
} // 앱 시작 구성을 마칩니다.

Future<void> _initSvc() async { // 시작 서비스 초기화를 묶습니다.
  try { // 광고 초기화 실패가 앱 전체를 멈추지 않게 막습니다.
    await MobileAds.instance.initialize(); // 모바일 광고 SDK를 초기화합니다.
  } catch (_) {} // 광고 초기화 예외는 무시합니다.
  try { // 파이어베이스 초기화도 개별적으로 보호합니다.
    await Firebase.initializeApp(); // 파이어베이스를 초기화합니다.
  } catch (_) {} // 파이어베이스 초기화 예외는 무시합니다.
} // 시작 서비스 초기화를 마칩니다.

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
  double bpm = 89;
  int beatCount = 8;
  int noteCount = 1;
  bool isPlaying = false;

  bool _showMemoryGrid = false;

  final List<int> beatLevels = List<int>.filled(8, 1);
  int _lastBpmInt = 89;

  late List<MemoryPreset> memoryPresets = List<MemoryPreset>.generate(
    40,
    (_) => const MemoryPreset(bpm: 120, beats: 4, notes: 1),
  );

  final List<SettingSnapshot> _history = <SettingSnapshot>[];

  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _clickSource;
  final ListQueue<SoundHandle> _hQ = ListQueue<SoundHandle>(); // 최근 재생 핸들을 짧게 유지하는 큐를 저장합니다.

  Timer? _tickTimer;
  Stopwatch? _stopwatch;

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

  double _masterVolume = 1.0;
  double _balance = 0.0;

  bool _keepScreenOn = true;
  bool _soundMix = true;
  bool _backgroundPlay = true;

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
  bool _audOk = false; // 오디오 엔진 준비 여부를 저장합니다.
  int _adW = 0; // 마지막 배너 로드 기준 너비를 저장합니다.
  Orientation? _adO; // 마지막 배너 로드 기준 방향을 저장합니다.
  int _audSeq = 0; // 다음 오디오 재생 틱 순번을 저장합니다.
  int _visSeq = 0; // 다음 시각 표시 틱 순번을 저장합니다.
  double _baseUs = 0.0; // 현재 템포 기준선의 절대 시간을 저장합니다.
  double _baseSeq = 0.0; // 현재 템포 기준선의 틱 위치를 저장합니다.
  double _stepUs = 0.0; // 현재 템포의 틱 간격 마이크로초를 저장합니다.

  static const int _audLeadUs = 8000; // 오디오 호출을 미리 당길 마이크로초 보정값입니다.
  static const int _schMinUs = 1200; // 스케줄러가 가장 짧게 대기할 시간입니다.
  static const int _schMaxUs = 6000; // 스케줄러가 가장 길게 대기할 시간입니다.

  // =========================
  // AdMob: Banner + App Open
  // =========================

  static const String _bannerUnitId = 'ca-app-pub-7323951525567036/2502811037';
  BannerAd? _bannerAd;
  AdSize? _bannerSize;
  bool _bannerLoaded = false;

  static const String _appOpenUnitId = 'ca-app-pub-7323951525567036/4878127701';
  AppOpenAd? _appOpenAd;
  bool _isShowingAppOpenAd = false;
  bool _isLoadingAppOpenAd = false;

  Future<void> _loadBanner() async {
    try {
      _bannerAd?.dispose();
      _bannerAd = null;
      _bannerLoaded = false;

      if (!mounted) return;

      final width = MediaQuery.of(context).size.width.floor();
      final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

      if (!mounted) return;

      final resolved = (size == null)
          ? AdSize.largeBanner
          : (size.height < 90 ? AdSize.largeBanner : size);

      _bannerSize = resolved;

      final ad = BannerAd(
        adUnitId: _bannerUnitId,
        request: const AdRequest(),
        size: _bannerSize!,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) return;
            setState(() {
              _bannerAd = ad as BannerAd;
              _bannerLoaded = true;
            });
          },
          onAdFailedToLoad: (ad, err) {
            ad.dispose();
            if (!mounted) return;
            setState(() {
              _bannerAd = null;
              _bannerLoaded = false;
            });
          },
        ),
      );

      await ad.load();
      if (!mounted) return;
      setState(() {});
    } catch (_) {}
  }

  void _loadAppOpenAd() {
    if (_isLoadingAppOpenAd) return;
    _isLoadingAppOpenAd = true;

    AppOpenAd.load(
      adUnitId: _appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingAppOpenAd = false;
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (error) {
          _isLoadingAppOpenAd = false;
          _appOpenAd = null;
        },
      ),
    );
  }

  void _showAppOpenAdIfAvailable() {
    if (_isShowingAppOpenAd) return;
    if (isPlaying) return;

    final ad = _appOpenAd;
    if (ad == null) {
      _loadAppOpenAd();
      return;
    }

    _isShowingAppOpenAd = true;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {},
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpenAd();
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        _loadAppOpenAd();
      },
    );

    ad.show();
    _appOpenAd = null;
  }

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

    _loadAppOpenAd();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadBanner();
      _showAppOpenAdIfAvailable();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;

    _appOpenAd?.dispose();
    _appOpenAd = null;

    WidgetsBinding.instance.removeObserver(this);
    _stopMetronome();
    if (_audOk && _clickSource != null) { // 오디오가 준비된 경우에만 소스를 정리합니다.
      try { // 정리 중 예외를 개별적으로 막습니다.
        _soloud.disposeSource(_clickSource!); // 클릭 소스를 해제합니다.
      } catch (_) {} // 소스 해제 예외는 무시합니다.
    } // 클릭 소스 정리를 마칩니다.
    if (_audOk) { // 오디오 엔진이 살아 있을 때만 종료합니다.
      try { // 엔진 종료 예외도 안전하게 막습니다.
        _soloud.deinit(); // 오디오 엔진을 종료합니다.
      } catch (_) {} // 엔진 종료 예외는 무시합니다.
    } // 오디오 엔진 종료를 마칩니다.
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

    if (state == AppLifecycleState.resumed) {
      _showAppOpenAdIfAvailable();
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

      await sp.setDouble(_kPrefMasterVol, _masterVolume);

      await sp.setDouble(_kPrefBalance, _balance);
      await sp.setBool(_kPrefKeepOn, _keepScreenOn);
      await sp.setBool(_kPrefMix, _soundMix);
      await sp.setBool(_kPrefBg, _backgroundPlay);
    } catch (_) {}
  }

  Future<void> _initAudio() async { // 오디오 엔진을 준비합니다.
    try { // 초기화 예외를 개별적으로 보호합니다.
      await _soloud.init(sampleRate: 48000, bufferSize: 256, channels: Channels.stereo); // 파일 샘플레이트와 맞춘 상태로 엔진을 초기화합니다.
      _audOk = true; // 오디오 준비 완료 상태를 기록합니다.
      await _reloadClickSource(); // 현재 선택된 클릭 소스를 다시 불러옵니다.
    } catch (_) { // 초기화 실패를 잡습니다.
      _audOk = false; // 오디오 준비 실패 상태를 기록합니다.
    } // 오디오 초기화 예외 처리를 마칩니다.
  } // 오디오 엔진 준비를 마칩니다.

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

  Duration _clickTrimForKind(ClickKind k) { // 파일별 선행 무음을 줄이기 위한 보정값을 반환합니다.
    switch (k) { // 클릭 종류별 측정값을 분기합니다.
      case ClickKind.dgit1: // 디지털 1의 보정값을 반환합니다.
        return const Duration(milliseconds: 135); // 측정된 선행 무음 대부분을 잘라냅니다.
      case ClickKind.dgit2: // 디지털 2의 보정값을 반환합니다.
        return const Duration(milliseconds: 23); // 짧은 선행 무음을 줄입니다.
      case ClickKind.dgit3: // 디지털 3의 보정값을 반환합니다.
        return const Duration(milliseconds: 83); // 측정된 선행 무음을 줄입니다.
      case ClickKind.anal1: // 아날로그 1의 보정값을 반환합니다.
        return const Duration(milliseconds: 128); // 측정된 선행 무음을 줄입니다.
      case ClickKind.anal2: // 아날로그 2의 보정값을 반환합니다.
        return const Duration(milliseconds: 130); // 측정된 선행 무음을 줄입니다.
      case ClickKind.anal3: // 아날로그 3의 보정값을 반환합니다.
        return const Duration(milliseconds: 110); // 측정된 선행 무음을 줄입니다.
    } // 클릭 종류 분기를 마칩니다.
  } // 파일별 클릭 보정값 반환을 마칩니다.

  double _calcStepUs({double? bpmVal, int? noteVal}) { // 현재 설정 기준 틱 간격을 실수 마이크로초로 계산합니다.
    final bpmNum = bpmVal ?? bpm; // 계산에 사용할 BPM 값을 고릅니다.
    final noteNum = noteVal ?? noteCount; // 계산에 사용할 분할 수를 고릅니다.
    return 60000000.0 / bpmNum / noteNum; // 1분을 현재 BPM과 분할 수로 나눈 틱 간격을 반환합니다.
  } // 틱 간격 계산을 마칩니다.

  void _retimeBpm(double nextBpm) { // 재생 위치를 유지한 채 템포만 바꿉니다.
    final sw = _stopwatch; // 현재 기준 시계를 가져옵니다.
    if (!isPlaying || sw == null || _stepUs <= 0) return; // 재생 중이 아니면 재타이밍하지 않습니다.
    final nowUs = sw.elapsedMicroseconds.toDouble(); // 현재 경과 시간을 실수 마이크로초로 구합니다.
    final pos = _baseSeq + ((nowUs - _baseUs) / _stepUs); // 현재 시간축에서의 연속 틱 위치를 계산합니다.
    _baseUs = nowUs; // 새 기준 절대 시간을 현재 시각으로 옮깁니다.
    _baseSeq = pos; // 새 기준 틱 위치를 현재 연속 위치로 옮깁니다.
    _stepUs = _calcStepUs(bpmVal: nextBpm, noteVal: noteCount); // 새 BPM 기준 틱 간격을 다시 계산합니다.
    _tickTimer?.cancel(); // 기존 짧은 폴링 타이머를 정리합니다.
    _runTickLoop(); // 새 템포 기준으로 즉시 다음 스케줄을 다시 잡습니다.
  } // BPM 연속 변경 재타이밍을 마칩니다.

  Uint8List _trimWav(Uint8List src, Duration cut) { // WAV 바이트에서 선행 무음을 잘라낸 새 버퍼를 만듭니다.
    if (src.length < 44 || cut <= Duration.zero) return src; // WAV가 아니거나 자를 필요가 없으면 원본을 반환합니다.
    final bd = ByteData.sublistView(src); // 원본 버퍼를 바이트 데이터 뷰로 엽니다.
    if (String.fromCharCodes(src.sublist(0, 4)) != 'RIFF') return src; // RIFF 헤더가 아니면 원본을 반환합니다.
    if (String.fromCharCodes(src.sublist(8, 12)) != 'WAVE') return src; // WAVE 포맷이 아니면 원본을 반환합니다.
    int fmtOff = -1; // fmt 청크 시작 위치를 저장합니다.
    int dataOff = -1; // data 청크 시작 위치를 저장합니다.
    int dataLen = -1; // data 청크 길이를 저장합니다.
    int off = 12; // 첫 청크 탐색 시작 위치를 저장합니다.
    while (off + 8 <= src.length) { // 끝까지 청크를 순회합니다.
      final id = String.fromCharCodes(src.sublist(off, off + 4)); // 현재 청크 아이디를 읽습니다.
      final len = bd.getUint32(off + 4, Endian.little); // 현재 청크 길이를 읽습니다.
      final bodyOff = off + 8; // 현재 청크 본문 시작 위치를 계산합니다.
      if (id == 'fmt ') fmtOff = bodyOff; // fmt 청크를 찾으면 본문 시작 위치를 저장합니다.
      if (id == 'data') { // data 청크를 찾으면 관련 정보를 저장합니다.
        dataOff = bodyOff; // data 본문 시작 위치를 저장합니다.
        dataLen = len; // data 길이를 저장합니다.
        break; // 필요한 청크를 찾았으므로 탐색을 마칩니다.
      } // data 청크 처리 분기를 마칩니다.
      off = bodyOff + len + (len.isOdd ? 1 : 0); // 패딩 바이트를 포함한 다음 청크 위치로 이동합니다.
    } // WAV 청크 순회를 마칩니다.
    if (fmtOff < 0 || dataOff < 0 || dataLen <= 0) return src; // 필수 청크가 없으면 원본을 반환합니다.
    final sampleRate = bd.getUint32(fmtOff + 4, Endian.little); // 샘플레이트를 읽습니다.
    final blockAlign = bd.getUint16(fmtOff + 12, Endian.little); // 프레임 바이트 수를 읽습니다.
    if (sampleRate <= 0 || blockAlign <= 0) return src; // 포맷 정보가 비정상이면 원본을 반환합니다.
    final cutBytes = (((cut.inMicroseconds * sampleRate) / 1000000).floor() * blockAlign).clamp(0, dataLen); // 잘라낼 데이터 바이트 수를 계산합니다.
    if (cutBytes <= 0 || cutBytes >= dataLen) return src; // 잘라낼 양이 비정상이면 원본을 반환합니다.
    final headLen = dataOff; // 헤더와 data 청크 헤더까지의 길이를 저장합니다.
    final newDataLen = dataLen - cutBytes; // 잘라낸 뒤 남는 PCM 길이를 계산합니다.
    final out = Uint8List(headLen + newDataLen); // 새 WAV 버퍼를 필요한 크기로 생성합니다.
    out.setRange(0, headLen, src); // 헤더와 data 청크 시작 전까지를 그대로 복사합니다.
    out.setRange(headLen, headLen + newDataLen, src.sublist(dataOff + cutBytes, dataOff + dataLen)); // 잘라낸 뒤 남는 PCM 데이터만 복사합니다.
    final outBd = ByteData.sublistView(out); // 새 버퍼를 수정 가능한 뷰로 엽니다.
    outBd.setUint32(4, out.length - 8, Endian.little); // RIFF 전체 길이를 새 버퍼 기준으로 다시 기록합니다.
    outBd.setUint32(dataOff - 4, newDataLen, Endian.little); // data 청크 길이를 잘라낸 크기로 다시 기록합니다.
    return out; // 잘라낸 새 WAV 버퍼를 반환합니다.
  } // WAV 선행 무음 제거를 마칩니다.

  Future<void> _reloadClickSource() async { // 클릭 소스를 다시 불러옵니다.
    if (!_audOk) return; // 오디오 엔진이 준비되지 않았으면 중단합니다.
    try { // 소스 교체 예외를 보호합니다.
      final nextAsset = _clickAssetForKind(_clickKind); // 현재 클릭 종류에 맞는 에셋을 구합니다.
      if (_clickSource != null) { // 기존 소스가 있으면 먼저 정리합니다.
        _soloud.disposeSource(_clickSource!); // 기존 클릭 소스를 해제합니다.
        _clickSource = null; // 기존 소스 참조를 비웁니다.
      } // 기존 소스 정리를 마칩니다.
      final raw = await rootBundle.load(nextAsset); // 원본 클릭 에셋 바이트를 읽습니다.
      final buf = Uint8List.sublistView(raw); // 원본 바이트를 리스트 뷰로 변환합니다.
      final trim = _trimWav(buf, _clickTrimForKind(_clickKind)); // 파일별 선행 무음을 잘라낸 새 버퍼를 만듭니다.
      _clickSource = await _soloud.loadMem(nextAsset, trim); // 잘라낸 클릭 버퍼를 메모리에서 바로 불러옵니다.
    } catch (_) {} // 클릭 소스 교체 예외는 무시합니다.
  } // 클릭 소스 재로딩을 마칩니다.

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
    if (isPlaying) _retimeBpm(next); // 재생 중이면 박자 위치를 유지한 채 템포만 바꿉니다.
    _savePrefs();
  }

  void _previewBpm(double v) { // 슬라이더 이동 중 BPM 미리보기를 갱신합니다.
    final next = v.clamp(_bpmMin, _bpmMax); // 미리보기에도 동일한 BPM 범위를 적용합니다.
    setState(() { // 화면에 반영할 BPM 숫자를 즉시 갱신합니다.
      _lastBpmInt = bpm.round(); // 이전 BPM 값을 보존합니다.
      bpm = next; // 새 BPM 값을 범위 안으로 반영합니다.
    }); // BPM 미리보기 갱신을 마칩니다.
    if (isPlaying) _retimeBpm(next); // 재생 중이면 드래그 중에도 템포를 끊김 없이 반영합니다.
  } // 슬라이더 BPM 미리보기 메서드를 마칩니다.

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

  Future<void> _togglePlay() async { // 재생 상태를 토글합니다.
    if (isPlaying) { // 이미 재생 중이면 정지로 전환합니다.
      _stopMetronome(); // 메트로놈 타이머를 멈춥니다.
      setState(() => isPlaying = false); // 재생 상태를 해제합니다.
      return; // 정지 처리 뒤 종료합니다.
    } // 정지 분기를 마칩니다.
    setState(() => isPlaying = true); // 재생 상태를 먼저 반영합니다.
    final ok = await _startMetronome(); // 실제 재생 시작 가능 여부를 확인합니다.
    if (!ok && mounted) { // 오디오가 준비되지 않아 시작 실패한 경우를 처리합니다.
      setState(() => isPlaying = false); // 화면 상태를 다시 정지로 되돌립니다.
    } // 시작 실패 보정을 마칩니다.
  } // 재생 토글 처리를 마칩니다.

  Future<void> _restartMetronome() async { // 현재 설정으로 메트로놈을 다시 시작합니다.
    if (!isPlaying) return; // 재생 중이 아니면 다시 시작하지 않습니다.
    _stopMetronome(); // 기존 타이머와 소리를 먼저 정리합니다.
    final ok = await _startMetronome(); // 새 설정으로 다시 시작합니다.
    if (!ok && mounted) { // 재시작이 실패하면 상태를 바로잡습니다.
      setState(() => isPlaying = false); // 재생 상태를 해제합니다.
    } // 재시작 실패 보정을 마칩니다.
  } // 메트로놈 재시작을 마칩니다.

  Future<bool> _startMetronome() async { // 메트로놈 재생을 시작합니다.
    if (_clickSource == null) { // 클릭 소스가 비어 있으면 한 번 더 재로딩합니다.
      await _reloadClickSource(); // 현재 설정으로 클릭 소스를 다시 준비합니다.
    } // 클릭 소스 준비 시도를 마칩니다.
    if (_clickSource == null) return false; // 소스가 없으면 시작 실패를 반환합니다.
    _tickTimer?.cancel(); // 기존 타이머가 있으면 취소합니다.
    _stopwatch?.stop(); // 기존 스톱워치가 있으면 멈춥니다.
    _stopwatch = Stopwatch()..start(); // 새 기준 시계를 시작합니다.
    _hQ.clear(); // 시작 시 최근 재생 핸들 큐를 비웁니다.
    _stepUs = _calcStepUs(bpmVal: bpm, noteVal: noteCount); // 현재 템포 기준 틱 간격을 계산합니다.
    _baseUs = _stopwatch!.elapsedMicroseconds.toDouble(); // 첫 클릭 시점을 기준 절대 시간으로 저장합니다.
    _baseSeq = 0.0; // 첫 클릭이 0번째 틱이 되도록 기준 틱 위치를 맞춥니다.
    _audSeq = 1; // 첫 클릭은 즉시 내보내고 다음 오디오 틱부터 스케줄링합니다.
    _visSeq = 1; // 첫 박자 원형도 즉시 갱신하고 다음 시각 틱부터 스케줄링합니다.
    _activeBeatIndex = -1; // 활성 박자 표시를 초기화합니다.
    _pulseToken = 0; // 펄스 토큰을 초기화합니다.
    _fireAud(0); // 시작 버튼을 누른 순간 첫 클릭을 즉시 재생합니다.
    _fireVis(0); // 첫 클릭과 같은 순간 첫 박자 원형도 즉시 갱신합니다.
    _runTickLoop(); // 정밀 스케줄링 루프를 시작합니다.
    return true; // 재생 시작 성공을 반환합니다.
  } // 메트로놈 시작 처리를 마칩니다.

  void _stopMetronome() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    _baseUs = 0.0; // 정지 시 기준 절대 시간을 초기화합니다.
    _baseSeq = 0.0; // 정지 시 기준 틱 위치를 초기화합니다.
    _stepUs = 0.0; // 정지 시 틱 간격 기준도 초기화합니다.
    _activeBeatIndex = -1;
    _pulseToken = 0;
    _stopAllSounds();
  }

  Future<void> _stopAllSounds() async { // 현재 재생 중인 소리를 모두 멈춥니다.
    if (!_audOk) { // 오디오 엔진이 준비되지 않은 경우를 처리합니다.
      _hQ.clear(); // 남아 있던 핸들만 비웁니다.
      return; // 추가 정지 호출 없이 종료합니다.
    } // 비준비 상태 분기를 마칩니다.
    final lst = _hQ.toList(growable: false); // 현재 남아 있는 최근 핸들 목록을 복사합니다.
    _hQ.clear(); // 즉시 정지감을 위해 큐를 먼저 비웁니다.
    try { // 정지 중 예외를 보호합니다.
      for (final h in lst) { // 기록된 최근 핸들을 순회합니다.
        unawaited(_soloud.stop(h)); // 각 사운드 정지를 기다리지 않고 바로 요청합니다.
      } // 핸들 순회를 마칩니다.
    } catch (_) {} // 사운드 정지 예외는 무시합니다.
  } // 전체 사운드 정지를 마칩니다.

  void _runTickLoop() { // 드리프트 없는 절대 시간 기준 스케줄러를 실행합니다.
    final sw = _stopwatch; // 현재 기준 시계를 가져옵니다.
    if (sw == null || !isPlaying || !mounted) return; // 재생이 끝났으면 루프를 중단합니다.
    final nowUs = sw.elapsedMicroseconds.toDouble(); // 현재 경과 시간을 실수 마이크로초로 구합니다.
    if (_stepUs <= 0) _stepUs = _calcStepUs(bpmVal: bpm, noteVal: noteCount); // 틱 간격 기준이 비어 있으면 현재 값으로 보정합니다.
    while (_audSeq <= _visSeq + 1) { // 오디오 선행 스케줄을 조금 앞서 유지합니다.
      final tgtUs = _baseUs + ((_audSeq - _baseSeq) * _stepUs); // 현재 오디오 틱의 절대 목표 시각을 구합니다.
      if (nowUs + _audLeadUs < tgtUs) break; // 아직 선행 예약 시점이 아니면 빠져나옵니다.
      _fireAud(_audSeq); // 현재 틱의 오디오를 예약합니다.
      _audSeq++; // 다음 오디오 틱 순번으로 넘어갑니다.
    } // 오디오 선행 예약 루프를 마칩니다.
    while (true) { // 시각 표시도 절대 시간 기준으로 따라갑니다.
      final tgtUs = _baseUs + ((_visSeq - _baseSeq) * _stepUs); // 현재 시각 틱의 절대 목표 시각을 구합니다.
      if (nowUs < tgtUs) break; // 아직 표시 시점이 아니면 빠져나옵니다.
      _fireVis(_visSeq); // 현재 틱의 시각 표시를 실행합니다.
      _visSeq++; // 다음 시각 틱 순번으로 넘어갑니다.
    } // 시각 표시 루프를 마칩니다.
    final nextAudUs = (_baseUs + ((_audSeq - _baseSeq) * _stepUs)) - _audLeadUs; // 다음 오디오 선행 예약 시각을 계산합니다.
    final nextVisUs = _baseUs + ((_visSeq - _baseSeq) * _stepUs); // 다음 시각 표시 시각을 계산합니다.
    final nextUs = math.min(nextAudUs, nextVisUs); // 더 이른 다음 작업 시각을 고릅니다.
    final waitUs = (nextUs - sw.elapsedMicroseconds).clamp(_schMinUs.toDouble(), _schMaxUs.toDouble()).round(); // 다음 폴링 대기 시간을 제한합니다.
    _tickTimer?.cancel(); // 기존 스케줄러 타이머를 정리합니다.
    _tickTimer = Timer(Duration(microseconds: waitUs), _runTickLoop); // 짧은 간격으로 다시 스케줄러를 호출합니다.
  } // 정밀 스케줄링 루프를 마칩니다.

  void _fireVis(int seq) { // 시각 박자 표시를 실제 목표 시각에 맞춰 갱신합니다.
    final beatIdx = (seq ~/ noteCount) % beatCount; // 현재 틱이 속한 박자 인덱스를 계산합니다.
    final subIdx = seq % noteCount; // 현재 틱의 세부 분할 인덱스를 계산합니다.
    if (subIdx != 0) return; // 메인 박자 외에는 원형 표시를 바꾸지 않습니다.
    if (!mounted) return; // 위젯이 사라졌으면 화면 갱신을 중단합니다.
    setState(() { // 박자 원형 표시를 한 프레임으로 갱신합니다.
      _activeBeatIndex = beatIdx; // 현재 활성 박자 인덱스를 반영합니다.
      _pulseToken++; // 펄스 애니메이션 토큰을 증가시킵니다.
    }); // 시각 박자 표시 갱신을 마칩니다.
  } // 시각 박자 처리 메서드를 마칩니다.

  void _fireAud(int seq) { // 오디오 클릭을 선행 예약 시점에 재생합니다.
    final src = _clickSource; // 현재 클릭 소스를 지역 변수로 고정합니다.
    if (!_audOk || src == null || !isPlaying) return; // 오디오 준비가 안 되었으면 중단합니다.
    final beatIdx = (seq ~/ noteCount) % beatCount; // 현재 틱이 속한 박자 인덱스를 계산합니다.
    final subIdx = seq % noteCount; // 현재 틱의 세부 분할 인덱스를 계산합니다.
    final lvl = beatLevels[beatIdx]; // 현재 박자의 강세 레벨을 가져옵니다.
    final baseVol = (lvl == 1) ? 1.0 : (lvl == 2) ? 0.5 : 0.0; // 강세 레벨에 따른 기본 볼륨을 계산합니다.
    final vol = baseVol * (subIdx == 0 ? 1.0 : 0.5) * _masterVolume; // 분할 박자와 마스터 볼륨을 반영한 최종 볼륨을 계산합니다.
    if (vol <= 0) return; // 무음 박자는 재생하지 않습니다.
    unawaited(_playClick(src, vol)); // 비동기 재생을 스케줄러와 분리해 호출합니다.
  } // 오디오 클릭 처리 메서드를 마칩니다.

  Future<void> _playClick(AudioSource src, double vol) async { // 클릭 재생과 파일별 보정을 수행합니다.
    try { // 재생 예외를 보호합니다.
      final h = await _soloud.play(src, volume: vol, pan: _balance); // 잘라낸 클릭 소스를 바로 재생해 시작 지연을 줄입니다.
      _hQ.addLast(h); // 즉시 정지를 위해 최근 핸들 큐 뒤에 기록합니다.
      while (_hQ.length > 8) { // 큐가 과도하게 길어지지 않도록 최근 핸들만 유지합니다.
        _hQ.removeFirst(); // 가장 오래된 핸들을 앞에서 제거합니다.
      } // 최근 핸들 큐 길이 제한을 마칩니다.
    } catch (_) {} // 클릭 재생 예외는 무시합니다.
  } // 클릭 재생 보정 처리를 마칩니다.

  void _syncBanner(Orientation ori, double w) { // 현재 방향과 너비에 맞춰 배너를 동기화합니다.
    final nextW = w.floor(); // 현재 화면 너비를 정수 기준으로 계산합니다.
    if (_adO == ori && (_adW - nextW).abs() < 8) return; // 방향과 너비가 사실상 같으면 건너뜁니다.
    _adO = ori; // 최신 방향을 기록합니다.
    _adW = nextW; // 최신 너비를 기록합니다.
    WidgetsBinding.instance.addPostFrameCallback((_) { // 빌드가 끝난 뒤 안전하게 배너를 갱신합니다.
      if (!mounted) return; // 위젯이 사라졌으면 중단합니다.
      _loadBanner(); // 현재 화면 조건에 맞는 배너를 다시 불러옵니다.
    }); // 배너 갱신 예약을 마칩니다.
  } // 배너 동기화를 마칩니다.

  Future<void> _openTapTempoSheet() async {
    final cPrimary = _theme.color;
    const cPanel = Color(0xFF303030);
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
                    const fixedTop = 6.0 + 18.0 + 22.0 + 14.0;
                    const fixedBottom = 12.0 + 30.0;
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
                              overlayColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.pressed)) return pressOverlay;
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

    final pressOverlay = cText.withValues(alpha: 0.10);

    ClickKind localClickKind = _clickKind;
    ThemeOption localTheme = _theme;
    double localVol = _masterVolume;
    double localBal = _balance;
    bool localKeep = _keepScreenOn;
    bool localMix = _soundMix;
    bool localBg = _backgroundPlay;

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

  Widget _buildBottomBannerBar() {
    final h = (_bannerSize?.height.toDouble() ?? AdSize.banner.height.toDouble());
    final w = (_bannerSize?.width.toDouble() ?? double.infinity);

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        height: h,
        color: const Color(0xFF202020),
        alignment: Alignment.center,
        child: (_bannerLoaded && _bannerAd != null)
            ? SizedBox(
                width: w == double.infinity ? double.infinity : w,
                height: h,
                child: AdWidget(ad: _bannerAd!),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) { // 화면을 방향별 반응형 구조로 그립니다.
    return _buildRspScf(context); // 분리된 반응형 스캐폴드 빌더를 호출합니다.
  } // 빌드 메서드를 마칩니다.
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
            activeThumbColor: primary, // 활성 썸 색을 현재 테마 색으로 지정합니다.
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
    final gap = (cell * 0.22).clamp(16.0, 56.0); // 화면 폭에 맞춰 박자 행 간격을 조정합니다.

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
          SizedBox(height: gap), // 반응형 간격 값을 그대로 사용합니다.
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
      fontSize: (72.0 * scale.clamp(0.85, 1.25)).clamp(54.0, 90.0), // 선택 숫자 크기를 화면 폭에 맞춰 조정합니다.
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
      anchorWidth: (132.0 * scale.clamp(0.85, 1.20)).clamp(110.0, 160.0), // 앵커 너비를 화면 비율에 맞춰 조정합니다.
      menuMinWidth: (96.0 * scale.clamp(0.85, 1.20)).clamp(88.0, 120.0), // 메뉴 최소 너비를 반응형으로 조정합니다.
      menuMaxWidth: (118.0 * scale.clamp(0.85, 1.20)).clamp(104.0, 138.0), // 메뉴 최대 너비를 반응형으로 조정합니다.
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
      fontSize: (62.0 * scale.clamp(0.85, 1.25)).clamp(48.0, 74.0), // 선택 박자표 숫자 크기를 화면 폭에 맞춰 조정합니다.
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

    final noteSelected = (78.0 * scale.clamp(0.85, 1.25)).clamp(58.0, 95.0); // 선택 박자표 아이콘 크기를 반응형으로 조정합니다.
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
      anchorWidth: (188.0 * scale.clamp(0.85, 1.20)).clamp(156.0, 230.0), // 앵커 너비를 화면 비율에 맞춰 조정합니다.
      menuMinWidth: (128.0 * scale.clamp(0.85, 1.20)).clamp(118.0, 160.0), // 메뉴 최소 너비를 반응형으로 조정합니다.
      menuMaxWidth: (148.0 * scale.clamp(0.85, 1.20)).clamp(132.0, 180.0), // 메뉴 최대 너비를 반응형으로 조정합니다.
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

          final selected = await _showSlidePopupMenu<T>( // 슬라이드 업/다운 애니메이션 메뉴를 엽니다.
            context: context, // 현재 빌드 컨텍스트를 전달합니다.
            rect: rect, // 앵커 위치를 전달합니다.
            overlaySize: overlay.size, // 오버레이 전체 크기를 전달합니다.
            items: items, // 선택 가능한 항목 목록을 전달합니다.
            value: value, // 현재 선택 값을 전달합니다.
            itemHeight: itemHeight, // 항목 높이를 전달합니다.
            menuTextStyle: menuTextStyle, // 메뉴 글꼴 스타일을 전달합니다.
            menuBg: menuBg, // 메뉴 배경색을 전달합니다.
            menuMinWidth: menuMinWidth, // 메뉴 최소 너비를 전달합니다.
            menuMaxWidth: menuMaxWidth, // 메뉴 최대 너비를 전달합니다.
            buildItem: buildItem, // 항목 빌더를 전달합니다.
          ); // 슬라이드 메뉴 호출을 마칩니다.

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
