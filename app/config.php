<?php
// Configuración de la base de datos.
// En Docker se usan variables de entorno (-e DB_HOST=...).
// En Apache, scripts/setup-apache.sh reemplaza los valores por defecto de abajo.
define('DB_HOST', getenv('DB_HOST') ?: '__DB_HOST__');
define('DB_USER', getenv('DB_USER') ?: '__DB_USER__');
define('DB_PASS', getenv('DB_PASS') ?: '__DB_PASS__');
define('DB_NAME', getenv('DB_NAME') ?: 'appdb');
define('DB_PORT', (int)(getenv('DB_PORT') ?: 3306));
