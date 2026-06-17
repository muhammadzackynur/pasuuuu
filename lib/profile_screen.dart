import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'role_selection_screen.dart';
import 'api_config.dart';
import 'achievement_widget.dart'; // Sesuaikan path-nya jika perlu

class ProfileScreen extends StatefulWidget {
  final String userName;
  final String role;
  final String userId;
  final int databaseId;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.role,
    required this.userId,
    required this.databaseId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String currentUserName;
  bool isLoading = false;

  // Variabel untuk Pencapaian (Achievements)
  int totalSubmitted = 0;
  int totalClosed = 0;
  int currentStreak = 0;
  bool isLoadingAchievements = true;

  @override
  void initState() {
    super.initState();
    currentUserName = widget.userName;
    if (widget.role == 'Tim Lapangan') {
      _fetchAchievements();
    } else {
      isLoadingAchievements = false;
    }
  }

  // --- LOGIKA PENENTU RANK PER-BADGE (berdasarkan progress current/target) ---
  String _calculateBadgeRank(int current, int target) {
    if (target <= 0) return 'bronze';
    double progress = current / target;
    if (progress >= 1.0) return 'crown';
    if (progress >= 0.5) return 'silver';
    return 'bronze';
  }

  // --- FUNGSI API FETCH ACHIEVEMENTS ---
  Future<void> _fetchAchievements() async {
    final url = Uri.parse(
      '${ApiConfig.baseUrl}/user/achievements/${widget.userId}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              totalSubmitted = data['data']['total_submitted'] ?? 0;
              totalClosed = data['data']['total_closed'] ?? 0;
              currentStreak = data['data']['current_streak'] ?? 0;
              isLoadingAchievements = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingAchievements = false;
        });
      }
    }
  }

  // --- FUNGSI API UPDATE PROFIL ---
  Future<void> _updateProfile(String newName) async {
    setState(() {
      isLoading = true;
    });

    final url = Uri.parse(
      '${ApiConfig.baseUrl}/user/update/${widget.databaseId}',
    );

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': newName}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          currentUserName = newName;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Profil Berhasil Diperbarui",
                style: TextStyle(fontSize: 19),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(data['message'] ?? "Gagal update profil");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e", style: const TextStyle(fontSize: 19)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // --- DIALOG EDIT PROFIL ---
  void _showEditProfileDialog() {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color dialogBgColor = isLightMode ? Colors.white : const Color(0xFF1E293B);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    TextEditingController nameController = TextEditingController(
      text: currentUserName,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBgColor,
        title: Text(
          "Edit Profil",
          style: TextStyle(
            color: textColor,
            fontSize: 24, // Diperbesar dari 20 agar lebih terlihat
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: TextStyle(color: textColor, fontSize: 19),
          decoration: InputDecoration(
            labelText: "Nama Lengkap",
            labelStyle: const TextStyle(color: Colors.cyan, fontSize: 19),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyan),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Batal",
              style: TextStyle(color: Colors.grey, fontSize: 19),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context);
                _updateProfile(nameController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            child: const Text(
              "Simpan",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI LOGOUT ---
  void _logout(BuildContext context) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color dialogBgColor = isLightMode ? Colors.white : const Color(0xFF1E293B);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBgColor,
        title: Text(
          "Konfirmasi Logout",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24, // Diperbesar dari 20
          ),
        ),
        content: Text(
          "Apakah Anda yakin ingin keluar?",
          style: TextStyle(
            color: isLightMode ? Colors.grey[700] : Colors.grey,
            fontSize: 19,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Batal",
              style: TextStyle(color: Colors.grey, fontSize: 19),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text(
              "Logout",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color bgColor = isLightMode
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0D1424);
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF1E293B);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- HEADER PROFILE ---
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.cyan, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: cardColor,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: isLightMode ? Colors.grey : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  isLoading
                      ? const CircularProgressIndicator(color: Colors.cyan)
                      : Text(
                          currentUserName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize:
                                32, // DIUBAH: Diperbesar dari 24 agar sangat jelas terbaca
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                  const SizedBox(height: 8), // Sedikit dinaikkan jaraknya
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.role,
                      style: const TextStyle(
                        color: Colors.cyan,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- INFO CARD (USER ID) ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isLightMode
                    ? [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.badge,
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "User ID",
                        style: TextStyle(
                          color: isLightMode ? Colors.grey[600] : Colors.grey,
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.userId,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.copy,
                      color: isLightMode ? Colors.grey[600] : Colors.grey,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- PENCAPAIAN SAYA (Hanya tampil untuk Tim Lapangan) ---
            if (widget.role == 'Tim Lapangan')
              _buildAchievementsSection(isLightMode),

            // --- MENU OPTIONS ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Pengaturan Akun",
                style: TextStyle(
                  color: isLightMode ? Colors.grey[700] : Colors.grey,
                  fontSize:
                      22, // DIUBAH: Diperbesar dari 20 untuk membedakan section header
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 15),

            _buildMenuTile(
              icon: Icons.person_outline,
              title: "Edit Profil",
              onTap: _showEditProfileDialog,
              isLightMode: isLightMode,
            ),

            _buildMenuTile(
              icon: Icons.calendar_month,
              title: "Jadwal & Tim Lapangan (TLA)",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const JadwalScreen()),
                );
              },
              isLightMode: isLightMode,
            ),

            _buildMenuTile(
              icon: Icons.notifications_none,
              title: "Notifikasi",
              onTap: () {},
              isLightMode: isLightMode,
            ),
            _buildMenuTile(
              icon: Icons.help_outline,
              title: "Bantuan & Support",
              onTap: () {},
              isLightMode: isLightMode,
            ),

            const SizedBox(height: 40),

            // --- LOGOUT BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, color: Colors.white, size: 24),
                label: const Text(
                  "Keluar Akun",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 20),
            Text(
              "Versi Aplikasi 1.0.0",
              style: TextStyle(
                color: isLightMode ? Colors.grey[600] : Colors.grey,
                fontSize: 19,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Widget Bagian Pencapaian (gabungan animasi rank Lottie + badge progress)
  Widget _buildAchievementsSection(bool isLightMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Pencapaian Saya",
            style: TextStyle(
              color: isLightMode ? Colors.grey[700] : Colors.grey,
              fontSize: 22, // DIUBAH: Diperbesar dari 20 agar seimbang
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        isLoadingAchievements
            ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
            : Column(
                children: [
                  // ===== BADGE PROGRESS PER KATEGORI =====
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBadgeCard(
                          title: "Kontributor Aktif",
                          current: totalSubmitted,
                          target: 25,
                          activeColor: Colors.blue,
                          isLightMode: isLightMode,
                        ),
                        const SizedBox(width: 12),
                        _buildBadgeCard(
                          title: "Bintang Lapangan",
                          current: totalClosed,
                          target: 25,
                          activeColor: Colors.orange,
                          isLightMode: isLightMode,
                        ),
                        const SizedBox(width: 12),
                        _buildBadgeCard(
                          title: "Pekerja Tanpa Cacat",
                          current: currentStreak,
                          target: 25,
                          activeColor: Colors.green,
                          isLightMode: isLightMode,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Widget Kartu Lencana Satuan
  Widget _buildBadgeCard({
    required String title,
    required int current,
    required int target,
    required Color activeColor,
    required bool isLightMode,
  }) {
    bool isAchieved = current >= target;
    double progress = (current / target).clamp(0.0, 1.0);
    String badgeRank = _calculateBadgeRank(current, target);

    return Container(
      width: 165,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLightMode ? Colors.white : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isAchieved
              ? activeColor
              : (isLightMode ? Colors.grey[300]! : Colors.white10),
          width: isAchieved ? 2 : 1,
        ),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ===== ANIMASI RANK (BRONZE/SILVER/CROWN) PER KATEGORI =====
          SizedBox(
            height: 72,
            width: 72,
            child: AchievementWidget(
              rank: badgeRank,
              showLabel: false,
              size: 72,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isAchieved
                    ? (isLightMode ? Colors.black : Colors.white)
                    : Colors.grey,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: isLightMode ? Colors.grey[200] : Colors.black26,
            color: activeColor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 8),
          Text(
            "$current / $target",
            style: TextStyle(
              color: isAchieved ? activeColor : Colors.grey,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isLightMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isLightMode ? Colors.white : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: Colors.cyan, size: 28),
        title: Text(
          title,
          style: TextStyle(
            color: isLightMode ? Colors.black : Colors.white,
            fontSize: 19,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isLightMode ? Colors.grey[600] : Colors.grey,
        ),
      ),
    );
  }
}

// ======================================================================
// --- HALAMAN JADWAL & DAFTAR TIM (BERUPA TABEL PER STO) ---
// ======================================================================
class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  bool _isLoading = true;
  Map<String, List<dynamic>> _groupedTlaUsers = {};

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/users');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> users = data['data'] ?? [];

        Map<String, List<dynamic>> tempGroup = {};

        for (var user in users) {
          String role = user['role']?.toString() ?? '';
          if (role != 'Tim Lapangan') {
            continue;
          }

          String userId = user['user_id']?.toString().toUpperCase() ?? '';

          if (!userId.contains('-')) {
            continue;
          }

          String prefix = userId.split('-')[0];

          if (!tempGroup.containsKey(prefix)) {
            tempGroup[prefix] = [];
          }

          tempGroup[prefix]!.add(user);
        }

        if (mounted) {
          setState(() {
            _groupedTlaUsers = tempGroup;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        _showError("Gagal mengambil data: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError("Koneksi Error: $e");
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 19)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color bgColor = isLightMode
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0D1424);
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF1E293B);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    List<String> groupKeys = _groupedTlaUsers.keys.toList()..sort();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Daftar Tim Lapangan (TLA)',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize:
                26, // DIUBAH: Diperbesar dari 20 agar AppBar title terlihat tegas dan jelas
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : _groupedTlaUsers.isEmpty
          ? Center(
              child: Text(
                "Belum ada data tim lapangan",
                style: TextStyle(
                  color: isLightMode ? Colors.grey[700] : Colors.grey,
                  fontSize: 19,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: groupKeys.length,
              itemBuilder: (context, index) {
                String prefix = groupKeys[index];
                List<dynamic> usersInGroup = _groupedTlaUsers[prefix]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "STO $prefix",
                            style: const TextStyle(
                              color: Colors.cyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${usersInGroup.length} Teknisi",
                          style: TextStyle(
                            color: isLightMode ? Colors.grey[700] : Colors.grey,
                            fontSize: 19,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isLightMode
                              ? Colors.grey[300]!
                              : Colors.white10,
                        ),
                        boxShadow: isLightMode
                            ? [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            isLightMode
                                ? Colors.grey[200]
                                : const Color(0xFF161F2E),
                          ),
                          dataRowMinHeight: 70,
                          dataRowMaxHeight: 70,
                          headingTextStyle: const TextStyle(
                            color: Colors.cyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                          ),
                          dataTextStyle: TextStyle(
                            color: textColor,
                            fontSize: 19,
                          ),
                          columns: const [
                            DataColumn(label: Text('NO')),
                            DataColumn(label: Text('KODE UNIK (ID)')),
                            DataColumn(label: Text('NAMA LENGKAP')),
                          ],
                          rows: List.generate(usersInGroup.length, (rowIndex) {
                            final user = usersInGroup[rowIndex];
                            return DataRow(
                              color: MaterialStateProperty.all(
                                rowIndex % 2 == 0
                                    ? Colors.transparent
                                    : (isLightMode
                                          ? Colors.grey[50]
                                          : Colors.black12),
                              ),
                              cells: [
                                DataCell(Text('${rowIndex + 1}')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.cyan.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      user['user_id'] ?? '-',
                                      style: const TextStyle(
                                        color: Colors.cyan,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 19,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text(user['name'] ?? '-')),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                  ],
                );
              },
            ),
    );
  }
}
