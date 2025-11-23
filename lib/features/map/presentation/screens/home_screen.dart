import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// Services
import '../../services/route_planning_service.dart';
import '../../services/green_space_service.dart';
import '../../services/forecast_service.dart';
import '../../services/sensitive_area_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/perception_service.dart';

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
  final PerceptionService _perceptionService = PerceptionService(); // 👈 KHỞI TẠO SERVICE MỚI

  // --- State ---
  LatLng? _currentPosition;
  LatLng? _startPoint;
  LatLng? _endPoint;

  double? _distanceKm;

  bool _isSettingStart = true;
  bool _isLoading = false;
  bool _isNavigating = false;
  bool _showLayers = false;

  StreamSubscription<Position>? _positionStreamSubscription;

  // --- Map Layers ---
  List<Polyline> _polylines = [];
  List<Marker> _parkMarkers = [];
  List<CircleMarker> _forecastCircles = [];
  List<Marker> _sensitiveMarkers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).clearSnackBars();
      if (mounted) {
        _determinePosition();
        _fetchForecasts();
      }
    });
  }

  @override
  void dispose() {
    _stopNavigation();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2), margin: const EdgeInsets.only(bottom: 70, left: 10, right: 10)),
    );
  }

  Color _getAqiColor(double v) => v<=12?Colors.green:v<=35?Colors.yellow:v<=55?Colors.orange:Colors.red;
  String _getAqiLevel(double v) => v<=12?"Tốt":v<=35?"Trung bình":v<=55?"Kém":v<=150?"Xấu":"Nguy hại";

  // --- HELPER TÍNH KHOẢNG CÁCH ---
  void _updateDistance() {
    if (_startPoint != null && _endPoint != null) {
      double distanceInMeters = Geolocator.distanceBetween(
        _startPoint!.latitude, _startPoint!.longitude,
        _endPoint!.latitude, _endPoint!.longitude,
      );
      setState(() {
        _distanceKm = distanceInMeters / 1000;
      });
    } else {
      setState(() {
        _distanceKm = null;
      });
    }
  }

  // ===============================================================
  // 🗣️ TÍNH NĂNG 6: KHOA HỌC CÔNG DÂN (CẢM NHẬN)
  // ===============================================================
  void _showPerceptionDialog() {
    if (_currentPosition == null) {
      _showSnack('Đang lấy vị trí của bạn...');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emoji_emotions, color: Colors.teal),
            SizedBox(width: 10),
            Text('Cảm nhận không khí?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Đóng góp dữ liệu cho cộng đồng:", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            _buildFeelingOption(ctx, 1, 'Trong lành', Colors.green, Icons.sentiment_very_satisfied),
            _buildFeelingOption(ctx, 2, 'Bình thường', Colors.yellow.shade800, Icons.sentiment_neutral),
            _buildFeelingOption(ctx, 3, 'Kém / Bụi', Colors.orange, Icons.sentiment_dissatisfied),
            _buildFeelingOption(ctx, 4, 'Ô nhiễm / Khó thở', Colors.red, Icons.masks),
          ],
        ),
      ),
    );
  }

  Widget _buildFeelingOption(BuildContext ctx, int level, String text, Color color, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: color, size: 30),
      title: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      onTap: () {
        Navigator.of(ctx).pop();
        _submitPerception(level);
      },
    );
  }

  Future<void> _submitPerception(int level) async {
    if (_currentPosition == null) return;
    setState(() => _isLoading = true);
    try {
      await _perceptionService.submitPerception(
        location: _currentPosition!,
        feeling: level,
      );
      _showSnack('Đã gửi cảm nhận! Cảm ơn bạn.');
    } catch (e) {
      _showSnack('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===============================================================
  // 🧠 THUẬT TOÁN NỘI SUY (IDW)
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
            radius: 1500,
            useRadiusInMeter: true,
            color: color.withOpacity(0.15),
            borderColor: Colors.transparent,
            borderStrokeWidth: 0,
          ));
        }
      }
    }
    return heatmapPoints;
  }

  double _calculateIdw(double lat, double lng, List<dynamic> sensors) {
    double numerator = 0; double denominator = 0;
    for (var sensor in sensors) {
      final loc = sensor['location']['value']['coordinates'];
      final val = sensor['forecastedPM25']?['value'] ?? 0.0;
      double dist = (lat - loc[1]) * (lat - loc[1]) + (lng - loc[0]) * (lng - loc[0]);
      if (dist == 0) return val;
      double weight = 1 / dist;
      numerator += val * weight;
      denominator += weight;
    }
    return (denominator != 0) ? (numerator / denominator) : 0;
  }

  // ===============================================================
  // ☁️ TẢI DỰ BÁO
  // ===============================================================
  Future<void> _fetchForecasts() async {
    if (mounted) setState(() { _isLoading = true; });
    try {
      final forecasts = await _forecastService.getAqiForecasts();
      if(forecasts.isEmpty) { _showSnack("Chưa có dữ liệu dự báo"); return; }

      final circles = <CircleMarker>[];
      final markers = <Marker>[];

      circles.addAll(_generateInterpolatedHeatmap(forecasts));

      for (var f in forecasts) {
        final loc = f['location']['value']['coordinates'];
        final pm25 = f['forecastedPM25']?['value'] ?? 0.0;
        final rawId = f['id'] ?? '';
        final stationName = rawId.split(':').last.replaceAll('OWM-', '');
        final timeStr = f['validFrom']?['value']?['@value'] ?? '';

        String displayTime = 'N/A';
        if (timeStr.contains('T')) {
          try { displayTime = timeStr.split('T')[1].substring(0, 5); } catch (_) { displayTime = timeStr; }
        }

        final pos = LatLng(loc[1], loc[0]);
        final color = _getAqiColor(pm25);

        circles.add(CircleMarker(
            point: pos, radius: 2000, useRadiusInMeter: true,
            color: color.withOpacity(0.5), borderColor: color, borderStrokeWidth: 2
        ));

        markers.add(Marker(
          point: pos, width: 40, height: 40,
          child: GestureDetector(
            onTap: () {
              showDialog(context: context, builder: (ctx) => AlertDialog(
                title: Row(children: [Icon(Icons.wb_cloudy, color: color), const SizedBox(width: 10), const Text("Trạm quan trắc", style: TextStyle(color: Colors.black87))]),
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
        _parkMarkers.addAll(markers);
      });
      _showSnack('Đã tải bản đồ nhiệt toàn thành phố');

    } catch(e) { print(e); } finally { if(mounted) setState(() { _isLoading = false; }); }
  }

  // ===============================================================
  // 📍 LOGIC VỊ TRÍ & GEOCODING
  // ===============================================================
  Future<void> _determinePosition() async {
    if (_isNavigating) return;
    setState(() { _isLoading = true; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS chưa bật');
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Quyền GPS bị từ chối');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        if (_startController.text == "Vị trí của tôi") {
          _startPoint = _currentPosition;
          _mapController.move(_currentPosition!, 15.0);
        }
        _updateDistance();
      });
    } catch (e) { _showSnack('Lỗi GPS: $e'); } finally { if (mounted) setState(() { _isLoading = false; }); }
  }

  Future<LatLng?> _resolveAddress(String address) async {
    if (address.trim().isEmpty) return null;
    if (address == "Vị trí của tôi") return _currentPosition;
    return await _geocodingService.getCoordinatesFromAddress(address);
  }

  // ===============================================================
  // 🛣️ TÌM ĐƯỜNG
  // ===============================================================
  Future<void> _handleSearchRoute() async {
    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; });
    try {
      LatLng? startCoords = await _resolveAddress(_startController.text);
      if (startCoords == null && _currentPosition == null) await _determinePosition();
      startCoords ??= _currentPosition;

      LatLng? endCoords = await _resolveAddress(_endController.text);
      if (startCoords == null || endCoords == null) throw Exception("Không tìm thấy địa chỉ.");

      setState(() {
        _startPoint = startCoords;
        _endPoint = endCoords;
        _updateDistance();
      });

      await _fetchAndDrawRoutes(startCoords, endCoords);

      final bounds = LatLngBounds.fromPoints([startCoords, endCoords]);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));

    } catch (e) { _showSnack('$e'); } finally { if (mounted) setState(() { _isLoading = false; }); }
  }

  Future<void> _fetchAndDrawRoutes(LatLng start, LatLng end) async {
    try {
      final geoJsonData = await _routeService.getRecommendedRoutes(start, end);
      final List features = geoJsonData['features'] ?? [];
      final List<Polyline> routes = [];
      for (var i = 0; i < features.length; i++) {
        final props = features[i]['properties'];
        final routeType = props['routeType'];
        final List<LatLng> points = (features[i]['geometry']['coordinates'] as List).map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        Color color = Colors.grey; double width = 4.0;
        if (routeType == 'cleanest') { color = Colors.green; width = 6.0; }
        else if (routeType == 'fastest') { color = Colors.blue; }
        routes.add(Polyline(points: points, color: color, strokeWidth: width));
      }
      setState(() { _polylines = routes; });
    } catch (e) { _showSnack("Không tìm thấy đường đi"); }
  }

  void _startNavigation() {
    if (_currentPosition == null) return;
    setState(() { _isNavigating = true; });
    const settings = LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5);
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
      final newPos = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _currentPosition = newPos);
        _mapController.move(newPos, 18.0);
      }
    });
    _showSnack('Bắt đầu dẫn đường!');
  }

  void _stopNavigation() {
    _positionStreamSubscription?.cancel();
    if (mounted) {
      setState(() => _isNavigating = false);
      _showSnack('Đã dừng dẫn đường');
    }
  }

  void _clearMap() {
    setState(() {
      _polylines = []; _parkMarkers = []; _sensitiveMarkers = [];
      _startPoint = null; _endPoint = null; _distanceKm = null;
      _startController.text = "Vị trí của tôi"; _endController.clear();
      _isNavigating = false; _positionStreamSubscription?.cancel();
      if (_currentPosition != null) _mapController.move(_currentPosition!, 15.0);
    });
    _showSnack('Đã xóa bản đồ');
  }

  void _handleMapTap(LatLng point) {
    if (_isNavigating) return;

    setState(() {
      if (!_isSettingStart) {
        _endPoint = point;
        _endController.text = "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
        _isSettingStart = true;
      } else {
        _endPoint = point;
        _endController.text = "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
      }
      _updateDistance();
    });
  }

  // ===============================================================
  // 🌳 CÁC LỚP DỮ LIỆU KHÁC
  // ===============================================================
  Future<void> _fetchNearbyParks() async {
    if(_currentPosition == null) { _showSnack("Chưa có vị trí"); return; }
    setState(() { _isLoading = true; _parkMarkers = []; });
    try {
      final parks = await _greenSpaceService.findNearbyGreenSpaces(_currentPosition!, 3000);
      setState(() {
        _parkMarkers = parks.map((p) {
          final c = p['location']['value']['coordinates'][0];
          return Marker(point: LatLng(c[0][1], c[0][0]), child: const Icon(Icons.park, color: Colors.green, size: 30));
        }).toList();
      });
      _showSnack('Đã tải ${parks.length} công viên');
    } catch(e) { _showSnack('Lỗi tải công viên'); } finally { if(mounted) setState(() => _isLoading = false); }
  }

  Future<void> _fetchSensitiveAreas() async {
    if(_currentPosition == null) { _showSnack("Chưa có vị trí"); return; }
    setState(() { _isLoading = true; _sensitiveMarkers = []; });
    try {
      final areas = await _sensitiveService.findNearbySensitiveAreas(_currentPosition!, 3000);
      setState(() {
        _sensitiveMarkers = areas.map((a) {
          final c = a['location']['value']['coordinates'][0];
          final cat = a['category']['value'];
          IconData icon = Icons.place; Color color = Colors.grey;
          if(cat == 'school') { icon = Icons.school; color = Colors.blue; }
          else if(cat == 'hospital') { icon = Icons.local_hospital; color = Colors.red; }
          else if(cat == 'police') { icon = Icons.local_police; color = Colors.indigo; }
          else if(cat == 'military') { icon = Icons.shield; color = Colors.brown; }
          return Marker(point: LatLng(c[0][1], c[0][0]), child: Icon(icon, color: color, size: 30));
        }).toList();
      });
      _showSnack('Đã tải ${areas.length} khu vực');
    } catch(e) { _showSnack('Lỗi tải khu vực nhạy cảm'); } finally { if(mounted) setState(() => _isLoading = false); }
  }

  // ===============================================================
  // 🖥️ UI
  // ===============================================================
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final List<Marker> allMarkers = [];
    if (_currentPosition != null) {
      allMarkers.add(Marker(
        point: _currentPosition!,
        child: _isNavigating
            ? const Icon(Icons.navigation, color: Colors.blue, size: 40.0)
            : const Icon(Icons.my_location, color: Colors.blue, size: 30.0),
      ));
    }
    if (_startPoint != null && _startPoint != _currentPosition) {
      allMarkers.add(Marker(
          point: _startPoint!,
          width: 80, height: 80,
          child: const Column(children: [Icon(Icons.trip_origin, color: Colors.green, size: 35), Text("Bắt đầu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))])
      ));
    }
    if (_endPoint != null) {
      allMarkers.add(Marker(
          point: _endPoint!,
          width: 80, height: 80,
          child: const Column(children: [Icon(Icons.location_on, color: Colors.red, size: 35), Text("Đến", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))])
      ));
    }
    allMarkers.addAll(_parkMarkers);
    allMarkers.addAll(_sensitiveMarkers);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // --- 1. BẢN ĐỒ ---
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(10.7769, 106.7009),
              initialZoom: 14.0,
              onTap: (_, point) => _handleMapTap(point),
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              CircleLayer(circles: _forecastCircles),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: allMarkers),
            ],
          ),

          // --- 1.5 LEGEND ---
          if (_showLayers && !_isNavigating)
            Positioned(
              top: 150, left: 16,
              child: Card(
                elevation: 4, color: Colors.white.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Chỉ số PM2.5', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      _buildLegendItem(Colors.green, '0-12 (Tốt)'),
                      _buildLegendItem(Colors.yellow, '12-35 (TB)'),
                      _buildLegendItem(Colors.orange, '35-55 (Kém)'),
                      _buildLegendItem(Colors.red, '> 55 (Xấu)'),
                    ],
                  ),
                ),
              ),
            ),

          // --- 2. THANH TÌM KIẾM ---
          if (!_isNavigating)
            Positioned(
              top: 50, left: 16, right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: TextField(
                        controller: _startController,
                        decoration: const InputDecoration(icon: Icon(Icons.my_location, color: Colors.green), hintText: "Chọn điểm đi", border: InputBorder.none),
                        onTap: () => setState(() => _isSettingStart = true),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
                      child: Row(children: [
                        const Icon(Icons.location_on, color: Colors.red), const SizedBox(width: 16),
                        Expanded(child: TextField(controller: _endController, decoration: const InputDecoration(hintText: "Nhập điểm đến...", border: InputBorder.none), onSubmitted: (_) => _handleSearchRoute(), onTap: () => setState(() => _isSettingStart = false))),
                        IconButton(icon: const Icon(Icons.search, color: Colors.blue), onPressed: _handleSearchRoute)
                      ]),
                    ),

                    // 🚀 HIỂN THỊ KHOẢNG CÁCH
                    if (_distanceKm != null)
                      Container(
                        width: double.infinity,
                        color: Colors.blue.shade50,
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          "Khoảng cách: ${_distanceKm!.toStringAsFixed(2)} km",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      )
                  ],
                ),
              ),
            ),

          // --- 3. NÚT CHỨC NĂNG ---
          Positioned(
            bottom: 30, right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(heroTag: 'clear', onPressed: _clearMap, backgroundColor: Colors.white, child: const Icon(Icons.cleaning_services_outlined, color: Colors.black87)),
                const SizedBox(height: 10),
                FloatingActionButton.small(heroTag: 'zoomIn', onPressed: () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1); }, backgroundColor: Colors.white, child: const Icon(Icons.add, color: Colors.black87)),
                const SizedBox(height: 10),
                FloatingActionButton.small(heroTag: 'zoomOut', onPressed: () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1); }, backgroundColor: Colors.white, child: const Icon(Icons.remove, color: Colors.black87)),
                const SizedBox(height: 10),
                FloatingActionButton.small(heroTag: 'gps', onPressed: _determinePosition, backgroundColor: Colors.white, child: const Icon(Icons.gps_fixed, color: Colors.blue)),
                const SizedBox(height: 10),
                if (!_isNavigating) FloatingActionButton.small(heroTag: 'layers', onPressed: () => setState(() => _showLayers = !_showLayers), backgroundColor: _showLayers ? Colors.blue : Colors.white, child: const Icon(Icons.layers, color: Colors.black87)),
              ],
            ),
          ),

          // --- 4. MENU LỚP PHỦ ---
          if (_showLayers && !_isNavigating)
            Positioned(
              bottom: 30, right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 🚀 NÚT MỚI: CẢM NHẬN
                  _buildLayerBtn('Cảm nhận', Icons.emoji_emotions, Colors.teal, _showPerceptionDialog),
                  const SizedBox(height: 8),
                  _buildLayerBtn('Công viên', Icons.park, Colors.green, _fetchNearbyParks),
                  const SizedBox(height: 8),
                  _buildLayerBtn('Trường/Viện', Icons.local_hospital, Colors.redAccent, _fetchSensitiveAreas),
                  const SizedBox(height: 8),
                  _buildLayerBtn('Dự báo AQI', Icons.wb_cloudy, Colors.orange, _fetchForecasts),
                ],
              ),
            ),

          // --- 5. NÚT DẪN ĐƯỜNG ---
          if (_polylines.isNotEmpty && !_isNavigating)
            Positioned(
              bottom: 30, left: 16,
              child: FloatingActionButton.extended(heroTag: 'nav', onPressed: _startNavigation, icon: const Icon(Icons.navigation), label: const Text("Bắt đầu đi"), backgroundColor: Colors.green),
            ),

          if (_isNavigating)
            Positioned(
              bottom: 30, left: 16,
              child: FloatingActionButton.extended(heroTag: 'stop', onPressed: _stopNavigation, icon: const Icon(Icons.close), label: const Text("Thoát"), backgroundColor: Colors.red),
            ),

          if (_isLoading)
            Container(color: Colors.black.withOpacity(0.3), child: const Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildLayerBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))), const SizedBox(width: 8), FloatingActionButton.small(heroTag: label, onPressed: () { onTap(); setState(() => _showLayers = false); }, backgroundColor: color, child: Icon(icon, color: Colors.white))]);
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(text, style: const TextStyle(fontSize: 11))]));
  }
}