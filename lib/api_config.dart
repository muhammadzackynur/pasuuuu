import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiConfig {
  // Pastikan IP ini adalah IP laptop Anda yang terhubung ke WiFi saat ini
  static const String baseUrl = 'http://192.168.1.154:8000/api';

  // Fungsi history ini HARUS berada di DALAM kurung kurawal class ApiConfig
  static Future<List<dynamic>> getHistoryPekerjaan(String userId) async {
    final url = Uri.parse('$baseUrl/maintenance/history/$userId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          // 'Authorization': 'Bearer $token', // Buka komentar ini jika API Anda memakai token
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
