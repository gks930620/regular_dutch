// ✅ main.dart
import 'package:flutter/material.dart';
import 'group_db_helper.dart';
import 'screens/post_list_screen.dart'; // 목록화면 import
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //fluter main 초반에 엔진초기화.    밑의  GroupDatabaseHelper().resetDB()에서
  // getDatabasesPath() 같은 Flutter의 플랫폼 채널과 연동되는 기능은, Flutter 엔진이 초기화되기 전에는 호출하면 안 됨.
  //await GroupDatabaseHelper().resetDB(); // 개발 중 DB 초기화.  배포때는 없어야함

  print('[앱 시작] dotenv 로딩 중...');
  await dotenv.load(); // ⬅️ 반드시 async로
  print('[앱 시작] dotenv 로딩 완료');

  print('[앱 시작] 공휴일 최신화 시작...');
  await refreshHolidaysIfNeeded(); // 공휴일 최신화
  print('[앱 시작] 공휴일 최신화 완료');

  runApp(MyApp());
}

/// 공휴일 DB 최신화:
/// - 최초 실행 시 또는 연도가 바뀌었을 때만 API 호출
/// - 범위: 현재년도-5 ~ 현재년도+10 (총 16년치)
/// - 예: 2025년이면 2020~2035년 공휴일 저장
Future<void> refreshHolidaysIfNeeded() async {
  try {
    final db = GroupDatabaseHelper();
    final lastUpdate = await db.getLastHolidayUpdate();
    final now = DateTime.now();
    final currentYear = now.year;

    // 마지막 업데이트 연도 추출 (없으면 0)
    final lastUpdateYear = lastUpdate != null
        ? DateTime.fromMillisecondsSinceEpoch(lastUpdate).year
        : 0;

    print('[공휴일] 현재 연도: $currentYear, 마지막 업데이트 연도: ${lastUpdateYear == 0 ? "없음" : lastUpdateYear}');

    // DB에 저장된 공휴일 개수 확인
    final existingHolidays = await db.getAllHolidayDates();
    print('[공휴일] DB에 현재 ${existingHolidays.length}개 저장되어 있음');

    // 최초 실행(데이터 없음)이거나, 연도가 바뀌었으면 갱신
    if (existingHolidays.isEmpty || lastUpdate == null || currentYear > lastUpdateYear) {
      print('[공휴일] 업데이트 시작... (${currentYear - 5}년 ~ ${currentYear + 10}년)');
      Map<String, Map<String, dynamic>> holidayMap = {};

      // API 키 가져오기 (디코딩된 키가 있으면 우선 사용)
      String apiKey = dotenv.env['PUBLIC_API_KEY_DECODED'] ?? dotenv.env['PUBLIC_API_KEY'] ?? '';

      if (apiKey.isEmpty) {
        print('[공휴일 오류] API 키가 없습니다. .env 파일을 확인하세요.');
        return;
      }

      print('[공휴일] API 키 확인 완료 (길이: ${apiKey.length}자)');

      final startYear = currentYear - 5;
      final endYear = currentYear + 10;

      for (int year = startYear; year <= endYear; year++) {
        print('[공휴일] $year년 데이터 요청 중...');

        final url =
            'https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo'
            '?serviceKey=$apiKey'
            '&solYear=$year'
            '&numOfRows=100'
            '&_type=json';

        try {
          final response = await http.get(Uri.parse(url));
          print('[공휴일] $year년 응답 코드: ${response.statusCode}');

          if (response.statusCode == 200) {
            final body = jsonDecode(response.body);

            // API 에러 응답 확인
            final resultCode = body['response']?['header']?['resultCode'];
            final resultMsg = body['response']?['header']?['resultMsg'];

            if (resultCode != null && resultCode != '00') {
              print('[공휴일 오류] $year년 API 에러: [$resultCode] $resultMsg');
              continue;
            }

            final items = body['response']?['body']?['items'];

            if (items == null) {
              print('[공휴일] $year년 데이터 없음');
              continue;
            }

            final List holidays = items['item'] is List ? items['item'] : [items['item']];
            print('[공휴일] $year년 공휴일 ${holidays.length}개 발견');

            for (final item in holidays) {
              if (item is! Map || !item.containsKey('locdate')) continue;
              final dateStr = item['locdate'].toString();
              if (dateStr.length != 8) continue;
              final name = item['dateName']?.toString() ?? '';
              final key = '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}';
              holidayMap[key] = {
                'holiday_date': key,
                'name': name,
                'last_updated': now.millisecondsSinceEpoch,
              };
            }
          } else {
            print('[공휴일 오류] $year년 API 호출 실패: ${response.statusCode}');
            print('[공휴일 오류] 응답 본문: ${response.body}');
          }
        } catch (e) {
          print('[공휴일 오류] $year년 처리 중 예외: $e');
        }
      }

      final allHolidays = holidayMap.values.toList();
      if (allHolidays.isNotEmpty) {
        await db.saveHolidays(allHolidays);
        print('[공휴일] ✅ DB 최신화 완료 (${allHolidays.length}건)');
        // 저장된 데이터 샘플 확인
        if (allHolidays.length > 0) {
          print('[공휴일] 샘플: ${allHolidays.first}');
        }
      } else {
        print('[공휴일 오류] 수집된 데이터가 없습니다.');
      }
    } else {
      print('[공휴일] 최신 상태 (같은 연도 내 갱신 불필요)');
      // 현재 DB에 저장된 공휴일 개수 확인
      final holidays = await db.getAllHolidayDates();
      print('[공휴일] DB에 ${holidays.length}개 저장되어 있음');
    }
  } catch (e) {
    print('[공휴일 오류] 전체 처리 실패: $e');
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // debug 배너 숨김
      title: '그룹 멤버 등록 앱',
      theme: ThemeData(primarySwatch: Colors.purple),
      home: PostListScreen(), // 첫 진입화면
    );
  }
}