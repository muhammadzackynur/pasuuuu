import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
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

  // Variabel untuk Pencapaian (Achievements)
  int totalSubmitted = 0;
  int totalClosed = 0;
  int currentStreak = 0;
  bool isLoadingAchievements = true;

  // Variabel untuk Foto Profil
  File? _profileImage;
  String? _photoUrl;
  final ImagePicker _picker = ImagePicker();
  bool isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    currentUserName = widget.userName;
    _fetchUserPhoto();
    if (widget.role == 'Tim Lapangan') {
      _fetchAchievements();
    } else {
      isLoadingAchievements = false;
    }
  }

  // --- FUNGSI MENGAMBIL URL FOTO PROFIL SAAT INI ---
  Future<void> _fetchUserPhoto() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/users');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> users = data['data'] ?? [];
        for (var u in users) {
          if (u['id'] == widget.databaseId && u['photo'] != null) {
            if (mounted) {
              setState(() {
                String photoPath = u['photo'].toString();
                if (photoPath.startsWith('http')) {
                  _photoUrl = photoPath;
                } else {
                  // Sesuaikan path storage Laravel
                  String host = ApiConfig.baseUrl.replaceAll(
                    RegExp(r'/api$'),
                    '',
                  );
                  _photoUrl = '$host/storage/$photoPath';
                }
              });
            }
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetch photo: $e');
    }
  }

  // --- LOGIKA PENENTU RANK PER-BADGE ---
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

  // --- FUNGSI API UPDATE FOTO PROFIL ---
  Future<void> _pickAndUploadPhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    setState(() {
      _profileImage = File(pickedFile.path);
      isUploadingPhoto = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/user/photo/${widget.databaseId}'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('photo', pickedFile.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      var data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          setState(() {
            if (data['photo_url'] != null) {
              _photoUrl = data['photo_url'];
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Foto Profil berhasil diperbarui!",
                style: TextStyle(fontSize: 19),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(data['message'] ?? 'Gagal mengunggah foto');
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
      if (mounted) {
        setState(() {
          isUploadingPhoto = false;
        });
      }
    }
  }

  // --- FUNGSI EKSEKUSI HAPUS USER (KHUSUS ADMIN) ---
  Future<void> _executeAdminDeleteUser(
    int targetDbId,
    String targetName,
  ) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF1E293B),
        title: const Text(
          "Hapus Pengguna?",
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: Text(
          "Seluruh akses, data, dan laporan milik teknisi '$targetName' akan dihapus permanen. Lanjutkan?",
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Batal",
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Ya, Hapus Permanen",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/user/$targetDbId'),
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "User '$targetName' berhasil dihapus",
                style: const TextStyle(fontSize: 19),
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Tutup modal BottomSheet
          _showAdminDeleteUserModal(); // Buka kembali agar list ter-refresh
        }
      } else {
        throw Exception(data['message'] ?? "Gagal menghapus user");
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
    }
  }

  // --- MODAL DAFTAR PENGGUNA UNTUK DIHAPUS (KHUSUS ADMIN) ---
  void _showAdminDeleteUserModal() {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color modalBg = isLightMode ? Colors.white : const Color(0xFF1E293B);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: modalBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<http.Response>(
              future: http.get(Uri.parse('${ApiConfig.baseUrl}/users')),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.cyan),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.statusCode != 200) {
                  return Center(
                    child: Text(
                      "Gagal menarik data pengguna",
                      style: TextStyle(color: textColor, fontSize: 18),
                    ),
                  );
                }

                final body = jsonDecode(snapshot.data!.body);
                final List<dynamic> users = body['data'] ?? [];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        "Pilih Pengguna yang Ingin Dihapus",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.grey),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final u = users[index];
                          // Admin tidak boleh menghapus akunnya sendiri
                          if (u['id'] == widget.databaseId)
                            return const SizedBox.shrink();

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.withOpacity(0.15),
                              child: const Icon(
                                Icons.person,
                                color: Colors.red,
                              ),
                            ),
                            title: Text(
                              u['name'] ?? 'Tanpa Nama',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 19,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              "Role: ${u['role']} | ID: ${u['user_id']}",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                                size: 30,
                              ),
                              onPressed: () => _executeAdminDeleteUser(
                                u['id'],
                                u['name'] ?? 'User',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
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
            fontSize: 24,
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

            // --- HEADER PROFILE DENGAN GANTI FOTO ---
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: isUploadingPhoto ? null : _pickAndUploadPhoto,
                    child: Stack(
                      alignment: Alignment.bottomRight,
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
                            backgroundImage: _profileImage != null
                                ? FileImage(_profileImage!) as ImageProvider
                                : (_photoUrl != null
                                      ? NetworkImage(_photoUrl!)
                                      : null),
                            child: (_profileImage == null && _photoUrl == null)
                                ? Icon(
                                    Icons.person,
                                    size: 50,
                                    color: isLightMode
                                        ? Colors.grey
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.cyan,
                            shape: BoxShape.circle,
                          ),
                          child: isUploadingPhoto
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    currentUserName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),
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
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 15),

            // =========================================================
            // FITUR MENGHAPUS USER (HANYA MUNCUL UNTUK TIM ADMINISTRASI)
            // =========================================================
            if (widget.role == 'Tim Administrasi')
              _buildMenuTile(
                icon: Icons.person_remove_alt_1,
                title: "Hapus Akun Pengguna",
                onTap: _showAdminDeleteUserModal,
                isLightMode: isLightMode,
                iconColor: Colors.red,
                textColorOverride: Colors.red,
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
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        isLoadingAchievements
            ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
            : Column(
                children: [
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
    Color iconColor = Colors.cyan,
    Color? textColorOverride,
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
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(
          title,
          style: TextStyle(
            color:
                textColorOverride ??
                (isLightMode ? Colors.black : Colors.white),
            fontSize: 19,
            fontWeight: textColorOverride != null
                ? FontWeight.bold
                : FontWeight.normal,
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
            fontSize: 26,
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
