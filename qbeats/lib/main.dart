import 'dart:collection';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'l10n/app_localizations.dart';
part 'main_layout.dart';

const MethodChannel _vCh = MethodChannel('metronome/vibe');
const MethodChannel _dCh = MethodChannel('metronome/dnd');
final ValueNotifier<UiModeOpt> _uiModeNt =
    ValueNotifier<UiModeOpt>(UiModeOpt.dark);
final ValueNotifier<LangOpt> _langNt = ValueNotifier<LangOpt>(LangOpt.en);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _uiModeNt.value =
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? UiModeOpt.dark
          : UiModeOpt.light;
  await _initSvc();
  runApp(const MetronomeApp());
}

Future<void> _initSvc() async {
  try {
    await MobileAds.instance.initialize();
  } catch (_) {}
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class MetronomeApp extends StatelessWidget {
  const MetronomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UiModeOpt>(
      valueListenable: _uiModeNt,
      builder: (context, md, child) {
        return ValueListenableBuilder<LangOpt>(
          valueListenable: _langNt,
          builder: (context, lg, child) {
            final bg = md == UiModeOpt.light
                ? const Color(0xFFC8C8C8)
                : const Color(0xFF202020);
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: _locOf(lg),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(
                fontFamily: 'Pretendard',
                scaffoldBackgroundColor: bg,
                useMaterial3: true,
              ),
              home: const MetronomeScreen(),
            );
          },
        );
      },
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
  final List<int>? levels;
  final String? name;
  final bool tmOn;
  final TimerMode tmMode;
  final int tmSec;
  final int tmBar;
  final TmAct tmAct;

  const MemoryPreset({
    this.bpm,
    this.beats,
    this.notes,
    this.levels = _defLv,
    this.name,
    this.tmOn = false,
    this.tmMode = TimerMode.sec,
    this.tmSec = 60,
    this.tmBar = 16,
    this.tmAct = TmAct.stop,
  });

  const MemoryPreset.empty()
      : bpm = null,
        beats = null,
        notes = null,
        levels = null,
        name = null,
        tmOn = false,
        tmMode = TimerMode.sec,
        tmSec = 60,
        tmBar = 16,
        tmAct = TmAct.stop;

  bool get hasValue => bpm != null && beats != null && notes != null;

  @override
  bool operator ==(Object other) {
    return other is MemoryPreset &&
        other.bpm == bpm &&
        other.beats == beats &&
        other.notes == notes &&
        other.name == name &&
        other.tmOn == tmOn &&
        other.tmMode == tmMode &&
        other.tmSec == tmSec &&
        other.tmBar == tmBar &&
        other.tmAct == tmAct &&
        _sameLv(other.levels, levels);
  }

  @override
  int get hashCode => Object.hash(
        bpm,
        beats,
        notes,
        name,
        tmOn,
        tmMode,
        tmSec,
        tmBar,
        tmAct,
        levels == null ? null : Object.hashAll(levels!),
      );
}

const List<int> _defLv = <int>[1, 1, 1, 1, 1, 1, 1, 1];
const int _noteShf = 7;

bool _sameLv(List<int>? a, List<int>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

MemoryPreset _defMem(int i) => switch (i) {
      0 => const MemoryPreset(bpm: 60, beats: 4, notes: 1),
      1 => const MemoryPreset(bpm: 90, beats: 4, notes: 1),
      2 => const MemoryPreset(bpm: 120, beats: 4, notes: 1),
      _ => const MemoryPreset.empty(),
    };

List<MemoryPreset> _defMemLst() => List<MemoryPreset>.generate(40, _defMem);

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

enum UiModeOpt {
  auto,
  dark,
  light,
}

enum LangOpt {
  ko,
  en,
  ja,
  zhs,
  zht,
}

enum ScreenDir {
  auto,
  manual,
  portrait,
  landscape,
}

enum FuncBtn {
  tap,
  timer,
  rotate,
  none,
}

enum TimerMode {
  sec,
  bar,
}

enum TmAct {
  stop,
  next,
}

Locale _locOf(LangOpt v) => switch (v) {
      LangOpt.ko => const Locale('ko'),
      LangOpt.en => const Locale('en'),
      LangOpt.ja => const Locale('ja'),
      LangOpt.zhs => const Locale('zh'),
      LangOpt.zht => const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
    };

class ThemeOption {
  final String name;
  final Color color;

  const ThemeOption(this.name, this.color);
}

class _MetronomeScreenState extends State<MetronomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  double bpm = 100;
  int beatCount = 4;
  int noteCount = 1;
  bool isPlaying = false;

  bool _showMemoryGrid = false;

  final List<int> beatLevels = List<int>.filled(8, 1);
  int _lastBpmInt = 100;
  int? _memFocusIdx;

  late List<MemoryPreset> memoryPresets = List<MemoryPreset>.generate(
    40,
    _defMem,
  );

  final List<SettingSnapshot> _history = <SettingSnapshot>[];

  final SoLoud _soloud = SoLoud.instance;
  AudioSource? _clickSource;
  final ListQueue<SoundHandle> _hQ = ListQueue<SoundHandle>();

  Timer? _tickTimer;
  Timer? _undoTm;
  Timer? _bpmTm;
  Timer? _memDelTm;
  Timer? _tmUi;
  Stopwatch? _stopwatch;
  bool _memDelRan = false;
  bool _memDelIn = false;
  bool _memDelMd = false;
  bool _memNameMd = false;

  int _activeBeatIndex = -1;
  int _pulseToken = 0;
  double _pulseAmp = 1.0;
  int _waveToken = 0;
  int _waveIdx = -1;
  double _waveAmp = 1.0;
  double _tmProg = 0.0;
  bool _manLnd = false;
  bool _tmOn = false;
  TimerMode _tmMode = TimerMode.sec;
  int _tmSec = 60;
  int _tmBar = 16;
  TmAct _tmAct = TmAct.stop;
  double _tmSeq0 = 0.0;
  int _tmBarStep = 4;
  bool _tmRunOn = false;
  TimerMode _tmRunMode = TimerMode.sec;
  int _tmRunSec = 60;
  int _tmRunBar = 16;
  TmAct _tmRunAct = TmAct.stop;
  bool _tmPend = false;
  TmAct _tmPendAct = TmAct.stop;
  int? _tmPendIdx;
  FuncBtn _fnBtn = FuncBtn.tap;

  static const _bpmMin = 1.0;
  static const _bpmMax = 500.0;
  static const _bpmDefLo = 10;
  static const _bpmDefHi = 260;

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
  static const _kPrefDndAuto = 'dndAuto';
  static const _kPrefSlideSnap = 'slideSnap';
  static const _kPrefBpmLo = 'bpmLo';
  static const _kPrefBpmHi = 'bpmHi';
  static const _kPrefUiMode = 'uiMode';
  static const _kPrefLang = 'lang';
  static const _kPrefScreenDir = 'screenDir';
  static const _kPrefFnBtn = 'fnBtn';
  static const _kPrefTmOn = 'tmOn';
  static const _kPrefTmMode = 'tmMode';
  static const _kPrefTmSec = 'tmSec';
  static const _kPrefTmBar = 'tmBar';
  static const _kPrefManLnd = 'manLnd';

  ClickKind _clickKind = ClickKind.dgit1;

  double _masterVolume = 1.0;
  double _balance = 0.0;

  bool _keepScreenOn = false;
  bool _soundMix = false;
  bool _backgroundPlay = false;
  int _fastBpmStep = 10;
  bool _vibeClick = false;
  bool _dndAuto = false;
  bool _slideSnap = false;
  int _bpmLo = 40;
  int _bpmHi = _bpmDefHi;
  UiModeOpt _uiMode = UiModeOpt.auto;
  LangOpt _lang = LangOpt.en;
  ScreenDir _screenDir = ScreenDir.auto;

  static const List<ThemeOption> _themes = <ThemeOption>[
    ThemeOption('sky', Color(0xFF18A8F1)),
    ThemeOption('blue', Color(0xFF5D6DBE)),
    ThemeOption('red', Color(0xFFFF7048)),
    ThemeOption('orange', Color(0xFFFD9F28)),
    ThemeOption('yellow', Color(0xFFFDEB28)),
    ThemeOption('green', Color(0xFF2FA599)),
    ThemeOption('lime', Color(0xFF7DB249)),
    ThemeOption('purple', Color(0xFF9A30AE)),
    ThemeOption('mint', Color(0xFF03EFD7)),
    ThemeOption('pink', Color(0xFFF369FF)),
  ];

  ThemeOption _theme = _themes.first;
  UiModeOpt _uiVal(UiModeOpt md) => md == UiModeOpt.auto
      ? (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? UiModeOpt.dark
          : UiModeOpt.light)
      : md;
  UiModeOpt get _uiEff => _uiMode == UiModeOpt.auto
      ? (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? UiModeOpt.dark
          : UiModeOpt.light)
      : _uiMode;
  bool get _isLight => _uiEff == UiModeOpt.light;
  Color _bgColorOf(UiModeOpt md) =>
      _uiVal(md) == UiModeOpt.light ? const Color(0xFFC8C8C8) : const Color(0xFF202020);
  Color _panelColorOf(UiModeOpt md) =>
      _uiVal(md) == UiModeOpt.light ? const Color(0xFFB6B6B6) : const Color(0xFF404040);
  Color _sheetPanelColorOf(UiModeOpt md) =>
      _uiVal(md) == UiModeOpt.light ? const Color(0xFFBDBDBD) : const Color(0xFF303030);
  Color _fieldBgColorOf(UiModeOpt md) =>
      _uiVal(md) == UiModeOpt.light ? const Color(0xFFA8A8A8) : const Color(0xFF202020);
  Color _textColorOf(UiModeOpt md) =>
      _uiVal(md) == UiModeOpt.light ? const Color(0xFF202020) : const Color(0xFFEEEEEE);
  String _iconBaseOf(UiModeOpt md) =>
      _uiVal(md) == UiModeOpt.light ? 'assets/icons/dark' : 'assets/icons/light';
  Color get _bgColor => _bgColorOf(_uiEff);
  Color get _panelColor => _panelColorOf(_uiEff);
  Color get _sheetPanelColor => _sheetPanelColorOf(_uiEff);
  Color get _fieldBgColor => _fieldBgColorOf(_uiEff);
  Color get _textColor => _textColorOf(_uiEff);
  String get _iconBase => _iconBaseOf(_uiEff);
  String _ic(String nm) => '$_iconBase/$nm.png';

  AudioSession? _audioSession;
  bool _audOk = false;
  int _adW = 0;
  Orientation? _adO;
  bool _bannerLoading = false;
  BannerAd? _bannerAd;
  AdSize? _bannerSize;
  bool _bannerLoaded = false;
  int _memAdW = 0;
  Orientation? _memAdO;
  bool _memBannerLoading = false;
  BannerAd? _memBannerAd;
  AdSize? _memBannerSize;
  bool _memBannerLoaded = false;
  AppOpenAd? _appOpenAd;
  bool _isShowingAppOpenAd = false;
  bool _isLoadingAppOpenAd = false;
  int _audSeq = 0;
  int _visSeq = 0;
  double _baseUs = 0.0;
  double _baseSeq = 0.0;
  double _stepUs = 0.0;

  static const int _audLeadUs = 8000;
  static const int _schMinUs = 1200;
  static const int _schMaxUs = 6000;
  final GlobalKey _memDelKey = GlobalKey();
  static const String _bannerUnitId = 'ca-app-pub-7323951525567036/2502811037';
  static const String _appOpenUnitId = 'ca-app-pub-7323951525567036/4878127701';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applySysUi();
    unawaited(_applyScreenDir());
    unawaited(_syncDnd(on: false, play: false));
    _loadPrefs();
    _initAudio();
    _initAudioSession();
    _loadAppOpenAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showAppOpenAdIfAvailable();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _memBannerAd?.dispose();
    _memBannerAd = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_syncDnd(play: false));
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
        unawaited(_syncDnd());
      }
    }
    if (state == AppLifecycleState.resumed) {
      _showAppOpenAdIfAvailable();
    }
    if (state != AppLifecycleState.resumed) {
      if (_memDelMd || _memNameMd) {
        setState(() {
          _memDelMd = false;
          _memNameMd = false;
        });
      }
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_uiMode != UiModeOpt.auto) return;
    _applySysUi();
    if (mounted) setState(() {});
  }

  bool _isShf([int? v]) => (v ?? noteCount) == _noteShf;

  int _subCnt({int? noteVal}) => _isShf(noteVal) ? 3 : (noteVal ?? noteCount);

  LangOpt _sysLang() {
    final lc = WidgetsBinding.instance.platformDispatcher.locale;
    final lang = lc.languageCode.toLowerCase();
    final scr = (lc.scriptCode ?? '').toLowerCase();
    final ctry = (lc.countryCode ?? '').toLowerCase();
    switch (lang) {
      case 'en':
        return LangOpt.en;
      case 'ja':
        return LangOpt.ja;
      case 'zh':
        if (scr == 'hant' || ctry == 'tw' || ctry == 'hk' || ctry == 'mo') {
          return LangOpt.zht;
        }
        return LangOpt.zhs;
      default:
        return LangOpt.en;
    }
  }

  AppLocalizations? get _l => AppLocalizations.of(context);

  String _noteLbl(int v, {bool short = false}) {
    if (v == _noteShf) return short ? 'S' : 'Shuf';
    return '$v';
  }

  double _clampBpm(double v) =>
      v.clamp(_bpmLo.toDouble(), _bpmHi.toDouble()).toDouble();

  double _snapBpm(double v) {
    final next = _clampBpm(v);
    if (!_slideSnap) return next;
    final lo = _bpmLo.toDouble();
    final hi = _bpmHi.toDouble();
    final cands = <double>{lo, hi};
    final st = (lo / 5).ceil() * 5;
    for (int n = st; n <= hi; n += 5) {
      cands.add(n.toDouble());
    }
    double best = lo;
    double bestDst = double.infinity;
    for (final cand in cands) {
      final dst = (cand - next).abs();
      if (dst < bestDst - 0.0001) {
        best = cand;
        bestDst = dst;
        continue;
      }
      if ((dst - bestDst).abs() <= 0.0001) {
        final cand10 = cand.round() % 10 == 0;
        final best10 = best.round() % 10 == 0;
        if (cand10 && !best10) {
          best = cand;
        } else if (cand10 == best10 && cand < best) {
          best = cand;
        }
      }
    }
    return _clampBpm(best);
  }

  String _uiLbl(UiModeOpt v, LangOpt lg) {
    switch (lg) {
      case LangOpt.ko:
        return switch (v) {
          UiModeOpt.auto => '자동',
          UiModeOpt.dark => '다크',
          UiModeOpt.light => '라이트',
        };
      case LangOpt.en:
        return switch (v) {
          UiModeOpt.auto => 'Auto',
          UiModeOpt.dark => 'Dark',
          UiModeOpt.light => 'Light',
        };
      case LangOpt.ja:
        return switch (v) {
          UiModeOpt.auto => '自動',
          UiModeOpt.dark => 'ダーク',
          UiModeOpt.light => 'ライト',
        };
      case LangOpt.zhs:
        return switch (v) {
          UiModeOpt.auto => '自动',
          UiModeOpt.dark => '深色',
          UiModeOpt.light => '浅色',
        };
      case LangOpt.zht:
        return switch (v) {
          UiModeOpt.auto => '自動',
          UiModeOpt.dark => '深色',
          UiModeOpt.light => '淺色',
        };
    }
  }

  String _dirLbl(ScreenDir v, LangOpt lg) {
    switch (lg) {
      case LangOpt.ko:
        return switch (v) {
          ScreenDir.auto => '자동',
          ScreenDir.manual => '수동',
          ScreenDir.portrait => '세로',
          ScreenDir.landscape => '가로',
        };
      case LangOpt.en:
        return switch (v) {
          ScreenDir.auto => 'Auto',
          ScreenDir.manual => 'Manual',
          ScreenDir.portrait => 'Portrait',
          ScreenDir.landscape => 'Landscape',
        };
      case LangOpt.ja:
        return switch (v) {
          ScreenDir.auto => '自動',
          ScreenDir.manual => '手動',
          ScreenDir.portrait => '縦',
          ScreenDir.landscape => '横',
        };
      case LangOpt.zhs:
        return switch (v) {
          ScreenDir.auto => '自动',
          ScreenDir.manual => '手动',
          ScreenDir.portrait => '竖屏',
          ScreenDir.landscape => '横屏',
        };
      case LangOpt.zht:
        return switch (v) {
          ScreenDir.auto => '自動',
          ScreenDir.manual => '手動',
          ScreenDir.portrait => '直向',
          ScreenDir.landscape => '橫向',
        };
    }
  }

  String _fnLbl(FuncBtn v, LangOpt lg) {
    switch (lg) {
      case LangOpt.ko:
        return switch (v) {
          FuncBtn.tap => '탭 BPM',
          FuncBtn.timer => '타이머',
          FuncBtn.rotate => '화면 회전',
          FuncBtn.none => '없음',
        };
      case LangOpt.en:
        return switch (v) {
          FuncBtn.tap => 'Tap BPM',
          FuncBtn.timer => 'Timer',
          FuncBtn.rotate => 'Rotate',
          FuncBtn.none => 'None',
        };
      case LangOpt.ja:
        return switch (v) {
          FuncBtn.tap => 'タップ BPM',
          FuncBtn.timer => 'タイマー',
          FuncBtn.rotate => '回転',
          FuncBtn.none => 'なし',
        };
      case LangOpt.zhs:
        return switch (v) {
          FuncBtn.tap => '点按 BPM',
          FuncBtn.timer => '计时器',
          FuncBtn.rotate => '旋转',
          FuncBtn.none => '无',
        };
      case LangOpt.zht:
        return switch (v) {
          FuncBtn.tap => '點按 BPM',
          FuncBtn.timer => '計時器',
          FuncBtn.rotate => '旋轉',
          FuncBtn.none => '無',
        };
    }
  }

  String _tmModeLbl(TimerMode v, LangOpt lg, int n) {
    switch (lg) {
      case LangOpt.ko:
        return v == TimerMode.sec ? '$n초 후 클릭 종료' : '$n마디 후 클릭 종료';
      case LangOpt.en:
        return v == TimerMode.sec ? 'Stop after $n sec' : 'Stop after $n bars';
      case LangOpt.ja:
        return v == TimerMode.sec ? '$n秒後に停止' : '$n小節後に停止';
      case LangOpt.zhs:
        return v == TimerMode.sec ? '$n秒后停止' : '$n小节后停止';
      case LangOpt.zht:
        return v == TimerMode.sec ? '$n秒後停止' : '$n小節後停止';
    }
  }

  void _showMsg(String txt) {
    if (!mounted) return;
    final msgr = ScaffoldMessenger.of(context);
    msgr.hideCurrentSnackBar();
    msgr.showSnackBar(
      SnackBar(
        content: Text(txt),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _syncDnd({bool? on, bool? play}) async {
    try {
      await _dCh.invokeMethod<void>(
        'sync',
        <String, dynamic>{
          'on': on ?? _dndAuto,
          'play': play ?? isPlaying,
        },
      );
    } catch (_) {}
  }

  Future<Map<Object?, Object?>?> _getDndSt() async {
    try {
      final res = await _dCh.invokeMethod<dynamic>('state');
      return res is Map ? res : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _reqDnd() async {
    try {
      final ok = await _dCh.invokeMethod<bool>('req');
      if (ok == true) return true;
      _showMsg(_tx('dnd_need'));
      return false;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'unsupported':
          _showMsg(_tx('dnd_unsupported'));
          break;
        case 'denied':
          _showMsg(_tx('dnd_need'));
          break;
        case 'busy':
          _showMsg(_tx('dnd_busy'));
          break;
        default:
          _showMsg(_tx('dnd_fail'));
          break;
      }
      return false;
    } catch (_) {
      _showMsg(_tx('dnd_fail'));
      return false;
    }
  }

  void _ensureBannerFor(BuildContext context, double width,
      {bool grid = false}) {
    if (width <= 0) return;
    final w = width.floor().clamp(1, 1200).toInt();
    final o = MediaQuery.of(context).orientation;
    final same = grid
        ? _memAdW == w &&
            _memAdO == o &&
            (_memBannerLoaded || _memBannerLoading)
        : _adW == w && _adO == o && (_bannerLoaded || _bannerLoading);
    if (same) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadBannerFor(w, o, grid: grid));
    });
  }

  Future<void> _loadBannerFor(int width, Orientation orientation,
      {bool grid = false}) async {
    if (grid ? _memBannerLoading : _bannerLoading) return;
    if (grid) {
      _memBannerLoading = true;
    } else {
      _bannerLoading = true;
    }
    try {
      final old = grid ? _memBannerAd : _bannerAd;
      if (grid) {
        _memBannerAd = null;
        _memBannerLoaded = false;
      } else {
        _bannerAd = null;
        _bannerLoaded = false;
      }
      old?.dispose();
      final size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (!mounted) return;
      final resolved = size ?? AdSize.banner;
      if (grid) {
        _memBannerSize = resolved;
        _memAdW = width;
        _memAdO = orientation;
      } else {
        _bannerSize = resolved;
        _adW = width;
        _adO = orientation;
      }
      final ad = BannerAd(
        adUnitId: _bannerUnitId,
        request: const AdRequest(),
        size: resolved,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) return;
            setState(() {
              if (grid) {
                _memBannerAd = ad as BannerAd;
                _memBannerLoaded = true;
                _memBannerLoading = false;
              } else {
                _bannerAd = ad as BannerAd;
                _bannerLoaded = true;
                _bannerLoading = false;
              }
            });
          },
          onAdFailedToLoad: (ad, err) {
            ad.dispose();
            if (!mounted) return;
            setState(() {
              if (grid) {
                _memBannerAd = null;
                _memBannerLoaded = false;
                _memBannerLoading = false;
              } else {
                _bannerAd = null;
                _bannerLoaded = false;
                _bannerLoading = false;
              }
            });
          },
        ),
      );
      await ad.load();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (grid) {
          _memBannerLoading = false;
        } else {
          _bannerLoading = false;
        }
      });
    }
  }

  Widget _buildBannerSlot(BuildContext context,
      {required double height, bool grid = false}) {
    return LayoutBuilder(
      builder: (context, cs) {
        _ensureBannerFor(context, cs.maxWidth, grid: grid);
        final ad = grid ? _memBannerAd : _bannerAd;
        final size = grid ? _memBannerSize : _bannerSize;
        final loaded = grid ? _memBannerLoaded : _bannerLoaded;
        if (!loaded || ad == null || size == null) {
          return SizedBox(height: height);
        }
        final adW = size.width.toDouble();
        final adH = size.height.toDouble();
        return SizedBox(
          height: math.max(height, adH),
          child: Center(
            child: SizedBox(
              width: adW,
              height: adH,
              child: AdWidget(ad: ad),
            ),
          ),
        );
      },
    );
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
      bpm = _clampBpm(s.bpm.toDouble());
      beatCount = s.beats.clamp(1, 8);
      noteCount = s.notes.clamp(1, _noteShf);
      for (int i = 0; i < 8; i++) {
        beatLevels[i] = s.levels[i].clamp(1, 3);
      }
      memoryPresets = List<MemoryPreset>.from(s.memories);
      _memFocusIdx = s.focusIndex;
      _activeBeatIndex = -1;
      _pulseToken = 0;
      _pulseAmp = 1.0;
      _waveToken = 0;
      _waveIdx = -1;
      _waveAmp = 1.0;
    });
    _savePrefs();
    if (isPlaying) {
      _retimeCfg(bpmVal: bpm, noteVal: noteCount);
      _stTmRun();
    }
  }

  void _stUndoHold() {
    if (_history.isEmpty) return;
    _undoTm?.cancel();
    _undoTm = null;
    _undo();
    _undoTm = Timer.periodic(const Duration(milliseconds: 200), (tm) {
      if (_history.isEmpty) {
        tm.cancel();
        if (identical(_undoTm, tm)) _undoTm = null;
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
    _bpmTm = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _setBpm(bpm + delta, recordHistory: false);
    });
  }

  void _edBpmHold() {
    _bpmTm?.cancel();
    _bpmTm = null;
  }

  SystemUiOverlayStyle get _sysUiStyle {
    final dark = !_isLight;
    return SystemUiOverlayStyle(
      statusBarColor: _bgColor,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    );
  }

  void _applySysUi() {
    SystemChrome.setSystemUIOverlayStyle(_sysUiStyle);
    _uiModeNt.value = _uiEff;
  }

  void _applyLang() {
    _langNt.value = _lang;
  }

  Future<void> _applyScreenDir() async {
    final dirs = switch (_screenDir) {
      ScreenDir.auto => DeviceOrientation.values,
      ScreenDir.manual => _manLnd
          ? const <DeviceOrientation>[
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const <DeviceOrientation>[
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
      ScreenDir.portrait => const <DeviceOrientation>[
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
      ScreenDir.landscape => const <DeviceOrientation>[
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
    };
    await SystemChrome.setPreferredOrientations(dirs);
  }

  int get _waveMs => math.max(120, (60000 / bpm).round());

  double _sheetMaxW(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    if (sz.width <= sz.height) return sz.width;
    return math.min(sz.width - 24.0, 620.0);
  }

  Widget _sheetWrap(BuildContext context, Widget child) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _sheetMaxW(context)),
        child: child,
      ),
    );
  }

  InputDecoration _fldDec(Color bg, Color pri) {
    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      filled: true,
      fillColor: bg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: pri.withValues(alpha: 0.38),
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: pri,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _fldBox({
    required BuildContext context,
    required TextEditingController ctrl,
    required Color bg,
    required Color pri,
    required Color txt,
    double? w,
    int maxLen = 9999,
    TextInputType? kbType,
    List<TextInputFormatter>? ifs,
    TextAlign align = TextAlign.center,
    String? counterText,
    ValueChanged<String>? onSub,
    TapRegionCallback? onOut,
  }) {
    final fld = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: pri,
          selectionColor: pri.withValues(alpha: 0.28),
          selectionHandleColor: pri,
        ),
      ),
      child: TextField(
        controller: ctrl,
        maxLength: maxLen,
        cursorColor: pri,
        textAlign: align,
        keyboardType: kbType,
        inputFormatters: ifs,
        style: TextStyle(
          color: txt,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        decoration: _fldDec(bg, pri).copyWith(counterText: counterText),
        onSubmitted: onSub,
        onTapOutside: onOut,
      ),
    );
    if (w == null) return fld;
    return SizedBox(width: w, child: fld);
  }

  bool _hitMemDel(Offset pos) {
    final ctx = _memDelKey.currentContext;
    if (ctx == null) return false;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox) return false;
    final loc = ro.globalToLocal(pos);
    return (Offset.zero & ro.size).contains(loc);
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
      final savedDndAuto = sp.getBool(_kPrefDndAuto);
      final savedSlideSnap = sp.getBool(_kPrefSlideSnap);
      final savedBpmLo = sp.getInt(_kPrefBpmLo);
      final savedBpmHi = sp.getInt(_kPrefBpmHi);
      final savedUiMode = sp.getString(_kPrefUiMode);
      final savedLang = sp.getString(_kPrefLang);
      final savedScreenDir = sp.getString(_kPrefScreenDir);
      final savedFnBtn = sp.getString(_kPrefFnBtn);
      final savedTmOn = sp.getBool(_kPrefTmOn);
      final savedTmMode = sp.getString(_kPrefTmMode);
      final savedTmSec = sp.getInt(_kPrefTmSec);
      final savedTmBar = sp.getInt(_kPrefTmBar);
      final savedManLnd = sp.getBool(_kPrefManLnd);

      final List<int>? savedLevels = (savedLevelsStr == null)
          ? null
          : (jsonDecode(savedLevelsStr) as List)
              .map((e) => (e as num).toInt())
              .toList();

      final savedPresetRaw =
          savedPresetsStr == null ? null : jsonDecode(savedPresetsStr);

      if (!mounted) return;

      setState(() {
        _lang = savedLang == null
            ? _sysLang()
            : LangOpt.values.firstWhere(
                (e) => e.name == savedLang,
                orElse: _sysLang,
              );
        _manLnd = savedManLnd ?? false;
        _screenDir = savedScreenDir == null
            ? ScreenDir.auto
            : ScreenDir.values.firstWhere(
                (e) => e.name == savedScreenDir,
                orElse: () => ScreenDir.auto,
              );
        final lo = (savedBpmLo ?? 40).clamp(10, 499);
        final hi = (savedBpmHi ?? _bpmDefHi).clamp(lo + 1, 500);
        _bpmLo = lo;
        _bpmHi = hi;
        if (savedBpm != null) {
          _lastBpmInt = bpm.round();
          bpm = _clampBpm(savedBpm);
        } else {
          bpm = 100;
          _lastBpmInt = 100;
        }
        beatCount = (savedBeatCount ?? 4).clamp(1, 8);
        noteCount = (savedNoteCount ?? 1).clamp(1, _noteShf);

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
                  notes: notes.clamp(1, _noteShf),
                  levels: List<int>.from(_defLv),
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
              final rawLv = raw['levels'];
              final rawName = raw['name'];
              final rawTmOn = raw['tmOn'];
              final rawTmMode = raw['tmMode'];
              final rawTmSec = raw['tmSec'];
              final rawTmBar = raw['tmBar'];
              final rawTmAct = raw['tmAct'];
              final lv = rawLv is List
                  ? rawLv
                      .take(8)
                      .map((e) => (e as num).toInt().clamp(1, 3))
                      .toList()
                  : List<int>.from(_defLv);
              while (lv.length < 8) {
                lv.add(1);
              }
              next[i] = MemoryPreset(
                bpm: bpmRaw.toInt().clamp(_bpmMin.toInt(), _bpmMax.toInt()),
                beats: beatsRaw.toInt().clamp(1, 8),
                notes: notesRaw.toInt().clamp(1, _noteShf),
                levels: lv,
                name: rawName is String && rawName.trim().isNotEmpty
                    ? rawName.trim()
                    : null,
                tmOn: rawTmOn == true,
                tmMode: rawTmMode == 'bar' ? TimerMode.bar : TimerMode.sec,
                tmSec: (rawTmSec is num ? rawTmSec.toInt() : 60).clamp(1, 9999),
                tmBar: (rawTmBar is num ? rawTmBar.toInt() : 16).clamp(1, 9999),
                tmAct: rawTmAct == 'next' ? TmAct.next : TmAct.stop,
              );
            }
          }
          if (!(savedPresetRaw.isNotEmpty &&
              savedPresetRaw.first is num &&
              savedPresetRaw.length >= 40 * 3)) memoryPresets = next;
        }

        if (savedClickKind != null) {
          _clickKind = ClickKind.values.firstWhere(
            (e) => e.name == savedClickKind,
            orElse: () => ClickKind.dgit1,
          );
        }

        if (savedThemeName != null) {
          final themeKey = _themeKey(savedThemeName);
          _theme = _themes.firstWhere(
            (t) => t.name == themeKey,
            orElse: () => _themes.first,
          );
        }

        if (savedMasterVol != null)
          _masterVolume = savedMasterVol.clamp(0.0, 5.0);

        if (savedBalance != null) _balance = savedBalance.clamp(-1.0, 1.0);
        if (savedKeepOn != null) _keepScreenOn = savedKeepOn;
        if (savedMix != null) _soundMix = savedMix;
        if (savedBg != null) _backgroundPlay = savedBg;
        if (savedFastStep != null) _fastBpmStep = savedFastStep.clamp(2, 100);
        if (savedVibeClick != null) _vibeClick = savedVibeClick;
        if (savedDndAuto != null) _dndAuto = savedDndAuto;
        if (savedSlideSnap != null) _slideSnap = savedSlideSnap;
        if (savedUiMode != null) {
          _uiMode = UiModeOpt.values.firstWhere(
            (e) => e.name == savedUiMode,
            orElse: () => UiModeOpt.auto,
          );
        }
        _fnBtn = savedFnBtn == null
            ? FuncBtn.tap
            : FuncBtn.values.firstWhere(
                (e) => e.name == savedFnBtn,
                orElse: () => FuncBtn.tap,
              );
        if (_screenDir != ScreenDir.manual && _fnBtn == FuncBtn.rotate) {
          _fnBtn = FuncBtn.tap;
        }
        _tmOn = savedTmOn ?? false;
        _tmMode = savedTmMode == null
            ? TimerMode.sec
            : TimerMode.values.firstWhere(
                (e) => e.name == savedTmMode,
                orElse: () => TimerMode.sec,
              );
        _tmSec = (savedTmSec ?? 60).clamp(1, 9999);
        _tmBar = (savedTmBar ?? 16).clamp(1, 9999);
      });

      _applySysUi();
      _applyLang();
      await _applyScreenDir();
      _applyKeepScreenOn();
      _applyAudioSessionConfig();
      await _reloadClickSource();
      final st = await _getDndSt();
      final ok = st?['sup'] == true && st?['acc'] == true;
      if (_dndAuto && !ok && mounted) {
        setState(() => _dndAuto = false);
        await _savePrefs();
      }
      await _syncDnd();
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
          'levels': p.levels ?? _defLv,
          'name': p.name,
          'tmOn': p.tmOn,
          'tmMode': p.tmMode.name,
          'tmSec': p.tmSec,
          'tmBar': p.tmBar,
          'tmAct': p.tmAct.name,
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
      await sp.setBool(_kPrefDndAuto, _dndAuto);
      await sp.setBool(_kPrefSlideSnap, _slideSnap);
      await sp.setInt(_kPrefBpmLo, _bpmLo);
      await sp.setInt(_kPrefBpmHi, _bpmHi);
      await sp.setString(_kPrefUiMode, _uiMode.name);
      await sp.setString(_kPrefLang, _lang.name);
      await sp.setString(_kPrefScreenDir, _screenDir.name);
      await sp.setString(_kPrefFnBtn, _fnBtn.name);
      await sp.setBool(_kPrefTmOn, _tmOn);
      await sp.setString(_kPrefTmMode, _tmMode.name);
      await sp.setInt(_kPrefTmSec, _tmSec);
      await sp.setInt(_kPrefTmBar, _tmBar);
      await sp.setBool(_kPrefManLnd, _manLnd);
    } catch (_) {}
  }

  Future<void> _initAudio() async {
    try {
      await _soloud.init(
          sampleRate: 48000, bufferSize: 256, channels: Channels.stereo);
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
    switch (_lang) {
      case LangOpt.ko:
        return switch (k) {
          ClickKind.dgit1 => '디지털 1',
          ClickKind.dgit2 => '디지털 2',
          ClickKind.dgit3 => '디지털 3',
          ClickKind.anal1 => '아날로그 1',
          ClickKind.anal2 => '아날로그 2',
          ClickKind.anal3 => '아날로그 3',
        };
      case LangOpt.en:
        return switch (k) {
          ClickKind.dgit1 => 'Digital 1',
          ClickKind.dgit2 => 'Digital 2',
          ClickKind.dgit3 => 'Digital 3',
          ClickKind.anal1 => 'Analog 1',
          ClickKind.anal2 => 'Analog 2',
          ClickKind.anal3 => 'Analog 3',
        };
      case LangOpt.ja:
        return switch (k) {
          ClickKind.dgit1 => 'デジタル 1',
          ClickKind.dgit2 => 'デジタル 2',
          ClickKind.dgit3 => 'デジタル 3',
          ClickKind.anal1 => 'アナログ 1',
          ClickKind.anal2 => 'アナログ 2',
          ClickKind.anal3 => 'アナログ 3',
        };
      case LangOpt.zhs:
        return switch (k) {
          ClickKind.dgit1 => '数字 1',
          ClickKind.dgit2 => '数字 2',
          ClickKind.dgit3 => '数字 3',
          ClickKind.anal1 => '模拟 1',
          ClickKind.anal2 => '模拟 2',
          ClickKind.anal3 => '模拟 3',
        };
      case LangOpt.zht:
        return switch (k) {
          ClickKind.dgit1 => '數位 1',
          ClickKind.dgit2 => '數位 2',
          ClickKind.dgit3 => '數位 3',
          ClickKind.anal1 => '類比 1',
          ClickKind.anal2 => '類比 2',
          ClickKind.anal3 => '類比 3',
        };
    }
  }

  String _themeLbl(ThemeOption t) {
    final idx = _themes.indexOf(t);
    switch (_lang) {
      case LangOpt.ko:
        return const ['하늘', '파랑', '빨강', '주황', '노랑', '초록', '연두', '보라', '민트', '핑크'][idx];
      case LangOpt.en:
        return const ['Sky', 'Blue', 'Red', 'Orange', 'Yellow', 'Green', 'Lime', 'Purple', 'Mint', 'Pink'][idx];
      case LangOpt.ja:
        return const ['空', '青', '赤', '橙', '黄', '緑', '黄緑', '紫', 'ミント', 'ピンク'][idx];
      case LangOpt.zhs:
        return const ['天空', '蓝色', '红色', '橙色', '黄色', '绿色', '青柠', '紫色', '薄荷', '粉色'][idx];
      case LangOpt.zht:
        return const ['天空', '藍色', '紅色', '橙色', '黃色', '綠色', '青檸', '紫色', '薄荷', '粉色'][idx];
    }
  }

  String _themeKey(String v) {
    return switch (v) {
      '\uD558\uB298' => 'sky',
      '\uD30C\uB791' => 'blue',
      '\uBE68\uAC15' => 'red',
      '\uC8FC\uD669' => 'orange',
      '\uB178\uB791' => 'yellow',
      '\uCD08\uB85D' => 'green',
      '\uC5F0\uB450' => 'lime',
      '\uBCF4\uB77C' => 'purple',
      '\uBBFC\uD2B8' => 'mint',
      '\uD551\uD06C' => 'pink',
      _ => v,
    };
  }

  String _langLbl(LangOpt v) {
    switch (v) {
      case LangOpt.ko:
        return '\uD55C\uAD6D\uC5B4';
      case LangOpt.en:
        return 'English';
      case LangOpt.ja:
        return '\u65E5\u672C\u8A9E';
      case LangOpt.zhs:
        return '\u7B80\u4F53\u4E2D\u6587';
      case LangOpt.zht:
        return '\u7E41\u9AD4\u4E2D\u6587';
    }
  }

  String _dirTitle(LangOpt v) {
    switch (v) {
      case LangOpt.ko:
        return '화면 방향';
      case LangOpt.en:
        return 'Orientation';
      case LangOpt.ja:
        return '画面方向';
      case LangOpt.zhs:
        return '屏幕方向';
      case LangOpt.zht:
        return '畫面方向';
    }
  }

  String _tx(String k) {
    switch (k) {
      case 'click_kind':
        return switch (_lang) {
          LangOpt.ko => '클릭 종류',
          LangOpt.en => 'Click Type',
          LangOpt.ja => 'クリック音',
          LangOpt.zhs => '点击音',
          LangOpt.zht => '點擊音',
        };
      case 'theme':
        return switch (_lang) {
          LangOpt.ko => '테마',
          LangOpt.en => 'Theme',
          LangOpt.ja => 'テーマ',
          LangOpt.zhs => '主题',
          LangOpt.zht => '主題',
        };
      case 'color':
        return switch (_lang) {
          LangOpt.ko => '색상',
          LangOpt.en => 'Color',
          LangOpt.ja => '色',
          LangOpt.zhs => '颜色',
          LangOpt.zht => '顏色',
        };
      case 'lang':
        return switch (_lang) {
          LangOpt.ko => '언어',
          LangOpt.en => 'Language',
          LangOpt.ja => '言語',
          LangOpt.zhs => '语言',
          LangOpt.zht => '語言',
        };
      case 'func':
        return switch (_lang) {
          LangOpt.ko => '기능 버튼',
          LangOpt.en => 'Function Btn',
          LangOpt.ja => '機能ボタン',
          LangOpt.zhs => '功能按钮',
          LangOpt.zht => '功能按鈕',
        };
      case 'vol':
        return switch (_lang) {
          LangOpt.ko => '클릭 음량',
          LangOpt.en => 'Click Vol',
          LangOpt.ja => 'クリック音量',
          LangOpt.zhs => '点击音量',
          LangOpt.zht => '點擊音量',
        };
      case 'bal':
        return switch (_lang) {
          LangOpt.ko => '좌우 소리 균형',
          LangOpt.en => 'L/R Balance',
          LangOpt.ja => '左右バランス',
          LangOpt.zhs => '左右平衡',
          LangOpt.zht => '左右平衡',
        };
      case 'fast':
        return switch (_lang) {
          LangOpt.ko => '빠른 BPM 조정',
          LangOpt.en => 'Fast BPM Step',
          LangOpt.ja => '高速 BPM',
          LangOpt.zhs => '快速 BPM',
          LangOpt.zht => '快速 BPM',
        };
      case 'rng':
        return switch (_lang) {
          LangOpt.ko => 'BPM 범위',
          LangOpt.en => 'BPM Range',
          LangOpt.ja => 'BPM 範囲',
          LangOpt.zhs => 'BPM 范围',
          LangOpt.zht => 'BPM 範圍',
        };
      case 'keep':
        return switch (_lang) {
          LangOpt.ko => '화면 유지',
          LangOpt.en => 'Keep On',
          LangOpt.ja => '画面維持',
          LangOpt.zhs => '保持亮屏',
          LangOpt.zht => '保持亮屏',
        };
      case 'mix':
        return switch (_lang) {
          LangOpt.ko => '소리 혼합',
          LangOpt.en => 'Audio Mix',
          LangOpt.ja => '音声ミックス',
          LangOpt.zhs => '声音混合',
          LangOpt.zht => '聲音混合',
        };
      case 'bg':
        return switch (_lang) {
          LangOpt.ko => '백그라운드',
          LangOpt.en => 'Background',
          LangOpt.ja => 'バックグラウンド',
          LangOpt.zhs => '后台',
          LangOpt.zht => '背景執行',
        };
      case 'dnd':
        return switch (_lang) {
          LangOpt.ko => '방해금지',
          LangOpt.en => 'Do Not Disturb',
          LangOpt.ja => 'おやすみ',
          LangOpt.zhs => '勿扰模式',
          LangOpt.zht => '勿擾模式',
        };
      case 'snap':
        return switch (_lang) {
          LangOpt.ko => '슬라이드 스냅',
          LangOpt.en => 'Slide Snap',
          LangOpt.ja => 'スライド吸着',
          LangOpt.zhs => '滑块吸附',
          LangOpt.zht => '滑桿吸附',
        };
      case 'vibe':
        return switch (_lang) {
          LangOpt.ko => '진동 클릭',
          LangOpt.en => 'Vibe Click',
          LangOpt.ja => '振動クリック',
          LangOpt.zhs => '振动点击',
          LangOpt.zht => '震動點擊',
        };
      case 'adv':
        return switch (_lang) {
          LangOpt.ko => '고급 설정',
          LangOpt.en => 'Advanced',
          LangOpt.ja => '詳細設定',
          LangOpt.zhs => '高级设置',
          LangOpt.zht => '進階設定',
        };
      case 'tm_on':
        return switch (_lang) {
          LangOpt.ko => '타이머',
          LangOpt.en => 'Timer',
          LangOpt.ja => 'タイマー',
          LangOpt.zhs => '计时器',
          LangOpt.zht => '計時器',
        };
      case 'rst':
        return switch (_lang) {
          LangOpt.ko => '초기화',
          LangOpt.en => 'Reset',
          LangOpt.ja => '初期化',
          LangOpt.zhs => '重置',
          LangOpt.zht => '重設',
        };
      case 'name':
        return switch (_lang) {
          LangOpt.ko => '이름',
          LangOpt.en => 'Name',
          LangOpt.ja => '名前',
          LangOpt.zhs => '名称',
          LangOpt.zht => '名稱',
        };
      case 'save':
        return switch (_lang) {
          LangOpt.ko => '저장',
          LangOpt.en => 'Save',
          LangOpt.ja => '保存',
          LangOpt.zhs => '保存',
          LangOpt.zht => '儲存',
        };
      case 'cancel':
        return switch (_lang) {
          LangOpt.ko => '취소',
          LangOpt.en => 'Cancel',
          LangOpt.ja => '取消',
          LangOpt.zhs => '取消',
          LangOpt.zht => '取消',
        };
      case 'dnd_need':
        return switch (_lang) {
          LangOpt.ko => '방해금지 접근 권한이 필요합니다.',
          LangOpt.en => 'DND access is required.',
          LangOpt.ja => 'おやすみモード権限が必要です。',
          LangOpt.zhs => '需要勿扰模式权限。',
          LangOpt.zht => '需要勿擾模式權限。',
        };
      case 'dnd_unsupported':
        return switch (_lang) {
          LangOpt.ko => '이 기기에서는 방해금지 자동 설정을 지원하지 않습니다.',
          LangOpt.en => 'Auto DND is not supported on this device.',
          LangOpt.ja => 'この端末では自動 DND を使えません。',
          LangOpt.zhs => '此设备不支持自动勿扰。',
          LangOpt.zht => '此裝置不支援自動勿擾。',
        };
      case 'dnd_busy':
        return switch (_lang) {
          LangOpt.ko => '방해금지 권한 화면이 이미 열려 있습니다.',
          LangOpt.en => 'The DND permission screen is already open.',
          LangOpt.ja => 'DND 権限画面が既に開いています。',
          LangOpt.zhs => '勿扰权限页面已打开。',
          LangOpt.zht => '勿擾權限頁面已開啟。',
        };
      case 'dnd_fail':
        return switch (_lang) {
          LangOpt.ko => '방해금지 설정을 완료하지 못했습니다.',
          LangOpt.en => 'Could not complete DND setup.',
          LangOpt.ja => 'DND 設定を完了できませんでした。',
          LangOpt.zhs => '无法完成勿扰设置。',
          LangOpt.zht => '無法完成勿擾設定。',
        };
      case 'tap_bpm':
        return 'BPM';
      default:
        return k;
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
    final noteNum = _subCnt(noteVal: noteVal);
    return 60000000.0 / bpmNum / noteNum;
  }

  void _retimeCfg({double? bpmVal, int? noteVal}) {
    final sw = _stopwatch;
    if (!isPlaying || sw == null || _stepUs <= 0) return;
    final nowUs = sw.elapsedMicroseconds.toDouble();
    final pos = _baseSeq + ((nowUs - _baseUs) / _stepUs);
    _baseUs = nowUs;
    _baseSeq = pos;
    _stepUs = _calcStepUs(bpmVal: bpmVal ?? bpm, noteVal: noteVal ?? noteCount);
    _tickTimer?.cancel();
    _runTickLoop();
  }

  Uint8List _trimWav(Uint8List src, Duration cut) {
    if (src.length < 44 || cut <= Duration.zero) return src;
    final bd = ByteData.sublistView(src);
    if (String.fromCharCodes(src.sublist(0, 4)) != 'RIFF') return src;
    if (String.fromCharCodes(src.sublist(8, 12)) != 'WAVE') return src;
    int fmtOff = -1;
    int dataOff = -1;
    int dataLen = -1;
    int off = 12;
    while (off + 8 <= src.length) {
      final id = String.fromCharCodes(src.sublist(off, off + 4));
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
    if (fmtOff < 0 || dataOff < 0 || dataLen <= 0) return src;
    final sampleRate = bd.getUint32(fmtOff + 4, Endian.little);
    final blockAlign = bd.getUint16(fmtOff + 12, Endian.little);
    if (sampleRate <= 0 || blockAlign <= 0) return src;
    final cutBytes =
        (((cut.inMicroseconds * sampleRate) / 1000000).floor() * blockAlign)
            .clamp(0, dataLen);
    if (cutBytes <= 0 || cutBytes >= dataLen) return src;
    final headLen = dataOff;
    final newDataLen = dataLen - cutBytes;
    final out = Uint8List(headLen + newDataLen);
    out.setRange(0, headLen, src);
    out.setRange(headLen, headLen + newDataLen,
        src.sublist(dataOff + cutBytes, dataOff + dataLen));
    final outBd = ByteData.sublistView(out);
    outBd.setUint32(4, out.length - 8, Endian.little);
    outBd.setUint32(dataOff - 4, newDataLen, Endian.little);
    return out;
  }

  Future<void> _reloadClickSource() async {
    if (!_audOk) return;
    try {
      final nextAsset = _clickAssetForKind(_clickKind);
      if (_clickSource != null) {
        _soloud.disposeSource(_clickSource!);
        _clickSource = null;
      }
      final raw = await rootBundle.load(nextAsset);
      final buf = Uint8List.sublistView(raw);
      final trim = _trimWav(buf, _clickTrimForKind(_clickKind));
      _clickSource = await _soloud.loadMem(nextAsset, trim);
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
    if (isPlaying) _retimeCfg();
  }

  void _setNoteCount(int v, {bool recordHistory = true}) {
    if (recordHistory) _pushHistoryIfNeeded(_currentSnapshot());
    setState(() => noteCount = v.clamp(1, _noteShf));
    _savePrefs();
    if (isPlaying) _retimeCfg(noteVal: noteCount);
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
    final next = _clampBpm(v);
    final prevInt = bpm.round();
    final nextInt = next.round();
    setState(() {
      if (nextInt != prevInt) _lastBpmInt = prevInt;
      bpm = next;
    });
    if (isPlaying) _retimeCfg(bpmVal: next);
    _savePrefs();
  }

  void _previewBpm(double v) {
    final next = _snapBpm(v);
    final prevInt = bpm.round();
    final nextInt = next.round();
    setState(() {
      if (nextInt != prevInt) _lastBpmInt = prevInt;
      bpm = next;
    });
    if (isPlaying) _retimeCfg(bpmVal: next);
  }

  void _changeBpmBy(int delta, {bool recordHistory = true}) =>
      _setBpm(bpm + delta, recordHistory: recordHistory);

  bool _isPresetActive(MemoryPreset p) {
    if (!p.hasValue) return false;
    return bpm.round() == p.bpm &&
        beatCount == p.beats &&
        noteCount == p.notes &&
        _sameLv(beatLevels, p.levels);
  }

  bool _showFnBtn() =>
      _screenDir == ScreenDir.manual || _fnBtn != FuncBtn.none;

  FuncBtn _effFnBtn() =>
      _screenDir == ScreenDir.manual ? FuncBtn.rotate : _fnBtn;

  String _fnIc(FuncBtn v) => switch (v) {
        FuncBtn.tap => _ic('hand'),
        FuncBtn.timer => _ic('clock'),
        FuncBtn.rotate => _ic('rotate'),
        FuncBtn.none => _ic('none'),
      };

  Future<void> _onFnTap() async {
    if (_showMemoryGrid) {
      _closeMemoryGrid();
      return;
    }
    switch (_effFnBtn()) {
      case FuncBtn.tap:
        await _openTapTempoSheet();
        return;
      case FuncBtn.timer:
        await _openTimerSheet();
        return;
      case FuncBtn.rotate:
        await _rotManualDir();
        return;
      case FuncBtn.none:
        return;
    }
  }

  void _applyPreset(MemoryPreset p, {bool recordHistory = true, int? index}) {
    if (!p.hasValue) return;
    if (_memDelMd) {
      final i = index ?? memoryPresets.indexOf(p);
      if (i >= 0) _resetPresetAt(i);
      return;
    }
    if (_memNameMd) {
      final i = index ?? memoryPresets.indexOf(p);
      if (i >= 0) {
        unawaited(_openMemNameSheet(i));
      }
      return;
    }
    if (recordHistory) _pushHistoryIfNeeded(_currentSnapshot());
    final idx = memoryPresets.indexOf(p);
    setState(() {
      _lastBpmInt = bpm.round();
      bpm = _clampBpm(p.bpm!.toDouble());
      beatCount = p.beats!.clamp(1, 8);
      noteCount = p.notes!.clamp(1, _noteShf);
      _memFocusIdx = index ?? (idx >= 0 ? idx : _memFocusIdx);
      for (int i = 0; i < 8; i++) {
        beatLevels[i] = (p.levels ?? _defLv)[i].clamp(1, 3);
      }
    });
    _savePrefs();
    if (isPlaying) _retimeCfg(bpmVal: bpm, noteVal: noteCount);
  }

  void _savePreset(int index) {
    _pushHistoryIfNeeded(_currentSnapshot());
    final old = memoryPresets[index];
    final p = MemoryPreset(
      bpm: bpm.round(),
      beats: beatCount,
      notes: noteCount,
      levels: List<int>.from(beatLevels),
      name: old.name,
      tmOn: old.tmOn,
      tmMode: old.tmMode,
      tmSec: old.tmSec,
      tmBar: old.tmBar,
      tmAct: old.tmAct,
    );
    setState(() {
      memoryPresets[index] = p;
      _memFocusIdx = index;
    });
    unawaited(_buzz(ms: 75, amp: 200));
    _savePrefs();
  }

  void _resetPresetAt(int index) {
    if (index < 0 || index >= 38) return;
    _pushHistoryIfNeeded(_currentSnapshot());
    setState(() {
      memoryPresets[index] = _defMem(index);
      if (_memFocusIdx == index) _memFocusIdx = null;
    });
    _savePrefs();
    unawaited(_buzz(ms: 90, amp: 200));
  }

  void _resetAllPresets() {
    _pushHistoryIfNeeded(_currentSnapshot());
    setState(() {
      memoryPresets = _defMemLst();
      _memFocusIdx = null;
      _memDelMd = false;
      _memNameMd = false;
    });
    _savePrefs();
    unawaited(_buzz(ms: 120, amp: 240));
  }

  void _tglMemDel() {
    setState(() {
      _memDelMd = !_memDelMd;
      if (_memDelMd) _memNameMd = false;
    });
  }

  void _tglMemName() {
    setState(() {
      _memNameMd = !_memNameMd;
      if (_memNameMd) _memDelMd = false;
    });
  }

  void _stDeletePresetHold() {
    _memDelTm?.cancel();
    _memDelTm = null;
    _memDelIn = true;
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
    _memDelIn = false;
    _memDelRan = false;
    if (allowTap && !ran) _tglMemDel();
  }

  void _fireHpt(int lvl, int subIdx) {
    if (!_vibeClick) return;
    if (!isPlaying) return;
    if (lvl >= 3) return;
    final lvlMul = lvl == 1 ? 1.0 : 0.55;
    final subMul = _isShf()
        ? (subIdx == 0 ? 1.0 : (subIdx == 2 ? 0.5 : 0.0))
        : (subIdx == 0 ? 1.0 : (1.0 / _subCnt()).clamp(0.22, 0.55));
    final volMul = (_masterVolume / 5.0).clamp(0.0, 1.0);
    final pow = (lvlMul * subMul * volMul).clamp(0.0, 1.0);
    if (pow <= 0) return;
    if (pow >= 0.62) {
      unawaited(_buzz(ms: 70, amp: 220));
      return;
    }
    if (pow >= 0.28) {
      unawaited(_buzz(ms: 50, amp: 150));
      return;
    }
    unawaited(_buzz(ms: 30, amp: 95));
  }

  void _openMemoryGrid() {
    if (_showMemoryGrid) return;
    setState(() {
      _showMemoryGrid = true;
      _memDelMd = false;
      _memNameMd = false;
    });
  }

  void _closeMemoryGrid() {
    if (!_showMemoryGrid) return;
    setState(() {
      _showMemoryGrid = false;
      _memDelMd = false;
      _memNameMd = false;
    });
  }

  Future<void> _buzz({required int ms, required int amp}) async {
    final d = ms.clamp(1, 120);
    final a = amp.clamp(1, 255);
    try {
      await _vCh.invokeMethod<void>('pulse', {
        'ms': d,
        'amp': a,
      });
      return;
    } catch (_) {}
    if (a >= 170) {
      unawaited(HapticFeedback.mediumImpact());
      return;
    }
    if (a >= 100) {
      unawaited(HapticFeedback.lightImpact());
      return;
    }
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _rotManualDir() async {
    if (_screenDir != ScreenDir.manual) return;
    setState(() => _manLnd = !_manLnd);
    await _applyScreenDir();
    await _savePrefs();
  }

  Future<void> _openMemNameSheet(int i) async {
    if (i < 0 || i >= 38) return;
    final p = memoryPresets[i];
    if (!p.hasValue) return;
    final ctrl = TextEditingController(text: p.name ?? '');
    bool localOn = p.tmOn;
    TimerMode localMode = p.tmMode;
    int localSec = p.tmSec;
    int localBar = p.tmBar;
    TmAct localAct = p.tmAct;
    final secCtrl = TextEditingController(text: '$localSec');
    final barCtrl = TextEditingController(text: '$localBar');
    final cPri = _theme.color;
    final cPnl = _sheetPanelColor;
    final cTxt = _textColor;
    final cBg = _fieldBgColor;
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            void syncSec() {
              localSec = (int.tryParse(secCtrl.text.trim()) ?? localSec)
                  .clamp(1, 9999);
              secCtrl.text = '$localSec';
              secCtrl.selection =
                  TextSelection.collapsed(offset: secCtrl.text.length);
            }

            void syncBar() {
              localBar = (int.tryParse(barCtrl.text.trim()) ?? localBar)
                  .clamp(1, 9999);
              barCtrl.text = '$localBar';
              barCtrl.selection =
                  TextSelection.collapsed(offset: barCtrl.text.length);
            }

            Widget actDd() {
              String lbl(TmAct v) => switch (_lang) {
                    LangOpt.ko => v == TmAct.stop
                        ? '\uD074\uB9AD \uC885\uB8CC'
                        : '\uB2E4\uC74C \uBA54\uBAA8\uB9AC \uC7AC\uC0DD',
                    LangOpt.en => v == TmAct.stop ? 'Stop' : 'Play Next Preset',
                    LangOpt.ja => v == TmAct.stop
                        ? '\u505C\u6B62'
                        : '\u6B21\u306E\u30E1\u30E2\u30EA\u518D\u751F',
                    LangOpt.zhs => v == TmAct.stop
                        ? '\u505C\u6B62'
                        : '\u64AD\u653E\u4E0B\u4E00\u4E2A\u9884\u8BBE',
                    LangOpt.zht => v == TmAct.stop
                        ? '\u505C\u6B62'
                        : '\u64AD\u653E\u4E0B\u4E00\u500B\u9810\u8A2D',
                  };
              return PopupSelectButton<TmAct>(
                value: localAct,
                items: TmAct.values,
                overlayColor: cPri.withValues(alpha: 0.18),
                textColor: cTxt,
                itemHeight: 48,
                menuTextStyle: TextStyle(
                  fontSize: 15.2,
                  fontWeight: FontWeight.w800,
                  color: cTxt,
                  height: 1.0,
                ),
                menuBg: cBg,
                anchorWidth: 166,
                menuMinWidth: 144,
                menuMaxWidth: 178,
                buildSelected: (ctx, v) => Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    lbl(v),
                    style: TextStyle(
                      fontSize: 15.2,
                      fontWeight: FontWeight.w700,
                      color: cTxt,
                    ),
                  ),
                ),
                buildItem: (ctx, v) => Center(
                  child: Text(
                    lbl(v),
                    style: TextStyle(
                      fontSize: 15.2,
                      fontWeight: FontWeight.w700,
                      color: cTxt,
                    ),
                  ),
                ),
                onChanged: (v) => setSheet(() => localAct = v),
              );
            }

            Widget tmRow(TimerMode mode) {
              final on = localMode == mode;
              final ctrl2 = mode == TimerMode.sec ? secCtrl : barCtrl;
              final sync = mode == TimerMode.sec ? syncSec : syncBar;
              final tail = switch (_lang) {
                LangOpt.ko => mode == TimerMode.sec
                    ? '\uCD08 \uD6C4'
                    : '\uB9C8\uB514 \uD6C4',
                LangOpt.en => mode == TimerMode.sec ? 'sec later' : 'bars later',
                LangOpt.ja => mode == TimerMode.sec
                    ? '\u79D2\u5F8C'
                    : '\u5C0F\u7BC0\u5F8C',
                LangOpt.zhs => mode == TimerMode.sec
                    ? '\u79D2\u540E'
                    : '\u5C0F\u8282\u540E',
                LangOpt.zht => mode == TimerMode.sec
                    ? '\u79D2\u5F8C'
                    : '\u5C0F\u7BC0\u5F8C',
              };
              return Opacity(
                opacity: on ? 1.0 : 0.46,
                child: RadioListTile<TimerMode>(
                  value: mode,
                  groupValue: localMode,
                  activeColor: cPri,
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      _fldBox(
                        context: context,
                        ctrl: ctrl2,
                        bg: cBg,
                        pri: cPri,
                        txt: cTxt,
                        w: 72,
                        maxLen: 4,
                        kbType: TextInputType.number,
                        ifs: [FilteringTextInputFormatter.digitsOnly],
                        counterText: '',
                        onSub: (_) => sync(),
                        onOut: (_) => sync(),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        tail,
                        style: TextStyle(
                          color: cTxt,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: actDd()),
                    ],
                  ),
                  onChanged: localOn
                      ? (v) {
                          if (v == null) return;
                          setSheet(() => localMode = v);
                        }
                      : null,
                ),
              );
            }

            return _sheetWrap(
              context,
              SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: cPnl,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(34),
                      topRight: Radius.circular(34),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    22,
                    18,
                    22,
                    22 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 56,
                          height: 6,
                          decoration: BoxDecoration(
                            color: cPri.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _tx('name'),
                        style: TextStyle(
                          color: cTxt,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _fldBox(
                        context: context,
                        ctrl: ctrl,
                        bg: cBg,
                        pri: cPri,
                        txt: cTxt,
                        maxLen: 8,
                        counterText: '',
                      ),
                      const SizedBox(height: 18),
                      _SettingSwitchRow(
                        title: _tx('tm_on'),
                        value: localOn,
                        primary: cPri,
                        textColor: cTxt,
                        onChanged: (v) => setSheet(() => localOn = v),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: localOn ? 1.0 : 0.0,
                          child: localOn
                              ? Column(
                                  children: [
                                    tmRow(TimerMode.sec),
                                    tmRow(TimerMode.bar),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SheetBtn(
                              text: _tx('cancel'),
                              bg: cBg,
                              fg: cTxt,
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SheetBtn(
                              text: _tx('rst'),
                              bg: const Color(0xFFFF7048),
                              fg: cTxt,
                              icon: _ic('reload'),
                              onTap: () {
                                setSheet(() {
                                  ctrl.text = '';
                                  localOn = false;
                                  localMode = TimerMode.sec;
                                  localSec = 60;
                                  localBar = 16;
                                  localAct = TmAct.stop;
                                  secCtrl.text = '$localSec';
                                  barCtrl.text = '$localBar';
                                  secCtrl.selection = TextSelection.collapsed(
                                      offset: secCtrl.text.length);
                                  barCtrl.selection = TextSelection.collapsed(
                                      offset: barCtrl.text.length);
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SheetBtn(
                              text: _tx('save'),
                              bg: cPri,
                              fg: cTxt,
                              onTap: () {
                                syncSec();
                                syncBar();
                                final nm = ctrl.text.trim();
                                _pushHistoryIfNeeded(_currentSnapshot());
                                setState(() {
                                  memoryPresets[i] = MemoryPreset(
                                    bpm: p.bpm,
                                    beats: p.beats,
                                    notes: p.notes,
                                    levels: p.levels == null
                                        ? null
                                        : List<int>.from(p.levels!),
                                    name: nm.isEmpty ? null : nm,
                                    tmOn: localOn,
                                    tmMode: localMode,
                                    tmSec: localSec,
                                    tmBar: localBar,
                                    tmAct: localAct,
                                  );
                                });
                                _savePrefs();
                                if (isPlaying && _memFocusIdx == i) {
                                  _stTmRun();
                                }
                                Navigator.pop(context);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    ctrl.dispose();
    secCtrl.dispose();
    barCtrl.dispose();
  }

  Future<void> _rstAll() async {
    _pushHistoryIfNeeded(_currentSnapshot());
    _stopMetronome();
    setState(() {
      isPlaying = false;
      bpm = 100;
      _lastBpmInt = 100;
      beatCount = 4;
      noteCount = 1;
      for (int i = 0; i < 8; i++) {
        beatLevels[i] = 1;
      }
      memoryPresets = _defMemLst();
      _memFocusIdx = null;
      _clickKind = ClickKind.dgit1;
      _uiMode = UiModeOpt.auto;
      _theme = _themes.first;
      _masterVolume = 1.0;
      _balance = 0.0;
      _keepScreenOn = false;
      _soundMix = false;
      _backgroundPlay = false;
      _fastBpmStep = 10;
      _vibeClick = false;
      _dndAuto = false;
      _slideSnap = false;
      _bpmLo = 40;
      _bpmHi = 260;
      _lang = _sysLang();
      _screenDir = ScreenDir.auto;
      _fnBtn = FuncBtn.tap;
      _tmOn = false;
      _tmMode = TimerMode.sec;
      _tmSec = 60;
      _tmBar = 16;
      _tmAct = TmAct.stop;
      _tmRunOn = false;
      _manLnd = false;
      _memDelMd = false;
      _memNameMd = false;
    });
    _applySysUi();
    _applyLang();
    await _applyScreenDir();
    await _applyKeepScreenOn();
    await _applyAudioSessionConfig();
    await _savePrefs();
    await _syncDnd(on: false, play: false);
    unawaited(_buzz(ms: 120, amp: 240));
  }

  Future<void> _togglePlay() async {
    if (isPlaying) {
      _stopMetronome();
      setState(() => isPlaying = false);
      unawaited(_syncDnd());
      return;
    }
    setState(() => isPlaying = true);
    unawaited(_syncDnd());
    final ok = await _startMetronome();
    if (!ok && mounted) {
      setState(() => isPlaying = false);
      unawaited(_syncDnd());
    }
  }

  double _curSeq() {
    final sw = _stopwatch;
    if (sw == null || _stepUs <= 0) return 0.0;
    final nowUs = sw.elapsedMicroseconds.toDouble();
    return _baseSeq + ((nowUs - _baseUs) / _stepUs);
  }

  MemoryPreset? _curMemTm() {
    final i = _memFocusIdx;
    if (i == null || i < 0 || i >= 38) return null;
    final p = memoryPresets[i];
    if (!p.hasValue || !p.tmOn) return null;
    return p;
  }

  int? _nextMemIdx(int i) {
    for (int n = i + 1; n < 38; n++) {
      if (memoryPresets[n].hasValue) return n;
    }
    return null;
  }

  void _setTmCfg() {
    final mp = _curMemTm();
    if (mp != null) {
      _tmRunOn = true;
      _tmRunMode = mp.tmMode;
      _tmRunSec = mp.tmSec;
      _tmRunBar = mp.tmBar;
      _tmRunAct = mp.tmAct;
      return;
    }
    if (_fnBtn == FuncBtn.timer && _tmOn) {
      _tmRunOn = true;
      _tmRunMode = _tmMode;
      _tmRunSec = _tmSec;
      _tmRunBar = _tmBar;
      _tmRunAct = TmAct.stop;
      return;
    }
    _tmRunOn = false;
    _tmRunMode = _tmMode;
    _tmRunSec = _tmSec;
    _tmRunBar = _tmBar;
    _tmRunAct = TmAct.stop;
  }

  void _stTmRun() {
    _tmUi?.cancel();
    _tmProg = 0.0;
    _tmPend = false;
    _tmPendAct = TmAct.stop;
    _tmPendIdx = null;
    _setTmCfg();
    if (!_tmRunOn) return;
    _tmSeq0 = _curSeq();
    _tmBarStep = math.max(1, beatCount * _subCnt());
    void tick() {
      if (!mounted || !isPlaying || !_tmRunOn) {
        _tmUi?.cancel();
        _tmUi = null;
        if (mounted) setState(() => _tmProg = 0.0);
        return;
      }
      double p = 0.0;
      if (_tmRunMode == TimerMode.sec) {
        final sw = _stopwatch;
        final ms = sw?.elapsedMilliseconds ?? 0;
        p = ms / (_tmRunSec * 1000);
      } else {
        final cur = _curSeq();
        final tot = math.max(1.0, _tmBarStep * _tmRunBar.toDouble());
        p = (cur - _tmSeq0) / tot;
      }
      final next = p.clamp(0.0, 1.0);
      if ((next - _tmProg).abs() > 0.002 && mounted) {
        setState(() => _tmProg = next);
      }
      if (next >= 1.0) {
        _tmUi?.cancel();
        _tmUi = null;
        if (_tmRunAct == TmAct.next) {
          final i = _memFocusIdx;
          final ni = i == null ? null : _nextMemIdx(i);
          if (ni != null) {
            _tmPend = true;
            _tmPendAct = TmAct.next;
            _tmPendIdx = ni;
            return;
          }
        }
        _tmPend = true;
        _tmPendAct = TmAct.stop;
        _tmPendIdx = null;
      }
    }

    _tmUi = Timer.periodic(const Duration(milliseconds: 33), (_) => tick());
    tick();
  }

  void _edTmRun() {
    _tmUi?.cancel();
    _tmUi = null;
    _tmRunOn = false;
    _tmPend = false;
    _tmPendAct = TmAct.stop;
    _tmPendIdx = null;
    if (mounted) {
      setState(() => _tmProg = 0.0);
    } else {
      _tmProg = 0.0;
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
    _stepUs = _calcStepUs(bpmVal: bpm, noteVal: noteCount);
    _baseUs = _stopwatch!.elapsedMicroseconds.toDouble();
    _baseSeq = 0.0;
    _audSeq = 1;
    _visSeq = 1;
    _activeBeatIndex = -1;
    _pulseToken = 0;
    _pulseAmp = 1.0;
    _waveToken = 0;
    _waveIdx = -1;
    _waveAmp = 1.0;
    _tmPend = false;
    _tmPendAct = TmAct.stop;
    _tmPendIdx = null;
    _fireAud(0);
    _fireVis(0);
    _runTickLoop();
    _stTmRun();
    return true;
  }

  void _stopMetronome({bool cut = true}) {
    _tickTimer?.cancel();
    _tickTimer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    _baseUs = 0.0;
    _baseSeq = 0.0;
    _stepUs = 0.0;
    _activeBeatIndex = -1;
    _pulseToken = 0;
    _pulseAmp = 1.0;
    _waveToken = 0;
    _waveIdx = -1;
    _waveAmp = 1.0;
    _edTmRun();
    if (cut) {
      _stopAllSounds();
    } else {
      _hQ.clear();
    }
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
    final nowUs = sw.elapsedMicroseconds.toDouble();
    if (_stepUs <= 0) _stepUs = _calcStepUs(bpmVal: bpm, noteVal: noteCount);
    if (_tmPend) {
      final act = _tmPendAct;
      final idx = _tmPendIdx;
      _tmPend = false;
      _tmPendAct = TmAct.stop;
      _tmPendIdx = null;
      if (act == TmAct.next && idx != null && idx >= 0 && idx < 38) {
        _applyPreset(memoryPresets[idx], recordHistory: true, index: idx);
        _stTmRun();
      } else {
        _stopMetronome(cut: false);
        if (mounted) {
          setState(() => isPlaying = false);
        } else {
          isPlaying = false;
        }
        unawaited(_syncDnd(play: false));
      }
      return;
    }
    while (_audSeq <= _visSeq + 1) {
      final tgtUs = _baseUs + ((_audSeq - _baseSeq) * _stepUs);
      if (nowUs + _audLeadUs < tgtUs) break;
      _fireAud(_audSeq);
      _audSeq++;
    }
    while (true) {
      final tgtUs = _baseUs + ((_visSeq - _baseSeq) * _stepUs);
      if (nowUs < tgtUs) break;
      _fireVis(_visSeq);
      _visSeq++;
    }
    final nextAudUs = (_baseUs + ((_audSeq - _baseSeq) * _stepUs)) - _audLeadUs;
    final nextVisUs = _baseUs + ((_visSeq - _baseSeq) * _stepUs);
    final nextUs = math.min(nextAudUs, nextVisUs);
    final waitUs = (nextUs - sw.elapsedMicroseconds)
        .clamp(_schMinUs.toDouble(), _schMaxUs.toDouble())
        .round();
    _tickTimer?.cancel();
    _tickTimer = Timer(Duration(microseconds: waitUs), _runTickLoop);
  }

  void _fireVis(int seq) {
    final subCnt = _subCnt();
    final beatIdx = (seq ~/ subCnt) % beatCount;
    final subIdx = seq % subCnt;
    final lvl = beatLevels[beatIdx];
    double amp = 0.0;
    if (subIdx == 0) {
      amp = 1.0;
    } else if (_isShf() && subIdx == 2) {
      amp = 0.5;
    } else if (!_isShf()) {
      amp = 0.5;
    }
    if (amp <= 0) return;
    if (!mounted) return;
    setState(() {
      _activeBeatIndex = beatIdx;
      _pulseAmp = amp;
      _pulseToken++;
      if (subIdx == 0) {
        if (lvl < 3) {
          _waveIdx = beatIdx;
          _waveAmp = lvl == 1 ? 1.0 : 0.68;
          _waveToken++;
        } else {
          _waveIdx = -1;
        }
      }
    });
  }

  void _fireAud(int seq) {
    final src = _clickSource;
    if (!_audOk || src == null || !isPlaying) return;
    final subCnt = _subCnt();
    final beatIdx = (seq ~/ subCnt) % beatCount;
    final subIdx = seq % subCnt;
    final lvl = beatLevels[beatIdx];
    final baseVol = (lvl == 1)
        ? 1.0
        : (lvl == 2)
            ? 0.5
            : 0.0;
    final mul = _isShf()
        ? (subIdx == 0 ? 1.0 : (subIdx == 2 ? 0.5 : 0.0))
        : (subIdx == 0 ? 1.0 : 0.5);
    final vol = baseVol * mul * _masterVolume;
    if (vol <= 0) return;
    _fireHpt(lvl, subIdx);
    unawaited(_playClick(src, vol));
  }

  Future<void> _playClick(AudioSource src, double vol) async {
    try {
      final h = await _soloud.play(src, volume: vol, pan: _balance);
      _hQ.addLast(h);
      while (_hQ.length > 8) {
        _hQ.removeFirst();
      }
    } catch (_) {}
  }

  Future<void> _openTapTempoSheet() async {
    final cPrimary = _theme.color;
    final cPanel = _sheetPanelColor;
    final cText = _textColor;

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

      final calc = _clampBpm(60000.0 / avg);

      if (!pushed) {
        _pushHistoryIfNeeded(_currentSnapshot());
        pushed = true;
      }

      setState(() {
        _lastBpmInt = bpm.round();
        bpm = calc;
      });
      _savePrefs();
      if (isPlaying) _retimeCfg(bpmVal: calc);

      setSheet(() {});
    }

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final shownBpm = bpm.round();

            final screenH = MediaQuery.of(context).size.height;
            final isLnd =
                MediaQuery.of(context).orientation == Orientation.landscape;
            final sheetH = screenH * (isLnd ? 0.76 : 0.385);

            return _sheetWrap(
              context,
              SafeArea(
                top: false,
                child: Container(
                height: sheetH,
                decoration: BoxDecoration(
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
                          style: TextStyle(
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
                                  _ic('hand'),
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

  Future<void> _openTimerSheet() async {
    final cPri = _theme.color;
    final cPnl = _sheetPanelColor;
    final cTxt = _textColor;
    final cBg = _fieldBgColor;
    bool localOn = _tmOn;
    TimerMode localMode = _tmMode;
    int localSec = _tmSec;
    int localBar = _tmBar;
    final secCtrl = TextEditingController(text: '$localSec');
    final barCtrl = TextEditingController(text: '$localBar');

    Future<void> apply(StateSetter setSheet) async {
      setState(() {
        _tmOn = localOn;
        _tmMode = localMode;
        _tmSec = localSec;
        _tmBar = localBar;
      });
      await _savePrefs();
      if (isPlaying) _stTmRun();
      setSheet(() {});
    }

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            void syncSec(String _) {
              localSec = (int.tryParse(secCtrl.text.trim()) ?? localSec).clamp(1, 9999);
              secCtrl.text = '$localSec';
              secCtrl.selection =
                  TextSelection.collapsed(offset: secCtrl.text.length);
              unawaited(apply(setSheet));
            }

            void syncBar(String _) {
              localBar = (int.tryParse(barCtrl.text.trim()) ?? localBar).clamp(1, 9999);
              barCtrl.text = '$localBar';
              barCtrl.selection =
                  TextSelection.collapsed(offset: barCtrl.text.length);
              unawaited(apply(setSheet));
            }

            Widget tmRow(TimerMode mode) {
              final on = localMode == mode;
              final ctrl2 = mode == TimerMode.sec ? secCtrl : barCtrl;
              final sync = mode == TimerMode.sec ? syncSec : syncBar;
              final tail = switch (_lang) {
                LangOpt.ko => mode == TimerMode.sec
                    ? '\uCD08 \uD6C4 \uD074\uB9AD \uC885\uB8CC'
                    : '\uB9C8\uB514 \uD6C4 \uD074\uB9AD \uC885\uB8CC',
                LangOpt.en => mode == TimerMode.sec ? 'sec later stop' : 'bars later stop',
                LangOpt.ja => mode == TimerMode.sec
                    ? '\u79D2\u5F8C\u306B\u505C\u6B62'
                    : '\u5C0F\u7BC0\u5F8C\u306B\u505C\u6B62',
                LangOpt.zhs => mode == TimerMode.sec
                    ? '\u79D2\u540E\u505C\u6B62'
                    : '\u5C0F\u8282\u540E\u505C\u6B62',
                LangOpt.zht => mode == TimerMode.sec
                    ? '\u79D2\u5F8C\u505C\u6B62'
                    : '\u5C0F\u7BC0\u5F8C\u505C\u6B62',
              };
              return Opacity(
                opacity: on ? 1.0 : 0.46,
                child: RadioListTile<TimerMode>(
                  value: mode,
                  groupValue: localMode,
                  activeColor: cPri,
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      _fldBox(
                        context: context,
                        ctrl: ctrl2,
                        bg: cBg,
                        pri: cPri,
                        txt: cTxt,
                        w: 72,
                        maxLen: 4,
                        kbType: TextInputType.number,
                        ifs: [FilteringTextInputFormatter.digitsOnly],
                        counterText: '',
                        onSub: sync,
                        onOut: (_) => sync(ctrl2.text),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tail,
                          style: TextStyle(
                            color: cTxt,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onChanged: localOn
                      ? (v) async {
                          if (v == null) return;
                          setSheet(() => localMode = v);
                          await apply(setSheet);
                        }
                      : null,
                ),
              );
            }

            return _sheetWrap(
              context,
              SafeArea(
                top: false,
                child: Container(
                decoration: BoxDecoration(
                  color: cPnl,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(34),
                    topRight: Radius.circular(34),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  22,
                  18,
                  22,
                  22 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 6,
                        decoration: BoxDecoration(
                          color: cPri.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SettingSwitchRow(
                      title: _tx('tm_on'),
                      value: localOn,
                      primary: cPri,
                      textColor: cTxt,
                      onChanged: (v) async {
                        setSheet(() => localOn = v);
                        await apply(setSheet);
                      },
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: localOn ? 1.0 : 0.0,
                        child: localOn
                            ? Column(
                                children: [
                                  tmRow(TimerMode.sec),
                                  tmRow(TimerMode.bar),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
    secCtrl.dispose();
    barCtrl.dispose();
  }

  Future<void> _openSettingsSheet() async {
    ClickKind localClickKind = _clickKind;
    UiModeOpt localUiMode = _uiMode;
    ThemeOption localTheme = _theme;
    double localVol = _masterVolume;
    double localBal = _balance;
    bool localKeep = _keepScreenOn;
    bool localMix = _soundMix;
    bool localBg = _backgroundPlay;
    int localFastStep = _fastBpmStep;
    bool localVibeClick = _vibeClick;
    bool localDndAuto = _dndAuto;
    bool localSlideSnap = _slideSnap;
    int localBpmLo = _bpmLo;
    int localBpmHi = _bpmHi;
    LangOpt localLang = _lang;
    ScreenDir localScreenDir = _screenDir;
    FuncBtn localFnBtn = _fnBtn;
    bool localTmOn = _tmOn;
    TimerMode localTmMode = _tmMode;
    int localTmSec = _tmSec;
    int localTmBar = _tmBar;
    bool advOpen = false;
    final fastCtrl = TextEditingController(text: '$localFastStep');
    final loCtrl = TextEditingController(text: '$localBpmLo');
    final hiCtrl = TextEditingController(text: '$localBpmHi');
    ScrollController? scrCtrl;
    final advCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    final advAni = CurvedAnimation(
      parent: advCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final advTglKey = GlobalKey();
    final advEndKey = GlobalKey();
    const advDur = Duration(milliseconds: 240);

    double snapVolume(double v) {
      if ((v - 1.0).abs() <= 0.05) return 1.0;
      if ((v - 2.0).abs() <= 0.05) return 2.0;
      if ((v - 3.0).abs() <= 0.05) return 3.0;
      if ((v - 4.0).abs() <= 0.05) return 4.0;
      return v;
    }

    double snapBalance(double v) {
      if (v.abs() <= 0.05) return 0.0;
      return v;
    }

    Future<void> applyAll(StateSetter setSheet) async {
      final prevKind = _clickKind;
      final prevBpm = bpm;
      setState(() {
        _clickKind = localClickKind;
        _uiMode = localUiMode;
        _theme = localTheme;
        _masterVolume = localVol;
        _balance = localBal;
        _keepScreenOn = localKeep;
        _soundMix = localMix;
        _backgroundPlay = localBg;
        _fastBpmStep = localFastStep;
        _vibeClick = localVibeClick;
        _dndAuto = localDndAuto;
        _slideSnap = localSlideSnap;
        _bpmLo = localBpmLo;
        _bpmHi = localBpmHi;
        _lang = localLang;
        if (_screenDir != localScreenDir &&
            localScreenDir == ScreenDir.manual) {
          final ori = MediaQuery.of(context).orientation;
          _manLnd = ori == Orientation.landscape;
        }
        _screenDir = localScreenDir;
        _fnBtn = localFnBtn;
        _tmOn = localTmOn;
        _tmMode = localTmMode;
        _tmSec = localTmSec;
        _tmBar = localTmBar;
        final nextBpm = _clampBpm(bpm);
        if (nextBpm.round() != bpm.round()) {
          _lastBpmInt = bpm.round();
        }
        bpm = nextBpm;
      });

      _applySysUi();
      _applyLang();
      await _applyScreenDir();
      await _savePrefs();
      await _applyKeepScreenOn();
      await _applyAudioSessionConfig();
      if (_clickKind != prevKind) {
        await _reloadClickSource();
      }
      if (isPlaying && bpm != prevBpm) {
        _retimeCfg(bpmVal: bpm);
      }
      if (isPlaying) _stTmRun();
      await _syncDnd();

      setSheet(() {});
    }

    Future<void> saveAud(StateSetter setSheet) async {
      await _savePrefs();
      setSheet(() {});
    }

    Future<void> syncFast(StateSetter setSheet) async {
      final raw = fastCtrl.text.trim();
      final next = int.tryParse(raw);
      if (next == null || next < 2 || next > 100) {
        fastCtrl.text = '$localFastStep';
        fastCtrl.selection =
            TextSelection.collapsed(offset: fastCtrl.text.length);
        setSheet(() {});
        return;
      }
      if (next == localFastStep) {
        fastCtrl.text = '$localFastStep';
        fastCtrl.selection =
            TextSelection.collapsed(offset: fastCtrl.text.length);
        return;
      }
      localFastStep = next;
      await applyAll(setSheet);
      fastCtrl.text = '$localFastStep';
      fastCtrl.selection =
          TextSelection.collapsed(offset: fastCtrl.text.length);
      setSheet(() {});
    }

    Future<void> stepFast(int delta, StateSetter setSheet) async {
      final next = (localFastStep + delta).clamp(2, 100);
      if (next == localFastStep) return;
      localFastStep = next;
      fastCtrl.text = '$localFastStep';
      fastCtrl.selection =
          TextSelection.collapsed(offset: fastCtrl.text.length);
      await applyAll(setSheet);
      setSheet(() {});
    }

    Future<void> syncBpmRng(StateSetter setSheet) async {
      final lo = int.tryParse(loCtrl.text.trim());
      final hi = int.tryParse(hiCtrl.text.trim());
      if (lo == null || hi == null) {
        loCtrl.text = '$localBpmLo';
        hiCtrl.text = '$localBpmHi';
        loCtrl.selection = TextSelection.collapsed(offset: loCtrl.text.length);
        hiCtrl.selection = TextSelection.collapsed(offset: hiCtrl.text.length);
        setSheet(() {});
        return;
      }
      final nextLo = lo.clamp(10, 499);
      final nextHi = hi.clamp(11, 500);
      if (nextLo >= nextHi) {
        loCtrl.text = '$localBpmLo';
        hiCtrl.text = '$localBpmHi';
        loCtrl.selection = TextSelection.collapsed(offset: loCtrl.text.length);
        hiCtrl.selection = TextSelection.collapsed(offset: hiCtrl.text.length);
        setSheet(() {});
        return;
      }
      if (nextLo == localBpmLo && nextHi == localBpmHi) {
        loCtrl.text = '$localBpmLo';
        hiCtrl.text = '$localBpmHi';
        return;
      }
      localBpmLo = nextLo;
      localBpmHi = nextHi;
      await applyAll(setSheet);
      loCtrl.text = '$localBpmLo';
      hiCtrl.text = '$localBpmHi';
      loCtrl.selection = TextSelection.collapsed(offset: loCtrl.text.length);
      hiCtrl.selection = TextSelection.collapsed(offset: hiCtrl.text.length);
      setSheet(() {});
    }

    void togAdv(StateSetter setSheet) {
      advOpen = !advOpen;
      setSheet(() {});
      if (advOpen) {
        final s = scrCtrl;
        final st = s != null && s.hasClients ? s.offset : 0.0;
        double mov = 0.0;
        final tgCtx = advTglKey.currentContext;
        if (s != null && s.hasClients && tgCtx != null) {
          final tgBox = tgCtx.findRenderObject();
          final vpBox = Scrollable.of(tgCtx)?.context.findRenderObject();
          if (tgBox is RenderBox && vpBox is RenderBox) {
            final dy = tgBox.localToGlobal(Offset.zero, ancestor: vpBox).dy;
            mov = math.max(0.0, dy - 2.0);
          }
        }
        void lis() {
          final s2 = scrCtrl;
          if (s2 == null || !s2.hasClients) return;
          final max = s2.position.maxScrollExtent;
          final tgt = (st + (mov * advCtrl.value)).clamp(0.0, max);
          if ((s2.offset - tgt).abs() > 0.5) {
            s2.jumpTo(tgt);
          }
        }

        advCtrl.addListener(lis);
        advCtrl.forward();
        void rm(AnimationStatus st) {
          if (st == AnimationStatus.completed ||
              st == AnimationStatus.dismissed) {
            advCtrl.removeListener(lis);
            advCtrl.removeStatusListener(rm);
          }
        }

        advCtrl.addStatusListener(rm);
      } else {
        advCtrl.reverse();
        if (scrCtrl != null &&
            scrCtrl!.hasClients &&
            scrCtrl!.offset >
                math.max(120.0, scrCtrl!.position.maxScrollExtent * 0.7)) {
          final next = math.max(0.0, scrCtrl!.offset - 220.0);
          unawaited(
            scrCtrl!.animateTo(
              next,
              duration: advDur,
              curve: Curves.easeInOutCubic,
            ),
          );
        }
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        final sh0 = MediaQuery.of(context).orientation == Orientation.landscape
            ? 0.90
            : 0.78;
        final sh1 = MediaQuery.of(context).orientation == Orientation.landscape
            ? 0.90
            : 0.78;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: sh1,
          minChildSize: 0.22,
          maxChildSize: sh1,
          snap: true,
          snapSizes: [sh1],
          builder: (context, shCtrl) {
            scrCtrl = shCtrl;
            return StatefulBuilder(
              builder: (context, setSheet) {
            final cPanel = _sheetPanelColorOf(localUiMode);
            final cBg = _fieldBgColorOf(localUiMode);
            final cText = _textColorOf(localUiMode);
            final pressOverlay = localTheme.color.withValues(alpha: 0.18);
            final icBase = _iconBaseOf(localUiMode);
            String sIc(String nm) => '$icBase/$nm.png';
            Future<void> setVol(double v) async {
              final next = snapVolume(v.clamp(0.0, 5.0));
              localVol = next;
              setState(() => _masterVolume = next);
              setSheet(() {});
              await saveAud(setSheet);
            }

            Future<void> setBal(double v) async {
              final next = snapBalance(v.clamp(-1.0, 1.0));
              localBal = next;
              setState(() => _balance = next);
              setSheet(() {});
              await saveAud(setSheet);
            }

            Widget sectionTitle(String t) {
              return Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t,
                    textAlign: TextAlign.left,
                    style: TextStyle(
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

            final volPct = (localVol.clamp(0.0, 5.0) * 100).round();

            return _sheetWrap(
              context,
              SafeArea(
                top: false,
                child: Container(
                decoration: BoxDecoration(
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
                        controller: shCtrl,
                        physics: const ClampingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: Column(
                          children: [
                            rowTile(
                              left: Text(
                                _tx('click_kind'),
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
                                textColor: cText,
                                itemHeight: 48,
                                menuTextStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: cText,
                                  height: 1.0,
                                ),
                                menuBg: cBg,
                                anchorWidth: 198,
                                menuMinWidth: 156,
                                menuMaxWidth: 184,
                                buildSelected: (ctx, v) => Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    _clickLabel(v),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: cText,
                                    ),
                                  ),
                                ),
                                buildItem: (ctx, v) => Center(
                                  child: Text(
                                    _clickLabel(v),
                                    style: TextStyle(
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
                              left: Text(
                                _tx('theme'),
                                style: TextStyle(
                                  color: cText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              right: PopupSelectButton<UiModeOpt>(
                                value: localUiMode,
                                items: UiModeOpt.values,
                                overlayColor: pressOverlay,
                                textColor: cText,
                                itemHeight: 48,
                                menuTextStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: cText,
                                  height: 1.0,
                                ),
                                menuBg: cBg,
                                anchorWidth: 198,
                                menuMinWidth: 156,
                                menuMaxWidth: 184,
                                buildSelected: (ctx, v) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Image.asset(
                                        sIc(v == UiModeOpt.auto
                                            ? 'whiteblack'
                                            : v == UiModeOpt.dark
                                                ? 'dark'
                                                : 'light'),
                                        width: 18,
                                        height: 18,
                                        color: cText,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _uiLbl(v, localLang),
                                        style: TextStyle(
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
                                      Image.asset(
                                        sIc(v == UiModeOpt.auto
                                            ? 'whiteblack'
                                            : v == UiModeOpt.dark
                                                ? 'dark'
                                                : 'light'),
                                        width: 18,
                                        height: 18,
                                        color: cText,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _uiLbl(v, localLang),
                                        style: TextStyle(
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
                                  localUiMode = v;
                                  await applyAll(setSheet);
                                },
                              ),
                            ),
                            rowTile(
                              left: Text(
                                _tx('color'),
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
                                textColor: cText,
                                itemHeight: 48,
                                menuTextStyle: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: cText,
                                  height: 1.0,
                                ),
                                menuBg: cBg,
                                anchorWidth: 198,
                                menuMinWidth: 156,
                                menuMaxWidth: 184,
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
                                        _themeLbl(v),
                                        style: TextStyle(
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
                                        _themeLbl(v),
                                        style: TextStyle(
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
                            rowTile(
                              left: Text(
                                _tx('func'),
                                style: TextStyle(
                                  color: cText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              right: localScreenDir == ScreenDir.manual
                                  ? SizedBox(
                                      width: 198,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Image.asset(
                                            sIc('rotate'),
                                            width: 18,
                                            height: 18,
                                            color: cText,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _fnLbl(FuncBtn.rotate, localLang),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: cText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : PopupSelectButton<FuncBtn>(
                                      value: localFnBtn,
                                      items: const [
                                        FuncBtn.tap,
                                        FuncBtn.timer,
                                        FuncBtn.none,
                                      ],
                                      overlayColor: pressOverlay,
                                      textColor: cText,
                                      itemHeight: 48,
                                      menuTextStyle: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: cText,
                                        height: 1.0,
                                      ),
                                      menuBg: cBg,
                                      anchorWidth: 198,
                                      menuMinWidth: 156,
                                      menuMaxWidth: 184,
                                      buildSelected: (ctx, v) => Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Image.asset(
                                            _fnIc(v),
                                            width: 18,
                                            height: 18,
                                            color: cText,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _fnLbl(v, localLang),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: cText,
                                            ),
                                          ),
                                        ],
                                      ),
                                      buildItem: (ctx, v) => Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image.asset(
                                            _fnIc(v),
                                            width: 18,
                                            height: 18,
                                            color: cText,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _fnLbl(v, localLang),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: cText,
                                              height: 1.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                      onChanged: (v) async {
                                        localFnBtn = v;
                                        await applyAll(setSheet);
                                      },
                                    ),
                            ),
                            const SizedBox(height: 18),
                            sectionTitle('${_tx('vol')}: $volPct%'),
                            Row(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    await setVol(0.0);
                                  },
                                  child: Image.asset(
                                    sIc('mute'),
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
                                      inactiveTrackColor:
                                          cText.withValues(alpha: 0.7),
                                      thumbColor: localTheme.color,
                                      overlayColor: localTheme.color
                                          .withValues(alpha: 0.18),
                                      thumbShape: const TallOvalThumbShape(
                                          width: 19.5, height: 34.5),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                              overlayRadius: 18),
                                      trackShape: MarkedSliderTrackShape(
                                        min: 0.0,
                                        max: 5.0,
                                        marks: const [1.0, 2.0, 3.0, 4.0],
                                        markColor: cText.withValues(alpha: 0.7),
                                        markWidth: 4.5,
                                      ),
                                    ),
                                    child: Slider(
                                      min: 0.0,
                                      max: 5.0,
                                      value: localVol.clamp(0.0, 5.0),
                                      onChanged: (v) {
                                        final next =
                                            snapVolume(v.clamp(0.0, 5.0));
                                        localVol = next;
                                        setState(() => _masterVolume = next);
                                        setSheet(() {});
                                      },
                                      onChangeEnd: (v) async {
                                        final snapped =
                                            snapVolume(v.clamp(0.0, 5.0));
                                        localVol = snapped;
                                        setState(() => _masterVolume = snapped);
                                        await saveAud(setSheet);
                                        setSheet(() {});
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    await setVol(5.0);
                                  },
                                  child: Image.asset(
                                    sIc('volume'),
                                    width: 34,
                                    height: 34,
                                    color: cText,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _SettingSwitchRow(
                              title: _tx('keep'),
                              value: localKeep,
                              primary: localTheme.color,
                              textColor: cText,
                              onChanged: (v) async {
                                setSheet(() => localKeep = v);
                                await applyAll(setSheet);
                              },
                            ),
                            _SettingSwitchRow(
                              title: _tx('bg'),
                              value: localBg,
                              primary: localTheme.color,
                              textColor: cText,
                              onChanged: (v) async {
                                setSheet(() => localBg = v);
                                await applyAll(setSheet);
                              },
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              key: advTglKey,
                              behavior: HitTestBehavior.opaque,
                              onTap: () => togAdv(setSheet),
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(top: 18, bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _tx('adv'),
                                        style: TextStyle(
                                          color: cText,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    AnimatedRotation(
                                      turns: advOpen ? 0.5 : 0.0,
                                      duration:
                                          const Duration(milliseconds: 180),
                                      curve: Curves.easeOutCubic,
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: cText,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IgnorePointer(
                              ignoring: !advOpen,
                              child: FadeTransition(
                                opacity: advAni,
                                child: SizeTransition(
                                  sizeFactor: advAni,
                                  axisAlignment: -1.0,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 12),
                                      rowTile(
                                        left: Text(
                                          _tx('lang'),
                                          style: TextStyle(
                                            color: cText,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        right: PopupSelectButton<LangOpt>(
                                          value: localLang,
                                          items: LangOpt.values,
                                          overlayColor: pressOverlay,
                                          textColor: cText,
                                          itemHeight: 48,
                                          menuTextStyle: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: cText,
                                            height: 1.0,
                                          ),
                                          menuBg: cBg,
                                          anchorWidth: 198,
                                          menuMinWidth: 156,
                                          menuMaxWidth: 184,
                                          buildSelected: (ctx, v) => Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              _langLbl(v),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: cText,
                                              ),
                                            ),
                                          ),
                                          buildItem: (ctx, v) => Center(
                                            child: Text(
                                              _langLbl(v),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: cText,
                                              ),
                                            ),
                                          ),
                                          onChanged: (v) async {
                                            localLang = v;
                                            await applyAll(setSheet);
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      rowTile(
                                        left: Text(
                                          _dirTitle(localLang),
                                          style: TextStyle(
                                            color: cText,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        right: PopupSelectButton<ScreenDir>(
                                          value: localScreenDir,
                                          items: ScreenDir.values,
                                          overlayColor: pressOverlay,
                                          textColor: cText,
                                          itemHeight: 48,
                                          menuTextStyle: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: cText,
                                            height: 1.0,
                                          ),
                                          menuBg: cBg,
                                          anchorWidth: 198,
                                          menuMinWidth: 156,
                                          menuMaxWidth: 184,
                                          buildSelected: (ctx, v) => Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              _dirLbl(v, localLang),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: cText,
                                              ),
                                            ),
                                          ),
                                          buildItem: (ctx, v) => Center(
                                            child: Text(
                                              _dirLbl(v, localLang),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: cText,
                                              ),
                                            ),
                                          ),
                                          onChanged: (v) async {
                                            localScreenDir = v;
                                            await applyAll(setSheet);
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      sectionTitle(_tx('bal')),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () async {
                                              await setBal(-1.0);
                                            },
                                            child: Transform(
                                              alignment: Alignment.center,
                                              transform: Matrix4.identity()
                                                ..rotateY(math.pi),
                                              child: Image.asset(
                                                sIc('arrows'),
                                                width: 34,
                                                height: 34,
                                                color: cText,
                                                filterQuality:
                                                    FilterQuality.high,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                trackHeight: 6,
                                                activeTrackColor:
                                                    localTheme.color,
                                                inactiveTrackColor: cText
                                                    .withValues(alpha: 0.7),
                                                thumbColor: localTheme.color,
                                                overlayColor: localTheme.color
                                                    .withValues(alpha: 0.18),
                                                thumbShape:
                                                    const TallOvalThumbShape(
                                                        width: 19.5,
                                                        height: 34.5),
                                                overlayShape:
                                                    const RoundSliderOverlayShape(
                                                        overlayRadius: 18),
                                                trackShape:
                                                    MarkedSliderTrackShape(
                                                  min: -1.0,
                                                  max: 1.0,
                                                  marks: const [0.0],
                                                  markColor: cText.withValues(
                                                      alpha: 0.7),
                                                  markWidth: 4.5,
                                                ),
                                              ),
                                              child: Slider(
                                                min: -1.0,
                                                max: 1.0,
                                                value:
                                                    localBal.clamp(-1.0, 1.0),
                                                onChanged: (v) {
                                                  final next = snapBalance(
                                                      v.clamp(-1.0, 1.0));
                                                  localBal = next;
                                                  setState(
                                                      () => _balance = next);
                                                  setSheet(() {});
                                                },
                                                onChangeEnd: (v) async {
                                                  final snapped = snapBalance(
                                                      v.clamp(-1.0, 1.0));
                                                  localBal = snapped;
                                                  setState(
                                                      () => _balance = snapped);
                                                  await saveAud(setSheet);
                                                  setSheet(() {});
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () async {
                                              await setBal(1.0);
                                            },
                                            child: Image.asset(
                                              sIc('arrows'),
                                              width: 34,
                                              height: 34,
                                              color: cText,
                                              filterQuality: FilterQuality.high,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 32),
                                      rowTile(
                                        left: Text(
                                          _tx('fast'),
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
                                              asset: sIc('minus'),
                                              bg: cBg,
                                              color: cText,
                                              overlayColor: pressOverlay,
                                              borderColor: localTheme.color
                                                  .withValues(alpha: 0.38),
                                              onTap: () async {
                                                await stepFast(-1, setSheet);
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              width: 122,
                                              child: Theme(
                                                data:
                                                    Theme.of(context).copyWith(
                                                  textSelectionTheme:
                                                      TextSelectionThemeData(
                                                    cursorColor:
                                                        localTheme.color,
                                                    selectionColor: localTheme
                                                        .color
                                                        .withValues(
                                                            alpha: 0.28),
                                                    selectionHandleColor:
                                                        localTheme.color,
                                                  ),
                                                ),
                                                child: TextField(
                                                  controller: fastCtrl,
                                                  cursorColor: localTheme.color,
                                                  textAlign: TextAlign.center,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  style: TextStyle(
                                                    color: cText,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 14,
                                                            vertical: 12),
                                                    filled: true,
                                                    fillColor: cBg,
                                                    hintText: '2~100',
                                                    hintStyle: TextStyle(
                                                      color: cText.withValues(
                                                          alpha: 0.42),
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      borderSide: BorderSide(
                                                        color: localTheme.color
                                                            .withValues(
                                                                alpha: 0.38),
                                                        width: 1.2,
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
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
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                    await syncFast(setSheet);
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _StepValueButton(
                                              asset: sIc('plus'),
                                              bg: cBg,
                                              color: cText,
                                              overlayColor: pressOverlay,
                                              borderColor: localTheme.color
                                                  .withValues(alpha: 0.38),
                                              onTap: () async {
                                                await stepFast(1, setSheet);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      rowTile(
                                        left: Text(
                                          _tx('rng'),
                                          style: TextStyle(
                                            color: cText,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        right: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 72,
                                              child: Theme(
                                                data:
                                                    Theme.of(context).copyWith(
                                                  textSelectionTheme:
                                                      TextSelectionThemeData(
                                                    cursorColor:
                                                        localTheme.color,
                                                    selectionColor: localTheme
                                                        .color
                                                        .withValues(
                                                            alpha: 0.28),
                                                    selectionHandleColor:
                                                        localTheme.color,
                                                  ),
                                                ),
                                                child: TextField(
                                                  controller: loCtrl,
                                                  cursorColor: localTheme.color,
                                                  textAlign: TextAlign.center,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  style: TextStyle(
                                                    color: cText,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10,
                                                            vertical: 12),
                                                    filled: true,
                                                    fillColor: cBg,
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      borderSide: BorderSide(
                                                        color: localTheme.color
                                                            .withValues(
                                                                alpha: 0.38),
                                                        width: 1.2,
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      borderSide: BorderSide(
                                                        color: localTheme.color,
                                                        width: 1.4,
                                                      ),
                                                    ),
                                                  ),
                                                  onSubmitted: (_) async {
                                                    await syncBpmRng(setSheet);
                                                  },
                                                  onTapOutside: (_) async {
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                    await syncBpmRng(setSheet);
                                                  },
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10),
                                              child: Text(
                                                '~',
                                                style: TextStyle(
                                                  color: cText,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 72,
                                              child: Theme(
                                                data:
                                                    Theme.of(context).copyWith(
                                                  textSelectionTheme:
                                                      TextSelectionThemeData(
                                                    cursorColor:
                                                        localTheme.color,
                                                    selectionColor: localTheme
                                                        .color
                                                        .withValues(
                                                            alpha: 0.28),
                                                    selectionHandleColor:
                                                        localTheme.color,
                                                  ),
                                                ),
                                                child: TextField(
                                                  controller: hiCtrl,
                                                  cursorColor: localTheme.color,
                                                  textAlign: TextAlign.center,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                  ],
                                                  style: TextStyle(
                                                    color: cText,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 10,
                                                            vertical: 12),
                                                    filled: true,
                                                    fillColor: cBg,
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      borderSide: BorderSide(
                                                        color: localTheme.color
                                                            .withValues(
                                                                alpha: 0.38),
                                                        width: 1.2,
                                                      ),
                                                    ),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                      borderSide: BorderSide(
                                                        color: localTheme.color,
                                                        width: 1.4,
                                                      ),
                                                    ),
                                                  ),
                                                  onSubmitted: (_) async {
                                                    await syncBpmRng(setSheet);
                                                  },
                                                  onTapOutside: (_) async {
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                    await syncBpmRng(setSheet);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _SettingSwitchRow(
                                        title: _tx('mix'),
                                        value: localMix,
                                        primary: localTheme.color,
                                        textColor: cText,
                                        onChanged: (v) async {
                                          setSheet(() => localMix = v);
                                          await applyAll(setSheet);
                                        },
                                      ),
                                      _SettingSwitchRow(
                                        title: _tx('dnd'),
                                        value: localDndAuto,
                                        primary: localTheme.color,
                                        textColor: cText,
                                        onChanged: (v) async {
                                          if (!v) {
                                            setSheet(
                                                () => localDndAuto = false);
                                            await applyAll(setSheet);
                                            return;
                                          }
                                          final ok = await _reqDnd();
                                          if (!ok) {
                                            setSheet(
                                                () => localDndAuto = false);
                                            return;
                                          }
                                          setSheet(() => localDndAuto = true);
                                          await applyAll(setSheet);
                                        },
                                      ),
                                      _SettingSwitchRow(
                                        title: _tx('snap'),
                                        value: localSlideSnap,
                                        primary: localTheme.color,
                                        textColor: cText,
                                        onChanged: (v) async {
                                          setSheet(() => localSlideSnap = v);
                                          await applyAll(setSheet);
                                        },
                                      ),
                                      _SettingSwitchRow(
                                        title: _tx('vibe'),
                                        value: localVibeClick,
                                        primary: localTheme.color,
                                        textColor: cText,
                                        onChanged: (v) async {
                                          setSheet(() => localVibeClick = v);
                                          await applyAll(setSheet);
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                      SizedBox(
                                        width: double.infinity,
                                        child: _SheetBtn(
                                          text: _tx('rst'),
                                          bg: const Color(0xFFFF7048),
                                          fg: cText,
                                          icon: _ic('reload'),
                                          onTap: () async {
                                            await _rstAll();
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(key: advEndKey, height: 0),
                                    ],
                                  ),
                                ),
                              ),
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
              ),
            );
          },
        );
      },
    );
    advCtrl.dispose();
    fastCtrl.dispose();
    loCtrl.dispose();
    hiCtrl.dispose();
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
  final Color textColor;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchRow({
    required this.title,
    required this.value,
    required this.primary,
    required this.textColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: textColor,
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
  final double pulseAmp;
  final int waveToken;
  final int waveIndex;
  final double waveAmp;
  final int waveMs;
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
    required this.pulseAmp,
    required this.waveToken,
    required this.waveIndex,
    required this.waveAmp,
    required this.waveMs,
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
      final bool isWave = index == waveIndex;
      final amp = isActive ? pulseAmp.clamp(0.0, 1.0) : 0.0;
      final wav = isWave ? waveAmp.clamp(0.0, 1.0) : 0.0;
      final double alphaBase = (level == 1)
          ? 0.7
          : (level == 2)
              ? 0.6
              : 0.3;
      final activeAlpha = level == 3 ? (alphaBase + 1.0) * 0.5 : 1.0;
      final alpha = isActive ? activeAlpha : alphaBase;

      return SizedBox(
        width: cell,
        height: cell,
        child: Center(
          child: SizedBox(
            width: cell,
            height: cell,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  key: ValueKey('r$index-${isWave ? waveToken : 0}'),
                  tween: Tween<double>(
                    begin: 0.0,
                    end: isWave && wav > 0 ? 1.0 : 0.0,
                  ),
                  duration: Duration(milliseconds: waveMs),
                  curve: Curves.linear,
                  builder: (context, p, _) {
                    final a = (isWave && wav > 0
                            ? 0.33 *
                                wav *
                                math.pow(1.0 - p.clamp(0.0, 1.0), 1.45)
                            : 0.0)
                        .clamp(0.0, 0.33)
                        .toDouble();
                    final rs = 1.0 + (0.24 * Curves.easeOutCubic.transform(p));
                    return IgnorePointer(
                      child: Opacity(
                        opacity: a,
                        child: Transform.scale(
                          scale: rs,
                          child: Container(
                            width: d,
                            height: d,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  opacity: alpha,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('b$index-${isActive ? pulseToken : 0}'),
                    tween: Tween<double>(
                      begin: isActive ? 1.0 + (0.12 * amp) : 1.0,
                      end: 1.0,
                    ),
                    duration: const Duration(milliseconds: 170),
                    curve: Curves.easeOutCubic,
                    builder: (context, s, child) =>
                        Transform.scale(scale: s, child: child),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 115),
                      curve: Curves.easeOutCubic,
                      width: d,
                      height: d,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      foregroundDecoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => onTapBeat(index),
                          customBorder: const CircleBorder(),
                          overlayColor:
                              WidgetStateProperty.resolveWith((states) {
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
              ],
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
  final Color menuBg;
  final ValueChanged<int> onChanged;

  const PopupNumberSelect({
    super.key,
    required this.value,
    required this.items,
    required this.scale,
    required this.color,
    required this.overlayColor,
    required this.menuBg,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedStyle = TextStyle(
      fontSize: (48.0 * scale.clamp(0.76, 1.06)).clamp(34.0, 56.0),
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

    final itemH = (38.0 * scale.clamp(0.70, 1.0)).clamp(28.0, 42.0);

    return PopupSelectButton<int>(
      value: value,
      items: items,
      overlayColor: overlayColor,
      itemHeight: itemH,
      menuTextStyle: menuStyle,
      menuBg: menuBg,
      textColor: color,
      anchorWidth: (116.0 * scale.clamp(0.78, 1.08)).clamp(92.0, 132.0),
      menuMinWidth: (88.0 * scale.clamp(0.78, 1.08)).clamp(80.0, 106.0),
      menuMaxWidth: (108.0 * scale.clamp(0.78, 1.08)).clamp(94.0, 124.0),
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
  final Color menuBg;
  final String noteAsset;
  final String Function(int) labelOf;
  final ValueChanged<int> onChanged;

  const PopupNoteSelect({
    super.key,
    required this.value,
    required this.items,
    required this.scale,
    required this.color,
    required this.overlayColor,
    required this.menuBg,
    required this.noteAsset,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedNumStyle = TextStyle(
      fontSize: (40.0 * scale.clamp(0.76, 1.06)).clamp(30.0, 48.0),
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

    final noteSelected = (46.0 * scale.clamp(0.76, 1.06)).clamp(32.0, 56.0);
    final noteMenu = (24.0 * scale.clamp(0.70, 1.0)).clamp(18.0, 28.0);
    final itemH = (38.0 * scale.clamp(0.70, 1.0)).clamp(28.0, 42.0);

    Widget row(
        {required double noteSize, required TextStyle ts, required int v}) {
      final isShf = v == _noteShf;
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isShf) ...[
            Image.asset(
              noteAsset,
              width: noteSize,
              height: noteSize,
              color: color,
              filterQuality: FilterQuality.high,
            ),
            const SizedBox(width: 8),
          ],
          Text(labelOf(v), style: ts),
        ],
      );
    }

    return PopupSelectButton<int>(
      value: value,
      items: items,
      overlayColor: overlayColor,
      itemHeight: itemH,
      menuTextStyle: menuStyle,
      menuBg: menuBg,
      textColor: color,
      anchorWidth: (154.0 * scale.clamp(0.78, 1.08)).clamp(126.0, 182.0),
      menuMinWidth: (114.0 * scale.clamp(0.78, 1.08)).clamp(98.0, 138.0),
      menuMaxWidth: (134.0 * scale.clamp(0.78, 1.08)).clamp(110.0, 154.0),
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
  final Color textColor;
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
    required this.textColor,
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
    final arrSz = (itemHeight * 1.28).clamp(34.0, 52.0);

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
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        child: SizedBox(
          width: anchorWidth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(child: buildSelected(context, value)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: arrSz, color: textColor),
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
    final fill = bg.withValues(
      alpha: math.min(bg.alpha / 255.0, 0.90),
    );
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: fill,
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
  final bool useMinAlpha;

  const PresetIconButton({
    super.key,
    required this.bg,
    required this.radius,
    required this.asset,
    required this.iconColor,
    required this.overlayColor,
    required this.iconSize,
    required this.onTap,
    this.useMinAlpha = true,
  });

  @override
  Widget build(BuildContext context) {
    final fill = useMinAlpha
        ? bg.withValues(
            alpha: math.min(bg.alpha / 255.0, 0.90),
          )
        : bg;
    return SizedBox.expand(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.all(radius),
        ),
        child: Material(
          color: Colors.transparent,
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
    final fill = bg.withValues(
      alpha: math.min(bg.alpha / 255.0, 0.90),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: fill,
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
  final double ringP;
  final Color? ringColor;
  final VoidCallback onTap;

  const CircleActionButton({
    super.key,
    required this.diameter,
    required this.bg,
    required this.asset,
    required this.iconSize,
    required this.iconColor,
    required this.overlayColor,
    this.ringP = 0.0,
    this.ringColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = bg.withValues(
      alpha: math.min(bg.alpha / 255.0, 0.90),
    );
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (ringP > 0 && ringColor != null)
            SizedBox(
              width: diameter * 1.10,
              height: diameter * 1.10,
              child: CustomPaint(
                painter: _TimerRingPainter(
                  p: ringP.clamp(0.0, 1.0),
                  color: ringColor!,
                ),
              ),
            ),
          Material(
            color: fill,
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 132),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, ani) {
                    final fade = CurvedAnimation(
                      parent: ani,
                      curve: Curves.easeOutCubic,
                    );
                    final scale =
                        Tween<double>(begin: 0.92, end: 1.0).animate(fade);
                    return FadeTransition(
                      opacity: fade,
                      child: ScaleTransition(
                        scale: scale,
                        child: child,
                      ),
                    );
                  },
                  child: Image.asset(
                    asset,
                    key: ValueKey(asset),
                    width: iconSize,
                    height: iconSize,
                    color: iconColor,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  final double p;
  final Color color;

  const _TimerRingPainter({
    required this.p,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, size.width * 0.03)
      ..strokeCap = StrokeCap.round
      ..color = color;
    final sweep = math.pi * 2 * p.clamp(0.0, 1.0);
    canvas.drawArc(
      rect.deflate(paint.strokeWidth * 0.5),
      -math.pi / 2,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.p != p || oldDelegate.color != color;
  }
}

class _SheetBtn extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final String? icon;
  final VoidCallback onTap;

  const _SheetBtn({
    required this.text,
    required this.bg,
    required this.fg,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: bg.withValues(alpha: math.min(bg.alpha / 255.0, 0.90)),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Image.asset(
                  icon!,
                  width: 18,
                  height: 18,
                  color: fg,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  color: fg,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
