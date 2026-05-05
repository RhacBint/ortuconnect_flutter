<?php
/**
 * test_notif.php
 * File untuk test kirim notifikasi ke device
 * HAPUS file ini setelah selesai testing!
 */

include "../koneksi.php";
include "send_notification.php";

// Ambil fcm_token user 'plug' dari database
$username = 'plug';
$query = "SELECT fcm_token FROM akun WHERE username = '$username' LIMIT 1";
$result = mysqli_query($conn, $query);
$row = mysqli_fetch_assoc($result);

if (!$row || empty($row['fcm_token'])) {
    echo json_encode(['success' => false, 'message' => 'FCM token tidak ditemukan untuk user: ' . $username]);
    exit;
}

$fcmToken = $row['fcm_token'];

// Kirim notifikasi test
$success = sendFCMNotification(
    $fcmToken,
    '🔔 Test Notifikasi',
    'Notifikasi dari server berhasil dikirim!'
);

echo json_encode([
    'success' => $success,
    'message' => $success ? 'Notifikasi berhasil dikirim!' : 'Gagal kirim notifikasi',
    'token_used' => substr($fcmToken, 0, 20) . '...'
]);

mysqli_close($conn);
?>
