import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'role_selection_screen.dart'; // Mengubah import ke halaman role

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

  @override
  void initState() {
    super.initState();
    currentUserName = widget.userName;
  }

  // --- FUNGSI API UPDATE PROFIL ---
  Future<void> _updateProfile(String newName) async {
    setState(() {
      isLoading = true;
    });

    // PASTIKAN IP SESUAI DENGAN SERVER ANDA
    final url = Uri.parse(
      'http://10.253.130.116:8000/api/user/update/${widget.databaseId}',
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
              content: Text("Profil Berhasil Diperbarui"),
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
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
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
    TextEditingController nameController = TextEditingController(
      text: currentUserName,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Edit Profil", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Nama Lengkap",
            labelStyle: TextStyle(color: Colors.cyan),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyan),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
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
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI LOGOUT ---
  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Konfirmasi Logout",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Apakah Anda yakin ingin keluar?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context); // Tutup dialog
              // Arahkan ke halaman pemilihan role (RoleSelectionScreen) dan hapus riwayat rute sebelumnya
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
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
                    child: const CircleAvatar(
                      radius: 50,
                      backgroundColor: Color(0xFF1E293B),
                      child: Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),

                  isLoading
                      ? const CircularProgressIndicator(color: Colors.cyan)
                      : Text(
                          currentUserName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.role,
                      style: const TextStyle(
                        color: Colors.cyan,
                        fontSize: 12,
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
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.badge, color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "User ID",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.userId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.copy, color: Colors.grey, size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- MENU OPTIONS ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Pengaturan Akun",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),

            _buildMenuTile(
              icon: Icons.person_outline,
              title: "Edit Profil",
              onTap: _showEditProfileDialog,
            ),

            // MENU JADWAL TIM LAPANGAN (TLA)
            _buildMenuTile(
              icon: Icons.calendar_month,
              title: "Jadwal & Tim Lapangan (TLA)",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const JadwalScreen()),
                );
              },
            ),

            _buildMenuTile(
              icon: Icons.notifications_none,
              title: "Notifikasi",
              onTap: () {},
            ),
            _buildMenuTile(
              icon: Icons.help_outline,
              title: "Bantuan & Support",
              onTap: () {},
            ),

            const SizedBox(height: 40),

            // --- LOGOUT BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  "Keluar Akun",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
            const Text(
              "Versi Aplikasi 1.0.0",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.cyan),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
      final url = Uri.parse('http://10.253.130.116:8000/api/users');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> users = data['data'] ?? [];

        Map<String, List<dynamic>> tempGroup = {};

        for (var user in users) {
          // 1. FILTER: HANYA TAMPILKAN TIM LAPANGAN (TLA)
          String role = user['role']?.toString() ?? '';
          if (role != 'Tim Lapangan') {
            continue;
          }

          String userId = user['user_id']?.toString().toUpperCase() ?? '';

          // 2. FILTER: HAPUS "LAINNYA" (Harus punya tanda '-' seperti KJR-001)
          if (!userId.contains('-')) {
            continue;
          }

          // Mengambil kode unik STO (misal: "KJR" dari "KJR-001")
          String prefix = userId.split('-')[0];

          if (!tempGroup.containsKey(prefix)) {
            tempGroup[prefix] = [];
          }

          // Masukkan ke grup STO yang sesuai
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
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mengambil daftar STO dan mengurutkannya sesuai abjad (KDG, KJR, MGS, dst)
    List<String> groupKeys = _groupedTlaUsers.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Daftar Tim Lapangan (TLA)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : _groupedTlaUsers.isEmpty
          ? const Center(
              child: Text(
                "Belum ada data tim lapangan",
                style: TextStyle(color: Colors.grey),
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
                    // --- HEADER STO ---
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
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
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "${usersInGroup.length} Teknisi",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // --- TABEL DATA TEKNISI ---
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            const Color(0xFF161F2E),
                          ),
                          dataRowMinHeight: 60,
                          dataRowMaxHeight: 60,
                          headingTextStyle: const TextStyle(
                            color: Colors.cyan,
                            fontWeight: FontWeight.bold,
                          ),
                          dataTextStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
                                    : Colors.black12,
                              ),
                              cells: [
                                DataCell(Text('${rowIndex + 1}')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
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
                                        fontSize: 12,
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
                    const SizedBox(height: 30), // Jarak antar STO
                  ],
                );
              },
            ),
    );
  }
}
