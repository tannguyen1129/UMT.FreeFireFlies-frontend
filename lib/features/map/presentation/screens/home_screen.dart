/*
 * Copyright 2025 Green-AQI Navigator Team
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Services
import '../../services/route_planning_service.dart';
import '../../services/green_space_service.dart';
import '../../services/forecast_service.dart';
import '../../services/sensitive_area_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/perception_service.dart';
import '../../../../features/profile/services/profile_service.dart';
import '../../../../features/incidents/services/incident_service.dart';

// Widgets
import '../../../profile/presentation/widgets/health_advice_card.dart';
import 'notification_screen.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // --- Controllers & Services ---
  final MapController _mapController = MapController();
  final TextEditingController _startController = TextEditingController(text: "Vị trí của tôi");
  final TextEditingController _endController = TextEditingController();

  final RoutePlanningService _routeService = RoutePlanningService();
  final GreenSpaceService _greenSpaceService = GreenSpaceService();
  final ForecastService _forecastService = ForecastService();
  final SensitiveAreaService _sensitiveService = SensitiveAreaService();
  final GeocodingService _geocodingService = GeocodingService();
  final PerceptionService _perceptionService = PerceptionService();
  final IncidentService _incidentService = IncidentService();

  // --- State ---
  LatLng? _currentPosition;
  LatLng? _startPoint;
  LatLng? _endPoint;
  double? _distanceKm;

  bool _isSettingStart = true;
  bool _isLoading = false;
  bool _isNavigating = false;

  bool _isPickingLocation = false;

  // Trạng thái các lớp (để tô màu nút khi đang bật)
  bool _layerParks = false;
  bool _layerSensitive = false;
  bool _layerForecast = false;

  String _userHealthGroup = 'normal';
  double _currentMaxPm25 = 0.0;

  StreamSubscription<Position>? _positionStreamSubscription;

  // --- Map Layers ---
  List<Polyline> _polylines = [];
  List<Marker> _parkMarkers = [];
  List<Marker> _sensitiveMarkers = [];
  List<Marker> _incidentMarkers = [];

  // Layer cho AQI (Heatmap + Trạm)
  List<CircleMarker> _forecastCircles = [];
  List<Marker> _aqiMarkers = [];
  List<RemoteMessage> _notifications = [];
  List<Polygon> _hcmcPolygons = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        _determinePosition();
        _fetchForecasts();
        _fetchUserProfile();
        _fetchIncidents();
        _loadKmlPolygon();

        // 🚀 THÊM: Lắng nghe thông báo
        _setupFCMListener();
      }
    });
  }

  // 🚀 HÀM MỚI: Lắng nghe FCM & Tự động Refresh
  void _setupFCMListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        if (mounted) {
          setState(() {
            // 1. Thêm tin nhắn vào danh sách và tăng số đếm
            _notifications.insert(0, message);
            _unreadCount++;
          });

          // 2. Tự động tải lại dữ liệu (Auto-Fetch)
          // Khi có tin báo "Cảnh báo ô nhiễm" hoặc "Sự cố đã duyệt", ta load lại map ngay
          _fetchForecasts();
          _fetchIncidents();

          // 3. Hiện SnackBar nhỏ thông báo
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("🔔 ${message.notification!.title ?? 'Thông báo mới'}"),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.teal,
                duration: const Duration(seconds: 2),
                margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
              )
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _stopNavigation(isDisposing: true);
    _mapController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2), margin: const EdgeInsets.only(bottom: 80, left: 10, right: 10)));
  }
  Color _getAqiColor(double v) => v<=12?Colors.green:v<=35?Colors.yellow:v<=55?Colors.orange:Colors.red;
  String _getAqiLevel(double v) => v<=12?"Tốt":v<=35?"Trung bình":v<=55?"Kém":v<=150?"Xấu":"Nguy hại";

  void _updateDistance() {
    if (_startPoint != null && _endPoint != null) {
      double d = Geolocator.distanceBetween(_startPoint!.latitude, _startPoint!.longitude, _endPoint!.latitude, _endPoint!.longitude);
      setState(() => _distanceKm = d / 1000);
    } else { setState(() => _distanceKm = null); }
  }

  Future<void> _loadKmlPolygon() async {
    try {
      // 1. Đọc file từ assets
      final kmlString = await rootBundle.loadString('assets/kml/HCMC.kml');
      final document = XmlDocument.parse(kmlString);

      final polygons = <Polygon>[];
      final allPoints = <LatLng>[];

      // 2. Tìm tất cả thẻ <Coordinates> hoặc <coordinates>
      final placemarks = document.findAllElements('Placemark');

      for (var placemark in placemarks) {
        final coordinatesNode = placemark.findAllElements('coordinates').firstOrNull;

        if (coordinatesNode != null) {
          final text = coordinatesNode.innerText.trim();
          // KML format: long,lat,alt long,lat,alt ... (cách nhau bởi khoảng trắng hoặc xuống dòng)
          final List<LatLng> points = [];

          final rawPoints = text.split(RegExp(r'\s+'));
          for (var raw in rawPoints) {
            final parts = raw.split(',');
            if (parts.length >= 2) {
              final lng = double.tryParse(parts[0]);
              final lat = double.tryParse(parts[1]);
              if (lng != null && lat != null) {
                final p = LatLng(lat, lng);
                points.add(p);
                allPoints.add(p);
              }
            }
          }

          if (points.isNotEmpty) {
            polygons.add(Polygon(
              points: points,
              color: Colors.blue.withOpacity(0.1), // Màu nền
              borderColor: Colors.blue,            // Màu viền
              borderStrokeWidth: 2,
              isFilled: true,
            ));
          }
        }
      }

      // 3. Cập nhật UI & Tự động Zoom (Fit Bounds)
      if (mounted && polygons.isNotEmpty) {
        setState(() {
          _hcmcPolygons = polygons;
        });

        // Tự động tính khung bao để zoom vừa khít bản đồ
        if (allPoints.isNotEmpty) {
          final bounds = LatLngBounds.fromPoints(allPoints);

          // Fit camera vào bounds (Cần padding để không bị sát lề)
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(20),
            ),
          );
        }
      }
    } catch (e) {
      print("Lỗi đọc KML: $e");
    }
  }

  Future<void> _fetchIncidents() async {
    try {
      // Gọi service lấy danh sách sự cố
      final incidents = await _incidentService.getAllIncidents();
      final markers = <Marker>[];

      for (var inc in incidents) {
        final status = inc['status'] ?? 'pending';

        // Lọc: Chỉ hiện những sự cố chưa giải quyết/từ chối
        if (status == 'resolved' || status == 'rejected') continue;

        final loc = inc['location'];
        if (loc == null || loc['coordinates'] == null) continue;

        // Lấy tọa độ (GeoJSON: [long, lat])
        final lat = (loc['coordinates'][1] as num).toDouble();
        final lng = (loc['coordinates'][0] as num).toDouble();

        // Chọn màu marker theo trạng thái
        Color color = Colors.red; // Mặc định (Pending)
        if (status == 'verified') color = Colors.orange;
        if (status == 'in_progress') color = Colors.blue;

        // Tạo Marker hình tam giác cảnh báo
        markers.add(Marker(
          point: LatLng(lat, lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              // Hiện popup thông tin khi bấm vào
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Row(children: [
                    Icon(Icons.warning, color: color),
                    const SizedBox(width: 10),
                    const Text("Sự cố")
                  ]),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inc['incidentType']?['type_name'] ?? 'Sự cố', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(inc['description'] ?? 'Không có mô tả'),
                      const SizedBox(height: 8),
                      Text("Trạng thái: $status", style: TextStyle(color: color, fontStyle: FontStyle.italic)),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng"))
                  ],
                ),
              );
            },
            child: Icon(Icons.warning_rounded, color: color, size: 35),
          ),
        ));
      }

      // Cập nhật UI
      if (mounted) {
        setState(() {
          _incidentMarkers = markers;
        });
      }
    } catch (e) {
      print("Lỗi tải sự cố: $e");
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final profile = await ProfileService().getMyProfile();
      if (mounted) {
        setState(() {
          _userHealthGroup = profile['health_group'] ?? 'normal';
        });
        final userId = profile['user_id'];
        if (userId != null) {
          await FirebaseMessaging.instance.subscribeToTopic('user_$userId');
        }
      }
    } catch (_) {}
  }

  Future<void> _determinePosition() async {
    if (_isNavigating) return;
    if (mounted) setState(() => _isLoading = true);
    try {
      bool s = await Geolocator.isLocationServiceEnabled(); if(!s) throw 'GPS tắt';
      LocationPermission p = await Geolocator.checkPermission(); if(p==LocationPermission.denied) p=await Geolocator.requestPermission(); if(p==LocationPermission.denied) throw 'Quyền từ chối';
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        if (_startController.text == "Vị trí của tôi") { _startPoint = _currentPosition; _mapController.move(_currentPosition!, 15.0); }
        _updateDistance();
      });
    } catch (e) { _showSnack('$e'); } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<LatLng?> _resolveAddress(String address) async {
    if (address.trim().isEmpty) return null; if (address == "Vị trí của tôi") return _currentPosition;
    return await _geocodingService.getCoordinatesFromAddress(address);
  }

  // ... (Logic Tìm đường) ...
  Future<void> _handleSearchRoute() async {
    FocusScope.of(context).unfocus(); if(mounted) setState(() => _isLoading = true);
    try {
      LatLng? s = await _resolveAddress(_startController.text); if(s==null && _currentPosition==null) await _determinePosition(); s ??= _currentPosition;
      LatLng? e = await _resolveAddress(_endController.text); if(s==null||e==null) throw "Thiếu địa chỉ";
      setState(() { _startPoint = s; _endPoint = e; _updateDistance(); });
      await _fetchAndDrawRoutes(s, e);
      final b = LatLngBounds.fromPoints([s, e]); _mapController.fitCamera(CameraFit.bounds(bounds: b, padding: const EdgeInsets.all(50)));
    } catch(e) { _showSnack('$e'); } finally { if(mounted) setState(() => _isLoading = false); }
  }

  Future<void> _fetchAndDrawRoutes(LatLng s, LatLng e) async {
    try { final json = await _routeService.getRecommendedRoutes(s, e); final List f = json['features']??[]; final List<Polyline> r = [];
    for(var i in f) { final pts = (i['geometry']['coordinates'] as List).map((c)=>LatLng((c[1] as num).toDouble(),(c[0] as num).toDouble())).toList();
    Color col = Colors.grey; double w = 4.0; if(i['properties']['routeType']=='cleanest'){col=Colors.green;w=6.0;} else if(i['properties']['routeType']=='fastest'){col=Colors.blue;}
    r.add(Polyline(points: pts, color: col, strokeWidth: w)); } setState(() => _polylines = r); } catch(_){_showSnack("Không tìm thấy đường");}
  }

  Future<void> _fetchNearbyParks() async {
    if (_currentPosition == null) {
      _showSnack("Chưa có vị trí");
      return;
    }
    setState(() {
      _isLoading = true;
      _parkMarkers = [];
    });
    try {
      final parks = await _greenSpaceService.findNearbyGreenSpaces(_currentPosition!, 3000);
      setState(() {
        _parkMarkers = parks.map((p) {
          // Lấy tọa độ (GeoJSON Polygon -> Lấy điểm đầu tiên làm mốc)
          final c = p['location']['value']['coordinates'][0];
          final pos = LatLng(c[0][1], c[0][0]); // Đảo lat/lng cho đúng

          // Lấy tên
          final name = p['name']?['value'] ?? 'Công viên không tên';

          return Marker(
            point: pos,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                // 🔥 HIỆN INFO KHI BẤM VÀO
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Row(children: [
                      Icon(Icons.park, color: Colors.green),
                      SizedBox(width: 10),
                      Text("Không gian xanh", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                    ]),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 10),
                        const Text("Đây là khu vực cây xanh giúp giảm thiểu ô nhiễm và tốt cho sức khỏe.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
                      // Nút Đi đến đây
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleMapTap(pos); // Chọn làm điểm đến
                        },
                        icon: const Icon(Icons.directions),
                        label: const Text("Đi đến đây"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      )
                    ],
                  ),
                );
              },
              child: const Icon(Icons.park, color: Colors.green, size: 35),
            ),
          );
        }).toList();
        _layerParks = true;
      });
      _showSnack('Đã tải ${parks.length} công viên');
    } catch (e) {
      _showSnack('Lỗi tải công viên');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSensitiveAreas() async {
    if (_currentPosition == null) {
      _showSnack("Chưa có vị trí");
      return;
    }
    setState(() {
      _isLoading = true;
      _sensitiveMarkers = [];
    });
    try {
      final areas = await _sensitiveService.findNearbySensitiveAreas(_currentPosition!, 3000);
      setState(() {
        _sensitiveMarkers = areas.map((a) {
          final c = a['location']['value']['coordinates'][0];
          final pos = LatLng(c[0][1], c[0][0]);

          final name = a['name']?['value'] ?? 'Địa điểm không tên';
          final cat = a['category']['value'];

          // Config Icon & Màu & Tiêu đề theo loại
          IconData icon = Icons.place;
          Color color = Colors.grey;
          String typeName = "Khu vực";

          if (cat == 'school' || cat == 'kindergarten') {
            icon = Icons.school;
            color = Colors.blue;
            typeName = "Trường học";
          } else if (cat == 'hospital') {
            icon = Icons.local_hospital;
            color = Colors.redAccent;
            typeName = "Bệnh viện/Y tế";
          } else if (cat == 'police') {
            icon = Icons.local_police;
            color = Colors.indigo;
            typeName = "Công an";
          } else if (cat == 'military') {
            icon = Icons.shield;
            color = Colors.brown;
            typeName = "Quân sự";
          }

          return Marker(
            point: pos,
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () {
                // 🔥 HIỆN INFO KHI BẤM VÀO
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Row(children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 10),
                      Text(typeName, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold))
                    ]),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(cat.toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _handleMapTap(pos); // Chọn làm điểm đến
                        },
                        icon: const Icon(Icons.directions),
                        label: const Text("Đi đến đây"),
                        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                      )
                    ],
                  ),
                );
              },
              child: Icon(icon, color: color, size: 30),
            ),
          );
        }).toList();
        _layerSensitive = true;
      });
      _showSnack('Đã tải ${areas.length} khu vực');
    } catch (e) {
      _showSnack('Lỗi tải khu vực nhạy cảm');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startNavigation() { if(_currentPosition==null)return; setState(() => _isNavigating = true); _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5)).listen((p){ final np = LatLng(p.latitude, p.longitude); if(mounted){ setState(()=>_currentPosition=np); _mapController.move(np, 18.0); } }); _showSnack('Bắt đầu dẫn đường!'); }

  // ---------------------------------------------------------------------------
  // <--- CẬP NHẬT: LOGIC GAMIFICATION + DỪNG DẪN ĐƯỜNG
  // ---------------------------------------------------------------------------
  void _stopNavigation({bool isDisposing = false}) {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;

    if (!isDisposing && mounted) {
      setState(() => _isNavigating = false);

      // 🚀 LOGIC GAMIFICATION: TÍNH ĐIỂM
      if (_distanceKm != null && _distanceKm! > 0) {
        final int pointsEarned = (_distanceKm! * 10).round(); // 1km = 10 điểm

        if (pointsEarned > 0) {
          // Gọi API cộng điểm (Lưu ý: Đảm bảo ProfileService có hàm addPoints)
          ProfileService().addPoints(pointsEarned);

          // Hiện Dialog Chúc mừng
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.green.shade50,
              title: const Row(children: [Icon(Icons.emoji_events, color: Colors.orange), SizedBox(width: 10), Text("Chuyến đi hoàn tất!")]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Bạn vừa đóng góp vào việc giảm thiểu khí thải và bảo vệ sức khỏe.", textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Text("+$pointsEarned Điểm Xanh", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 10),
                  const Icon(Icons.eco, size: 60, color: Colors.green),
                ],
              ),
              actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Tuyệt vời!"))],
            ),
          );
        }
      }

      if (_currentPosition != null) _mapController.move(_currentPosition!, 15.0);
    }
  }
  // ---------------------------------------------------------------------------
  void _activatePickMode() {
    setState(() {
      _isPickingLocation = true;
    });
    _showSnack("Chạm vào bản đồ để chọn điểm đến 📍");
  }

  void _handleMapTap(LatLng p) {
    if (_isNavigating) return;

    // Nếu ĐANG ở chế độ chọn điểm -> Thì mới nhận tọa độ
    if (_isPickingLocation) {
      setState(() {
        if (!_isSettingStart) {
          _endPoint = p;
          _endController.text = "${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}";
          _isSettingStart = true;
        } else {
          // Mặc định là chọn điểm đến
          _endPoint = p;
          _endController.text = "${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}";
        }
        _updateDistance();

        // 🚀 Tự động TẮT chế độ chọn sau khi chọn xong (để tránh bấm nhầm lần sau)
        _isPickingLocation = false;
      });
      _showSnack("Đã chọn điểm đến ✅");
    } else {
      // Nếu KHÔNG ở chế độ chọn -> Không làm gì cả (để người dùng trượt map thoải mái)
      // Hoặc có thể dùng để đóng các popup đang mở
      // print("Tap map ignored (Pick mode off)");
    }
  }

  void _clearMap() {
    setState(() {
      _polylines = []; _parkMarkers = []; _sensitiveMarkers = []; _incidentMarkers = [];
      _startPoint = null; _endPoint = null; _distanceKm = null;
      _startController.text = "Vị trí của tôi"; _endController.clear();
      _isNavigating = false; _positionStreamSubscription?.cancel();
      if (_currentPosition != null) _mapController.move(_currentPosition!, 15.0);
      _layerParks = false; _layerSensitive = false;
      _isPickingLocation = false; // Reset luôn chế độ chọn
    });
    _fetchIncidents();
    _showSnack('Đã làm mới bản đồ');
  }

  // ... (Logic Nội suy IDW) ...
  List<CircleMarker> _generateInterpolatedHeatmap(List<dynamic> sensors) {
    final List<CircleMarker> heatmapPoints = [];
    const double minLat = 10.35; const double maxLat = 11.10;
    const double minLng = 106.30; const double maxLng = 107.00;
    const double step = 0.015;

    for (double lat = minLat; lat <= maxLat; lat += step) {
      for (double lng = minLng; lng <= maxLng; lng += step) {
        double interpolatedPm25 = _calculateIdw(lat, lng, sensors);
        if (interpolatedPm25 > 0) {
          final color = _getAqiColor(interpolatedPm25);
          heatmapPoints.add(CircleMarker(
            point: LatLng(lat, lng),
            radius: 1500, useRadiusInMeter: true,
            color: color.withOpacity(0.15), borderColor: Colors.transparent, borderStrokeWidth: 0,
          ));
        }
      }
    }
    return heatmapPoints;
  }

  double _calculateIdw(double lat, double lng, List<dynamic> sensors) {
    double num = 0; double den = 0;
    for (var s in sensors) {
      final loc = s['location']['value']['coordinates'];
      final val = (s['forecastedPM25']?['value'] ?? 0.0).toDouble();
      double d = (lat - loc[1]) * (lat - loc[1]) + (lng - loc[0]) * (lng - loc[0]);
      if (d == 0) return val;
      double w = 1 / d; num += val * w; den += w;
    }
    return (den != 0) ? (num / den) : 0;
  }

  // ... (Tải dự báo) ...
  Future<void> _fetchForecasts() async {
    if (mounted) setState(() { _isLoading = true; });
    try {
      final List<dynamic> forecasts = await _forecastService.getAqiForecasts();

      if (forecasts.isEmpty) return;

      final circles = <CircleMarker>[];
      final markers = <Marker>[];

      // 🚀 KHAI BÁO BIẾN maxPm TẠI ĐÂY
      double maxPm = 0.0;

      // 1. Tạo Heatmap nội suy
      circles.addAll(_generateInterpolatedHeatmap(forecasts));

      // 2. Tạo Marker
      for (var f in forecasts) {
        // --- XỬ LÝ PM2.5 ---
        dynamic pm25Data;
        for (var key in f.keys) {
          if (key.toString().contains('forecastedPM25')) {
            pm25Data = f[key];
            break;
          }
        }
        final pm25 = (pm25Data?['value'] ?? 0.0).toDouble();

        // 🚀 CẬP NHẬT GIÁ TRỊ MAX
        if (pm25 > maxPm) maxPm = pm25;

        // --- XỬ LÝ LOCATION ---
        dynamic locData;
        for (var key in f.keys) {
          if (key.toString().contains('location')) {
            locData = f[key];
            break;
          }
        }
        final loc = locData?['value']?['coordinates'];
        if (loc == null) continue;

        // --- XỬ LÝ THỜI GIAN (FIX DỨT ĐIỂM) ---
        // Thay vì parse từ server, ta lấy giờ hiện tại + 15 phút
        // Vì đây là dự báo Real-time cho tương lai gần
        final now = DateTime.now();
        final forecastTime = now.add(const Duration(minutes: 15));

        String hour = forecastTime.hour.toString().padLeft(2, '0');
        String minute = forecastTime.minute.toString().padLeft(2, '0');
        String displayTime = "$hour:$minute"; // Ví dụ: 10:30

        // --- XỬ LÝ TÊN TRẠM ---
        final rawId = f['id'] ?? '';
        final stationName = rawId.split(':').last.replaceAll('OWM-', '');
        final pos = LatLng(loc[1], loc[0]);
        final color = _getAqiColor(pm25);

        // Vẽ vòng tròn đậm
        circles.add(CircleMarker(
            point: pos, radius: 2000, useRadiusInMeter: true,
            color: color.withOpacity(0.5), borderColor: color, borderStrokeWidth: 2
        ));

        // Vẽ Marker đám mây
        markers.add(Marker(
          point: pos, width: 40, height: 40,
          child: GestureDetector(
            onTap: () {
              showDialog(context: context, builder: (ctx) => AlertDialog(
                title: Row(children: [
                  Icon(Icons.wb_cloudy, color: color),
                  const SizedBox(width: 10),
                  const Text("Dự báo AI (ST-GNN)", style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold))
                ]),
                content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Khu vực: $stationName", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("PM2.5:", style: TextStyle(fontSize: 16)),
                      Text("${pm25.toStringAsFixed(1)} µg/m³", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(children: [const Text("Mức độ: "), Text(_getAqiLevel(pm25), style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.blue),
                      const SizedBox(width: 5),
                      Text("Dự báo cho lúc: $displayTime", style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ]),
                actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Đóng"))],
              ));
            },
            child: Icon(Icons.cloud, color: color.withOpacity(1.0), size: 30),
          ),
        ));
      }

      if(mounted) setState(() {
        _forecastCircles = circles;
        _aqiMarkers = markers;
        _layerForecast = true;
        _currentMaxPm25 = maxPm; // 🚀 CẬP NHẬT BIẾN STATE
      });

    } catch(e) {
      print("Lỗi fetch forecast: $e");
    } finally {
      if(mounted) setState(() { _isLoading = false; });
    }
  }

  // ... (Cảm nhận) ...
  void _showPerceptionDialog() {
    if (_currentPosition == null) { _showSnack('Đang lấy vị trí...'); return; }
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Row(children: [Icon(Icons.emoji_emotions, color: Colors.teal), SizedBox(width: 10), Text('Cảm nhận không khí?')]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildF(ctx, 1, 'Trong lành', Colors.green, Icons.sentiment_very_satisfied),
        _buildF(ctx, 2, 'Bình thường', Colors.yellow.shade800, Icons.sentiment_neutral),
        _buildF(ctx, 3, 'Kém', Colors.orange, Icons.sentiment_dissatisfied),
        _buildF(ctx, 4, 'Ô nhiễm', Colors.red, Icons.masks),
      ]),
    ));
  }
  Widget _buildF(BuildContext ctx, int l, String t, Color c, IconData i) {
    return ListTile(leading: Icon(i, color: c, size: 30), title: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold)), onTap: () { Navigator.of(ctx).pop(); _submitPerception(l); });
  }
  Future<void> _submitPerception(int level) async {
    if (_currentPosition == null) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _isLoading = true);
    try {
      await _perceptionService.submitPerception(location: _currentPosition!, feeling: level);
      _showSnack('Cảm ơn đóng góp của bạn!');
    } catch (e) { _showSnack('Lỗi: $e'); } finally { if (mounted) setState(() => _isLoading = false); }
  }

  // --- Các hàm Toggle Layer khác ---
  Future<void> _toggleParks() async {
    if (_layerParks) { setState(() { _parkMarkers = []; _layerParks = false; }); }
    else {
      if(_currentPosition == null) { _showSnack("Chưa có vị trí"); return; }
      setState(() => _isLoading = true);
      try {
        final parks = await _greenSpaceService.findNearbyGreenSpaces(_currentPosition!, 3000);
        setState(() {
          _parkMarkers = parks.map((p) {
            final c = p['location']['value']['coordinates'][0];
            return Marker(point: LatLng(c[0][1], c[0][0]), child: const Icon(Icons.park, color: Colors.green, size: 30));
          }).toList();
          _layerParks = true;
        });
        _showSnack('Đã hiện ${parks.length} công viên');
      } catch(_) { _showSnack('Lỗi tải công viên'); } finally { if(mounted) setState(() => _isLoading = false); }
    }
  }

  Future<void> _toggleSensitive() async {
    if (_layerSensitive) { setState(() { _sensitiveMarkers = []; _layerSensitive = false; }); }
    else {
      if(_currentPosition == null) { _showSnack("Chưa có vị trí"); return; }
      setState(() => _isLoading = true);
      try {
        final areas = await _sensitiveService.findNearbySensitiveAreas(_currentPosition!, 3000);
        setState(() {
          _sensitiveMarkers = areas.map((a) {
            final c = a['location']['value']['coordinates'][0];
            final cat = a['category']['value'];
            IconData i = Icons.place; Color cl = Colors.grey;
            if(cat=='school'){i=Icons.school;cl=Colors.blue;} else if(cat=='hospital'){i=Icons.local_hospital;cl=Colors.red;}
            else if(cat=='police'){i=Icons.local_police;cl=Colors.indigo;} else if(cat=='military'){i=Icons.shield;cl=Colors.brown;}
            return Marker(point: LatLng(c[0][1], c[0][0]), child: Icon(i, color: cl, size: 30));
          }).toList();
          _layerSensitive = true;
        });
        _showSnack('Đã hiện ${areas.length} khu vực');
      } catch(_) { _showSnack('Lỗi tải KV nhạy cảm'); } finally { if(mounted) setState(() => _isLoading = false); }
    }
  }

  // ===============================================================
  // 🖥️ GIAO DIỆN (UI)
  // ===============================================================
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final allMarkers = <Marker>[];
    if (_currentPosition != null) {
      allMarkers.add(Marker(
        point: _currentPosition!,
        child: _isNavigating
            ? const Icon(Icons.navigation, color: Colors.blue, size: 40.0)
            : const Icon(Icons.my_location, color: Colors.blue, size: 30.0),
      ));
    }
    if (_startPoint != null && _startPoint != _currentPosition) allMarkers.add(Marker(point: _startPoint!, width: 80, height: 80, child: const Column(children: [Icon(Icons.trip_origin, color: Colors.green, size: 35), Text("Bắt đầu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))])));
    if (_endPoint != null) allMarkers.add(Marker(point: _endPoint!, width: 80, height: 80, child: const Column(children: [Icon(Icons.location_on, color: Colors.red, size: 35), Text("Đến", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))])));

    allMarkers.addAll(_parkMarkers);
    allMarkers.addAll(_sensitiveMarkers);
    if (_layerForecast) allMarkers.addAll(_aqiMarkers);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. BẢN ĐỒ
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(10.7769, 106.7009),
              initialZoom: 14.0,
              onTap: (_, point) => _handleMapTap(point),
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.frontend_citizen',
              ),

              PolygonLayer(polygons: _hcmcPolygons),

              if (_layerForecast) CircleLayer(circles: _forecastCircles),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: allMarkers),
            ],
          ),

          // 2. THANH TÌM KIẾM (NỔI) + CHUÔNG
          if (!_isNavigating)
            Positioned(
              top: 50, left: 16, right: 16,
              child: Column(
                children: [
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        // Hàng chứa: Các ô Input (Trái) + Nút Chuông (Phải)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Phần Input (Chiếm phần lớn diện tích)
                            Expanded(
                              child: Column(
                                children: [
                                  // Ô Điểm đi
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                    leading: const Icon(Icons.my_location, color: Colors.green, size: 20),
                                    title: TextField(
                                      controller: _startController,
                                      decoration: const InputDecoration(hintText: "Chọn điểm đi", border: InputBorder.none, isDense: true),
                                      style: const TextStyle(fontSize: 14),
                                      onTap: () => setState(() => _isSettingStart = true),
                                    ),
                                    trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _startController.text = "Vị trí của tôi"),
                                    dense: true,
                                  ),
                                  const Divider(height: 1, indent: 16, endIndent: 16),
                                  // Ô Điểm đến
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                    leading: const Icon(Icons.location_on, color: Colors.red, size: 20),
                                    title: TextField(
                                      controller: _endController,
                                      decoration: const InputDecoration(hintText: "Nhập điểm đến...", border: InputBorder.none, isDense: true),
                                      style: const TextStyle(fontSize: 14),
                                      onTap: () => setState(() => _isSettingStart = false),
                                      onSubmitted: (_) => _handleSearchRoute(),
                                    ),
                                    trailing: IconButton(icon: const Icon(Icons.search, color: Colors.blue), onPressed: _handleSearchRoute),
                                    dense: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // (Giữ nguyên phần hiển thị khoảng cách và thẻ sức khỏe bên dưới Card)
                  if (_distanceKm != null)
                    Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                        child: Text("${_distanceKm!.toStringAsFixed(2)} km", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                    ),

                  if (_layerForecast && _currentMaxPm25 > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: HealthAdviceCard(pm25: _currentMaxPm25, userHealthGroup: _userHealthGroup),
                    ),
                ],
              ),
            ),

          // 3. CÁC NÚT CHỨC NĂNG
          Positioned(
            bottom: 100,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🚀 NÚT ZOOM IN (+)
                _buildCircleBtn(Icons.add, () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, currentZoom + 1);
                }, color: Colors.white),
                const SizedBox(height: 10),

                // 🚀 NÚT ZOOM OUT (-)
                _buildCircleBtn(Icons.remove, () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(_mapController.camera.center, currentZoom - 1);
                }, color: Colors.white),
                const SizedBox(height: 10),

                // --- CÁC NÚT CŨ ---
                _buildCircleBtn(Icons.refresh, () => _clearMap(), color: Colors.white),
                const SizedBox(height: 10),

                _buildCircleBtn(Icons.gps_fixed, () => _determinePosition(), color: Colors.white, iconColor: Colors.blue),
                const SizedBox(height: 10),

                // NÚT CẮM MỐC
                _buildCircleBtn(
                    _isPickingLocation ? Icons.location_off : Icons.add_location_alt,
                        () => _activatePickMode(),
                    color: _isPickingLocation ? Colors.orange : Colors.white,
                    iconColor: _isPickingLocation ? Colors.white : Colors.black87
                ),
              ],
            ),
          ),

          // 4. BOTTOM SHEET
          if (!_isNavigating)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip("Công viên", Icons.park, Colors.green, _layerParks, _toggleParks),
                    const SizedBox(width: 8),
                    _buildFilterChip("Y tế/Giáo dục", Icons.local_hospital, Colors.redAccent, _layerSensitive, _toggleSensitive),
                    const SizedBox(width: 8),
                    _buildFilterChip("Cảm nhận", Icons.emoji_emotions, Colors.teal, false, _showPerceptionDialog),
                    const SizedBox(width: 8),
                    _buildFilterChip("Dự báo AQI", Icons.cloud, Colors.orange, _layerForecast, _fetchForecasts),
                  ],
                ),
              ),
            ),

          // 5. NÚT DẪN ĐƯỜNG
          if (_polylines.isNotEmpty && !_isNavigating)
            Positioned(bottom: 80, left: 16, right: 16, child: SizedBox(height: 50, child: ElevatedButton.icon(onPressed: _startNavigation, icon: const Icon(Icons.directions), label: const Text("BẮT ĐẦU ĐI (TUYẾN ĐƯỜNG XANH)"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white)))),

          if (_isNavigating)
            Positioned(bottom: 30, left: 16, right: 16, child: Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text("Đang dẫn đường...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text("Đi theo tuyến đường xanh lá", style: TextStyle(color: Colors.grey, fontSize: 12))]), const Spacer(), ElevatedButton.icon(onPressed: () => _stopNavigation(), icon: const Icon(Icons.stop), label: const Text("Dừng"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white))])))),

          if (_isLoading) Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, VoidCallback onTap, {Color color = Colors.white, Color iconColor = Colors.black87}) {
    return Material(elevation: 4, shape: const CircleBorder(), color: color, child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(12.0), child: Icon(icon, color: iconColor, size: 24))));
  }

  Widget _buildFilterChip(String label, IconData icon, Color color, bool isActive, VoidCallback onTap) {
    return FilterChip(
      label: Row(children: [Icon(icon, size: 18, color: isActive ? Colors.white : color), const SizedBox(width: 6), Text(label)]),
      selected: isActive,
      onSelected: (_) => onTap(),
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black87, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
      backgroundColor: Colors.white,
      elevation: 2,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildLegendItem(Color color, String text) { return Container(); }
}