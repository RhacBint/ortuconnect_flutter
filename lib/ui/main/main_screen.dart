import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../kalender/kalender_screen.dart';
import '../absen/absensi_screen.dart';
import '../perizinan/perizinan_screen.dart';
import '../profile/profile_screen.dart';
import '../notifikasi/notifikasi_screen.dart';
import '../../core/notification_database.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _unreadCount = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    AbsensiScreen(),
    PerizinanScreen(),
    KalenderScreen(),
    NotifikasiScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationDatabase().getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    // Reset badge saat buka tab notifikasi
    if (index == 4) {
      setState(() => _unreadCount = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    final items = [
      {'icon': 'assets/images/ic_home.png', 'label': 'Home'},
      {'icon': 'assets/images/ic_absensi.png', 'label': 'Absensi'},
      {'icon': 'assets/images/ic_perizinan.png', 'label': 'Perizinan'},
      {'icon': 'assets/images/ic_calendar.png', 'label': 'Kalender'},
      {'icon': 'assets/images/ic_speaker_white.png', 'label': 'Notifikasi'},
      {'icon': 'assets/images/ic_profile.png', 'label': 'Profil'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = _selectedIndex == index;
              final isNotifTab = index == 4;
              return GestureDetector(
                onTap: () => _onItemTapped(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 12 : 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0F53BF).withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ImageIcon(
                            AssetImage(items[index]['icon']!),
                            size: 24,
                            color: isSelected
                                ? const Color(0xFF0F53BF)
                                : Colors.grey.shade500,
                          ),
                          // Badge unread untuk tab notifikasi
                          if (isNotifTab && _unreadCount > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16, minHeight: 16,
                                ),
                                child: Text(
                                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: TextStyle(
                          fontSize: isSelected ? 10 : 9,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: isSelected
                              ? const Color(0xFF0F53BF)
                              : Colors.grey.shade500,
                        ),
                        child: Text(items[index]['label']!),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
