import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/session_manager.dart';
import '../login/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String baseUrl = "https://ortuconnect.pbltifnganjuk.com/api/profile.php";
  final String uploadUrl = "https://ortuconnect.pbltifnganjuk.com/api/upload_photo.php";

  bool isLoading = true;
  bool _isUploadingPhoto = false;
  Map<String, dynamic>? profileData;
  String? username;
  String _photoUrl = '';

  static const String _keyPhotoUrl = 'profile_photo_url';

  @override
  void initState() {
    super.initState();
    _loadUsernameAndData();
  }

  Future<void> _loadUsernameAndData() async {
    username = await SessionManager().getUsername();
    final prefs = await SharedPreferences.getInstance();
    _photoUrl = prefs.getString(_keyPhotoUrl) ?? '';
    if (username != null && username!.isNotEmpty) {
      await _fetchProfileData();
    } else {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl?username=$username"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          // Cek apakah server mengembalikan photo_url
          final serverPhoto = data['data']?['photo_url']?.toString() ?? '';
          if (serverPhoto.isNotEmpty) {
            _photoUrl = serverPhoto;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyPhotoUrl, serverPhoto);
          }
          if (mounted) {
            setState(() {
              profileData = data['data'];
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Pilih Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0F53BF)),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF68327E)),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            if (_photoUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Hapus Foto', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(ctx, null),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;

    // Hapus foto
    if (source == null && _photoUrl.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPhotoUrl);
      setState(() => _photoUrl = '');
      return;
    }

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.fields['username'] = username ?? '';
      request.files.add(await http.MultipartFile.fromPath('photo', picked.path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final newUrl = data['photo_url']?.toString() ?? '';
          if (newUrl.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyPhotoUrl, newUrl);
            if (mounted) setState(() => _photoUrl = newUrl);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Foto profil berhasil diperbarui')),
            );
          }
        } else {
          _showError(data['message']?.toString() ?? 'Gagal upload foto');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Gagal upload foto: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _updateProfile(Map<String, String> updatedData) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {'username': username, ...updatedData},
      );
      if (response.statusCode == 200) {
        String serverMessage = 'Berhasil update profil';
        try {
          final resBody = json.decode(response.body) as Map<String, dynamic>;
          if (resBody['success'] == true) {
            serverMessage = resBody['message']?.toString() ?? 'Berhasil update profil';
          } else {
            final errMsg = resBody['message']?.toString() ?? 'Gagal update profil';
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
              );
            }
            return;
          }
        } catch (_) {}

        final newGender = updatedData['gender'] ?? '';
        if (newGender.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_gender_icon',
              newGender.toLowerCase() == 'perempuan' ? 'cewe' : 'cowo');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(serverMessage)),
          );
        }
        await _fetchProfileData();
      } else {
        String errMsg = 'Gagal update (${response.statusCode})';
        try {
          final resBody = json.decode(response.body) as Map<String, dynamic>;
          errMsg = resBody['message']?.toString() ?? errMsg;
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan koneksi'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showEditDialog() {
    if (profileData == null) return;
    final nameController = TextEditingController(text: profileData!['nama_siswa']);
    final dateController = TextEditingController(text: profileData!['tanggal_lahir']);
    final addressController = TextEditingController(text: profileData!['alamat']);
    final parentNameController = TextEditingController(text: profileData!['nama_ortu']);
    final phoneController = TextEditingController(text: profileData!['no_telp_ortu']);
    String selectedGender = profileData!['gender'] ?? 'Laki-Laki';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Edit Data Profil"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameController, "Nama Anak"),
                GestureDetector(
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(dateController.text) ?? DateTime(2010),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      setDialogState(() {
                        dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: _buildTextField(dateController, "Tanggal Lahir (YYYY-MM-DD)"),
                  ),
                ),
                _buildTextField(addressController, "Alamat"),
                DropdownButtonFormField<String>(
                  initialValue: ["Laki-Laki", "Perempuan"].contains(selectedGender)
                      ? selectedGender
                      : "Laki-Laki",
                  items: const [
                    DropdownMenuItem(value: "Laki-Laki", child: Text("Laki-Laki")),
                    DropdownMenuItem(value: "Perempuan", child: Text("Perempuan")),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedGender = value);
                  },
                  decoration: const InputDecoration(labelText: "Gender"),
                ),
                _buildTextField(parentNameController, "Nama Orang Tua"),
                _buildTextField(phoneController, "Nomor Telepon"),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateProfile({
                  'nama_siswa': nameController.text,
                  'tanggal_lahir': dateController.text,
                  'alamat': addressController.text,
                  'gender': selectedGender,
                  'nama_ortu': parentNameController.text,
                  'no_telp_ortu': phoneController.text,
                });
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi"),
        content: const Text("Apakah Anda yakin ingin keluar dari perangkat?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tidak")),
          TextButton(
            onPressed: () async {
              await SessionManager().logoutUser();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Ya"),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String genderImagePath) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: Colors.white,
          child: ClipOval(
            child: _isUploadingPhoto
                ? const SizedBox(
                    width: 96, height: 96,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _photoUrl.isNotEmpty
                    ? Image.network(
                        _photoUrl,
                        width: 96, height: 96, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Image.asset(genderImagePath, width: 96, height: 96, fit: BoxFit.cover),
                      )
                    : Image.asset(genderImagePath, width: 96, height: 96, fit: BoxFit.cover),
          ),
        ),
        // Tombol edit foto
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadPhoto,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF0F53BF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
        // Tombol edit data (pojok kiri bawah)
        Positioned(
          bottom: 0,
          left: 0,
          child: GestureDetector(
            onTap: _showEditDialog,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF68327E),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(7),
              child: Image.asset('assets/images/ic_edit.png', fit: BoxFit.contain),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF007ABF), Color(0xFF45287F), Color(0xFF68327E)],
          ),
        ),
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final String gender = profileData?['gender'] ?? "";
    final String genderImagePath = gender.toLowerCase() == "perempuan"
        ? "assets/images/icon_cewe.png"
        : "assets/images/icon_cowo.png";

    return Scaffold(
      backgroundColor: const Color(0xFF0F53BF),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  const Row(
                    children: [
                      SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          'Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildAvatar(genderImagePath),
                  const SizedBox(height: 12),
                  Text(
                    profileData?['nama_siswa'] ?? "-",
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (profileData?['kelas'] ?? "-").toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70, fontSize: 14,
                      fontWeight: FontWeight.w600, letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Identitas Anak',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 12),
                    _buildInfoRow("Nama Anak:", profileData?['nama_siswa'] ?? "-"),
                    _buildInfoRow("Alamat:", profileData?['alamat'] ?? "-"),
                    _buildInfoRow("Tanggal Lahir:", profileData?['tanggal_lahir'] ?? "-"),
                    _buildInfoRow("Gender:", profileData?['gender'] ?? "-"),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text('Identitas Orangtua',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 12),
                    _buildInfoRow("Nama Orang Tua:", profileData?['nama_ortu'] ?? "-"),
                    _buildInfoRow("Nomor Telepon:", profileData?['no_telp_ortu'] ?? "-"),
                    const SizedBox(height: 32),
                    Center(
                      child: TextButton(
                        onPressed: _logout,
                        child: const Text(
                          'KELUAR DARI PERANGKAT',
                          style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold,
                            fontSize: 15, letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
