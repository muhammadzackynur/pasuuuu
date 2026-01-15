import 'package:flutter/material.dart';
import 'role_selection_screen.dart';

void main() {
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
      // HAPUS 'const' di baris bawah ini
      home: RoleSelectionScreen(),
    );
  }
}
