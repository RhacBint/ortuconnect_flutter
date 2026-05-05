<?php
header("Content-Type: application/json; charset=UTF-8");
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

include "../koneksi.php";

$response = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);

    $username  = isset($input['username'])  ? mysqli_real_escape_string($conn, trim($input['username']))  : '';
    $fcm_token = isset($input['fcm_token']) ? mysqli_real_escape_string($conn, trim($input['fcm_token'])) : '';

    if (empty($username) || empty($fcm_token)) {
        echo json_encode(['success' => false, 'message' => 'Parameter tidak lengkap']);
        exit;
    }

    $query = "UPDATE akun SET fcm_token = '$fcm_token' WHERE username = '$username'";
    $result = mysqli_query($conn, $query);

    if ($result && mysqli_affected_rows($conn) > 0) {
        echo json_encode(['success' => true, 'message' => 'FCM token berhasil disimpan']);
    } else {
        echo json_encode(['success' => false, 'message' => 'Gagal menyimpan token atau username tidak ditemukan']);
    }
} else {
    echo json_encode(['success' => false, 'message' => 'Gunakan metode POST']);
}

mysqli_close($conn);
?>
