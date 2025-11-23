import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

// Import các service
import '../../services/incident_service.dart';
import '../../../map/services/geocoding_service.dart';

class IncidentReportScreen extends StatefulWidget {
  final LatLng initialCenter;

  const IncidentReportScreen({Key? key, required this.initialCenter}) : super(key: key);

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  // Services & Controllers
  final IncidentService _incidentService = IncidentService();
  final GeocodingService _geocodingService = GeocodingService();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController(); // 👈 Controller địa chỉ
  final MapController _mapController = MapController();
  final ImagePicker _picker = ImagePicker();

  // State Variables
  LatLng? _incidentLocation;
  bool _isLoading = false;
  late Future<List<dynamic>> _incidentTypesFuture;
  int? _selectedIncidentTypeId;
  List<XFile> _selectedImages = []; // 👈 Danh sách ảnh đã chọn

  @override
  void initState() {
    super.initState();
    _incidentLocation = widget.initialCenter;
    _incidentTypesFuture = _incidentService.getIncidentTypes();

    // Lấy địa chỉ ban đầu (nếu có thể - tùy chọn)
    // _updateAddressText(_incidentLocation!);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // --- 📍 LOGIC VỊ TRÍ ---

  // 1. Xử lý chạm vào bản đồ
  void _handleMapTap(LatLng tapPosition) {
    setState(() {
      _incidentLocation = tapPosition;
    });
    // (Tùy chọn) Gọi Geocoding ngược để lấy tên đường từ tọa độ
    // _updateAddressText(tapPosition);
  }

  // 2. Lấy vị trí GPS hiện tại
  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      // Kiểm tra quyền (giản lược vì HomeScreen đã làm kỹ rồi)
      final position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _incidentLocation = latLng;
        _mapController.move(latLng, 16.0);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật vị trí hiện tại')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi GPS: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 3. Tìm vị trí từ địa chỉ nhập vào
  Future<void> _searchAddress() async {
    final address = _addressController.text;
    if (address.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final latLng = await _geocodingService.getCoordinatesFromAddress(address);
      if (latLng != null) {
        setState(() {
          _incidentLocation = latLng;
          _mapController.move(latLng, 16.0);
        });
        FocusScope.of(context).unfocus(); // Ẩn bàn phím
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy địa chỉ này.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tìm kiếm: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 📸 LOGIC ẢNH ---

  // Chọn nhiều ảnh
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

  // Chụp 1 ảnh từ Camera
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn vị trí.')));
      return;
    }
    if (_selectedIncidentTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn loại sự cố.')));
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // TODO: Upload ảnh lên server trước để lấy URL (Hiện tại demo gửi text list ảnh)
      // Trong thực tế, bạn cần upload từng file trong _selectedImages lên Cloudinary/S3/Server của bạn
      // sau đó lấy về danh sách URL chuỗi để gửi vào API createIncident.

      String imageUrls = _selectedImages.isNotEmpty
          ? "User selected ${_selectedImages.length} images (Upload logic pending)"
          : "";

      await _incidentService.createIncident(
        location: _incidentLocation!,
        incidentTypeId: _selectedIncidentTypeId!,
        description: _descriptionController.text,
        imageUrl: imageUrls, // Gửi URL ảnh (hoặc chuỗi mô tả tạm thời)
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Báo cáo thành công!')));
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo Sự cố'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _submitReport,
              tooltip: 'Gửi báo cáo',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // --- PHẦN 1: BẢN ĐỒ & CHỌN VỊ TRÍ (45%) ---
          Expanded(
            flex: 45,
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
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                    if (_incidentLocation != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _incidentLocation!,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        )
                      ]),
                  ],
                ),
                // Thanh tìm kiếm địa chỉ nằm trên bản đồ
                Positioned(
                  top: 10, left: 10, right: 10,
                  child: Card(
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: TextField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                hintText: 'Nhập địa chỉ hoặc tìm kiếm...',
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _searchAddress(),
                            ),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.search), onPressed: _searchAddress),
                        IconButton(icon: const Icon(Icons.my_location), onPressed: _useCurrentLocation),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- PHẦN 2: FORM NHẬP LIỆU (55%) ---
          Expanded(
            flex: 55,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text('Chi tiết sự cố', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // Dropdown Loại sự cố
                FutureBuilder<List<dynamic>>(
                  future: _incidentTypesFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    return DropdownButtonFormField<int>(
                      value: _selectedIncidentTypeId,
                      hint: const Text('Chọn loại sự cố'),
                      decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
                      items: snapshot.data!.map((type) => DropdownMenuItem<int>(
                        value: type['type_id'],
                        child: Text(type['type_name']),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedIncidentTypeId = v),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Input Mô tả
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả chi tiết',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                // --- KHU VỰC CHỌN ẢNH ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hình ảnh đính kèm:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(onPressed: _takePhoto, icon: const Icon(Icons.camera_alt), tooltip: 'Chụp ảnh'),
                        IconButton(onPressed: _pickImages, icon: const Icon(Icons.photo_library), tooltip: 'Chọn từ thư viện'),
                      ],
                    )
                  ],
                ),

                // Hiển thị danh sách ảnh đã chọn
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
                              margin: const EdgeInsets.only(right: 8),
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(File(_selectedImages[index].path)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0, right: 8,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
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
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('Chưa có ảnh nào được chọn', style: TextStyle(color: Colors.grey))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}