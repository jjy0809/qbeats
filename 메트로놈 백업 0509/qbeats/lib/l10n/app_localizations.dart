import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
  ];

  /// No description provided for @clickDigital1.
  ///
  /// In ko, this message translates to:
  /// **'디지털 1'**
  String get clickDigital1;

  /// No description provided for @clickDigital2.
  ///
  /// In ko, this message translates to:
  /// **'디지털 2'**
  String get clickDigital2;

  /// No description provided for @clickDigital3.
  ///
  /// In ko, this message translates to:
  /// **'디지털 3'**
  String get clickDigital3;

  /// No description provided for @clickAnalog1.
  ///
  /// In ko, this message translates to:
  /// **'아날로그 1'**
  String get clickAnalog1;

  /// No description provided for @clickAnalog2.
  ///
  /// In ko, this message translates to:
  /// **'아날로그 2'**
  String get clickAnalog2;

  /// No description provided for @clickAnalog3.
  ///
  /// In ko, this message translates to:
  /// **'아날로그 3'**
  String get clickAnalog3;

  /// No description provided for @themeSky.
  ///
  /// In ko, this message translates to:
  /// **'하늘'**
  String get themeSky;

  /// No description provided for @themeBlue.
  ///
  /// In ko, this message translates to:
  /// **'파랑'**
  String get themeBlue;

  /// No description provided for @themeRed.
  ///
  /// In ko, this message translates to:
  /// **'빨강'**
  String get themeRed;

  /// No description provided for @themeOrange.
  ///
  /// In ko, this message translates to:
  /// **'주황'**
  String get themeOrange;

  /// No description provided for @themeYellow.
  ///
  /// In ko, this message translates to:
  /// **'노랑'**
  String get themeYellow;

  /// No description provided for @themeGreen.
  ///
  /// In ko, this message translates to:
  /// **'초록'**
  String get themeGreen;

  /// No description provided for @themeLime.
  ///
  /// In ko, this message translates to:
  /// **'연두'**
  String get themeLime;

  /// No description provided for @themePurple.
  ///
  /// In ko, this message translates to:
  /// **'보라'**
  String get themePurple;

  /// No description provided for @themeMint.
  ///
  /// In ko, this message translates to:
  /// **'민트'**
  String get themeMint;

  /// No description provided for @themePink.
  ///
  /// In ko, this message translates to:
  /// **'핑크'**
  String get themePink;

  /// No description provided for @modeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get modeDark;

  /// No description provided for @modeLight.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get modeLight;

  /// No description provided for @optClickKind.
  ///
  /// In ko, this message translates to:
  /// **'클릭 종류'**
  String get optClickKind;

  /// No description provided for @optTheme.
  ///
  /// In ko, this message translates to:
  /// **'테마'**
  String get optTheme;

  /// No description provided for @optColor.
  ///
  /// In ko, this message translates to:
  /// **'색상'**
  String get optColor;

  /// No description provided for @optLanguage.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get optLanguage;

  /// No description provided for @optVolume.
  ///
  /// In ko, this message translates to:
  /// **'클릭 음량'**
  String get optVolume;

  /// No description provided for @optBalance.
  ///
  /// In ko, this message translates to:
  /// **'좌우 소리 균형'**
  String get optBalance;

  /// No description provided for @optFastBpm.
  ///
  /// In ko, this message translates to:
  /// **'빠른 BPM 조정'**
  String get optFastBpm;

  /// No description provided for @optBpmRange.
  ///
  /// In ko, this message translates to:
  /// **'BPM 범위'**
  String get optBpmRange;

  /// No description provided for @optKeepScreen.
  ///
  /// In ko, this message translates to:
  /// **'화면 유지'**
  String get optKeepScreen;

  /// No description provided for @optAudioMix.
  ///
  /// In ko, this message translates to:
  /// **'소리 혼합'**
  String get optAudioMix;

  /// No description provided for @optBackground.
  ///
  /// In ko, this message translates to:
  /// **'백그라운드'**
  String get optBackground;

  /// No description provided for @optDnd.
  ///
  /// In ko, this message translates to:
  /// **'방해금지'**
  String get optDnd;

  /// No description provided for @optSlideSnap.
  ///
  /// In ko, this message translates to:
  /// **'슬라이드 스냅'**
  String get optSlideSnap;

  /// No description provided for @optVibeClick.
  ///
  /// In ko, this message translates to:
  /// **'진동 클릭'**
  String get optVibeClick;

  /// No description provided for @optAdvanced.
  ///
  /// In ko, this message translates to:
  /// **'고급 설정'**
  String get optAdvanced;

  /// No description provided for @msgDndNeed.
  ///
  /// In ko, this message translates to:
  /// **'방해금지 접근 권한이 필요합니다.'**
  String get msgDndNeed;

  /// No description provided for @msgDndUnsupported.
  ///
  /// In ko, this message translates to:
  /// **'이 기기에서는 방해금지 자동 설정을 지원하지 않습니다.'**
  String get msgDndUnsupported;

  /// No description provided for @msgDndBusy.
  ///
  /// In ko, this message translates to:
  /// **'방해금지 권한 화면이 이미 열려 있습니다.'**
  String get msgDndBusy;

  /// No description provided for @msgDndFail.
  ///
  /// In ko, this message translates to:
  /// **'방해금지 설정을 완료하지 못했습니다.'**
  String get msgDndFail;

  /// No description provided for @tapBpm.
  ///
  /// In ko, this message translates to:
  /// **'탭 BPM'**
  String get tapBpm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
