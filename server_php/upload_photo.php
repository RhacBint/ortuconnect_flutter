<?php
header("Content-Type: application/json; charset=UTF-8");
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');

include "../koneksi.php";

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'message' => 'Gunakan metode POST']);
    exit;
}

$username = isset($_POST['username']) ? mysqli_real_escape_string($conn, trim($_POST['username'])) : '';

if (empty($username)) {
    echo json_encode(['success' => false, 'message' => 'Username tidak boleh kosong']);
    exit;
}

if (!isset($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
    echo json_encode(['success' => false, 'message' => 'File foto tidak valid']);
    exit;
}

$file = $_FILES['photo'];
$allowedTypes = ['image/jpeg', 'image/png', 'image/webp'];
$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mimeType = finfo_file($finfo, $file['tmp_name']);
finfo_close($finfo);

if (!in_array($mimeType, $allowedTypes)) {
    echo json_encode(['success' => false, 'message' => 'Format file tidak didukung. Gunakan JPG, PNG, atau WebP']);
    exit;
}

// Maksimal 2MB
if ($file['size'] > 2 * 1024 * 1024) {
    echo json_encode(['success' => false, 'message' => 'Ukuran file maksimal 2MB']);
    exit;
}

// Buat folder uploads kalau belum ada
$uploadDir = __DIR__ . '/../uploads/profile/';
if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

// Hapus foto lama kalau ada
$queryOld = "SELECT photo_url FROM akun WHERE username = '$username' LIMIT 1";
$resultOld = mysqli_query($conn, $queryOld);
if ($resultOld && mysqli_num_rows($resultOld) > 0) {
    $rowOld = mysqli_fetch_assoc($resultOld);
    $oldUrl = $rowOld['photo_url'] ?? '';
    if (!empty($oldUrl)) {
        $oldPath = __DIR__ . '/../' . ltrim(parse_url($oldUrl, PHP_URL_PATH), '/');
        if (file_exists($oldPath)) {
            unlink($oldPath);
        }
    }
}

// Simpan file baru
$ext = pathinfo($file['name'], PATHINFO_EXTENSION) ?: 'jpg';
$filename = 'profile_' . $username . '_' . time() . '.' . $ext;
$destPath = $uploadDir . $filename;

if (!move_uploaded_file($file['tmp_name'], $destPath)) {
    echo json_encode(['success' => false, 'message' => 'Gagal menyimpan file']);
    exit;
}

// URL publik foto
$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host = $_SERVER['HTTP_HOST'];
$photoUrl = $protocol . '://' . $host . '/uploads/profile/' . $filename;

// Simpan URL ke database (perlu kolom photo_url di tabel akun)
$query = "UPDATE akun SET photo_url = '$photoUrl' WHERE username = '$username'";
mysqli_query($conn, $query);

echo json_encode([
    'success' => true,
    'message' => 'Foto berhasil diupload',
    'photo_url' => $photoUrl
]);

mysqli_close($conn);
?>
