import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'notification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String userName;
  final String role;
  final String? userId;

  const AdminDashboardScreen({
    super.key,
    required this.userName,
    required this.role,
    this.userId,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;

  List<dynamic> _allReports = [];
  List<dynamic> _recentReports = [];

  // Variabel untuk fitur Notifikasi
  int _unreadNotifCount = 0;
  Timer? _notificationTimer;

  final String serverUrl = 'http://192.168.1.9:8000/api';

  int _totalCount = 0;
  int _pendingCount = 0;
  int _verifiedCount = 0;
  int _rejectedCount = 0;

  int _selectedFilterIndex = 0;
  final List<String> _filterOptions = [
    'Semua',
    'Pending',
    'Verified',
    'Rejected',
  ];

  int touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
    _fetchUnreadCount(); // Panggil fungsi notifikasi lonceng saat aplikasi dibuka
    _startNotificationCheck();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  // =========================================================================
  // FUNGSI NOTIFIKASI LONCENG
  // =========================================================================
  Future<void> _fetchUnreadCount() async {
    try {
      final response = await http.get(Uri.parse('$serverUrl/notifications'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _unreadNotifCount = data['unread_count'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error get notif count: $e");
    }
  }

  // =========================================================================
  // FUNGSI NOTIFIKASI (CEK LAPORAN BARU SETIAP 10 DETIK)
  // =========================================================================
  void _startNotificationCheck() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      try {
        final url = Uri.parse(
          'http://192.168.1.9:8000/api/maintenance/reports',
        );
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          List<dynamic> fetchedReports = data['data'] ?? [];

          if (fetchedReports.length > _allReports.length) {
            if (_allReports.isNotEmpty) {
              _showNewReportNotification();
            }
            _refreshDataSilently(fetchedReports);
            _fetchUnreadCount(); // Update titik kuning jika ada laporan baru secara realtime
          }
        }
      } catch (e) {
        print("Error Polling: $e");
      }
    });
  }

  void _refreshDataSilently(List<dynamic> newReports) {
    int p = 0, v = 0, r = 0;
    for (var report in newReports) {
      String status = (report['status'] ?? 'Pending').toString().toLowerCase();
      if (status.contains('verif'))
        v++;
      else if (status.contains('reject'))
        r++;
      else
        p++;
    }

    setState(() {
      _allReports = newReports;
      _recentReports = newReports.take(5).toList();
      _totalCount = newReports.length;
      _pendingCount = p;
      _verifiedCount = v;
      _rejectedCount = r;
    });
  }

  void _showNewReportNotification() {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.notifications_active, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Laporan Baru Masuk dari Tim Lapangan!",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: "LIHAT",
          textColor: Colors.white,
          onPressed: () {
            setState(() => _selectedIndex = 1);
          },
        ),
      ),
    );
  }

  // =========================================================================
  // FUNGSI MENGAMBIL DATA DARI SERVER
  // =========================================================================
  Future<void> _fetchAdminData() async {
    try {
      final url = Uri.parse('http://192.168.1.9:8000/api/maintenance/reports');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> fetchedReports = data['data'] ?? [];

        int p = 0, v = 0, r = 0;
        for (var report in fetchedReports) {
          String status = (report['status'] ?? 'Pending')
              .toString()
              .toLowerCase();
          if (status.contains('verif')) {
            v++;
          } else if (status.contains('reject')) {
            r++;
          } else {
            p++;
          }
        }

        fetchedReports.sort(
          (a, b) => (b['id'] as int).compareTo(a['id'] as int),
        );

        if (mounted) {
          setState(() {
            _allReports = fetchedReports;
            _recentReports = fetchedReports.take(5).toList();
            _totalCount = fetchedReports.length;
            _pendingCount = p;
            _verifiedCount = v;
            _rejectedCount = r;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error koneksi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int reportId, String newStatus) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00D1F3)),
      ),
    );

    try {
      final url = Uri.parse(
        'http://192.168.1.9:8000/api/maintenance/reports/$reportId/status',
      );

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Laporan MAINT-${reportId.toString().padLeft(3, '0')} berhasil di-$newStatus!",
            ),
            backgroundColor: newStatus == 'Verified'
                ? Colors.green
                : Colors.red,
          ),
        );
        _fetchAdminData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal: ${response.statusCode} - ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      print("KONEKSI ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error koneksi ke server"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmUpdateStatus(
    BuildContext context,
    int reportId,
    String newStatus,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161F2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "Konfirmasi Tindakan",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Apakah Anda yakin ingin mengubah status laporan MAINT-${reportId.toString().padLeft(3, '0')} menjadi $newStatus?",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: newStatus == 'Verified'
                    ? Colors.green
                    : Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _updateStatus(reportId, newStatus);
              },
              child: Text(
                newStatus == 'Verified' ? "Ya, Verifikasi" : "Ya, Tolak",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  List<dynamic> get _filteredReports {
    if (_selectedFilterIndex == 0) return _allReports;
    String targetStatus = '';
    if (_selectedFilterIndex == 1) targetStatus = 'pending';
    if (_selectedFilterIndex == 2) targetStatus = 'verified';
    if (_selectedFilterIndex == 3) targetStatus = 'rejected';

    return _allReports.where((report) {
      String status = (report['status'] ?? 'pending').toString().toLowerCase();
      return status.contains(targetStatus);
    }).toList();
  }

  void _showAddUserDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController idController = TextEditingController();
    String selectedRole = 'Tim Lapangan';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161F2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Daftarkan Pengguna",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Nama Lengkap",
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: idController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "User ID (Unik)",
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Jabatan / Role",
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 5,
                        ),
                      ),
                      items: ['Tim Lapangan', 'Tim Administrasi']
                          .map(
                            (String role) => DropdownMenuItem<String>(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                      onChanged: (newValue) =>
                          setStateDialog(() => selectedRole = newValue!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text(
                    "Batal",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D1F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty ||
                              idController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Nama dan User ID tidak boleh kosong!",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setStateDialog(() => isSubmitting = true);
                          try {
                            final url = Uri.parse(
                              'http://192.168.1.9:8000/api/users/register',
                            );
                            final response = await http.post(
                              url,
                              body: {
                                'name': nameController.text.trim(),
                                'user_id': idController.text.trim(),
                                'role': selectedRole,
                              },
                            );
                            setStateDialog(() => isSubmitting = false);
                            if (response.statusCode == 201 ||
                                response.statusCode == 200) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Pengguna berhasil didaftarkan!",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Gagal. Pastikan User ID belum dipakai!",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            setStateDialog(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Error: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Simpan",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    if (_selectedIndex == 0) {
      bodyContent = _buildHomeContent();
    } else if (_selectedIndex == 1) {
      bodyContent = _buildDataContent();
    } else if (_selectedIndex == 2) {
      bodyContent = _buildAnalyticsContent();
    } else if (_selectedIndex == 3) {
      bodyContent = _buildProfileContent();
    } else {
      bodyContent = const Center(
        child: Text(
          "Halaman belum tersedia",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A101D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 20.0),
          child: CircleAvatar(
            backgroundColor: Color(0xFF1E293B),
            child: Icon(Icons.person, color: Colors.white),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Good Morning,',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              widget.userName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              // Navigasi ke halaman notifikasi dan update badge saat kembali
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const NotificationScreen(userId: 'admin'),
                ), // <--- TAMBAHKAN userId: 'admin'
              );
              _fetchUnreadCount(); // Refresh jumlah notifikasi saat kembali ke dashboard
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications, color: Colors.white),
                if (_unreadNotifCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.orange, // Titik kuning/orange notifikasi
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_unreadNotifCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.logout, color: Colors.redAccent),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D1F3)),
            )
          : RefreshIndicator(onRefresh: _fetchAdminData, child: bodyContent),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF0F1623),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00D1F3),
        unselectedItemColor: Colors.grey.shade600,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.dataset), label: 'Data'),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. KONTEN HOME
  // =========================================================================
  Widget _buildHomeContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00D1F3), Color(0xFF00A3FF)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total Reports",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.insert_chart,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _totalCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Row(
            children: [
              _buildSmallStatCard(
                "Pending",
                _pendingCount.toString(),
                Colors.orange,
                Icons.hourglass_top,
              ),
              const SizedBox(width: 15),
              _buildSmallStatCard(
                "Verified",
                _verifiedCount.toString(),
                Colors.green,
                Icons.check_circle_outline,
              ),
              const SizedBox(width: 15),
              _buildSmallStatCard(
                "Rejected",
                _rejectedCount.toString(),
                Colors.red,
                Icons.cancel_outlined,
              ),
            ],
          ),
          const SizedBox(height: 35),
          const Text(
            "Quick Actions",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionBtn(
                Icons.folder_shared,
                "Manage Data",
                const Color(0xFF3B82F6),
                () => _onItemTapped(1),
              ),
              _buildQuickActionBtn(
                Icons.analytics,
                "Analytics",
                const Color(0xFF8B5CF6),
                () => _onItemTapped(2),
              ),
              _buildQuickActionBtn(
                Icons.fact_check,
                "Verification",
                const Color(0xFF10B981),
                () {
                  setState(() => _selectedFilterIndex = 1);
                  _onItemTapped(1);
                },
              ),
            ],
          ),
          const SizedBox(height: 35),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Activity",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => _onItemTapped(1),
                child: const Text(
                  "See All",
                  style: TextStyle(color: Color(0xFF00D1F3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_recentReports.isEmpty)
            const Center(
              child: Text(
                "No recent activity.",
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentReports.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminDetailLaporanScreen(
                          reportData: _recentReports[index],
                        ),
                      ),
                    );
                  },
                  child: _buildActivityTile(_recentReports[index]),
                );
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. KONTEN DATA
  // =========================================================================
  Widget _buildDataContent() {
    List<dynamic> currentData = _filteredReports;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          decoration: const BoxDecoration(
            color: Color(0xFF0A101D),
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_filterOptions.length, (index) {
                bool isSelected = _selectedFilterIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => setState(() => _selectedFilterIndex = index),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00D1F3)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        _filterOptions[index],
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.grey,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        Expanded(
          child: currentData.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: currentData.length,
                  itemBuilder: (context, index) {
                    return _buildDataCard(currentData[index]);
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // 3. KONTEN ANALYTICS
  // =========================================================================
  Widget _buildAnalyticsContent() {
    if (_allReports.isEmpty) {
      return const Center(
        child: Text(
          "Belum ada data untuk dianalisis",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    double completionRate = _totalCount == 0
        ? 0
        : (_verifiedCount / _totalCount) * 100;

    Map<String, int> stoCount = {};
    for (var r in _allReports) {
      String sto = (r['sto'] ?? 'Unknown').toString().trim();
      if (sto.isEmpty) sto = 'Unknown';
      stoCount[sto] = (stoCount[sto] ?? 0) + 1;
    }
    var sortedSto = stoCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var top5Sto = sortedSto.take(5).toList();

    Map<String, int> techCount = {};
    for (var r in _allReports) {
      String tech = (r['teknisi'] ?? 'Unknown').toString().trim();
      if (tech.isEmpty) tech = 'Unknown';
      techCount[tech] = (techCount[tech] ?? 0) + 1;
    }
    var sortedTech = techCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var top5Tech = sortedTech.take(5).toList();

    Map<String, int> catCount = {};
    for (var r in _allReports) {
      String cat = (r['kategori_kegiatan'] ?? 'Lainnya').toString().trim();
      if (cat.isEmpty) cat = 'Lainnya';
      catCount[cat] = (catCount[cat] ?? 0) + 1;
    }
    var sortedCat = catCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Descriptive Analytics",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Overview & performa pemeliharaan",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 25),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161F2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.task_alt, color: Colors.green),
                      const SizedBox(height: 10),
                      Text(
                        "${completionRate.toStringAsFixed(1)}%",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Completion Rate",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161F2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00D1F3).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.analytics, color: Color(0xFF00D1F3)),
                      const SizedBox(height: 10),
                      Text(
                        "$_totalCount",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Total Laporan",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          const Text(
            "Distribusi Status Pekerjaan",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            height: 250,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              touchedPieIndex = -1;
                              return;
                            }
                            touchedPieIndex = pieTouchResponse
                                .touchedSection!
                                .touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          color: Colors.orange,
                          value: _pendingCount.toDouble(),
                          title: '$_pendingCount',
                          radius: touchedPieIndex == 0 ? 60.0 : 50.0,
                          titleStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: Colors.green,
                          value: _verifiedCount.toDouble(),
                          title: '$_verifiedCount',
                          radius: touchedPieIndex == 1 ? 60.0 : 50.0,
                          titleStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        PieChartSectionData(
                          color: Colors.red,
                          value: _rejectedCount.toDouble(),
                          title: '$_rejectedCount',
                          radius: touchedPieIndex == 2 ? 60.0 : 50.0,
                          titleStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegend(Colors.orange, "Pending"),
                    const SizedBox(height: 10),
                    _buildLegend(Colors.green, "Verified"),
                    const SizedBox(height: 10),
                    _buildLegend(Colors.red, "Rejected"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          const Text(
            "Lokasi Kritis (Top 5 STO)",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            height: 250,
            padding: const EdgeInsets.only(
              top: 30,
              right: 20,
              left: 10,
              bottom: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: top5Sto.isEmpty
                ? const Center(
                    child: Text(
                      "Tidak ada data",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: top5Sto.first.value.toDouble() + 2,
                      barTouchData: BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value.toInt() < 0 ||
                                  value.toInt() >= top5Sto.length)
                                return const SizedBox.shrink();
                              String title = top5Sto[value.toInt()].key;
                              if (title.length > 5)
                                title = title.substring(0, 5);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (val, meta) => Text(
                              val.toInt().toString(),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: Colors.white10, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(top5Sto.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: top5Sto[i].value.toDouble(),
                              color: const Color(0xFFEAB308),
                              width: 16,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
          const SizedBox(height: 30),

          const Text(
            "Distribusi Jenis Gangguan",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedCat.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Colors.white10, height: 24),
              itemBuilder: (context, index) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        sortedCat[index].key,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D1F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${sortedCat[index].value} Kasus",
                        style: const TextStyle(
                          color: Color(0xFF00D1F3),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 4. KONTEN PROFIL (ADMIN)
  // =========================================================================
  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00D1F3), width: 2),
              color: const Color(0xFF161F2E),
            ),
            child: const Icon(Icons.person, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 15),

          Text(
            widget.userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00D1F3).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.role,
              style: const TextStyle(
                color: Color(0xFF00D1F3),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 30),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D1F3).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.badge, color: Color(0xFF00D1F3)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "User ID",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.userId ?? 'ADMIN-PST',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: widget.userId ?? 'ADMIN-PST'),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("User ID berhasil disalin!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Pengaturan Akun & Admin",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 15),

          _buildNewProfileMenuItem(
            Icons.person_add_alt_1,
            "Daftarkan Pengguna Baru",
            () => _showAddUserDialog(context),
          ),
          _buildNewProfileMenuItem(Icons.person_outline, "Edit Profil", () {}),

          // --- MENU BARU: JADWAL & TIM LAPANGAN (TLA) UNTUK ADMIN ---
          _buildNewProfileMenuItem(
            Icons.calendar_month,
            "Jadwal & Tim Lapangan (TLA)",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const JadwalScreen()),
              );
            },
          ),

          _buildNewProfileMenuItem(Icons.lock_outline, "Ganti Password", () {}),
          _buildNewProfileMenuItem(
            Icons.notifications_none,
            "Notifikasi",
            () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const NotificationScreen(userId: 'admin'),
                ), // <--- TAMBAHKAN userId: 'admin'
              );
              _fetchUnreadCount();
            },
          ),
          _buildNewProfileMenuItem(
            Icons.help_outline,
            "Bantuan & Support",
            () {},
          ),

          const SizedBox(height: 10),
          _buildNewProfileMenuItem(Icons.logout, "Keluar Aplikasi", () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }, isDestructive: true),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNewProfileMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDestructive
              ? Colors.red.withOpacity(0.3)
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDestructive
                      ? Colors.redAccent
                      : const Color(0xFF00D1F3),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.redAccent : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDestructive
                      ? Colors.transparent
                      : Colors.grey.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // WIDGET CARD UNTUK MENU DATA (DENGAN TOMBOL KONFIRMASI)
  Widget _buildDataCard(dynamic data) {
    String idStr = "MAINT-${data['id'].toString().padLeft(3, '0')}";
    bool isPending = (data['status'] ?? '').toString().toLowerCase().contains(
      'pending',
    );
    Color statusColor = isPending
        ? Colors.orange
        : (data['status'].toString().toLowerCase().contains('verif')
              ? Colors.green
              : Colors.red);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AdminDetailLaporanScreen(reportData: data),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          idStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['created_at']?.toString().substring(0, 10) ??
                              '-',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AdminEditLaporanScreen(reportData: data),
                              ),
                            );
                            if (result == true) _fetchAdminData();
                          },
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: statusColor.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            (data['status'] ?? 'PENDING').toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      Icons.person,
                      "Teknisi",
                      data['teknisi'] ?? 'Teknisi Lapangan',
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(Icons.map, "Witel", data['witel'] ?? '-'),
                    const SizedBox(height: 10),
                    _buildInfoRow(Icons.location_on, "STO", data['sto'] ?? '-'),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      Icons.category,
                      "Kategori",
                      data['kategori_kegiatan'] ?? '-',
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Uraian Pekerjaan:",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      data['uraian_pekerjaan'] ?? '-',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (isPending) ...[
                const Divider(color: Colors.white10, height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmUpdateStatus(
                            context,
                            data['id'],
                            'Rejected',
                          ),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          label: const Text(
                            "Tolak",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmUpdateStatus(
                            context,
                            data['id'],
                            'Verified',
                          ),
                          icon: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            "Verifikasi",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF00D1F3), size: 16),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const Text(":", style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 15),
          const Text(
            "Tidak ada data ditemukan",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Coba ubah filter kategori Anda.",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161F2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionBtn(
    IconData icon,
    String label,
    Color bgColor,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: bgColor.withOpacity(0.3)),
            ),
            child: Icon(icon, color: bgColor, size: 28),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTile(dynamic data) {
    Color statusColor =
        (data['status'] ?? '').toString().toLowerCase().contains('verif')
        ? Colors.green
        : (data['status'] ?? '').toString().toLowerCase().contains('reject')
        ? Colors.red
        : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['kategori_kegiatan'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "Report ID: MAINT-${data['id'].toString().padLeft(3, '0')}",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            (data['status'] ?? 'PENDING').toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// --- HALAMAN DETAIL LAPORAN UNTUK ADMIN ---
// ======================================================================
class AdminDetailLaporanScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;
  const AdminDetailLaporanScreen({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    String idData = "MAINT-${reportData['id'].toString().padLeft(3, '0')}";
    String status = reportData['status'] ?? 'Pending';
    Color statusColor = status.toLowerCase().contains('verif')
        ? Colors.green
        : status.toLowerCase().contains('reject')
        ? Colors.red
        : Colors.orange;

    String? latStr = reportData['latitude']?.toString();
    String? lngStr = reportData['longitude']?.toString();
    String mapsUrl = (latStr != null && lngStr != null && latStr.isNotEmpty)
        ? "https://www.google.com/maps?q=$latStr,$lngStr"
        : "Koordinat belum tersedia";

    List<dynamic> allImages = reportData['images'] ?? [];
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
      backgroundColor: const Color(0xFF0A101D),
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

            // --- BAGIAN LOKASI & LINK MAPS ---
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
                    reportData['area']?.toString() ?? '-',
                  ),
                  _buildDetailRow(
                    "District",
                    reportData['district']?.toString() ?? '-',
                  ),
                  _buildDetailRow(
                    "Witel",
                    reportData['witel']?.toString() ?? '-',
                  ),
                  _buildDetailRow("STO", reportData['sto']?.toString() ?? '-'),
                  const Divider(color: Colors.white10, height: 30),
                  _buildDetailRow("Latitude", latStr ?? '-'),
                  _buildDetailRow("Longitude", lngStr ?? '-'),

                  const SizedBox(height: 5),
                  const Text(
                    "Link Google Maps:",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    mapsUrl,
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
                          await launchUrl(
                            Uri.parse(mapsUrl),
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161F2E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    "Kategori",
                    reportData['kategori_kegiatan'] ?? '-',
                  ),
                  _buildDetailRow(
                    "Mitra",
                    reportData['mitra_pelaksana'] ?? '-',
                  ),
                  _buildDetailRow("Teknisi", reportData['teknisi'] ?? '-'),
                  _buildDetailRow(
                    "Waktu Input",
                    reportData['created_at']?.toString().substring(0, 10) ??
                        '-',
                  ),
                  const Divider(color: Colors.white10, height: 30),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Uraian Pekerjaan:",
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      reportData['uraian_pekerjaan'] ?? '-',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- BAGIAN BUKTI FOTO ---
            const Text(
              "Bukti Foto Lapangan",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPhotoCategory(context, "Before", beforePaths),
            const SizedBox(height: 15),
            _buildPhotoCategory(context, "Progress", progressPaths),
            const SizedBox(height: 15),
            _buildPhotoCategory(context, "After", afterPaths),

            const SizedBox(height: 24),
            const Text(
              "Lampiran Evidence",
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
              ),
              child: Column(
                children: [
                  _buildEvidenceStatus(
                    context,
                    "Material Tiba",
                    reportData['evidence_material'],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _buildEvidenceStatus(
                    context,
                    "Hasil Ukur",
                    reportData['evidence_ukur'],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _buildEvidenceStatus(
                    context,
                    "Pendukung/BA",
                    reportData['evidence_pendukung'],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
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

  Widget _buildPhotoCategory(
    BuildContext context,
    String label,
    List<String> paths,
  ) {
    const String baseUrl = "http://192.168.1.9:8000/storage/";
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
        paths.isEmpty
            ? Container(
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
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: paths.length,
                itemBuilder: (context, index) {
                  String fullUrl = "$baseUrl${paths[index]}";
                  String heroTag = "admin_image_${label}_$index";
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
                            errorBuilder: (c, e, s) => const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
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

  Widget _buildEvidenceStatus(
    BuildContext context,
    String title,
    dynamic path,
  ) {
    bool isUploaded = path != null && path.toString().isNotEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isUploaded
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isUploaded ? "Terlampir" : "Kosong",
                style: TextStyle(
                  color: isUploaded ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isUploaded) ...[
              const SizedBox(width: 10),
              InkWell(
                onTap: () async {
                  final String fileUrl =
                      'http://192.168.1.9:8000/storage/$path';
                  final Uri url = Uri.parse(fileUrl);
                  if (await canLaunchUrl(url))
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  else
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Tidak dapat membuka file"),
                        backgroundColor: Colors.red,
                      ),
                    );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download,
                    color: Colors.blue,
                    size: 18,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ======================================================================
// --- HALAMAN EDIT LAPORAN & UPLOAD BUKTI UNTUK ADMIN ---
// ======================================================================
class AdminEditLaporanScreen extends StatefulWidget {
  final Map<String, dynamic> reportData;
  const AdminEditLaporanScreen({super.key, required this.reportData});

  @override
  State<AdminEditLaporanScreen> createState() => _AdminEditLaporanScreenState();
}

class _AdminEditLaporanScreenState extends State<AdminEditLaporanScreen> {
  late TextEditingController _uraianController;
  late TextEditingController _stoController;
  late TextEditingController _kategoriController;
  late TextEditingController _mitraController;
  bool _isSaving = false;

  PlatformFile? _fileMaterialTiba;
  PlatformFile? _fileHasilUkur;
  PlatformFile? _filePendukung;

  @override
  void initState() {
    super.initState();
    _uraianController = TextEditingController(
      text: widget.reportData['uraian_pekerjaan']?.toString() ?? '',
    );
    _stoController = TextEditingController(
      text: widget.reportData['sto']?.toString() ?? '',
    );
    _kategoriController = TextEditingController(
      text: widget.reportData['kategori_kegiatan']?.toString() ?? '',
    );
    _mitraController = TextEditingController(
      text: widget.reportData['mitra_pelaksana']?.toString() ?? '',
    );
  }

  Future<void> _pickFile(int type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'rar', 'pdf'],
      withData: true,
    );
    if (result != null) {
      setState(() {
        if (type == 1)
          _fileMaterialTiba = result.files.first;
        else if (type == 2)
          _fileHasilUkur = result.files.first;
        else if (type == 3)
          _filePendukung = result.files.first;
      });
    }
  }

  Future<void> _saveEditData() async {
    setState(() => _isSaving = true);
    try {
      final reportId = widget.reportData['id'];
      final url = Uri.parse(
        'http://192.168.1.9:8000/api/maintenance/reports/$reportId',
      );

      var request = http.MultipartRequest('POST', url);
      request.fields['_method'] = 'PUT';
      request.fields['sto'] = _stoController.text;
      request.fields['kategori_kegiatan'] = _kategoriController.text;
      request.fields['mitra_pelaksana'] = _mitraController.text;
      request.fields['uraian_pekerjaan'] = _uraianController.text;

      if (_fileMaterialTiba != null) {
        if (_fileMaterialTiba!.bytes != null)
          request.files.add(
            http.MultipartFile.fromBytes(
              'evidence_material',
              _fileMaterialTiba!.bytes!,
              filename: _fileMaterialTiba!.name,
            ),
          );
        else
          request.files.add(
            await http.MultipartFile.fromPath(
              'evidence_material',
              _fileMaterialTiba!.path!,
            ),
          );
      }
      if (_fileHasilUkur != null) {
        if (_fileHasilUkur!.bytes != null)
          request.files.add(
            http.MultipartFile.fromBytes(
              'evidence_ukur',
              _fileHasilUkur!.bytes!,
              filename: _fileHasilUkur!.name,
            ),
          );
        else
          request.files.add(
            await http.MultipartFile.fromPath(
              'evidence_ukur',
              _fileHasilUkur!.path!,
            ),
          );
      }
      if (_filePendukung != null) {
        if (_filePendukung!.bytes != null)
          request.files.add(
            http.MultipartFile.fromBytes(
              'evidence_pendukung',
              _filePendukung!.bytes!,
              filename: _filePendukung!.name,
            ),
          );
        else
          request.files.add(
            await http.MultipartFile.fromPath(
              'evidence_pendukung',
              _filePendukung!.path!,
            ),
          );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      setState(() => _isSaving = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data & Bukti berhasil diperbarui!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Gagal menyimpan data ke server. Pastikan batas di php.ini sudah diubah!",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A101D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Edit Laporan & Upload Bukti',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel("STO"),
            _buildTextField(_stoController),
            const SizedBox(height: 20),
            _buildFieldLabel("Kategori Kegiatan"),
            _buildTextField(_kategoriController),
            const SizedBox(height: 20),
            _buildFieldLabel("Mitra Pelaksana"),
            _buildTextField(_mitraController),
            const SizedBox(height: 20),
            _buildFieldLabel("Uraian Pekerjaan"),
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161F2E),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white10),
              ),
              child: TextField(
                controller: _uraianController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(15),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Divider(color: Colors.white10),
            const SizedBox(height: 15),
            const Text(
              "Upload Evidence (.zip/.rar)",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),

            _buildFilePicker(
              "Evidence Material Tiba",
              _fileMaterialTiba,
              () => _pickFile(1),
            ),
            _buildFilePicker(
              "Evidence Hasil Ukur",
              _fileHasilUkur,
              () => _pickFile(2),
            ),
            _buildFilePicker(
              "Evidence Pendukung/BA",
              _filePendukung,
              () => _pickFile(3),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveEditData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D1F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Simpan Semua Perubahan",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: Colors.grey,
      fontSize: 13,
      fontWeight: FontWeight.bold,
    ),
  );

  Widget _buildTextField(TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildFilePicker(
    String label,
    PlatformFile? file,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_zip,
                  color: file != null ? Colors.green : const Color(0xFF00D1F3),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    file != null ? file.name : "Pilih File...",
                    style: TextStyle(
                      color: file != null ? Colors.white : Colors.grey,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (file != null)
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
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

// ======================================================================
// --- HALAMAN JADWAL & DAFTAR TIM ---
// --- DI TAMPILKAN BERTUMPUK (LIST VERTIKAL) SESUAI GAMBAR ---
// ======================================================================

class JadwalScreen extends StatefulWidget {
  const JadwalScreen({super.key});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  bool _isLoading = true;
  Map<String, List<dynamic>> _groupedTlaUsers = {};

  // Kamus Nama Lengkap STO
  final Map<String, String> _stoFullNames = {
    'KJR': 'KENJERAN',
    'KPS': 'KAPASAN',
    'KBL': 'KEBALEN',
    'KLK': 'KALIANAK',
    'MGS': 'MERGOYOSO',
    'TND': 'TANDES',
    'KDG': 'KANDANGAN',
    'KRP': 'KARANGPILANG',
    'LKS': 'LAKASANTRI',
    'GRK': 'GRESIK',
    'CRM': 'CERME',
    'LMG': 'LAMONGAN',
    'BPG': 'BALOPANGGANG',
    'BRD': 'BERONDONG',
    'DSK': 'DUDUKSAMPEYAN',
    'BWN': 'BAWEAN',
    'BBT': 'BABAT',
    'SKD': 'SUKODADI',
    'KDM': 'KEDAMEAN',
  };

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final url = Uri.parse('http://192.168.1.9:8000/api/users');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> users = data['data'] ?? [];

        Map<String, List<dynamic>> tempGroup = {};

        for (var user in users) {
          // FILTER: HANYA TAMPILKAN TIM LAPANGAN (TLA)
          String role = user['role']?.toString() ?? '';
          if (role != 'Tim Lapangan') {
            continue;
          }

          String userId = user['user_id']?.toString().toUpperCase() ?? '';

          // FORMAT BARU: TLA-KJR-834
          List<String> parts = userId.split('-');

          String prefix = '';

          if (parts.length >= 3 && parts[0] == 'TLA') {
            prefix = parts[1];
          } else if (parts.length == 2) {
            prefix = parts[0];
          } else {
            continue;
          }

          if (!tempGroup.containsKey(prefix)) {
            tempGroup[prefix] = [];
          }

          tempGroup[prefix]!.add(user);
        }

        if (mounted) {
          setState(() {
            _groupedTlaUsers = tempGroup;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
        _showError("Gagal mengambil data: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError("Koneksi Error: $e");
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mengambil daftar STO dan mengurutkannya sesuai abjad
    List<String> groupKeys = _groupedTlaUsers.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFF0A101D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Manajemen Tim Lapangan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D1F3)),
            )
          : _groupedTlaUsers.isEmpty
          ? const Center(
              child: Text(
                "Belum ada data tim lapangan",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: groupKeys.length,
              itemBuilder: (context, index) {
                String prefix = groupKeys[index];
                String fullStoName =
                    _stoFullNames[prefix] ??
                    prefix; // Mengubah singkatan jadi Nama Lengkap
                List<dynamic> usersInGroup = _groupedTlaUsers[prefix]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- HEADER STO (NAMA LENGKAP) ---
                    Text(
                      "STO $fullStoName",
                      style: const TextStyle(
                        color: Color(0xFF00D1F3),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- TABEL DATA TEKNISI ---
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(
                            const Color(0xFF334155),
                          ),
                          dataRowMinHeight: 50,
                          dataRowMaxHeight: 50,
                          columns: const [
                            DataColumn(
                              label: Text(
                                'No',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'STO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'ID Tim Lapangan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Nama',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          rows: List.generate(usersInGroup.length, (rowIndex) {
                            final user = usersInGroup[rowIndex];
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    '${rowIndex + 1}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    fullStoName,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ), // Kolom STO menggunakan Nama Lengkap
                                DataCell(
                                  Text(
                                    user['user_id'] ?? '-',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    user['name'] ?? '-',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),
                  ],
                );
              },
            ),
    );
  }
}
