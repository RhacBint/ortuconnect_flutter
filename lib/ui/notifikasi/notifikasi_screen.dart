import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../core/notification_database.dart';
import '../../core/api_service.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});
  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (mounted) setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final items = await ApiService().getNotifications();
      try {
        await ApiService().markAllNotificationsRead();
      } catch (e) {
        debugPrint('Mark all read error: $e');
      }
      if (mounted) {
        setState(() {
          _notifications = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('ApiException(401): ', '').replaceAll('ApiException(500): ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteItem(NotificationItem item) async {
    if (item.id == null) return;
    try {
      await ApiService().deleteNotification(item.id!);
      setState(() => _notifications.removeWhere((n) => n.id == item.id));
    } catch (e) {
      debugPrint('Delete notification item error: $e');
    }
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgDarkPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hapus Semua', style: AppTheme.heading3),
        content: Text('Hapus semua riwayat notifikasi?', style: AppTheme.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: AppTheme.body.copyWith(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: AppTheme.body.copyWith(color: AppTheme.error))),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        for (var notif in _notifications) {
          if (notif.id != null) {
            await ApiService().deleteNotification(notif.id!);
          }
        }
        setState(() {
          _notifications.clear();
          _isLoading = false;
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Gagal menghapus semua notifikasi. Coba lagi.';
            _isLoading = false;
          });
        }
      }
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'izin': return AppTheme.success;
      case 'agenda': return AppTheme.info;
      case 'absensi': return AppTheme.error;
      case 'rekap': return AppTheme.accent;
      default: return AppTheme.primary;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'izin': return 'Izin';
      case 'agenda': return 'Agenda';
      case 'absensi': return 'Absensi';
      case 'rekap': return 'Rekap';
      default: return 'Pesan';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return DarkBackground(
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 16, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Riwayat Notifikasi', style: AppTheme.heading1),
              if (_notifications.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.delete_sweep_rounded, color: AppTheme.textMuted),
                  tooltip: 'Hapus semua', onPressed: _deleteAll),
            ]),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_rounded, color: AppTheme.error, size: 64),
                              const SizedBox(height: 12),
                              Text(_errorMessage, style: AppTheme.body, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadNotifications,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: Text('Coba Lagi', style: AppTheme.body.copyWith(fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.bgDarkPurple,
                        child: _notifications.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.notifications_none_rounded, color: AppTheme.textMuted, size: 64),
                                        const SizedBox(height: 12),
                                        Text('Belum ada notifikasi', style: AppTheme.body),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                itemCount: _notifications.length,
                                itemBuilder: (ctx, i) => _buildCard(_notifications[i]),
                              ),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCard(NotificationItem item) {
    final color = _typeColor(item.type);
    return Dismissible(
      key: Key('notif_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: AppTheme.error),
      ),
      onDismissed: (_) => _deleteItem(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: GlassCard(
          borderRadius: 16, padding: const EdgeInsets.all(14),
          backgroundColor: item.isRead
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.1),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 4), width: 10, height: 10,
              decoration: BoxDecoration(
                color: item.isRead ? AppTheme.textMuted : color, shape: BoxShape.circle,
                boxShadow: item.isRead ? [] : [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(item.title,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600,
                    color: item.isRead ? AppTheme.textSecondary : AppTheme.textPrimary))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(_typeLabel(item.type),
                    style: AppTheme.bodySmall.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(item.body, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Text(_formatTime(item.timestamp), style: AppTheme.bodySmall.copyWith(fontSize: 11)),
            ])),
          ]),
        ),
      ),
    );
  }
}
