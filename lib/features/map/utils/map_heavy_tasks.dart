/*
 * Copyright 2025 Green-AQI Navigator Team
 * Apache License 2.0
 */

import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import 'package:collection/collection.dart'; // Cần cài package: collection

/// 1. Giải mã KML (Chạy ngầm qua isolate)
/// Input: Chuỗi XML raw -> Output: List các đa giác
List<List<LatLng>> parseKmlInBackground(String kmlString) {
  final document = XmlDocument.parse(kmlString);
  final polygons = <List<LatLng>>[];

  final placemarks = document.findAllElements('Placemark');
  for (var placemark in placemarks) {
    final coordinatesNode = placemark.findAllElements('coordinates').firstOrNull;
    if (coordinatesNode != null) {
      final text = coordinatesNode.innerText.trim();
      final List<LatLng> points = [];
      // Tối ưu Regex để parse nhanh hơn
      final rawPoints = text.split(RegExp(r'\s+'));

      for (var raw in rawPoints) {
        final parts = raw.split(',');
        if (parts.length >= 2) {
          final lng = double.tryParse(parts[0]);
          final lat = double.tryParse(parts[1]);
          if (lng != null && lat != null) {
            points.add(LatLng(lat, lng));
          }
        }
      }
      if (points.isNotEmpty) polygons.add(points);
    }
  }
  return polygons;
}

/// 2. Tính toán Heatmap IDW (Chạy ngầm qua isolate)
/// Input: List JSON từ API -> Output: List các điểm vẽ Map
List<Map<String, dynamic>> computeHeatmapData(List<dynamic> sensors) {
  final List<Map<String, dynamic>> results = [];

  // ⚡ TỐI ƯU HIỆU NĂNG:
  // Step 0.025 là mức cân bằng giữa Đẹp và Nhanh
  const double minLat = 10.35; const double maxLat = 11.10;
  const double minLng = 106.30; const double maxLng = 107.00;
  const double step = 0.025;

  for (double lat = minLat; lat <= maxLat; lat += step) {
    for (double lng = minLng; lng <= maxLng; lng += step) {

      double numerator = 0;
      double denominator = 0;

      for (var s in sensors) {
        // Safe Parse dữ liệu thô từ API
        final locData = s['location'] ?? s['refLocation'];
        List<dynamic>? coords;
        if (locData is Map) {
          if(locData.containsKey('value')) coords = locData['value']['coordinates'];
          else if(locData.containsKey('coordinates')) coords = locData['coordinates'];
        }

        if (coords == null || coords.length < 2) continue;
        double sLat = (coords[1] as num).toDouble();
        double sLng = (coords[0] as num).toDouble();

        // Safe Parse PM2.5
        dynamic rawVal;
        if (s.containsKey('forecastedPM25')) rawVal = s['forecastedPM25'];
        else if (s.containsKey('pm25')) rawVal = s['pm25'];

        double val = 0.0;
        if (rawVal is Map && rawVal.containsKey('value')) rawVal = rawVal['value'];
        if (rawVal is num) val = rawVal.toDouble();
        else if (rawVal is String) val = double.tryParse(rawVal) ?? 0.0;

        // IDW Calculation (Inverse Distance Weighting)
        // Dùng công thức bình phương khoảng cách để không phải khai căn (tốn CPU)
        double d2 = (lat - sLat) * (lat - sLat) + (lng - sLng) * (lng - sLng);

        if (d2 < 0.000001) { numerator = val; denominator = 1; break; } // Trùng vị trí

        double w = 1 / d2;
        numerator += val * w;
        denominator += w;
      }

      double interpolatedPm25 = (denominator != 0) ? (numerator / denominator) : 0;

      // Chỉ trả về điểm có ô nhiễm > 5 để vẽ (tiết kiệm bộ nhớ RAM cho máy)
      if (interpolatedPm25 > 5) {
        results.add({'lat': lat, 'lng': lng, 'pm25': interpolatedPm25});
      }
    }
  }
  return results;
}