// ✅ main.dart
import 'package:flutter/material.dart';
import 'screens/post_list_screen.dart'; // 목록화면 import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //fluter main 초반에 엔진초기화.    밑의  GroupDatabaseHelper().resetDB()에서
  // getDatabasesPath() 같은 Flutter의 플랫폼 채널과 연동되는 기능은, Flutter 엔진이 초기화되기 전에는 호출하면 안 됨.
  //await GroupDatabaseHelper().resetDB(); // 개발 중 DB 초기화.  배포때는 없어야함

  print('[앱 시작] 시작...');

  runApp(MyApp());
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