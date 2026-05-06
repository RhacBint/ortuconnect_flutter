import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class NotificationItem {
  final int? id;
  final String title;
  final String body;
  final String type; // izin, agenda, absensi, rekap, fcm
  final DateTime timestamp;
  final bool isRead;

  NotificationItem({
    this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'type': type,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'is_read': isRead ? 1 : 0,
  };

  factory NotificationItem.fromMap(Map<String, dynamic> map) => NotificationItem(
    id: map['id'],
    title: map['title'],
    body: map['body'],
    type: map['type'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    isRead: map['is_read'] == 1,
  );
}

class NotificationDatabase {
  static final NotificationDatabase _instance = NotificationDatabase._internal();
  factory NotificationDatabase() => _instance;
  NotificationDatabase._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'notifications.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            type TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            is_read INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  Future<void> insert(NotificationItem item) async {
    final db = await database;
    await db.insert('notifications', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<NotificationItem>> getAll() async {
    final db = await database;
    final maps = await db.query('notifications',
        orderBy: 'timestamp DESC', limit: 100);
    return maps.map(NotificationItem.fromMap).toList();
  }

  Future<int> getUnreadCount() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notifications WHERE is_read = 0');
    return result.first['count'] as int;
  }

  Future<void> markAllRead() async {
    final db = await database;
    await db.update('notifications', {'is_read': 1});
  }

  Future<void> markRead(int id) async {
    final db = await database;
    await db.update('notifications', {'is_read': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAll() async {
    final db = await database;
    await db.delete('notifications');
  }
}
