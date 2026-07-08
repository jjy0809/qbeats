part of 'main.dart';

extension _MainLayout on _MetronomeScreenState {

  Widget _buildRspScf(BuildContext context) {

    const cBg = Color(0xFF202020);
    final mq = MediaQuery.of(context);
    final sz = mq.size;
    return Scaffold(

      backgroundColor: cBg,
      body: SafeArea(
        bottom: false,

        child: AnimatedSwitcher(

          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, ani) {

            final fade = CurvedAnimation(
                parent: ani, curve: Curves.easeOutCubic);
            final slide =
                Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                    .animate(fade);
            return FadeTransition(
                opacity: fade,
                child: SlideTransition(
                    position: slide, child: child));
          },
          child: mq.orientation ==
                  Orientation.landscape
              ? _buildLnd(context, sz, const ValueKey('lnd'))
              : _buildPtr(
                  context, sz, const ValueKey('ptr')),
        ),
      ),
    );
  }

  Widget _buildPtr(BuildContext context, Size sz, Key key) {

    final cPri = _theme.color;
    const cTxt = Color(0xFFEEEEEE);
    const cPnl = Color(0xFF404040);
    final ov = cPri.withValues(alpha: 0.18);
    final pad = (sz.width * 0.06).clamp(18.0, 34.0);
    final gap = (sz.height * 0.018).clamp(12.0, 26.0);
    final scale = ((sz.width / 390.0) * 0.82)
        .clamp(0.72, 1.02);
    final r = Radius.circular(
        (sz.width * 0.07).clamp(26.0, 38.0));
    return Container(

      key: key,
      color: const Color(0xFF202020),
      child: Column(

        children: [

          SizedBox(height: gap),
          Expanded(

            child: LayoutBuilder(

              builder: (context, cs) {

                final beatW = sz.width - pad * 2;
                final cell = beatW / 4.0;
                final beatGap =
                    (cell * 0.22).clamp(16.0, 56.0);
                final beatH = cell * 2 + beatGap;
                final selH = (86.0 * scale)
                    .clamp(70.0, 96.0);
                final scGap = (cs.maxHeight * 0.022)
                    .clamp(12.0, 22.0);
                final bpmFs = (sz.width * 0.122)
                    .clamp(54.0, 88.0);
                final ic = (sz.width * 0.132)
                    .clamp(50.0, 74.0);
                final act = (sz.width * 0.235)
                    .clamp(90.0, 114.0);
                final thH =
                    (MediaQuery.of(context).size.shortestSide * 0.095)
                        .clamp(30.0, 42.0);
                final pnlTop = beatH + gap + selH + gap;
                final rise = beatH + gap;
                final mvTop =
                    (_showMemoryGrid && !_memCls)
                        ? -rise
                        : 0.0;
                return Stack(

                  children: [

                    AnimatedPositioned(

                      duration: const Duration(
                          milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      left: 0,
                      right: 0,
                      top: pnlTop + mvTop,
                      bottom: 0,
                      child: Container(

                        decoration: BoxDecoration(

                          color: cPnl,
                          borderRadius: BorderRadius.only(
                              topLeft: r,
                              topRight: r),
                        ),
                        child: LayoutBuilder(

                          builder: (context, bc) {

                            final pW = (sz.shortestSide * 0.28)
                                .clamp(108.0, 144.0);
                            final pH = (pW * 1.26)
                                .clamp(138.0, 198.0);
                            final stripH =
                                math.max(bpmFs, ic * 0.76);
                            final sldH = thH + 18.0;
                            final isMem =
                                _showMemoryGrid && !_memCls;
                            final memH = isMem
                                ? math.max(
                                    0.0,
                                    bc.maxHeight -
                                        stripH -
                                        sldH -
                                        act -
                                        scGap * 5.5)
                                : pH.toDouble();
                            final gapY = isMem
                                ? scGap
                                : math.max(
                                    8.0,
                                    (bc.maxHeight -
                                            memH -
                                            stripH -
                                            sldH -
                                            act) /
                                        5.5);
                            final botGap = gapY * 1.5;
                            return Padding(

                              padding: EdgeInsets.symmetric(
                                  horizontal: pad),
                              child: Column(

                                children: [

                                  SizedBox(height: gapY),
                                  SizedBox(

                                    height: memH,
                                    child: AnimatedSwitcher(

                                      duration: const Duration(
                                          milliseconds: 240),
                                      switchInCurve:
                                          Curves.easeOutCubic,
                                      switchOutCurve:
                                          Curves.easeInCubic,
                                      transitionBuilder:
                                          (child, ani) {

                                        return FadeTransition(
                                            opacity: ani,
                                            child: child);
                                      },
                                      child: isMem
                                          ? _buildMemGrid(
                                              sz,
                                              cPri,
                                              cTxt,
                                              ov,
                                              const ValueKey('ptr-mem'),
                                              scroll:
                                                  true)
                                          : Align(

                                              alignment:
                                                  Alignment.topCenter,
                                              child: _buildQuickPresets(
                                                  sz,
                                                  cPri,
                                                  cTxt,
                                                  ov,
                                                  const ValueKey('ptr-pre')),
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: gapY),
                                  _buildTempoStrip(
                                      cTxt, ov, bpmFs, ic),
                                  SizedBox(height: gapY),
                                  _buildTempoSlider(
                                      context, cPri, cTxt),
                                  SizedBox(height: gapY),
                                  _buildActRow(
                                      cTxt, ov, ic, act),
                                  SizedBox(height: botGap),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    AnimatedPositioned(

                      duration: const Duration(
                          milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      left: 0,
                      right: 0,
                      top: mvTop,
                      height: beatH,
                      child: Padding(

                        padding: EdgeInsets.symmetric(
                            horizontal: pad),
                        child: BeatCircles(

                          count: beatCount,
                          areaWidth:
                              beatW,
                          primary: cPri,
                          baseOverlay:
                              cPri.withValues(alpha: 0.16),
                          levels: beatLevels,
                          activeIndex:
                              _activeBeatIndex,
                          pulseToken:
                              _pulseToken,
                          onTapBeat:
                              _cycleBeatLevel,
                        ),
                      ),
                    ),
                    AnimatedPositioned(

                      duration: const Duration(
                          milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      left: 0,
                      right: 0,
                      top: beatH + gap + mvTop,
                      height: selH,
                      child: Padding(

                        padding: EdgeInsets.symmetric(
                            horizontal: pad),
                        child: Row(

                          children: [

                            Expanded(

                              child: Center(

                                child: PopupNumberSelect(

                                  value: beatCount,
                                  items: const [
                                    1,
                                    2,
                                    3,
                                    4,
                                    5,
                                    6,
                                    7,
                                    8
                                  ],
                                  scale: scale,
                                  color: cTxt,
                                  overlayColor: ov,
                                  onChanged: (v) => _setBeatCount(
                                      v,
                                      recordHistory: true),
                                ),
                              ),
                            ),
                            Expanded(

                              child: Center(

                                child: PopupNoteSelect(

                                  value: noteCount,
                                  items: const [
                                    1,
                                    2,
                                    3,
                                    4,
                                    5,
                                    6
                                  ],
                                  scale: scale,
                                  color: cTxt,
                                  overlayColor: ov,
                                  noteAsset:
                                      'assets/icons/light/note.png',
                                  onChanged: (v) => _setNoteCount(
                                      v,
                                      recordHistory: true),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLnd(BuildContext context, Size sz, Key key) {

    final cPri = _theme.color;
    const cTxt = Color(0xFFEEEEEE);
    const cPnl = Color(0xFF404040);
    final ov = cPri.withValues(alpha: 0.18);
    final pad = (sz.height * 0.05).clamp(16.0, 28.0);
    final gap = (sz.width * 0.018).clamp(14.0, 26.0);
    final vGap = (sz.width * 0.022).clamp(18.0, 34.0);
    final scale =
        (sz.height / 430.0).clamp(0.82, 1.14);
    final bpmFs =
        (sz.height * 0.18).clamp(58.0, 96.0);
    final ic = (sz.height * 0.16).clamp(64.0, 96.0);
    final act =
        (sz.height * 0.24).clamp(92.0, 126.0);
    return Container(

      key: key,
      color: const Color(0xFF202020),
      padding: EdgeInsets.all(pad),
      child: Row(

        children: [

          Expanded(

            flex: 1,
            child: Container(

              decoration: BoxDecoration(

                color: cPnl,
                borderRadius: BorderRadius.circular(
                    (sz.height * 0.06).clamp(22.0, 34.0)),
              ),
              padding: EdgeInsets.all(pad),
              child: Column(

                children: [

                  Row(

                    children: [

                      Expanded(

                        child: Center(

                          child: PopupNumberSelect(

                            value: beatCount,
                            items: const [
                              1,
                              2,
                              3,
                              4,
                              5,
                              6,
                              7,
                              8
                            ],
                            scale: scale,
                            color: cTxt,
                            overlayColor: ov,
                            onChanged: (v) => _setBeatCount(v,
                                recordHistory: true),
                          ),
                        ),
                      ),
                      Expanded(

                        child: Center(

                          child: PopupNoteSelect(

                            value: noteCount,
                            items: const [
                              1,
                              2,
                              3,
                              4,
                              5,
                              6
                            ],
                            scale: scale,
                            color: cTxt,
                            overlayColor: ov,
                            noteAsset:
                                'assets/icons/light/note.png',
                            onChanged: (v) => _setNoteCount(v,
                                recordHistory: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: gap),
                  Expanded(

                    child: _buildMemGrid(
                      sz,
                      cPri,
                      cTxt,
                      ov,
                      const ValueKey('lnd-mem'),
                      scroll: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: gap),
          Expanded(

            flex: 1,
            child: Container(

              decoration: BoxDecoration(

                color: cPnl,
                borderRadius: BorderRadius.circular(
                    (sz.height * 0.06).clamp(22.0, 34.0)),
              ),
              padding: EdgeInsets.symmetric(
                  horizontal: pad * 1.24,
                  vertical: pad * 1.12),
              child: Column(

                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [

                  _buildTempoStripLnd(
                      cTxt, ov, bpmFs, ic),
                  SizedBox(height: vGap * 1.18),
                  _buildTempoSlider(context, cPri, cTxt),
                  SizedBox(height: vGap * 1.18),
                  CircleActionButton(

                    diameter: act,
                    bg: _theme.color,
                    asset: isPlaying
                        ? 'assets/icons/light/stop.png'
                        : 'assets/icons/light/play.png',
                    iconSize: act * 0.54,
                    iconColor: cTxt,
                    overlayColor: ov,
                    onTap: _togglePlay,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPresets(
      Size sz, Color cPri, Color cTxt, Color ov, Key key) {

    final canUndo = _history.isNotEmpty;
    return LayoutBuilder(

      key: key,
      builder: (context, cs) {

        final gap = (cs.maxWidth * 0.028)
            .clamp(10.0, 18.0)
            .toDouble();
        final sideW = (cs.maxWidth * 0.16)
            .clamp(72.0, 102.0)
            .toDouble();
        final cardW = ((cs.maxWidth - sideW - gap * 3) / 3)
            .clamp(76.0, 156.0)
            .toDouble();
        final cardH = (cardW * 1.26)
            .clamp(132.0, 196.0)
            .toDouble();
        final sideH = ((cardH - gap) / 2)
            .clamp(60.0, 94.0)
            .toDouble();
        final topFs = (cardW * 0.33)
            .clamp(32.0, 50.0)
            .toDouble();
        final btmFs =
            (cardW * 0.18).clamp(18.0, 30.0).toDouble();
        final r = Radius.circular(
            (cardW * 0.22).clamp(20.0, 30.0));
        final sideR = Radius.circular(
            (sideW * 0.22).clamp(16.0, 24.0));
        final rowW = cardW * 3 + sideW + gap * 3;
        return Align(

          alignment: Alignment.topCenter,
          child: SizedBox(

            width: rowW.clamp(0.0, cs.maxWidth),
            height: cardH,
            child: Row(

              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                for (int i = 0; i < 3; i++) ...[

                  PresetButton(

                    width: cardW,
                    height: cardH,
                    bg: cPri.withValues(
                        alpha: _isPresetActive(memoryPresets[i])
                            ? 1.0
                            : 0.6),
                    radius: r,
                    top: memoryPresets[i].hasValue
                        ? '${memoryPresets[i].bpm}'
                        : '',
                    bottom: memoryPresets[i].hasValue
                        ? '${memoryPresets[i].beats} / ${memoryPresets[i].notes}'
                        : '',
                    topSize: topFs,
                    bottomSize: btmFs,
                    color: cTxt,
                    overlayColor: ov,
                    onTap: memoryPresets[i].hasValue
                        ? () => _applyPreset(memoryPresets[i],
                            recordHistory: true,
                            index: i)
                        : null,
                    onLongPress: () =>
                        _savePreset(i),
                  ),
                  if (i < 2) SizedBox(width: gap),
                ],
                SizedBox(width: gap),
                SizedBox(

                  width: sideW,
                  height: cardH,
                  child: Column(

                    children: [

                      SquareIconButton(

                        size: sideH,
                        radius: sideR,
                        bg: cPri,
                        asset:
                            'assets/icons/light/grid.png',
                        iconColor: cTxt,
                        overlayColor: ov,
                        onTap: _openMemoryGrid,
                      ),
                      SizedBox(height: gap),
                      GestureDetector(

                        onLongPressStart: canUndo
                            ? (_) => _stUndoHold()
                            : null,
                        onLongPressEnd: canUndo
                            ? (_) => _edUndoHold()
                            : null,
                        child: SquareIconButton(

                          size: sideH,
                          radius: sideR,
                          bg: cPri.withValues(
                              alpha: canUndo
                                  ? 1.0
                                  : 0.6),
                          asset:
                              'assets/icons/light/back.png',
                          iconColor: cTxt,
                          overlayColor: ov,
                          onTap: canUndo
                              ? _undo
                              : () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickPresetCards(
      Size sz, Color cPri, Color cTxt, Color ov, Key key) {

    return LayoutBuilder(

      key: key,
      builder: (context, cs) {

        final gap = (cs.maxWidth * 0.03)
            .clamp(10.0, 18.0)
            .toDouble();
        final cardW = ((cs.maxWidth - gap * 2) / 3)
            .clamp(76.0, 156.0)
            .toDouble();
        final cardH = (cardW * 1.26)
            .clamp(132.0, 196.0)
            .toDouble();
        final topFs = (cardW * 0.33)
            .clamp(32.0, 50.0)
            .toDouble();
        final btmFs =
            (cardW * 0.18).clamp(18.0, 30.0).toDouble();
        final r = Radius.circular(
            (cardW * 0.22).clamp(20.0, 30.0));
        return Align(

          alignment: Alignment.topCenter,
          child: SizedBox(

            width: (cardW * 3 + gap * 2)
                .clamp(0.0, cs.maxWidth),
            height: cardH,
            child: Row(

              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                for (int i = 0; i < 3; i++) ...[
                  PresetButton(

                    width: cardW,
                    height: cardH,
                    bg: cPri.withValues(
                        alpha: _isPresetActive(memoryPresets[i])
                            ? 1.0
                            : 0.6),
                    radius: r,
                    top: memoryPresets[i].hasValue
                        ? '${memoryPresets[i].bpm}'
                        : '',
                    bottom: memoryPresets[i].hasValue
                        ? '${memoryPresets[i].beats} / ${memoryPresets[i].notes}'
                        : '',
                    topSize: topFs,
                    bottomSize: btmFs,
                    color: cTxt,
                    overlayColor: ov,
                    onTap: memoryPresets[i].hasValue
                        ? () => _applyPreset(memoryPresets[i],
                            recordHistory: true,
                            index: i)
                        : null,
                    onLongPress: () =>
                        _savePreset(i),
                  ),
                  if (i < 2) SizedBox(width: gap),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemGrid(Size sz, Color cPri, Color cTxt, Color ov, Key key,
      {bool scroll = false}) {

    return LayoutBuilder(

      key: key,
      builder: (context, cs) {

        final cols = cs.maxWidth >= 900
            ? 5
            : cs.maxWidth >= 360
                ? 4
                : 3;
        final gap = (cs.maxWidth * 0.022)
            .clamp(8.0, 16.0)
            .toDouble();
        final itemW = ((cs.maxWidth - gap * (cols - 1)) / cols)
            .clamp(72.0, 180.0)
            .toDouble();
        final topFs = (itemW * 0.30)
            .clamp(24.0, 41.0)
            .toDouble();
        final btmFs = (itemW * 0.17)
            .clamp(14.5, 24.0)
            .toDouble();
        final r = Radius.circular(
            (itemW * 0.22).clamp(14.0, 24.0));
        return GridView.builder(

          padding: EdgeInsets.only(
              top: scroll ? 4.0 : 0.0),
          shrinkWrap: !scroll,
          physics: scroll
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(

            crossAxisCount: cols,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            childAspectRatio: 0.92,
          ),
          itemCount: 40,
          itemBuilder: (context, i) {

            if (i == 39) {
              const cDel = Color(0xFFFF7048);
              return Listener(
                onPointerDown: (_) => _stDeletePresetHold(),
                onPointerUp: (_) =>
                    _edDeletePresetHold(allowTap: true),
                onPointerCancel: (_) =>
                    _edDeletePresetHold(allowTap: false),
                child: PresetIconButton(
                  bg: cDel.withValues(alpha: 0.6),
                  radius: r,
                  asset: 'assets/icons/light/bin.png',
                  iconColor: cTxt,
                  overlayColor: cDel.withValues(alpha: 0.18),
                  iconSize: itemW * 0.34,
                  onTap: () {},
                ),
              );
            }
            final p = memoryPresets[i];
            return PresetButton(

              width: double.infinity,
              height: double.infinity,
              bg: cPri.withValues(
                  alpha: _isPresetActive(p)
                      ? 1.0
                      : 0.6),
              radius: r,
              top: p.hasValue ? '${p.bpm}' : '',
              bottom: p.hasValue
                  ? '${p.beats} / ${p.notes}'
                  : '',
              topSize: topFs,
              bottomSize: btmFs,
              color: cTxt,
              overlayColor: ov,
              hint: p.hasValue ? null : '+',
              hintSize: topFs * 0.86,
              hintColor: cTxt.withValues(alpha: 0.20),
              onTap: p.hasValue
                  ? () =>
                      _applyPreset(p,
                          recordHistory: true,
                          index: i)
                  : null,
              onLongPress: () => _savePreset(i),
            );
          },
        );
      },
    );
  }

  Widget _buildTempoStrip(Color cTxt, Color ov, double bpmFs, double ic) {

    final arIc = ic * 0.64;
    return Row(

      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        Transform(

          alignment: Alignment.center,
          transform: Matrix4.identity()..rotateY(math.pi),
          child: IconAssetButton(

            asset: 'assets/icons/light/arrows.png',
            size: arIc,
            color: cTxt,
            overlayColor: ov,
            onTap: () => _changeBpmBy(-_fastBpmStep),
            onLongPress: () => _stBpmHold(-_fastBpmStep),
            onLongPressEnd: _edBpmHold,
          ),
        ),
        SizedBox(width: ic * 0.065),
        IconAssetButton(

          asset: 'assets/icons/light/minus.png',
          size: ic * 0.76,
          color: cTxt,
          overlayColor: ov,
          onTap: () => _changeBpmBy(-1),
          onLongPress: () => _stBpmHold(-1),
          onLongPressEnd: _edBpmHold,
        ),
        SizedBox(width: ic * 0.108),
        RollingBpmText(

          value: bpm.round(),
          previous: _lastBpmInt,
          fontSize: bpmFs,
          color: cTxt,
        ),
        SizedBox(width: ic * 0.108),
        IconAssetButton(

          asset: 'assets/icons/light/plus.png',
          size: ic * 0.76,
          color: cTxt,
          overlayColor: ov,
          onTap: () => _changeBpmBy(1),
          onLongPress: () => _stBpmHold(1),
          onLongPressEnd: _edBpmHold,
        ),
        SizedBox(width: ic * 0.065),
        IconAssetButton(

          asset: 'assets/icons/light/arrows.png',
          size: arIc,
          color: cTxt,
          overlayColor: ov,
          onTap: () => _changeBpmBy(_fastBpmStep),
          onLongPress: () => _stBpmHold(_fastBpmStep),
          onLongPressEnd: _edBpmHold,
        ),
      ],
    );
  }

  Widget _buildTempoStripLnd(
      Color cTxt, Color ov, double bpmFs, double ic) {

    return Row(

      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        IconAssetButton(

          asset: 'assets/icons/light/minus.png',
          size: ic * 0.76,
          color: cTxt,
          overlayColor: ov,
          onTap: () => _changeBpmBy(-1),
          onLongPress: () => _stBpmHold(-1),
          onLongPressEnd: _edBpmHold,
        ),
        SizedBox(width: ic * 0.17),
        RollingBpmText(

          value: bpm.round(),
          previous: _lastBpmInt,
          fontSize: bpmFs,
          color: cTxt,
        ),
        SizedBox(width: ic * 0.17),
        IconAssetButton(

          asset: 'assets/icons/light/plus.png',
          size: ic * 0.76,
          color: cTxt,
          overlayColor: ov,
          onTap: () => _changeBpmBy(1),
          onLongPress: () => _stBpmHold(1),
          onLongPressEnd: _edBpmHold,
        ),
      ],
    );
  }

  Widget _buildTempoSlider(BuildContext context, Color cPri, Color cTxt) {

    final sh = MediaQuery.of(context).size.shortestSide;
    final thW = (sh * 0.055).clamp(18.0, 24.0);
    final thH = (sh * 0.095).clamp(30.0, 42.0);
    final ovR = (thH * 0.46).clamp(14.0, 20.0);

    return SliderTheme(

      data: SliderTheme.of(context).copyWith(

        trackHeight: 8,
        activeTrackColor: cPri,
        inactiveTrackColor: cTxt,
        thumbColor: cPri,
        overlayColor: cPri.withValues(alpha: 0.22),
        thumbShape: TallOvalThumbShape(
            width: thW, height: thH),
        overlayShape: RoundSliderOverlayShape(
            overlayRadius: ovR),
      ),
      child: Slider(

        min: _MetronomeScreenState._bpmMin,
        max: _MetronomeScreenState._bpmMax,
        value: bpm
            .clamp(_MetronomeScreenState._bpmMin, _MetronomeScreenState._bpmMax)
            .toDouble(),
        onChanged: (v) {

          _previewBpm(v);
        },
        onChangeEnd: (v) =>
            _setBpm(v, recordHistory: true),
      ),
    );
  }

  Widget _buildActRow(Color cTxt, Color ov, double ic, double act) {

    return Row(

      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        IconAssetButton(

          asset: 'assets/icons/light/setting.png',
          size: ic,
          color: cTxt,
          overlayColor: ov,
          onTap: _openSettingsSheet,
        ),
        CircleActionButton(

          diameter: act,
          bg: _theme.color,
          asset: isPlaying
              ? 'assets/icons/light/stop.png'
              : 'assets/icons/light/play.png',
          iconSize: act * 0.54,
          iconColor: cTxt,
          overlayColor: ov,
          onTap: _togglePlay,
        ),
        IconAssetButton(

          asset: _showMemoryGrid
              ? 'assets/icons/light/exit.png'
              : 'assets/icons/light/hand.png',
          size: ic,
          color: cTxt,
          overlayColor: ov,
          onTap: _showMemoryGrid
              ? _closeMemoryGrid
              : _openTapTempoSheet,
        ),
      ],
    );
  }
}

Future<T?> _showSlidePopupMenu<T>({

  required BuildContext context,
  required Rect rect,
  required Size overlaySize,
  required List<T> items,
  required T value,
  required double itemHeight,
  required TextStyle menuTextStyle,
  required Color menuBg,
  required double menuMinWidth,
  required double menuMaxWidth,
  double? menuMaxHeight,
  required Widget Function(BuildContext, T) buildItem,
}) async {

  final menuW = rect.width
      .clamp(menuMinWidth, menuMaxWidth)
      .toDouble();
  final rawH = items.length * itemHeight + 12;
  final capH = math.min(rawH, menuMaxHeight ?? rawH);
  final belowTop = rect.bottom + 4;
  final aboveSpace = rect.top - 8;
  final belowSpace = overlaySize.height - belowTop - 8;
  final showBelow = belowSpace >= capH || belowSpace >= aboveSpace;
  final maxSpace = math.max(0.0, showBelow ? belowSpace : aboveSpace);
  final menuH = math.min(capH, maxSpace);
  final left = (rect.left + rect.width - menuW)
      .clamp(8.0, overlaySize.width - menuW - 8.0);
  final rawTop = showBelow
      ? belowTop
      : rect.top - menuH - 8;
  final top = rawTop
      .clamp(8.0, overlaySize.height - menuH - 8.0);
  return showGeneralDialog<T>(

    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context)
        .modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.14),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, ani, sec) {

      return Stack(

        children: [

          Positioned(

            left: left,
            top: top,
            width: menuW,
            height: menuH,
            child: _SlideMenu<T>(

              items: items,
              value: value,
              itemHeight: itemHeight,
              menuHeight: menuH,
              menuTextStyle: menuTextStyle,
              menuBg: menuBg,
              buildItem: buildItem,
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, ani, sec, child) {

      final fade = CurvedAnimation(
          parent: ani, curve: Curves.easeOutCubic);
      final slide =
          Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(fade);
      return FadeTransition(
          opacity: fade,
          child: SlideTransition(
              position: slide, child: child));
    },
  );
}

class _SlideMenu<T> extends StatelessWidget {

  final List<T> items;
  final T value;
  final double itemHeight;
  final double menuHeight;
  final TextStyle menuTextStyle;
  final Color menuBg;
  final Widget Function(BuildContext, T) buildItem;

  const _SlideMenu({

    required this.items,
    required this.value,
    required this.itemHeight,
    required this.menuHeight,
    required this.menuTextStyle,
    required this.menuBg,
    required this.buildItem,
  });

  @override
  Widget build(BuildContext context) {

    return Material(

      color: menuBg,
      elevation: 14,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: menuHeight,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 6),
          physics: const ClampingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final e = items[i];
            final sel = e == value;
            return InkWell(
              onTap: () => Navigator.of(context).pop(e),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: itemHeight,
                margin: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DefaultTextStyle(
                  style: menuTextStyle,
                  child: Center(
                      child: buildItem(context, e)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
