import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'profile_screen.dart';
import 'widgets/skeletons.dart';
import 'admin/admin_main_screen.dart';

class MainTabScreen extends StatefulWidget {
  final String userName; // 로그인한 사용자 이름을 받습니다.

  const MainTabScreen({
    super.key,
    required this.userName, // 필수 인자로 설정
  });

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedIndex = 0;

  // 초기화 시 이름을 확인하여 권한 설정
  late final bool _isAdmin;
  bool _isLoadingNotices = true;

  @override
  void initState() {
    super.initState();
    // 박민우면 목사님(Admin), 아니면 일반 성도
    _isAdmin = widget.userName == "박민우";
    _startLoadingTimer();
  }

  void _startLoadingTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isLoadingNotices = false;
        });
      }
    });
  }

  // --- [추가] 순차적 등장을 위한 애니메이션 위젯 ---
  Widget _buildAnimatedItem({required int delayMs, required Widget child}) {
    return TweenAnimationBuilder<double>(
      // 0.0에서 1.0으로 애니메이션 실행
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      // 지연 시간을 주어 순차적으로 나타나게 함 (간단한 지연 효과)
      curve: Interval(
        (delayMs / 1000).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)), // 아래에서 위로 30px 이동
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // 1. 홈 화면 컴포넌트 (애니메이션 적용)
  Widget _buildHomeScreen() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      children: [
        _buildAnimatedItem(
          delayMs: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "반갑습니다,",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    "${widget.userName} ${_isAdmin ? '목사님' : '성도님'}", // 권한에 따른 호칭 변경
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(isAdmin: false),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
                  child: Icon(
                    Icons.person_rounded,
                    color: theme.colorScheme.secondary,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // [2단계] 출석 카드
        _buildAnimatedItem(
          delayMs: 150,
          child: _buildAttendanceStatusCard(
            isChecked: false,
            onTap: () => setState(() => _selectedIndex = 1),
          ),
        ),

        const SizedBox(height: 40),

        // [3단계] 공지사항 헤더
        _buildAnimatedItem(
          delayMs: 300,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "📢 교회 공지사항",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {},
                child: const Text("전체보기", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        _isLoadingNotices
            ? const NoticeSkeleton(itemCount: 3) // 훨씬 깔끔해진 코드!
            : Column(
                children: [
                  _buildAnimatedItem(
                    delayMs: 450,
                    child: _buildNoticeItem(
                      "이번 주 라이프팀 리더 모임 안내",
                      "2026-01-19",
                      true,
                    ),
                  ),
                  _buildAnimatedItem(
                    delayMs: 550,
                    child: _buildNoticeItem(
                      "이은수❤️조은애 베이비 샤워 ",
                      "2026-01-17",
                      false,
                    ),
                  ),
                  _buildAnimatedItem(
                    delayMs: 650,
                    child: _buildNoticeItem(
                      "날씨로 인한 예배 변경 사항",
                      "2026-01-15",
                      false,
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  // ... 나머지 위젯들 (이전과 동일)
  Widget _buildAttendanceStatusCard({
    required bool isChecked,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final secondary = theme.colorScheme.secondary;

    return GestureDetector(
      onTap: isChecked ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isChecked
                ? [secondary, const Color(0xFFFFD700)]
                : [primary, primary.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (isChecked ? secondary : primary).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        isChecked ? Icons.verified : Icons.auto_awesome,
                        color: isChecked ? Colors.black87 : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isChecked ? "축복합니다!" : "환영합니다!",
                        style: TextStyle(
                          color: isChecked
                              ? Colors.black87
                              : Colors.white.withOpacity(0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isChecked ? "오늘 출석이 완료되었습니다" : "탭하여 출석 QR을 띄우세요",
                    style: TextStyle(
                      color: isChecked ? Colors.black : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeItem(String title, String date, bool isNew) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        title: Row(
          children: [
            if (isNew)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "NEW",
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Text(date),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {},
      ),
    );
  }

  // --- QR 스크린 및 예약 스크린 (애니메이션 적용 추천) ---
  Widget _buildQRScreen() {
    return _buildAnimatedItem(
      delayMs: 0,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "아이패드 카메라에 보여주세요",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "화면을 밝게 하시면 인식이 더 잘 됩니다",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                  ),
                ],
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 3,
                ),
              ),
              child: QrImageView(
                data: "김수환550101",
                version: QrVersions.auto,
                size: 250.0,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              "Mz's Us 라이프팀",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              "${widget.userName} ${_isAdmin ? '목사님' : '성도님'}",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationScreen() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildAnimatedItem(
          delayMs: 0,
          child: const Text(
            "모임 장소 예약",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 20),
        _buildAnimatedItem(
          delayMs: 100,
          child: _buildRoomCard("본당", "사용 가능", Icons.church),
        ),
        _buildAnimatedItem(
          delayMs: 200,
          child: _buildRoomCard("식당", "예약 완료", Icons.coffee),
        ),
        _buildAnimatedItem(
          delayMs: 300,
          child: _buildRoomCard("Youth Group", "사용 가능", Icons.groups),
        ),
      ],
    );
  }

  Future<void> _selectReservation(BuildContext context, String roomName) async {
    final theme = Theme.of(context);

    final DateTime? pickedDate = await showDatePicker(
      context: context,

      initialDate: DateTime.now(),

      firstDate: DateTime.now(),

      lastDate: DateTime.now().add(const Duration(days: 30)),

      helpText: "$roomName 예약 날짜 선택",

      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: theme.primaryColor, // 테마 컬러 적용

              onPrimary: Colors.white,

              onSurface: Colors.black,
            ),
          ),

          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,

        initialTime: TimeOfDay.now(),

        helpText: "$roomName 예약 시간 선택",
      );

      if (pickedTime != null) {
        _showConfirmDialog(context, roomName, pickedDate, pickedTime);
      }
    }
  }

  void _showConfirmDialog(
    BuildContext context,

    String room,

    DateTime date,

    TimeOfDay time,
  ) {
    final theme = Theme.of(context);

    showDialog(
      context: context,

      builder: (context) => AlertDialog(
        title: const Text(
          "예약 확인",

          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        content: Text(
          "장소: $room\n"
          "날짜: ${date.year}년 ${date.month}월 ${date.day}일\n"
          "시간: ${time.format(context)}\n\n"
          "이 정보로 예약하시겠습니까?",

          style: const TextStyle(fontSize: 16),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),

            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary, // 테마 컬러 적용
            ),

            onPressed: () {
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("$room 예약이 완료되었습니다!"),

                  backgroundColor: theme.primaryColor, // 테마 컬러 적용
                ),
              );
            },

            child: const Text(
              "예약 확정",

              style: TextStyle(
                color: Colors.black,

                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          title: Padding(
            padding: const EdgeInsets.only(left: 10, top: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                    children: [
                      TextSpan(
                        text: "Life ",
                        style: TextStyle(color: theme.primaryColor),
                      ),
                      TextSpan(
                        text: "Connect",
                        style: TextStyle(color: theme.colorScheme.secondary),
                      ),
                    ],
                  ),
                ),
                const Text(
                  "LOUISVILLE WOORI CHURCH",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20, top: 10),
              child: IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
      // IndexedStack을 사용하되, 각 화면 내에서 개별 애니메이션이 작동하도록 함
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeScreen(),
          _buildQRScreen(),
          _buildReservationScreen(),
          if (_isAdmin) const AdminMainScreen(), // 관리자 전용 페이지 추가
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: theme.colorScheme.secondary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // 탭이 4개일 때는 fixed가 안정적입니다
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: "홈",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: "출석",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: "예약",
          ),
          if (_isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings),
              label: "관리",
            ),
        ],
      ),
    );
  }

  // _buildRoomCard 등 누락된 헬퍼 위젯들 기존 소스 그대로 사용
  Widget _buildRoomCard(String name, String status, IconData icon) {
    final theme = Theme.of(context);
    bool isAvailable = status == "사용 가능";
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAvailable
              ? theme.primaryColor.withOpacity(0.1)
              : Colors.grey.shade100,
          child: Icon(
            icon,
            color: isAvailable ? theme.primaryColor : Colors.grey,
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          status,
          style: TextStyle(
            color: isAvailable ? theme.primaryColor : Colors.red,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: isAvailable
              ? () => _selectReservation(context, name)
              : null, // 실제 로직 연결 필요
          style: ElevatedButton.styleFrom(
            backgroundColor: isAvailable
                ? theme.colorScheme.secondary
                : Colors.grey.shade300,
            foregroundColor: isAvailable ? Colors.black : Colors.grey,
            elevation: 0,
          ),
          child: const Text("예약하기", style: TextStyle(color: Colors.black)),
        ),
      ),
    );
  }
}
