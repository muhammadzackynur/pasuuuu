import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'notification_screen.dart';
import 'api_config.dart';
import 'filter_laporan_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String userName;
  final String role;
  final String? userId;
  final int? databaseId;

  const AdminDashboardScreen({
    super.key,
    required this.userName,
    required this.role,
    this.userId,
    this.databaseId,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;

  File? _profileImage;
  String? _photoUrl;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;
  int? _adminDatabaseId;

  List<dynamic> _allReports = [];
  List<dynamic> _recentReports = [];

  int _unreadNotifCount = 0;
  Timer? _notificationTimer;

  Map<String, List<dynamic>> _stoTechnicians = {};

  final TextEditingController _deleteUserIdController = TextEditingController();
  bool _isDeletingUser = false;

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
  Map<String, dynamic>? activeFilter;

  @override
  void initState() {
    super.initState();
    _adminDatabaseId = widget.databaseId;
    _fetchAdminData();
    _fetchUnreadCount();
    _fetchTechnicianData();
    _fetchUserPhoto();
    _startNotificationCheck();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _deleteUserIdController.dispose();
    super.dispose();
  }

  Set<String> _getBusyTechnicians() {
    Set<String> busyIds = {};
    for (var report in _allReports) {
      String status = (report['status'] ?? '').toString().toLowerCase();

      if (status.contains('verif') || status == 'selesai') {
        String reportSto = (report['sto'] ?? '').toString().toUpperCase();
        if (_stoFullNames.containsKey(reportSto)) {
          reportSto = _stoFullNames[reportSto]!;
        }

        if (report['user_id'] != null) {
          busyIds.add(report['user_id'].toString());
        }

        List<dynamic> allTechsInSto = _stoTechnicians[reportSto] ?? [];
        int added = 1;
        for (var tech in allTechsInSto) {
          if (tech['user_id']?.toString() != report['user_id']?.toString() &&
              added < 5) {
            if (tech['user_id'] != null) {
              busyIds.add(tech['user_id'].toString());
            }
            added++;
          }
        }
      }
    }
    return busyIds;
  }

  Future<void> _fetchTechnicianData() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/users');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> users = data['data'] ?? [];
        Map<String, List<dynamic>> tempTechs = {};

        for (var user in users) {
          String role = user['role']?.toString() ?? '';
          if (role != 'Tim Lapangan') continue;

          String userId = user['user_id']?.toString().toUpperCase() ?? '';
          List<String> parts = userId.split('-');
          String prefix = '';

          if (parts.length >= 3 && parts[0] == 'TLA') {
            prefix = parts[1];
          } else if (parts.length == 2) {
            prefix = parts[0];
          } else {
            continue;
          }

          String fullStoName = _stoFullNames[prefix] ?? prefix;

          if (!tempTechs.containsKey(fullStoName)) {
            tempTechs[fullStoName] = [];
          }
          tempTechs[fullStoName]!.add(user);
        }

        if (mounted) {
          setState(() {
            _stoTechnicians = tempTechs;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetch technicians: $e");
    }
  }

  // ===========================================================================
  // FOTO PROFIL ADMIN
  // ===========================================================================
  Future<void> _fetchUserPhoto() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/users');
      final response = await http.get(url);
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final List<dynamic> users = data['data'] ?? [];

      for (var u in users) {
        final bool matchById =
            _adminDatabaseId != null && u['id'] == _adminDatabaseId;
        final bool matchByUserId = widget.userId != null &&
            u['user_id']?.toString().toUpperCase() ==
                widget.userId!.toUpperCase();

        if (matchById || matchByUserId) {
          if (!mounted) return;
          setState(() {
            _adminDatabaseId = u['id'];
            if (u['photo'] != null) {
              String photoPath = u['photo'].toString();
              if (photoPath.startsWith('http')) {
                _photoUrl = photoPath;
              } else {
                String host =
                    ApiConfig.baseUrl.replaceAll(RegExp(r'/api$'), '');
                _photoUrl = '$host/storage/$photoPath';
              }
            }
          });
          break;
        }
      }
    } catch (e) {
      debugPrint('Error fetch foto admin: $e');
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    if (_adminDatabaseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "ID pengguna belum terdeteksi, coba refresh halaman lalu ulangi.",
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _profileImage = File(pickedFile.path);
      _isUploadingPhoto = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      String? token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(
            "Token tidak ditemukan. Silakan logout dan login ulang.");
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/user/update-photo/$_adminDatabaseId'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.files.add(
        await http.MultipartFile.fromPath('photo', pickedFile.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (mounted) {
          setState(() => _photoUrl = data['photo_url'] ?? _photoUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Foto profil berhasil diperbarui!",
                style: TextStyle(fontSize: 17),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (response.statusCode == 401) {
        throw Exception("Sesi habis (401). Silakan logout dan login ulang.");
      } else {
        throw Exception(
          "Server error: ${response.statusCode} — ${response.body}",
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Gagal upload foto: $e",
              style: const TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/notifications'),
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

  void _startNotificationCheck() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      try {
        final url = Uri.parse('${ApiConfig.baseUrl}/maintenance/reports');
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          List<dynamic> fetchedReports = data['data'] ?? [];

          if (fetchedReports.length > _allReports.length) {
            if (_allReports.isNotEmpty) {
              _showNewReportNotification();
            }
            _refreshDataSilently(fetchedReports);
            _fetchUnreadCount();
          }
        }
      } catch (e) {
        debugPrint("Error Polling: $e");
      }
    });
  }

  void _refreshDataSilently(List<dynamic> newReports) {
    int p = 0, v = 0, r = 0;
    for (var report in newReports) {
      String status = (report['status'] ?? 'Pending').toString().toLowerCase();
      if (status.contains('verif') ||
          status == 'selesai' ||
          status == 'close') {
        v++;
      } else if (status.contains('reject')) {
        r++;
      } else {
        p++;
      }
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
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

  Future<void> _fetchAdminData() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/maintenance/reports');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> fetchedReports = data['data'] ?? [];

        int p = 0, v = 0, r = 0;
        for (var report in fetchedReports) {
          String status =
              (report['status'] ?? 'Pending').toString().toLowerCase();
          if (status.contains('verif') ||
              status == 'selesai' ||
              status == 'close') {
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
      debugPrint("Error koneksi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUserById(String id) async {
    if (id.isEmpty) return;

    setState(() {
      _isDeletingUser = true;
    });

    const String token = "GANTI_TOKEN_BEARER_ANDA_DISINI";

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.deleteUser}/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final responseData = json.decode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                responseData['message'] ?? 'Pengguna berhasil dihapus',
                style: const TextStyle(fontSize: 19)),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
        _deleteUserIdController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Gagal menghapus pengguna',
                style: const TextStyle(fontSize: 19)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan koneksi: $e',
              style: const TextStyle(fontSize: 19)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingUser = false;
        });
      }
    }
  }

  void _showDeleteDialog() {
    Map<String, dynamic>? previewUserObj;
    bool isFetchingPreview = false;
    Timer? debounceTimer;

    showDialog(
      context: context,
      builder: (ctx) {
        bool isLightMode = Theme.of(context).brightness == Brightness.light;
        Color dialogBgColor =
            isLightMode ? Colors.white : const Color(0xFF161F2E);
        Color textColor = isLightMode ? Colors.black : Colors.white;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> detectUserData(String inputId) async {
              if (inputId.isEmpty) {
                setStateDialog(() => previewUserObj = null);
                return;
              }

              setStateDialog(() {
                isFetchingPreview = true;
                previewUserObj = null;
              });

              try {
                final url = Uri.parse('${ApiConfig.baseUrl}/users');
                final response = await http.get(url);

                if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  final List<dynamic> usersList = data['data'] ?? [];

                  final target = usersList.firstWhere(
                    (u) =>
                        u['id']?.toString() == inputId ||
                        u['user_id']?.toString().toUpperCase() ==
                            inputId.toUpperCase(),
                    orElse: () => null,
                  );

                  if (target != null) {
                    String detectedRole =
                        target['role']?.toString() ?? 'Unknown';
                    int historyCount = 0;

                    if (detectedRole == 'Tim Lapangan') {
                      String searchUid =
                          (target['user_id'] ?? target['id']).toString();
                      List<dynamic> historyData =
                          await ApiConfig.getHistoryPekerjaan(searchUid);
                      historyCount = historyData.length;
                    }

                    if (!ctx.mounted) return;
                    setStateDialog(() {
                      previewUserObj = {
                        'success': true,
                        'id': target['id'],
                        'user_id': target['user_id'] ?? inputId,
                        'name': target['name'] ?? 'Tanpa Nama',
                        'role': detectedRole,
                        'history_count': historyCount,
                      };
                    });
                  } else {
                    if (!ctx.mounted) return;
                    setStateDialog(() {
                      previewUserObj = {
                        'success': false,
                        'message':
                            'Pengguna dengan ID "$inputId" tidak ditemukan'
                      };
                    });
                  }
                }
              } catch (e) {
                if (!ctx.mounted) return;
                setStateDialog(() {
                  previewUserObj = {
                    'success': false,
                    'message': 'Gagal terhubung ke server'
                  };
                });
              } finally {
                if (ctx.mounted) {
                  setStateDialog(() {
                    isFetchingPreview = false;
                  });
                }
              }
            }

            return AlertDialog(
              backgroundColor: dialogBgColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text('Hapus Pengguna',
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ketik ID Pengguna di bawah ini (Sistem akan melacak profilnya secara otomatis):',
                    style: TextStyle(
                        color: isLightMode ? Colors.grey[700] : Colors.white70,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _deleteUserIdController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: textColor, fontSize: 19),
                    onChanged: (val) {
                      if (debounceTimer?.isActive ?? false)
                        debounceTimer!.cancel();
                      debounceTimer =
                          Timer(const Duration(milliseconds: 500), () {
                        detectUserData(val.trim());
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'User ID / No. Urut',
                      hintText: 'Ketik angka ID...',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: isLightMode
                                ? Colors.grey[400]!
                                : Colors.white30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.blueAccent),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon:
                          const Icon(Icons.badge, color: Colors.blueAccent),
                      suffixIcon: isFetchingPreview
                          ? const Padding(
                              padding: EdgeInsets.all(14.0),
                              child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : const Icon(Icons.check_circle_outline,
                              color: Colors.transparent),
                    ),
                  ),
                  if (previewUserObj != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: previewUserObj!['success'] == true
                            ? (isLightMode
                                ? Colors.blue[50]
                                : Colors.blue.withOpacity(0.05))
                            : (isLightMode
                                ? Colors.red[50]
                                : Colors.red.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: previewUserObj!['success'] == true
                              ? Colors.blueAccent.withOpacity(0.3)
                              : Colors.redAccent.withOpacity(0.3),
                        ),
                      ),
                      child: previewUserObj!['success'] == true
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.blueAccent,
                                      child: Icon(Icons.person,
                                          color: Colors.white),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            previewUserObj!['name'],
                                            style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            previewUserObj!['role'],
                                            style: const TextStyle(
                                                color: Colors.blueAccent,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (previewUserObj!['role'] ==
                                    'Tim Lapangan') ...[
                                  const SizedBox(height: 12),
                                  Divider(
                                      color: Colors.blueAccent.withOpacity(0.2),
                                      height: 1),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.work_history,
                                          color: Colors.orange, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Riwayat Pekerjaan: ",
                                        style: TextStyle(
                                            color: isLightMode
                                                ? Colors.grey[700]
                                                : Colors.white70,
                                            fontSize: 14),
                                      ),
                                      Text(
                                        "${previewUserObj!['history_count']} Laporan dikerjakan",
                                        style: const TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                    ],
                                  ),
                                ]
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.redAccent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    previewUserObj!['message'],
                                    style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isDeletingUser
                      ? null
                      : () {
                          Navigator.of(ctx).pop();
                          _deleteUserIdController.clear();
                        },
                  child: const Text('Batal',
                      style: TextStyle(color: Colors.grey, fontSize: 19)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (_isDeletingUser ||
                          previewUserObj?['success'] != true)
                      ? null
                      : () =>
                          _deleteUserById(_deleteUserIdController.text.trim()),
                  child: _isDeletingUser
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Hapus Permanen',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 19)),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      debounceTimer?.cancel();
    });
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
        '${ApiConfig.baseUrl}/maintenance/reports/$reportId/status',
      );

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Laporan MAINT-${reportId.toString().padLeft(3, '0')} berhasil di-$newStatus!",
              style: const TextStyle(fontSize: 19),
            ),
            backgroundColor: newStatus == 'Verified' || newStatus == 'CLOSE'
                ? Colors.green
                : Colors.red,
          ),
        );
        _fetchAdminData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Gagal: ${response.statusCode} - ${response.body}",
              style: const TextStyle(fontSize: 19),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      debugPrint("KONEKSI ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Error koneksi ke server",
            style: TextStyle(fontSize: 19),
          ),
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
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color dialogBgColor = isLightMode ? Colors.white : const Color(0xFF161F2E);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "Konfirmasi Tindakan",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Text(
            newStatus == 'CLOSE'
                ? "Apakah Anda yakin data laporan MAINT-${reportId.toString().padLeft(3, '0')} sudah lengkap dan ingin Menutup Tiket (CLOSE)?"
                : "Apakah Anda yakin ingin mengubah status laporan MAINT-${reportId.toString().padLeft(3, '0')} menjadi $newStatus?",
            style: TextStyle(
              color: isLightMode ? Colors.grey[700] : Colors.white70,
              fontSize: 19,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Batal",
                style: TextStyle(color: Colors.grey, fontSize: 19),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: newStatus == 'Verified'
                    ? Colors.green
                    : (newStatus == 'CLOSE' ? Colors.blueAccent : Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _updateStatus(reportId, newStatus);
              },
              child: Text(
                newStatus == 'Verified'
                    ? "Ya, Verifikasi"
                    : (newStatus == 'CLOSE' ? "Ya, Tutup Tiket" : "Ya, Tolak"),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  String _getMonthNumber(String monthName) {
    switch (monthName) {
      case 'Jan':
        return '01';
      case 'Feb':
        return '02';
      case 'Mar':
        return '03';
      case 'Apr':
        return '04';
      case 'Mei':
        return '05';
      case 'Jun':
        return '06';
      case 'Jul':
        return '07';
      case 'Agu':
        return '08';
      case 'Sep':
        return '09';
      case 'Okt':
        return '10';
      case 'Nov':
        return '11';
      case 'Des':
        return '12';
      default:
        return '00';
    }
  }

  List<dynamic> get _filteredReports {
    List<dynamic> result = _allReports;

    if (activeFilter != null) {
      if (activeFilter!['bulan'] != null) {
        String selectedMonthStr = activeFilter!['bulan'];
        String targetMonthNumber = _getMonthNumber(selectedMonthStr);

        result = result.where((report) {
          String dateStr = report['created_at']?.toString() ?? '';
          if (dateStr.length >= 7) {
            String reportMonth = dateStr.substring(5, 7);
            return reportMonth == targetMonthNumber;
          }
          return false;
        }).toList();
      }

      if (activeFilter!['gangguan'] != null &&
          (activeFilter!['gangguan'] as List).isNotEmpty) {
        List<dynamic> selectedGangguan = activeFilter!['gangguan'];
        result = result.where((report) {
          String kategori = report['kategori_kegiatan']?.toString() ?? '';
          return selectedGangguan.contains(kategori);
        }).toList();
      }
    }

    if (_selectedFilterIndex != 0) {
      result = result.where((report) {
        String status =
            (report['status'] ?? 'pending').toString().toLowerCase();
        if (_selectedFilterIndex == 1) return status.contains('pending');
        if (_selectedFilterIndex == 2) {
          return status.contains('verif') ||
              status == 'selesai' ||
              status == 'close';
        }
        if (_selectedFilterIndex == 3) return status.contains('reject');
        return true;
      }).toList();
    }

    return result;
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
        bool isLightMode = Theme.of(context).brightness == Brightness.light;
        Color dialogBgColor =
            isLightMode ? Colors.white : const Color(0xFF161F2E);
        Color textColor = isLightMode ? Colors.black : Colors.white;
        Color borderColor =
            isLightMode ? Colors.grey[400]! : Colors.white.withOpacity(0.3);

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: dialogBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Daftarkan Pengguna",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: textColor, fontSize: 19),
                      decoration: InputDecoration(
                        labelText: "Nama Lengkap",
                        labelStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 19,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: idController,
                      style: TextStyle(color: textColor, fontSize: 19),
                      decoration: InputDecoration(
                        labelText: "User ID (Unik)",
                        labelStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 19,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      dropdownColor:
                          isLightMode ? Colors.white : const Color(0xFF1E293B),
                      style: TextStyle(color: textColor, fontSize: 19),
                      decoration: InputDecoration(
                        labelText: "Jabatan / Role",
                        labelStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 19,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
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
                    style: TextStyle(color: Colors.grey, fontSize: 19),
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
                                  style: TextStyle(fontSize: 19),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setStateDialog(() => isSubmitting = true);
                          try {
                            final url = Uri.parse(
                              '${ApiConfig.baseUrl}/users/register',
                            );
                            final response = await http.post(
                              url,
                              body: {
                                'name': nameController.text.trim(),
                                'user_id': idController.text.trim(),
                                'role': selectedRole,
                              },
                            );

                            if (!context.mounted) return;
                            setStateDialog(() => isSubmitting = false);

                            if (response.statusCode == 201 ||
                                response.statusCode == 200) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Pengguna berhasil didaftarkan!",
                                    style: TextStyle(fontSize: 19),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Gagal. Pastikan User ID belum dipakai!",
                                    style: TextStyle(fontSize: 19),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            setStateDialog(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Error: $e",
                                  style: const TextStyle(fontSize: 19),
                                ),
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
                            fontSize: 19,
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

  Widget _buildSidebar(bool isLightMode) {
    Color sidebarColor = isLightMode ? Colors.white : const Color(0xFF0F1623);
    Color selectedColor = const Color(0xFF00D1F3);
    Color unselectedColor = isLightMode ? Colors.grey : Colors.grey.shade600;

    return Container(
      width: 250,
      color: sidebarColor,
      child: Column(
        children: [
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.admin_panel_settings, color: selectedColor, size: 32),
              const SizedBox(width: 10),
              Text(
                "Admin Panel",
                style: TextStyle(
                  color: isLightMode ? Colors.black : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 50),
          _buildSidebarItem(
            Icons.home_filled,
            'Home',
            0,
            isLightMode,
            selectedColor,
            unselectedColor,
          ),
          _buildSidebarItem(
            Icons.dataset,
            'Data',
            1,
            isLightMode,
            selectedColor,
            unselectedColor,
          ),
          _buildSidebarItem(
            Icons.pie_chart,
            'Analytics',
            2,
            isLightMode,
            selectedColor,
            unselectedColor,
          ),
          _buildSidebarItem(
            Icons.person,
            'Profile',
            3,
            isLightMode,
            selectedColor,
            unselectedColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title,
    int index,
    bool isLightMode,
    Color selectedColor,
    Color unselectedColor,
  ) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        color: isSelected ? selectedColor.withOpacity(0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 30),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 24,
            ),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? selectedColor : unselectedColor,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color iconAndTextColor = isLightMode ? Colors.black : Colors.white;

    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 800;

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
          style: TextStyle(color: Colors.grey, fontSize: 19),
        ),
      );
    }

    Widget mainContent = _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF00D1F3)),
          )
        : RefreshIndicator(
            onRefresh: () async {
              await _fetchAdminData();
              await _fetchTechnicianData();
            },
            child: bodyContent,
          );

    PreferredSizeWidget myAppBar = AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20.0),
        child: CircleAvatar(
          backgroundColor:
              isLightMode ? Colors.grey[200] : const Color(0xFF1E293B),
          child: Icon(Icons.person, color: iconAndTextColor, size: 24),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Good Morning,',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Text(
            widget.userName,
            style: TextStyle(
              color: iconAndTextColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        if (_selectedIndex == 1)
          IconButton(
            onPressed: () async {
              final filterData = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FilterLaporanScreen(role: widget.role),
                ),
              );
              if (filterData != null) {
                setState(() {
                  activeFilter = filterData;
                });
              }
            },
            icon: Stack(
              children: [
                Icon(Icons.tune, color: iconAndTextColor),
                if (activeFilter != null &&
                    (activeFilter!['bulan'] != null ||
                        (activeFilter!['gangguan'] as List).isNotEmpty))
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        IconButton(
          onPressed: () {
            setState(() {
              activeFilter = null;
            });
            _fetchAdminData();
            _fetchUnreadCount();
          },
          icon: Icon(Icons.refresh, color: iconAndTextColor),
        ),
        IconButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationScreen(userId: 'admin'),
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
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.logout, color: Colors.redAccent),
        ),
        const SizedBox(width: 10),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        backgroundColor:
            isLightMode ? const Color(0xFFF8FAFC) : const Color(0xFF0A101D),
        body: Row(
          children: [
            _buildSidebar(isLightMode),
            Expanded(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: myAppBar,
                body: mainContent,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isLightMode ? const Color(0xFFF8FAFC) : const Color(0xFF0A101D),
      appBar: myAppBar,
      body: mainContent,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: isLightMode ? Colors.white : const Color(0xFF0F1623),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00D1F3),
        unselectedItemColor: isLightMode ? Colors.grey : Colors.grey.shade600,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
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

  Widget _buildHomeContent() {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color textColor = isLightMode ? Colors.black : Colors.white;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 800;

    Widget leftSideContent = Column(
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
                      fontSize: 20,
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
                      size: 24,
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
        Text(
          "Quick Actions",
          style: TextStyle(
            color: textColor,
            fontSize: 20,
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
      ],
    );

    Widget rightSideContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Recent Activity",
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => _onItemTapped(1),
              child: const Text(
                "See All",
                style: TextStyle(color: Color(0xFF00D1F3), fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_recentReports.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "No recent activity.",
                style: TextStyle(color: Colors.grey, fontSize: 19),
              ),
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
                        reportData:
                            _recentReports[index] as Map<String, dynamic>,
                      ),
                    ),
                  );
                },
                child: _buildActivityTile(_recentReports[index]),
              );
            },
          ),
      ],
    );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: leftSideContent),
                const SizedBox(width: 30),
                Expanded(flex: 4, child: rightSideContent),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftSideContent,
                const SizedBox(height: 35),
                rightSideContent,
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildDataContent() {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    List<dynamic> currentData = _filteredReports;

    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 800;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          decoration: BoxDecoration(
            color: isLightMode ? Colors.white : const Color(0xFF0A101D),
            border: Border(
              bottom: BorderSide(
                color: isLightMode ? Colors.grey[200]! : Colors.white10,
              ),
            ),
            boxShadow: isLightMode
                ? [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
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
                            : (isLightMode
                                ? Colors.grey[100]
                                : const Color(0xFF1E293B)),
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: isLightMode
                                    ? Colors.grey[300]!
                                    : Colors.white10,
                              ),
                      ),
                      child: Text(
                        _filterOptions[index],
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.grey,
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        if (activeFilter != null &&
            (activeFilter!['bulan'] != null ||
                (activeFilter!['gangguan'] as List).isNotEmpty))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: const Color(0xFF00D1F3).withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    "Filter aktif diterapkan pada daftar laporan",
                    style: TextStyle(color: Color(0xFF00D1F3), fontSize: 16),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() {
                    activeFilter = null;
                  }),
                  child: const Text(
                    "Hapus Filter",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: currentData.isEmpty
              ? _buildEmptyState()
              : (isDesktop
                  ? GridView.builder(
                      padding: const EdgeInsets.all(20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: screenWidth > 1400
                            ? 5
                            : (screenWidth > 1100 ? 4 : 3),
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        mainAxisExtent: 500,
                      ),
                      itemCount: currentData.length,
                      itemBuilder: (context, index) {
                        return _buildDataCard(currentData[index]);
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: currentData.length,
                      itemBuilder: (context, index) {
                        return _buildDataCard(currentData[index]);
                      },
                    )),
        ),
      ],
    );
  }

  Widget _buildAnalyticsContent() {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color textColor = isLightMode ? Colors.black : Colors.white;
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF161F2E);

    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 800;

    if (_allReports.isEmpty) {
      return const Center(
        child: Text(
          "Belum ada data untuk dianalisis",
          style: TextStyle(color: Colors.grey, fontSize: 19),
        ),
      );
    }

    double completionRate =
        _totalCount == 0 ? 0 : (_verifiedCount / _totalCount) * 100;

    Map<String, int> stoCount = {};
    for (var r in _allReports) {
      String sto = (r['sto'] ?? 'Unknown').toString().trim();
      if (sto.isEmpty) sto = 'Unknown';
      stoCount[sto] = (stoCount[sto] ?? 0) + 1;
    }
    var sortedSto = stoCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var top5Sto = sortedSto.take(5).toList();

    Map<String, int> catCount = {};
    for (var r in _allReports) {
      String cat = (r['kategori_kegiatan'] ?? 'Lainnya').toString().trim();
      if (cat.isEmpty) cat = 'Lainnya';
      catCount[cat] = (catCount[cat] ?? 0) + 1;
    }
    var sortedCat = catCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String topStoName = top5Sto.isNotEmpty ? top5Sto.first.key : '-';
    int topStoCount = top5Sto.isNotEmpty ? top5Sto.first.value : 0;
    String topCatName = sortedCat.isNotEmpty ? sortedCat.first.key : '-';
    int topCatCount = sortedCat.isNotEmpty ? sortedCat.first.value : 0;

    String majorityStatus = 'Pending';
    int maxStatusCount = _pendingCount;
    if (_verifiedCount > maxStatusCount) {
      majorityStatus = 'Verified';
      maxStatusCount = _verifiedCount;
    }
    if (_rejectedCount > maxStatusCount) {
      majorityStatus = 'Rejected';
      maxStatusCount = _rejectedCount;
    }

    String summaryText =
        "Berdasarkan data saat ini, total terdapat $_totalCount laporan dengan tingkat penyelesaian sebesar ${completionRate.toStringAsFixed(1)}%. "
        "Mayoritas laporan saat ini berada pada status $majorityStatus. "
        "Lokasi STO yang paling banyak menerima laporan adalah STO $topStoName ($topStoCount laporan), "
        "dengan jenis gangguan yang mendominasi yaitu $topCatName ($topCatCount kasus).";

    Widget summaryCard = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00D1F3).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D1F3).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline, color: Color(0xFF00D1F3), size: 24),
              SizedBox(width: 8),
              Text(
                "Ringkasan Eksekutif",
                style: TextStyle(
                  color: Color(0xFF00D1F3),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            summaryText,
            style: TextStyle(
              color: isLightMode ? Colors.black87 : Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );

    Widget completionCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.task_alt, color: Colors.green, size: 28),
          const SizedBox(height: 10),
          Text(
            "${completionRate.toStringAsFixed(1)}%",
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "Completion Rate",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );

    Widget totalReportCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00D1F3).withOpacity(0.3)),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics, color: Color(0xFF00D1F3), size: 28),
          const SizedBox(height: 10),
          Text(
            "$_totalCount",
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            "Total Laporan",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );

    Widget pieChartCard = Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Distribusi Status Pekerjaan",
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
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
                                .touchedSection!.touchedSectionIndex;
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
        ],
      ),
    );

    Widget barChartCard = Container(
      height: 300,
      padding: const EdgeInsets.only(top: 20, right: 20, left: 10, bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10.0),
            child: Text(
              "Lokasi Kritis (Top 5 STO)",
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: top5Sto.isEmpty
                ? const Center(
                    child: Text(
                      "Tidak ada data",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
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
                                  value.toInt() >= top5Sto.length) {
                                return const SizedBox.shrink();
                              }
                              String title = top5Sto[value.toInt()].key;
                              if (title.length > 5) {
                                title = title.substring(0, 5);
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
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
                                fontSize: 12,
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
                        getDrawingHorizontalLine: (value) => FlLine(
                          color:
                              isLightMode ? Colors.grey[200] : Colors.white10,
                          strokeWidth: 1,
                        ),
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
        ],
      ),
    );

    Widget categoryListCard = Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Distribusi Jenis Gangguan",
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: sortedCat.length,
              separatorBuilder: (context, index) => Divider(
                color: isLightMode ? Colors.grey[300] : Colors.white10,
                height: 24,
              ),
              itemBuilder: (context, index) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        sortedCat[index].key,
                        style: TextStyle(
                          color:
                              isLightMode ? Colors.grey[800] : Colors.white70,
                          fontSize: 15,
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
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Descriptive Analytics",
            style: TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Overview & performa pemeliharaan",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 20),
          if (isDesktop) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: summaryCard),
                  const SizedBox(width: 20),
                  Expanded(flex: 1, child: completionCard),
                  const SizedBox(width: 20),
                  Expanded(flex: 1, child: totalReportCard),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: pieChartCard),
                const SizedBox(width: 20),
                Expanded(flex: 1, child: barChartCard),
                const SizedBox(width: 20),
                Expanded(flex: 1, child: categoryListCard),
              ],
            ),
          ] else ...[
            summaryCard,
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: completionCard),
                const SizedBox(width: 15),
                Expanded(child: totalReportCard),
              ],
            ),
            const SizedBox(height: 20),
            pieChartCard,
            const SizedBox(height: 20),
            barChartCard,
            const SizedBox(height: 20),
            categoryListCard,
          ],
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileContent() {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color textColor = isLightMode ? Colors.black : Colors.white;
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF161F2E);

    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 800;

    Widget userInfoWidget = Column(
      children: [
        GestureDetector(
          onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00D1F3), width: 2),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor:
                      isLightMode ? Colors.grey[200] : const Color(0xFF161F2E),
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!) as ImageProvider
                      : (_photoUrl != null ? NetworkImage(_photoUrl!) : null),
                  child: (_profileImage == null && _photoUrl == null)
                      ? Icon(
                          Icons.person,
                          size: 50,
                          color: isLightMode ? Colors.grey : Colors.white,
                        )
                      : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF00D1F3),
                  shape: BoxShape.circle,
                ),
                child: _isUploadingPhoto
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.camera_alt,
                        color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Text(
          widget.userName,
          style: TextStyle(
            color: textColor,
            fontSize: 24,
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isLightMode
                ? [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D1F3).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.badge,
                  color: Color(0xFF00D1F3),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "User ID",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.userId ?? 'ADMIN-PST',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
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
                icon: const Icon(Icons.copy, color: Colors.grey, size: 24),
              ),
            ],
          ),
        ),
      ],
    );

    List<Widget> menuButtons = [
      _buildNewProfileMenuItem(
        Icons.person_add_alt_1,
        "Daftarkan Pengguna Baru",
        () => _showAddUserDialog(context),
        isDesktop,
      ),
      _buildNewProfileMenuItem(
        Icons.person_remove,
        "Hapus Pengguna via ID",
        _showDeleteDialog,
        isDesktop,
        isDestructive: true,
      ),
      _buildNewProfileMenuItem(
        Icons.person_outline,
        "Edit Profil",
        () {},
        isDesktop,
      ),
      _buildNewProfileMenuItem(
        Icons.calendar_month,
        "Jadwal & Tim Lapangan (TLA)",
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  JadwalScreen(busyTechIds: _getBusyTechnicians()),
            ),
          );
        },
        isDesktop,
      ),
      _buildNewProfileMenuItem(
        Icons.notifications_none,
        "Notifikasi",
        () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationScreen(userId: 'admin'),
            ),
          );
          _fetchUnreadCount();
        },
        isDesktop,
      ),
      _buildNewProfileMenuItem(
        Icons.help_outline,
        "Bantuan & Support",
        () {},
        isDesktop,
      ),
      _buildNewProfileMenuItem(
        Icons.logout,
        "Keluar Aplikasi",
        () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        isDesktop,
        isDestructive: true,
      ),
    ];

    Widget settingsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Pengaturan Akun & Admin",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        if (isDesktop)
          Wrap(
            spacing: 15,
            runSpacing: 0,
            children: menuButtons
                .map(
                  (btn) => SizedBox(
                    width: (screenWidth - 250 - 40 - 50) / 2,
                    child: btn,
                  ),
                )
                .toList(),
          )
        else
          Column(children: menuButtons),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: userInfoWidget),
                const SizedBox(width: 40),
                Expanded(flex: 5, child: settingsWidget),
              ],
            )
          : Column(
              children: [
                userInfoWidget,
                const SizedBox(height: 30),
                settingsWidget,
              ],
            ),
    );
  }

  Widget _buildNewProfileMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap,
    bool isDesktop, {
    bool isDestructive = false,
  }) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color bgColor = isLightMode ? Colors.white : const Color(0xFF161F2E);
    Color textColor = isDestructive
        ? Colors.redAccent
        : (isLightMode ? Colors.black : Colors.white);
    Color borderColor = isDestructive
        ? Colors.red.withOpacity(0.3)
        : (isLightMode ? Colors.grey[200]! : Colors.transparent);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: isDesktop ? 14 : 18,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isDestructive
                      ? Colors.redAccent
                      : const Color(0xFF00D1F3),
                  size: isDesktop ? 24 : 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: isDesktop ? 16 : 19,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDestructive
                      ? Colors.transparent
                      : Colors.grey.withOpacity(0.5),
                  size: isDesktop ? 16 : 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCard(dynamic data) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 800;

    String idStr = "MAINT-${(data['id'] ?? 0).toString().padLeft(3, '0')}";

    String statusString = (data['status'] ?? '').toString().toLowerCase();
    bool isPending = statusString.contains('pending');
    bool isVerified = statusString.contains('verif');
    bool isSelesai = statusString == 'selesai';
    bool isClose = statusString == 'close';

    Color statusColor = isClose
        ? Colors.grey
        : (isSelesai
            ? Colors.redAccent
            : (isPending
                ? Colors.orange
                : (isVerified ? Colors.green : Colors.red)));

    String reportSto = (data['sto'] ?? '').toString().toUpperCase();
    if (_stoFullNames.containsKey(reportSto)) {
      reportSto = _stoFullNames[reportSto]!;
    }

    List<dynamic> allTechsInSto = _stoTechnicians[reportSto] ?? [];
    List<dynamic> assignedTechs = [];

    assignedTechs.add({
      'user_id': data['user_id']?.toString() ?? '-',
      'name': data['teknisi']?.toString() ?? 'Teknisi Pelapor',
    });

    int maxWorkers = 5;
    int added = 1;
    for (var tech in allTechsInSto) {
      if (tech['user_id']?.toString() != data['user_id']?.toString() &&
          added < maxWorkers) {
        assignedTechs.add(tech);
        added++;
      }
    }

    int currentWorkers = assignedTechs.length;

    Color cardBgColor = isLightMode ? Colors.white : const Color(0xFF161F2E);
    Color headerBgColor = isLightMode
        ? Colors.grey[100]!
        : const Color(0xFF1E293B).withOpacity(0.5);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    Widget contentBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          Icons.person,
          "Pelapor",
          data['teknisi'] ?? 'Teknisi Pelapor',
          isLightMode,
          isDesktop,
        ),
        const SizedBox(height: 10),
        _buildInfoRow(
          Icons.map,
          "Witel",
          data['witel'] ?? '-',
          isLightMode,
          isDesktop,
        ),
        const SizedBox(height: 10),
        _buildInfoRow(
          Icons.location_on,
          "STO",
          data['sto'] ?? '-',
          isLightMode,
          isDesktop,
        ),
        const SizedBox(height: 10),
        _buildInfoRow(
          Icons.category,
          "Kategori",
          data['kategori_kegiatan'] ?? '-',
          isLightMode,
          isDesktop,
        ),
        const SizedBox(height: 15),
        Text(
          "Uraian Pekerjaan:",
          style: TextStyle(color: Colors.grey, fontSize: isDesktop ? 14 : 16),
        ),
        const SizedBox(height: 5),
        Text(
          data['uraian_pekerjaan'] ?? '-',
          style: TextStyle(color: textColor, fontSize: isDesktop ? 15 : 19),
        ),
        if (isVerified || isSelesai || isClose) ...[
          const SizedBox(height: 15),
          Divider(color: isLightMode ? Colors.grey[300] : Colors.white10),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.engineering,
                color: Colors.blueAccent,
                size: isDesktop ? 16 : 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Teknisi Ditugaskan :",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: isDesktop ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (assignedTechs.isEmpty)
            Text(
              "Belum ada data teknisi tersedia di STO ini.",
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: isDesktop ? 14 : 16,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLightMode
                    ? Colors.grey[100]
                    : Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLightMode ? Colors.grey[300]! : Colors.white10,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: assignedTechs
                    .map(
                      (tech) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              color: Colors.green,
                              size: 8,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "${tech['user_id']}  -  ${tech['name']}",
                                style: TextStyle(
                                  color: isLightMode
                                      ? Colors.grey[800]
                                      : Colors.white70,
                                  fontSize: isDesktop ? 13 : 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ],
    );

    return Container(
      margin: EdgeInsets.only(bottom: isDesktop ? 0 : 20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelesai
              ? Colors.red
              : (isLightMode
                  ? Colors.grey[300]!
                  : Colors.white.withOpacity(0.05)),
          width: isSelesai ? 2.0 : 1.0,
        ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminDetailLaporanScreen(
                  reportData: data as Map<String, dynamic>,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 16),
                decoration: BoxDecoration(
                  color: headerBgColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            idStr,
                            style: TextStyle(
                              color: textColor,
                              fontSize: isDesktop ? 16 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['created_at']?.toString().substring(0, 10) ??
                                '-',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: isDesktop ? 12 : 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.only(
                                right: isDesktop ? 4 : 8,
                              ),
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AdminEditLaporanScreen(
                                      reportData: data as Map<String, dynamic>,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _fetchAdminData();
                                  _fetchTechnicianData();
                                }
                              },
                              icon: Icon(
                                Icons.edit,
                                color: Colors.blue,
                                size: isDesktop ? 20 : 24,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 8 : 12,
                                vertical: isDesktop ? 4 : 6,
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
                                  fontSize: isDesktop ? 12 : 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isVerified || isSelesai || isClose)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isClose
                                        ? Colors.grey.withOpacity(0.2)
                                        : Colors.blueAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isClose
                                          ? Colors.grey.withOpacity(0.5)
                                          : Colors.blueAccent.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    isClose ? "CLOSE" : "OPEN",
                                    style: TextStyle(
                                      color: isClose
                                          ? Colors.grey
                                          : Colors.blueAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.group,
                                      color: Colors.grey,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "$currentWorkers/$maxWorkers",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isDesktop)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(child: contentBody),
                  ),
                )
              else
                Padding(padding: const EdgeInsets.all(20), child: contentBody),
              if (isPending) ...[
                Divider(
                  color: isLightMode ? Colors.grey[200] : Colors.white10,
                  height: 1,
                ),
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 12 : 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmUpdateStatus(
                            context,
                            data['id'],
                            'Rejected',
                          ),
                          icon: Icon(
                            Icons.close,
                            color: Colors.redAccent,
                            size: isDesktop ? 20 : 24,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Tolak",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: isDesktop ? 15 : 19,
                              ),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            padding: EdgeInsets.symmetric(
                              vertical: isDesktop ? 8 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _confirmUpdateStatus(
                            context,
                            data['id'],
                            'Verified',
                          ),
                          icon: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: isDesktop ? 20 : 24,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "Verifikasi",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 15 : 19,
                              ),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(
                              vertical: isDesktop ? 8 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isSelesai) ...[
                Divider(
                  color: isLightMode ? Colors.grey[200] : Colors.white10,
                  height: 1,
                ),
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 12 : 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: isDesktop ? 45 : 55,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _confirmUpdateStatus(context, data['id'], 'CLOSE'),
                      icon: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: isDesktop ? 20 : 24,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Tutup Tiket (CLOSE)",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 15 : 20,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: EdgeInsets.symmetric(
                          vertical: isDesktop ? 8 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ] else if (isClose) ...[
                Divider(
                  color: isLightMode ? Colors.grey[200] : Colors.white10,
                  height: 1,
                ),
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 12 : 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: isDesktop ? 45 : 55,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final String docUrl =
                            '${ApiConfig.baseUrl}/maintenance/reports/${data['id']}/export-word';
                        final Uri url = Uri.parse(docUrl);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Gagal mengunduh dokumen Word"),
                              ),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        Icons.description,
                        color: Colors.white,
                        size: isDesktop ? 20 : 24,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Export Laporan (Word)",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 15 : 20,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: EdgeInsets.symmetric(
                          vertical: isDesktop ? 8 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value,
    bool isLightMode,
    bool isDesktop,
  ) {
    double fontSize = isDesktop ? 14 : 19;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF00D1F3), size: isDesktop ? 20 : 24),
        const SizedBox(width: 10),
        SizedBox(
          width: isDesktop ? 65 : 85,
          child: Text(
            title,
            style: TextStyle(color: Colors.grey, fontSize: fontSize),
          ),
        ),
        Text(
          ":",
          style: TextStyle(color: Colors.grey, fontSize: fontSize),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isLightMode ? Colors.black : Colors.white,
              fontSize: fontSize,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
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
          Text(
            "Tidak ada data ditemukan",
            style: TextStyle(
              color: isLightMode ? Colors.black : Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Coba ubah filter kategori Anda.",
            style: TextStyle(color: Colors.grey, fontSize: 19),
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
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 800;

    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isDesktop ? 12 : 20,
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: isLightMode ? Colors.white : const Color(0xFF161F2E),
          borderRadius: BorderRadius.circular(20),
          border: isLightMode
              ? Border.all(color: Colors.grey[200]!)
              : Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: isLightMode
              ? [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: isDesktop ? 24 : 32),
            SizedBox(height: isDesktop ? 8 : 12),
            Text(
              value,
              style: TextStyle(
                color: isLightMode ? Colors.black : Colors.white,
                fontSize: isDesktop ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey,
                fontSize: isDesktop ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
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
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
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
            child: Icon(icon, color: bgColor, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: isLightMode ? Colors.black87 : Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTile(dynamic data) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    String status = (data['status'] ?? '').toString().toLowerCase();
    Color statusColor = status == 'close'
        ? Colors.grey
        : (status == 'selesai'
            ? Colors.redAccent
            : (status.contains('verif')
                ? Colors.green
                : (status.contains('reject') ? Colors.red : Colors.orange)));
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLightMode ? Colors.white : const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLightMode
            ? [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
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
                  style: TextStyle(
                    color: isLightMode ? Colors.black : Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "Report ID: MAINT-${(data['id'] ?? 0).toString().padLeft(3, '0')}",
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
          Text(
            (data['status'] ?? 'PENDING').toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDetailLaporanScreen extends StatelessWidget {
  final Map<String, dynamic> reportData;
  const AdminDetailLaporanScreen({super.key, required this.reportData});

  @override
  Widget build(BuildContext context) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color bgColor =
        isLightMode ? const Color(0xFFF8FAFC) : const Color(0xFF0A101D);
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF161F2E);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    String idData = "MAINT-${reportData['id'].toString().padLeft(3, '0')}";
    String statusString =
        (reportData['status'] ?? 'Pending').toString().toLowerCase();

    bool isSelesai = statusString == 'selesai';
    bool isClose = statusString == 'close';
    bool isVerified = statusString.contains('verif');

    Color statusColor = isClose
        ? Colors.grey
        : (isSelesai
            ? Colors.redAccent
            : (isVerified
                ? Colors.green
                : statusString.contains('reject')
                    ? Colors.red
                    : Colors.orange));

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
      backgroundColor: bgColor,
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
                          offset: const Offset(0, 5),
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
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        idData,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24,
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
                      (reportData['status'] ?? 'Pending')
                          .toString()
                          .toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    "Area",
                    reportData['area']?.toString() ?? '-',
                    isLightMode,
                  ),
                  _buildDetailRow(
                    "District",
                    reportData['district']?.toString() ?? '-',
                    isLightMode,
                  ),
                  _buildDetailRow(
                    "Witel",
                    reportData['witel']?.toString() ?? '-',
                    isLightMode,
                  ),
                  _buildDetailRow(
                    "STO",
                    reportData['sto']?.toString() ?? '-',
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
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SelectableText(
                    mapsUrl,
                    style: TextStyle(
                      color:
                          isLightMode ? Colors.blue[700] : Colors.greenAccent,
                      fontSize: 19,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
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
                        size: 24,
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Buka di Google Maps",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
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
                reportData['kategori_kegiatan']?.toString() ?? '-',
                isLightMode,
              ),
              _buildDetailRow(
                "Uraian Pekerjaan",
                reportData['uraian_pekerjaan']?.toString() ?? '-',
                isLightMode,
              ),
              _buildDetailRow(
                "Mitra Pelaksana",
                reportData['mitra_pelaksana']?.toString() ?? '-',
                isLightMode,
              ),
              _buildDetailRow(
                "Teknisi",
                reportData['teknisi']?.toString() ?? '-',
                isLightMode,
              ),
              _buildDetailRow(
                "Waktu Laporan",
                reportData['created_at']?.toString().substring(0, 10) ?? '-',
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
            _buildPhotoCategory(
              context,
              "Before",
              beforePaths,
              isLightMode,
              reportData['id'],
            ),
            const SizedBox(height: 15),
            _buildPhotoCategory(
              context,
              "Progress",
              progressPaths,
              isLightMode,
              reportData['id'],
            ),
            const SizedBox(height: 15),
            _buildPhotoCategory(
              context,
              "After",
              afterPaths,
              isLightMode,
              reportData['id'],
            ),
            const SizedBox(height: 40),
            Text(
              "Lampiran Evidence",
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
              child: Column(
                children: [
                  _buildEvidenceStatus(
                    context,
                    "Material Tiba",
                    reportData['evidence_material'],
                    isLightMode,
                  ),
                  Divider(
                    color: isLightMode ? Colors.grey[300] : Colors.white10,
                    height: 24,
                  ),
                  _buildEvidenceStatus(
                    context,
                    "Hasil Ukur",
                    reportData['evidence_ukur'],
                    isLightMode,
                  ),
                  Divider(
                    color: isLightMode ? Colors.grey[300] : Colors.white10,
                    height: 24,
                  ),
                  _buildEvidenceStatus(
                    context,
                    "Pendukung/BA",
                    reportData['evidence_pendukung'],
                    isLightMode,
                  ),
                ],
              ),
            ),
            if (isClose) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final String docUrl =
                        '${ApiConfig.baseUrl}/maintenance/reports/${reportData['id']}/export-word';
                    final Uri url = Uri.parse(docUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Gagal mengunduh dokumen Word",
                              style: TextStyle(fontSize: 19),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.description,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      "Export Report ke Word (.docx)",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
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
                fontSize: 19,
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
                fontSize: 19,
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
    bool isLightMode,
    int? reportId,
  ) {
    String storageBaseUrl = ApiConfig.baseUrl.replaceAll('/api', '/storage/');
    Color boxBg = isLightMode ? Colors.grey[200]! : const Color(0xFF1E293B);
    Color borderColor = isLightMode ? Colors.grey[300]! : Colors.white10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label (${paths.length} Foto)",
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 10),
        paths.isEmpty
            ? Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: boxBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  Icons.image_not_supported,
                  color: isLightMode ? Colors.grey[400] : Colors.grey,
                  size: 32,
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
                  String fullUrl = "$storageBaseUrl${paths[index]}";
                  String heroTag =
                      "admin_image_${reportId ?? 0}_${label}_$index";
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
                          color:
                              isLightMode ? Colors.grey[300]! : Colors.white24,
                        ),
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
    bool isLightMode,
  ) {
    bool isUploaded = path != null && path.toString().isNotEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isLightMode ? Colors.grey[800] : Colors.white70,
            fontSize: 19,
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isUploaded) ...[
              const SizedBox(width: 10),
              InkWell(
                onTap: () async {
                  final String fileUrl =
                      '${ApiConfig.baseUrl.replaceAll('/api', '/storage/')}$path';
                  final Uri url = Uri.parse(fileUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Tidak dapat membuka file",
                          style: TextStyle(fontSize: 19),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download,
                    color: Colors.blue,
                    size: 24,
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
    // KEMBALIKAN KATA '.platform' KE TEMPAT DUDUKNYA:
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'rar', 'pdf'],
      withData: true,
    );

    if (result != null) {
      setState(() {
        if (type == 1) {
          _fileMaterialTiba = result.files.first;
        } else if (type == 2) {
          _fileHasilUkur = result.files.first;
        } else if (type == 3) {
          _filePendukung = result.files.first;
        }
      });
    }
  }

  Future<void> _saveEditData() async {
    setState(() => _isSaving = true);
    try {
      final reportId = widget.reportData['id'];
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/maintenance/reports/$reportId',
      );

      var request = http.MultipartRequest('POST', url);
      request.fields['_method'] = 'PUT';
      request.fields['sto'] = _stoController.text;
      request.fields['kategori_kegiatan'] = _kategoriController.text;
      request.fields['mitra_pelaksana'] = _mitraController.text;
      request.fields['uraian_pekerjaan'] = _uraianController.text;

      if (_fileMaterialTiba != null) {
        if (_fileMaterialTiba!.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'evidence_material',
              _fileMaterialTiba!.bytes!,
              filename: _fileMaterialTiba!.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'evidence_material',
              _fileMaterialTiba!.path!,
            ),
          );
        }
      }
      if (_fileHasilUkur != null) {
        if (_fileHasilUkur!.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'evidence_ukur',
              _fileHasilUkur!.bytes!,
              filename: _fileHasilUkur!.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'evidence_ukur',
              _fileHasilUkur!.path!,
            ),
          );
        }
      }
      if (_filePendukung != null) {
        if (_filePendukung!.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'evidence_pendukung',
              _filePendukung!.bytes!,
              filename: _filePendukung!.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'evidence_pendukung',
              _filePendukung!.path!,
            ),
          );
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!context.mounted) return;
      setState(() => _isSaving = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Data & Bukti berhasil diperbarui!",
              style: TextStyle(fontSize: 19),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Gagal menyimpan data ke server. Pastikan batas di php.ini sudah diubah!",
              style: TextStyle(fontSize: 19),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e", style: const TextStyle(fontSize: 19)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color bgColor =
        isLightMode ? const Color(0xFFF8FAFC) : const Color(0xFF0A101D);
    Color textColor = isLightMode ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Edit Laporan & Upload Bukti',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
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
            _buildTextField(_stoController, isLightMode),
            const SizedBox(height: 20),
            _buildFieldLabel("Kategori Kegiatan"),
            _buildTextField(_kategoriController, isLightMode),
            const SizedBox(height: 20),
            _buildFieldLabel("Mitra Pelaksana"),
            _buildTextField(_mitraController, isLightMode),
            const SizedBox(height: 20),
            _buildFieldLabel("Uraian Pekerjaan"),
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: isLightMode ? Colors.white : const Color(0xFF161F2E),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isLightMode ? Colors.grey[300]! : Colors.white10,
                ),
              ),
              child: TextField(
                controller: _uraianController,
                maxLines: 4,
                style: TextStyle(color: textColor, fontSize: 19),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(15),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Divider(color: isLightMode ? Colors.grey[300] : Colors.white10),
            const SizedBox(height: 15),
            Text(
              "Upload Evidence (.zip/.rar)",
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            _buildFilePicker(
              "Evidence Material Tiba",
              _fileMaterialTiba,
              () => _pickFile(1),
              isLightMode,
            ),
            _buildFilePicker(
              "Evidence Hasil Ukur",
              _fileHasilUkur,
              () => _pickFile(2),
              isLightMode,
            ),
            _buildFilePicker(
              "Evidence Pendukung/BA",
              _filePendukung,
              () => _pickFile(3),
              isLightMode,
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
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "Simpan Semua Perubahan",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
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
          fontSize: 19,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _buildTextField(TextEditingController controller, bool isLightMode) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isLightMode ? Colors.white : const Color(0xFF161F2E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isLightMode ? Colors.grey[300]! : Colors.white10,
        ),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(
          color: isLightMode ? Colors.black : Colors.white,
          fontSize: 19,
        ),
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
    bool isLightMode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 19,
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
              color: isLightMode ? Colors.white : const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isLightMode ? Colors.grey[300]! : Colors.white10,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_zip,
                  size: 24,
                  color: file != null ? Colors.green : const Color(0xFF00D1F3),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    file != null ? file.name : "Pilih File...",
                    style: TextStyle(
                      color: file != null
                          ? (isLightMode ? Colors.black : Colors.white)
                          : Colors.grey,
                      fontSize: 19,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (file != null)
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

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

class JadwalScreen extends StatefulWidget {
  final Set<String> busyTechIds;
  const JadwalScreen({super.key, required this.busyTechIds});

  @override
  State<JadwalScreen> createState() => _JadwalScreenState();
}

class _JadwalScreenState extends State<JadwalScreen> {
  bool _isLoading = true;
  Map<String, List<dynamic>> _groupedTlaUsers = {};

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
      final url = Uri.parse('${ApiConfig.baseUrl}/users');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> users = data['data'] ?? [];
        Map<String, List<dynamic>> tempGroup = {};

        for (var user in users) {
          String role = user['role']?.toString() ?? '';
          if (role != 'Tim Lapangan') continue;

          String userId = user['user_id']?.toString().toUpperCase() ?? '';
          List<String> parts = userId.split('-');
          String prefix = '';

          if (parts.length >= 3 && parts[0] == 'TLA') {
            prefix = parts[1];
          } else if (parts.length == 2) {
            prefix = parts[0];
          } else {
            continue;
          }

          if (!tempGroup.containsKey(prefix)) tempGroup[prefix] = [];
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
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 19)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLightMode = Theme.of(context).brightness == Brightness.light;
    Color bgColor =
        isLightMode ? const Color(0xFFF8FAFC) : const Color(0xFF0A101D);
    Color textColor = isLightMode ? Colors.black : Colors.white;
    Color cardColor = isLightMode ? Colors.white : const Color(0xFF1E293B);

    List<String> groupKeys = _groupedTlaUsers.keys.toList()..sort();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Manajemen Tim Lapangan',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
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
                    style: TextStyle(color: Colors.grey, fontSize: 19),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: groupKeys.length,
                  itemBuilder: (context, index) {
                    String prefix = groupKeys[index];
                    String fullStoName = _stoFullNames[prefix] ?? prefix;
                    List<dynamic> usersInGroup = _groupedTlaUsers[prefix]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "STO $fullStoName",
                          style: const TextStyle(
                            color: Color(0xFF00D1F3),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isLightMode
                                ? [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                isLightMode
                                    ? Colors.grey[200]
                                    : const Color(0xFF334155),
                              ),
                              dataRowMinHeight: 60,
                              dataRowMaxHeight: 60,
                              columns: [
                                DataColumn(
                                  label: Text(
                                    'No',
                                    style: TextStyle(
                                      color: isLightMode
                                          ? Colors.black87
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'STO',
                                    style: TextStyle(
                                      color: isLightMode
                                          ? Colors.black87
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'ID Tim Lapangan',
                                    style: TextStyle(
                                      color: isLightMode
                                          ? Colors.black87
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Nama',
                                    style: TextStyle(
                                      color: isLightMode
                                          ? Colors.black87
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Status',
                                    style: TextStyle(
                                      color: isLightMode
                                          ? Colors.black87
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                              ],
                              rows: List.generate(usersInGroup.length,
                                  (rowIndex) {
                                final user = usersInGroup[rowIndex];
                                bool isBusy = widget.busyTechIds.contains(
                                  user['user_id'],
                                );

                                return DataRow(
                                  color: WidgetStateProperty.all(
                                    rowIndex % 2 == 0
                                        ? Colors.transparent
                                        : (isLightMode
                                            ? Colors.grey[50]
                                            : Colors.black12),
                                  ),
                                  cells: [
                                    DataCell(
                                      Text(
                                        '${rowIndex + 1}',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 19,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        fullStoName,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 19,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        user['user_id'] ?? '-',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 19,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        user['name'] ?? '-',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 19,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isBusy
                                              ? Colors.orange.withOpacity(0.2)
                                              : Colors.green.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isBusy
                                                ? Colors.orange.withOpacity(0.5)
                                                : Colors.green.withOpacity(0.5),
                                          ),
                                        ),
                                        child: Text(
                                          isBusy ? "Ditugaskan" : "Tersedia",
                                          style: TextStyle(
                                            color: isBusy
                                                ? (isLightMode
                                                    ? Colors.orange[800]
                                                    : Colors.orangeAccent)
                                                : (isLightMode
                                                    ? Colors.green[800]
                                                    : Colors.greenAccent),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
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
