import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart'; // Import konfigurasi API terpusat

class NotificationScreen extends StatefulWidget {
  final String userId; // Tambahan parameter User ID

  const NotificationScreen({super.key, required this.userId});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Menggunakan ApiConfig.baseUrl agar lebih fleksibel
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      // Panggil API dengan mengirimkan user_id menggunakan ApiConfig
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/notifications?user_id=${widget.userId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _notifications = data['data'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int id, int index) async {
    // Jika sudah dibaca, tidak perlu hit API lagi
    if (_notifications[index]['is_read'] == 1 ||
        _notifications[index]['is_read'] == true) {
      return;
    }

    setState(() {
      _notifications[index]['is_read'] = true;
    });

    try {
      // Menggunakan ApiConfig.baseUrl
      await http.post(Uri.parse('${ApiConfig.baseUrl}/notifications/$id/read'));
    } catch (e) {
      debugPrint("Gagal update status read");
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- DETEKSI TEMA CERAH / GELAP ---
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color bgColor = isLightMode
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF080E1C);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors
            .transparent, // Dibuat transparan agar seragam dengan halaman lain
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Notifikasi',
          style: TextStyle(
            color: textColor,
            fontSize: 20, // Judul AppBar 20
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _notifications.isEmpty
          ? Center(
              child: Text(
                "Belum ada notifikasi",
                style: TextStyle(
                  color: isLightMode ? Colors.grey[700] : Colors.grey,
                  fontSize: 19, // Diubah minimal 19
                ),
              ),
            )
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                final isRead =
                    notif['is_read'] == 1 || notif['is_read'] == true;

                // Pengaturan Warna Card berdasarkan status Read & Theme
                Color cardBgColor = isRead
                    ? (isLightMode ? Colors.white : const Color(0xFF1A2336))
                    : (isLightMode
                          ? Colors.blue.withOpacity(0.1)
                          : const Color(0xFF1E3A8A).withOpacity(0.4));
                Color borderColor = isRead
                    ? (isLightMode ? Colors.grey[300]! : Colors.white10)
                    : Colors.blueAccent.withOpacity(0.5);

                return GestureDetector(
                  onTap: () {
                    _markAsRead(notif['id'], index);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                      boxShadow: isLightMode && isRead
                          ? [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.15),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isRead
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: isRead
                              ? (isLightMode ? Colors.grey[500] : Colors.grey)
                              : (isLightMode
                                    ? Colors.orange[700]
                                    : Colors.orange),
                          size:
                              28, // Diperbesar sedikit agar proporsional dengan font
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notif['title'] ?? 'Laporan Baru!',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  fontSize: 20, // Judul Notifikasi 20
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notif['message'] ?? '-',
                                style: TextStyle(
                                  color: isLightMode
                                      ? Colors.grey[800]
                                      : Colors.grey[400],
                                  fontSize: 19, // Teks Pesan 19
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                notif['created_at']?.toString().substring(
                                      0,
                                      10,
                                    ) ??
                                    '',
                                style: TextStyle(
                                  color: isLightMode
                                      ? Colors.grey[600]
                                      : Colors.grey,
                                  fontSize: 19, // Teks Tanggal 19
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
