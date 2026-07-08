part of 'main.dart';

extension _MainLayout on _MetronomeScreenState {
  Widget _buildRspScf(BuildContext context) {
    final cBg = _bgColor;
    final mq = MediaQuery.of(context);
    final sz = mq.size;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _sysUiStyle,
      child: Scaffold(
        backgroundColor: cBg,
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, ani) {
              final fade =
                  CurvedAnimation(parent: ani, curve: Curves.easeOutCubic);
              final slide =
                  Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                      .animate(fade);
              return FadeTransition(
                  opacity: fade,
                  child: SlideTransition(position: slide, child: child));
            },
            child: mq.orientation == Orientation.landscape
                ? _buildLnd(context, sz, const ValueKey('lnd'))
                : _buildPtr(context, sz, const ValueKey('ptr')),
          ),
        ),
      ),
    );
  }

  Widget _buildPtr(BuildContext context, Size sz, Key key) {
    final cPri = _theme.color;
    final cTxt = _textColor;
    final cPnl = _panelColor;
    final ov = cPri.withValues(alpha: 0.18);
    final pad = (sz.width * 0.06).clamp(18.0, 34.0);
    final gap = (sz.height * 0.018).clamp(12.0, 26.0);
    final scale = ((sz.width / 390.0) * 0.82).clamp(0.72, 1.02);
    final r = Radius.circular((sz.width * 0.07).clamp(26.0, 38.0));
    return Container(
      key: key,
      color: _bgColor,
      child: Column(
        children: [
          SizedBox(height: gap),
          Expanded(
            child: LayoutBuilder(
              builder: (context, cs) {
                final selH = (86.0 * scale).clamp(70.0, 96.0);
                final scGap = (cs.maxHeight * 0.022).clamp(12.0, 22.0);
                final bpmFs = (sz.width * 0.122).clamp(54.0, 88.0);
                final ic = (sz.width * 0.132).clamp(50.0, 74.0);
                final act = (sz.width * 0.235).clamp(90.0, 114.0);
                final thH = (MediaQuery.of(context).size.shortestSide * 0.095)
                    .clamp(30.0, 42.0);
                final pnlLift = (sz.height * 0.022).clamp(14.0, 22.0);
                final rawBeatW =
                    (sz.width - pad * 2).clamp(0.0, double.infinity);
                final topGapEst = (scGap * 1.02).clamp(12.0, 22.0);
                final memGapEst = (scGap * 2.45).clamp(28.0, 46.0);
                final lowGapEst = (scGap * 1.12).clamp(12.0, 24.0);
                final botGapEst = (scGap * 2.75).clamp(28.0, 52.0);
                final stripHEst = math.max(bpmFs, ic * 0.76);
                final sldHEst = thH + 18.0;
                final minMemHEst = 120.0;
                final minPnlH = topGapEst +
                    minMemHEst +
                    memGapEst +
                    stripHEst +
                    lowGapEst +
                    sldHEst +
                    lowGapEst +
                    act +
                    botGapEst;
                final maxPnlTop = math.max(0.0, cs.maxHeight - minPnlH);
                final maxBeatH =
                    math.max(120.0, maxPnlTop + pnlLift - selH - gap * 2);
                double fitBeatW(double rawW, double maxH) {
                  double lo = 0.0;
                  double hi = rawW;
                  for (int i = 0; i < 16; i++) {
                    final mid = (lo + hi) / 2;
                    final midCell = mid / 4.0;
                    final midGap = (midCell * 0.22).clamp(16.0, 56.0);
                    final midH = midCell * 2 + midGap;
                    if (midH <= maxH) {
                      lo = mid;
                    } else {
                      hi = mid;
                    }
                  }
                  return lo;
                }

                final beatW = math.min(
                  rawBeatW,
                  math.max(220.0, fitBeatW(rawBeatW, maxBeatH)),
                );
                final cell = beatW / 4.0;
                final beatGap = (cell * 0.22).clamp(16.0, 56.0);
                final beatH = cell * 2 + beatGap;
                final pnlTop = beatH + gap + selH + gap - pnlLift;
                final rise = beatH + gap;
                final mvTop = _showMemoryGrid ? -rise : 0.0;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      left: 0,
                      right: 0,
                      top: pnlTop + mvTop,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cPnl,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: _isLight ? 0.10 : 0.26),
                              blurRadius: 28,
                              spreadRadius: 1,
                              offset: const Offset(0, -4),
                            ),
                          ],
                          border: Border(
                            top: BorderSide(
                              color: cTxt.withValues(
                                  alpha: _isLight ? 0.10 : 0.05),
                            ),
                          ),
                          borderRadius:
                              BorderRadius.only(topLeft: r, topRight: r),
                        ),
                        child: LayoutBuilder(
                          builder: (context, bc) {
                            final pW =
                                (sz.shortestSide * 0.28).clamp(108.0, 144.0);
                            final pH = (pW * 1.26).clamp(138.0, 198.0);
                            final stripH = math.max(bpmFs, ic * 0.76);
                            final sldH = thH + 18.0;
                            final isMem = _showMemoryGrid;
                            final topGap = (scGap * 1.02).clamp(12.0, 22.0);
                            final memGap = (scGap * 2.45).clamp(28.0, 46.0);
                            final lowGap = (scGap * 1.12).clamp(12.0, 24.0);
                            final botGap = (scGap * 2.75).clamp(28.0, 52.0);
                            final adGap = math.max(
                                memGap,
                                (_bannerSize?.height.toDouble() ??
                                        (sz.shortestSide * 0.14)
                                            .clamp(48.0, 86.0))
                                    .toDouble());
                            final midGap = isMem ? memGap : adGap;
                            final ctrlH =
                                stripH + lowGap + sldH + lowGap + act + botGap;
                            final memH = math.max(isMem ? 120.0 : pH.toDouble(),
                                bc.maxHeight - topGap - midGap - ctrlH);
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: pad),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: topGap,
                                    height: memH,
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 240),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, ani) {
                                        final fade = CurvedAnimation(
                                          parent: ani,
                                          curve: Curves.easeOutCubic,
                                        );
                                        return FadeTransition(
                                          opacity: fade,
                                          child: child,
                                        );
                                      },
                                      child: isMem
                                          ? _buildMemGrid(sz, cPri, cTxt, ov,
                                              const ValueKey('ptr-mem'),
                                              scroll: true)
                                          : Align(
                                              alignment: Alignment.bottomCenter,
                                              child: _buildQuickPresets(
                                                  sz,
                                                  cPri,
                                                  cTxt,
                                                  ov,
                                                  const ValueKey('ptr-pre')),
                                            ),
                                    ),
                                  ),
                                  if (!isMem)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: topGap + memH,
                                      height: midGap,
                                      child: _buildBannerSlot(context,
                                          height: midGap),
                                    ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom:
                                        botGap + act + lowGap + sldH + lowGap,
                                    child:
                                        _buildTempoStrip(cTxt, ov, bpmFs, ic),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: botGap + act + lowGap,
                                    height: sldH,
                                    child:
                                        _buildTempoSlider(context, cPri, cTxt),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: botGap,
                                    height: act,
                                    child: _buildActRow(cTxt, ov, ic, act),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      left: 0,
                      right: 0,
                      top: mvTop,
                      height: beatH,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: BeatCircles(
                            count: beatCount,
                            areaWidth: beatW,
                            primary: cPri,
                            baseOverlay: cPri.withValues(alpha: 0.16),
                            levels: beatLevels,
                            activeIndex: _activeBeatIndex,
                            pulseToken: _pulseToken,
                            pulseAmp: _pulseAmp,
                            waveToken: _waveToken,
                            waveIndex: _waveIdx,
                            waveAmp: _waveAmp,
                            waveMs: _waveMs,
                            onTapBeat: _cycleBeatLevel,
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      left: 0,
                      right: 0,
                      top: beatH + gap + mvTop,
                      height: selH,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: pad),
                        child: Row(
                          children: [
                            Expanded(
                              child: Center(
                                child: PopupNumberSelect(
                                  value: beatCount,
                                  items: const [1, 2, 3, 4, 5, 6, 7, 8],
                                  scale: scale,
                                  color: cTxt,
                                  overlayColor: ov,
                                  menuBg: _fieldBgColor,
                                  onChanged: (v) =>
                                      _setBeatCount(v, recordHistory: true),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: PopupNoteSelect(
                                  value: noteCount,
                                  items: const [1, 2, 3, 4, 6, _noteShf],
                                  scale: scale,
                                  color: cTxt,
                                  overlayColor: ov,
                                  menuBg: _fieldBgColor,
                                  noteAsset: _ic('note'),
                                  labelOf: (v) => _noteLbl(v),
                                  onChanged: (v) =>
                                      _setNoteCount(v, recordHistory: true),
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
    final cTxt = _textColor;
    final cPnl = _panelColor;
    final ov = cPri.withValues(alpha: 0.18);
    final pad = (sz.height * 0.05).clamp(16.0, 28.0);
    final gap = (sz.width * 0.018).clamp(14.0, 26.0);
    final vGap = (sz.width * 0.022).clamp(18.0, 34.0);
    final scale = (sz.height / 430.0).clamp(0.82, 1.14);
    final bpmFs = (sz.height * 0.18).clamp(58.0, 96.0);
    final ic = (sz.height * 0.16).clamp(64.0, 96.0);
    final act = (sz.height * 0.24).clamp(92.0, 126.0);
    return Container(
      key: key,
      color: _bgColor,
      padding: EdgeInsets.all(pad),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                color: cPnl,
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: _isLight ? 0.10 : 0.24),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: cTxt.withValues(alpha: _isLight ? 0.08 : 0.04),
                ),
                borderRadius:
                    BorderRadius.circular((sz.height * 0.06).clamp(22.0, 34.0)),
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
                            items: const [1, 2, 3, 4, 5, 6, 7, 8],
                            scale: scale,
                            color: cTxt,
                            overlayColor: ov,
                            menuBg: _fieldBgColor,
                            onChanged: (v) =>
                                _setBeatCount(v, recordHistory: true),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: PopupNoteSelect(
                            value: noteCount,
                            items: const [1, 2, 3, 4, 6, _noteShf],
                            scale: scale,
                            color: cTxt,
                            overlayColor: ov,
                            menuBg: _fieldBgColor,
                            noteAsset: _ic('note'),
                            labelOf: (v) => _noteLbl(v),
                            onChanged: (v) =>
                                _setNoteCount(v, recordHistory: true),
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
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: _isLight ? 0.10 : 0.24),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: cTxt.withValues(alpha: _isLight ? 0.08 : 0.04),
                ),
                borderRadius:
                    BorderRadius.circular((sz.height * 0.06).clamp(22.0, 34.0)),
              ),
              padding: EdgeInsets.symmetric(
                  horizontal: pad * 1.24, vertical: pad * 1.12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTempoStripLnd(cTxt, ov, bpmFs, ic),
                  SizedBox(height: vGap * 1.18),
                  _buildTempoSlider(context, cPri, cTxt),
                  SizedBox(height: vGap * 1.18),
                  SizedBox(
                    height: act,
                    child: _buildActRow(cTxt, ov, ic * 0.88, act),
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
        final gap = (cs.maxWidth * 0.028).clamp(10.0, 18.0).toDouble();
        final sideW = (cs.maxWidth * 0.16).clamp(72.0, 102.0).toDouble();
        final cardW =
            ((cs.maxWidth - sideW - gap * 3) / 3).clamp(76.0, 156.0).toDouble();
        final cardH = (cardW * 1.26).clamp(132.0, 196.0).toDouble();
        final sideH = ((cardH - gap) / 2).clamp(60.0, 94.0).toDouble();
        final topFs = (cardW * 0.33).clamp(32.0, 50.0).toDouble();
        final btmFs = (cardW * 0.18).clamp(18.0, 30.0).toDouble();
        final r = Radius.circular((cardW * 0.22).clamp(20.0, 30.0));
        final sideR = Radius.circular((sideW * 0.22).clamp(16.0, 24.0));
        final rowW = cardW * 3 + sideW + gap * 3;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: rowW.clamp(0.0, cs.maxWidth),
            height: cardH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < 3; i++) ...[
                  PresetButton(
                    width: cardW,
                    height: cardH,
                    bg: cPri.withValues(
                        alpha: _isPresetActive(memoryPresets[i]) ? 1.0 : 0.6),
                    radius: r,
                    top: memoryPresets[i].hasValue
                        ? '${memoryPresets[i].bpm}'
                        : '',
                    bottom: memoryPresets[i].hasValue
                        ? (memoryPresets[i].name == null
                            ? '${memoryPresets[i].beats} / ${_noteLbl(memoryPresets[i].notes!, short: true)}'
                            : memoryPresets[i].name!)
                        : '',
                    topSize: topFs,
                    bottomSize: memoryPresets[i].name == null
                        ? btmFs
                        : btmFs * 0.8,
                    color: cTxt,
                    overlayColor: ov,
                    onTap: memoryPresets[i].hasValue
                        ? () => _applyPreset(memoryPresets[i],
                            recordHistory: true, index: i)
                        : null,
                    onLongPress: () => _savePreset(i),
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
                        asset: _ic('grid'),
                        iconColor: cTxt,
                        overlayColor: ov,
                        onTap: _openMemoryGrid,
                      ),
                      SizedBox(height: gap),
                      GestureDetector(
                        onLongPressStart: canUndo ? (_) => _stUndoHold() : null,
                        onLongPressEnd: canUndo ? (_) => _edUndoHold() : null,
                        child: SquareIconButton(
                          size: sideH,
                          radius: sideR,
                          bg: cPri.withValues(alpha: canUndo ? 1.0 : 0.6),
                          asset: _ic('back'),
                          iconColor: cTxt,
                          overlayColor: ov,
                          onTap: canUndo ? _undo : () {},
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
        final gap = (cs.maxWidth * 0.03).clamp(10.0, 18.0).toDouble();
        final cardW =
            ((cs.maxWidth - gap * 2) / 3).clamp(76.0, 156.0).toDouble();
        final cardH = (cardW * 1.26).clamp(132.0, 196.0).toDouble();
        final topFs = (cardW * 0.33).clamp(32.0, 50.0).toDouble();
        final btmFs = (cardW * 0.18).clamp(18.0, 30.0).toDouble();
        final r = Radius.circular((cardW * 0.22).clamp(20.0, 30.0));
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: (cardW * 3 + gap * 2).clamp(0.0, cs.maxWidth),
            height: cardH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < 3; i++) ...[
                  PresetButton(
                    width: cardW,
                    height: cardH,
                    bg: cPri.withValues(
                        alpha: _isPresetActive(memoryPresets[i]) ? 1.0 : 0.6),
                    radius: r,
                    top: memoryPresets[i].hasValue
                        ? '${memoryPresets[i].bpm}'
                        : '',
                    bottom: memoryPresets[i].hasValue
                        ? (memoryPresets[i].name == null
                            ? '${memoryPresets[i].beats} / ${_noteLbl(memoryPresets[i].notes!, short: true)}'
                            : memoryPresets[i].name!)
                        : '',
                    topSize: topFs,
                    bottomSize: memoryPresets[i].name == null
                        ? btmFs
                        : btmFs * 0.8,
                    color: cTxt,
                    overlayColor: ov,
                    onTap: memoryPresets[i].hasValue
                        ? () => _applyPreset(memoryPresets[i],
                            recordHistory: true, index: i)
                        : null,
                    onLongPress: () => _savePreset(i),
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
        final gap = (cs.maxWidth * 0.022).clamp(8.0, 16.0).toDouble();
        final cellW = ((cs.maxWidth - gap * (cols - 1)) / cols)
            .clamp(72.0, double.infinity)
            .toDouble();
        final itemW = cellW.clamp(72.0, 180.0).toDouble();
        final topFs = (itemW * 0.30).clamp(24.0, 41.0).toDouble();
        final btmFs = (itemW * 0.17).clamp(14.5, 24.0).toDouble();
        final r = Radius.circular((itemW * 0.22).clamp(14.0, 24.0));
        final itemH = cellW / 0.92;
        final rowW = cellW * cols + gap * (cols - 1);
        final rows = (40 / cols).ceil();
        final isLnd = sz.width > sz.height;

        Widget btn(int i) {
          if (i == 38) {
            const cEd = Color(0xFF2FA599);
            return PresetIconButton(
              bg: cEd.withValues(alpha: _memNameMd ? 1.0 : 0.62),
              radius: r,
              asset: _ic('pencil'),
              iconColor: cTxt,
              overlayColor: cEd.withValues(alpha: 0.18),
              iconSize: itemW * 0.30,
              onTap: _tglMemName,
              useMinAlpha: false,
            );
          }
          if (i == 39) {
            const cDel = Color(0xFFFF7048);
            return Listener(
              onPointerDown: (e) {
                _memDelIn = _hitMemDel(e.position);
                if (_memDelIn) _stDeletePresetHold();
              },
              onPointerMove: (e) {
                if (_memDelTm == null) return;
                if (!_hitMemDel(e.position)) {
                  _memDelIn = false;
                  _edDeletePresetHold(allowTap: false);
                }
              },
              onPointerUp: (e) {
                final ok = _memDelIn && _hitMemDel(e.position);
                _edDeletePresetHold(allowTap: ok);
              },
              onPointerCancel: (_) => _edDeletePresetHold(allowTap: false),
              child: PresetIconButton(
                key: _memDelKey,
                bg: cDel.withValues(alpha: _memDelMd ? 1.0 : 0.62),
                radius: r,
                asset: _ic('bin'),
                iconColor: cTxt,
                overlayColor: cDel.withValues(alpha: 0.18),
                iconSize: itemW * 0.34,
                onTap: () {},
                useMinAlpha: false,
              ),
            );
          }
          final p = memoryPresets[i];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              PresetButton(
                width: double.infinity,
                height: double.infinity,
                bg: cPri.withValues(alpha: _isPresetActive(p) ? 1.0 : 0.6),
                radius: r,
                top: p.hasValue ? '${p.bpm}' : '',
                bottom: p.hasValue
                    ? (p.name == null
                        ? '${p.beats} / ${_noteLbl(p.notes!, short: true)}'
                        : p.name!)
                    : '',
                topSize: topFs,
                bottomSize: p.name == null ? btmFs : btmFs * 0.8,
                color: cTxt,
                overlayColor: ov,
                hint: p.hasValue ? null : '+',
                hintSize: topFs * 0.86,
                hintColor: cTxt.withValues(alpha: 0.20),
                onTap: _memDelMd
                    ? (p.hasValue ? () => _resetPresetAt(i) : null)
                    : _memNameMd
                        ? (p.hasValue ? () => _openMemNameSheet(i) : null)
                        : p.hasValue
                            ? () =>
                                _applyPreset(p, recordHistory: true, index: i)
                            : () => _savePreset(i),
                onLongPress: (_memDelMd || _memNameMd)
                    ? null
                    : () => _savePreset(i),
              ),
              if (p.hasValue && p.tmOn)
                Positioned(
                  right: itemW * 0.10,
                  top: itemW * 0.10,
                  child: Opacity(
                    opacity: 0.22,
                    child: Image.asset(
                      _ic('clock'),
                      width: topFs * 0.72,
                      height: topFs * 0.72,
                      color: cTxt,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
            ],
          );
        }

        Widget row(int st) {
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: rowW.clamp(0.0, cs.maxWidth).toDouble(),
              child: Row(
                children: [
                  for (int c = 0; c < cols; c++) ...[
                    SizedBox(
                      width: cellW,
                      height: itemH,
                      child:
                          st + c < 40 ? btn(st + c) : const SizedBox.shrink(),
                    ),
                    if (c < cols - 1) SizedBox(width: gap),
                  ],
                ],
              ),
            ),
          );
        }

        final ch = <Widget>[
          if (isLnd) ...[
            _buildBannerSlot(context, height: itemH, grid: true),
            SizedBox(height: gap),
          ],
          for (int i = 0; i < rows; i++) ...[
            row(i * cols),
            if (!isLnd && i == 1) ...[
              SizedBox(height: gap),
              _buildBannerSlot(context, height: itemH, grid: true),
            ],
            if (i < rows - 1) SizedBox(height: gap),
          ],
        ];
        if (scroll) {
          return ListView(
            padding: EdgeInsets.only(top: scroll ? 4.0 : 0.0),
            physics: const ClampingScrollPhysics(),
            children: ch,
          );
        }
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ch,
          ),
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
            asset: _ic('arrows'),
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
          asset: _ic('minus'),
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
          asset: _ic('plus'),
          size: ic * 0.76,
          color: cTxt,
          overlayColor: ov,
          onTap: () => _changeBpmBy(1),
          onLongPress: () => _stBpmHold(1),
          onLongPressEnd: _edBpmHold,
        ),
        SizedBox(width: ic * 0.065),
        IconAssetButton(
          asset: _ic('arrows'),
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

  Widget _buildTempoStripLnd(Color cTxt, Color ov, double bpmFs, double ic) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconAssetButton(
          asset: _ic('minus'),
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
          asset: _ic('plus'),
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
        thumbShape: TallOvalThumbShape(width: thW, height: thH),
        overlayShape: RoundSliderOverlayShape(overlayRadius: ovR),
      ),
      child: Slider(
        min: _bpmLo.toDouble(),
        max: _bpmHi.toDouble(),
        value: bpm.clamp(_bpmLo.toDouble(), _bpmHi.toDouble()).toDouble(),
        onChanged: (v) {
          _previewBpm(v);
        },
        onChangeEnd: (v) => _setBpm(_snapBpm(v), recordHistory: true),
      ),
    );
  }

  Widget _buildActRow(Color cTxt, Color ov, double ic, double act) {
    final isLnd = MediaQuery.of(context).orientation == Orientation.landscape;
    final showExit = _showMemoryGrid && !isLnd;
    final ringP = _tmRunOn && isPlaying ? 1.0 - _tmProg : 0.0;
    final ringC = _isLight
        ? const Color(0xFF202020).withValues(alpha: 0.8)
        : const Color(0xFFEEEEEE).withValues(alpha: 0.8);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconAssetButton(
          asset: _ic('setting'),
          size: ic,
          color: cTxt,
          overlayColor: ov,
          onTap: _openSettingsSheet,
        ),
        SizedBox(
          width: act * 1.24,
          height: act * 1.24,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (ringP > 0)
                IgnorePointer(
                  child: SizedBox(
                    width: act * 1.24,
                    height: act * 1.24,
                    child: CustomPaint(
                      painter: _TimerRingPainter(
                        p: ringP,
                        color: ringC,
                      ),
                    ),
                  ),
                ),
              CircleActionButton(
                diameter: act,
                bg: _theme.color,
                asset: isPlaying ? _ic('stop') : _ic('play'),
                iconSize: act * 0.54,
                iconColor: cTxt,
                overlayColor: ov,
                onTap: _togglePlay,
              ),
            ],
          ),
        ),
        SizedBox(
          width: ic * 1.2,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 132),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, ani) {
              final fade = CurvedAnimation(
                parent: ani,
                curve: Curves.easeOutCubic,
              );
              final scale = Tween<double>(begin: 0.92, end: 1.0).animate(fade);
              return FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                  scale: scale,
                  child: child,
                ),
              );
            },
            child: (!showExit && !_showFnBtn())
                ? SizedBox(key: const ValueKey('none'), width: ic, height: ic)
                : IconAssetButton(
                    key: ValueKey(showExit ? 'exit' : _effFnBtn().name),
                    asset: showExit
                        ? _ic('exit')
                        : _fnIc(_effFnBtn()),
                    size: ic,
                    color: cTxt,
                    overlayColor: ov,
                    onTap: _onFnTap,
                  ),
          ),
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
  final menuW = rect.width.clamp(menuMinWidth, menuMaxWidth).toDouble();
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
  final rawTop = showBelow ? belowTop : rect.top - menuH - 8;
  final top = rawTop.clamp(8.0, overlaySize.height - menuH - 8.0);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
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
      final fade = CurvedAnimation(parent: ani, curve: Curves.easeOutCubic);
      final slide =
          Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(fade);
      return FadeTransition(
          opacity: fade, child: SlideTransition(position: slide, child: child));
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
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sel
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DefaultTextStyle(
                  style: menuTextStyle,
                  child: Center(child: buildItem(context, e)),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
