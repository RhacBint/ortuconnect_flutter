import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/session_manager.dart';
import '../login/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String baseUrl = "https://ortuconnect.pbltifnganjuk.com/api/profile.php";
  bool isLoading = true;
  Map<String, dynamic>? profileData;
  String? username;

  @override
  void initState() {
    super.initState();
    _loadUsernameAndData();
  }

  Future<void> _loadUsernameAndData() async {
    username = await SessionManager().getUsername();
    if (username != null && username!.isNotEmpty) {
      await _fetchProfileData();
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl?username=$username"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            profileData = data['data'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateProfile(Map<String, String> updatedData) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        body: {'username': username, ...updatedData},
      );
      if (response.statusCode == 200) {
        // Update gender icon di SharedPreferences agar dashboard ikut berubah
        final newGender = updatedData['gender'] ?? '';
        if (newGender.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_gender_icon',
              newGender.toLowerCase() == 'perempuan' ? 'cewe' : 'cowo');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berhasil update profil')),
          );
        }
        await _fetchProfileData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal update')),
          );
        }
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
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
                          initialDate: DateTime.parse(dateController.text.isNotEmpty ? dateController.text : "2010-01-01"),
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
                      value: ["Laki-Laki", "Perempuan"].contains(selectedGender) ? selectedGender : "Laki-Laki",
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
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
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
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Ya"),
          ),
        ],
      ),
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
    final String imagePath = gender.toLowerCase() == "perempuan"
        ? "assets/images/icon_cewe.png"
        : "assets/images/icon_cowo.png";

    return Scaffold(
      backgroundColor: const Color(0xFF0F53BF),
      body: Column(
        children: [
          // Header biru
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  // AppBar row
                  Row(
                    children: [
                      const SizedBox(width: 48),
                      const Expanded(
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
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.white,
                        child: ClipOval(
                          child: Image.asset(imagePath, width: 96, height: 96, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showEditDialog,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F53BF),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Image.asset(
                              'assets/images/ic_edit.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profileData?['nama_siswa'] ?? "-",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (profileData?['kelas'] ?? "-").toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Body putih dengan rounded top
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
                    // Section Identitas Anak
                    const Text(
                      'Identitas Anak',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow("Nama Anak:", profileData?['nama_siswa'] ?? "-"),
                    _buildInfoRow("Alamat:", profileData?['alamat'] ?? "-"),
                    _buildInfoRow("Tanggal Lahir:", profileData?['tanggal_lahir'] ?? "-"),
                    _buildInfoRow("Gender:", profileData?['gender'] ?? "-"),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Section Identitas Orangtua
                    const Text(
                      'Identitas Orangtua',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow("Nama Orang Tua:", profileData?['nama_ortu'] ?? "-"),
                    _buildInfoRow("Nomor Telepon:", profileData?['no_telp_ortu'] ?? "-"),

                    const SizedBox(height: 32),

                    // Tombol Keluar
                    Center(
                      child: TextButton(
                        onPressed: _logout,
                        child: const Text(
                          'KELUAR DARI PERANGKAT',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.5,
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
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
