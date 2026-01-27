import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'input_laporan_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String role;
  final String userId; // ID Tampilan (misal TEK-001)
  final int databaseId; // ID Database (Primary Key)

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.role,
    required this.userId,
    required this.databaseId,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; // 0: Home, 1: Add (Action), 2: Status, 3: Profile
  List<dynamic> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  // --- FUNGSI AMBIL DATA DARI BACKEND ---
  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      // GANTI IP INI dengan IP Laptop/Server Anda
      final url = Uri.parse(
        'http://192.168.100.192:8000/api/maintenance/reports',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _reports = data['data'];
          _isLoading = false;
        });
      } else {
        print("Gagal mengambil data: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error koneksi: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- LOGIKA NAVIGASI ---
  void _onItemTapped(int index) {
    if (index == 1) {
      // Navigasi ke Input Laporan
      // PERBAIKAN: Mengirim data user ke InputLaporanScreen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InputLaporanScreen(
            userName: widget.userName,
            role: widget.role,
            userId: widget.userId,
            databaseId: widget.databaseId,
          ),
        ),
      ).then((_) {
        // Refresh data saat kembali dari halaman input
        _fetchReports();
      });
    } else {
      // Pindah Tab
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    switch (_selectedIndex) {
      case 0:
        bodyContent = _buildHomeContent();
        break;
      case 2:
        bodyContent = _buildStatusContent();
        break;
      case 3:
        bodyContent = ProfileScreen(
          userName: widget.userName,
          role: widget.role,
          userId: widget.userId,
          databaseId: widget.databaseId,
        );
        break;
      default:
        bodyContent = _buildHomeContent();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
      appBar: _selectedIndex == 3
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: const Icon(Icons.menu, color: Colors.white),
              title: Text(
                _selectedIndex == 2 ? 'Status Laporan' : 'Tim Lapangan',
                style: const TextStyle(color: Colors.white),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: _fetchReports,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
                Stack(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.notifications,
                        color: Colors.white,
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 8,
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.cyan,
                    child: Text(
                      'AY',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_selectedIndex == 3
                ? bodyContent
                : RefreshIndicator(
                    onRefresh: _fetchReports,
                    child: bodyContent,
                  )),

      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0D1424),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.cyan,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              backgroundColor: Color(0xFF1E293B),
              child: Icon(Icons.add, color: Colors.cyan),
            ),
            label: 'Tambah Data',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Status'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  // --- TAMPILAN HOME (Dashboard) ---
  Widget _buildHomeContent() {
    final recentReports = _reports.take(4).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreetingCard(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Laporan Terbaru',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selectedIndex = 2);
                },
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(color: Colors.cyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (recentReports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  "Belum ada laporan.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...recentReports
                .map(
                  (data) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildReportItem(data),
                  ),
                )
                .toList(),

          const SizedBox(height: 12),
          _buildTipCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- TAMPILAN STATUS (List Semua Laporan) ---
  Widget _buildStatusContent() {
    if (_reports.isEmpty) {
      return const Center(
        child: Text("Belum ada data.", style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildReportItem(_reports[index]),
        );
      },
    );
  }

  // --- COMPONENTS ---

  Widget _buildGreetingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: const Border(left: BorderSide(color: Colors.cyan, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('👋', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            'Halo, ${widget.userName}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Selamat bekerja hari ini!',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Icon(Icons.calendar_today, color: Colors.grey, size: 16),
              SizedBox(width: 8),
              Text('Hari ini', style: TextStyle(color: Colors.grey)),
              SizedBox(width: 16),
              Icon(Icons.wb_sunny, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text('Cerah', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(dynamic data) {
    String id = "MAINT-${data['id'].toString().padLeft(3, '0')}";
    String location = data['lokasi_pekerjaan'] ?? 'Lokasi tidak diketahui';
    String date = data['time_plan'] ?? '-';
    String maintenanceType = data['jenis_maintenance'] ?? 'Maintenance';
    String status = "TERKIRIM";
    Color statusColor = Colors.green;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        location,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  "$date • $maintenanceType",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.yellow.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Colors.yellow),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tip: Pastikan GPS aktif sebelum input laporan untuk akurasi lokasi.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.close, color: Colors.white70, size: 16),
          ),
        ],
      ),
    );
  }
}
