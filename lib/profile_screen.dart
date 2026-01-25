import 'package:flutter/material.dart';
import 'login_screen.dart'; // Pastikan import login screen untuk fungsi logout

class ProfileScreen extends StatelessWidget {
  final String userName;
  final String role;
  final String userId; // Tambahan jika ingin menampilkan ID (misal TEK-001)

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.role,
    this.userId = "TEK-001", // Default value jika data ID belum dipassing
  });

  // Fungsi Logout
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
              // Tutup Dialog
              Navigator.pop(context);
              // Kembali ke Login Screen dan hapus semua history navigasi
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
      backgroundColor: const Color(0xFF0D1424), // Background Navy Gelap
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
                  Text(
                    userName,
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
                      role,
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
                        userId, // Menampilkan ID User
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
              onTap: () {},
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
