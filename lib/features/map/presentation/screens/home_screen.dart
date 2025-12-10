/*
 * Copyright 2025 Green-AQI Navigator Team
 * Apache License 2.0
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';

// Import logic nặng
import '../../utils/map_heavy_tasks.dart';

// Import Auth Provider
import '../../../auth/presentation/providers/auth_state_provider.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Controllers
  final MapController _mapController = MapController();
  final TextEditingController _startController = TextEditingController(text: "Vị trí của tôi");
  final TextEditingController _endController = TextEditingController();

  // Services
  final _routeService = RoutePlanningService();
  final _greenSpaceService = GreenSpaceService();
  final _forecastService = ForecastService();
  final _sensitiveService = SensitiveAreaService();
  final _geocodingService = GeocodingService();
  final _perceptionService = PerceptionService();
  final _incidentService = IncidentService();
  // Dữ liệu đường bao vùng biển chủ quyền (Mô phỏng)
  final List<Marker> _sovereigntyMarkers = [
    Marker(
      point: const LatLng(16.5, 112.0), // Tọa độ Hoàng Sa
      width: 160, height: 60,
      child: Column(children: [
        const Icon(Icons.flag, color: Colors.red, size: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(4)),
          child: const Text("HOÀNG SA (VIỆT NAM)", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
        )
      ]),
    ),
    Marker(
      point: const LatLng(9.0, 113.0), // Tọa độ Trường Sa (Chỉnh lại xíu cho dễ nhìn)
      width: 160, height: 60,
      child: Column(children: [
        const Icon(Icons.flag, color: Colors.red, size: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(4)),
          child: const Text("TRƯỜNG SA (VIỆT NAM)", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red)),
        )
      ]),
    ),
  ];

  // Data
  LatLng? _currentPosition;
  LatLng? _startPoint;
  LatLng? _endPoint;
  double? _distanceKm;
  String _userHealthGroup = 'normal';
  double _currentMaxPm25 = 0.0;

  // UI State
  bool _isLoading = false;
  bool _isMapLoading = true;
  bool _isNavigating = false;
  bool _isPickingLocation = false;
  bool _isSettingStart = true;

  // Layers
  bool _layerParks = false;
  bool _layerSensitive = false;
  bool _layerForecast = false;

  // Markers
  List<Polyline> _polylines = [];
  List<Marker> _parkMarkers = [];
  List<Marker> _sensitiveMarkers = [];
  List<Marker> _incidentMarkers = [];
  List<CircleMarker> _forecastCircles = [];
  List<Marker> _aqiMarkers = [];
  List<Polygon> _hcmcPolygons = [];

  StreamSubscription<Position>? _positionStreamSubscription;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
      _startAutoRefresh();
    });
  }

  void _startAutoRefresh() {
    // Hủy timer cũ nếu có
    _refreshTimer?.cancel();

    // Tạo timer mới: Cứ 30 giây gọi API 1 lần
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _checkAuth() && !_isNavigating) {
        print("🔄 Auto-refreshing data...");
        // Gọi thầm lặng (không hiện loading) để trải nghiệm mượt
        _fetchForecasts();
        _fetchIncidents();
      }
    });
  }

  /// 🛡️ INIT DATA AN TOÀN
  Future<void> _initializeData() async {
    if (!mounted) return;
    if (!_checkAuth()) return;

    // 1. Lấy vị trí
    await _determinePosition();

    // 2. Load KML (Chạy ngầm)
    if (_checkAuth()) _loadKmlPolygon();

    // 3. Load dữ liệu nhẹ
    if (_checkAuth()) {
      _fetchUserProfile();
      _fetchIncidents();
    }

    // 4. Load AQI (Nặng) - Delay để UI mượt
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted && _checkAuth()) {
      _fetchForecasts();
    }

    _setupFCMListener();
  }

  bool _checkAuth() {
    if (!mounted) return false;
    return Provider.of<AuthStateProvider>(context, listen: false).isAuthenticated;
  }

  void _setupFCMListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("🔔 ${message.notification!.title}"), backgroundColor: Colors.teal, duration: const Duration(seconds: 2))
        );
        if (_checkAuth()) _fetchIncidents();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _stopNavigation(isDisposing: true);
    _mapController.dispose();
    _startController.dispose();
    _endController.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // ===============================================================
  // 🔇 HÀM FETCH ĐÃ ĐƯỢC BỊT MIỆNG LỖI 401 (SILENT CATCH)
  // ===============================================================

  Future<void> _loadKmlPolygon() async {
    try {
      final kmlString = await rootBundle.loadString('assets/kml/HCMC.kml');
      final rawPolygons = await compute(parseKmlInBackground, kmlString);

      final polygons = rawPolygons.map((points) => Polygon(
        points: points,
        color: Colors.blue.withOpacity(0.05),
        borderColor: Colors.blue,
        borderStrokeWidth: 1.5,
        isFilled: true,
      )).toList();

      if (mounted) {
        setState(() {
          _hcmcPolygons = polygons;
          _isMapLoading = false;
        });
        if (_currentPosition == null) _mapController.move(const LatLng(10.7769, 106.7009), 12.0);
      }
    } catch (e) {
      if(mounted) setState(() => _isMapLoading = false);
    }
  }

  Future<void> _fetchForecasts() async {
    // 1. Kiểm tra quyền
    if (!_checkAuth()) return;

    try {
      final List<dynamic> forecasts = await _forecastService.getAqiForecasts();
      if (forecasts.isEmpty) return;

      // 2. Tính toán Heatmap (Chạy ngầm để không lag máy)
      final heatmapData = await compute(computeHeatmapData, forecasts);

      final circles = heatmapData.map((data) {
        final color = _getAqiColor(data['pm25']);
        return CircleMarker(
          point: LatLng(data['lat'], data['lng']),
          radius: 2000, useRadiusInMeter: true,
          color: color.withOpacity(0.15),
          borderColor: Colors.transparent, borderStrokeWidth: 0,
        );
      }).toList();

      final markers = <Marker>[];
      double maxPm = 0.0;

      // 3. Xử lý từng trạm đo
      for (var f in forecasts) {
        // --- A. LẤY PM2.5 ---
        // Tìm key chứa chữ 'PM25' bất kể hoa thường
        dynamic pm25Val;
        f.forEach((k, v) {
          if (k.toString().toLowerCase().contains('pm25')) {
            pm25Val = v;
          }
        });

        // Đào sâu lấy giá trị số
        double pm25 = 0.0;
        if (pm25Val is Map) {
          dynamic inner = pm25Val['value'];
          if (inner is Map && inner.containsKey('@value')) inner = inner['@value']; // Fix lỗi lồng nhau
          pm25Val = inner;
        }
        if (pm25Val is num) pm25 = pm25Val.toDouble();
        else if (pm25Val is String) pm25 = double.tryParse(pm25Val) ?? 0.0;

        if (pm25 > maxPm) maxPm = pm25;

        // --- B. LẤY TỌA ĐỘ ---
        dynamic locData;
        f.forEach((k, v) {
          if (k.toString().toLowerCase().contains('location')) locData = v;
        });

        List<dynamic>? coords;
        if (locData is Map) {
          if(locData.containsKey('value')) {
            dynamic val = locData['value'];
            if(val is Map && val.containsKey('coordinates')) coords = val['coordinates'];
            // Trường hợp cấu trúc phẳng
            else if (val is Map && val.containsKey('@value')) { /* Xử lý nếu cần */ }
            else if (val is Map && val['type'] == 'Point') coords = val['coordinates'];
          }
        }

        if (coords == null || coords.length < 2) continue;

        final pos = LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
        final color = _getAqiColor(pm25);

        // --- C. LẤY TÊN TRẠM ---
        final rawId = f['id'] ?? 'Trạm';
        final stationName = rawId.toString().split(':').last.replaceAll('OWM-', '');

        // --- D. LẤY THỜI GIAN (QUAN TRỌNG: FIX LỖI 28/11) ---
        // 3. XỬ LÝ THỜI GIAN (FIX: BẮT BUỘC LẤY VALIDFROM + CHUYỂN MÚI GIỜ)
        String timeStr = "Đang cập nhật";
        try {
          dynamic targetTimeValue;

          // 🔍 BƯỚC 1: Tìm chính xác key chứa 'validFrom' (Dự báo tương lai)
          // Chúng ta Loop để tìm, thấy là BREAK ngay lập tức.
          for (var key in f.keys) {
            if (key.toString().contains('validFrom')) {
              targetTimeValue = f[key];
              break; // 🛑 QUAN TRỌNG: Tìm thấy validFrom là dừng, không đi tiếp!
            }
          }

          // Fallback: Nếu (rất xui) không có validFrom thì mới lấy observationDateTime
          if (targetTimeValue == null) {
            for (var key in f.keys) {
              if (key.toString().contains('observationDateTime')) {
                targetTimeValue = f[key];
                break;
              }
            }
          }

          // Đào sâu lấy value (xử lý cấu trúc NGSI-LD: value -> @value)
          if (targetTimeValue is Map) {
            if (targetTimeValue.containsKey('value')) targetTimeValue = targetTimeValue['value'];
          }
          if (targetTimeValue is Map) {
            if (targetTimeValue.containsKey('@value')) targetTimeValue = targetTimeValue['@value'];
          }

          if (targetTimeValue != null) {
            String ts = targetTimeValue.toString();

            // 🔍 BƯỚC 2: Xử lý Múi giờ chuẩn xác (UTC -> Local)
            // Backend Python trả về chuỗi ISO (ví dụ: "2025-12-10T04:30:00") thường là UTC nhưng thiếu chữ 'Z'.
            // DateTime.parse() của Flutter sẽ mặc định hiểu nhầm đây là giờ Local.
            // 👉 Ta phải ép nó hiểu đây là UTC trước.

            DateTime utcDate;
            try {
              DateTime temp = DateTime.parse(ts);
              if (!ts.endsWith('Z')) {
                // Tái tạo lại object nhưng gắn mác là UTC
                utcDate = DateTime.utc(
                    temp.year, temp.month, temp.day,
                    temp.hour, temp.minute, temp.second
                );
              } else {
                utcDate = temp.toUtc();
              }
            } catch (_) {
              utcDate = DateTime.now().toUtc(); // Fallback an toàn
            }

            // 👉 Chuyển sang giờ Việt Nam (Local Device Time)
            // Lúc này nó sẽ tự động cộng 7 tiếng (Ví dụ: 04:30 UTC -> 11:30 VN)
            final vnDate = utcDate.toLocal();

            // Format đẹp: 11:30 10/12
            timeStr = "${vnDate.hour.toString().padLeft(2, '0')}:${vnDate.minute.toString().padLeft(2, '0')} ${vnDate.day}/${vnDate.month}";
          }
        } catch (e) {
          print("Lỗi parse time: $e");
        }

        markers.add(Marker(
          point: pos, width: 45, height: 45,
          child: GestureDetector(
            // Truyền timeStr vào popup
            onTap: () => _showStationInfo(stationName, pm25, color, timeStr),
            child: Icon(Icons.cloud, color: color, size: 35),
          ),
        ));
      }

      if (mounted) {
        setState(() {
          _forecastCircles = circles;
          _aqiMarkers = markers;
          _layerForecast = true;
          _currentMaxPm25 = maxPm;
        });
      }
    } catch (e) {
      // Bỏ qua lỗi 401/403 để log sạch
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) return;
      print("Lỗi Forecast: $e");
    }
  }

  Future<void> _fetchIncidents() async {
    // Auth Guard: Chưa đăng nhập thì chặn luôn
    if (!_checkAuth()) return;

    try {
      final incidents = await _incidentService.getAllIncidents();

      if(!mounted) return;

      final markers = <Marker>[];
      for(var inc in incidents) {
        final status = inc['status'] ?? 'pending';
        // Lọc bớt status đã xong hoặc từ chối
        if (status == 'resolved' || status == 'rejected') continue;

        final loc = inc['location'];
        if(loc == null || loc['coordinates'] == null) continue;

        final lat = (loc['coordinates'][1] as num).toDouble();
        final lng = (loc['coordinates'][0] as num).toDouble();

        Color color = Colors.red; // Mặc định đỏ (nguy hiểm)
        if(status == 'verified') color = Colors.orange; // Đã xác minh thì cam

        markers.add(Marker(
            point: LatLng(lat, lng),
            width: 35,
            height: 35,
            child: GestureDetector(
                onTap: (){
                  showDialog(context: context, builder: (ctx)=>AlertDialog(
                      title: const Text("Sự cố môi trường"),
                      content: Text(inc['description'] ?? 'Không có mô tả'),
                      actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Đóng"))]
                  ));
                },
                child: Icon(Icons.warning_rounded, color: color, size: 30)
            )
        ));
      }

      setState(() => _incidentMarkers = markers);

    } on DioException catch (e) {
      // 🔇 IM LẶNG: Nếu là 403 (Không quyền) hoặc 401 (Hết hạn) thì bỏ qua
      // ApiClient lo logout 401 rồi, còn 403 thì coi như user không xem được sự cố.
      if (e.response?.statusCode == 403 || e.response?.statusCode == 401) return;

      // Chỉ in log nếu là lỗi khác (ví dụ 500 Server Error)
      // print("⚠️ Lỗi tải sự cố: ${e.message}");
    } catch (_) {
      // Bắt các lỗi linh tinh khác mà không làm crash app
    }
  }

  Future<void> _fetchUserProfile() async {
    if (!_checkAuth()) return;
    try {
      final p = await ProfileService().getMyProfile();
      if(mounted) setState(() => _userHealthGroup = p['health_group'] ?? 'normal');
    } catch(e) {
      // 🔇 IM LẶNG
      if (e is DioException && (e.response?.statusCode == 401)) return;
    }
  }

  // --- CÁC HÀM KHÁC (GIỮ NGUYÊN) ---

  Future<void> _determinePosition() async {
    try {
      bool s = await Geolocator.isLocationServiceEnabled();
      if(!s) return;
      LocationPermission p = await Geolocator.checkPermission();
      if(p==LocationPermission.denied) p=await Geolocator.requestPermission();
      if(p==LocationPermission.denied || p==LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition();
      if(mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          if(_startController.text == "Vị trí của tôi") {
            _startPoint = _currentPosition;
            _mapController.move(_currentPosition!, 14.0);
          }
          _updateDistance();
        });
      }
    } catch(_){}
  }

  Future<void> _handleSearchRoute() async {
    FocusScope.of(context).unfocus();
    if(mounted) setState(() => _isLoading = true);
    try {
      LatLng? s = _startController.text == "Vị trí của tôi" ? _currentPosition : await _geocodingService.getCoordinatesFromAddress(_startController.text);
      if(s == null) { await _determinePosition(); s = _currentPosition; }
      if(s == null) throw "Thiếu điểm đi";

      LatLng? e = await _geocodingService.getCoordinatesFromAddress(_endController.text);
      if(e == null) throw "Thiếu điểm đến";

      setState(() { _startPoint = s; _endPoint = e; });

      final json = await _routeService.getRecommendedRoutes(s, e);
      final List features = json['features'] ?? [];
      final List<Polyline> lines = [];
      double totalDistance = 0.0;

      for(var f in features) {
        final coords = f['geometry']['coordinates'] as List;
        final pts = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        final type = f['properties']['routeType'];

        // Tính tổng khoảng cách của tuyến đường chính (cleanest hoặc fastest)
        if (totalDistance == 0.0) {
          // Sử dụng hàm tính khoảng cách đường gấp khúc
          const Distance distance = Distance();
          for (int i = 0; i < pts.length - 1; i++) {
            totalDistance += distance.as(LengthUnit.Meter, pts[i], pts[i+1]);
          }
        }

        lines.add(Polyline(
            points: pts,
            color: type=='cleanest'?Colors.green:Colors.blue,
            strokeWidth: type=='cleanest'? 6.0 : 4.0
        ));
      }

      setState(() {
        _polylines = lines;
        _distanceKm = totalDistance / 1000; // Đổi ra km
      });

      final bounds = LatLngBounds.fromPoints([s, e]);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));

    } catch(e) {
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) return;
      _showSnack("Lỗi tìm đường: $e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  void _startNavigation() {
    if(_currentPosition == null || _polylines.isEmpty) return;
    setState(() => _isNavigating = true);
    _showSnack("Bắt đầu dẫn đường!");

    _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 10)
    ).listen((p) {
      if(mounted) {
        final np = LatLng(p.latitude, p.longitude);
        setState(() => _currentPosition = np);
        _mapController.move(np, 17.0);
      }
    });
  }

  void _stopNavigation({bool isDisposing=false}) {
    _positionStreamSubscription?.cancel();
    if(!isDisposing && mounted) {
      setState(() => _isNavigating = false);
      if(_distanceKm != null && _distanceKm! > 0.5) {
        final points = (_distanceKm! * 10).round();
        try { ProfileService().addPoints(points); } catch(_){}

        showDialog(context: context, builder: (ctx)=>AlertDialog(
            title: const Text("🎉 Chuyến đi hoàn tất!"),
            content: Text("Bạn nhận được $points Điểm Xanh vì đã chọn lộ trình sạch."),
            actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Tuyệt vời"))]
        ));
      }
      if(_currentPosition!=null) _mapController.move(_currentPosition!, 14.0);
    }
  }

  Future<void> _toggleParks() async {
    setState(()=>_layerParks=!_layerParks);
    if(_layerParks) {
      setState(() => _isLoading = true);
      try {
        final parks = await _greenSpaceService.findNearbyGreenSpaces(_currentPosition!, 3000);
        setState(() => _parkMarkers = parks.map((p) {
          // Parse tọa độ (Lấy điểm đầu tiên của Polygon làm mốc)
          final coords = p['location']['value']['coordinates'];
          double lat = (coords[0][0][1] as num).toDouble();
          double lng = (coords[0][0][0] as num).toDouble();

          // Lấy tên công viên
          final name = p['name']?['value'] ?? 'Công viên xanh';

          return Marker(
              point: LatLng(lat, lng),
              width: 45, height: 45,
              child: GestureDetector(
                // 👇 Bấm vào thì hiện thông tin + nút chỉ đường
                  onTap: () => _showPlaceInfo(name, LatLng(lat, lng), Icons.park, Colors.green),
                  child: const Icon(Icons.park, color: Colors.green, size: 35)
              )
          );
        }).toList());
        _showSnack("Đã tìm thấy ${parks.length} công viên");
      } catch(e){
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) return;
      } finally { setState(() => _isLoading = false); }
    } else {
      setState(() => _parkMarkers = []);
    }
  }

  void _showPlaceInfo(String name, LatLng location, IconData icon, Color color) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Bạn có muốn tìm đường đến địa điểm này không?"),
            const SizedBox(height: 8),
            Text("📍 ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}",
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Đóng")
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            icon: const Icon(Icons.directions),
            label: const Text("Đi đến đây"),
            onPressed: () {
              Navigator.pop(ctx); // Đóng dialog

              // 👇 TỰ ĐỘNG ĐIỀN ĐIỂM ĐẾN VÀ TÌM ĐƯỜNG
              setState(() {
                _endPoint = location;
                _endController.text = "${location.latitude}, ${location.longitude}";
                _isSettingStart = false; // Focus vào ô đích
              });

              // Gọi hàm tìm đường ngay lập tức
              _handleSearchRoute();
            },
          )
        ]
    ));
  }

  Future<void> _toggleSensitive() async {
    setState(()=>_layerSensitive=!_layerSensitive);

    if(_layerSensitive) {
      setState(() => _isLoading = true);
      try {
        final areas = await _sensitiveService.findNearbySensitiveAreas(_currentPosition!, 3000);

        setState(() => _sensitiveMarkers = areas.map((a) {
          // 1. Lấy Tọa độ (Xử lý an toàn cho cả Point và Polygon)
          final rawLoc = a['location']['value'];
          List<dynamic> coords;

          // Nếu là Polygon (nhiều lớp ngoặc), lấy điểm đầu tiên làm mốc
          if (rawLoc['type'] == 'Polygon') {
            coords = rawLoc['coordinates'][0][0];
          } else {
            // Nếu là Point
            coords = rawLoc['coordinates'];
          }

          double lat = (coords[1] as num).toDouble();
          double lng = (coords[0] as num).toDouble();

          // 2. Lấy Tên địa điểm (New!)
          String name = 'Khu vực nhạy cảm';
          if (a.containsKey('name')) {
            name = a['name']['value'] ?? name;
          }

          // 3. Phân loại Icon & Màu sắc
          final cat = a['category']['value'];
          IconData icon = Icons.place;
          Color color = Colors.grey;

          if (cat == 'school') {
            icon = Icons.school;
            color = Colors.blue;
          } else if (cat == 'hospital') {
            icon = Icons.local_hospital;
            color = Colors.redAccent;
          }

          return Marker(
              point: LatLng(lat, lng),
              width: 45, height: 45,
              child: GestureDetector(
                // 👇 Bấm vào hiển thị Tên + Nút đi đến
                  onTap: () => _showPlaceInfo(name, LatLng(lat, lng), icon, color),
                  child: Icon(icon, color: color, size: 35)
              )
          );
        }).toList());

        _showSnack("Đã tìm thấy ${areas.length} khu vực nhạy cảm");

      } catch(e){
        // Im lặng với lỗi Auth
        if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) return;
        print("Lỗi Sensitive: $e");
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _sensitiveMarkers = []);
    }
  }

  void _showPerceptionDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Cảm nhận không khí"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.sentiment_very_satisfied, color: Colors.green), title: const Text("Trong lành"), onTap: () => _submitPerception(1, ctx)),
        ListTile(leading: const Icon(Icons.sentiment_neutral, color: Colors.orange), title: const Text("Bình thường"), onTap: () => _submitPerception(2, ctx)),
        ListTile(leading: const Icon(Icons.sentiment_very_dissatisfied, color: Colors.red), title: const Text("Ô nhiễm"), onTap: () => _submitPerception(3, ctx)),
      ]),
    ));
  }

  Future<void> _submitPerception(int level, BuildContext dialogContext) async {
    Navigator.pop(dialogContext);
    if(_currentPosition == null) return;
    try {
      await _perceptionService.submitPerception(location: _currentPosition!, feeling: level);
      _showSnack("Cảm ơn đóng góp của bạn!");
    } catch(e) {
      if (e is DioException && e.response?.statusCode == 401) return;
      _showSnack("Lỗi: $e");
    }
  }

  void _showStationInfo(String name, double pm25, Color color, String time) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.location_on, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 1. Phần hiển thị chỉ số
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Chỉ số PM2.5", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text("${pm25.toStringAsFixed(1)}", style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w900)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                  child: Text(_getAqiLevel(pm25), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. 👇 PHẦN HIỂN THỊ DỰ BÁO AI (QUAN TRỌNG)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1)
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon AI đang hoạt động
                const Icon(Icons.psychology, color: Colors.blueAccent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("DỰ BÁO SỚM (30 PHÚT)",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text("Khung giờ: $time",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      const Text("Dữ liệu được AI phân tích từ mạng lưới quan trắc thời gian thực.",
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: ()=>Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text("Đóng")
          ),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Có thể thêm hành động: Xem chi tiết / Báo cáo
              },
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              child: const Text("Xem chi tiết")
          )
        ]
    ));
  }

  Color _getAqiColor(double v) => v<=12?Colors.green:v<=35?Colors.yellow.shade700:v<=55?Colors.orange:Colors.red;
  String _getAqiLevel(double v) => v<=12?"Tốt":v<=35?"Trung bình":v<=55?"Kém":v<=150?"Xấu":"Nguy hại";
  void _showSnack(String m) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2))); }

  void _updateDistance() {
    if (_startPoint != null && _endPoint != null) {
      final d = Geolocator.distanceBetween(_startPoint!.latitude, _startPoint!.longitude, _endPoint!.latitude, _endPoint!.longitude);
      setState(() => _distanceKm = d/1000);
    }
  }

  void _activatePickMode() {
    setState(() => _isPickingLocation = true);
    _showSnack("Chạm vào bản đồ để chọn điểm đến 📍");
  }

  void _clearMap() {
    setState(() {
      _polylines=[]; _parkMarkers=[]; _sensitiveMarkers=[]; _incidentMarkers=[]; _forecastCircles=[]; _aqiMarkers=[];
      _startPoint=null; _endPoint=null; _distanceKm=null; _startController.text="Vị trí của tôi"; _endController.clear();
      _isNavigating=false; _layerParks=false; _layerSensitive=false; _layerForecast=false; _isPickingLocation=false;
    });
    _determinePosition();
  }

  void _handleMapTap(LatLng p) {
    if (_isNavigating) return;
    if (_isPickingLocation) {
      setState(() {
        _endPoint = p;
        _endController.text = "${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}";
        _isPickingLocation = false;
        if (!_isSettingStart) _isSettingStart = true;
        _updateDistance();
      });
      _showSnack("Đã chọn điểm đến ✅");
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final allMarkers = [
      if(_currentPosition != null) Marker(point: _currentPosition!, child: Icon(_isNavigating ? Icons.navigation : Icons.my_location, color: Colors.blue, size: 30)),
      if(_startPoint != null && _startPoint != _currentPosition) Marker(point: _startPoint!, width: 80, height: 80, child: const Column(children: [Icon(Icons.trip_origin, color: Colors.green, size: 35), Text("Bắt đầu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))])),
      if(_endPoint != null) Marker(point: _endPoint!, width: 80, height: 80, child: const Column(children: [Icon(Icons.location_on, color: Colors.red, size: 35), Text("Đến", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))])),
      ..._parkMarkers, ..._sensitiveMarkers, ..._aqiMarkers, ..._incidentMarkers
    ];

    return Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(10.7769, 106.7009),
                initialZoom: 13.0,
                onTap: (_, p) => _handleMapTap(p),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: NetworkTileProvider(
                    headers: {
                      'User-Agent': 'com.example.frontend_citizen',
                    },
                  ),
                ),

                // Vùng HCM (Giữ nguyên)
                if (!_isMapLoading) PolygonLayer(polygons: _hcmcPolygons),

                // Lớp Dự báo (Giữ nguyên)
                if (_layerForecast) CircleLayer(circles: _forecastCircles),

                // Đường đi (Giữ nguyên)
                PolylineLayer(polylines: _polylines),

                // MARKER: Gộp marker thường + Marker Cờ Tổ Quốc
                MarkerLayer(markers: [
                  ...allMarkers,
                  ..._sovereigntyMarkers, // 👈 Chỉ thêm đúng dòng này là có cờ
                ]),
              ],
            ),

            // --- CÁC WIDGET GIAO DIỆN KHÁC GIỮ NGUYÊN ---
            if (_isLoading || _isMapLoading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(color: Colors.green, minHeight: 4)),

            if (!_isNavigating) Positioned(top: 50, left: 16, right: 16, child: Column(children: [
              _buildSearchBar(),
              if(_layerForecast && _currentMaxPm25 > 0) Padding(padding: const EdgeInsets.only(top:8), child: HealthAdviceCard(pm25: _currentMaxPm25, userHealthGroup: _userHealthGroup))
            ])),

            if (!_isNavigating) ...[
              Positioned(bottom: 100, right: 16, child: _buildRightButtons()),
              Positioned(bottom: 16, left: 16, right: 16, child: _buildBottomFilter()),
            ],

            if (_polylines.isNotEmpty && !_isNavigating) Positioned(bottom: 80, left: 40, right: 40, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: _startNavigation, child: const Text("BẮT ĐẦU ĐI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
            )),

            if (_isNavigating) Positioned(bottom: 30, right: 16, child: FloatingActionButton(onPressed: () => _stopNavigation(), backgroundColor: Colors.red, child: const Icon(Icons.stop, color: Colors.white))),
          ],
        )
    );
  }

  Widget _buildSearchBar() {
    return Card(child: Column(children: [
      ListTile(
          dense: true, leading: const Icon(Icons.my_location, color: Colors.green),
          title: TextField(controller: _startController, onTap: ()=>setState(()=>_isSettingStart=true), decoration: const InputDecoration(border: InputBorder.none, hintText: "Điểm đi")),
          trailing: IconButton(icon: const Icon(Icons.close), onPressed: ()=>setState(()=>_startController.text="Vị trí của tôi"))
      ),
      const Divider(height: 1),
      ListTile(
          dense: true, leading: const Icon(Icons.location_on, color: Colors.red),
          title: TextField(controller: _endController, onTap: ()=>setState(()=>_isSettingStart=false), onSubmitted: (_)=>_handleSearchRoute(), decoration: const InputDecoration(border: InputBorder.none, hintText: "Điểm đến")),
          trailing: IconButton(icon: const Icon(Icons.search, color: Colors.blue), onPressed: _handleSearchRoute)
      )
    ]));
  }

  Widget _buildRightButtons() {
    return Column(children: [
      FloatingActionButton(mini: true, heroTag: "z1", backgroundColor: Colors.white, onPressed: (){ _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1); }, child: const Icon(Icons.add, color: Colors.black)),
      const SizedBox(height: 10),
      FloatingActionButton(mini: true, heroTag: "z2", backgroundColor: Colors.white, onPressed: (){ _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1); }, child: const Icon(Icons.remove, color: Colors.black)),
      const SizedBox(height: 10),
      FloatingActionButton(mini: true, heroTag: "gps", backgroundColor: Colors.white, onPressed: _determinePosition, child: const Icon(Icons.gps_fixed, color: Colors.blue)),
      const SizedBox(height: 10),
      FloatingActionButton(mini: true, heroTag: "pick", backgroundColor: _isPickingLocation?Colors.orange:Colors.white, onPressed: _activatePickMode, child: const Icon(Icons.add_location_alt, color: Colors.black)),
      const SizedBox(height: 10),
      FloatingActionButton(mini: true, heroTag: "refresh", backgroundColor: Colors.white, onPressed: _clearMap, child: const Icon(Icons.refresh, color: Colors.black)),
    ]);
  }

  Widget _buildBottomFilter() {
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      _chip("AQI", Icons.cloud, Colors.orange, _layerForecast, _fetchForecasts), const SizedBox(width: 8),
      _chip("Công viên", Icons.park, Colors.green, _layerParks, _toggleParks), const SizedBox(width: 8),
      _chip("Nhạy cảm", Icons.local_hospital, Colors.red, _layerSensitive, _toggleSensitive), const SizedBox(width: 8),
      _chip("Cảm nhận", Icons.emoji_emotions, Colors.teal, false, _showPerceptionDialog),
    ]));
  }

  Widget _chip(String l, IconData i, Color c, bool a, VoidCallback t) {
    return FilterChip(label: Row(children: [Icon(i, size: 16, color: a?Colors.white:c), const SizedBox(width: 4), Text(l)]), selected: a, onSelected: (_)=>t(), selectedColor: c, checkmarkColor: Colors.white, backgroundColor: Colors.white);
  }
}