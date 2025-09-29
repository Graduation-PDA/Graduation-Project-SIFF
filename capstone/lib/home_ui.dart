import 'package:flutter/material.dart';
import 'home_back.dart';
import 'community_ui.dart';
import 'usersetting_ui.dart';
import 'message_ui.dart';
import 'report_ui.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'analytics_ui.dart';
import 'app_language.dart';
import 'localizedtext.dart';
import 'translation_service.dart';
import 'chat_bot_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;
  bool _isFilterExpanded = false;
  NLatLng? lastCameraPosition;

  final GlobalKey<HomeMapPageState> _mapKey = GlobalKey<HomeMapPageState>();

  final List<Map<String, dynamic>> _filterTypes = [
    {
      'name': 'Arson',
      'icon': Icons.local_fire_department,
      'color': Colors.orange
    },
    {'name': 'Assault', 'icon': Icons.dangerous, 'color': Colors.blue},
    {'name': 'Robbery', 'icon': Icons.monetization_on, 'color': Colors.green},
    {'name': 'Murder', 'icon': 'assets/swords.png', 'color': Colors.red},
    {'name': 'Sexual Violence', 'icon': Icons.warning, 'color': Colors.purple},
    {'name': 'Drug', 'icon': Icons.medication, 'color': Colors.teal},
  ];
  late List<bool> _filterSelected;
  List<String> selectedFilters = [];

  String _labelMessage = 'MESSAGE';
  String _labelHome = 'HOME';
  String _labelCommunity = 'COMMUNITY';
  

  @override
  void initState() {
    super.initState();
    _filterSelected = List.filled(_filterTypes.length, false);
    _translateNavLabels();
    mapLanguageNotifier.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    mapLanguageNotifier.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
  _translateNavLabels(); // MESSAGE/HOME/COMMUNITY 라벨 다시 번역
  if (mounted) setState(() {});
}

  Future<void> _translateNavLabels() async {
  final lang = mapLanguageNotifier.value;
  final m = await translateText('MESSAGE', source: 'en', to: lang);
  final h = await translateText('HOME',    source: 'en', to: lang);
  final c = await translateText('COMMUNITY', source: 'en', to: lang);

  if (!mounted) return;
  setState(() {
    _labelMessage   = m;
    _labelHome      = h;
    _labelCommunity = c;
  });
}

  void _toggleFilterExpansion() =>
      setState(() => _isFilterExpanded = !_isFilterExpanded);

  // 필터 선택 함수
  void _onFilterSelected(int idx) {
    setState(() {
      _filterSelected[idx] = !_filterSelected[idx];
      selectedFilters = List.generate(_filterTypes.length, (i) {
        if (_filterSelected[i]) return _filterTypes[i]['name'] as String;
        return null;
      }).whereType<String>().toList();
    });
    // HomeMapPage의 마커 갱신
    _mapKey.currentState?.loadMarkers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.white30,
        leadingWidth: 96, // 88에서 96으로 늘림
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 기존 햄버거 메뉴 (Drawer)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
                padding: const EdgeInsets.only(left: 8, right: 0), // 오른쪽 패딩 제거
              ),
            ),
            // 통계 아이콘 추가
            IconButton(
              icon: const Icon(Icons.equalizer),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                );
              },
            ),
          ],
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        actions: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline),
          tooltip: "AI 챗봇",
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatBotScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.person),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserSettingScreen()),
            );
          },
        ),
      ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              MessageScreen(),
              HomeMapPage(
                key: _mapKey, // GlobalKey 연결
                selectedFilters: selectedFilters,
                initialCameraPosition: lastCameraPosition,
                onCameraIdle: (pos) {
                  lastCameraPosition = pos;
                },
              ),
              const CommunityScreen(),
            ],
          ),
          if (_selectedIndex == 1)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  FloatingActionButton(
                    mini: true,
                    backgroundColor: Colors.white,
                    heroTag: "home_filter_button", // 고유 태그
                    onPressed: _toggleFilterExpansion,
                    child: const Icon(Icons.filter_list, color: Colors.black),
                  ),
                  if (_isFilterExpanded)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_filterTypes.length, (i) {
                            final f = _filterTypes[i];
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                avatar: f['icon'] is IconData
                                    ? Icon(
                                        f['icon'] as IconData,
                                        color: Colors.black, // 모든 아이콘을 검정색으로
                                      )
                                    : SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: Image.asset(
                                          f['icon'] as String,
                                          color:
                                              Colors.black, // 흑백 PNG라면 검정색 적용
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                label: LocalizedText(original: f['name'] as String),
                                selected: _filterSelected[i],
                                onSelected: (_) => _onFilterSelected(i),
                                selectedColor: _filterSelected[i]
                                    ? (f['color'] as Color).withOpacity(0.2)
                                    : null,
                                checkmarkColor: f['color'] as Color,
                                backgroundColor: Colors.grey[200],
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.warning), label: _labelMessage),
          BottomNavigationBarItem(icon: const Icon(Icons.home),    label: _labelHome),
          BottomNavigationBarItem(icon: const Icon(Icons.people),  label: _labelCommunity),
        ],
        onTap: (idx) => setState(() => _selectedIndex = idx),
      ),
    );
  }

   Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 40),

          _drawerItem(const LocalizedText(original: '• Home'), () {
            setState(() => _selectedIndex = 1);
            Navigator.pop(context);
          }, bold: true),

          _drawerItem(const LocalizedText(original: '• Emergency Disaster Message'), () {
            setState(() => _selectedIndex = 0);
            Navigator.pop(context);
          }),

          _drawerItem(const LocalizedText(original: '• Community'), () {
            setState(() => _selectedIndex = 2);
            Navigator.pop(context);
          }),

          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: _drawerItem(const LocalizedText(original: '· Incident Report'), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportUI()));
            }),
          ),

          _drawerItem(const LocalizedText(original: '• Settings'), () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSettingScreen()));
          }),
        ],
      ),
    );
  }

  // label을 Widget으로 받아서 LocalizedText 사용 가능하도록 변경
  Widget _drawerItem(Widget label, VoidCallback onTap, {bool bold = false}) {
    return ListTile(
      title: DefaultTextStyle.merge(
        style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        child: label,
      ),
      onTap: onTap,
    );
  }
}