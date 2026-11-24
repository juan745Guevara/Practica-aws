# Guía de despliegue

Cómo poner la app en una instancia EC2 con Ubuntu, de dos formas: **Apache** (puerto 80) y
**Docker** (puerto 8080), conectada a MySQL en RDS.

Si todavía no tienes la instancia, el Security Group o la base de datos, créalos primero con las
guías [01 · EC2](docs/01-ec2-ssh-security-group.md) y [04 · RDS](docs/04-rds-mysql.md).

## Antes de empezar

Necesitas:

| Dato | Ejemplo | Dónde lo sacas |
| --- | --- | --- |
| IP pública de la EC2 | `107.20.40.138` | EC2 → Instancias → tu instancia |
| Llave SSH | `lab-key.pem` | Se descargó al crear el key pair |
| Endpoint de RDS | `lab-db.xxxxxxxx.us-east-1.rds.amazonaws.com` | RDS → tu base → Conectividad y seguridad |
| Usuario / clave maestra de RDS | `admin` / la que elegiste | Al crear la base |

Security Group de la EC2 con: **22** (tu IP), **80** y **8080** (0.0.0.0/0).
Security Group de RDS con: **3306** desde el Security Group de la EC2.

---

## Paso 1 · Entrar a la EC2 y clonar el repositorio

```bash
ssh -i lab-key.pem ubuntu@<IP-PUBLICA>
```

Dentro de la instancia:

```bash
sudo apt update
sudo apt install -y git mysql-client
git clone https://github.com/juan745Guevara/Practica-aws.git
cd Practica-aws
chmod +x scripts/*.sh
```

## Paso 2 · Preparar la base de datos (una sola vez)

```bash
nc -zv <ENDPOINT-RDS> 3306                              # debe decir: succeeded
mysql -h <ENDPOINT-RDS> -u admin -p < sql/schema.sql    # pide la clave maestra
```

Esto crea la base `appdb`, la tabla `productos` con 3 filas y el usuario de la app
**`appuser`** / **`CambiaEsto123!`**.

Si `mysql` responde *insecure transport are prohibited*, agrega `--ssl-mode=REQUIRED` al comando.

---

## Opción A · Desplegar con Apache (puerto 80)

### Con el script (1 comando)

```bash
sudo ./scripts/setup-apache.sh <ENDPOINT-RDS> appuser 'CambiaEsto123!'
```

### A mano (lo que hace el script)

```bash
# 1. Instalar Apache + PHP
sudo apt install -y apache2 php libapache2-mod-php php-mysql
sudo systemctl enable --now apache2

# 2. Copiar la app
sudo rm -f /var/www/html/index.html
sudo cp -r app/. /var/www/html/
sudo chown -R www-data:www-data /var/www/html

# 3. Poner los datos de RDS
sudo nano /var/www/html/config.php
#    __DB_HOST__ -> tu endpoint · __DB_USER__ -> appuser · __DB_PASS__ -> CambiaEsto123!

# 4. Reiniciar y probar
sudo systemctl restart apache2
curl -s http://localhost/health.php      # "db": "ok"
```

Abre **`http://<IP-PUBLICA>/`** → *Conectado a RDS* y la lista de productos.

---

## Opción B · Desplegar con Docker (puerto 8080)

### Instalar Docker (una sola vez)

```bash
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu
exit        # sal y vuelve a entrar por SSH para usar docker sin sudo
```

Vuelve a entrar y a la carpeta: `ssh -i lab-key.pem ubuntu@<IP-PUBLICA>` y luego `cd Practica-aws`.

### B1 · Con `docker build` + `docker run`

```bash
docker build -f docker/Dockerfile -t lab-app .
docker run -d --name lab-app --restart unless-stopped -p 8080:80 \
  -e DB_HOST=<ENDPOINT-RDS> -e DB_USER=appuser -e DB_PASS='CambiaEsto123!' -e DB_NAME=appdb \
  lab-app
docker ps                                 # lab-app  Up  0.0.0.0:8080->80/tcp
```

### B2 · Con Docker Compose y `.env`

```bash
sudo apt install -y docker-compose-v2     # si "docker compose" no existe
cp .env.example .env
nano .env                                 # pon DB_HOST, DB_USER=appuser, DB_PASS
docker compose up -d --build
docker compose ps
```

### B3 · Con el script

```bash
sudo ./scripts/setup-docker.sh <ENDPOINT-RDS> appuser 'CambiaEsto123!' 8080
```

Abre **`http://<IP-PUBLICA>:8080/`** → los mismos productos que en Apache (comparten la base).

---

## Paso final · Verificar todo

```bash
sudo ./scripts/check.sh
```

Revisa capa por capa y marca `[OK]` o `[FALLA]` con el comando para arreglarlo:
Apache, configuración, puertos, HTTP local, Docker, DNS del endpoint, puerto 3306 y login a MySQL.

| Comprobación | Resultado esperado |
| --- | --- |
| `http://<IP>/` | Inventario · *Conectado a RDS* |
| `http://<IP>:8080/` | Inventario · *Conectado a RDS* · mismos datos |
| `http://<IP>/health.php` | `"db": "ok"` |
| `systemctl status apache2` | `active (running)` |
| `docker ps` | `lab-app` en `Up (healthy)` |

## Actualizar la app después de un cambio en GitHub

```bash
cd ~/Practica-aws && git pull
sudo cp -r app/. /var/www/html/ && sudo ./scripts/configurar-db.sh <ENDPOINT-RDS> appuser 'CambiaEsto123!'   # Apache
docker compose up -d --build        # Docker (o repite docker build + docker rm -f lab-app + docker run)
```

## Si algo falla

| Síntoma | Ve a |
| --- | --- |
| No entra por SSH | [01 · Si SSH falla](docs/01-ec2-ssh-security-group.md#si-ssh-falla) |
| La web no carga | [05 · Método de adentro hacia afuera](docs/05-troubleshooting.md#51-método-de-adentro-hacia-afuera) |
| *Sin conexión a la base de datos* | [04 · Probar la conexión](docs/04-rds-mysql.md#44-probar-la-conexión-desde-la-ec2) |
| Cualquier error | [05 · Tabla síntoma → causa → solución](docs/05-troubleshooting.md#53-tabla-síntoma--causa--solución) |
