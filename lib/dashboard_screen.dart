import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'input_laporan_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String role;
  final String userId;
  final int databaseId;

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
  int _selectedIndex = 0;
  List<dynamic> _reports = [];
  bool _isLoading = true;

  // Variabel untuk statistik
  int _pendingCount = 0;
  int _verifiedCount = 0;
  int _rejectedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      // Pastikan IP ini sesuai dengan konfigurasi lokal Anda
      final url = Uri.parse(
        'http://192.168.1.45.189:8000/api/maintenance/reports',
      );
      final response = await http.get(url);

      print("LOG: Status Code = ${response.statusCode}");
      print("LOG: Response Body = ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> fetchedReports = data['data'];

        int p = 0;
        int v = 0;
        int r = 0;

        for (var report in fetchedReports) {
          String status = report['status'] ?? 'Pending';
          if (status.toLowerCase().contains('verif')) {
            v++;
          } else if (status.toLowerCase().contains('reject')) {
            r++;
          } else {
            p++; // Default Pending
          }
        }

        setState(() {
          _reports = fetchedReports;
          _pendingCount = p;
          _verifiedCount = v;
          _rejectedCount = r;
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

  void _onItemTapped(int index) {
    if (index == 1) {
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
        _fetchReports();
      });
    } else {
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
        bodyContent = _buildStatusContent(); // UI STATUS LAPORAN
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
      backgroundColor: const Color(0xFF0F1623),
      appBar: _selectedIndex == 3
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: const Icon(Icons.menu, color: Colors.white),
              title: Text(
                _selectedIndex == 2 ? 'Status Laporan' : 'Tim Lapangan',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: _fetchReports,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
                if (_selectedIndex != 2)
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
        backgroundColor: const Color(0xFF0F1623),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00D1F3), // Warna Cyan
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              backgroundColor: Color(0xFF1E293B),
              child: Icon(Icons.add, color: Color(0xFF00D1F3)),
            ),
            label: 'Tambah',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Status'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  // --- TAMPILAN HOME ---
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
                onPressed: () => setState(() => _selectedIndex = 2),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(color: Color(0xFF00D1F3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentReports.isEmpty)
            const Center(
              child: Text(
                "Belum ada laporan.",
                style: TextStyle(color: Colors.grey),
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
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // --- TAMPILAN STATUS ---
  Widget _buildStatusContent() {
    int totalReports = _reports.length;
    int flexP = _pendingCount > 0 ? _pendingCount : 1;
    int flexV = _verifiedCount > 0 ? _verifiedCount : 1;
    int flexR = _rejectedCount > 0 ? _rejectedCount : 1;

    if (totalReports == 0) {
      flexP = 1;
      flexV = 1;
      flexR = 1;
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const FilterChipWidget(label: "Semua", isActive: true),
                const SizedBox(width: 10),
                FilterChipWidget(
                  label: "Pending",
                  count: _pendingCount,
                  isActive: false,
                ),
                const SizedBox(width: 10),
                FilterChipWidget(
                  label: "Verified",
                  count: _verifiedCount,
                  isActive: false,
                ),
                const SizedBox(width: 10),
                FilterChipWidget(
                  label: "Rejected",
                  count: _rejectedCount,
                  isActive: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // 2. Dashboard Card (Laporan Saya)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Laporan Saya",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 5),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "$totalReports ",
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const TextSpan(
                        text: "Total",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF00D1F3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // Custom Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        if (totalReports > 0) ...[
                          Expanded(
                            flex: flexP,
                            child: Container(color: Colors.amber),
                          ),
                          Expanded(
                            flex: flexV,
                            child: Container(color: Colors.green),
                          ),
                          Expanded(
                            flex: flexR,
                            child: Container(color: Colors.red),
                          ),
                        ] else
                          Expanded(
                            child: Container(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Stats Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatItem(
                      icon: Icons.more_horiz,
                      count: _pendingCount.toString(),
                      label: "PEND",
                      color: Colors.amber,
                    ),
                    StatItem(
                      icon: Icons.check_circle_outline,
                      count: _verifiedCount.toString(),
                      label: "VERIF",
                      color: Colors.green,
                    ),
                    StatItem(
                      icon: Icons.cancel_outlined,
                      count: _rejectedCount.toString(),
                      label: "REJECT",
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),
          const Text(
            "Daftar Pekerjaan",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 15),

          // 3. Timeline List
          if (_reports.isEmpty)
            const Center(
              child: Text(
                "Tidak ada aktivitas",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reports.length,
              itemBuilder: (context, index) {
                final data = _reports[index];

                // Mapping Status
                String statusStr = data['status'] ?? 'Pending';
                StatusType type = StatusType.pending;
                Color sColor = Colors.amber;

                if (statusStr.toLowerCase().contains('verif')) {
                  type = StatusType.verified;
                  sColor = Colors.green;
                } else if (statusStr.toLowerCase().contains('reject')) {
                  type = StatusType.rejected;
                  sColor = Colors.red;
                }

                return TimelineItem(
                  id: "MAINT-${data['id'].toString().padLeft(3, '0')}",
                  sto: data['sto'] ?? 'STO Tidak Diketahui',
                  kategori: data['kategori_kegiatan'] ?? '-',
                  uraian: data['uraian_pekerjaan'] ?? '-',
                  statusLabel: statusStr.toUpperCase(),
                  statusColor: sColor,
                  type: type,
                  isFirst: index == 0,
                  isLast: index == _reports.length - 1,
                  // FUNGSI ONTAP DIPANGGIL DI SINI
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DetailLaporanScreen(reportData: data),
                      ),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // --- WIDGET HELPER BAWAAN ---
  Widget _buildGreetingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: const Border(
          left: BorderSide(color: Color(0xFF00D1F3), width: 4),
        ),
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
        ],
      ),
    );
  }

  Widget _buildReportItem(dynamic data) {
    String id = "MAINT-${data['id'].toString().padLeft(3, '0')}";
    String location = data['sto'] ?? 'STO -';
    String status = data['status'] ?? 'TERKIRIM';
    Color statusColor = status.toLowerCase().contains('pend')
        ? Colors.amber
        : Colors.green;

    return InkWell(
      onTap: () {
        // Berikan fitur klik juga pada laporan terbaru di halaman Home
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailLaporanScreen(reportData: data),
          ),
        );
      },
      child: Container(
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
                  Text(
                    location,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        children: const [
          Icon(Icons.lightbulb, color: Colors.yellow),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tip: Pastikan GPS aktif saat input laporan.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// --- CLASS WIDGET TAMBAHAN ---

class FilterChipWidget extends StatelessWidget {
  final String label;
  final int? count;
  final bool isActive;

  const FilterChipWidget({
    super.key,
    required this.label,
    this.count,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF00D1F3) : const Color(0xFF1E2738),
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? null
            : Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.black.withOpacity(0.2)
                    : Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.black : Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final IconData icon;
  final String count;
  final String label;
  final Color color;

  const StatItem({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1623),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            count,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}

enum StatusType { pending, verified, rejected }

// --- TIMELINE ITEM UPDATE (Ditambahkan Fitur Klik) ---
class TimelineItem extends StatelessWidget {
  final String id;
  final String sto;
  final String kategori;
  final String uraian;
  final String statusLabel;
  final Color statusColor;
  final StatusType type;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap; // Tambahkan parameter onTap

  const TimelineItem({
    super.key,
    required this.id,
    required this.sto,
    required this.kategori,
    required this.uraian,
    required this.statusLabel,
    required this.statusColor,
    required this.type,
    this.isFirst = false,
    this.isLast = false,
    this.onTap, // Inisialisasi parameter onTap
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Garis Timeline
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFF00D1F3)),
                  ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: type == StatusType.rejected
                          ? Colors.red
                          : const Color(0xFF00D1F3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.transparent,
                    child: Icon(
                      type == StatusType.pending
                          ? Icons.circle
                          : type == StatusType.verified
                          ? Icons.check
                          : Icons.close,
                      size: 12,
                      color: type == StatusType.pending
                          ? Colors.amber
                          : type == StatusType.verified
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFF00D1F3)),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Kartu Data Dibungkus dengan InkWell agar bisa di klik
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF161F2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onTap, // Menjalankan fungsi onTap saat diklik
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: ID dan Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              id, // MAINT-00X
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // STO (Lokasi)
                        Row(
                          children: [
                            const Icon(
                              Icons.location_city,
                              size: 16,
                              color: Color(0xFF00D1F3),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sto,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Kategori Kegiatan
                        Row(
                          children: [
                            const Icon(
                              Icons.category,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                kategori,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Divider Kecil
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),

                        // Uraian Pekerjaan
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.description,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                uraian,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
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
}

// ======================================================================
// --- HALAMAN BARU UNTUK DETAIL LAPORAN ---
// ======================================================================

class DetailLaporanScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;

  const DetailLaporanScreen({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    // Format ID Data
    String idData = "MAINT-${reportData['id'].toString().padLeft(3, '0')}";
    String status = reportData['status'] ?? 'Pending';

    // Status color mapping
    Color statusColor = Colors.amber;
    if (status.toLowerCase().contains('verif')) {
      statusColor = Colors.green;
    } else if (status.toLowerCase().contains('reject')) {
      statusColor = Colors.red;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1623),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Detail Laporan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161F2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "ID Laporan",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        idData,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "Informasi Lokasi",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailCard([
              _buildDetailRow("Area", reportData['area'] ?? '-'),
              _buildDetailRow("District", reportData['district'] ?? '-'),
              _buildDetailRow("Witel", reportData['witel'] ?? '-'),
              _buildDetailRow("STO", reportData['sto'] ?? '-'),
            ]),

            const SizedBox(height: 24),
            const Text(
              "Rincian Pekerjaan",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailCard([
              _buildDetailRow(
                "Kategori Kegiatan",
                reportData['kategori_kegiatan'] ?? '-',
              ),
              _buildDetailRow(
                "Uraian Pekerjaan",
                reportData['uraian_pekerjaan'] ?? '-',
              ),
              _buildDetailRow(
                "Mitra Pelaksana",
                reportData['mitra_pelaksana'] ?? '-',
              ),
              _buildDetailRow("Teknisi", reportData['teknisi'] ?? '-'),
              _buildDetailRow(
                "Waktu Laporan",
                reportData['created_at']?.toString().substring(0, 10) ?? '-',
              ),
            ]),

            // --- SEKSI TAMPILAN FOTO BUKTI ---
            const SizedBox(height: 24),
            const Text(
              "Bukti Foto Lapangan",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePreview("Before", reportData['foto_before']),
                _buildImagePreview("Progress", reportData['foto_progress']),
                _buildImagePreview("After", reportData['foto_after']),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Helper widget untuk membuat card container rincian
  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }

  // Helper widget untuk membuat baris detail
  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI TAMPILAN FOTO (Wajib Ada di dalam class DetailLaporanScreen) ---
  Widget _buildImagePreview(String label, String? imagePath) {
    // URL dasar storage Laravel Anda
    final String baseUrl = "http://192.168.1.45:8000/storage/";

    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: (imagePath != null && imagePath.isNotEmpty)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    baseUrl + imagePath,
                    fit: BoxFit.cover,
                    // Menangani jika gambar tidak ditemukan di server
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                )
              : const Icon(Icons.image_not_supported, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}
