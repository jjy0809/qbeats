part of 'main.dart'; // 메인 라이브러리에 이 파트를 연결합니다.

extension _MainLayout on _MetronomeScreenState { // 메인 화면 상태에 반응형 레이아웃 메서드를 확장합니다.
  Widget _buildRspScf(BuildContext context) { // 방향별 반응형 스캐폴드를 구성합니다.
    const cBg = Color(0xFF202020); // 공통 배경색을 고정합니다.
    final mq = MediaQuery.of(context); // 현재 화면 정보를 가져옵니다.
    final sz = mq.size; // 현재 화면 크기를 구합니다.
    _syncBanner(mq.orientation, sz.width); // 방향과 너비가 바뀌면 배너를 다시 맞춥니다.
    return Scaffold( // 반응형 화면의 기본 스캐폴드를 반환합니다.
      backgroundColor: cBg, // 전체 배경색을 적용합니다.
      body: SafeArea( // 시스템 영역을 피해 본문을 배치합니다.
        child: AnimatedSwitcher( // 방향 전환 시 본문을 부드럽게 교체합니다.
          duration: const Duration(milliseconds: 280), // 화면 전환 시간을 지정합니다.
          switchInCurve: Curves.easeOutCubic, // 진입 곡선을 부드럽게 지정합니다.
          switchOutCurve: Curves.easeInCubic, // 이탈 곡선을 부드럽게 지정합니다.
          transitionBuilder: (child, ani) { // 전환 애니메이션을 정의합니다.
            final fade = CurvedAnimation(parent: ani, curve: Curves.easeOutCubic); // 페이드 곡선을 만듭니다.
            final slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(fade); // 짧은 슬라이드 전환을 만듭니다.
            return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child)); // 페이드와 슬라이드를 함께 적용합니다.
          }, // 전환 애니메이션 구성을 마칩니다.
          child: mq.orientation == Orientation.landscape // 현재 방향에 따라 전용 레이아웃을 고릅니다.
              ? _buildLnd(context, sz, const ValueKey('lnd')) // 가로 전용 화면을 그립니다.
              : _buildPtr(context, sz, const ValueKey('ptr')), // 세로 전용 화면을 그립니다.
        ), // 본문 전환 구성을 마칩니다.
      ), // 세이프 에어리어 구성을 마칩니다.
      bottomNavigationBar: (_bannerLoaded && _bannerAd != null) ? _buildBottomBannerBar() : null, // 배너가 준비된 경우에만 하단 광고를 붙입니다.
    ); // 스캐폴드 반환을 마칩니다.
  } // 반응형 스캐폴드 구성을 마칩니다.

  Widget _buildPtr(BuildContext context, Size sz, Key key) { // 세로 전용 화면을 구성합니다.
    final cPri = _theme.color; // 현재 테마의 포인트 색을 가져옵니다.
    const cTxt = Color(0xFFEEEEEE); // 공통 텍스트 색을 고정합니다.
    const cPnl = Color(0xFF404040); // 공통 패널 색을 고정합니다.
    final ov = cTxt.withValues(alpha: 0.10); // 터치 오버레이 색을 만듭니다.
    final pad = (sz.width * 0.06).clamp(18.0, 34.0); // 화면 폭 기반의 기본 패딩을 계산합니다.
    final gap = (sz.height * 0.018).clamp(12.0, 26.0); // 화면 높이 기반의 간격을 계산합니다.
    final scale = (sz.width / 390.0).clamp(0.88, 1.20); // 선택 위젯용 기본 스케일을 계산합니다.
    final r = Radius.circular((sz.width * 0.07).clamp(26.0, 38.0)); // 패널 모서리 반경을 계산합니다.
    return Container( // 세로 전용 본문 컨테이너를 만듭니다.
      key: key, // 방향 전환용 고정 키를 적용합니다.
      color: const Color(0xFF202020), // 배경색을 적용합니다.
      child: Column( // 상하 구조로 화면을 배치합니다.
        children: [ // 세로 화면의 섹션들을 나열합니다.
          SizedBox(height: gap), // 상단 여백을 둡니다.
          AnimatedSize( // 메모리 그리드 전환 시 상단 박자 영역 높이를 부드럽게 바꿉니다.
            duration: const Duration(milliseconds: 260), // 높이 전환 시간을 지정합니다.
            curve: Curves.easeInOutCubic, // 높이 전환 곡선을 지정합니다.
            child: AnimatedOpacity( // 박자 영역의 노출도 함께 부드럽게 바꿉니다.
              duration: const Duration(milliseconds: 180), // 투명도 전환 시간을 지정합니다.
              opacity: _showMemoryGrid ? 0.0 : 1.0, // 메모리 화면에서는 박자 영역을 숨깁니다.
              child: _showMemoryGrid // 메모리 화면 여부에 따라 실제 위젯을 바꿉니다.
                  ? const SizedBox.shrink() // 메모리 화면에서는 상단 박자 영역을 제거합니다.
                  : Padding( // 일반 화면에서는 좌우 패딩을 적용합니다.
                      padding: EdgeInsets.symmetric(horizontal: pad), // 상단 박자 영역 패딩을 적용합니다.
                      child: BeatCircles( // 박자 원형 영역을 렌더링합니다.
                        count: beatCount, // 현재 박자 수를 전달합니다.
                        areaWidth: sz.width - pad * 2, // 현재 화면에 맞는 박자 영역 너비를 전달합니다.
                        primary: cPri, // 포인트 색을 전달합니다.
                        baseOverlay: cPri.withValues(alpha: 0.16), // 원형 터치 오버레이를 전달합니다.
                        levels: beatLevels, // 박자 강세 목록을 전달합니다.
                        activeIndex: _activeBeatIndex, // 현재 활성 박자 인덱스를 전달합니다.
                        pulseToken: _pulseToken, // 펄스 토큰을 전달합니다.
                        onTapBeat: _cycleBeatLevel, // 박자 강세 순환 콜백을 전달합니다.
                      ), // 박자 원형 렌더링을 마칩니다.
                    ), // 일반 화면 박자 영역 구성을 마칩니다.
            ), // 상단 박자 영역 투명도 전환을 마칩니다.
          ), // 상단 박자 영역 크기 전환을 마칩니다.
          SizedBox(height: gap), // 박자 영역과 선택 영역 사이 간격을 둡니다.
          Padding( // 선택 메뉴 좌우 패딩을 적용합니다.
            padding: EdgeInsets.symmetric(horizontal: pad), // 선택 메뉴 패딩 값을 적용합니다.
            child: Row( // 박자 수와 분할 수 선택을 한 줄에 배치합니다.
              children: [ // 선택 메뉴 두 개를 나열합니다.
                Expanded( // 왼쪽 선택 메뉴가 남는 폭을 차지하게 합니다.
                  child: Center( // 왼쪽 메뉴를 가운데 정렬합니다.
                    child: PopupNumberSelect( // 박자 수 선택 팝업을 표시합니다.
                      value: beatCount, // 현재 박자 수를 전달합니다.
                      items: const [1, 2, 3, 4, 5, 6, 7, 8], // 가능한 박자 수 목록을 전달합니다.
                      scale: scale, // 현재 화면용 스케일을 전달합니다.
                      color: cTxt, // 텍스트 색을 전달합니다.
                      overlayColor: ov, // 터치 오버레이 색을 전달합니다.
                      onChanged: (v) => _setBeatCount(v, recordHistory: true), // 선택 값 변경 콜백을 전달합니다.
                    ), // 박자 수 팝업 구성을 마칩니다.
                  ), // 왼쪽 메뉴 정렬을 마칩니다.
                ), // 왼쪽 선택 영역 구성을 마칩니다.
                Expanded( // 오른쪽 선택 메뉴가 남는 폭을 차지하게 합니다.
                  child: Center( // 오른쪽 메뉴를 가운데 정렬합니다.
                    child: PopupNoteSelect( // 분할 수 선택 팝업을 표시합니다.
                      value: noteCount, // 현재 분할 수를 전달합니다.
                      items: const [1, 2, 3, 4, 5, 6], // 가능한 분할 수 목록을 전달합니다.
                      scale: scale, // 현재 화면용 스케일을 전달합니다.
                      color: cTxt, // 텍스트 색을 전달합니다.
                      overlayColor: ov, // 터치 오버레이 색을 전달합니다.
                      noteAsset: 'assets/icons/light/note.png', // 음표 아이콘 에셋을 전달합니다.
                      onChanged: (v) => _setNoteCount(v, recordHistory: true), // 선택 값 변경 콜백을 전달합니다.
                    ), // 분할 수 팝업 구성을 마칩니다.
                  ), // 오른쪽 메뉴 정렬을 마칩니다.
                ), // 오른쪽 선택 영역 구성을 마칩니다.
              ], // 선택 메뉴 나열을 마칩니다.
            ), // 선택 메뉴 행 구성을 마칩니다.
          ), // 선택 메뉴 패딩 구성을 마칩니다.
          SizedBox(height: gap), // 선택 영역과 메인 패널 사이 간격을 둡니다.
          Expanded( // 메인 패널이 남는 높이를 모두 차지하게 합니다.
            child: AnimatedContainer( // 세로 패널의 높이와 스타일 전환을 부드럽게 처리합니다.
              duration: const Duration(milliseconds: 260), // 패널 전환 시간을 지정합니다.
              curve: Curves.easeInOutCubic, // 패널 전환 곡선을 지정합니다.
              decoration: BoxDecoration( // 메인 패널 장식을 정의합니다.
                color: cPnl, // 패널 배경색을 적용합니다.
                borderRadius: BorderRadius.only(topLeft: r, topRight: r), // 상단 모서리만 둥글게 만듭니다.
              ), // 패널 장식 구성을 마칩니다.
              child: LayoutBuilder( // 패널 내부에서 실제 높이를 기반으로 배치합니다.
                builder: (context, cs) { // 패널 내부 레이아웃을 동적으로 계산합니다.
                  final scGap = (cs.maxHeight * 0.028).clamp(16.0, 28.0); // 패널 내부 간격을 계산합니다.
                  final bpmFs = (sz.width * 0.16).clamp(72.0, 118.0); // BPM 숫자 크기를 계산합니다.
                  final ic = (sz.width * 0.19).clamp(78.0, 110.0); // 일반 아이콘 크기를 계산합니다.
                  final act = (sz.width * 0.29).clamp(108.0, 136.0); // 재생 버튼 지름을 계산합니다.
                  return SingleChildScrollView( // 작은 화면에서도 내용이 안전하게 스크롤되게 합니다.
                    padding: EdgeInsets.fromLTRB(pad, pad, pad, pad), // 패널 내부 패딩을 적용합니다.
                    child: Column( // 패널 내부 콘텐츠를 세로로 나열합니다.
                      children: [ // 패널 내부 섹션들을 나열합니다.
                        AnimatedSwitcher( // 프리셋과 메모리 그리드 전환을 부드럽게 처리합니다.
                          duration: const Duration(milliseconds: 220), // 전환 시간을 지정합니다.
                          switchInCurve: Curves.easeOutCubic, // 진입 곡선을 지정합니다.
                          switchOutCurve: Curves.easeInCubic, // 이탈 곡선을 지정합니다.
                          child: _showMemoryGrid // 메모리 화면 여부에 따라 섹션을 고릅니다.
                              ? _buildMemGrid(sz, cPri, cTxt, ov, const ValueKey('ptr-mem')) // 메모리 그리드를 렌더링합니다.
                              : _buildQuickPresets(sz, cPri, cTxt, ov, const ValueKey('ptr-pre')), // 빠른 프리셋 영역을 렌더링합니다.
                        ), // 프리셋 전환 구성을 마칩니다.
                        SizedBox(height: scGap), // 프리셋 영역과 템포 영역 사이 간격을 둡니다.
                        _buildTempoStrip(cTxt, ov, bpmFs, ic), // 템포 증감과 숫자 표시 영역을 렌더링합니다.
                        SizedBox(height: scGap), // 템포 영역과 슬라이더 사이 간격을 둡니다.
                        _buildTempoSlider(context, cPri, cTxt), // 템포 슬라이더를 렌더링합니다.
                        SizedBox(height: scGap * 1.15), // 슬라이더와 하단 액션 영역 사이 간격을 둡니다.
                        _buildActRow(cTxt, ov, ic, act), // 설정, 재생, 탭 템포 버튼을 렌더링합니다.
                      ], // 패널 내부 섹션 나열을 마칩니다.
                    ), // 패널 내부 컬럼 구성을 마칩니다.
                  ); // 스크롤 가능한 패널 콘텐츠를 반환합니다.
                }, // 패널 내부 레이아웃 계산을 마칩니다.
              ), // 패널 내부 레이아웃 빌더 구성을 마칩니다.
            ), // 세로 패널 구성을 마칩니다.
          ), // 메인 패널 확장 구성을 마칩니다.
        ], // 세로 화면 섹션 나열을 마칩니다.
      ), // 세로 화면 컬럼 구성을 마칩니다.
    ); // 세로 화면 반환을 마칩니다.
  } // 세로 전용 화면 구성을 마칩니다.

  Widget _buildLnd(BuildContext context, Size sz, Key key) { // 가로 전용 화면을 구성합니다.
    final cPri = _theme.color; // 현재 테마의 포인트 색을 가져옵니다.
    const cTxt = Color(0xFFEEEEEE); // 공통 텍스트 색을 고정합니다.
    const cPnl = Color(0xFF404040); // 공통 패널 색을 고정합니다.
    final ov = cTxt.withValues(alpha: 0.10); // 터치 오버레이 색을 만듭니다.
    final pad = (sz.height * 0.05).clamp(16.0, 28.0); // 가로 화면용 기본 패딩을 계산합니다.
    final gap = (sz.width * 0.018).clamp(14.0, 26.0); // 가로 화면용 간격을 계산합니다.
    final scale = (sz.height / 430.0).clamp(0.82, 1.14); // 가로 화면용 선택 위젯 스케일을 계산합니다.
    final bpmFs = (sz.height * 0.18).clamp(58.0, 96.0); // 가로 화면용 BPM 숫자 크기를 계산합니다.
    final ic = (sz.height * 0.16).clamp(64.0, 96.0); // 가로 화면용 일반 아이콘 크기를 계산합니다.
    final act = (sz.height * 0.24).clamp(92.0, 126.0); // 가로 화면용 재생 버튼 지름을 계산합니다.
    return Container( // 가로 전용 본문 컨테이너를 만듭니다.
      key: key, // 방향 전환용 고정 키를 적용합니다.
      color: const Color(0xFF202020), // 배경색을 적용합니다.
      padding: EdgeInsets.all(pad), // 화면 바깥 패딩을 적용합니다.
      child: Row( // 좌우 분할 레이아웃을 구성합니다.
        children: [ // 가로 화면의 좌우 패널을 나열합니다.
          Expanded( // 왼쪽 제어 패널이 남는 폭을 차지하게 합니다.
            flex: 10, // 왼쪽 패널의 비중을 지정합니다.
            child: Container( // 왼쪽 제어 패널 컨테이너를 만듭니다.
              decoration: BoxDecoration( // 왼쪽 패널 장식을 정의합니다.
                color: cPnl, // 패널 배경색을 적용합니다.
                borderRadius: BorderRadius.circular((sz.height * 0.06).clamp(22.0, 34.0)), // 패널 모서리를 둥글게 만듭니다.
              ), // 왼쪽 패널 장식 구성을 마칩니다.
              padding: EdgeInsets.all(pad), // 왼쪽 패널 내부 패딩을 적용합니다.
              child: Column( // 왼쪽 패널 내부를 세로로 배치합니다.
                mainAxisAlignment: MainAxisAlignment.center, // 주요 제어를 세로 중앙에 배치합니다.
                children: [ // 왼쪽 제어 요소들을 나열합니다.
                  _buildTempoStrip(cTxt, ov, bpmFs, ic), // 템포 증감과 숫자 표시 영역을 렌더링합니다.
                  SizedBox(height: gap), // 템포 영역과 슬라이더 사이 간격을 둡니다.
                  _buildTempoSlider(context, cPri, cTxt), // 템포 슬라이더를 렌더링합니다.
                  SizedBox(height: gap * 1.15), // 슬라이더와 버튼 영역 사이 간격을 둡니다.
                  _buildActRow(cTxt, ov, ic, act), // 설정, 재생, 탭 템포 버튼을 렌더링합니다.
                ], // 왼쪽 제어 요소 나열을 마칩니다.
              ), // 왼쪽 패널 컬럼 구성을 마칩니다.
            ), // 왼쪽 제어 패널 구성을 마칩니다.
          ), // 왼쪽 패널 확장 구성을 마칩니다.
          SizedBox(width: gap), // 좌우 패널 사이 간격을 둡니다.
          Expanded( // 오른쪽 정보 패널이 남는 폭을 차지하게 합니다.
            flex: 12, // 오른쪽 패널의 비중을 지정합니다.
            child: Container( // 오른쪽 정보 패널 컨테이너를 만듭니다.
              decoration: BoxDecoration( // 오른쪽 패널 장식을 정의합니다.
                color: cPnl, // 패널 배경색을 적용합니다.
                borderRadius: BorderRadius.circular((sz.height * 0.06).clamp(22.0, 34.0)), // 패널 모서리를 둥글게 만듭니다.
              ), // 오른쪽 패널 장식 구성을 마칩니다.
              padding: EdgeInsets.all(pad), // 오른쪽 패널 내부 패딩을 적용합니다.
              child: SingleChildScrollView( // 내용이 많아져도 안전하게 스크롤되게 합니다.
                child: Column( // 오른쪽 패널 내부를 세로로 배치합니다.
                  children: [ // 오른쪽 패널 섹션들을 나열합니다.
                    Row( // 선택 메뉴를 한 줄에 배치합니다.
                      children: [ // 선택 메뉴 두 개를 나열합니다.
                        Expanded( // 왼쪽 메뉴를 확장 배치합니다.
                          child: Center( // 왼쪽 메뉴를 가운데 정렬합니다.
                            child: PopupNumberSelect( // 박자 수 선택 팝업을 표시합니다.
                              value: beatCount, // 현재 박자 수를 전달합니다.
                              items: const [1, 2, 3, 4, 5, 6, 7, 8], // 가능한 박자 수 목록을 전달합니다.
                              scale: scale, // 현재 화면용 스케일을 전달합니다.
                              color: cTxt, // 텍스트 색을 전달합니다.
                              overlayColor: ov, // 터치 오버레이 색을 전달합니다.
                              onChanged: (v) => _setBeatCount(v, recordHistory: true), // 선택 값 변경 콜백을 전달합니다.
                            ), // 박자 수 팝업 구성을 마칩니다.
                          ), // 왼쪽 메뉴 정렬을 마칩니다.
                        ), // 왼쪽 메뉴 확장 구성을 마칩니다.
                        Expanded( // 오른쪽 메뉴를 확장 배치합니다.
                          child: Center( // 오른쪽 메뉴를 가운데 정렬합니다.
                            child: PopupNoteSelect( // 분할 수 선택 팝업을 표시합니다.
                              value: noteCount, // 현재 분할 수를 전달합니다.
                              items: const [1, 2, 3, 4, 5, 6], // 가능한 분할 수 목록을 전달합니다.
                              scale: scale, // 현재 화면용 스케일을 전달합니다.
                              color: cTxt, // 텍스트 색을 전달합니다.
                              overlayColor: ov, // 터치 오버레이 색을 전달합니다.
                              noteAsset: 'assets/icons/light/note.png', // 음표 아이콘 에셋을 전달합니다.
                              onChanged: (v) => _setNoteCount(v, recordHistory: true), // 선택 값 변경 콜백을 전달합니다.
                            ), // 분할 수 팝업 구성을 마칩니다.
                          ), // 오른쪽 메뉴 정렬을 마칩니다.
                        ), // 오른쪽 메뉴 확장 구성을 마칩니다.
                      ], // 선택 메뉴 나열을 마칩니다.
                    ), // 선택 메뉴 행 구성을 마칩니다.
                    SizedBox(height: gap), // 선택 메뉴와 박자 원형 사이 간격을 둡니다.
                    AnimatedSwitcher( // 메모리 화면 여부에 따라 상단 박자 영역을 부드럽게 바꿉니다.
                      duration: const Duration(milliseconds: 220), // 전환 시간을 지정합니다.
                      child: _showMemoryGrid // 메모리 화면 여부를 확인합니다.
                          ? const SizedBox.shrink() // 메모리 화면에서는 박자 원형을 숨깁니다.
                          : BeatCircles( // 일반 화면에서는 박자 원형을 표시합니다.
                              key: const ValueKey('lnd-beat'), // 가로 박자 영역 키를 부여합니다.
                              count: beatCount, // 현재 박자 수를 전달합니다.
                              areaWidth: sz.width * 0.44, // 가로 화면에 맞는 박자 영역 너비를 전달합니다.
                              primary: cPri, // 포인트 색을 전달합니다.
                              baseOverlay: cPri.withValues(alpha: 0.16), // 원형 터치 오버레이를 전달합니다.
                              levels: beatLevels, // 박자 강세 목록을 전달합니다.
                              activeIndex: _activeBeatIndex, // 현재 활성 박자 인덱스를 전달합니다.
                              pulseToken: _pulseToken, // 펄스 토큰을 전달합니다.
                              onTapBeat: _cycleBeatLevel, // 박자 강세 순환 콜백을 전달합니다.
                            ), // 박자 원형 렌더링을 마칩니다.
                    ), // 상단 박자 영역 전환을 마칩니다.
                    SizedBox(height: gap), // 박자 영역과 프리셋 영역 사이 간격을 둡니다.
                    AnimatedSwitcher( // 프리셋과 메모리 그리드 전환을 부드럽게 처리합니다.
                      duration: const Duration(milliseconds: 220), // 전환 시간을 지정합니다.
                      switchInCurve: Curves.easeOutCubic, // 진입 곡선을 지정합니다.
                      switchOutCurve: Curves.easeInCubic, // 이탈 곡선을 지정합니다.
                      child: _showMemoryGrid // 메모리 화면 여부에 따라 섹션을 고릅니다.
                          ? _buildMemGrid(sz, cPri, cTxt, ov, const ValueKey('lnd-mem')) // 메모리 그리드를 렌더링합니다.
                          : _buildQuickPresets(sz, cPri, cTxt, ov, const ValueKey('lnd-pre')), // 빠른 프리셋 영역을 렌더링합니다.
                    ), // 프리셋 전환 구성을 마칩니다.
                  ], // 오른쪽 패널 섹션 나열을 마칩니다.
                ), // 오른쪽 패널 컬럼 구성을 마칩니다.
              ), // 오른쪽 패널 스크롤 구성을 마칩니다.
            ), // 오른쪽 정보 패널 구성을 마칩니다.
          ), // 오른쪽 패널 확장 구성을 마칩니다.
        ], // 좌우 패널 나열을 마칩니다.
      ), // 가로 화면 행 구성을 마칩니다.
    ); // 가로 화면 반환을 마칩니다.
  } // 가로 전용 화면 구성을 마칩니다.

  Widget _buildQuickPresets(Size sz, Color cPri, Color cTxt, Color ov, Key key) { // 빠른 프리셋 묶음을 구성합니다.
    final gap = (sz.shortestSide * 0.03).clamp(10.0, 18.0); // 프리셋 간격을 계산합니다.
    final pW = (sz.shortestSide * 0.28).clamp(108.0, 144.0); // 프리셋 카드 너비를 계산합니다.
    final pH = (pW * 1.26).clamp(138.0, 198.0); // 프리셋 카드 높이를 계산합니다.
    final side = (sz.shortestSide * 0.22).clamp(72.0, 104.0); // 보조 아이콘 버튼 크기를 계산합니다.
    final canUndo = _history.isNotEmpty; // 되돌리기 가능 여부를 계산합니다.
    return Wrap( // 화면 폭에 따라 프리셋을 유연하게 줄바꿈 배치합니다.
      key: key, // 전환용 키를 적용합니다.
      alignment: WrapAlignment.center, // 프리셋 묶음을 가운데 정렬합니다.
      spacing: gap, // 가로 간격을 적용합니다.
      runSpacing: gap, // 세로 간격을 적용합니다.
      children: [ // 빠른 프리셋과 보조 버튼을 나열합니다.
        for (int i = 0; i < 3; i++) // 첫 세 개 프리셋만 빠른 카드로 노출합니다.
          PresetButton( // 빠른 프리셋 카드를 렌더링합니다.
            width: pW, // 카드 너비를 전달합니다.
            height: pH, // 카드 높이를 전달합니다.
            bg: cPri.withValues(alpha: _isPresetActive(memoryPresets[i]) ? 1.0 : 0.6), // 현재 활성 프리셋은 더 진하게 표시합니다.
            radius: Radius.circular((pW * 0.22).clamp(24.0, 32.0)), // 카드 모서리 반경을 계산합니다.
            top: '${memoryPresets[i].bpm}', // 카드 상단 BPM 텍스트를 전달합니다.
            bottom: '${memoryPresets[i].beats} / ${memoryPresets[i].notes}', // 카드 하단 박자 정보를 전달합니다.
            topSize: (pW * 0.34).clamp(34.0, 50.0), // 카드 상단 글자 크기를 계산합니다.
            bottomSize: (pW * 0.19).clamp(20.0, 30.0), // 카드 하단 글자 크기를 계산합니다.
            color: cTxt, // 카드 텍스트 색을 전달합니다.
            overlayColor: ov, // 카드 터치 오버레이 색을 전달합니다.
            onTap: () => _applyPreset(memoryPresets[i], recordHistory: true), // 카드 탭 시 프리셋을 적용합니다.
            onLongPress: () => _savePreset(i), // 카드 길게 누름 시 현재 설정을 저장합니다.
          ), // 빠른 프리셋 카드 구성을 마칩니다.
        Column( // 메모리 그리드와 되돌리기 버튼을 세로로 배치합니다.
          mainAxisSize: MainAxisSize.min, // 필요한 높이만 사용합니다.
          children: [ // 보조 버튼 두 개를 나열합니다.
            SquareIconButton( // 메모리 전체 그리드를 여는 버튼을 렌더링합니다.
              size: side, // 버튼 크기를 전달합니다.
              radius: Radius.circular((side * 0.22).clamp(18.0, 26.0)), // 버튼 모서리 반경을 계산합니다.
              bg: cPri, // 버튼 배경색을 적용합니다.
              asset: 'assets/icons/light/grid.png', // 그리드 아이콘을 전달합니다.
              iconColor: cTxt, // 아이콘 색을 전달합니다.
              overlayColor: ov, // 터치 오버레이 색을 전달합니다.
              onTap: _openMemoryGrid, // 탭 시 전체 메모리 그리드를 엽니다.
            ), // 메모리 그리드 버튼 구성을 마칩니다.
            SizedBox(height: gap), // 보조 버튼 사이 간격을 둡니다.
            SquareIconButton( // 되돌리기 버튼을 렌더링합니다.
              size: side, // 버튼 크기를 전달합니다.
              radius: Radius.circular((side * 0.22).clamp(18.0, 26.0)), // 버튼 모서리 반경을 계산합니다.
              bg: cPri.withValues(alpha: canUndo ? 1.0 : 0.6), // 되돌리기 가능 여부에 따라 농도를 바꿉니다.
              asset: 'assets/icons/light/back.png', // 되돌리기 아이콘을 전달합니다.
              iconColor: cTxt, // 아이콘 색을 전달합니다.
              overlayColor: ov, // 터치 오버레이 색을 전달합니다.
              onTap: canUndo ? _undo : () {}, // 되돌리기 가능할 때만 실제 동작을 연결합니다.
            ), // 되돌리기 버튼 구성을 마칩니다.
          ], // 보조 버튼 나열을 마칩니다.
        ), // 보조 버튼 컬럼 구성을 마칩니다.
      ], // 빠른 프리셋 영역 나열을 마칩니다.
    ); // 빠른 프리셋 묶음 반환을 마칩니다.
  } // 빠른 프리셋 묶음 구성을 마칩니다.

  Widget _buildMemGrid(Size sz, Color cPri, Color cTxt, Color ov, Key key) { // 전체 메모리 프리셋 그리드를 구성합니다.
    final cols = sz.width >= 900 ? 5 : sz.width >= 560 ? 4 : 3; // 현재 화면 폭에 맞는 열 수를 계산합니다.
    final gap = (sz.shortestSide * 0.028).clamp(8.0, 16.0); // 그리드 간격을 계산합니다.
    final topFs = (sz.shortestSide * 0.10).clamp(24.0, 38.0); // 상단 숫자 글자 크기를 계산합니다.
    final btmFs = (sz.shortestSide * 0.055).clamp(14.0, 22.0); // 하단 정보 글자 크기를 계산합니다.
    return Column( // 메모리 그리드와 닫기 버튼을 세로로 배치합니다.
      key: key, // 전환용 키를 적용합니다.
      children: [ // 메모리 섹션 요소들을 나열합니다.
        Align( // 닫기 버튼을 오른쪽 정렬합니다.
          alignment: Alignment.centerRight, // 닫기 버튼 정렬 방향을 지정합니다.
          child: IconAssetButton( // 메모리 그리드를 닫는 버튼을 렌더링합니다.
            asset: 'assets/icons/light/exit.png', // 닫기 아이콘을 전달합니다.
            size: (sz.shortestSide * 0.12).clamp(42.0, 58.0), // 닫기 아이콘 크기를 계산합니다.
            color: cTxt, // 아이콘 색을 전달합니다.
            overlayColor: ov, // 터치 오버레이 색을 전달합니다.
            onTap: _closeMemoryGrid, // 탭 시 메모리 그리드를 닫습니다.
          ), // 닫기 버튼 구성을 마칩니다.
        ), // 닫기 버튼 정렬을 마칩니다.
        SizedBox(height: gap), // 닫기 버튼과 그리드 사이 간격을 둡니다.
        GridView.builder( // 전체 프리셋 그리드를 렌더링합니다.
          shrinkWrap: true, // 부모 스크롤 안에서 필요한 높이만 사용합니다.
          physics: const NeverScrollableScrollPhysics(), // 외부 스크롤과 충돌하지 않게 내부 스크롤을 끕니다.
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount( // 현재 화면에 맞는 고정 열 수 그리드를 구성합니다.
            crossAxisCount: cols, // 계산된 열 수를 적용합니다.
            crossAxisSpacing: gap, // 가로 간격을 적용합니다.
            mainAxisSpacing: gap, // 세로 간격을 적용합니다.
            childAspectRatio: 1.04, // 카드 비율을 맞춥니다.
          ), // 그리드 위임 구성을 마칩니다.
          itemCount: 40, // 저장 슬롯 전체 개수를 렌더링합니다.
          itemBuilder: (context, i) { // 각 프리셋 카드를 생성합니다.
            final p = memoryPresets[i]; // 현재 슬롯 프리셋 정보를 가져옵니다.
            return PresetButton( // 메모리 프리셋 카드를 렌더링합니다.
              width: double.infinity, // 셀 폭을 모두 사용합니다.
              height: double.infinity, // 셀 높이를 모두 사용합니다.
              bg: cPri.withValues(alpha: _isPresetActive(p) ? 1.0 : 0.6), // 현재 활성 프리셋은 더 진하게 표시합니다.
              radius: Radius.circular((sz.shortestSide * 0.06).clamp(16.0, 24.0)), // 카드 모서리 반경을 계산합니다.
              top: '${p.bpm}', // 카드 상단 BPM 텍스트를 전달합니다.
              bottom: '${p.beats} / ${p.notes}', // 카드 하단 박자 정보를 전달합니다.
              topSize: topFs, // 카드 상단 글자 크기를 전달합니다.
              bottomSize: btmFs, // 카드 하단 글자 크기를 전달합니다.
              color: cTxt, // 카드 텍스트 색을 전달합니다.
              overlayColor: ov, // 카드 터치 오버레이 색을 전달합니다.
              onTap: () => _applyPreset(p, recordHistory: true), // 탭 시 프리셋을 적용합니다.
              onLongPress: () => _savePreset(i), // 길게 누르면 현재 설정을 저장합니다.
            ); // 메모리 프리셋 카드 구성을 마칩니다.
          }, // 그리드 아이템 생성을 마칩니다.
        ), // 전체 프리셋 그리드 구성을 마칩니다.
      ], // 메모리 섹션 요소 나열을 마칩니다.
    ); // 전체 메모리 프리셋 그리드 반환을 마칩니다.
  } // 전체 메모리 프리셋 그리드 구성을 마칩니다.

  Widget _buildTempoStrip(Color cTxt, Color ov, double bpmFs, double ic) { // 템포 증감과 숫자 표시 행을 구성합니다.
    return Row( // 템포 조작 행을 렌더링합니다.
      mainAxisAlignment: MainAxisAlignment.center, // 행 전체를 가운데 정렬합니다.
      children: [ // 템포 조작 아이콘과 숫자를 나열합니다.
        Transform( // 좌측 10 단위 이동 아이콘을 좌우 반전합니다.
          alignment: Alignment.center, // 반전 기준을 가운데로 둡니다.
          transform: Matrix4.identity()..rotateY(math.pi), // 아이콘을 좌우 반전합니다.
          child: IconAssetButton( // 좌측 10 단위 감소 버튼을 렌더링합니다.
            asset: 'assets/icons/light/arrows.png', // 양방향 화살표 아이콘을 전달합니다.
            size: ic, // 아이콘 크기를 전달합니다.
            color: cTxt, // 아이콘 색을 전달합니다.
            overlayColor: ov, // 터치 오버레이 색을 전달합니다.
            onTap: () => _changeBpmBy(-10), // 탭 시 BPM을 10 감소시킵니다.
          ), // 좌측 10 단위 감소 버튼 구성을 마칩니다.
        ), // 좌우 반전 구성을 마칩니다.
        SizedBox(width: ic * 0.10), // 아이콘 사이 간격을 둡니다.
        IconAssetButton( // 1 단위 감소 버튼을 렌더링합니다.
          asset: 'assets/icons/light/minus.png', // 마이너스 아이콘을 전달합니다.
          size: ic * 0.88, // 약간 작은 아이콘 크기를 적용합니다.
          color: cTxt, // 아이콘 색을 전달합니다.
          overlayColor: ov, // 터치 오버레이 색을 전달합니다.
          onTap: () => _changeBpmBy(-1), // 탭 시 BPM을 1 감소시킵니다.
        ), // 1 단위 감소 버튼 구성을 마칩니다.
        SizedBox(width: ic * 0.16), // 숫자와 아이콘 사이 간격을 둡니다.
        RollingBpmText( // 롤링 숫자형 BPM 표시를 렌더링합니다.
          value: bpm.round(), // 현재 BPM 정수값을 전달합니다.
          previous: _lastBpmInt, // 이전 BPM 값을 전달합니다.
          fontSize: bpmFs, // 현재 화면용 글자 크기를 전달합니다.
          color: cTxt, // 숫자 색을 전달합니다.
        ), // BPM 숫자 표시 구성을 마칩니다.
        SizedBox(width: ic * 0.16), // 숫자와 아이콘 사이 간격을 둡니다.
        IconAssetButton( // 1 단위 증가 버튼을 렌더링합니다.
          asset: 'assets/icons/light/plus.png', // 플러스 아이콘을 전달합니다.
          size: ic * 0.88, // 약간 작은 아이콘 크기를 적용합니다.
          color: cTxt, // 아이콘 색을 전달합니다.
          overlayColor: ov, // 터치 오버레이 색을 전달합니다.
          onTap: () => _changeBpmBy(1), // 탭 시 BPM을 1 증가시킵니다.
        ), // 1 단위 증가 버튼 구성을 마칩니다.
        SizedBox(width: ic * 0.10), // 아이콘 사이 간격을 둡니다.
        IconAssetButton( // 10 단위 증가 버튼을 렌더링합니다.
          asset: 'assets/icons/light/arrows.png', // 양방향 화살표 아이콘을 전달합니다.
          size: ic, // 아이콘 크기를 전달합니다.
          color: cTxt, // 아이콘 색을 전달합니다.
          overlayColor: ov, // 터치 오버레이 색을 전달합니다.
          onTap: () => _changeBpmBy(10), // 탭 시 BPM을 10 증가시킵니다.
        ), // 10 단위 증가 버튼 구성을 마칩니다.
      ], // 템포 조작 아이콘과 숫자 나열을 마칩니다.
    ); // 템포 조작 행 반환을 마칩니다.
  } // 템포 조작 행 구성을 마칩니다.

  Widget _buildTempoSlider(BuildContext context, Color cPri, Color cTxt) { // 템포 슬라이더를 구성합니다.
    return SliderTheme( // 현재 테마를 메트로놈 스타일로 덮어씁니다.
      data: SliderTheme.of(context).copyWith( // 슬라이더 스타일을 현재 테마에서 복사해 수정합니다.
        trackHeight: 10, // 트랙 높이를 지정합니다.
        activeTrackColor: cPri, // 활성 트랙 색을 지정합니다.
        inactiveTrackColor: cTxt, // 비활성 트랙 색을 지정합니다.
        thumbColor: cPri, // 썸 색을 지정합니다.
        overlayColor: cPri.withValues(alpha: 0.22), // 썸 오버레이 색을 지정합니다.
        thumbShape: const TallOvalThumbShape(width: 44, height: 78), // 기존 세로형 썸 모양을 유지합니다.
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 30), // 오버레이 반경을 지정합니다.
      ), // 슬라이더 테마 복사 수정을 마칩니다.
      child: Slider( // 실제 BPM 슬라이더를 렌더링합니다.
        min: _MetronomeScreenState._bpmMin, // BPM 최소값을 지정합니다.
        max: _MetronomeScreenState._bpmMax, // BPM 최대값을 지정합니다.
        value: bpm.clamp(_MetronomeScreenState._bpmMin, _MetronomeScreenState._bpmMax).toDouble(), // 현재 BPM 값을 슬라이더 범위에 맞춰 전달합니다.
        onChanged: (v) { // 슬라이더 이동 중 UI 값을 즉시 반영합니다.
          _previewBpm(v); // 현재 BPM 표시를 실시간으로 갱신합니다.
        }, // 슬라이더 이동 중 콜백을 마칩니다.
        onChangeEnd: (v) => _setBpm(v, recordHistory: true), // 드래그가 끝나면 히스토리 포함 저장을 수행합니다.
      ), // 실제 BPM 슬라이더 구성을 마칩니다.
    ); // 템포 슬라이더 테마 구성을 마칩니다.
  } // 템포 슬라이더 구성을 마칩니다.

  Widget _buildActRow(Color cTxt, Color ov, double ic, double act) { // 하단 액션 버튼 행을 구성합니다.
    return Row( // 하단 액션 버튼을 한 줄에 배치합니다.
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // 세 버튼을 좌우로 벌려 배치합니다.
      children: [ // 하단 액션 버튼 세 개를 나열합니다.
        IconAssetButton( // 설정 버튼을 렌더링합니다.
          asset: 'assets/icons/light/setting.png', // 설정 아이콘을 전달합니다.
          size: ic, // 아이콘 크기를 전달합니다.
          color: cTxt, // 아이콘 색을 전달합니다.
          overlayColor: ov, // 터치 오버레이 색을 전달합니다.
          onTap: _openSettingsSheet, // 탭 시 설정 시트를 엽니다.
        ), // 설정 버튼 구성을 마칩니다.
        CircleActionButton( // 재생 또는 정지 버튼을 렌더링합니다.
          diameter: act, // 메인 액션 버튼 지름을 전달합니다.
          bg: _theme.color, // 버튼 배경색으로 현재 테마 색을 적용합니다.
          asset: isPlaying ? 'assets/icons/light/stop.png' : 'assets/icons/light/play.png', // 현재 상태에 따라 정지 또는 재생 아이콘을 선택합니다.
          iconSize: act * 0.54, // 메인 아이콘 크기를 지름 기준으로 계산합니다.
          iconColor: cTxt, // 아이콘 색을 전달합니다.
          overlayColor: ov, // 터치 오버레이 색을 전달합니다.
          onTap: _togglePlay, // 탭 시 재생 상태를 토글합니다.
        ), // 메인 액션 버튼 구성을 마칩니다.
        IconAssetButton( // 탭 템포 또는 메모리 닫기 버튼을 렌더링합니다.
          asset: _showMemoryGrid ? 'assets/icons/light/exit.png' : 'assets/icons/light/hand.png', // 현재 화면 상태에 따라 아이콘을 고릅니다.
          size: ic, // 아이콘 크기를 전달합니다.
          color: cTxt, // 아이콘 색을 전달합니다.
          overlayColor: ov, // 터치 오버레이 색을 전달합니다.
          onTap: _showMemoryGrid ? _closeMemoryGrid : _openTapTempoSheet, // 현재 화면 상태에 맞는 동작을 연결합니다.
        ), // 오른쪽 액션 버튼 구성을 마칩니다.
      ], // 하단 액션 버튼 나열을 마칩니다.
    ); // 하단 액션 버튼 행 반환을 마칩니다.
  } // 하단 액션 버튼 행 구성을 마칩니다.
} // 메인 화면 반응형 레이아웃 확장을 마칩니다.

