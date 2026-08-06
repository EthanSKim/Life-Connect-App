import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:io' show Platform;
import 'package:qr_flutter/qr_flutter.dart';
import 'profile_screen.dart';
import 'widgets/skeletons.dart';
import 'package:url_launcher/url_launcher.dart'; // 패키지 설치 필요: flutter pub add url_launcher
import 'admin/admin_main_screen.dart';
import 'config.dart';
import 'auth_session.dart';
import 'facility_booking_screen.dart';
import 'main.dart';
import 'api_client.dart';
import 'widgets/facility_icons.dart';
import 'widgets/notice_card.dart';
import 'notice_detail_screen.dart';
import 'notice_list_screen.dart';

class MainTabScreen extends StatefulWidget {
  final String userName; // 로그인한 사용자 이름을 받습니다.
  final int personId;    // 로그인한 사용자 ID를 받습니다.
  final bool isAdmin;    // 관리자 여부
  final String userTitle; // 직급 (목사, 집사 등)
  final String attendanceToken; // QR 출석 체크용 전용 토큰 (로그인 PIN과 무관)

  const MainTabScreen({
    super.key,
    required this.userName, // 필수 인자로 설정
    required this.personId,
    required this.attendanceToken,
    required this.isAdmin,
    required this.userTitle,
  });

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _selectedIndex = 0;

  bool _isLoadingNotices = true;
  List<dynamic> _notices = [];
  bool _isAttended = false; // 오늘 출석 여부 상태 추가
  Timer? _attendancePollTimer; // QR 탭을 보고 있는 동안, 관리자가 스캔하면 바로 반영되도록 주기적으로 확인

  // 예약 관련 상태
  List<dynamic> _facilities = [];
  bool _isLoadingFacilities = true;

  @override
  void initState() {
    super.initState();
    _fetchNotices();
    _fetchFacilities();
    _checkAttendanceStatus(); // 출석 상태 확인 호출
  }

  @override
  void dispose() {
    _attendancePollTimer?.cancel();
    super.dispose();
  }

