import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// ⚠️ Đảm bảo bạn đã tạo các file service này
import '../../services/route_planning_service.dart';
import '../../services/green_space_service.dart';
import '../../services/forecast_service.dart';
import '../../services/sensitive_area_service.dart';
import '../../services/geocoding_service.dart'; // File tìm địa chỉ

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

  // --- State ---
  LatLng? _currentPosition;
  LatLng? _startPoint;
  LatLng? _endPoint;

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

    // 🚀 FIX QUAN TRỌNG 1: Xóa ngay thông báo "Đăng nhập thành công" khi vào màn hình này
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

  // ===============================================================
  // 🛠️ HELPER: HIỂN THỊ THÔNG BÁO (ĐÃ FIX)
  // ===============================================================
  void _showSnack(String msg) {
    // 🚀 FIX QUAN TRỌNG 2: Xóa thông báo cũ trước khi hiện cái mới
    ScaffoldMessenger.of(context).clearSnackBars();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.only(bottom: 70, left: 10, right: 10), // Tránh che nút bottom bar
      ),
    );
  }

  Color _getAqiColor(double v) => v<=12?Colors.green:v<=35?Colors.yellow:v<=55?Colors.orange:Colors.red;

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
        // Chỉ di chuyển cam nếu đang ở chế độ "Vị trí của tôi"
        if (_startController.text == "Vị trí của tôi") {
          _mapController.move(_currentPosition!, 15.0);
        }
      });
    } catch (e) {
      _showSnack('Lỗi GPS: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<LatLng?> _resolveAddress(String address) async {
    if (address.trim().isEmpty) return null;
    if (address == "Vị trí của tôi") return _currentPosition;
    return await _geocodingService.getCoordinatesFromAddress(address);
  }

  // ===============================================================
  // 🛣️ LOGIC TÌM ĐƯỜNG & ĐIỀU HƯỚNG
  // ===============================================================

  Future<void> _handleSearchRoute() async {
    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; });

    try {
      LatLng? startCoords = await _resolveAddress(_startController.text);
      if (startCoords == null && _currentPosition == null) await _determinePosition();
      startCoords ??= _currentPosition;

      LatLng? endCoords = await _resolveAddress(_endController.text);

      if (startCoords == null || endCoords == null) {
        throw Exception("Không tìm thấy địa chỉ.");
      }

      setState(() {
        _startPoint = startCoords;
        _endPoint = endCoords;
      });

      await _fetchAndDrawRoutes(startCoords, endCoords);
      _fitBounds(startCoords, endCoords);

    } catch (e) {
      _showSnack('$e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _fitBounds(LatLng p1, LatLng p2) {
    final bounds = LatLngBounds.fromPoints([p1, p2]);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }

  Future<void> _fetchAndDrawRoutes(LatLng start, LatLng end) async {
    try {
      final geoJsonData = await _routeService.getRecommendedRoutes(start, end);
      final List features = geoJsonData['features'] ?? [];
      final List<Polyline> routes = [];

      for (var i = 0; i < features.length; i++) {
        final geometry = features[i]['geometry'];
        final props = features[i]['properties'];
        final routeType = props['routeType'];
        final List<LatLng> points = (geometry['coordinates'] as List)
            .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();

        Color color = Colors.grey;
        double width = 4.0;
        if (routeType == 'cleanest') { color = Colors.green; width = 6.0; }
        else if (routeType == 'fastest') { color = Colors.blue; width = 4.0; }

        routes.add(Polyline(points: points, color: color, strokeWidth: width));
      }
      setState(() { _polylines = routes; });
    } catch (e) {
      _showSnack("Không tìm thấy đường đi");
    }
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
    if (mounted) setState(() => _isNavigating = false);
    _showSnack('Đã dừng dẫn đường');
  }

  void _clearMap() {
    setState(() {
      _polylines = [];
      _parkMarkers = [];
      _sensitiveMarkers = [];
      _startPoint = null;
      _endPoint = null;
      _startController.text = "Vị trí của tôi";
      _endController.clear();
      _isNavigating = false;
      _positionStreamSubscription?.cancel();
      if (_currentPosition != null) _mapController.move(_currentPosition!, 15.0);
    });
    _showSnack('Đã xóa bản đồ');
  }

  void _handleMapTap(LatLng point) {
    if(_isNavigating) return;
    setState(() {
      _endPoint = point;
      // Gán tọa độ vào ô text để người dùng biết
      _endController.text = "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
    });
  }

  // ===============================================================
  // 🌳 LOGIC CÁC LỚP DỮ LIỆU (LAYERS)
  // ===============================================================

  Future<void> _fetchNearbyParks() async {
    if(_currentPosition == null) { _showSnack("Chưa có vị trí"); return; }
    setState(() { _isLoading = true; _parkMarkers = []; });
    try {
      final parks = await _greenSpaceService.findNearbyGreenSpaces(_currentPosition!, 3000); // 3km
      setState(() {
        _parkMarkers = parks.map((p) {
          final c = p['location']['value']['coordinates'][0];
          // Cẩn thận cấu trúc Polygon [ [ [lng, lat], ... ] ]
          final firstPoint = c[0];
          return Marker(
              point: LatLng(firstPoint[1], firstPoint[0]),
              child: const Icon(Icons.park, color: Colors.green, size: 30)
          );
        }).toList();
      });
      _showSnack('Đã tải ${parks.length} công viên');
    } catch(e) { _showSnack('Lỗi tải công viên'); } finally { setState(() => _isLoading = false); }
  }

  Future<void> _fetchSensitiveAreas() async {
    if(_currentPosition == null) { _showSnack("Chưa có vị trí"); return; }
    setState(() { _isLoading = true; _sensitiveMarkers = []; });
    try {
      // Giả sử bạn có service này
      final areas = await _sensitiveService.findNearbySensitiveAreas(_currentPosition!, 3000);
      setState(() {
        _sensitiveMarkers = areas.map((a) {
          final c = a['location']['value']['coordinates'][0];
          // Cẩn thận cấu trúc Polygon [ [ [lng, lat], ... ] ]
          final firstPoint = c[0];
          final cat = a['category']['value'];
          IconData icon = Icons.place; Color color = Colors.grey;
          if(cat == 'school') { icon = Icons.school; color = Colors.blue; }
          else if(cat == 'hospital') { icon = Icons.local_hospital; color = Colors.red; }

          return Marker(
              point: LatLng(firstPoint[1], firstPoint[0]),
              child: Icon(icon, color: color, size: 30)
          );
        }).toList();
      });
      _showSnack('Đã tải ${areas.length} khu vực');
    } catch(e) { _showSnack('Lỗi tải khu vực nhạy cảm'); } finally { setState(() => _isLoading = false); }
  }

  Future<void> _fetchForecasts() async {
    setState(() { _isLoading = true; });
    try {
      final forecasts = await _forecastService.getAqiForecasts();
      if(forecasts.isEmpty) { _showSnack("Chưa có dữ liệu dự báo"); return; }

      final circles = forecasts.map((f) {
        final loc = f['location']['value']['coordinates'];
        final pm25 = f['forecastedPM25']?['value'] ?? 0.0;
        return CircleMarker(
            point: LatLng(loc[1], loc[0]),
            radius: 2000, // Tăng bán kính để dễ nhìn
            useRadiusInMeter: true,
            color: _getAqiColor(pm25).withOpacity(0.4),
            borderColor: _getAqiColor(pm25),
            borderStrokeWidth: 1
        );
      }).toList();
      setState(() => _forecastCircles = circles.cast<CircleMarker>());
    } catch(e) {
      print(e);
    } finally { setState(() => _isLoading = false); }
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
            ? const Icon(Icons.navigation, color: Colors.blue, size: 40)
            : const Icon(Icons.my_location, color: Colors.blue, size: 30),
      ));
    }
    if (_startPoint != null && _startPoint != _currentPosition) {
      allMarkers.add(Marker(point: _startPoint!, child: const Icon(Icons.trip_origin, color: Colors.green, size: 35)));
    }
    if (_endPoint != null) {
      allMarkers.add(Marker(point: _endPoint!, child: const Icon(Icons.location_on, color: Colors.red, size: 35)));
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

          // --- 2. THANH TÌM KIẾM (NỔI) ---
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
                        decoration: const InputDecoration(
                          icon: Icon(Icons.my_location, color: Colors.green, size: 20),
                          hintText: "Chọn điểm đi",
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red, size: 20),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _endController,
                              decoration: const InputDecoration(
                                hintText: "Nhập điểm đến...",
                                border: InputBorder.none,
                              ),
                              style: const TextStyle(fontSize: 14),
                              onSubmitted: (_) => _handleSearchRoute(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.blue),
                            onPressed: _handleSearchRoute,
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // --- 3. CÁC NÚT CHỨC NĂNG (BÊN PHẢI) ---
          Positioned(
            bottom: 30, right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'clear',
                  onPressed: _clearMap,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.cleaning_services_outlined, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'zoomIn',
                  onPressed: () {
                    final z = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, z + 1);
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'zoomOut',
                  onPressed: () {
                    final z = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, z - 1);
                  },
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'gps',
                  onPressed: _determinePosition,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.gps_fixed, color: Colors.blue),
                ),
                const SizedBox(height: 10),
                if (!_isNavigating)
                  FloatingActionButton.small(
                    heroTag: 'layers',
                    onPressed: () => setState(() => _showLayers = !_showLayers),
                    backgroundColor: _showLayers ? Colors.blue : Colors.white,
                    child: const Icon(Icons.layers, color: Colors.black87),
                  ),
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
              child: FloatingActionButton.extended(
                heroTag: 'nav',
                onPressed: _startNavigation,
                icon: const Icon(Icons.navigation),
                label: const Text("Bắt đầu đi"),
                backgroundColor: Colors.green,
              ),
            ),

          if (_isNavigating)
            Positioned(
              bottom: 30, left: 16,
              child: FloatingActionButton.extended(
                heroTag: 'stop',
                onPressed: _stopNavigation,
                icon: const Icon(Icons.close),
                label: const Text("Thoát"),
                backgroundColor: Colors.red,
              ),
            ),

          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildLayerBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: () {
            onTap();
            setState(() => _showLayers = false);
          },
          backgroundColor: color,
          child: Icon(icon, color: Colors.white),
        ),
      ],
    );
  }
}