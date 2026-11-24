<?php
// Endpoint de diagnóstico: responde JSON con el estado de la app y la BD.
require_once __DIR__ . '/db.php';
header('Content-Type: application/json');

[$conn, $error] = conectar();
$estado = [
    'app'      => 'ok',
    'host'     => gethostname(),
    'php'      => PHP_VERSION,
    'mysqli'   => extension_loaded('mysqli'),
    'db_host'  => DB_HOST,
    'db'       => $conn ? 'ok' : 'error',
    'db_error' => $error,
];
http_response_code($conn ? 200 : 503);
echo json_encode($estado, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), "\n";
