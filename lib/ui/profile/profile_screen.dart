import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../core/api_service.dart';
import '../../core/session_manager.dart';
import '../login/login_screen.dart';

/// Halaman ProfileScreen [StatefulWidget]
/// 
/// Fungsi: Menjadi wadah (screen) utama untuk menampilkan informasi profil siswa 
/// beserta orang tuanya, serta menyediakan fitur pengeditan data dan foto profil.
/// Alur: Memanggil State [_ProfileScreenState] untuk mengelola siklus hidup widget,
/// memuat data dari server, dan merender antarmuka pengguna.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// State [_ProfileScreenState] dari [ProfileScreen]
/// 
/// Fungsi: Mengelola data profil, proses upload/delete foto, pembaruan profil,
/// dialog edit, proses logout, dan rendering visual komponen glassmorphism.
class _ProfileScreenState extends State<ProfileScreen> {
  // Key SharedPreferences untuk menyimpan URL foto profil secara lokal agar akses lebih cepat.
  static const String _keyPhotoUrl = 'profile_photo_url';
  
  // Status loading untuk menampilkan indikator putar (spinner) saat memuat data.
  bool isLoading = true;
  
  // Status loading khusus ketika proses upload atau hapus foto sedang berjalan.
  bool _isUploadingPhoto = false;
  
  // Map untuk menampung data profil mentah yang diterima dari API Server.
  Map<String, dynamic>? profileData;
  
  // Variabel untuk menyimpan URL foto profil aktif siswa.
  String _photoUrl = '';

