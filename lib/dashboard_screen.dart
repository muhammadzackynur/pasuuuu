import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:io';

import 'input_laporan_screen.dart';
import 'profile_screen.dart';
import 'notification_screen.dart';
import 'api_config.dart';
import 'filter_laporan_screen.dart';

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
  int _closedCount = 0;

  int _unreadNotifCount = 0;
  final String serverUrl = ApiConfig.baseUrl;

  Map<String, dynamic>? activeFilter;
  String _selectedStatusFilter = 'Semua';
  bool _showOnlyMyReports = false;

  @override
  void initState() {
    super.initState();
    _fetchReports();
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final response = await http.get(
        Uri.parse('$serverUrl/notifications?user_id=${widget.userId}'),
      );
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

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      String urlStr = '$serverUrl/maintenance/reports';

      if (activeFilter != null) {
        List<String> queryParams = [];

        if (activeFilter!['role'] != null) {
          queryParams.add('role=${activeFilter!['role']}');
        }
        if (activeFilter!['bulan'] != null) {
          queryParams.add('bulan=${activeFilter!['bulan']}');
        }
        if (activeFilter!['gangguan'] != null) {
          List<dynamic> gangguanList = activeFilter!['gangguan'];
          for (String g in gangguanList) {
            queryParams.add('gangguan[]=${Uri.encodeComponent(g)}');
          }
        }
        if (queryParams.isNotEmpty) {
          urlStr += '?${queryParams.join('&')}';
        }
      }

      final url = Uri.parse(urlStr);
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> fetchedReports = data['data'];

        int p = 0, v = 0, r = 0, c = 0;
        for (var report in fetchedReports) {
          String status = report['status'] ?? 'Pending';
          String statusLower = status.toLowerCase();

          if (statusLower == 'close') {
            bool isReporter = report['user_id'].toString() == widget.userId;
            bool isAssigned = false;

            if (report['assigned_technicians'] != null) {
              var assigned = report['assigned_technicians'];
              if (assigned is List) {
                isAssigned = assigned.any(
                  (id) => id.toString() == widget.userId,
                );
              } else if (assigned is String) {
                isAssigned = assigned.contains(widget.userId);
              }
            }

            if (isReporter || isAssigned) {
              c++;
            }
          } else if (statusLower.contains('verif') ||
              statusLower == 'selesai') {
            v++;
          } else if (statusLower.contains('reject')) {
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
          _closedCount = c;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
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
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color iconAndTextColor = isLightMode ? Colors.black : Colors.white;

    Widget bodyContent;
    switch (_selectedIndex) {
      case 0:
        bodyContent = _buildHomeContent(isLightMode);
        break;
      case 2:
        bodyContent = _buildStatusContent(isLightMode);
        break;
      case 3:
        bodyContent = _buildHistoryContent(isLightMode);
        break;
      case 4:
        bodyContent = ProfileScreen(
          userName: widget.userName,
          role: widget.role,
          userId: widget.userId,
          databaseId: widget.databaseId,
        );
        break;
      default:
        bodyContent = _buildHomeContent(isLightMode);
    }

    String appBarTitle = 'Tim Lapangan';
    if (_selectedIndex == 2) appBarTitle = 'Status Laporan';
    if (_selectedIndex == 3) appBarTitle = 'History Pekerjaan';

    return Scaffold(
      backgroundColor: isLightMode
          ? const Color(0xFFF8FAFC)
          : const Color(0xFF0F1623),
      appBar: _selectedIndex == 4
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              // ===== HAMBURGER DIHAPUS =====
              leading: const SizedBox.shrink(),
              title: Text(
                appBarTitle,
                style: TextStyle(
                  color: iconAndTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      activeFilter = null;
                    });
                    _fetchReports();
                    _fetchUnreadCount();
                  },
                  icon: Icon(Icons.refresh, color: iconAndTextColor),
                ),
                if (_selectedIndex != 2 && _selectedIndex != 3)
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              NotificationScreen(userId: widget.userId),
                        ),
                      );
                      _fetchUnreadCount();
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.notifications, color: iconAndTextColor),
                        if (_unreadNotifCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
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
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_selectedIndex == 4
                ? bodyContent
                : RefreshIndicator(
                    onRefresh: () async {
                      await _fetchReports();
                      await _fetchUnreadCount();
                    },
                    child: bodyContent,
                  )),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: isLightMode ? Colors.white : const Color(0xFF0F1623),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00D1F3),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedLabelStyle: const TextStyle(fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              backgroundColor: isLightMode
                  ? const Color(0xFFF1F5F9)
                  : const Color(0xFF1E293B),
              child: const Icon(Icons.add, color: Color(0xFF00D1F3)),
            ),
            label: 'Tambah',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Status',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.history),
                if (_closedCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_closedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'History',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryContent(bool isLightMode) {
    final closedReports = _reports.where((d) {
      bool isClose = (d['status'] ?? '').toString().toLowerCase() == 'close';

      bool isReporter = d['user_id'].toString() == widget.userId;
      bool isAssigned = false;

      if (d['assigned_technicians'] != null) {
        var assigned = d['assigned_technicians'];
        if (assigned is List) {
          isAssigned = assigned.any((id) => id.toString() == widget.userId);
        } else if (assigned is String) {
          isAssigned = assigned.contains(widget.userId);
        }
      }

      return isClose && (isReporter || isAssigned);
    }).toList();

    Color textColor = isLightMode ? Colors.black : Colors.white;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, color: Color(0xFF00D1F3), size: 20),
              const SizedBox(width: 8),
              Text(
                'Daftar Riwayat Pekerjaan',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (closedReports.isEmpty)
            _buildHistoryEmptyState(isLightMode)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: closedReports.length,
              itemBuilder: (context, index) {
                final data = closedReports[index];
                return _buildHistoryCard(data, isLightMode, index);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmptyState(bool isLightMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 72,
              color: isLightMode ? Colors.grey[300] : Colors.grey[700],
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Pekerjaan Selesai',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isLightMode ? Colors.grey[500] : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pekerjaan yang telah di-CLOSE\noleh Admin akan muncul di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isLightMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    Map<String, dynamic> data,
    bool isLightMode,
    int index,
  ) {
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF161F2E);
    Color textColor = isLightMode ? Colors.black : Colors.white;
    Color subtleText = isLightMode ? Colors.grey[600]! : Colors.grey[400]!;

    String idData = "MAINT-${data['id'].toString().padLeft(3, '0')}";
    String sto = data['sto'] ?? '-';
    String kategori = data['kategori_kegiatan'] ?? '-';
    String uraian = data['uraian_pekerjaan'] ?? '-';
    String mitra = data['mitra_pelaksana'] ?? '-';
    String teknisi = data['teknisi'] ?? '-';
    String tanggal = '';
    if (data['updated_at'] != null) {
      tanggal = data['updated_at'].toString().substring(0, 10);
    } else if (data['created_at'] != null) {
      tanggal = data['created_at'].toString().substring(0, 10);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.blueAccent.withOpacity(0.25),
          width: 1.2,
        ),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
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
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        idData,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.done_all,
                            size: 13,
                            color: Colors.blueAccent,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'CLOSE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Divider(
                  color: isLightMode ? Colors.grey[200] : Colors.white10,
                  height: 1,
                ),
                const SizedBox(height: 14),

                _buildHistoryInfoRow(
                  Icons.location_city,
                  Colors.blue,
                  'STO',
                  sto,
                  textColor,
                  subtleText,
                ),
                const SizedBox(height: 10),
                _buildHistoryInfoRow(
                  Icons.category,
                  Colors.amber,
                  'Kategori',
                  kategori,
                  textColor,
                  subtleText,
                ),
                const SizedBox(height: 10),
                _buildHistoryInfoRow(
                  Icons.description_outlined,
                  Colors.teal,
                  'Uraian',
                  uraian,
                  textColor,
                  subtleText,
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                _buildHistoryInfoRow(
                  Icons.business,
                  Colors.purple,
                  'Mitra',
                  mitra,
                  textColor,
                  subtleText,
                ),
                const SizedBox(height: 10),
                _buildHistoryInfoRow(
                  Icons.engineering,
                  Colors.orange,
                  'Teknisi',
                  teknisi,
                  textColor,
                  subtleText,
                ),

                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 14,
                          color: Colors.blueAccent.withOpacity(0.8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tanggal.isNotEmpty
                              ? 'Selesai: $tanggal'
                              : 'Tanggal tidak tersedia',
                          style: TextStyle(fontSize: 12, color: subtleText),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D1F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Detail',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00D1F3),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 10,
                            color: Color(0xFF00D1F3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryInfoRow(
    IconData icon,
    Color iconColor,
    String label,
    String value,
    Color textColor,
    Color subtleText, {
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: maxLines > 1
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(label, style: TextStyle(fontSize: 12, color: subtleText)),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeContent(bool isLightMode) {
    final recentReports = _reports.take(4).toList();
    Color textColor = isLightMode ? Colors.black : Colors.white;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreetingCard(isLightMode),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Laporan Terbaru',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 2),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(color: Color(0xFF00D1F3), fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentReports.isEmpty)
            Center(
              child: Text(
                "Belum ada laporan.",
                style: TextStyle(color: Colors.grey, fontSize: 19),
              ),
            )
          else
            ...recentReports
                .map(
                  (data) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildReportItem(data, isLightMode),
                  ),
                )
                .toList(),
          const SizedBox(height: 12),
          if (_closedCount > 0) _buildHistoryShortcut(isLightMode),
          const SizedBox(height: 12),
          _buildTipCard(isLightMode),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHistoryShortcut(bool isLightMode) {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 3),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLightMode
              ? Colors.blue.withOpacity(0.07)
              : const Color(0xFF1A2744),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                color: Colors.blueAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'History Pekerjaan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isLightMode ? Colors.black : Colors.white,
                    ),
                  ),
                  Text(
                    '$_closedCount pekerjaan telah selesai & di-CLOSE',
                    style: TextStyle(
                      fontSize: 12,
                      color: isLightMode ? Colors.grey[600] : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.blueAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent(bool isLightMode) {
    int totalReports = _reports.length;
    int flexP = _pendingCount > 0 ? _pendingCount : 1;
    int flexV = _verifiedCount > 0 ? _verifiedCount : 1;
    int flexR = _rejectedCount > 0 ? _rejectedCount : 1;
    int flexC = _closedCount > 0 ? _closedCount : 1;

    if (totalReports == 0) {
      flexP = 1;
      flexV = 1;
      flexR = 1;
      flexC = 1;
    }

    List<dynamic> displayedReports = _reports.where((data) {
      bool matchStatus = true;
      String statusStr = data['status'] ?? 'Pending';
      String statusLower = statusStr.toLowerCase();

      bool isClose = statusLower == 'close';
      bool isVerified =
          statusLower.contains('verif') || statusLower == 'selesai';
      bool isRejected = statusLower.contains('reject');
      bool isPending = !isVerified && !isRejected && !isClose;

      if (_selectedStatusFilter == 'Pending') {
        matchStatus = isPending;
      } else if (_selectedStatusFilter == 'Verified') {
        matchStatus = isVerified;
      } else if (_selectedStatusFilter == 'Rejected') {
        matchStatus = isRejected;
      } else if (_selectedStatusFilter == 'Semua') {
        matchStatus = !isClose;
      }

      bool matchOwner = true;
      if (_showOnlyMyReports) {
        matchOwner = data['user_id']?.toString() == widget.userId;
      }

      return matchStatus && matchOwner;
    }).toList();

    Color cardColor = isLightMode ? Colors.white : const Color(0xFF161F2E);
    Color textColor = isLightMode ? Colors.black : Colors.white;

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
                FilterChipWidget(
                  label: "Semua",
                  isActive: _selectedStatusFilter == 'Semua',
                  onTap: () => setState(() => _selectedStatusFilter = 'Semua'),
                  isLightMode: isLightMode,
                ),
                const SizedBox(width: 10),
                FilterChipWidget(
                  label: "Pending",
                  count: _pendingCount,
                  isActive: _selectedStatusFilter == 'Pending',
                  onTap: () =>
                      setState(() => _selectedStatusFilter = 'Pending'),
                  isLightMode: isLightMode,
                ),
                const SizedBox(width: 10),
                FilterChipWidget(
                  label: "Verified",
                  count: _verifiedCount,
                  isActive: _selectedStatusFilter == 'Verified',
                  onTap: () =>
                      setState(() => _selectedStatusFilter = 'Verified'),
                  isLightMode: isLightMode,
                ),
                const SizedBox(width: 10),
                FilterChipWidget(
                  label: "Rejected",
                  count: _rejectedCount,
                  isActive: _selectedStatusFilter == 'Rejected',
                  onTap: () =>
                      setState(() => _selectedStatusFilter = 'Rejected'),
                  isLightMode: isLightMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isLightMode
                      ? Colors.grey.withOpacity(0.2)
                      : Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Laporan",
                  style: TextStyle(
                    color: isLightMode ? Colors.grey[700] : Colors.grey,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "$totalReports ",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const TextSpan(
                        text: "Total",
                        style: TextStyle(
                          fontSize: 19,
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
                          Expanded(
                            flex: flexC,
                            child: Container(color: Colors.blueAccent),
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
                    Expanded(
                      child: StatItem(
                        icon: Icons.more_horiz,
                        count: _pendingCount.toString(),
                        label: "PEND",
                        color: Colors.amber,
                        isLightMode: isLightMode,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatItem(
                        icon: Icons.check_circle_outline,
                        count: _verifiedCount.toString(),
                        label: "VERIF",
                        color: Colors.green,
                        isLightMode: isLightMode,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatItem(
                        icon: Icons.cancel_outlined,
                        count: _rejectedCount.toString(),
                        label: "REJECT",
                        color: Colors.red,
                        isLightMode: isLightMode,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatItem(
                        icon: Icons.done_all,
                        count: _closedCount.toString(),
                        label: "CLOSE",
                        color: Colors.blueAccent,
                        isLightMode: isLightMode,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Daftar Pekerjaan",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isLightMode ? Colors.grey[800] : Colors.grey,
                ),
              ),
              Row(
                children: [
                  Text(
                    "Laporan Saya",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 5),
                  SizedBox(
                    height: 30,
                    child: Switch(
                      value: _showOnlyMyReports,
                      onChanged: (value) {
                        setState(() {
                          _showOnlyMyReports = value;
                        });
                      },
                      activeColor: const Color(0xFF00D1F3),
                      inactiveTrackColor: Colors.grey.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (displayedReports.isEmpty)
            Center(
              child: Text(
                "Tidak ada aktivitas",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedReports.length,
              itemBuilder: (context, index) {
                final data = displayedReports[index];
                String statusStr = data['status'] ?? 'Pending';
                String statusLower = statusStr.toLowerCase();
                StatusType type = StatusType.pending;
                Color sColor = Colors.amber;

                if (statusLower == 'close') {
                  type = StatusType.closed;
                  sColor = Colors.blueAccent;
                } else if (statusLower.contains('verif') ||
                    statusLower == 'selesai') {
                  type = StatusType.verified;
                  sColor = statusLower == 'selesai'
                      ? Colors.redAccent
                      : Colors.green;
                } else if (statusLower.contains('reject')) {
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
                  isLast: index == displayedReports.length - 1,
                  isLightMode: isLightMode,
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

  Widget _buildGreetingCard(bool isLightMode) {
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF1E293B);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : [],
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
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Selamat bekerja hari ini!',
            style: TextStyle(
              color: isLightMode ? Colors.grey[700] : Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(dynamic data, bool isLightMode) {
    String id = "MAINT-${data['id'].toString().padLeft(3, '0')}";
    String location = data['sto'] ?? 'STO -';
    String status = data['status'] ?? 'TERKIRIM';
    String statusLower = status.toLowerCase();

    Color statusColor = statusLower == 'close'
        ? Colors.blueAccent
        : (statusLower == 'selesai'
              ? Colors.redAccent
              : (statusLower.contains('pend')
                    ? Colors.amber
                    : (statusLower.contains('reject')
                          ? Colors.red
                          : Colors.green)));

    Color cardColor = isLightMode ? Colors.white : const Color(0xFF1E293B);
    Color textColor = isLightMode ? Colors.black : Colors.white;

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
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLightMode
              ? [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
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
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    location,
                    style: TextStyle(
                      color: isLightMode ? Colors.grey[700] : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(bool isLightMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLightMode
            ? Colors.amber.withOpacity(0.15)
            : Colors.yellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.yellow.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tip: Pastikan GPS aktif saat input laporan.',
              style: TextStyle(
                color: isLightMode ? Colors.black87 : Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// ===== WIDGET PENDUKUNG ===============================================
// ======================================================================

class FilterChipWidget extends StatelessWidget {
  final String label;
  final int? count;
  final bool isActive;
  final VoidCallback? onTap;
  final bool isLightMode;

  const FilterChipWidget({
    super.key,
    required this.label,
    this.count,
    required this.isActive,
    this.onTap,
    required this.isLightMode,
  });

  @override
  Widget build(BuildContext context) {
    Color inactiveColor = isLightMode
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF1E2738);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00D1F3) : inactiveColor,
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
                fontSize: 14,
                color: isActive
                    ? (isLightMode ? Colors.white : Colors.black)
                    : textColor,
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
                    color: isActive
                        ? (isLightMode ? Colors.white : Colors.black)
                        : Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final IconData icon;
  final String count;
  final String label;
  final Color color;
  final bool isLightMode;

  const StatItem({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
    required this.isLightMode,
  });

  @override
  Widget build(BuildContext context) {
    Color itemColor = isLightMode
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F1623);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: itemColor,
        borderRadius: BorderRadius.circular(12),
        border: isLightMode
            ? Border.all(color: Colors.grey.withOpacity(0.2))
            : null,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isLightMode ? Colors.grey[700] : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum StatusType { pending, verified, rejected, closed }

class TimelineItem extends StatelessWidget {
  final String id, sto, kategori, uraian, statusLabel;
  final Color statusColor;
  final StatusType type;
  final bool isFirst, isLast, isLightMode;
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
    required this.isLightMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF161F2E);
    Color textColor = isLightMode ? Colors.black : Colors.white;

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
                          : (type == StatusType.closed
                                ? Colors.blueAccent
                                : const Color(0xFF00D1F3)),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: isLightMode
                        ? Colors.white
                        : Colors.transparent,
                    child: Icon(
                      type == StatusType.pending
                          ? Icons.circle
                          : type == StatusType.verified
                          ? Icons.check
                          : type == StatusType.closed
                          ? Icons.done_all
                          : Icons.close,
                      size: 12,
                      color: type == StatusType.pending
                          ? Colors.amber
                          : type == StatusType.verified
                          ? Colors.green
                          : type == StatusType.closed
                          ? Colors.blueAccent
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
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isLightMode
                    ? [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
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
                            Expanded(
                              child: Text(
                                id,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
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
                                      fontSize: 11,
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
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 14,
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
                                style: TextStyle(
                                  color: isLightMode
                                      ? Colors.grey[700]
                                      : Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Divider(
                          color: isLightMode
                              ? Colors.grey[300]
                              : Colors.white10,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.description,
                              size: 16,
                              color: isLightMode
                                  ? Colors.grey[600]
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                uraian,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isLightMode
                                      ? Colors.grey[600]
                                      : Colors.grey,
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
// ===== HALAMAN DETAIL LAPORAN =========================================
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

  String get storageBaseUrl =>
      ApiConfig.baseUrl.replaceAll('/api', '/storage/');

  List<String> _getImagesByType(String type) {
    if (widget.reportData['images'] == null) return [];
    List<dynamic> allImages = widget.reportData['images'];
    return allImages
        .where((img) => img['type'] == type)
        .map<String>((img) => img['image_path'].toString())
        .toList();
  }

  Future<void> _uploadPhotosForCategory(String kategori) async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        imageQuality: 70,
      );
      if (pickedFiles.isEmpty) return;

      setState(() => _isUploading = true);

      String id = widget.reportData['id'].toString();
      var url = Uri.parse(
        "${ApiConfig.baseUrl}/maintenance/report/$id/add-photos",
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

  Future<void> _markAsDone() async {
    final fotoBefore = _getImagesByType('before');
    final fotoProgress = _getImagesByType('progress');
    final fotoAfter = _getImagesByType('after');
    bool isLightMode = Theme.of(context).brightness == Brightness.light;

    if (fotoBefore.isEmpty || fotoProgress.isEmpty || fotoAfter.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isLightMode ? Colors.white : const Color(0xFF1E293B),
          title: Text(
            "Peringatan",
            style: TextStyle(
              color: isLightMode ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Text(
            "Data belum lengkap!\n\nAnda harus mengunggah setidaknya 1 foto untuk masing-masing kategori: Before, Progress, dan After sebelum menekan selesai.",
            style: TextStyle(
              color: isLightMode ? Colors.grey[800] : Colors.grey,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Mengerti",
                style: TextStyle(color: Colors.blue, fontSize: 16),
              ),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/maintenance/reports/${widget.reportData['id']}/status',
      );
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'status': 'Selesai'}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Laporan Pekerjaan Berhasil Diselesaikan!"),
            backgroundColor: Colors.green,
          ),
        );
        if (widget.onRefresh != null) widget.onRefresh!();
        Navigator.pop(context);
      } else {
        throw Exception("Gagal menyelesaikan pekerjaan.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color textColor = isLightMode ? Colors.black : Colors.white;
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF161F2E);

    String idData =
        "MAINT-${widget.reportData['id'].toString().padLeft(3, '0')}";
    String status = widget.reportData['status']?.toString() ?? 'Pending';
    String statusLower = status.toLowerCase();

    Color statusColor = statusLower == 'close'
        ? Colors.blueAccent
        : (statusLower == 'selesai'
              ? Colors.redAccent
              : (statusLower.contains('pend')
                    ? Colors.amber
                    : (statusLower.contains('reject')
                          ? Colors.red
                          : Colors.green)));

    String? latStr = widget.reportData['latitude']?.toString();
    String? lngStr = widget.reportData['longitude']?.toString();

    final fotoBefore = _getImagesByType('before');
    final fotoProgress = _getImagesByType('progress');
    final fotoAfter = _getImagesByType('after');

    bool isVerifiedAndNotDone =
        status.toLowerCase().contains('verif') &&
        status.toLowerCase() != 'selesai';

    return Scaffold(
      backgroundColor: isLightMode
          ? const Color(0xFFF8FAFC)
          : const Color(0xFF0F1623),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Detail Laporan',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (statusLower == 'close')
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueAccent.shade700, Colors.blue.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.done_all, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pekerjaan ini telah selesai dan ditutup oleh Admin.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: isLightMode
                    ? [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ID Laporan",
                        style: TextStyle(
                          color: isLightMode ? Colors.grey[600] : Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        idData,
                        style: TextStyle(
                          color: textColor,
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
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              "Informasi Lokasi & Link Maps",
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
                boxShadow: isLightMode
                    ? [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    "Area",
                    widget.reportData['area']?.toString() ?? '-',
                    isLightMode,
                  ),
                  _buildDetailRow(
                    "District",
                    widget.reportData['district']?.toString() ?? '-',
                    isLightMode,
                  ),
                  _buildDetailRow(
                    "Witel",
                    widget.reportData['witel']?.toString() ?? '-',
                    isLightMode,
                  ),
                  _buildDetailRow(
                    "STO",
                    widget.reportData['sto']?.toString() ?? '-',
                    isLightMode,
                  ),
                  Divider(
                    color: isLightMode ? Colors.grey[300] : Colors.white10,
                    height: 30,
                  ),
                  _buildDetailRow("Latitude", latStr ?? '-', isLightMode),
                  _buildDetailRow("Longitude", lngStr ?? '-', isLightMode),
                  const SizedBox(height: 5),
                  Text(
                    "Link Google Maps:",
                    style: TextStyle(
                      color: isLightMode ? Colors.grey[600] : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    (latStr != null && lngStr != null && latStr.isNotEmpty)
                        ? "https://www.google.com/maps/search/?api=1&query=$latStr,$lngStr"
                        : "Koordinat belum tersedia",
                    style: TextStyle(
                      color: isLightMode
                          ? Colors.blue[700]
                          : Colors.greenAccent,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
                        size: 20,
                      ),
                      label: const Text(
                        "Buka di Google Maps",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
            Text(
              "Rincian Pekerjaan",
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailCard([
              _buildDetailRow(
                "Kategori Kegiatan",
                widget.reportData['kategori_kegiatan']?.toString() ?? '-',
                isLightMode,
              ),
              _buildDetailRow(
                "Uraian Pekerjaan",
                widget.reportData['uraian_pekerjaan']?.toString() ?? '-',
                isLightMode,
              ),
              _buildDetailRow(
                "Mitra Pelaksana",
                widget.reportData['mitra_pelaksana']?.toString() ?? '-',
                isLightMode,
              ),
              _buildDetailRow(
                "Teknisi",
                widget.reportData['teknisi']?.toString() ?? '-',
                isLightMode,
              ),
              _buildDetailRow(
                "Waktu Laporan",
                widget.reportData['created_at']?.toString().substring(0, 10) ??
                    '-',
                isLightMode,
              ),
            ], isLightMode),

            const SizedBox(height: 24),
            Text(
              "Bukti Foto Lapangan",
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildPhotoCategory("Before", fotoBefore, isLightMode),
            const SizedBox(height: 15),
            _buildPhotoCategory("Progress", fotoProgress, isLightMode),
            const SizedBox(height: 15),
            _buildPhotoCategory("After", fotoAfter, isLightMode),

            const SizedBox(height: 40),

            if (isVerifiedAndNotDone)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _markAsDone,
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Pekerjaan Selesai",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(List<Widget> children, bool isLightMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLightMode ? Colors.white : const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow(String title, String value, bool isLightMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              title,
              style: TextStyle(
                color: isLightMode ? Colors.grey[700] : Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: isLightMode ? Colors.black : Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCategory(
    String label,
    List<String> paths,
    bool isLightMode,
  ) {
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
            fontSize: 16,
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
                    height: 100,
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
                              const Icon(
                                Icons.add_a_photo,
                                color: Colors.blue,
                                size: 24,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Tambah Foto $label",
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
                    color: isLightMode
                        ? Colors.grey[200]
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLightMode ? Colors.grey[300]! : Colors.white10,
                    ),
                  ),
                  child: Icon(
                    Icons.image_not_supported,
                    color: isLightMode ? Colors.grey[400] : Colors.grey,
                    size: 30,
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
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "Tambah",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              }

              String fullUrl = storageBaseUrl + paths[index];
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
                    border: Border.all(
                      color: isLightMode ? Colors.grey[300]! : Colors.white24,
                    ),
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
// ===== FULLSCREEN IMAGE ===============================================
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
