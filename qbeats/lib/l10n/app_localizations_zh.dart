// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get clickDigital1 => '数字 1';

  @override
  String get clickDigital2 => '数字 2';

  @override
  String get clickDigital3 => '数字 3';

  @override
  String get clickAnalog1 => '模拟 1';

  @override
  String get clickAnalog2 => '模拟 2';

  @override
  String get clickAnalog3 => '模拟 3';

  @override
  String get themeSky => '天蓝';

  @override
  String get themeBlue => '蓝色';

  @override
  String get themeRed => '红色';

  @override
  String get themeOrange => '橙色';

  @override
  String get themeYellow => '黄色';

  @override
  String get themeGreen => '绿色';

  @override
  String get themeLime => '青柠';

  @override
  String get themePurple => '紫色';

  @override
  String get themeMint => '薄荷';

  @override
  String get themePink => '粉色';

  @override
  String get modeDark => '深色';

  @override
  String get modeLight => '浅色';

  @override
  String get optClickKind => '点击音';

  @override
  String get optTheme => '主题';

  @override
  String get optColor => '颜色';

  @override
  String get optLanguage => '语言';

  @override
  String get optVolume => '点击音量';

  @override
  String get optBalance => '左右平衡';

  @override
  String get optFastBpm => '快速BPM';

  @override
  String get optBpmRange => 'BPM范围';

  @override
  String get optKeepScreen => '保持亮屏';

  @override
  String get optAudioMix => '音频混合';

  @override
  String get optBackground => '后台播放';

  @override
  String get optDnd => '勿扰模式';

  @override
  String get optSlideSnap => '滑动吸附';

  @override
  String get optVibeClick => '振动点击';

  @override
  String get optAdvanced => '高级设置';

  @override
  String get msgDndNeed => '需要勿扰模式访问权限。';

  @override
  String get msgDndUnsupported => '此设备不支持自动勿扰设置。';

  @override
  String get msgDndBusy => '勿扰权限页面已打开。';

  @override
  String get msgDndFail => '无法完成勿扰设置。';

  @override
  String get tapBpm => '轻点BPM';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get clickDigital1 => '數位 1';

  @override
  String get clickDigital2 => '數位 2';

  @override
  String get clickDigital3 => '數位 3';

  @override
  String get clickAnalog1 => '類比 1';

  @override
  String get clickAnalog2 => '類比 2';

  @override
  String get clickAnalog3 => '類比 3';

  @override
  String get themeSky => '天藍';

  @override
  String get themeBlue => '藍色';

  @override
  String get themeRed => '紅色';

  @override
  String get themeOrange => '橙色';

  @override
  String get themeYellow => '黃色';

  @override
  String get themeGreen => '綠色';

  @override
  String get themeLime => '萊姆';

  @override
  String get themePurple => '紫色';

  @override
  String get themeMint => '薄荷';

  @override
  String get themePink => '粉色';

  @override
  String get modeDark => '深色';

  @override
  String get modeLight => '淺色';

  @override
  String get optClickKind => '點擊音';

  @override
  String get optTheme => '主題';

  @override
  String get optColor => '顏色';

  @override
  String get optLanguage => '語言';

  @override
  String get optVolume => '點擊音量';

  @override
  String get optBalance => '左右平衡';

  @override
  String get optFastBpm => '快速BPM';

  @override
  String get optBpmRange => 'BPM範圍';

  @override
  String get optKeepScreen => '保持亮屏';

  @override
  String get optAudioMix => '音訊混合';

  @override
  String get optBackground => '背景播放';

  @override
  String get optDnd => '勿擾模式';

  @override
  String get optSlideSnap => '滑動吸附';

  @override
  String get optVibeClick => '振動點擊';

  @override
  String get optAdvanced => '進階設定';

  @override
  String get msgDndNeed => '需要勿擾模式存取權限。';

  @override
  String get msgDndUnsupported => '此裝置不支援自動勿擾設定。';

  @override
  String get msgDndBusy => '勿擾權限頁面已開啟。';

  @override
  String get msgDndFail => '無法完成勿擾設定。';

  @override
  String get tapBpm => '點按BPM';
}