  /// Fungsi: Inisialisasi State (Siklus hidup widget pertama kali dibuat)
  /// Alur:
  /// 1. Memanggil [super.initState()] untuk menjalankan fungsi bawaan Flutter.
  /// 2. Memanggil [_loadProfile()] secara asinkron untuk mengambil data profil terbaru.
  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Fungsi: Mengambil data profil dari backend API dan menyimpannya secara lokal.
  /// Alur:
  /// 1. Membuka SharedPreferences untuk mengambil foto profil cache lama (jika ada).
  /// 2. Melakukan request HTTP GET ke server melalui `ApiService().getProfile()`.
  /// 3. Jika berhasil (`success == true`):
  ///    - Menyimpan URL foto profil terbaru ke SharedPreferences jika tidak kosong.
  ///    - Menentukan ikon gender default ('cewe' / 'cowo') dan menyimpannya di SharedPreferences.
  ///    - Mengupdate `profileData` dan mengubah `isLoading = false` lewat `setState`.
  /// 4. Jika gagal karena unauthorized (token kedaluwarsa):
  ///    - Melakukan logout lokal via `SessionManager().logoutUser()`.
  ///    - Mengarahkan paksa pengguna kembali ke `LoginScreen` dan menghapus seluruh tumpukan halaman.
  /// 5. Jika error koneksi lainnya: Menghentikan loading spinner agar tidak stuck.
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _photoUrl = prefs.getString(_keyPhotoUrl) ?? '';
    try {
      final res = await ApiService().getProfile();
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        final serverFoto = data['foto']?.toString() ?? '';
        if (serverFoto.isNotEmpty) {
          _photoUrl = ApiService.photoUrl(serverFoto);
          await prefs.setString(_keyPhotoUrl, _photoUrl);
        } else {
          _photoUrl = '';
          await prefs.remove(_keyPhotoUrl);
        }
        final gender = data['gender']?.toString().toLowerCase() ?? '';
        await prefs.setString(
          'profile_gender_icon',
          gender.contains('perempuan') ? 'cewe' : 'cowo',
        );
        if (mounted) {
          setState(() {
            profileData = data;
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await SessionManager().logoutUser();
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (r) => false,
          );
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Fungsi: Menampilkan pilihan sumber gambar dan memproses upload atau penghapusan foto profil.
  /// Alur:
  /// 1. Menampilkan BottomSheet kustom berisi 3 opsi: Kamera, Galeri, atau Hapus Foto (jika foto ada).
  /// 2. Jika opsi 'Hapus Foto' dipilih:
  ///    - Set `_isUploadingPhoto = true`.
  ///    - Panggil API `deletePhoto()`.
  ///    - Hapus cache lokal di SharedPreferences, kosongkan `_photoUrl`, lalu tampilkan SnackBar sukses.
  /// 3. Jika Kamera/Galeri dipilih:
  ///    - Buka plugin `ImagePicker` dengan batas kompresi resolusi 800x800 px dan kualitas 80%.
  ///    - Jika gambar berhasil diambil, set `_isUploadingPhoto = true`.
  ///    - Panggil API `uploadPhoto()` dengan mengirimkan path berkas gambar.
  ///    - Jika sukses, update `_photoUrl`, simpan di SharedPreferences, lalu tampilkan SnackBar sukses.
  /// 4. Selesai memproses, matikan status loading `_isUploadingPhoto = false` lewat `setState`.
  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.bgDarkPurple,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('Pilih Foto', style: AppTheme.heading3),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: AppTheme.primary,
              ),
              title: Text(
                'Kamera',
                style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppTheme.accent,
              ),
              title: Text(
                'Galeri',
                style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (_photoUrl.isNotEmpty)
              ListTile(
                leading: const Icon(
                  Icons.delete_rounded,
                  color: AppTheme.error,
                ),
                title: Text(
                  'Hapus Foto',
                  style: AppTheme.body.copyWith(color: AppTheme.error),
                ),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;

    if (action == 'delete') {
      setState(() => _isUploadingPhoto = true);
      try {
        final res = await ApiService().deletePhoto();
        if (res['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_keyPhotoUrl);
          if (mounted) setState(() => _photoUrl = '');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Foto profil berhasil dihapus',
                  style: AppTheme.body.copyWith(color: Colors.white),
                ),
                backgroundColor: AppTheme.bgDarkPurple,
              ),
            );
          }
        } else {
          _showError(res['message']?.toString() ?? 'Gagal menghapus foto');
        }
      } on ApiException catch (e) {
        _showError(e.message);
      } catch (e) {
        _showError('Gagal menghapus foto');
      } finally {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
      return;
    }

    if (action == null) return;

    final ImageSource source = action == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final res = await ApiService().uploadPhoto(picked.path);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>?;
        final newFoto = data?['foto']?.toString() ?? '';
        if (newFoto.isNotEmpty) {
          final newUrl = ApiService.photoUrl(newFoto);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyPhotoUrl, newUrl);
          if (mounted) setState(() => _photoUrl = newUrl);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Foto profil berhasil diperbarui',
                style: AppTheme.body.copyWith(color: Colors.white),
              ),
              backgroundColor: AppTheme.bgDarkPurple,
            ),
          );
        }
      } else {
        _showError(res['message']?.toString() ?? 'Gagal upload foto');
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Gagal upload foto');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  /// Fungsi: Helper untuk memicu dan menampilkan SnackBar pesan kesalahan (error).
  /// Alur: Menerima String pesan, memvalidasi state mounted, lalu menampilkannya dengan tema merah (AppTheme.error).
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTheme.body.copyWith(color: Colors.white)),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  /// Fungsi: Mengirim pembaruan data biodata profil ke API Server.
  /// Alur:
  /// 1. Mengaktifkan loading (`isLoading = true`).
  /// 2. Melakukan request HTTP PUT/POST melalui `ApiService().updateProfile(updatedData)`.
  /// 3. Jika berhasil:
  ///    - Memperbarui preferensi ikon gender lokal berdasarkan input jenis kelamin baru.
  ///    - Menampilkan pesan sukses berupa SnackBar.
  ///    - Memanggil kembali [_loadProfile()] untuk menyegarkan data UI dengan data terbaru dari server.
  /// 4. Jika gagal/error: Menangkap error dan memicu SnackBar pemberitahuan kegagalan.
  /// 5. Terakhir: Menonaktifkan loading (`isLoading = false`).
  Future<void> _updateProfile(Map<String, String> updatedData) async {
    setState(() => isLoading = true);
    try {
      final res = await ApiService().updateProfile(updatedData);
      if (res['success'] == true) {
        final newGender = updatedData['gender'] ?? '';
        if (newGender.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'profile_gender_icon',
            newGender.toLowerCase() == 'perempuan' ? 'cewe' : 'cowo',
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res['message']?.toString() ?? 'Berhasil update profil',
                style: AppTheme.body.copyWith(color: Colors.white),
              ),
              backgroundColor: AppTheme.bgDarkPurple,
            ),
          );
        }
        await _loadProfile();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res['message']?.toString() ?? 'Gagal update profil',
                style: AppTheme.body.copyWith(color: Colors.white),
              ),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message,
              style: AppTheme.body.copyWith(color: Colors.white),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Terjadi kesalahan koneksi',
              style: AppTheme.body.copyWith(color: Colors.white),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Fungsi: Menampilkan pop-up Dialog formulir untuk mengubah informasi profil.
  /// Alur:
  /// 1. Mengambil data profil yang ada lalu menginisialisasi `TextEditingController` untuk setiap input field.
  /// 2. Membuka dialog menggunakan `showDialog()` dengan layout Form di dalam `AlertDialog`.
  /// 3. Menggunakan `StatefulBuilder` agar state dialog terisolasi (misal mengganti gender atau tanggal lahir secara interaktif).
  /// 4. Opsi 'Tanggal Lahir' memicu dialog penanggalan `showDatePicker`.
  /// 5. Opsi 'Gender' menggunakan Dropdown kustom (Laki-Laki & Perempuan).
  /// 6. Jika menekan tombol 'Batal': Dialog tertutup.
  /// 7. Jika menekan tombol 'Simpan': Menutup dialog dan memanggil [_updateProfile()] dengan peta data yang diinput.
  void _showEditDialog() {
    if (profileData == null) return;
    final nameCtrl = TextEditingController(text: profileData!['nama_siswa']);
    final dateCtrl = TextEditingController(text: profileData!['tanggal_lahir']);
    final addrCtrl = TextEditingController(text: profileData!['alamat']);
    final parentCtrl = TextEditingController(text: profileData!['nama_ortu']);
    final phoneCtrl = TextEditingController(text: profileData!['no_telp_ortu']);
    String selectedGender = profileData!['gender'] ?? 'Laki-Laki';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.bgDarkPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text("Edit Data Profil", style: AppTheme.heading3),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _editField(nameCtrl, "Nama Anak"),
                GestureDetector(
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.tryParse(dateCtrl.text) ?? DateTime(2010),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      builder: (ctx, child) => Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppTheme.primary,
                            surface: AppTheme.bgDarkPurple,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (pickedDate != null) {
                      setDialogState(() {
                        dateCtrl.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(pickedDate);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: _editField(dateCtrl, "Tanggal Lahir"),
                  ),
                ),
                _editField(addrCtrl, "Alamat"),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: DropdownButtonFormField<String>(
                    initialValue:
                        ["Laki-Laki", "Perempuan"].contains(selectedGender)
                        ? selectedGender
                        : "Laki-Laki",
                    dropdownColor: AppTheme.bgDarkPurple,
                    style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
                    items: const [
                      DropdownMenuItem(
                        value: "Laki-Laki",
                        child: Text("Laki-Laki"),
                      ),
                      DropdownMenuItem(
                        value: "Perempuan",
                        child: Text("Perempuan"),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedGender = v);
                    },
                    decoration: InputDecoration(
                      labelText: "Gender",
                      labelStyle: AppTheme.bodySmall,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppTheme.primary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                _editField(parentCtrl, "Nama Orang Tua"),
                _editField(phoneCtrl, "Nomor Telepon"),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Batal",
                style: AppTheme.body.copyWith(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                _updateProfile({
                  'nama_siswa': nameCtrl.text,
                  'tanggal_lahir': dateCtrl.text,
                  'alamat': addrCtrl.text,
                  'gender': selectedGender,
                  'nama_ortu': parentCtrl.text,
                  'no_telp_ortu': phoneCtrl.text,
                });
              },
              child: Text("Simpan", style: AppTheme.button),
            ),
          ],
        ),
      ),
    );
  }

  /// Fungsi: Widget pembantu (helper) untuk membangun kolom teks input yang seragam.
  /// Alur: Menerima [TextEditingController] dan [String label], merender TextField dengan gaya visual gelap (AppTheme).
  Widget _editField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: ctrl,
        style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTheme.bodySmall,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppTheme.primary),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Fungsi: Menampilkan konfirmasi pop-up dialog untuk keluar/logout dari aplikasi.
  /// Alur:
  /// 1. Menampilkan dialog dengan pertanyaan konfirmasi "Yakin ingin keluar?".
  /// 2. Jika 'Tidak' ditekan: Dialog ditutup.
  /// 3. Jika 'Ya' ditekan:
  ///    - Menutup dialog segera agar tidak menumpuk.
  ///    - Mengamankan instance `Navigator` di variabel lokal demi menghindari "async gap" / BuildContext kedaluwarsa.
  ///    - Melakukan pemanggilan asinkron `ApiService().logout()` agar server menghapus token FCM yang terdaftar.
  ///    - Jika berhasil atau gagal: Sistem lokal dibersihkan lewat `SessionManager().logoutUser()` dan dipindahkan ke `LoginScreen`.
  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgDarkPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Konfirmasi", style: AppTheme.heading3),
        content: Text(
          "Apakah Anda yakin ingin keluar dari perangkat?",
          style: AppTheme.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Tidak",
              style: AppTheme.body.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              // 1. Tutup dialog segera
              Navigator.pop(context);

              try {
                // Simpan navigator instance sebelum async call agar aman dari BuildContext async gap
                final navigator = Navigator.of(context, rootNavigator: true);

                // 2. Jalankan proses logout API terlebih dahulu.
                // Ini wajib diawait agar API menggunakan token session yang masih aktif untuk
                // menghapus token FCM di database server Laravel.
                await ApiService().logout();

                // 3. Pindah ke halaman Login
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              } catch (e) {
                debugPrint('Logout Error: $e');
                // Jika terjadi error, tetap paksa bersihkan session lokal & pindah ke Login
                await SessionManager().logoutUser();
                if (!mounted) return;
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: Text(
              "Ya",
              style: AppTheme.body.copyWith(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Fungsi: Membangun widget foto profil berdesain premium lingkaran (Avatar).
  /// Parameter: [String genderImagePath] (Path gambar ikon default cewe/cowo jika foto kosong).
  /// Alur:
  /// 1. Stack utama berisi:
  ///    - Lingkaran Avatar utama berpendar bayangan (BoxShadow) berwarna neon ungu.
  ///    - Logika kondisional:
  ///      * Jika `_isUploadingPhoto == true`: Merender putaran CircularProgressIndicator.
  ///      * Jika `_photoUrl` terisi: Merender `Image.network()` dengan fallback ke asset gender jika gagal muat.
  ///      * Jika kosong: Merender `Image.asset()` gender default langsung.
  ///    - Tombol Kamera (kanan bawah) untuk memicu `_pickAndUploadPhoto()`.
  ///    - Tombol Edit (kiri bawah) untuk memicu `_showEditDialog()`.
  Widget _buildAvatar(String genderImagePath) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 52,
            backgroundColor: AppTheme.bgDarkPurple,
            child: ClipOval(
              child: _isUploadingPhoto
                  ? const SizedBox(
                      width: 96,
                      height: 96,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                      ),
                    )
                  : _photoUrl.isNotEmpty
                  ? Image.network(
                      _photoUrl,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Image.asset(
                        genderImagePath,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      genderImagePath,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickAndUploadPhoto,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: GestureDetector(
            onTap: _showEditDialog,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(7),
              child: Image.asset(
                'assets/images/ic_edit.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Fungsi: Metode rendering UI utama dari layar profil.
  /// Alur:
  /// 1. Mengecek status loading. Jika iya, tampilkan Fullscreen loading spinner.
  /// 2. Menentukan aset gambar avatar default berdasarkan data jenis kelamin (Perempuan -> cewe, Laki-Laki -> cowo).
  /// 3. Merender struktur layout utama dibungkus `DarkBackground`:
  ///    - Header Profil (SafeArea): Menampilkan judul "Profile", widget avatar ([_buildAvatar]), nama siswa, dan nama kelas.
  ///    - Pane Transparan Glassmorphism (Expanded): Menggunakan `BackdropFilter` blur 30px dan latar belakang semi-transparan untuk memberikan efek kaca premium.
  ///    - Bagian 1 "Identitas Anak": Kartu Info Nama, Alamat, serta Grid Bersebelahan berisi Tanggal Lahir dan Jenis Kelamin.
  ///    - Bagian 2 "Identitas Orangtua": Kartu Info Nama Orang Tua dan No. Telepon.
  ///    - Tombol Paling Bawah: OutlinedButton merah tebal untuk memicu `_logout()`.
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    final gender = profileData?['gender'] ?? "";
    final genderImagePath = gender.toLowerCase() == "perempuan"
        ? "assets/images/icon_cewe.png"
        : "assets/images/icon_cowo.png";

    return DarkBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // Header (Transparent)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            'Profile',
                            textAlign: TextAlign.center,
                            style: AppTheme.heading2,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildAvatar(genderImagePath),
                    const SizedBox(height: 12),
                    Text(
                      profileData?['nama_siswa'] ?? "-",
                      style: AppTheme.heading2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (profileData?['kelas'] ?? "-").toUpperCase(),
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Body (Glassmorphism pane)
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.bgDark.withValues(alpha: 0.55),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                        left: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                        right: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            "Identitas Anak",
                            AppTheme.primary,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoCard(
                            Icons.badge_rounded,
                            "NAMA LENGKAP",
                            profileData?['nama_siswa'] ?? "-",
                          ),
                          _buildInfoCard(
                            Icons.location_on_rounded,
                            "ALAMAT",
                            profileData?['alamat'] ?? "-",
                            iconColor: AppTheme.info,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildGridCard(
                                  "TANGGAL LAHIR",
                                  profileData?['tanggal_lahir'] ?? "-",
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildGridCard(
                                  "JENIS KELAMIN",
                                  profileData?['gender'] ?? "-",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          _buildSectionHeader(
                            "Identitas Orangtua",
                            AppTheme.accent,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoCard(
                            Icons.person_rounded,
                            "NAMA ORANGTUA",
                            profileData?['nama_ortu'] ?? "-",
                            iconColor: AppTheme.accent,
                          ),
                          _buildInfoCard(
                            Icons.phone_rounded,
                            "NO. TELEPON",
                            profileData?['no_telp_ortu'] ?? "-",
                            iconColor: AppTheme.accent,
                          ),

                          const SizedBox(height: 40),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _logout,
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: AppTheme.error,
                              ),
                              label: Text(
                                'KELUAR DARI PERANGKAT',
                                style: AppTheme.bodyLarge.copyWith(
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: BorderSide(
                                  color: AppTheme.error.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fungsi: Membangun baris judul sub-bagian dengan garis indikator berwarna di sebelah kiri.
  /// Parameter: [String title] (teks judul), [Color indicatorColor] (warna garis penanda vertikal).
  Widget _buildSectionHeader(String title, Color indicatorColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: indicatorColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: AppTheme.heading3),
      ],
    );
  }

  /// Fungsi: Membangun kartu data baris horizontal dengan ikon di sebelah kiri.
  /// Parameter:
  /// - [IconData icon] (Ikon representasi)
  /// - [String label] (Kategori info seperti "NAMA LENGKAP")
  /// - [String value] (Nilai informasi dari database)
  /// - [Color iconColor] (Warna latar & warna ikon, default ungu AppTheme.primary)
  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value, {
    Color iconColor = AppTheme.primary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.label.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fungsi: Membangun kartu informasi kecil berbentuk grid (kotak) berskala setengah lebar halaman.
  /// Parameter:
  /// - [String label] (Kategori info seperti "JENIS KELAMIN")
  /// - [String value] (Nilai informasi dari database)
  Widget _buildGridCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.label.copyWith(
              color: AppTheme.textMuted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
