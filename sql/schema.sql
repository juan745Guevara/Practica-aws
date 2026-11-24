-- Ejecutar desde la EC2:
--   mysql -h <endpoint-rds> -u admin -p < sql/schema.sql

CREATE DATABASE IF NOT EXISTS appdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE appdb;

CREATE TABLE IF NOT EXISTS productos (
  id      INT AUTO_INCREMENT PRIMARY KEY,
  nombre  VARCHAR(100)  NOT NULL,
  precio  DECIMAL(10,2) NOT NULL DEFAULT 0,
  stock   INT           NOT NULL DEFAULT 0,
  creado  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO productos (nombre, precio, stock) VALUES
  ('Café de Tingo María 250 g', 18.50, 40),
  ('Cacao en polvo 500 g',      22.00, 25),
  ('Miel de abeja 1 kg',        30.00, 12);

-- Usuario propio para la app (buena práctica: no usar admin en la app)
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY 'CambiaEsto123!';
GRANT SELECT, INSERT, UPDATE, DELETE ON appdb.* TO 'appuser'@'%';
FLUSH PRIVILEGES;