  // QR 화면을 보고 있는 동안에만 폴링한다 (다른 탭에 있을 때 계속 도는 것을 방지).
  // 이미 출석 처리되었으면 더 확인할 필요가 없으므로 시작하지 않는다.
  void _startAttendancePolling() {
    _attendancePollTimer?.cancel();
    // 출석 상태는 되돌려질 수 있다 (관리자가 실수로 체크 해제하는 등),
    // 그래서 이미 출석 상태여도 폴링을 계속 유지한다 - 예전에는 여기서
    // 출석 상태면 아예 시작하지 않고, 폴링 중에도 출석되는 순간 멈춰버려서
    // 관리자가 체크를 해제해도 이 화면에 있는 동안은 절대 반영되지 않았다.
    _attendancePollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkAttendanceStatus();
    });
  }

  void _stopAttendancePolling() {
    _attendancePollTimer?.cancel();
    _attendancePollTimer = null;
  }

  // 오늘 출석했는지 서버에 확인
  Future<void> _checkAttendanceStatus() async {
    try {
      final data = await ApiClient.get('/api/attendance/status/${widget.personId}');
      if (mounted) setState(() => _isAttended = data['attended']);
    } on ApiException catch (e) {
      debugPrint("출석 상태 확인 실패: ${e.message}");
    }
  }

  Future<void> _fetchNotices() async {
    try {
      final data = await ApiClient.get('/api/notices?limit=3');
      if (mounted) {
        setState(() {
          _notices = data;
          _isLoadingNotices = false;
        });
      }
    } on ApiException catch (e) {
      debugPrint("공지사항 로딩 실패: ${e.message}");
      if (mounted) setState(() => _isLoadingNotices = false);
    }
  }

  Future<void> _fetchFacilities() async {
    setState(() => _isLoadingFacilities = true);
    try {
      final data = await ApiClient.get('/api/facilities');
      if (mounted) {
        setState(() {
          _facilities = data;
          _isLoadingFacilities = false;
        });
      }
    } on ApiException catch (e) {
      debugPrint("장소 정보 로딩 실패: ${e.message}");
      if (mounted) setState(() => _isLoadingFacilities = false);
    }
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
                    style: TextStyle(fontSize: 15, color: kTextSecondary),
                  ),
                  Text(
                    "${widget.userName} ${widget.userTitle}님", // 인사말에서만 님 붙임 (직분 값 자체는 그대로)
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        isAdmin: false,
                        personId: widget.personId, // ID 전달
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: kFieldFill,
                  child: Icon(
                    Icons.person_rounded,
                    color: kTextSecondary,
                    size: 26,
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
            isChecked: _isAttended, // 실제 상태 적용
            onTap: () {
              setState(() => _selectedIndex = 1);
              _startAttendancePolling();
            },
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
                "교회 공지사항",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NoticeListScreen())),
                child: const Text("전체보기", style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.normal)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        _isLoadingNotices
            ? const NoticeSkeleton(itemCount: 3) // 훨씬 깔끔해진 코드!
            : Column(
                children: _notices.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var notice = entry.value;
                  return _buildAnimatedItem(
                    delayMs: 450 + (idx * 100),
                    child: NoticeCard(
                      notice: notice,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => NoticeDetailScreen(notice: notice)),
                      ),
                    ),
                  );
                }).toList(),
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
    const checkedText = Color(0xFF4A2E00); // 노란 배경 위 충분한 대비를 위한 진한 amber

    return GestureDetector(
      onTap: isChecked ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: isChecked ? secondary : primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withOpacity(0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        isChecked ? Icons.verified : Icons.qr_code_2,
                        color: isChecked ? checkedText : Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isChecked ? "축복합니다!" : "환영합니다!",
                        style: TextStyle(
                          color: isChecked ? checkedText : Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isChecked ? "오늘 출석이 완료되었습니다" : "탭하여 출석 QR을 띄우세요",
                    style: TextStyle(
                      color: isChecked ? checkedText : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
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

  // --- QR 스크린 및 예약 스크린 (애니메이션 적용 추천) ---
  Widget _buildQRScreen() {
    final theme = Theme.of(context);
    if (_isAttended) {
      return _buildAnimatedItem(
        delayMs: 0,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(44)),
                child: const Icon(Icons.check, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                "출석이 완료되었습니다",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kTextPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                "${widget.userName} ${widget.userTitle}",
                style: TextStyle(fontSize: 15, color: theme.primaryColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return _buildAnimatedItem(
      delayMs: 0,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "아이패드 카메라에 보여주세요",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: kTextPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              "화면을 밝게 하시면 인식이 더 잘 됩니다",
              style: TextStyle(fontSize: 13, color: kTextSecondary),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              child: QrImageView(
                data: widget.attendanceToken,
                version: QrVersions.auto,
                size: 250.0,
              ),
            ),
            const SizedBox(height: 40),
            
            if (!kIsWeb && Platform.isIOS)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: TextButton.icon(
                  onPressed: () async {
                    final url = Uri.parse('${AppConfig.baseUrl}/api/wallet/apple-pass/${widget.personId}?token=${AuthSession.token ?? ''}');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text("Apple Wallet에 추가"),
                  style: TextButton.styleFrom(foregroundColor: Colors.black),
                ),
              ),

            Text(
              "${widget.userName} ${widget.userTitle}", // DB에 등록된 직급 적용
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
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
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: kTextPrimary),
          ),
        ),
        const SizedBox(height: 6),
        _buildAnimatedItem(
          delayMs: 0,
          child: const Text(
            "장소를 선택하면 날짜와 시간을 고를 수 있어요",
            style: TextStyle(fontSize: 13, color: kTextSecondary),
          ),
        ),
        const SizedBox(height: 20),
        if (_isLoadingFacilities)
          const Center(child: CircularProgressIndicator())
        else
          ..._facilities.asMap().entries.map((entry) {
            int idx = entry.key;
            var facility = entry.value;
            return _buildAnimatedItem(
              delayMs: 100 + (idx * 100),
              child: _buildRoomCard(facility),
            );
          }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          title: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Life Connect",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextPrimary),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: kTextSecondary),
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
          if (widget.isAdmin) const AdminMainScreen(), // 전달받은 관리자 여부 사용
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          // IndexedStack은 모든 탭을 계속 살려두므로, 관리자 탭에서 장소를
          // 추가/변경해도 홈/예약 탭의 기존 목록은 자동으로 갱신되지 않는다.
          // 탭을 누를 때마다 다시 불러와서 항상 최신 상태를 보장한다.
          _fetchFacilities();
          _fetchNotices();
          // 출석 상태도 마찬가지 - 다른 기기(관리자)에서 체크/해제한 내용이
          // 어느 탭으로 전환하든 반영되도록 매번 다시 확인한다.
          _checkAttendanceStatus();
          // QR 탭(index 1)을 보고 있는 동안에는 관리자가 스캔하는 즉시
          // 반영되도록 주기적으로 확인하고, 다른 탭으로 이동하면 멈춘다.
          if (index == 1) {
            _startAttendancePolling();
          } else {
            _stopAttendancePolling();
          }
        },
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
          if (widget.isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings),
              label: "관리",
            ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> facility) {
    final theme = Theme.of(context);
    String name = facility['name'];
    String? description = facility['description'];
    final bool isReservable = facility['is_reservable'] ?? true;

    // 아이콘 매핑 (widgets/facility_icons.dart - 관리자 화면과 공유)
    final icon = facilityIconFor(facility['icon_key']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: kBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Opacity(
        opacity: isReservable ? 1.0 : 0.6,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: theme.primaryColor.withOpacity(0.08),
            child: Icon(icon, color: theme.primaryColor),
          ),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, color: kTextPrimary)),
          subtitle: description != null && description.isNotEmpty
              ? Text(description, style: const TextStyle(color: kTextSecondary))
              : null,
          trailing: isReservable
              ? ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FacilityBookingScreen(
                          facility: facility,
                          personId: widget.personId,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: const Color(0xFF4A2E00),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text("예약하기", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text("예약 불가", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
                ),
        ),
      ),
    );
  }
}
