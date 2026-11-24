# 2 · Desplegar la web con Apache

**Objetivo:** que `http://<IP-PUBLICA>/` muestre la app de inventario servida por Apache + PHP.
En esta parte todavía **no hay base de datos**, así que la app mostrará *"Sin conexión a la base
de datos"*. Eso es lo esperado: se conecta en la [Parte 4](04-rds-mysql.md).

Tiempo estimado: 15 minutos. Todo se hace **dentro de la EC2** (conectado por SSH).

---

## 2.1 Instalar Apache y comprobarlo

```bash
sudo apt update
sudo apt install -y apache2
sudo systemctl enable --now apache2     # arranca ahora y en cada reinicio
sudo systemctl status apache2           # debe decir: active (running)  → q para salir
curl -I http://localhost                # debe responder: HTTP/1.1 200 OK
```

Abre `http://<IP-PUBLICA>/` en tu navegador → debe salir **"Apache2 Default Page"** de Ubuntu.

> Escribe **http://**, no https://. Si el navegador cambia solo a https, la página no cargará
> (no hay SSL configurado).

✔️ Si ves la página por defecto, ya probaste tres cosas: Apache corre, el puerto 80 escucha y el
Security Group deja pasar HTTP.

## 2.2 Instalar PHP

```bash
sudo apt install -y php libapache2-mod-php php-mysql
php -v                                  # versión de PHP
php -m | grep mysqli                    # debe aparecer: mysqli
sudo systemctl restart apache2
```

Prueba rápida de PHP:

```bash
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/info.php
```

Abre `http://<IP-PUBLICA>/info.php` → debe salir la tabla morada de PHP. Luego bórrala
(muestra datos del servidor): `sudo rm /var/www/html/info.php`.

## 2.3 Traer la app desde GitHub

```bash
cd ~
sudo apt install -y git
git clone https://github.com/juan745Guevara/Practica-aws.git
cd Practica-aws
ls                                      # app  docker  docs  scripts  sql ...
```

> Alternativa sin Git: desde tu PC, `scp -i lab-key.pem -r ./Practica-aws ubuntu@<IP-PUBLICA>:~`

## 2.4 Publicar la app (a mano)

```bash
sudo rm -f /var/www/html/index.html             # quita la página por defecto
sudo cp -r ~/Practica-aws/app/. /var/www/html/
sudo chown -R www-data:www-data /var/www/html   # www-data = usuario de Apache en Ubuntu
ls -l /var/www/html
sudo systemctl restart apache2
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/    # 200
```

Abre `http://<IP-PUBLICA>/` → debe salir **Inventario** con un recuadro rojo
*"Sin conexión a la base de datos"*. Correcto por ahora.

También puedes ver el diagnóstico en JSON: `http://<IP-PUBLICA>/health.php`
(`"app": "ok"`, `"mysqli": true`, `"db": "error"`).

### Atajo con el script

Todo lo de 2.1 a 2.4 en un solo comando:

```bash
cd ~/Practica-aws
chmod +x scripts/*.sh
sudo ./scripts/setup-apache.sh
```

## 2.5 Dónde está cada cosa en Ubuntu (para el troubleshooting)

| Qué | Ruta / comando |
| --- | --- |
| Archivos de la web | `/var/www/html/` |
| Config principal | `/etc/apache2/apache2.conf` |
| Sitio por defecto (puerto 80) | `/etc/apache2/sites-available/000-default.conf` |
| Puertos en que escucha | `/etc/apache2/ports.conf` |
| Log de errores | `/var/log/apache2/error.log` |
| Log de accesos | `/var/log/apache2/access.log` |
| Validar config | `sudo apache2ctl configtest` → `Syntax OK` |
| Servicio | `sudo systemctl status | restart | stop | start | enable apache2` |
| Usuario de Apache | `www-data` |

> En **Amazon Linux** cambian los nombres: paquete y servicio `httpd`, logs en `/var/log/httpd/`,
> config en `/etc/httpd/conf/httpd.conf`, usuario `apache`, instalador `dnf`.

## ✅ Verificación

- [ ] `systemctl status apache2` → *active (running)* y `enabled`.
- [ ] `http://<IP-PUBLICA>/` muestra **Inventario** (aunque diga *Sin conexión*).
- [ ] `health.php` responde `"app": "ok"` y `"mysqli": true`.

Siguiente: [3 · Despliegue con Docker](03-despliegue-docker.md)
