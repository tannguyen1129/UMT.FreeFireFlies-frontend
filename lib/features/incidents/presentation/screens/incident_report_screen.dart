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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

// Services
import '../../services/incident_service.dart';

class IncidentReportScreen extends StatefulWidget {
  final LatLng initialCenter;

  const IncidentReportScreen({Key? key, required this.initialCenter})
      : super(key: key);

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  // Services & Controllers
  final IncidentService _incidentService = IncidentService();
  final TextEditingController _descriptionController = TextEditingController();
  final MapController _mapController = MapController();
  final ImagePicker _picker = ImagePicker();

  // State Variables
  LatLng? _incidentLocation;
  bool _isLoading = false;

  late Future<List<dynamic>> _incidentTypesFuture;
  int? _selectedIncidentTypeId;

  // Danh sách ảnh đã chọn (Local)
  List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _incidentLocation = widget.initialCenter;
    _incidentTypesFuture = _incidentService.getIncidentTypes();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // --- 📍 LOGIC VỊ TRÍ ---
  void _handleMapTap(LatLng tapPosition) {
    setState(() {
      _incidentLocation = tapPosition;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('GPS chưa bật');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception('Quyền GPS bị từ chối');
      }

      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _incidentLocation = latLng;
        _mapController.move(latLng, 16.0);
      });
      _showSnack('Đã cập nhật vị trí hiện tại');
    } catch (e) {
      _showSnack('Lỗi GPS: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 📸 LOGIC ẢNH ---
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      print('Lỗi chọn ảnh: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      print('Lỗi chụp ảnh: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // --- 🚀 LOGIC GỬI BÁO CÁO ---
  Future<void> _submitReport() async {
    if (_incidentLocation == null) {
      _showSnack('Vui lòng chọn vị trí trên bản đồ.');
      return;
    }
    if (_selectedIncidentTypeId == null) {
      _showSnack('Vui lòng chọn loại sự cố.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Upload ảnh (Nếu có)
      String? uploadedImageUrl;

      if (_selectedImages.isNotEmpty) {
        // Hiện tại Backend chỉ lưu 1 URL ảnh, nên ta lấy ảnh đầu tiên
        // Hoặc bạn có thể upload hết và nối chuỗi, tùy logic backend
        File imageFile = File(_selectedImages.first.path);
        uploadedImageUrl = await _incidentService.uploadImage(imageFile);
      }

      // 2. Gửi báo cáo kèm URL ảnh
      await _incidentService.createIncident(
        location: _incidentLocation!,
        incidentTypeId: _selectedIncidentTypeId!,
        description: _descriptionController.text,
        imageUrl: uploadedImageUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Báo cáo thành công!')));
      Navigator.of(context).pop(); // Đóng màn hình
    } catch (e) {
      _showSnack('Lỗi: $e');
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F2),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        title: const Text(
          'Báo cáo Sự cố',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.send_rounded),
              onPressed: _submitReport,
              tooltip: 'Gửi báo cáo',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 1. BẢN ĐỒ (Phần trên)
                Expanded(
                  flex: 4,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: widget.initialCenter,
                          initialZoom: 16.0,
                          onTap: (_, point) => _handleMapTap(point),
                        ),
                        children: [
                          TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                          if (_incidentLocation != null)
                            MarkerLayer(markers: [
                              Marker(
                                point: _incidentLocation!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_on,
                                    color: Color(0xFFF44336), size: 40),
                              )
                            ]),
                        ],
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E7D32).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: FloatingActionButton.small(
                            onPressed: _useCurrentLocation,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            child: const Icon(Icons.my_location_rounded,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. FORM NHẬP LIỆU (Phần dưới)
                Expanded(
                  flex: 6,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      const Text(
                        'Thông tin chi tiết',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dropdown Loại sự cố
                      FutureBuilder<List<dynamic>>(
                        future: _incidentTypesFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData)
                            return const LinearProgressIndicator();
                          return DropdownButtonFormField<int>(
                            value: _selectedIncidentTypeId,
                            hint: const Text('Chọn loại sự cố'),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Color(0xFF2E7D32), width: 2),
                              ),
                              prefixIcon: const Icon(Icons.category_rounded,
                                  color: Color(0xFF2E7D32)),
                            ),
                            items: snapshot.data!
                                .map((type) => DropdownMenuItem<int>(
                                      value: type['type_id'],
                                      child: Text(type['type_name']),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedIncidentTypeId = v),
                          );
                        },
                      ),
                      const SizedBox(height: 15),

                      // Input Mô tả
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Mô tả thêm',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: Color(0xFF2E7D32), width: 2),
                          ),
                          prefixIcon: const Icon(Icons.description_rounded,
                              color: Color(0xFF2E7D32)),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      // Chọn ảnh
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Hình ảnh minh chứng:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: _takePhoto,
                                icon: const Icon(Icons.camera_alt_rounded,
                                    color: Color(0xFF2E7D32)),
                                tooltip: 'Chụp ảnh',
                              ),
                              IconButton(
                                onPressed: _pickImages,
                                icon: const Icon(Icons.photo_library_rounded,
                                    color: Color(0xFF2E7D32)),
                                tooltip: 'Chọn từ thư viện',
                              ),
                            ],
                          )
                        ],
                      ),

                      // Hiển thị ảnh
                      if (_selectedImages.isNotEmpty)
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2E7D32)
                                              .withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                      image: DecorationImage(
                                        image: FileImage(
                                            File(_selectedImages[index].path)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 14,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.close_rounded,
                                            size: 16, color: Color(0xFFF44336)),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text('Chưa có ảnh nào.',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
