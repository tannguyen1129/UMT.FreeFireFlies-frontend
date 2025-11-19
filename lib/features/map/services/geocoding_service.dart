import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingService {
  // Sử dụng Nominatim (OpenStreetMap) - Miễn phí
  final String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      final url = Uri.parse(
          '$_baseUrl?q=$address&format=json&limit=1&addressdetails=1');

      // Nominatim yêu cầu User-Agent
      final response = await http.get(url, headers: {
        'User-Agent': 'GreenAqiNavigator/1.0',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      print('Lỗi Geocoding: $e');
    }
    return null;
  }
}