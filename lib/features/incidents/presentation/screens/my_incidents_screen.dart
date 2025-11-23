import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:latlong2/latlong.dart';
import 'incident_report_screen.dart';
import '../../services/incident_service.dart';

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

    // 🚀 LẮNG NGHE THÔNG BÁO ĐỂ TỰ ĐỘNG REFRESH
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 Có cập nhật mới, đang tải lại danh sách...");
      _loadIncidents(); // Gọi hàm tải lại dữ liệu

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
    // Lấy vị trí mặc định (nếu không có GPS)
    const LatLng initialPos = LatLng(10.7769, 106.7009);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const IncidentReportScreen(
          initialCenter: initialPos,
        ),
      ),
    ).then((_) => _loadIncidents()); // Load lại khi quay về từ màn hình báo cáo
  }

  // Helper đổi màu trạng thái
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIncidents, // Nút reload thủ công
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _myIncidentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Lỗi tải báo cáo:\n${snapshot.error}',
                  textAlign: TextAlign.center,
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