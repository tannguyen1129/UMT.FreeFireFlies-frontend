import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart'; // Cần cho LatLng
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
  }

  void _loadIncidents() {
    setState(() {
      _myIncidentsFuture = _incidentService.getMyIncidents();
    });
  }

  void _navigateToReportScreen() {
    // Tạm thời dùng vị trí giả lập, sau này chúng ta sẽ lấy từ Provider
    const LatLng initialPos = LatLng(10.7769, 106.7009);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const IncidentReportScreen(
          initialCenter: initialPos,
        ),
      ),
    ).then((_) => _loadIncidents()); // 👈 Tự động tải lại danh sách sau khi báo cáo
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<dynamic>>(
        future: _myIncidentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // ⚠️ LỖI CHẮC CHẮN SẼ XẢY RA
            // (Vì API 'GET /aqi/incidents/me' chưa tồn tại)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Lỗi tải báo cáo (Backend API /aqi/incidents/me chưa được tạo):\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Bạn chưa có báo cáo nào.'));
          }

          final incidents = snapshot.data!;

          return ListView.builder(
            itemCount: incidents.length,
            itemBuilder: (context, index) {
              final incident = incidents[index];
              return ListTile(
                leading: Icon(
                  incident['status'] == 'pending' ? Icons.hourglass_top : Icons.check_circle,
                  color: incident['status'] == 'pending' ? Colors.orange : Colors.green,
                ),
                title: Text(incident['description'] ?? 'Không có mô tả'),
                subtitle: Text('Trạng thái: ${incident['status']}'),
                // (Thêm các trường khác nếu muốn)
              );
            },
          );
        },
      ),
      // 🚀 NÚT BÁO CÁO MỚI (Task 1)
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToReportScreen,
        tooltip: 'Báo cáo Sự cố Mới',
        backgroundColor: Colors.red,
        child: const Icon(Icons.add_alert),
      ),
    );
  }
}