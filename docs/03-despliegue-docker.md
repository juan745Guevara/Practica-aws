# 3 · Desplegar la web con Docker

**Objetivo:** la misma app corriendo dentro de un contenedor, publicada en el puerto **8080**
(`http://<IP-PUBLICA>:8080/`), al lado de Apache que sigue en el 80.

Tiempo estimado: 15 minutos. Todo se hace **dentro de la EC2**.

---

## 3.1 Instalar Docker

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo systemctl status docker            # active (running)
sudo usermod -aG docker ubuntu          # para usar docker sin sudo
exit                                    # sal y vuelve a entrar por SSH para que tome el grupo
```

Vuelve a conectarte y prueba:

```bash
docker run hello-world                  # "Hello from Docker!"
docker ps -a                            # el contenedor hello-world aparece como Exited (normal)
```

## 3.2 Prueba rápida con Nginx (opcional, para entender `-p`)

```bash
docker run -d --name prueba -p 8080:80 nginx
docker ps                               # STATUS: Up ... · PORTS: 0.0.0.0:8080->80/tcp
curl -I http://localhost:8080           # 200 OK
```

Abre `http://<IP-PUBLICA>:8080/` → *Welcome to nginx!*

`-p 8080:80` significa **puerto de la EC2 : puerto dentro del contenedor**. El Security Group
debe abrir el de la **izquierda** (8080).

Borra la prueba: `docker rm -f prueba`

## 3.3 Construir la imagen de la app

El `Dockerfile` del repositorio:

```dockerfile
FROM php:8.3-apache                          # PHP + Apache ya instalados
RUN docker-php-ext-install mysqli            # extensión para MySQL
COPY app/ /var/www/html/                     # copia la app
RUN chown -R www-data:www-data /var/www/html
HEALTHCHECK ... curl -fs http://localhost/health.php
EXPOSE 80
```

```bash
cd ~/Practica-aws
docker build -f docker/Dockerfile -t lab-app .     # el punto final = contexto: la carpeta del repo
docker images                                      # aparece lab-app
```

## 3.4 Ejecutar el contenedor

Sin base de datos todavía:

```bash
docker run -d --name lab-app --restart unless-stopped -p 8080:80 lab-app
docker ps                                          # lab-app  Up  0.0.0.0:8080->80/tcp
curl -s http://localhost:8080/health.php
```

Abre `http://<IP-PUBLICA>:8080/` → **Inventario** con *Sin conexión*. En la cabecera, el
*Servidor* es el ID del contenedor (no el hostname de la EC2): así distingues qué despliegue estás viendo.

Cuando tengas RDS (Parte 4), el contenedor recibe los datos por **variables de entorno**:

```bash
docker rm -f lab-app
docker run -d --name lab-app --restart unless-stopped -p 8080:80 \
  -e DB_HOST=<ENDPOINT-RDS> -e DB_USER=appuser -e DB_PASS='CambiaEsto123!' -e DB_NAME=appdb \
  lab-app
```

> ⚠️ Dentro de un contenedor, `localhost` es el propio contenedor, no la EC2 ni RDS.
> `DB_HOST` siempre es el **endpoint de RDS**.

### Atajo con el script

```bash
sudo ./scripts/setup-docker.sh                                          # sin BD, puerto 8080
sudo ./scripts/setup-docker.sh <ENDPOINT-RDS> appuser 'CambiaEsto123!' 8080   # con BD
```

O copia `.env.example` como `.env`, complétalo y ejecuta `sudo ./scripts/setup-docker.sh` sin argumentos.

## 3.5 Comandos de Docker que debes dominar

| Para | Comando |
| --- | --- |
| Ver contenedores corriendo / todos | `docker ps` / `docker ps -a` |
| Ver logs | `docker logs --tail 50 lab-app` · en vivo: `docker logs -f lab-app` |
| Entrar al contenedor | `docker exec -it lab-app bash` |
| Ver puertos y variables | `docker port lab-app` · `docker inspect lab-app` |
| Detener / iniciar / reiniciar | `docker stop lab-app` · `docker start lab-app` · `docker restart lab-app` |
| Borrar contenedor | `docker rm -f lab-app` |
| Ver imágenes / borrar imagen | `docker images` · `docker rmi lab-app` |
| Salud del contenedor | `docker inspect --format '{{.State.Health.Status}}' lab-app` |

## ✅ Verificación

- [ ] `docker ps` muestra `lab-app` en estado **Up** con `0.0.0.0:8080->80/tcp`.
- [ ] `http://<IP-PUBLICA>:8080/` muestra **Inventario**.
- [ ] `http://<IP-PUBLICA>/` (Apache) sigue funcionando.

Siguiente: [4 · RDS MySQL](04-rds-mysql.md)
