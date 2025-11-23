import 'package:flutter/material.dart';
import '../../services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({Key? key, required this.userData}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _agencyController;
  bool _isLoading = false;
  String _selectedHealthGroup = 'normal';

  @override
  void initState() {
    super.initState();
    // Điền sẵn dữ liệu cũ
    _nameController = TextEditingController(text: widget.userData['full_name'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phone_number'] ?? '');
    _agencyController = TextEditingController(text: widget.userData['agency_department'] ?? '');
    _selectedHealthGroup = widget.userData['health_group'] ?? 'normal';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _agencyController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _profileService.updateProfile(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        agency: _agencyController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!')));
      Navigator.of(context).pop(true); // Trả về true để màn hình trước reload lại

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chỉnh sửa Hồ sơ")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Avatar (Placeholder)
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 30),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (v) => v!.isEmpty ? 'Không được để trống' : null,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _agencyController,
                decoration: const InputDecoration(labelText: 'Cơ quan / Đơn vị', border: OutlineInputBorder(), prefixIcon: Icon(Icons.apartment)),
              ),
              const SizedBox(height: 30),

              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedHealthGroup,
                decoration: const InputDecoration(
                  labelText: 'Tình trạng sức khỏe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.health_and_safety),
                ),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Người bình thường')),
                  DropdownMenuItem(value: 'sensitive', child: Text('Nhạy cảm (Người già/Trẻ em)')),
                  DropdownMenuItem(value: 'respiratory', child: Text('Bệnh hô hấp (Hen suyễn...)')),
                  DropdownMenuItem(value: 'athlete', child: Text('Vận động viên ngoài trời')),
                ],
                onChanged: (val) => setState(() => _selectedHealthGroup = val!),
              ),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleUpdate,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('LƯU THAY ĐỔI', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}