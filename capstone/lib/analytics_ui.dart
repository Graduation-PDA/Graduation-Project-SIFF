import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'translation_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String selectedDistrict = 'All'; // 현재 선택된 구
  Map<String, int> crimeStats = {};
  Map<String, List<int>> monthlyTrends = {};
  bool isLoading = true;

  final List<String> districts = [
    'All',
    'Gangnam-gu',
    'Gangdong-gu',
    'Gangbuk-gu',
    'Gangseo-gu',
    'Gwanak-gu',
    'Gwangjin-gu',
    'Guro-gu',
    'Geumcheon-gu',
    'Nowon-gu',
    'Dobong-gu',
    'Dongdaemun-gu',
    'Dongjak-gu',
    'Mapo-gu',
    'Seodaemun-gu',
    'Seocho-gu',
    'Seongdong-gu',
    'Seongbuk-gu',
    'Songpa-gu',
    'Yangcheon-gu',
    'Yeongdeungpo-gu',
    'Yongsan-gu',
    'Eunpyeong-gu',
    'Jongno-gu',
    'Jung-gu',
    'Jungnang-gu'
  ];

  final Map<String, String> districtNameMap = {
    'Gangnam-gu': '강남구',
    'Gangdong-gu': '강동구',
    'Gangbuk-gu': '강북구',
    'Gangseo-gu': '강서구',
    'Gwanak-gu': '관악구',
    'Gwangjin-gu': '광진구',
    'Guro-gu': '구로구',
    'Geumcheon-gu': '금천구',
    'Nowon-gu': '노원구',
    'Dobong-gu': '도봉구',
    'Dongdaemun-gu': '동대문구',
    'Dongjak-gu': '동작구',
    'Mapo-gu': '마포구',
    'Seodaemun-gu': '서대문구',
    'Seocho-gu': '서초구',
    'Seongdong-gu': '성동구',
    'Seongbuk-gu': '성북구',
    'Songpa-gu': '송파구',
    'Yangcheon-gu': '양천구',
    'Yeongdeungpo-gu': '영등포구',
    'Yongsan-gu': '용산구',
    'Eunpyeong-gu': '은평구',
    'Jongno-gu': '종로구',
    'Jung-gu': '중구',
    'Jungnang-gu': '중랑구',
  };

  final List<String> crimeTypes = [
    'Arson',
    'Assault',
    'Robbery',
    'Murder',
    'Sexual Violence',
    'Drug'
  ];

  final Map<String, Color> crimeColors = {
    'Arson': Colors.orange,
    'Assault': Colors.blue,
    'Robbery': Colors.green,
    'Murder': Colors.red,
    'Sexual Violence': Colors.purple,
    'Drug': Colors.teal,
  };

  @override
  void initState() {
    super.initState();
    loadCrimeStatistics();
  }

  Future<void> loadCrimeStatistics() async {
    setState(() => isLoading = true);

    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('map_marker').get();

      Map<String, int> stats = {};
      Map<String, List<int>> trends = {};

      // 범죄 유형별 통계 초기화
      for (String type in crimeTypes) {
        stats[type] = 0;
        trends[type] = List.filled(12, 0); // 12개월
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final crimeType = data['Crime Type'] ?? '';
        final address = data['Address'] ?? '';
        String selectedKorDistrict = selectedDistrict == 'All'
            ? 'All'
            : (districtNameMap[selectedDistrict] ?? selectedDistrict);

        final timeStr = data['Time'] ?? '';

        // 구 필터링 (selectedDistrict가 'All'이 아닌 경우)
        if (selectedKorDistrict != 'All' && address != selectedKorDistrict) {
          continue;
        }
        // 범죄 유형별 카운트
        if (crimeTypes.contains(crimeType)) {
          stats[crimeType] = (stats[crimeType] ?? 0) + 1;

          // 월별 추세 (시간 데이터가 있는 경우)
          if (timeStr.isNotEmpty) {
            try {
              final month = _extractMonth(timeStr);
              if (month >= 1 && month <= 12) {
                trends[crimeType]![month - 1]++;
              }
            } catch (e) {
              // 시간 파싱 실패 시 무시
            }
          }
        }
      }

      setState(() {
        crimeStats = stats;
        monthlyTrends = trends;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('통계 로딩 실패: $e');
      setState(() => isLoading = false);
    }
  }

  int _extractMonth(String timeStr) {
    // "2024.08.29. PM 11:03"와 같이 .으로 구분된 날짜에서 월 추출
    try {
      final regex = RegExp(r'(\d{4})\.(\d{2})\.(\d{2})');
      final match = regex.firstMatch(timeStr);
      if (match != null) {
        return int.parse(match.group(2)!);
      }
    } catch (e) {}
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          'Crime Statistics Analysis',
          source: 'en',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white30,
        scrolledUnderElevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              // SingleChildScrollView로 감싸기
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 구 선택 드롭다운
                  _buildDistrictSelector(),
                  const SizedBox(height: 24),

                  // 범죄 유형별 통계 카드
                  _buildCrimeStatsCards(),
                  const SizedBox(height: 24),

                  // 월간 추세 막대 그래프
                  _buildMonthlyTrendsChart(),
                ],
              ),
            ),
    );
  }

  Widget _buildDistrictSelector() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.blue),
          const SizedBox(width: 8),
          const TranslatedText(
            'Select District: ',
            source: 'en',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: DropdownButton<String>(
              value: selectedDistrict,
              isExpanded: true,
              items: districts.map((district) {
                return DropdownMenuItem(
                  value: district,
                  child: TranslatedText(
                    district,          
                    source: 'en',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedDistrict = value);
                  loadCrimeStatistics();
                }
              },
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCrimeStatsCards() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const TranslatedText(
        'Crime Incidents by Type',
        source: 'en',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.0,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: crimeTypes.length,
        itemBuilder: (context, index) {
          final type = crimeTypes[index];
          final count = crimeStats[type] ?? 0;
          final color = crimeColors[type] ?? Colors.grey;

          return Card(
            color: color.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: TranslatedText(
                      type,                    // 'Arson', 'Assault' 등
                      source: 'en',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: TranslatedText(
                      '$count cases',          // 동적 문자열도 한 덩어리로 번역
                      source: 'en',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}


  Widget _buildMonthlyTrendsChart() {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatedText(
            'Monthly Crime Trends',
            source: 'en',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxMonthlyCount().toDouble(),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 2,
                      getTitlesWidget: (value, meta) {
                        const months = [
                          'Jan','Feb','Mar','Apr','May','Jun',
                          'Jul','Aug','Sep','Oct','Nov','Dec'
                        ];
                        final idx = value.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TranslatedText(
                              months[idx],
                              source: 'en',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value % 10 == 0) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(fontSize: 10, color: Colors.black),
                            textAlign: TextAlign.left,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (index) {
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: _getTotalForMonth(index).toDouble(),
                        color: Colors.blue,
                        width: 16,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  int _getMaxMonthlyCount() {
    int max = 0;
    for (int i = 0; i < 12; i++) {
      final total = _getTotalForMonth(i);
      if (total > max) max = total;
    }
    return max + 1;
  }

  int _getTotalForMonth(int monthIndex) {
    int total = 0;
    for (String type in crimeTypes) {
      final trends = monthlyTrends[type];
      if (trends != null && monthIndex < trends.length) {
        total += trends[monthIndex];
      }
    }
    return total;
  }
}
