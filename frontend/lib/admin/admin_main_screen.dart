import 'package:flutter/material.dart';
import '../profile_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, List<Map<String, dynamic>>> familyData = {
    "김수환 성도 가족": [
      {"name": "김수환", "role": "배우자", "isPresent": false},
      {"name": "최수지", "role": "배우자", "isPresent": false},
      {"name": "최이레", "role": "자녀", "isPresent": false},
    ],
    "이종민 집사 가족": [
      {"name": "이종민", "role": "배우자", "isPresent": true},
      {"name": "임태영", "role": "배우자", "isPresent": true},
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // 1. 탭이 바뀔 때마다 UI를 다시 그리도록 리스너 등록
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        // 탭 전환이 완료되었을 때만
        setState(() {
          // _tabController.index 값을 기준으로 UI가 업데이트됩니다.
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("사역 관리"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "성도 관리"),
            Tab(text: "출석 체크"),
            Tab(text: "통계"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMemberManager(),
          _buildAttendanceCheck(),
          _buildStatistics(),
        ],
      ),

      // 2. 조건부 플로팅 액션 버튼 배치
      // index가 0일 때만 FAB를 반환하고, 아니면 null을 반환합니다.
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddMemberDialog(context),
              backgroundColor: theme.primaryColor,
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: const Text(
                "성도 추가",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null, // 0번 탭이 아니면 버튼이 사라짐
    );
  }

  // --- 성도 등록 팝업창 ---
  void _showAddMemberDialog(BuildContext context) {
    final theme = Theme.of(context);
    String selectedRole = "성도";
    final List<String> roles = ["성도", "방문자", "집사", "전도사", "목사님"];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "새 성도 등록",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField("이름", Icons.person_outline),
                    const SizedBox(height: 15),
                    // --- [추가] 전화번호 입력 필드 ---
                    _buildTextField(
                      "전화번호",
                      Icons.phone_android_outlined,
                      keyboardType: TextInputType.phone, // 숫자 키패드 활성화
                    ),
                    const SizedBox(height: 15),
                    _buildTextField("생년월일 (YYYY-MM-DD)", Icons.cake_outlined),
                    const SizedBox(height: 15),
                    _buildTextField("주소", Icons.home_outlined),
                    const SizedBox(height: 15),
                    // 직분 선택 드롭다운 (기존 동일)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isExpanded: true,
                          items: roles.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setDialogState(() => selectedRole = newValue!);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildTextField("라이프팀 (선택사항)", Icons.group_work_outlined),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("취소", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("성도가 등록되었습니다.")),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                  ),
                  child: const Text(
                    "등록하기",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- [수정] 텍스트 필드 빌더 (keyboardType 추가) ---
  Widget _buildTextField(
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      keyboardType: keyboardType, // 전화번호일 경우 숫자 키패드를 띄움
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 15,
        ),
      ),
    );
  }

  // 1. 성도 관리 탭 (검색 + 리스트)
  Widget _buildMemberManager() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: "성도 이름으로 검색",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: const Text("김수환 성도"),
                subtitle: const Text("Mz's Us 라이프팀"),
                trailing: const Icon(Icons.edit_note),
                // AdminMainScreen의 ListTile 내부
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ProfileScreen(isAdmin: true), // 목사님 버전으로 이동!
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCheck() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "2026년 1월 20일 (오늘) 출석",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 20),

        // 가족별 카드 생성
        ...familyData.keys.map((familyName) {
          return _buildFamilyAttendanceCard(
            familyName,
            familyData[familyName]!,
          );
        }),

        const SizedBox(height: 80), // 하단 버튼 여유 공간
      ],
    );
  }

  Widget _buildFamilyAttendanceCard(
    String familyName,
    List<Map<String, dynamic>> members,
  ) {
    final theme = Theme.of(context);

    // 가족 중 모두가 출석했는지 확인
    bool isAllPresent = members.every((m) => m['isPresent'] == true);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Column(
        children: [
          // 가족 헤더 (가족 이름 + 일괄 체크 버튼)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 5,
            ),
            title: Text(
              familyName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            trailing: TextButton.icon(
              onPressed: () {
                setState(() {
                  for (var m in members) {
                    m['isPresent'] = !isAllPresent;
                  }
                });
              },
              icon: Icon(
                isAllPresent ? Icons.check_circle : Icons.check_circle_outline,
              ),
              label: Text(isAllPresent ? "전체 취소" : "가족 전체 출석"),
              style: TextButton.styleFrom(
                foregroundColor: isAllPresent
                    ? Colors.grey
                    : theme.colorScheme.secondary,
              ),
            ),
          ),
          const Divider(height: 1),

          // 가족 구성원 리스트
          ...members.map((member) {
            return CheckboxListTile(
              title: Text(
                member['name'],
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                member['role'],
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              value: member['isPresent'],
              activeColor: theme.primaryColor,
              secondary: const CircleAvatar(
                radius: 15,
                child: Icon(Icons.person, size: 18),
              ),
              onChanged: (bool? value) {
                setState(() {
                  member['isPresent'] = value ?? false;
                });
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFamilyCard(String familyName, List<String> members) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          ListTile(
            title: Text(
              familyName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: TextButton(onPressed: () {}, child: const Text("전체 출석")),
          ),
          const Divider(),
          ...members.map(
            (name) => CheckboxListTile(
              title: Text(name),
              value: false, // 실제 상태 데이터와 연결 필요
              onChanged: (bool? value) {},
              activeColor: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // 3. 통계 탭
  Widget _buildStatistics() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 10),
          Text("통계 데이터 준비 중입니다.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
