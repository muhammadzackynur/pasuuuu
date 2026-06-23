import 'package:flutter/material.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // --- DETEKSI MODE CERAH ATAU GELAP ---
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color textColor = isLightMode ? Colors.black : Colors.white;

    // --- DETEKSI LEBAR LAYAR ---
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 600;

    return Scaffold(
      // Background Scaffold akan otomatis mengikuti konfigurasi di main.dart
      body: Stack(
        children: [
          // Ornamen Lingkaran Kiri Atas
          Positioned(
            top: isDesktop ? -100 : -80,
            left: isDesktop ? -100 : -80,
            child: Container(
              width: isDesktop ? 350 : 250,
              height: isDesktop ? 350 : 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.teal.withOpacity(isLightMode ? 0.1 : 0.15),
              ),
            ),
          ),

          // Ornamen Lingkaran Kanan Bawah (Muncul saat di PC/Laptop agar tidak kosong)
          if (isDesktop)
            Positioned(
              bottom: -150,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyan.withOpacity(isLightMode ? 0.05 : 0.1),
                ),
              ),
            ),

          SafeArea(
            child: Center(
              // ConstrainedBox membatasi lebar maksimal konten agar tidak melar di PC
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 40.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.cyan.withOpacity(0.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.wifi_tethering,
                            color: Colors.cyan,
                            size: 50, // Sedikit diperbesar
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Maintenance Monitor',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isDesktop ? 40 : 35, // Ukuran dinamis
                            fontWeight: FontWeight.bold,
                            color: textColor, // Berubah otomatis
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pilih Role Anda',
                          style: TextStyle(
                            color: isLightMode ? Colors.grey[700] : Colors.grey,
                            fontSize: 20, // Diperbesar menjadi 20
                          ),
                        ),
                        const SizedBox(height: 48),
                        _buildRoleCard(
                          context,
                          title: 'Tim Lapangan',
                          subtitle: 'Laporan Maintenance',
                          icon: Icons.groups,
                          // Penyesuaian warna ikon agar lebih kontras di mode cerah
                          iconColor: isLightMode
                              ? Colors.teal
                              : Colors.cyanAccent,
                          bgColor: Colors.teal.withOpacity(0.2),
                          isLightMode: isLightMode,
                        ),
                        const SizedBox(height: 16),
                        _buildRoleCard(
                          context,
                          title: 'Tim Administrasi',
                          subtitle: 'Kelola & Verifikasi Data',
                          icon: Icons.admin_panel_settings,
                          iconColor: isLightMode
                              ? Colors.deepPurple
                              : Colors.purpleAccent,
                          bgColor: Colors.deepPurple.withOpacity(0.2),
                          isLightMode: isLightMode,
                        ),
                        SizedBox(height: isDesktop ? 60 : 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Belum punya akses? ',
                              style: TextStyle(
                                color: isLightMode
                                    ? Colors.grey[700]
                                    : Colors.grey,
                                fontSize: 19, // Diperbesar menjadi 19
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                // Aksi hubungi admin
                              },
                              child: Text(
                                'Hubungi Admin',
                                style: TextStyle(
                                  color: isLightMode
                                      ? Colors.cyan[700]
                                      : Colors.cyan,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19, // Diperbesar menjadi 19
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'Copyright © 2024 Maintenance Monitor',
                          style: TextStyle(
                            color: isLightMode ? Colors.grey[500] : Colors.grey,
                            fontSize: 16, // Diperbesar agar mudah terbaca
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isLightMode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Menggunakan InkWell agar ada efek hover dan efek klik yang bagus di PC
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(roleTitle: title),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            // Warna card berubah otomatis
            color: isLightMode ? Colors.white : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            // Tambahan shadow dan border untuk mode cerah agar card tidak menyatu dengan background
            border: isLightMode
                ? Border.all(color: Colors.grey.withOpacity(0.2))
                : Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: isLightMode
                ? [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 35,
                ), // Ikon diperbesar sedikit untuk mengimbangi teks
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isLightMode ? Colors.black : Colors.white,
                        fontSize: 22, // Diperbesar menjadi 22
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isLightMode ? Colors.grey[700] : Colors.grey,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isLightMode ? Colors.grey[500] : Colors.grey,
                size: 28, // Panah diperbesar menyesuaikan teks
              ),
            ],
          ),
        ),
      ),
    );
  }
}