Future<T?> _showSlidePopupMenu<T>({ // 슬라이드 업/다운 팝업 메뉴를 표시하는 함수를 정의합니다.
  required BuildContext context, // 현재 컨텍스트를 받습니다.
  required Rect rect, // 앵커 위치를 받습니다.
  required Size overlaySize, // 오버레이 전체 크기를 받습니다.
  required List<T> items, // 메뉴 항목 목록을 받습니다.
  required T value, // 현재 선택 값을 받습니다.
  required double itemHeight, // 항목 높이를 받습니다.
  required TextStyle menuTextStyle, // 메뉴 텍스트 스타일을 받습니다.
  required Color menuBg, // 메뉴 배경색을 받습니다.
  required double menuMinWidth, // 메뉴 최소 너비를 받습니다.
  required double menuMaxWidth, // 메뉴 최대 너비를 받습니다.
  required Widget Function(BuildContext, T) buildItem, // 항목 빌더를 받습니다.
}) async { // 슬라이드 팝업 비동기 함수를 마칩니다.
  final menuW = rect.width.clamp(menuMinWidth, menuMaxWidth).toDouble(); // 실제 메뉴 너비를 계산합니다.
  final menuH = items.length * itemHeight + 12; // 실제 메뉴 높이를 계산합니다.
  final left = (rect.left + rect.width - menuW).clamp(8.0, overlaySize.width - menuW - 8.0); // 메뉴의 좌측 위치를 계산합니다.
  final rawTop = rect.bottom + 8; // 메뉴를 기본적으로 앵커 아래에 배치합니다.
  final top = (rawTop + menuH <= overlaySize.height - 8) ? rawTop : (rect.top - menuH - 8).clamp(8.0, overlaySize.height - menuH - 8.0); // 아래 공간이 부족하면 위로 올립니다.
  return showGeneralDialog<T>( // 커스텀 전환이 가능한 일반 다이얼로그를 띄웁니다.
    context: context, // 현재 컨텍스트를 전달합니다.
    barrierDismissible: true, // 바깥을 탭하면 닫히게 합니다.
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel, // 접근성용 배리어 라벨을 전달합니다.
    barrierColor: Colors.black.withValues(alpha: 0.14), // 배리어 색을 살짝만 적용합니다.
    transitionDuration: const Duration(milliseconds: 180), // 팝업 전환 시간을 지정합니다.
    pageBuilder: (context, ani, sec) { // 실제 메뉴 오버레이를 빌드합니다.
      return Stack( // 오버레이 전체를 스택으로 구성합니다.
        children: [ // 배리어와 메뉴를 나열합니다.
          Positioned( // 메뉴를 계산된 위치에 배치합니다.
            left: left, // 메뉴 좌측 위치를 적용합니다.
            top: top, // 메뉴 상단 위치를 적용합니다.
            width: menuW, // 메뉴 너비를 적용합니다.
            child: _SlideMenu<T>( // 실제 메뉴 패널 위젯을 렌더링합니다.
              items: items, // 메뉴 항목 목록을 전달합니다.
              value: value, // 현재 선택 값을 전달합니다.
              itemHeight: itemHeight, // 항목 높이를 전달합니다.
              menuTextStyle: menuTextStyle, // 텍스트 스타일을 전달합니다.
              menuBg: menuBg, // 메뉴 배경색을 전달합니다.
              buildItem: buildItem, // 항목 빌더를 전달합니다.
            ), // 실제 메뉴 패널 렌더링을 마칩니다.
          ), // 메뉴 위치 배치를 마칩니다.
        ], // 오버레이 요소 나열을 마칩니다.
      ); // 메뉴 오버레이 스택 반환을 마칩니다.
    }, // 메뉴 오버레이 빌드를 마칩니다.
    transitionBuilder: (context, ani, sec, child) { // 슬라이드 업/다운 전환을 정의합니다.
      final fade = CurvedAnimation(parent: ani, curve: Curves.easeOutCubic); // 페이드 곡선을 만듭니다.
      final slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(fade); // 아래에서 위로 올라오는 슬라이드를 만듭니다.
      return FadeTransition(opacity: fade, child: SlideTransition(position: slide, child: child)); // 페이드와 슬라이드를 함께 적용합니다.
    }, // 슬라이드 전환 구성을 마칩니다.
  ); // 슬라이드 팝업 다이얼로그 호출을 마칩니다.
} // 슬라이드 팝업 메뉴 함수 정의를 마칩니다.

