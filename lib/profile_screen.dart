import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import http
import 'dart:convert'; // Import convert untuk JSON
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;
  final String role;
  final String userId; // ID Tampilan (misal TEK-001)
  final int databaseId; // ID Database (Primary Key) untuk API update

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.role,
    required this.userId, // Diubah menjadi required agar dinamis
    required this.databaseId, // Wajib di-pass dari Dashboard
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
    // Inisialisasi nama awal dari data yang dikirim saat login
    currentUserName = widget.userName;
  }

  // --- FUNGSI API KE LARAVEL ---
  Future<void> _updateProfile(String newName) async {
    setState(() {
      isLoading = true;
    });

    // Ganti IP sesuai server Anda
    final url = Uri.parse(
      'http://192.168.1.28:8000/api/user/update/${widget.databaseId}',
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
          currentUserName = newName; // Update tampilan nama
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
                Navigator.pop(context); // Tutup dialog dulu
                _updateProfile(nameController.text); // Jalankan fungsi update
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            child: const Text("Simpan", style: TextStyle(color: Colors.black)),
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
          style: TextStyle(color: Colors.white),
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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const LoginScreen(roleTitle: 'Tim Lapangan'),
                ),
                (route) => false,
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
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

                  // Tampilkan loading kecil jika sedang update
                  isLoading
                      ? const CircularProgressIndicator(color: Colors.cyan)
                      : Text(
                          currentUserName, // Menggunakan variable state
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
            _buildMenuTile(
              icon: Icons.lock_outline,
              title: "Ganti Password",
              onTap: () {},
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
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}
