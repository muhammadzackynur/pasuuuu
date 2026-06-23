import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiConfig {
  // URL Ngrok Anda (Sudah ditaruh /api di belakangnya)
  static const String baseUrl =
      'https://creation-catatonic-phoenix.ngrok-free.dev/api';

  // ===========================================================================
  // 1. DAFTAR ENDPOINT ROUTE (Jangan dihapus agar fitur lain tidak crash!)
  // ===========================================================================
  static const String login = '$baseUrl/login';
  static const String register = '$baseUrl/register';
  static const String logout = '$baseUrl/logout';

  static const String users = '$baseUrl/users';
  static const String deleteUser = '$baseUrl/users';

  // ===========================================================================
  // 2. FUNGSI-FUNGSI PEMANGGIL API
  // ===========================================================================

  /// Mengambil riwayat pekerjaan teknisi berdasarkan User ID
  static Future<List<dynamic>> getHistoryPekerjaan(
    String userId, {
    String? token,
  }) async {
    final url = Uri.parse('$baseUrl/maintenance/history/$userId');

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Header wajib untuk melewati layar biru "Visit Site" milik Ngrok
      'ngrok-skip-browser-warning': 'true',
    };

    // Jika endpoint ini di Laravel Anda dibungkus auth:sanctum, otomatis masukkan Bearer
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // Pengaman 1: Jika backend mengembalikan format JSON Object -> { "success": true, "data": [...] }
        if (decoded is Map<String, dynamic>) {
          if (decoded['success'] == true && decoded['data'] != null) {
            return decoded['data'];
          }
        }
        // Pengaman 2: Jika backend mengembalikan format JSON Array langsung -> [ {...}, {...} ]
        else if (decoded is List) {
          return decoded;
        }
      }

      // Jika status bukan 200 OK, print alasan kegagalannya di Debug Console
      print(
        'HTTP GET History Gagal. Status: ${response.statusCode}, Isi: ${response.body}',
      );
      return [];
    } catch (e) {
      print('Terjadi kesalahan koneksi saat mengambil History: $e');
      return [];
    }
  }
}
