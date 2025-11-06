import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../group_db_helper.dart';
import 'member_payment_history_screen.dart';

//해야될게 있으면 해야지  딴 생각하지말고.  졸려 뒤지겄소.

// 그룹 상세 화면 위젯
class GroupDetailScreen extends StatefulWidget {
  final int groupId; // 선택된 그룹의 ID
  const GroupDetailScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  String _groupName = ''; // 그룹 이름
  List<String> _members = []; // 그룹 멤버 리스트
  Map<DateTime, String> paymentRecords = {}; // 날짜별 결제자 기록 (달력 표시용)
  List<Map<String, dynamic>> allPayments = []; // 전체 결제 기록 (특별 결제 포함, 결제횟수 계산용)
  //처음에 DB에서 select,  이후 Map 직접 put + DB insert만.   DBselect는 맨 처음에만 하는거

  Set<DateTime> _holidays = {}; // DB에서 불러온 공휴일 집합
  DateTime _focusedDay = DateTime
      .now(); // 현재 포커스된 날짜   Caledndars는 이 focusedDay를 가지고 해당 월의 달력을 만듬.
  DateTime? _selectedDay; // 선택된 날짜 (nullable)

  @override
  void initState() {
    super.initState();

    //작업이 오래걸리는 일들은 여기서 해야 build하고 나서 작업이 일어남.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroup();
      _loadPayments();
      _loadHolidaysFromDB(); // 공휴일 DB에서만 불러오기
    });
  }

  // 날짜를 yyyy-MM-dd 형태로 정규화 (시간 제거)
  DateTime normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  // DateTime normalizeDate(DateTime date){   이렇게 간단히 한줄로 할수있는 메소드는 위의 람다식처럼 표현..   어쨋든 메소드임
  //   return DateTime(date.year, date.month, date.day);
  // }




  // 그룹 정보 불러오기
  Future<void> _loadGroup() async {
    final data =
    await GroupDatabaseHelper().getGroup(widget.groupId); //기본 제공 widget 객체
    if (data != null) {
      setState(() {
        _groupName = data['name'] ?? '이름 없음';
        _members = List<String>.from(data['members']);
      });
    }
  }

  Future<void> _loadPayments() async {
    final db = GroupDatabaseHelper();

    // DB에서 전체 결제 기록 조회 (getPayments는 Map<DateTime, String> 반환)
    final paymentsMap = await db.getPayments(widget.groupId);

    // 특별 결제(1900년 날짜)와 일반 결제 분리
    final Map<DateTime, String> normalPayments = {};
    final List<Map<String, dynamic>> allPaymentsList = [];

    paymentsMap.forEach((date, member) {
      // 1900년 날짜는 특별 결제
      if (date.year == 1900) {
        allPaymentsList.add({'date': date, 'member': member});
      } else {
        // 정상 날짜는 달력 표시용
        normalPayments[date] = member;
        allPaymentsList.add({'date': date, 'member': member});
      }
    });

    setState(() {
      paymentRecords = normalPayments;
      allPayments = allPaymentsList;
    });
  }

  //db에 있는걸로 뭘 할까? ....
  //

  // 공휴일 DB에서 불러오기
  Future<void> _loadHolidaysFromDB() async {
    final dates = await GroupDatabaseHelper().getAllHolidayDates();
    print('[상세화면] 공휴일 ${dates.length}개 로드됨');
    if (dates.isNotEmpty) {
      print('[상세화면] 공휴일 샘플: ${dates.take(3).toList()}');
    }
    setState(() {
      _holidays = dates.map((d) => normalizeDate(d)).toSet();
    });
    print('[상세화면] 정규화된 공휴일 ${_holidays.length}개');
  }

  // 특별 결제 버튼 클릭 시 실행되는 함수
  Future<void> _onSpecialPayment() async {
    String? selectedMember;
    final TextEditingController reasonController = TextEditingController();

    // 날짜 선택 초기값 (오늘)
    final now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    int selectedDay = now.day;

    // 날짜 선택 범위
    final years = List.generate(10, (i) => now.year - 5 + i); // 현재 기준 -5~+4년
    final months = List.generate(12, (i) => i + 1); // 1~12월
    List<int> days = List.generate(
      DateTime(selectedYear, selectedMonth + 1, 0).day,
      (i) => i + 1
    ); // 해당 월의 일수

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 월 변경 시 일수 재계산
            days = List.generate(
              DateTime(selectedYear, selectedMonth + 1, 0).day,
              (i) => i + 1
            );
            // 선택된 일이 새 월의 최대 일수를 넘으면 조정
            if (selectedDay > days.length) {
              selectedDay = days.length;
            }

            return AlertDialog(
              title: Text('특별 결제'),
              contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜 선택
                    Text('날짜 선택', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 년도
                        DropdownButton<int>(
                          value: selectedYear,
                          items: years.map((y) => DropdownMenuItem(
                            value: y,
                            child: Text('$y년'),
                          )).toList(),
                          onChanged: (value) {
                            selectedYear = value!;
                            setDialogState(() {});
                          },
                        ),
                        // 월
                        DropdownButton<int>(
                          value: selectedMonth,
                          items: months.map((m) => DropdownMenuItem(
                            value: m,
                            child: Text('$m월'),
                          )).toList(),
                          onChanged: (value) {
                            selectedMonth = value!;
                            setDialogState(() {});
                          },
                        ),
                        // 일
                        DropdownButton<int>(
                          value: selectedDay,
                          items: days.map((d) => DropdownMenuItem(
                            value: d,
                            child: Text('$d일'),
                          )).toList(),
                          onChanged: (value) {
                            selectedDay = value!;
                            setDialogState(() {});
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Divider(),
                    SizedBox(height: 8),

                    // 멤버 선택
                    Text('멤버 선택', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    ..._members.map((member) => InkWell(
                      onTap: () {
                        selectedMember = member;
                        setDialogState(() {});
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: selectedMember == member ? Colors.blue.shade50 : null,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedMember == member
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: selectedMember == member ? Colors.blue : Colors.grey,
                            ),
                            SizedBox(width: 12),
                            Text(
                              member,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: selectedMember == member
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                    SizedBox(height: 16),

                    // 사유 입력
                    Text('사유', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      maxLength: 50,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: '예: 커피 대신 점심 쐈음',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedMember != null && reasonController.text.trim().isNotEmpty) {
                      Navigator.pop(context, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('멤버와 사유를 모두 입력해주세요')),
                      );
                    }
                  },
                  child: Text('확인'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && selectedMember != null) {
      final reason = reasonController.text.trim();
      final selectedDate = DateTime(selectedYear, selectedMonth, selectedDay);

      // 특별 결제는 고유한 timestamp를 포함한 특수 날짜 사용 (중복 방지)
      // 1900년 + 현재 밀리초를 일(day) 단위로 변환하여 고유한 날짜 생성
      final uniqueDay = 1 + (DateTime.now().millisecondsSinceEpoch % 365); // 1~365 범위
      final specialDate = DateTime(1900, 1, uniqueDay, selectedDate.hour, selectedDate.minute, selectedDate.second);

      // member 컬럼에 "멤버명 (특별: 날짜 - 사유)" 형식으로 저장
      final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      final recordText = '$selectedMember (특별: $dateStr - $reason)';

      // DB에 저장 (고유 날짜이므로 기존 특별 결제 삭제 안 됨)
      await GroupDatabaseHelper().setPayment(widget.groupId, specialDate, recordText);

      // allPayments에 즉시 추가 (화면 갱신)
      setState(() {
        allPayments.add({'date': specialDate, 'member': recordText});
      });

      // 성공 메시지
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$selectedMember 님의 특별 결제가 기록되었습니다 ($dateStr, 결제횟수 +1)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }

    // TextField와 키보드가 완전히 정리된 후 controller dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reasonController.dispose();
    });
  }

  // 날짜 클릭 시 실행되는 콜백
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    //TableCalendar 위젯이 정해놓은 콜백 함수 타입.

    final normalized = normalizeDate(selectedDay); //yyyy-MM-dd 문자열
    final existingMember = paymentRecords[normalized]; // 기존 결제자 확인

    // 멤버 선택 다이얼로그 표시
    final TextEditingController _customNameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? selectedMemberName; // 로컬 변수로 관리

        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${normalized.year}-${normalized.month}-${normalized.day}"),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context, null),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 기존 결제자가 있으면 현재 상태 표시
                if (existingMember != null) ...[
                  Text(
                    '현재: $existingMember',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 12),
                  Divider(),
                  SizedBox(height: 8),
                ],

                // 멤버 목록 (SimpleDialogOption으로 변경)
                Text('멤버 선택', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                ..._members.map((member) => InkWell(
                  onTap: () {
                    Navigator.pop(context, member);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Text(
                      member,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                )),

                SizedBox(height: 16),
                Divider(),
                SizedBox(height: 8),

                // 직접 입력
                Text('직접 입력', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                TextField(
                  controller: _customNameController,
                  maxLength: 15,
                  decoration: InputDecoration(
                    hintText: '이름 입력',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // 하단 버튼 배치
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 왼쪽: 직접 입력으로 선택 버튼
                ElevatedButton.icon(
                  onPressed: () {
                    final customInput = _customNameController.text.trim();
                    if (customInput.isNotEmpty) {
                      Navigator.pop(context, customInput);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('이름을 입력해주세요')),
                      );
                    }
                  },
                  icon: Icon(Icons.check),
                  label: Text('입력'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),

                // 오른쪽: 삭제 또는 취소 버튼
                if (existingMember != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      // 삭제 확인 다이얼로그
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('삭제 확인'),
                          content: Text('${normalized.year}-${normalized.month}-${normalized.day} 결제 기록을 삭제하시겠습니까?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('취소')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              child: Text('삭제'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        Navigator.pop(context, '__DELETE__');
                      }
                    },
                    icon: Icon(Icons.delete, color: Colors.red),
                    label: Text('삭제', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red),
                    ),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text('취소'),
                  ),
              ],
            ),
          ],
        );
      },
    );

    //여기까지 했으면 멤버선택됐고 날짜도 선택됐으니까 마지막에 다시 setState를 하면 현재 날짜가 뜨는게 맞인데...

    // 선택된 멤버 기록 또는 삭제 처리
    if (result != null) {
      final selectedMember = result;
      if (selectedMember == '__DELETE__') {
        // 삭제 처리 (확인 후 이 코드가 실행됨)
        setState(() {
          _selectedDay = normalized;
          paymentRecords.remove(normalized);

          // allPayments에서도 제거
          allPayments.removeWhere((payment) =>
            payment['date'] is DateTime &&
            isSameDay(payment['date'], normalized)
          );
        });

        // DB에서 삭제
        final db = await GroupDatabaseHelper().database;
        final dateStr = normalized.toIso8601String().split('T').first;
        await db.delete(
          'payments',
          where: 'group_id = ? AND date = ?',
          whereArgs: [widget.groupId, dateStr],
        );

        // 삭제 완료 메시지
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${normalized.year}-${normalized.month}-${normalized.day} 결제 기록이 삭제되었습니다'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // 일반 멤버 선택 (추가/변경)
        setState(() {
          _selectedDay = normalized;
          paymentRecords[normalized] = selectedMember;

          // allPayments에도 추가/업데이트 (결제횟수 즉시 반영)
          // 기존 같은 날짜 기록 제거
          allPayments.removeWhere((payment) =>
            payment['date'] is DateTime &&
            isSameDay(payment['date'], normalized)
          );
          // 새 기록 추가
          allPayments.add({'date': normalized, 'member': selectedMember});
        });

        await GroupDatabaseHelper().setPayment(widget.groupId, normalized, selectedMember);
      }
    }
  }


  Widget _buildDowCell(BuildContext context, DateTime day) {
    final text = ['일', '월', '화', '수', '목', '금', '토'][day.weekday % 7];
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: day.weekday == DateTime.sunday ? Colors.red : Colors.grey[600],
        ),
      ),
    );
  }
  Text makeText(DateTime curDay , bool isHoliday , bool isToday) {
    // 오늘 -> 보라색 굵게.
    //공휴일 -> 빨간색표시,
    if( isToday){
      return Text(
          '${curDay.day}',
          style: TextStyle(
              color: Colors.purple,
            fontWeight: FontWeight.bold
          )
      );
    }

    if(isHoliday){
      return Text(
        '${curDay.day}',
        style: TextStyle(
            color: Colors.red
        )
      );
    }

    //그냥 평범한 날
    return Text(
        '${curDay.day}'
    );

  }

  Widget _basicMakeCalendarBuilder(BuildContext context, DateTime curDay,
      DateTime focusedDay) {
    final normalized = normalizeDate(curDay);
    final isHoliday = _holidays.contains(normalized);
    final member = paymentRecords[normalized]; //키 : 날짜,  value : 그 날짜의 계산자 멤버
    final isToday= isSameDay(DateTime.now(), curDay);
    Text dayText = makeText(curDay , isHoliday, isToday);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dayText,
        if (member != null) // 현재 날짜에 멤버가 있다면 멤버표시
          Text(
            member,
            style: TextStyle(fontSize: 10, color: Colors.purple),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(7, (i) => currentYear - 5 + i); // 현재 연도 기준 -5~+1년
    final months = List.generate(12, (i) => i + 1); // 1~12월

    // 결제횟수 계산 (allPayments 사용 - 특별 결제 포함)
    Map<String, int> paymentCountByMember = {};
    for (final member in _members) {
      paymentCountByMember[member] = 0;
    }

    // allPayments에서 멤버 이름 추출하여 카운팅
    for (final payment in allPayments) {
      String memberName = payment['member'];

      // "멤버명 (특별: 사유)" 형식에서 멤버명만 추출
      if (memberName.contains('(특별:')) {
        memberName = memberName.split('(특별:')[0].trim();
      }

      if (paymentCountByMember.containsKey(memberName)) {
        paymentCountByMember[memberName] = paymentCountByMember[memberName]! + 1;
      }
    }

    final minCount = paymentCountByMember.values.isNotEmpty
        ? paymentCountByMember.values.reduce((a, b) => a < b ? a : b)
        : 0;
    final nextPayer = _members.isNotEmpty
        ? _members.firstWhere(
            (m) => paymentCountByMember[m] == minCount,
            orElse: () => '',
          )
        : '';


    //detail 화면 들어가기전에 잠깐 에러나고 가네... 이거 확인하자.. minCount 다음결제자 하면서 생김 

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('📋 $_groupName'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
            // 멤버 목록 헤더와 특별 결제 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('👥 멤버 목록 (${_members.length})',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ElevatedButton.icon(
                  onPressed: _onSpecialPayment,
                  icon: Icon(Icons.add_card, size: 18),
                  label: Text('특별 결제'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: _members.map((m) {
                final count = paymentCountByMember[m] ?? 0;  //null이면 0
                final isNext = m == nextPayer;
                return ActionChip(
                  label: Text('$m ($count)'),
                  backgroundColor: isNext ? Colors.orange.shade200 : null,
                  shape: StadiumBorder(
                    side: isNext
                        ? BorderSide(color: Colors.deepOrange, width: 2)
                        : BorderSide.none,
                  ),
                  onPressed: () async {
                    // 멤버별 결제 내역 화면으로 이동
                    final hasChanges = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MemberPaymentHistoryScreen(
                          groupId: widget.groupId,
                          memberName: m,
                          totalCount: count,
                        ),
                      ),
                    );

                    // 변경사항이 있으면 데이터 다시 로드
                    if (hasChanges == true) {
                      await _loadPayments();
                    }
                  },
                );
              }).toList(),
            ),
            SizedBox(height: 24),
            // 연도, 월 드롭다운 선택 UI
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton<int>(
                  value: _focusedDay.year,
                  items: years
                      .map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y년')))
                      .toList(),
                  onChanged: (year) {
                    if (year != null) {
                      final newDate = DateTime(year, _focusedDay.month);
                      setState(() {
                        _focusedDay = newDate;
                        _loadHolidaysFromDB();
                      });
                    }
                  },
                ),
                SizedBox(width: 16),
                DropdownButton<int>(
                  value: _focusedDay.month,
                  items: months
                      .map(
                          (m) => DropdownMenuItem(value: m, child: Text('$m월')))
                      .toList(),
                  onChanged: (month) {
                    if (month != null) {
                      final newDate = DateTime(_focusedDay.year, month);
                      setState(() {
                        _focusedDay = newDate;
                        _loadHolidaysFromDB();
                      });
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 12),
            // 달력 위젯 (높이 제한 없이 직접 배치)
            TableCalendar(
              rowHeight: 70, // 한 줄 높이 줄임
              daysOfWeekHeight: 28, // 요일 줄 높이도 줄임
              firstDay: DateTime.utc(2015, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (curDay) =>
                  isSameDay(normalizeDate(curDay), _selectedDay),
              onDaySelected: _onDaySelected,
              headerVisible: false,
              calendarFormat: CalendarFormat.month,
              onPageChanged: (newFocusedDay) {
                setState(() {
                  _focusedDay = newFocusedDay;
                });
              },
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(),
                selectedDecoration: BoxDecoration(),
                todayTextStyle: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.purple),
                selectedTextStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              calendarBuilders: CalendarBuilders(
                dowBuilder: (context, curDay) =>
                    _buildDowCell(context, curDay),
                todayBuilder: (buildContext, curDay, foucsedDay) =>
                    _basicMakeCalendarBuilder(
                        buildContext, curDay, foucsedDay),
                selectedBuilder: (buildContext, curDay, foucsedDay) =>
                    _basicMakeCalendarBuilder(
                        buildContext, curDay, foucsedDay),
                defaultBuilder: (buildContext, curDay, foucsedDay) =>
                    _basicMakeCalendarBuilder(
                        buildContext, curDay, foucsedDay),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }


}
