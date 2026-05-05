<?php
/**
 * send_notification.php
 * Kirim push notification ke device via Firebase FCM HTTP v1 API
 * 
 * Cara pakai:
 * include 'send_notification.php';
 * sendFCMNotification($fcm_token, 'Judul', 'Isi pesan');
 */

// =============================================
// GANTI dengan path Service Account JSON kamu
// Download dari: Firebase Console → Project Settings → Service Accounts → Generate new private key
// =============================================
define('SERVICE_ACCOUNT_FILE', __DIR__ . '/firebase_service_account.json');
define('FCM_PROJECT_ID', 'ortuconnect-2e78e'); // project ID dari google-services.json

/**
 * Kirim notifikasi ke satu device
 */
function sendFCMNotification(string $fcmToken, string $title, string $body, array $data = []): bool {
    $accessToken = getFirebaseAccessToken();
    if (!$accessToken) return false;

    $url = "https://fcm.googleapis.com/v1/projects/" . FCM_PROJECT_ID . "/messages:send";

    $message = [
        'message' => [
            'token' => $fcmToken,
            'notification' => [
                'title' => $title,
                'body'  => $body,
            ],
            'android' => [
                'priority' => 'high',
                'notification' => [
                    'channel_id'           => 'ortuconnect_channel',
                    'sound'                => 'default',
                    'default_sound'        => true,
                    'default_vibrate_timings' => true,
                    'notification_priority' => 'PRIORITY_HIGH',
                    'visibility'           => 'PUBLIC',
                ],
            ],
        ]
    ];

    // Selalu sertakan data payload agar bisa diproses saat app mati
    $defaultData = [
        'title' => $title,
        'body'  => $body,
        'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
    ];
    $message['message']['data'] = array_map('strval', array_merge($defaultData, $data));

    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_HTTPHEADER     => [
            'Authorization: Bearer ' . $accessToken,
            'Content-Type: application/json',
        ],
        CURLOPT_POSTFIELDS => json_encode($message),
        CURLOPT_TIMEOUT    => 10,
    ]);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode === 200) {
        return true;
    } else {
        error_log("FCM Error ($httpCode): $response");
        return false;
    }
}

/**
 * Kirim notifikasi ke banyak device sekaligus
 */
function sendFCMToMultiple(array $fcmTokens, string $title, string $body, array $data = []): int {
    $successCount = 0;
    foreach ($fcmTokens as $token) {
        if (!empty($token) && sendFCMNotification($token, $title, $body, $data)) {
            $successCount++;
        }
    }
    return $successCount;
}

/**
 * Ambil access token dari Service Account JSON (OAuth2)
 */
function getFirebaseAccessToken(): ?string {
    if (!file_exists(SERVICE_ACCOUNT_FILE)) {
        error_log('Firebase service account file tidak ditemukan: ' . SERVICE_ACCOUNT_FILE);
        return null;
    }

    $serviceAccount = json_decode(file_get_contents(SERVICE_ACCOUNT_FILE), true);
    if (!$serviceAccount) {
        error_log('Gagal membaca service account JSON');
        return null;
    }

    $now    = time();
    $expiry = $now + 3600;

    $header  = base64UrlEncode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $payload = base64UrlEncode(json_encode([
        'iss'   => $serviceAccount['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud'   => 'https://oauth2.googleapis.com/token',
        'iat'   => $now,
        'exp'   => $expiry,
    ]));

    $signingInput = "$header.$payload";
    $privateKey   = $serviceAccount['private_key'];

    openssl_sign($signingInput, $signature, $privateKey, 'SHA256');
    $jwt = "$signingInput." . base64UrlEncode($signature);

    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POSTFIELDS     => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion'  => $jwt,
        ]),
        CURLOPT_TIMEOUT => 10,
    ]);

    $response = json_decode(curl_exec($ch), true);
    curl_close($ch);

    return $response['access_token'] ?? null;
}

function base64UrlEncode(string $data): string {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}
?>
