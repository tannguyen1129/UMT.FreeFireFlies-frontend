/*
 * Copyright 2025 Green-AQI Navigator Team
 * Apache License 2.0
 * 
 * UI REFACTORED - Giữ nguyên 100% Logic
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

// ============================================
// 🎨 DESIGN SYSTEM - COLORS & STYLES
// ============================================
class AppColors {
  static const primary = Color(0xFF2E7D32);
  static const primaryLight = Color(0xFF66BB6A);
  static const primaryDark = Color(0xFF1B5E20);
  static const accent = Color(0xFF81C784);

  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFA726);
  static const error = Color(0xFFEF5350);
  static const info = Color(0xFF29B6F6);

  static const background = Color(0xFFF8F9FA);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF1F3F4);

  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
  static const textHint = Color(0xFF9E9E9E);

  static const divider = Color(0xFFE0E0E0);
  static const border = Color(0xFFE0E0E0);
}

class AppTextStyles {
  static const h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}

class AppShadows {
  static final small = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static final medium = [
    BoxShadow(
      color: Colors.black.withOpacity(0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static final large = [
    BoxShadow(
      color: Colors.black.withOpacity(0.16),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static final primaryGlow = [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.3),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}

enum SnackType { success, error, warning, info }

// ============================================
// 🏠 HOME SCREEN
// ============================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Controllers
  final MapController _mapController = MapController();
  final TextEditingController _startController =
      TextEditingController(text: "Vị trí của tôi");
  final TextEditingController _endController = TextEditingController();

  // Services
  final _routeService = RoutePlanningService();
  final _greenSpaceService = GreenSpaceService();
  final _forecastService = ForecastService();
  final _sensitiveService = SensitiveAreaService();
  final _geocodingService = GeocodingService();
  final _perceptionService = PerceptionService();
  final _incidentService = IncidentService();

  // Dữ liệu đường bao vùng biển chủ quyền
  final List<Marker> _sovereigntyMarkers = [
    Marker(
      point: const LatLng(16.5, 112.0),
      width: 160,
      height: 60,
      child: Column(children: [
        const Icon(Icons.flag, color: Colors.red, size: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(4),
            boxShadow: AppShadows.small,
          ),
          child: const Text(
            "HOÀNG SA (VIỆT NAM)",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        )
      ]),
    ),
    Marker(
      point: const LatLng(9.0, 113.0),
      width: 160,
      height: 60,
      child: Column(children: [
        const Icon(Icons.flag, color: Colors.red, size: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(4),
            boxShadow: AppShadows.small,
          ),
          child: const Text(
            "TRƯỜNG SA (VIỆT NAM)",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
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
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && _checkAuth() && !_isNavigating) {
        _fetchForecasts();
        _fetchIncidents();
      }
    });
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    if (!_checkAuth()) return;

    await _determinePosition();
    if (_checkAuth()) _loadKmlPolygon();
    if (_checkAuth()) {
      _fetchUserProfile();
      _fetchIncidents();
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted && _checkAuth()) {
      _fetchForecasts();
    }
    _setupFCMListener();
  }

  bool _checkAuth() {
    if (!mounted) return false;
    return Provider.of<AuthStateProvider>(context, listen: false)
        .isAuthenticated;
  }

  void _setupFCMListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        _showSnack(
          "🔔 ${message.notification!.title}",
          type: SnackType.info,
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
  // 🔇 HÀM FETCH (GIỮ NGUYÊN LOGIC - KHÔNG THAY ĐỔI)
  // ===============================================================

  Future<void> _loadKmlPolygon() async {
    try {
      final kmlString = await rootBundle.loadString('assets/kml/HCMC.kml');
      final rawPolygons = await compute(parseKmlInBackground, kmlString);

      final polygons = rawPolygons
          .map((points) => Polygon(
                points: points,
                color: AppColors.primary.withOpacity(0.05),
                borderColor: AppColors.primary,
                borderStrokeWidth: 1.5,
                isFilled: true,
              ))
          .toList();

      if (mounted) {
        setState(() {
          _hcmcPolygons = polygons;
          _isMapLoading = false;
        });
        if (_currentPosition == null)
          _mapController.move(const LatLng(10.7769, 106.7009), 12.0);
      }
    } catch (e) {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  Future<void> _fetchForecasts() async {
    if (!_checkAuth()) return;

    try {
      final List<dynamic> forecasts = await _forecastService.getAqiForecasts();
      if (forecasts.isEmpty) return;

      final heatmapData = await compute(computeHeatmapData, forecasts);

      final circles = heatmapData.map((data) {
        final color = _getAqiColor(data['pm25']);
        return CircleMarker(
          point: LatLng(data['lat'], data['lng']),
          radius: 2000,
          useRadiusInMeter: true,
          color: color.withOpacity(0.15),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        );
      }).toList();

      final markers = <Marker>[];
      double maxPm = 0.0;

      for (var f in forecasts) {
        dynamic pm25Val;
        f.forEach((k, v) {
          if (k.toString().toLowerCase().contains('pm25')) {
            pm25Val = v;
          }
        });

        double pm25 = 0.0;
        if (pm25Val is Map) {
          dynamic inner = pm25Val['value'];
          if (inner is Map && inner.containsKey('@value'))
            inner = inner['@value'];
          pm25Val = inner;
        }
        if (pm25Val is num)
          pm25 = pm25Val.toDouble();
        else if (pm25Val is String) pm25 = double.tryParse(pm25Val) ?? 0.0;

        if (pm25 > maxPm) maxPm = pm25;

        dynamic locData;
        f.forEach((k, v) {
          if (k.toString().toLowerCase().contains('location')) locData = v;
        });

        List<dynamic>? coords;
        if (locData is Map) {
          if (locData.containsKey('value')) {
            dynamic val = locData['value'];
            if (val is Map && val.containsKey('coordinates'))
              coords = val['coordinates'];
            else if (val is Map && val['type'] == 'Point')
              coords = val['coordinates'];
          }
        }

        if (coords == null || coords.length < 2) continue;

        final pos = LatLng(
            (coords[1] as num).toDouble(), (coords[0] as num).toDouble());
        final color = _getAqiColor(pm25);

        final rawId = f['id'] ?? 'Trạm';
        final stationName =
            rawId.toString().split(':').last.replaceAll('OWM-', '');

        String timeStr = "Đang cập nhật";
        try {
          dynamic targetTimeValue;

          for (var key in f.keys) {
            if (key.toString().contains('validFrom')) {
              targetTimeValue = f[key];
              break;
            }
          }

          if (targetTimeValue == null) {
            for (var key in f.keys) {
              if (key.toString().contains('observationDateTime')) {
                targetTimeValue = f[key];
                break;
              }
            }
          }

          if (targetTimeValue is Map) {
            if (targetTimeValue.containsKey('value'))
              targetTimeValue = targetTimeValue['value'];
          }
          if (targetTimeValue is Map) {
            if (targetTimeValue.containsKey('@value'))
              targetTimeValue = targetTimeValue['@value'];
          }

          if (targetTimeValue != null) {
            String ts = targetTimeValue.toString();

            DateTime utcDate;
            try {
              DateTime temp = DateTime.parse(ts);
              if (!ts.endsWith('Z')) {
                utcDate = DateTime.utc(temp.year, temp.month, temp.day,
                    temp.hour, temp.minute, temp.second);
              } else {
                utcDate = temp.toUtc();
              }
            } catch (_) {
              utcDate = DateTime.now().toUtc();
            }

            final vnDate = utcDate.toLocal();
            timeStr =
                "${vnDate.hour.toString().padLeft(2, '0')}:${vnDate.minute.toString().padLeft(2, '0')} ${vnDate.day}/${vnDate.month}";
          }
        } catch (e) {
          print("Lỗi parse time: $e");
        }

        markers.add(Marker(
          point: pos,
          width: 45,
          height: 45,
          child: GestureDetector(
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
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403))
        return;
    }
  }

  Future<void> _fetchIncidents() async {
    if (!_checkAuth()) return;

    try {
      final incidents = await _incidentService.getAllIncidents();
      if (!mounted) return;

      final markers = <Marker>[];
      for (var inc in incidents) {
        final status = inc['status'] ?? 'pending';
        if (status == 'resolved' || status == 'rejected') continue;

        final loc = inc['location'];
        if (loc == null || loc['coordinates'] == null) continue;

        final lat = (loc['coordinates'][1] as num).toDouble();
        final lng = (loc['coordinates'][0] as num).toDouble();

        Color color = AppColors.error;
        if (status == 'verified') color = AppColors.warning;

        markers.add(Marker(
            point: LatLng(lat, lng),
            width: 35,
            height: 35,
            child: GestureDetector(
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (ctx) =>
                          AlertDialog(
                              title: const Text("Sự cố môi trường"),
                              content:
                                  Text(inc['description'] ?? 'Không có mô tả'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Đóng"))
                              ]));
                },
                child: Icon(Icons.warning_rounded, color: color, size: 30))));
      }

      setState(() => _incidentMarkers = markers);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 || e.response?.statusCode == 401)
        return;
    } catch (_) {}
  }

  Future<void> _fetchUserProfile() async {
    if (!_checkAuth()) return;
    try {
      final p = await ProfileService().getMyProfile();
      if (mounted)
        setState(() => _userHealthGroup = p['health_group'] ?? 'normal');
    } catch (e) {
      if (e is DioException && (e.response?.statusCode == 401)) return;
    }
  }

  Future<void> _determinePosition() async {
    try {
      bool s = await Geolocator.isLocationServiceEnabled();
      if (!s) return;
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied)
        p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          if (_startController.text == "Vị trí của tôi") {
            _startPoint = _currentPosition;
            _mapController.move(_currentPosition!, 14.0);
          }
          _updateDistance();
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSearchRoute() async {
    FocusScope.of(context).unfocus();
    if (mounted) setState(() => _isLoading = true);
    try {
      LatLng? s = _startController.text == "Vị trí của tôi"
          ? _currentPosition
          : await _geocodingService
              .getCoordinatesFromAddress(_startController.text);
      if (s == null) {
        await _determinePosition();
        s = _currentPosition;
      }
      if (s == null) throw "Thiếu điểm đi";

      LatLng? e = await _geocodingService
          .getCoordinatesFromAddress(_endController.text);
      if (e == null) throw "Thiếu điểm đến";

      setState(() {
        _startPoint = s;
        _endPoint = e;
      });

      final json = await _routeService.getRecommendedRoutes(s, e);
      final List features = json['features'] ?? [];
      final List<Polyline> lines = [];
      double totalDistance = 0.0;

      for (var f in features) {
        final coords = f['geometry']['coordinates'] as List;
        final pts = coords
            .map((c) =>
                LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
            .toList();
        final type = f['properties']['routeType'];

        if (totalDistance == 0.0) {
          const Distance distance = Distance();
          for (int i = 0; i < pts.length - 1; i++) {
            totalDistance += distance.as(LengthUnit.Meter, pts[i], pts[i + 1]);
          }
        }

        lines.add(Polyline(
            points: pts,
            color: type == 'cleanest' ? AppColors.success : AppColors.info,
            strokeWidth: type == 'cleanest' ? 6.0 : 4.0));
      }

      setState(() {
        _polylines = lines;
        _distanceKm = totalDistance / 1000;
      });

      final bounds = LatLngBounds.fromPoints([s, e]);
      _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
    } catch (e) {
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403))
        return;
      _showSnack("Lỗi tìm đường: $e", type: SnackType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startNavigation() {
    if (_currentPosition == null || _polylines.isEmpty) return;
    setState(() => _isNavigating = true);
    _showSnack("Bắt đầu dẫn đường!", type: SnackType.success);

    _positionStreamSubscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation,
                distanceFilter: 10))
        .listen((p) {
      if (mounted) {
        final np = LatLng(p.latitude, p.longitude);
        setState(() => _currentPosition = np);
        _mapController.move(np, 17.0);
      }
    });
  }

  void _stopNavigation({bool isDisposing = false}) {
    _positionStreamSubscription?.cancel();
    if (!isDisposing && mounted) {
      setState(() => _isNavigating = false);
      if (_distanceKm != null && _distanceKm! > 0.5) {
        final points = (_distanceKm! * 10).round();
        try {
          ProfileService().addPoints(points);
        } catch (_) {}

        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text("🎉 Chuyến đi hoàn tất!"),
                    content: Text(
                        "Bạn nhận được $points Điểm Xanh vì đã chọn lộ trình sạch."),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Tuyệt vời"))
                    ]));
      }
      if (_currentPosition != null)
        _mapController.move(_currentPosition!, 14.0);
    }
  }

  Future<void> _toggleParks() async {
    setState(() => _layerParks = !_layerParks);
    if (_layerParks) {
      setState(() => _isLoading = true);
      try {
        final parks = await _greenSpaceService.findNearbyGreenSpaces(
            _currentPosition!, 3000);
        setState(() => _parkMarkers = parks.map((p) {
              final coords = p['location']['value']['coordinates'];
              double lat = (coords[0][0][1] as num).toDouble();
              double lng = (coords[0][0][0] as num).toDouble();
              final name = p['name']?['value'] ?? 'Công viên xanh';

              return Marker(
                  point: LatLng(lat, lng),
                  width: 45,
                  height: 45,
                  child: GestureDetector(
                      onTap: () => _showPlaceInfo(name, LatLng(lat, lng),
                          Icons.park, AppColors.success),
                      child: const Icon(Icons.park,
                          color: AppColors.success, size: 35)));
            }).toList());
        _showSnack("Đã tìm thấy ${parks.length} công viên",
            type: SnackType.success);
      } catch (e) {
        if (e is DioException &&
            (e.response?.statusCode == 401 || e.response?.statusCode == 403))
          return;
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _parkMarkers = []);
    }
  }

  void _showPlaceInfo(
      String name, LatLng location, IconData icon, Color color) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Row(children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(name, style: AppTextStyles.h3))
                ]),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bạn có muốn tìm đường đến địa điểm này không?",
                      style: AppTextStyles.body2,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}",
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("Đóng",
                          style: AppTextStyles.button
                              .copyWith(color: AppColors.textSecondary))),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        )),
                    icon: const Icon(Icons.directions, size: 20),
                    label: const Text("Đi đến đây"),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _endPoint = location;
                        _endController.text =
                            "${location.latitude}, ${location.longitude}";
                        _isSettingStart = false;
                      });
                      _handleSearchRoute();
                    },
                  )
                ]));
  }

  Future<void> _toggleSensitive() async {
    setState(() => _layerSensitive = !_layerSensitive);

    if (_layerSensitive) {
      setState(() => _isLoading = true);
      try {
        final areas = await _sensitiveService.findNearbySensitiveAreas(
            _currentPosition!, 3000);

        setState(() => _sensitiveMarkers = areas.map((a) {
              final rawLoc = a['location']['value'];
              List<dynamic> coords;

              if (rawLoc['type'] == 'Polygon') {
                coords = rawLoc['coordinates'][0][0];
              } else {
                coords = rawLoc['coordinates'];
              }

              double lat = (coords[1] as num).toDouble();
              double lng = (coords[0] as num).toDouble();

              String name = 'Khu vực nhạy cảm';
              if (a.containsKey('name')) {
                name = a['name']['value'] ?? name;
              }

              final cat = a['category']['value'];
              IconData icon = Icons.place;
              Color color = AppColors.textSecondary;

              if (cat == 'school') {
                icon = Icons.school;
                color = AppColors.info;
              } else if (cat == 'hospital') {
                icon = Icons.local_hospital;
                color = AppColors.error;
              }

              return Marker(
                  point: LatLng(lat, lng),
                  width: 45,
                  height: 45,
                  child: GestureDetector(
                      onTap: () =>
                          _showPlaceInfo(name, LatLng(lat, lng), icon, color),
                      child: Icon(icon, color: color, size: 35)));
            }).toList());

        _showSnack("Đã tìm thấy ${areas.length} khu vực nhạy cảm",
            type: SnackType.success);
      } catch (e) {
        if (e is DioException &&
            (e.response?.statusCode == 401 || e.response?.statusCode == 403))
          return;
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _sensitiveMarkers = []);
    }
  }

  void _showPerceptionDialog() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: const [
                  Icon(Icons.emoji_emotions,
                      color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Text("Cảm nhận không khí", style: AppTextStyles.h3),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPerceptionOption(
                    ctx,
                    Icons.sentiment_very_satisfied,
                    "Trong lành",
                    AppColors.success,
                    1,
                  ),
                  _buildPerceptionOption(
                    ctx,
                    Icons.sentiment_neutral,
                    "Bình thường",
                    AppColors.warning,
                    2,
                  ),
                  _buildPerceptionOption(
                    ctx,
                    Icons.sentiment_very_dissatisfied,
                    "Ô nhiễm",
                    AppColors.error,
                    3,
                  ),
                ],
              ),
            ));
  }

  Widget _buildPerceptionOption(
    BuildContext dialogContext,
    IconData icon,
    String label,
    Color color,
    int level,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _submitPerception(level, dialogContext),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Text(label, style: AppTextStyles.body1),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitPerception(int level, BuildContext dialogContext) async {
    Navigator.pop(dialogContext);
    if (_currentPosition == null) return;
    try {
      await _perceptionService.submitPerception(
          location: _currentPosition!, feeling: level);
      _showSnack("Cảm ơn đóng góp của bạn!", type: SnackType.success);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) return;
      _showSnack("Lỗi: $e", type: SnackType.error);
    }
  }

  void _showStationInfo(String name, double pm25, Color color, String time) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.location_on, color: color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(name, style: AppTextStyles.h3)),
                  ],
                ),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.1),
                              color.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Chỉ số PM2.5",
                                    style: AppTextStyles.caption),
                                const SizedBox(height: 4),
                                Text("${pm25.toStringAsFixed(1)}",
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: AppShadows.small),
                              child: Text(_getAqiLevel(pm25),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.info.withOpacity(0.3),
                                width: 1.5)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.info.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.psychology,
                                  color: AppColors.info, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.info,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "DỰ BÁO SỚM (30 PHÚT)",
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text("Khung giờ: $time",
                                      style: AppTextStyles.body1.copyWith(
                                        fontWeight: FontWeight.w600,
                                      )),
                                  const SizedBox(height: 4),
                                  Text(
                                      "Dữ liệu được AI phân tích từ mạng lưới quan trắc thời gian thực.",
                                      style: AppTextStyles.caption.copyWith(
                                          fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text("Đóng")),
                  ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          )),
                      child: const Text("Xem chi tiết"))
                ]));
  }

  Color _getAqiColor(double v) => v <= 12
      ? AppColors.success
      : v <= 35
          ? const Color(0xFFFDD835)
          : v <= 55
              ? AppColors.warning
              : AppColors.error;
  String _getAqiLevel(double v) => v <= 12
      ? "Tốt"
      : v <= 35
          ? "Trung bình"
          : v <= 55
              ? "Kém"
              : v <= 150
                  ? "Xấu"
                  : "Nguy hại";
  void _showSnack(String m, {SnackType type = SnackType.info}) {
    if (!mounted) return;
    Color bgColor;
    IconData icon;

    switch (type) {
      case SnackType.success:
        bgColor = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case SnackType.error:
        bgColor = AppColors.error;
        icon = Icons.error_outline;
        break;
      case SnackType.warning:
        bgColor = AppColors.warning;
        icon = Icons.warning_amber_outlined;
        break;
      default:
        bgColor = AppColors.info;
        icon = Icons.info_outline;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(m,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _updateDistance() {
    if (_startPoint != null && _endPoint != null) {
      final d = Geolocator.distanceBetween(_startPoint!.latitude,
          _startPoint!.longitude, _endPoint!.latitude, _endPoint!.longitude);
      setState(() => _distanceKm = d / 1000);
    }
  }

  void _activatePickMode() {
    setState(() => _isPickingLocation = true);
    _showSnack("Chạm vào bản đồ để chọn điểm đến 📍", type: SnackType.info);
  }

  void _clearMap() {
    setState(() {
      _polylines = [];
      _parkMarkers = [];
      _sensitiveMarkers = [];
      _incidentMarkers = [];
      _forecastCircles = [];
      _aqiMarkers = [];
      _startPoint = null;
      _endPoint = null;
      _distanceKm = null;
      _startController.text = "Vị trí của tôi";
      _endController.clear();
      _isNavigating = false;
      _layerParks = false;
      _layerSensitive = false;
      _layerForecast = false;
      _isPickingLocation = false;
    });
    _determinePosition();
  }

  void _handleMapTap(LatLng p) {
    if (_isNavigating) return;
    if (_isPickingLocation) {
      setState(() {
        _endPoint = p;
        _endController.text =
            "${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}";
        _isPickingLocation = false;
        if (!_isSettingStart) _isSettingStart = true;
        _updateDistance();
      });
      _showSnack("Đã chọn điểm đến ✅", type: SnackType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final allMarkers = [
      if (_currentPosition != null)
        Marker(
            point: _currentPosition!,
            width: 50,
            height: 50,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isNavigating ? Icons.navigation : Icons.my_location,
                color: AppColors.info,
                size: 30,
              ),
            )),
      if (_startPoint != null && _startPoint != _currentPosition)
        Marker(
            point: _startPoint!,
            width: 90,
            height: 90,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.medium,
                ),
                child: const Icon(Icons.trip_origin,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AppShadows.small,
                ),
                child: const Text("Bắt đầu",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppColors.success,
                    )),
              ),
            ])),
      if (_endPoint != null)
        Marker(
            point: _endPoint!,
            width: 90,
            height: 90,
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.medium,
                ),
                child: const Icon(Icons.location_on,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: AppShadows.small,
                ),
                child: const Text("Đến",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppColors.error,
                    )),
              ),
            ])),
      ..._parkMarkers,
      ..._sensitiveMarkers,
      ..._aqiMarkers,
      ..._incidentMarkers
    ];

    return Scaffold(
        backgroundColor: AppColors.background,
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
                if (!_isMapLoading) PolygonLayer(polygons: _hcmcPolygons),
                if (_layerForecast) CircleLayer(circles: _forecastCircles),
                PolylineLayer(polylines: _polylines),
                MarkerLayer(markers: [
                  ...allMarkers,
                  ..._sovereigntyMarkers,
                ]),
              ],
            ),
            if (_isLoading || _isMapLoading)
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                      ),
                    ),
                    child: const LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 4,
                    ),
                  )),
            if (!_isNavigating)
              Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: Column(children: [
                    _buildSearchBar(),
                    if (_layerForecast && _currentMaxPm25 > 0)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: HealthAdviceCard(
                              pm25: _currentMaxPm25,
                              userHealthGroup: _userHealthGroup))
                  ])),
            if (!_isNavigating)
              Positioned(bottom: 120, right: 16, child: _buildRightButtons()),
            if (!_isNavigating)
              Positioned(
                  bottom: 16, left: 16, right: 16, child: _buildBottomFilter()),
            if (_polylines.isNotEmpty && !_isNavigating)
              Positioned(
                  bottom: 90,
                  left: 40,
                  right: 40,
                  child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          AppColors.primary,
                          AppColors.primaryLight
                        ]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppShadows.primaryGlow,
                      ),
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16))),
                          onPressed: _startNavigation,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.navigation,
                                  color: Colors.white, size: 24),
                              SizedBox(width: 12),
                              Text("BẮT ĐẦU ĐI",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.white,
                                      letterSpacing: 1)),
                            ],
                          )))),
            // Banner khi đang chọn vị trí
            if (_isPickingLocation)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.large,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Chạm vào bản đồ để chọn điểm đến',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () {
                            setState(() => _isPickingLocation = false);
                            _showSnack("Đã hủy chọn vị trí",
                                type: SnackType.info);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.close,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_isNavigating)
              Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _stopNavigation(),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.stop, color: Colors.white, size: 28),
                                SizedBox(width: 12),
                                Text(
                                  'DỪNG ĐIỀU HƯỚNG',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )),
          ],
        ));
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.large,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.my_location,
                      color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _startController,
                    onTap: () => setState(() => _isSettingStart = true),
                    style: AppTextStyles.body1,
                    decoration: InputDecoration(
                      hintText: "Điểm đi",
                      hintStyle: AppTextStyles.body2,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_startController.text != "Vị trí của tôi")
                  IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.textSecondary,
                      onPressed: () => setState(
                          () => _startController.text = "Vị trí của tôi")),
              ],
            ),
          ),
          Divider(
              height: 1, color: AppColors.divider, indent: 56, endIndent: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on,
                      color: AppColors.error, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _endController,
                    onTap: () => setState(() => _isSettingStart = false),
                    onSubmitted: (_) => _handleSearchRoute(),
                    style: AppTextStyles.body1,
                    decoration: InputDecoration(
                      hintText: "Điểm đến",
                      hintStyle: AppTextStyles.body2,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                      icon: const Icon(Icons.search, size: 20),
                      color: Colors.white,
                      onPressed: _handleSearchRoute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightButtons() {
    return Column(children: [
      _buildActionButton(
        icon: Icons.add,
        onPressed: () {
          _mapController.move(
              _mapController.camera.center, _mapController.camera.zoom + 1);
        },
        heroTag: "z1",
      ),
      const SizedBox(height: 12),
      _buildActionButton(
        icon: Icons.remove,
        onPressed: () {
          _mapController.move(
              _mapController.camera.center, _mapController.camera.zoom - 1);
        },
        heroTag: "z2",
      ),
      const SizedBox(height: 12),
      _buildActionButton(
        icon: Icons.gps_fixed,
        onPressed: _determinePosition,
        heroTag: "gps",
      ),
      const SizedBox(height: 12),
      _buildActionButton(
        icon: Icons.add_location_alt,
        onPressed: _activatePickMode,
        isActive: _isPickingLocation,
        heroTag: "pick",
      ),
      const SizedBox(height: 12),
      _buildActionButton(
        icon: Icons.refresh,
        onPressed: _clearMap,
        heroTag: "refresh",
      ),
    ]);
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String heroTag,
    bool isActive = false,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive ? AppShadows.primaryGlow : AppShadows.medium,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Icon(
              icon,
              color: isActive ? Colors.white : AppColors.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomFilter() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.medium,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _buildFilterChip("AQI", Icons.cloud, AppColors.warning,
              _layerForecast, _fetchForecasts),
          const SizedBox(width: 8),
          _buildFilterChip("Công viên", Icons.park, AppColors.success,
              _layerParks, _toggleParks),
          const SizedBox(width: 8),
          _buildFilterChip("Nhạy cảm", Icons.local_hospital, AppColors.error,
              _layerSensitive, _toggleSensitive),
          const SizedBox(width: 8),
          _buildFilterChip("Cảm nhận", Icons.emoji_emotions, AppColors.info,
              false, _showPerceptionDialog),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    IconData icon,
    Color color,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Material(
      color: isActive ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive ? Colors.transparent : AppColors.border,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? Colors.white : color,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
