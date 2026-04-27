import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // Import library OneSignal
import 'role_selection_screen.dart';

void main() {
  // Inisialisasi binding Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Konfigurasi OneSignal menggunakan App ID Anda
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("c5e1b4de-5fdf-406e-ab45-7bb5b47ac450");

  // Meminta izin notifikasi (Muncul saat aplikasi pertama kali dijalankan)
  OneSignal.Notifications.requestPermission(true);

  runApp(const MaintenanceApp());
}

class MaintenanceApp extends StatelessWidget {
  const MaintenanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maintenance Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: RoleSelectionScreen(),
    );
  }
}
