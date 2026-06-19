import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiConfig {
  // Ganti baseUrl menggunakan URL Ngrok Anda ditambah '/api'
  static const String baseUrl =
      'https://creation-catatonic-phoenix.ngrok-free.dev/api';

  static Future<List<dynamic>> getHistoryPekerjaan(String userId) async {
    final url = Uri.parse('$baseUrl/maintenance/history/$userId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          // Header ini WAJIB ditambahkan untuk melewati halaman peringatan keamanan Ngrok
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return responseData['data'];
        }
      }
      return [];
    } catch (e) {
      print('Error fetching history: $e');
      return [];
    }
  }
}
