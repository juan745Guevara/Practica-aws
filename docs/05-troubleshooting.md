# 5 · Identificar y solucionar fallos

**Objetivo:** saber encontrar **en qué capa** está el problema y arreglarlo con los comandos
correctos. Es la parte que más puntúa en un examen práctico.

---

## 5.1 Método: de adentro hacia afuera

Revisa en este orden. Cada paso que pasa descarta una capa entera:

| # | Pregunta | Comando | Si falla, el problema está en… |
| --- | --- | --- | --- |
| 1 | ¿El servicio corre? | `systemctl status apache2` · `docker ps -a` | El servicio o el contenedor |
| 2 | ¿La config es válida? | `sudo apache2ctl configtest` · `docker logs lab-app` | Archivos de configuración |
| 3 | ¿Escucha en el puerto correcto? | `sudo ss -tlnp \| grep -E ':80\|:8080'` | Puerto de Apache o mapeo `-p` |
| 4 | ¿Responde dentro de la EC2? | `curl -I http://localhost` · `curl -I http://localhost:8080` | La app (permisos, PHP, código) |
| 5 | ¿Responde desde internet? | Navegador `http://<IP>` | **Security Group** o IP pública cambiada |
| 6 | ¿La EC2 llega a RDS? | `nc -zv <ENDPOINT> 3306` | **Security Group de RDS** o VPC |
| 7 | ¿Las credenciales sirven? | `mysql -h <ENDPOINT> -u appuser -p` | Usuario, clave o nombre de base |

**Regla rápida:** si `curl localhost` funciona pero el navegador no → es el **Security Group**
(o la IP cambió). Si `curl localhost` tampoco funciona → el problema está **dentro** de la EC2.

## 5.2 Comandos de diagnóstico

```bash
# --- Servicios ---
sudo systemctl status apache2
sudo systemctl restart apache2
sudo systemctl is-enabled apache2           # enabled = arranca al reiniciar
sudo journalctl -u apache2 -n 50 --no-pager # por qué no arrancó
sudo apache2ctl configtest                  # "Syntax OK"

# --- Logs de Apache ---
sudo tail -n 50 /var/log/apache2/error.log
sudo tail -f /var/log/apache2/access.log    # en vivo mientras recargas el navegador (Ctrl+C para salir)

# --- Puertos y HTTP ---
sudo ss -tlnp                               # quién escucha en qué puerto
curl -I http://localhost
curl -s http://localhost/health.php

# --- Docker ---
docker ps -a                                # incluye los detenidos (Exited)
docker logs --tail 50 lab-app
docker inspect lab-app | grep -A3 -E '"Ports"|DB_HOST'
docker exec -it lab-app bash
docker restart lab-app

# --- Red hacia RDS ---
nslookup <ENDPOINT>
nc -zv <ENDPOINT> 3306

# --- Recursos de la instancia ---
df -h          # disco lleno
free -m        # memoria
top            # CPU (q para salir)
```

## 5.3 Tabla síntoma → causa → solución

