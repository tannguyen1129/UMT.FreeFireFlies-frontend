import 'package:dio/dio.dart'; // 👈 Import Dio để bắt lỗi DioException
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart'; // 👈 Import Provider
import 'incident_report_screen.dart';
import '../../services/incident_service.dart';
import '../providers/auth_state_provider.dart';

class MyIncidentsScreen extends StatefulWidget {
  const MyIncidentsScreen({Key? key}) : super(key: key);

  @override
  State<MyIncidentsScreen> createState() => _MyIncidentsScreenState();
}

class _MyIncidentsScreenState extends State<MyIncidentsScreen> {
  final IncidentService _incidentService = IncidentService();
  late Future<List<dynamic>> _myIncidentsFuture;

  @override
  void initState() {
    super.initState();
    _loadIncidents();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 Có cập nhật mới từ server...");
      _loadIncidents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Danh sách đã được cập nhật!'),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 1),
          ),
        );
      }
    });
  }

  void _loadIncidents() {
    setState(() {
      _myIncidentsFuture = _incidentService.getMyIncidents();
    });
  }

  void _navigateToReportScreen() {
    const LatLng initialPos = LatLng(10.7769, 106.7009);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const IncidentReportScreen(
          initialCenter: initialPos,
        ),
      ),
    ).then((_) => _loadIncidents());
  }

  // ... (Giữ nguyên các hàm helper màu sắc _getStatusColor, _getStatusText) ...
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'verified': return Colors.blue;
      case 'in_progress': return Colors.purple;
      case 'resolved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Đang chờ duyệt';
      case 'verified': return 'Đã xác minh';
      case 'in_progress': return 'Đang xử lý';
      case 'resolved': return 'Đã giải quyết';
      case 'rejected': return 'Đã từ chối';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử Báo cáo'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadIncidents)
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _myIncidentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 🔴 XỬ LÝ LỖI (ĐẶC BIỆT LÀ 403)
          if (snapshot.hasError) {
            final error = snapshot.error;
            bool isAuthError = false;

            // Kiểm tra xem có phải lỗi 403 Forbidden không
            if (error is DioException && error.response?.statusCode == 403) {
              isAuthError = true;
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        isAuthError ? Icons.lock_clock : Icons.error_outline,
                        size: 48,
                        color: Colors.red
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAuthError
                          ? 'Phiên đăng nhập đã hết hạn.\nVui lòng đăng nhập lại.'
                          : 'Lỗi tải dữ liệu:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (isAuthError)
                      ElevatedButton(
                        onPressed: () {
                          // Gọi hàm Logout từ Provider để quay về màn Login
                          Provider.of<AuthStateProvider>(context, listen: false).logout();
                        },
                        child: const Text("Đăng nhập lại"),
                      )
                    else
                      ElevatedButton(
                        onPressed: _loadIncidents,
                        child: const Text("Thử lại"),
                      ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Bạn chưa có báo cáo nào.'));
          }

          final incidents = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _loadIncidents(),
            child: ListView.builder(
              itemCount: incidents.length,
              itemBuilder: (context, index) {
                // ... (Giữ nguyên phần build Card như cũ) ...
                final incident = incidents[index];
                final status = incident['status'] ?? 'pending';
                final typeName = incident['incidentType']?['type_name'] ?? 'Sự cố';
                final date = DateTime.tryParse(incident['created_at'] ?? '') ?? DateTime.now();

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(status).withOpacity(0.2),
                      child: Icon(
                        status == 'resolved' ? Icons.check : Icons.report_problem,
                        color: _getStatusColor(status),
                      ),
                    ),
                    title: Text(typeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(incident['description'] ?? 'Không có mô tả'),
                        const SizedBox(height: 4),
                        Text(
                          "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}",
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(
                        _getStatusText(status),
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      backgroundColor: _getStatusColor(status),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToReportScreen,
        tooltip: 'Báo cáo Mới',
        backgroundColor: Colors.red,
        child: const Icon(Icons.add_alert),
      ),
    );
  }
}