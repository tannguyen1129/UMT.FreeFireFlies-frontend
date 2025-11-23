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

// Widgets
import '../../../profile/presentation/widgets/health_advice_card.dart';


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
  final PerceptionService _perceptionService = PerceptionService(); // ✅ Service Cảm nhận

  // --- State ---
  LatLng? _currentPosition;
  LatLng? _startPoint;
  LatLng? _endPoint;
  double? _distanceKm;

  bool _isSettingStart = true;
  bool _isLoading = false;
  bool _isNavigating = false;

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

  // Layer cho AQI (Heatmap + Trạm)
  List<CircleMarker> _forecastCircles = [];
  List<Marker> _aqiMarkers = [];

  @override
  void initState() {
    super.initState();

    // 🚀 LẮNG NGHE FCM KHI ĐANG MỞ APP
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Nhận tin nhắn Foreground: ${message.notification?.title}');

      if (message.notification != null && mounted) {
        // Hiện thông báo ngay lập tức bằng SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.notification!.title ?? 'Thông báo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(message.notification!.body ?? ''),
                ],
              ),
              backgroundColor: Colors.green, // Màu xanh nổi bật
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(top: 50, left: 10, right: 10),
              duration: const Duration(seconds: 5),
            )
        );
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

  Future<void> _fetchUserProfile() async {
    try {
      final profile = await ProfileService().getMyProfile();

      if (mounted) {
        setState(() {
          _userHealthGroup = profile['health_group'] ?? 'normal';
        });

        // 🚀 LOGIC MỚI: ĐĂNG KÝ TOPIC CÁ NHÂN
        // Topic dạng: user_12345-abcd...
        final userId = profile['user_id'];
        if (userId != null) {
          await FirebaseMessaging.instance.subscribeToTopic('user_$userId');
          print("✅ Đã đăng ký nhận tin riêng tại topic: user_$userId");
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

  // ... (Logic Tìm đường, Dẫn đường giữ nguyên) ...
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
  void _startNavigation() { if(_currentPosition==null)return; setState(() => _isNavigating = true); _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5)).listen((p){ final np = LatLng(p.latitude, p.longitude); if(mounted){ setState(()=>_currentPosition=np); _mapController.move(np, 18.0); } }); _showSnack('Bắt đầu dẫn đường!'); }
  void _stopNavigation({bool isDisposing=false}) { _positionStreamSubscription?.cancel(); _positionStreamSubscription=null; if(!isDisposing && mounted) { setState(()=>_isNavigating=false); _showSnack('Đã dừng'); if(_currentPosition!=null)_mapController.move(_currentPosition!, 15.0); } }
  void _handleMapTap(LatLng p) { if(_isNavigating)return; setState(() { if(!_isSettingStart){_endPoint=p; _endController.text="${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}"; _isSettingStart=true;} else {_endPoint=p; _endController.text="${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}";} _updateDistance(); }); }

  void _clearMap() {
    setState(() {
      _polylines = [];
      // Không xóa forecastCircles (Heatmap)
      // Không xóa aqiMarkers (Trạm)
      // Xóa các marker khác
      _parkMarkers = []; _sensitiveMarkers = [];

      _startPoint = null; _endPoint = null; _distanceKm = null;
      _startController.text = "Vị trí của tôi"; _endController.clear();
      _isNavigating = false; _positionStreamSubscription?.cancel();
      if (_currentPosition != null) _mapController.move(_currentPosition!, 15.0);

      // Reset toggle
      _layerParks = false; _layerSensitive = false;
    });
    _showSnack('Đã làm mới bản đồ');
  }

  // ===============================================================
  // 🧠 THUẬT TOÁN NỘI SUY (IDW) - ✅ ĐÃ KHÔI PHỤC
  // ===============================================================
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
            radius: 1500, // Bán kính lớn để phủ kín
            useRadiusInMeter: true,
            color: color.withOpacity(0.15), // Mờ làm nền
            borderColor: Colors.transparent,
            borderStrokeWidth: 0,
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

  // ===============================================================
  // ☁️ TẢI DỰ BÁO (KẾT HỢP NỘI SUY + MARKER)
  // ===============================================================
  Future<void> _fetchForecasts() async {
    if (mounted) setState(() { _isLoading = true; });
    try {
      final forecasts = await _forecastService.getAqiForecasts();
      if(forecasts.isEmpty) { _showSnack("Chưa có dữ liệu dự báo"); return; }

      final circles = <CircleMarker>[];
      final markers = <Marker>[];
      double maxPm = 0.0;

      // 1. Tạo Heatmap nội suy (Lớp nền)
      circles.addAll(_generateInterpolatedHeatmap(forecasts));

      // 2. Tạo Marker cho trạm chính (Lớp nổi)
      for (var f in forecasts) {
        final loc = f['location']['value']['coordinates'];
        final pm25 = (f['forecastedPM25']?['value'] ?? 0.0).toDouble();
        if (pm25 > maxPm) maxPm = pm25;

        final rawId = f['id'] ?? '';
        final stationName = rawId.split(':').last.replaceAll('OWM-', '');
        final timeStr = f['validFrom']?['value']?['@value'] ?? '';
        String displayTime = 'N/A';
        if (timeStr.contains('T')) { try { displayTime = timeStr.split('T')[1].substring(0, 5); } catch (_) {} }

        final pos = LatLng(loc[1], loc[0]);
        final color = _getAqiColor(pm25);

        // Vòng tròn đậm tại trạm
        circles.add(CircleMarker(point: pos, radius: 2000, useRadiusInMeter: true, color: color.withOpacity(0.5), borderColor: color, borderStrokeWidth: 2));

        // Icon đám mây (Clickable)
        markers.add(Marker(
          point: pos, width: 40, height: 40,
          child: GestureDetector(
            onTap: () {
              showDialog(context: context, builder: (ctx) => AlertDialog(
                title: Row(children: [Icon(Icons.wb_cloudy, color: color), const SizedBox(width: 10), const Text("Dự báo AQI", style: TextStyle(color: Colors.black87))]),
                content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Khu vực: $stationName", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  Text("PM2.5: ${pm25.toStringAsFixed(1)} µg/m³", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Row(children: [const Text("Mức độ: "), Text(_getAqiLevel(pm25), style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 10),
                  Text("Thời gian: $displayTime", style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
        _aqiMarkers = markers; // 👈 Lưu vào danh sách riêng
        _layerForecast = true;
        _currentMaxPm25 = maxPm;
      });
    } catch(e) { print(e); } finally { if(mounted) setState(() { _isLoading = false; }); }
  }

  // ===============================================================
  // 🗣️ TÍNH NĂNG 6: CẢM NHẬN (✅ ĐÃ KHÔI PHỤC)
  // ===============================================================
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
    if (_layerForecast) allMarkers.addAll(_aqiMarkers); // 👈 Thêm AQI markers nếu lớp đang bật

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
              if (_layerForecast) CircleLayer(circles: _forecastCircles), // 👈 Heatmap nội suy
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: allMarkers),
            ],
          ),

          // 2. THANH TÌM KIẾM (NỔI)
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
                        // Ô Điểm đi
                        ListTile(
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

                  // Hiển thị khoảng cách
                  if (_distanceKm != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                      child: Text("${_distanceKm!.toStringAsFixed(2)} km", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),

                  // Thẻ Lời khuyên sức khỏe
                  if (_layerForecast && _currentMaxPm25 > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: HealthAdviceCard(pm25: _currentMaxPm25, userHealthGroup: _userHealthGroup),
                    ),
                ],
              ),
            ),

          // 3. CÁC NÚT CHỨC NĂNG (BÊN PHẢI)
          Positioned(
            bottom: 100, right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ NÚT ZOOM ĐÃ CÓ LẠI
                FloatingActionButton.small(heroTag: 'zoomIn', onPressed: () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1); }, backgroundColor: Colors.white, child: const Icon(Icons.add, color: Colors.black87)),
                const SizedBox(height: 10),
                FloatingActionButton.small(heroTag: 'zoomOut', onPressed: () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1); }, backgroundColor: Colors.white, child: const Icon(Icons.remove, color: Colors.black87)),
                const SizedBox(height: 10),

                _buildCircleBtn(Icons.refresh, () => _clearMap(), color: Colors.white),
                const SizedBox(height: 10),
                _buildCircleBtn(Icons.gps_fixed, () => _determinePosition(), color: Colors.white, iconColor: Colors.blue),
              ],
            ),
          ),

          // 4. THANH CÔNG CỤ DƯỚI CÙNG (BOTTOM SHEET)
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
                    // ✅ NÚT CẢM NHẬN Ở ĐÂY
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

  Widget _buildLegendItem(Color color, String text) { /*...*/ return Container(); } // Đã bỏ legend vì đã có trên bottom sheet và popup
}