class _SlideMenu<T> extends StatelessWidget { // 슬라이드 팝업 메뉴 패널 위젯을 정의합니다.
  final List<T> items; // 메뉴 항목 목록을 저장합니다.
  final T value; // 현재 선택 값을 저장합니다.
  final double itemHeight; // 항목 높이를 저장합니다.
  final TextStyle menuTextStyle; // 메뉴 텍스트 스타일을 저장합니다.
  final Color menuBg; // 메뉴 배경색을 저장합니다.
  final Widget Function(BuildContext, T) buildItem; // 항목 빌더를 저장합니다.

  const _SlideMenu({ // 슬라이드 팝업 메뉴 생성자를 정의합니다.
    required this.items, // 메뉴 항목 목록을 필수로 받습니다.
    required this.value, // 현재 선택 값을 필수로 받습니다.
    required this.itemHeight, // 항목 높이를 필수로 받습니다.
    required this.menuTextStyle, // 메뉴 텍스트 스타일을 필수로 받습니다.
    required this.menuBg, // 메뉴 배경색을 필수로 받습니다.
    required this.buildItem, // 항목 빌더를 필수로 받습니다.
  }); // 슬라이드 팝업 메뉴 생성자 정의를 마칩니다.

  @override // 스테이트리스 위젯 빌드를 재정의합니다.
  Widget build(BuildContext context) { // 슬라이드 팝업 메뉴 패널을 그립니다.
    return Material( // 메뉴 패널에 머티리얼 효과를 부여합니다.
      color: menuBg, // 메뉴 배경색을 적용합니다.
      elevation: 14, // 떠 있는 메뉴 느낌을 위한 그림자를 적용합니다.
      borderRadius: BorderRadius.circular(20), // 메뉴 모서리를 둥글게 만듭니다.
      child: Padding( // 메뉴 내부에 얇은 패딩을 적용합니다.
        padding: const EdgeInsets.symmetric(vertical: 6), // 상하 패딩만 적용합니다.
        child: Column( // 메뉴 항목들을 세로로 나열합니다.
          mainAxisSize: MainAxisSize.min, // 필요한 높이만 사용합니다.
          children: items.map((e) { // 전달된 항목 목록을 순회합니다.
            final sel = e == value; // 현재 항목이 선택값인지 계산합니다.
            return InkWell( // 각 메뉴 항목에 터치 반응을 부여합니다.
              onTap: () => Navigator.of(context).pop(e), // 탭 시 해당 값을 반환하며 닫습니다.
              borderRadius: BorderRadius.circular(14), // 항목별 터치 반경을 둥글게 만듭니다.
              child: Container( // 각 항목의 실제 영역을 만듭니다.
                height: itemHeight, // 항목 높이를 적용합니다.
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // 항목 사이 여백을 적용합니다.
                decoration: BoxDecoration( // 선택 상태 배경을 정의합니다.
                  color: sel ? Colors.white.withValues(alpha: 0.08) : Colors.transparent, // 선택된 항목만 은은한 배경을 적용합니다.
                  borderRadius: BorderRadius.circular(14), // 선택 배경도 둥글게 만듭니다.
                ), // 항목 장식 구성을 마칩니다.
                child: DefaultTextStyle( // 메뉴 공통 텍스트 스타일을 적용합니다.
                  style: menuTextStyle, // 전달받은 메뉴 텍스트 스타일을 적용합니다.
                  child: Center(child: buildItem(context, e)), // 전달받은 항목 위젯을 가운데 배치합니다.
                ), // 항목 공통 텍스트 스타일 적용을 마칩니다.
              ), // 각 항목 영역 구성을 마칩니다.
            ); // 각 메뉴 항목 렌더링을 마칩니다.
          }).toList(), // 메뉴 항목 목록 생성을 마칩니다.
        ), // 메뉴 항목 세로 나열을 마칩니다.
      ), // 메뉴 내부 패딩 구성을 마칩니다.
    ); // 슬라이드 팝업 메뉴 패널 반환을 마칩니다.
  } // 슬라이드 팝업 메뉴 패널 빌드를 마칩니다.
} // 슬라이드 팝업 메뉴 패널 위젯 정의를 마칩니다.
