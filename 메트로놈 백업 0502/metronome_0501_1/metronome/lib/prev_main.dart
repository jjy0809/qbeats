import 'dart:math' as math;
import 'package:flutter/material.dart';

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

class _MetronomeScreenState extends State<MetronomeScreen> {
  double bpm = 140;
  int beatCount = 8;
  int noteCount = 1;
  bool isPlaying = false;

  final List<int> beatLevels = List<int>.filled(8, 1);
  int _lastBpmInt = 140;

  static const _bpmMin = 40.0;
  static const _bpmMax = 260.0;

  void _setBeatCount(int v) {
    final prev = beatCount;
    setState(() {
      beatCount = v.clamp(1, 8);
      if (beatCount > prev) {
        for (int i = prev; i < beatCount; i++) {
          beatLevels[i] = 1;
        }
      }
    });
  }

  void _setNoteCount(int v) {
    setState(() => noteCount = v.clamp(1, 6));
  }

  void _cycleBeatLevel(int index) {
    setState(() {
      final cur = beatLevels[index];
      beatLevels[index] = (cur % 3) + 1;
    });
  }

  void _setBpm(double v) {
    final next = v.clamp(_bpmMin, _bpmMax);
    setState(() {
      _lastBpmInt = bpm.round();
      bpm = next;
    });
  }

  void _changeBpmBy(int delta) => _setBpm(bpm + delta);

