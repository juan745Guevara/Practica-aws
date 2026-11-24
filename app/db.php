<?php
require_once __DIR__ . '/config.php';

mysqli_report(MYSQLI_REPORT_OFF);

/**
 * Conecta a MySQL (RDS). Intenta primero con SSL, porque algunas versiones de
 * RDS MySQL exigen conexiones cifradas; si el servidor no lo soporta, reintenta
 * sin SSL. Devuelve [conexion|null, mensajeDeError|null].
 */
function conectar(): array
{
    $error = null;
    foreach ([true, false] as $usarSsl) {
        $conn = mysqli_init();
        $conn->options(MYSQLI_OPT_CONNECT_TIMEOUT, 5);
        $flags = 0;
        if ($usarSsl) {
            $conn->ssl_set(null, null, null, null, null);
            $flags = MYSQLI_CLIENT_SSL | MYSQLI_CLIENT_SSL_DONT_VERIFY_SERVER_CERT;
        }
        if (@$conn->real_connect(DB_HOST, DB_USER, DB_PASS, DB_NAME, DB_PORT, null, $flags)) {
            $conn->set_charset('utf8mb4');
            return [$conn, null];
        }
        $error = 'Error ' . mysqli_connect_errno() . ': ' . mysqli_connect_error();
        // Credenciales, host o base inexistente: no tiene sentido reintentar sin SSL
        if (in_array(mysqli_connect_errno(), [1045, 1049, 2002, 2005], true)) {
            break;
        }
    }
    return [null, $error];
}
