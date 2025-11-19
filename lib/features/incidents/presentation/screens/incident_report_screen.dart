import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/incident_service.dart'; // 👈 Sửa: Import service

class IncidentReportScreen extends StatefulWidget {
  final LatLng initialCenter;

  const IncidentReportScreen({Key? key, required this.initialCenter}) : super(key: key);

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final IncidentService _incidentService = IncidentService();
  final _descriptionController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng? _incidentLocation;
  bool _isLoading = false;

  // 🚀 BIẾN TRẠNG THÁI MỚI CHO DROPDOWN
  late Future<List<dynamic>> _incidentTypesFuture;
  int? _selectedIncidentTypeId; // ID của loại sự cố đã chọn

  @override
  void initState() {
    super.initState();
    _incidentLocation = widget.initialCenter;
    // 🚀 Tải danh sách loại sự cố khi màn hình mở ra
    _incidentTypesFuture = _incidentService.getIncidentTypes();
  }

  void _handleMapTap(LatLng tapPosition) {
    setState(() {
      _incidentLocation = tapPosition;
    });
  }

  Future<void> _submitReport() async {
    if (_incidentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn vị trí sự cố trên bản đồ')),
      );
      return;
    }

    // 🚀 SỬA LỖI: Bắt buộc chọn loại sự cố
    if (_selectedIncidentTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn loại sự cố')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    print('--- (FLUTTER) Bắt đầu gửi báo cáo...');
    print('--- (FLUTTER) Vị trí: ${_incidentLocation.toString()}');
    print('--- (FLUTTER) Loại ID: $_selectedIncidentTypeId');

    try {
      await _incidentService.createIncident(
        location: _incidentLocation!,
        incidentTypeId: _selectedIncidentTypeId!, // 👈 Gửi ID đã chọn
        description: _descriptionController.text,
      );

      print('--- (FLUTTER) Gửi báo cáo THÀNH CÔNG!');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Báo cáo sự cố thành công!')),
      );
      Navigator.of(context).pop();

    } catch (e) {
      print('--- (FLUTTER) GẶP LỖI: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi báo cáo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo Sự cố Mới'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _submitReport,
              tooltip: 'Gửi báo cáo',
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. BẢN ĐỒ (chiếm 40% màn hình)
          Expanded(
            flex: 4, // 40%
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialCenter,
                initialZoom: 16.0,
                onTap: (tapPosition, point) => _handleMapTap(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                if (_incidentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _incidentLocation!,
                        child: const Icon(Icons.warning, color: Colors.red, size: 40.0),
                      )
                    ],
                  ),
              ],
            ),
          ),

          // 2. FORM NHẬP LIỆU (chiếm 60% màn hình)
          Expanded(
            flex: 6, // 60%
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Text(
                    'Chạm vào bản đồ để chọn vị trí sự cố.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // 🚀 SỬA LỖI: DÙNG FutureBuilder ĐỂ TẢI VÀ HIỂN THỊ DROPDOWN
                  FutureBuilder<List<dynamic>>(
                    future: _incidentTypesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Lỗi tải loại sự cố: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text('Không tìm thấy loại sự cố.'));
                      }

                      // Dữ liệu (danh sách các loại sự cố)
                      final types = snapshot.data!;

                      return DropdownButtonFormField<int>(
                        value: _selectedIncidentTypeId,
                        hint: const Text('Chọn loại sự cố...'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          icon: Icon(Icons.category),
                        ),
                        items: types.map((type) {
                          return DropdownMenuItem<int>(
                            value: type['type_id'], // 👈 ID
                            child: Text(type['type_name']), // 👈 Tên
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _selectedIncidentTypeId = newValue;
                          });
                        },
                        validator: (value) => value == null ? 'Vui lòng chọn loại sự cố' : null,
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả (Tùy chọn)',
                      border: OutlineInputBorder(),
                      icon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}