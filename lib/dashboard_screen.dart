import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:io';
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
      final url = Uri.parse(
        'http://192.168.1.189:8000/api/maintenance/reports',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> fetchedReports = data['data'];

        int p = 0, v = 0, r = 0;
        for (var report in fetchedReports) {
          String status = report['status'] ?? 'Pending';
          if (status.toLowerCase().contains('verif')) {
            v++;
          } else if (status.toLowerCase().contains('reject')) {
            r++;
          } else {
            p++;
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
      ).then((_) => _fetchReports());
    } else {
      setState(() => _selectedIndex = index);
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
        selectedItemColor: const Color(0xFF00D1F3),
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailLaporanScreen(
                          reportData: data,
                          onRefresh: _fetchReports,
                          currentUserId: widget.userId,
                        ),
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailLaporanScreen(
              reportData: data,
              onRefresh: _fetchReports,
              currentUserId: widget.userId,
            ),
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

class TimelineItem extends StatelessWidget {
  final String id, sto, kategori, uraian, statusLabel;
  final Color statusColor;
  final StatusType type;
  final bool isFirst, isLast;
  final VoidCallback? onTap;

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
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              id,
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
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
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
// --- HALAMAN DETAIL LAPORAN (STATEFUL WIDGET) ---
// ======================================================================

class DetailLaporanScreen extends StatefulWidget {
  final Map<String, dynamic> reportData;
  final VoidCallback? onRefresh;
  final String currentUserId;

  const DetailLaporanScreen({
    super.key,
    required this.reportData,
    this.onRefresh,
    required this.currentUserId,
  });

  @override
  State<DetailLaporanScreen> createState() => _DetailLaporanScreenState();
}

class _DetailLaporanScreenState extends State<DetailLaporanScreen> {
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _uploadPhotosForCategory(String kategori) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 70,
      );
      if (pickedFiles.isEmpty) return;

      setState(() => _isUploading = true);

      String id = widget.reportData['id'].toString();
      var url = Uri.parse(
        "http://192.168.1.189:8000/api/maintenance/report/$id/add-photos",
      );

      var request = http.MultipartRequest('POST', url);
      request.headers.addAll({"Accept": "application/json"});

      String fieldName = "foto_${kategori.toLowerCase()}[]";

      for (var file in pickedFiles) {
        request.files.add(
          await http.MultipartFile.fromPath(fieldName, file.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Foto $kategori susulan berhasil dikirim!"),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onRefresh != null) {
          widget.onRefresh!();
        }
        Navigator.pop(context);
      } else {
        throw Exception("Gagal upload: ${response.body}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String idData =
        "MAINT-${widget.reportData['id'].toString().padLeft(3, '0')}";
    String status = widget.reportData['status']?.toString() ?? 'Pending';

    Color statusColor = Colors.amber;
    if (status.toLowerCase().contains('verif')) {
      statusColor = Colors.green;
    } else if (status.toLowerCase().contains('reject')) {
      statusColor = Colors.red;
    }

    // Mengambil latitude dan longitude sebagai String secara aman (mencegah error 'double is not subtype of String')
    String? latStr = widget.reportData['latitude']?.toString();
    String? lngStr = widget.reportData['longitude']?.toString();

    List<dynamic> allImages = widget.reportData['images'] ?? [];
    List<String> beforePaths = allImages
        .where((i) => i['type'] == 'before')
        .map((i) => i['image_path'].toString())
        .toList();
    List<String> progressPaths = allImages
        .where((i) => i['type'] == 'progress')
        .map((i) => i['image_path'].toString())
        .toList();
    List<String> afterPaths = allImages
        .where((i) => i['type'] == 'after')
        .map((i) => i['image_path'].toString())
        .toList();

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

            // --- BAGIAN LOKASI YANG DIPERBARUI ---
            const Text(
              "Informasi Lokasi & Link Maps",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161F2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    "Area",
                    widget.reportData['area']?.toString() ?? '-',
                  ),
                  _buildDetailRow(
                    "District",
                    widget.reportData['district']?.toString() ?? '-',
                  ),
                  _buildDetailRow(
                    "Witel",
                    widget.reportData['witel']?.toString() ?? '-',
                  ),
                  _buildDetailRow(
                    "STO",
                    widget.reportData['sto']?.toString() ?? '-',
                  ),

                  const Divider(color: Colors.white10, height: 30),

                  // Menggunakan variabel String yang aman dari error
                  _buildDetailRow("Latitude", latStr ?? '-'),
                  _buildDetailRow("Longitude", lngStr ?? '-'),

                  const SizedBox(height: 5),
                  const Text(
                    "Link Google Maps:",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    (latStr != null && lngStr != null && latStr.isNotEmpty)
                        ? "https://www.google.com/maps/search/?api=1&query=$latStr,$lngStr"
                        : "Koordinat belum tersedia",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (latStr != null &&
                            lngStr != null &&
                            latStr.isNotEmpty) {
                          final url =
                              "https://www.google.com/maps/search/?api=1&query=$latStr,$lngStr";
                          await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Koordinat tidak ditemukan"),
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.map,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        "Buka di Google Maps",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                widget.reportData['kategori_kegiatan']?.toString() ?? '-',
              ),
              _buildDetailRow(
                "Uraian Pekerjaan",
                widget.reportData['uraian_pekerjaan']?.toString() ?? '-',
              ),
              _buildDetailRow(
                "Mitra Pelaksana",
                widget.reportData['mitra_pelaksana']?.toString() ?? '-',
              ),
              _buildDetailRow(
                "Teknisi",
                widget.reportData['teknisi']?.toString() ?? '-',
              ),
              _buildDetailRow(
                "Waktu Laporan",
                widget.reportData['created_at']?.toString().substring(0, 10) ??
                    '-',
              ),
            ]),
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

            _buildPhotoCategory("Before", beforePaths),
            const SizedBox(height: 15),
            _buildPhotoCategory("Progress", progressPaths),
            const SizedBox(height: 15),
            _buildPhotoCategory("After", afterPaths),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

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

  Widget _buildPhotoCategory(String label, List<String> paths) {
    final String baseUrl = "http://192.168.1.189:8000/storage/";

    bool canAddPhoto =
        widget.currentUserId == widget.reportData['user_id'].toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label (${paths.length} Foto)",
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),

        if (paths.isEmpty)
          canAddPhoto
              ? InkWell(
                  onTap: _isUploading
                      ? null
                      : () => _uploadPhotosForCategory(label),
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue, width: 1.5),
                    ),
                    child: _isUploading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo, color: Colors.blue),
                              const SizedBox(height: 5),
                              Text(
                                "Tambah Foto $label",
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                )
              : Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                  ),
                )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: canAddPhoto ? paths.length + 1 : paths.length,
            itemBuilder: (context, index) {
              if (canAddPhoto && index == paths.length) {
                return InkWell(
                  onTap: _isUploading
                      ? null
                      : () => _uploadPhotosForCategory(label),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue, width: 1.5),
                    ),
                    child: _isUploading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(10.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                color: Colors.blue,
                                size: 24,
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Tambah",
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              }

              String fullUrl = baseUrl + paths[index];
              String heroTag = "image_${label}_$index";

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageScreen(
                        imageUrl: fullUrl,
                        heroTag: heroTag,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Hero(
                      tag: heroTag,
                      child: Image.network(
                        fullUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ======================================================================
// --- HALAMAN FULL SCREEN IMAGE VIEWER DENGAN ZOOM ---
// ======================================================================

class FullScreenImageScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImageScreen({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: heroTag,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, color: Colors.grey, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}