| Síntoma | Causa probable | Cómo lo confirmas | Solución |
| --- | --- | --- | --- |
| SSH: `Connection timed out` | SG sin 22 para tu IP / tu IP cambió | Reglas de entrada de `sg-web` | Regla SSH → *Mi IP* |
| SSH: `Permission denied (publickey)` | Usuario o llave incorrectos | Usuario debe ser `ubuntu` | Usa la llave del key pair de la instancia |
| SSH: `UNPROTECTED PRIVATE KEY FILE` | Permisos de la `.pem` abiertos | Mensaje de ssh | `chmod 400` / `icacls` ([Parte 0](00-requisitos.md)) |
| Navegador no carga, `curl localhost` **sí** | SG sin 80/8080 | Reglas de entrada | Abrir el puerto desde 0.0.0.0/0 |
| Navegador no carga, `curl localhost` **no** | Apache detenido o mal configurado | `systemctl status`, `configtest`, `error.log` | Corregir y `systemctl restart apache2` |
| Funcionaba y tras detener/iniciar ya no | Cambió la IP pública, o servicio sin `enable` | Nueva IP en la consola; `is-enabled` | Usar la IP nueva (o IP elástica); `systemctl enable apache2` |
| `ERR_CONNECTION_REFUSED` con https:// | No hay SSL | La URL empieza con https | Usar `http://` |
| Sale *Apache2 Ubuntu Default Page* | Sigue el `index.html` por defecto | `ls /var/www/html` | `sudo rm /var/www/html/index.html` |
| `403 Forbidden` | Sin `index.php` o sin permisos de lectura | `ls -l /var/www/html`, `error.log` | `chown -R www-data:www-data` y `chmod 644` |
| El navegador **descarga** el `.php` o muestra código | Módulo PHP desactivado | `apache2ctl -M \| grep php` | `sudo a2enmod php8.*` + restart (o instalar `libapache2-mod-php`) |
| Página en blanco o `500` | Error de PHP / falta `mysqli` | `error.log`, `php -m \| grep mysqli` | `apt install php-mysql` + restart |
| App: *Access denied for user* | Clave o usuario mal en `config.php` | `health.php` | Corregir `config.php` / variables `-e` |
| App: *Unknown MySQL server host* | Endpoint mal escrito | `nslookup <host>` | Copiar el endpoint exacto de RDS |
| App: *Unknown database* | No existe `appdb` | `SHOW DATABASES;` | Ejecutar `sql/schema.sql` |
| App o `mysql` se quedan esperando | SG de RDS sin 3306 desde `sg-web`, o VPC distinta | `nc -zv` falla | Regla 3306 con origen **sg-web** |
| *insecure transport are prohibited* | RDS exige SSL | Mensaje del error | `mysql ... --ssl-mode=REQUIRED` (la app ya intenta SSL) |
| Docker: `port is already allocated` | Otro proceso usa ese puerto | `sudo ss -tlnp` | Otro puerto (`-p 8081:80`) o parar el otro |
| Docker: `lab-app` en *Exited* | La app falló o alguien lo detuvo | `docker ps -a`, `docker logs` | `docker start lab-app` / corregir y reconstruir |
| Docker: `permission denied ... docker.sock` | Usuario fuera del grupo docker | `groups` | `sudo usermod -aG docker ubuntu` y reconectar |
| Docker: app no llega a RDS usando `localhost` | localhost = el propio contenedor | `docker inspect` → DB_HOST | Pasar el endpoint en `-e DB_HOST=` |

## 5.4 Practicar con fallos reales: `romper.sh`

El script mete un fallo **sin decirte cuál**, como haría el profesor.

```bash
cd ~/Practica-aws
sudo ./scripts/check.sh               # 1) antes: todo debe salir [OK]
sudo ./scripts/romper.sh              # 2) mete un fallo al azar
#    3) abre la web, investiga con los comandos de 5.2 y arréglalo tú
sudo ./scripts/check.sh               # 4) si te atascas, te dice en qué capa está
sudo ./scripts/romper.sh restaurar    # 5) vuelve todo a la normalidad
```

`sudo ./scripts/romper.sh lista` muestra los fallos posibles. Pistas de cómo se ve cada uno:

| # | Fallo | Cómo se ve |
| --- | --- | --- |
| 1 | Apache detenido y deshabilitado | El navegador no carga; `curl localhost` tampoco |
| 2 | Error de sintaxis en la config | Apache no arranca al reiniciarlo |
| 3 | Clave de BD incorrecta | La web carga, pero dice *Access denied* |
| 4 | Endpoint mal escrito | La web carga, pero dice *Unknown MySQL server host* |
| 5 | `index.php` sin permisos | `403 Forbidden` |
| 6 | Apache en otro puerto | El navegador no carga, pero Apache está *active* |
| 7 | Módulo PHP desactivado | El navegador descarga `index.php` o muestra código |
| 8 | Contenedor detenido | El puerto 8080 no responde |

Fallos que debe provocar **otra persona en la consola de AWS** (el script no puede):

| Letra | Fallo | Cómo se ve |
| --- | --- | --- |
| A | Borrar la regla 80 de `sg-web` | `curl localhost` funciona; el navegador no |
| B | Cambiar el origen de 3306 en el SG de RDS | La web carga lenta y luego *Sin conexión*; `nc` falla |
| C | Detener e iniciar la EC2 | La IP de siempre ya no responde (cambió) |
| D | Quitar `sg-web` de la instancia | Ni SSH ni web |

## 5.5 Qué mostrar cuando arreglas algo

En el examen no basta con arreglarlo: muestra **cómo lo encontraste**.

1. El síntoma (captura del navegador o del error).
2. El comando que reveló la causa (`systemctl status`, `error.log`, `nc -zv`…).
3. El cambio que hiciste.
4. La prueba de que funciona (navegador + `systemctl status` / `docker ps`).

Siguiente: [6 · Simulacro y limpieza](06-simulacro-y-limpieza.md)
