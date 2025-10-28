import 'package:flutter/material.dart';
import '../group_db_helper.dart';

// 멤버별 결제 내역 화면
class MemberPaymentHistoryScreen extends StatefulWidget {
  final int groupId;
  final String memberName;
  final int totalCount; // 총 결제 횟수

  const MemberPaymentHistoryScreen({
    Key? key,
    required this.groupId,
    required this.memberName,
    required this.totalCount,
  }) : super(key: key);

  @override
  _MemberPaymentHistoryScreenState createState() => _MemberPaymentHistoryScreenState();
}

class _MemberPaymentHistoryScreenState extends State<MemberPaymentHistoryScreen> {
  List<Map<String, dynamic>> paymentHistory = [];
  bool isLoading = true;
  bool hasChanges = false; // 데이터 변경 여부 추적
  late int currentTotalCount; // 현재 총 결제 횟수 (삭제 시 갱신)

  @override
  void initState() {
    super.initState();
    currentTotalCount = widget.totalCount; // 초기값 설정
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    final db = GroupDatabaseHelper();
    final allPayments = await db.getPayments(widget.groupId);

    // 해당 멤버의 결제 내역만 필터링
    List<Map<String, dynamic>> memberPayments = [];

    allPayments.forEach((date, member) {
      // 일반 결제: 멤버명이 정확히 일치
      if (member == widget.memberName) {
        memberPayments.add({
          'date': date,
          'type': '일반 결제',
          'displayDate': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'reason': null,
        });
      }
      // 특별 결제: "멤버명 (특별: ...)" 형식
      else if (member.startsWith('${widget.memberName} (특별:')) {
        // "홍길동 (특별: 2025-10-28 - 사유)" 파싱
        final specialInfo = member.substring(member.indexOf('(특별:') + 5, member.length - 1).trim();
        String displayDate = '';
        String? reason;

        if (specialInfo.contains(' - ')) {
          final parts = specialInfo.split(' - ');
          displayDate = parts[0].trim();
          reason = parts.length > 1 ? parts[1].trim() : null;
        } else {
          displayDate = specialInfo;
        }

        memberPayments.add({
          'date': date,
          'type': '특별 결제',
          'displayDate': displayDate,
          'reason': reason,
        });
      }
    });

    // 날짜순 정렬 (최신순)
    memberPayments.sort((a, b) {
      // 특별 결제는 1900년이므로 displayDate의 실제 날짜로 비교
      if (a['type'] == '특별 결제' && b['type'] == '특별 결제') {
        return b['displayDate'].compareTo(a['displayDate']);
      } else if (a['type'] == '특별 결제') {
        return b['date'].compareTo(DateTime.parse(a['displayDate']));
      } else if (b['type'] == '특별 결제') {
        return DateTime.parse(b['displayDate']).compareTo(a['date']);
      } else {
        return b['date'].compareTo(a['date']);
      }
    });

    setState(() {
      paymentHistory = memberPayments;
      isLoading = false;
    });
  }

  // 결제 카드 빌더 메서드
  Widget _buildPaymentCard(Map<String, dynamic> payment, int index, bool isSpecial) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSpecial
                ? Colors.orange.shade100
                : Colors.blue.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSpecial ? Icons.star : Icons.calendar_today,
            color: isSpecial
                ? Colors.orange.shade700
                : Colors.blue.shade700,
          ),
        ),
        title: Text(
          payment['displayDate'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSpecial
                        ? Colors.orange.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    payment['type'],
                    style: TextStyle(
                      fontSize: 12,
                      color: isSpecial
                          ? Colors.orange.shade700
                          : Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (payment['reason'] != null) ...[
              SizedBox(height: 6),
              Text(
                '사유: ${payment['reason']}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: isSpecial
            ? IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  // 삭제 확인 다이얼로그
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('삭제 확인'),
                      content: Text(
                        '${payment['displayDate']} 특별 결제 기록을 삭제하시겠습니까?\n\n사유: ${payment['reason'] ?? '없음'}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('취소'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: Text('삭제'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    // DB에서 삭제
                    final db = await GroupDatabaseHelper().database;
                    final dateStr = (payment['date'] as DateTime)
                        .toIso8601String()
                        .split('T')
                        .first;
                    await db.delete(
                      'payments',
                      where: 'group_id = ? AND date = ?',
                      whereArgs: [widget.groupId, dateStr],
                    );

                    // 로컬 리스트에서 제거 및 화면 갱신
                    setState(() {
                      paymentHistory.removeAt(index);
                      currentTotalCount--; // 총 결제 횟수 감소
                      hasChanges = true; // 변경 사항 표시
                    });

                    // 스낵바 표시
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('특별 결제 기록이 삭제되었습니다'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 뒤로가기 시 변경 여부 반환
        Navigator.pop(context, hasChanges);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.memberName} 결제 내역'),
          backgroundColor: Colors.deepPurple,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context, hasChanges);
            },
          ),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
              children: [
                // 헤더: 총 결제 횟수
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  color: Colors.deepPurple.shade50,
                  child: Column(
                    children: [
                      Text(
                        '총 결제 횟수',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '$currentTotalCount회',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),

                // 결제 내역 리스트
                Expanded(
                  child: paymentHistory.isEmpty
                      ? Center(
                          child: Text(
                            '결제 내역이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(8),
                          itemCount: paymentHistory.length,
                          itemBuilder: (context, index) {
                            final payment = paymentHistory[index];
                            final isSpecial = payment['type'] == '특별 결제';

                            return _buildPaymentCard(payment, index, isSpecial);
                          },
                        ),
                ),
              ],
            ),
      ),
    );
  }
}

