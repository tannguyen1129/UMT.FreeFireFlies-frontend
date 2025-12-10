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

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
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
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => const IncidentReportScreen(
              initialCenter: initialPos,
            ),
          ),
        )
        .then((_) => _loadIncidents());
  }

  // ... (Giữ nguyên các hàm helper màu sắc _getStatusColor, _getStatusText) ...
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'verified':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Đang chờ duyệt';
      case 'verified':
        return 'Đã xác minh';
      case 'in_progress':
        return 'Đang xử lý';
      case 'resolved':
        return 'Đã giải quyết';
      case 'rejected':
        return 'Đã từ chối';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7F2),
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
                    Icon(isAuthError ? Icons.lock_clock : Icons.error_outline,
                        size: 48, color: Colors.red),
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
                          Provider.of<AuthStateProvider>(context, listen: false)
                              .logout();
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có báo cáo nào',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bấm nút + để tạo báo cáo mới',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
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
                final typeName =
                    incident['incidentType']?['type_name'] ?? 'Sự cố';
                final date = DateTime.tryParse(incident['created_at'] ?? '') ??
                    DateTime.now();

                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        status == 'resolved'
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: _getStatusColor(status),
                        size: 28,
                      ),
                    ),
                    title: Text(
                      typeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          incident['description'] ?? 'Không có mô tả',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              "${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Refresh button
          FloatingActionButton.small(
            onPressed: _loadIncidents,
            tooltip: 'Làm mới',
            backgroundColor: Colors.white,
            elevation: 4,
            child: const Icon(Icons.refresh_rounded, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 12),
          // Add report button
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _navigateToReportScreen,
              tooltip: 'Báo cáo Mới',
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(Icons.add_alert, size: 28, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