  @override
  Widget build(BuildContext context) {
    const cPrimary = Color(0xFF18A8F1);
    const cPanel = Color(0xFF404040);
    const cBg = Color(0xFF202020);
    const cText = Color(0xFFEEEEEE);

    final pressOverlay = cText.withValues(alpha: 0.10);

    const designW = 1080.0;
    const designH = 2280.0;

    final bpmInt = bpm.round();

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
                        // 상단 비트 원 버튼
                        Padding(
                          padding: const EdgeInsets.only(left: 70, right: 70, top: 60),
                          child: BeatCircles(
                            count: beatCount,
                            areaWidth: designW - 140,
                            primary: cPrimary,
                            baseOverlay: cPrimary.withValues(alpha: 0.16),
                            levels: beatLevels,
                            onTapBeat: _cycleBeatLevel,
                          ),
                        ),

                        // 드롭박스 위치
                        const SizedBox(height: 104),

                        // 드롭박스(비트/음표)
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
                                  onChanged: _setBeatCount,
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
                                  onChanged: _setNoteCount,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 패널 상단 여백
                        const SizedBox(height: 34),

                        // 하단 패널
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: designW,
                              height: 1500,
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
                                  // 프리셋 버튼 + 우측 버튼 2개
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
                                              bg: cPrimary,
                                              radius: const Radius.circular(54),
                                              top: '140',
                                              bottom: '8',
                                              topSize: 86,
                                              bottomSize: 76,
                                              color: cText,
                                              overlayColor: pressOverlay,
                                              onTap: () {},
                                            ),
                                            const SizedBox(width: 35),
                                            PresetButton(
                                              width: 230,
                                              height: 325,
                                              bg: cPrimary.withValues(alpha: 0.6),
                                              radius: const Radius.circular(54),
                                              top: '80',
                                              bottom: '4',
                                              topSize: 86,
                                              bottomSize: 76,
                                              color: cText,
                                              overlayColor: pressOverlay,
                                              onTap: () {},
                                            ),
                                            const SizedBox(width: 35),
                                            PresetButton(
                                              width: 230,
                                              height: 325,
                                              bg: cPrimary.withValues(alpha: 0.6),
                                              radius: const Radius.circular(54),
                                              top: '183',
                                              bottom: '4',
                                              topSize: 86,
                                              bottomSize: 76,
                                              color: cText,
                                              overlayColor: pressOverlay,
                                              onTap: () {},
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
                                            bg: cPrimary.withValues(alpha: 0.6),
                                            asset: 'assets/icons/light/grid.png',
                                            iconColor: cText,
                                            overlayColor: pressOverlay,
                                            onTap: () {},
                                          ),
                                          const SizedBox(height: 25),
                                          SquareIconButton(
                                            size: 150,
                                            radius: const Radius.circular(34),
                                            bg: cPrimary.withValues(alpha: 0.6),
                                            asset: 'assets/icons/light/back.png',
                                            iconColor: cText,
                                            overlayColor: pressOverlay,
                                            onTap: () {},
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // BPM 영역 위치
                                  const SizedBox(height: 220),

                                  // BPM 조절 버튼
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

                                  // BPM 슬라이더
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
                                        onChanged: _setBpm,
                                      ),
                                    ),
                                  ),

                                  // 하단 버튼 간격
                                  const SizedBox(height: 90),

                                  // 하단 3 버튼
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconAssetButton(
                                        asset: 'assets/icons/light/setting.png',
                                        size: 120,
                                        color: cText,
                                        overlayColor: pressOverlay,
                                        onTap: () {},
                                      ),
                                      CircleActionButton(
                                        diameter: 220,
                                        bg: cPrimary,
                                        asset: isPlaying
                                            ? 'assets/icons/light/stop.png'
                                            : 'assets/icons/light/play.png',
                                        iconSize: 120,
                                        iconColor: cText,
                                        overlayColor: pressOverlay,
                                        onTap: () => setState(() => isPlaying = !isPlaying),
                                      ),
                                      IconAssetButton(
                                        asset: 'assets/icons/light/hand.png',
                                        size: 120,
                                        color: cText,
                                        overlayColor: pressOverlay,
                                        onTap: () {},
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

// 상단 비트 원 버튼
class BeatCircles extends StatelessWidget {
  final int count;
  final double areaWidth;
  final Color primary;
  final Color baseOverlay;
  final List<int> levels;
  final void Function(int index) onTapBeat;

  const BeatCircles({
    super.key,
    required this.count,
    required this.areaWidth,
    required this.primary,
    required this.baseOverlay,
    required this.levels,
    required this.onTapBeat,
  });

  @override
  Widget build(BuildContext context) {
    final cell = areaWidth / 4.0;
    final bigD = cell * 0.89;
    final smallD = cell * 0.66;
    final tinyD = cell * 0.56;
    const gap = 70.0;

    Widget beatCircle(int index, bool visible) {
      if (!visible) return SizedBox(width: cell, height: cell);

      final level = levels[index];
      final d = (level == 1) ? bigD : (level == 2) ? smallD : tinyD;

      final double alpha = (level == 1) ? 0.9 : (level == 2) ? 0.7 : 0.4;
      final color = primary.withValues(alpha: alpha);

      return SizedBox(
        width: cell,
        height: cell,
        child: Center(
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
                  if (states.contains(WidgetState.hovered)) {
                    return baseOverlay.withValues(alpha: 0.08);
                  }
                  return Colors.transparent;
                }),
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

    if (count <= 4) {
      return SizedBox(width: areaWidth, height: cell, child: Row(children: row1));
    }

    return SizedBox(
      width: areaWidth,
      height: cell * 2 + gap,
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

// 드롭박스(숫자 1~8)
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
      menuBg: const Color(0xFF404040),
      anchorWidth: 160,
      menuMinWidth: 140,
      menuMaxWidth: 160,
      buildSelected: (ctx, v) => Center(child: Text('$v', style: selectedStyle)),
      buildItem: (ctx, v) => Center(child: Text('$v', style: menuStyle)),
      onChanged: onChanged,
    );
  }
}

// 드롭박스(음표 + 숫자 1~6)
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
      menuBg: const Color(0xFF404040),
      anchorWidth: 230,
      menuMinWidth: 180,
      menuMaxWidth: 220,
      buildSelected: (ctx, v) => Center(child: row(noteSize: noteSelected, ts: selectedNumStyle, v: v)),
      buildItem: (ctx, v) => Center(child: row(noteSize: noteMenu, ts: menuStyle, v: v)),
      onChanged: onChanged,
    );
  }
}

// 드롭박스 버튼(커스텀)
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;

          final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
          final pos = box.localToGlobal(Offset.zero, ancestor: overlay);
          final rect = Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height);

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
              const Icon(Icons.arrow_drop_down, size: 80, color: Color(0xFFEEEEEE)),
            ],
          ),
        ),
      ),
    );
  }
}

// 프리셋 버튼
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

// 우측 정사각형 아이콘 버튼
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

// 아이콘 버튼
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

// 중앙 원 버튼(재생/정지)
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

// BPM 숫자 애니메이션(자리수별)
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

    final digitHVisible = value >= 100 || previous >= 100;
    final digitTVisible = value >= 10 || previous >= 10;

    final w = fontSize * 0.78;
    final hgt = fontSize * 1.05;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DigitSlot(
          visible: digitHVisible,
          width: w,
          height: hgt,
          fontSize: fontSize,
          color: color,
          oldDigit: oldH,
          newDigit: newH,
          increasing: inc,
        ),
        DigitSlot(
          visible: digitTVisible,
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

// BPM 자리 슬롯
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

// BPM 숫자 릴(해당 자리만)
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

// 슬라이더 손잡이(세로 타원)
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