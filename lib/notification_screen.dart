import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Pastikan IP disesuaikan
  final String serverUrl = 'http://192.168.1.41:8000/api';
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/notifications'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _notifications = data['data'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int id, int index) async {
    // Jika sudah dibaca, tidak perlu hit API lagi
    if (_notifications[index]['is_read'] == 1 ||
        _notifications[index]['is_read'] == true)
      return;

    setState(() {
      _notifications[index]['is_read'] = true;
    });

    try {
      await http.post(Uri.parse('$serverUrl/notifications/$id/read'));
    } catch (e) {
      debugPrint("Gagal update status read");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080E1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Text('Notifikasi', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? const Center(
              child: Text(
                "Belum ada notifikasi",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                final isRead =
                    notif['is_read'] == 1 || notif['is_read'] == true;

                return GestureDetector(
                  onTap: () {
                    _markAsRead(notif['id'], index);
                    // Optional: Kasih dialog atau navigasi ke detail laporan
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isRead
                          ? const Color(0xFF1A2336)
                          : const Color(0xFF1E3A8A).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isRead
                            ? Colors.transparent
                            : Colors.blueAccent.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isRead
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: isRead ? Colors.grey : Colors.orange,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notif['title'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                notif['message'],
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
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
