import 'package:flutter/material.dart';
import '../widgets/responsive.dart';
import 'member_management_screen.dart';
import 'attendance_screen.dart';
import 'facility_management_screen.dart';
import 'facility_availability_screen.dart';
import 'life_team_management_screen.dart';

/// One entry describes one admin feature - the single source of truth for
/// both the mobile hub grid and the desktop nav rail. Adding a future admin
/// page (announcements, reports, etc.) is just adding one more entry here -
/// never a navigation redesign.
class _AdminDestination {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  const _AdminDestination({required this.label, required this.icon, required this.builder});
}

final List<_AdminDestination> _adminDestinations = [
  _AdminDestination(label: "성도 관리", icon: Icons.people_outline, builder: (_) => const MemberManagementScreen()),
  _AdminDestination(label: "출석 확인", icon: Icons.check_circle_outline, builder: (_) => const AttendanceScreen()),
  _AdminDestination(label: "장소 관리", icon: Icons.location_on_outlined, builder: (_) => const FacilityManagementScreen()),
  _AdminDestination(label: "예약 시간 설정", icon: Icons.event_available_outlined, builder: (_) => const FacilityAvailabilityScreen()),
  _AdminDestination(label: "라이프팀 관리", icon: Icons.groups_outlined, builder: (_) => const LifeTeamManagementScreen()),
];

/// Admin hub. On mobile this is a landing screen with one tile per feature -
/// tapping a tile pushes that feature as its own full screen (with its own
/// back button). On desktop the same destinations become a persistent nav
/// rail with content shown alongside it, since repeated back-and-forth to a
/// hub grid is the wrong pattern once there's a mouse and a wide screen.
class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return isDesktop(context) ? _buildDesktopLayout() : _buildMobileHub();
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            backgroundColor: const Color(0xFFF7F8FB),
            selectedIconTheme: const IconThemeData(color: Color(0xFF2F6FED)),
            selectedLabelTextStyle: const TextStyle(color: Color(0xFF2F6FED), fontWeight: FontWeight.w600),
            destinations: _adminDestinations
                .map((d) => NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          // 목적지가 바뀔 때마다 새로 빌드되어 각 화면이 매번 최신 데이터를
          // 직접 불러온다 (한 화면에서 바꾼 내용이 다른 화면에 캐시된 채로
          // 남아있지 않도록).
          Expanded(child: _adminDestinations[_selectedIndex].builder(context)),
        ],
      ),
    );
  }

  Widget _buildMobileHub() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(title: const Text("관리자"), backgroundColor: const Color(0xFFF7F8FB), elevation: 0, foregroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.1,
          children: _adminDestinations.map((d) => _buildTile(d)).toList(),
        ),
      ),
    );
  }

  Widget _buildTile(_AdminDestination destination) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: destination.builder)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDEEF1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(16)),
              child: Icon(destination.icon, color: const Color(0xFF2F6FED), size: 26),
            ),
            const SizedBox(height: 12),
            Text(destination.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
