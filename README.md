# Práctica AWS: EC2 + Apache/Docker + RDS MySQL

Práctica completa para el examen práctico de AWS. Partiendo de una cuenta **sin ningún recurso creado**,
vas a desplegar una app web de inventario (PHP) en una instancia EC2, primero con Apache y luego con
Docker, conectarla a una base de datos MySQL en RDS, y practicar cómo encontrar y arreglar fallos.

```
                       Internet
                          │
         ┌────────────────┼──────────────────────────────────────────┐
         │ VPC por defecto│                                          │
         │                ▼                                          │
         │   ┌──────────────────────────┐        ┌─────────────────┐ │
 Tu PC ──┼──▶│ EC2  lab-web (Ubuntu)    │ 3306   │ RDS  lab-db     │ │
  SSH 22 │   │  Apache :80              │───────▶│ MySQL           │ │
         │   │  Docker :8080            │        │ sin acceso      │ │
Navegador┼──▶│  SG: sg-web              │        │ público         │ │
 HTTP 80 │   └──────────────────────────┘        │ SG: sg-rds      │ │
   /8080 │                                        └─────────────────┘ │
         └───────────────────────────────────────────────────────────┘
```

> **¿Solo quieres desplegar la app?** Ve directo a la **[Guía de despliegue](DESPLIEGUE.md)**
> (clonar → Apache en el 80 → Docker en el 8080).

## Los 4 temas del examen y dónde está cada uno

| # | Tema del examen | Guía |
| --- | --- | --- |
| 0 | Preparar tu PC y tu cuenta | [docs/00-requisitos.md](docs/00-requisitos.md) |
| 1 | Crear/administrar EC2, acceso SSH y reglas del Security Group | [docs/01-ec2-ssh-security-group.md](docs/01-ec2-ssh-security-group.md) |
| 2 | Desplegar la web con **Apache** y comprobarla en el navegador | [docs/02-despliegue-apache.md](docs/02-despliegue-apache.md) |
| 2 | Desplegar la web con **Docker** y comprobarla en el navegador | [docs/03-despliegue-docker.md](docs/03-despliegue-docker.md) |
| 3 | Crear MySQL en **RDS** y conectarlo desde la app en EC2 | [docs/04-rds-mysql.md](docs/04-rds-mysql.md) |
| 4 | Identificar errores, revisar servicios, logs y contenedores, y solucionarlos | [docs/05-troubleshooting.md](docs/05-troubleshooting.md) |
| — | Simulacro cronometrado y limpieza para no pagar | [docs/06-simulacro-y-limpieza.md](docs/06-simulacro-y-limpieza.md) |

Sigue las guías **en orden**. Cada una termina con una lista de verificación: no pases a la
siguiente hasta que todo esté marcado.

## Qué hay en el repositorio

| Ruta | Qué es |
| --- | --- |
| `app/index.php` | App de inventario: lista, agrega y elimina productos |
| `app/health.php` | Diagnóstico en JSON: estado de la app, extensión mysqli y conexión a la BD |
| `app/config.php` | Plantilla de credenciales (variables de entorno o valores que escribe el script) |
| `app/db.php` | Conexión a MySQL (intenta SSL y, si no aplica, sin SSL) |
| `sql/schema.sql` | Crea la base `appdb`, la tabla `productos`, 3 filas y el usuario `appuser` |
| `docker/Dockerfile` | Imagen `php:8.3-apache` con mysqli y healthcheck |
| `docker-compose.yml` | Levanta el contenedor leyendo los datos de RDS desde `.env` |
| `DESPLIEGUE.md` | Guía corta de despliegue (Apache y Docker) |
| `scripts/setup-apache.sh` | Instala Apache + PHP y publica la app en el puerto 80 |
| `scripts/configurar-db.sh` | Escribe el endpoint, usuario y clave de RDS en la app de Apache |
| `scripts/setup-docker.sh` | Instala Docker, construye la imagen y publica la app en el 8080 |
| `scripts/check.sh` | Revisa capa por capa (servicio, puertos, HTTP, Docker, red a RDS, login) |
| `scripts/romper.sh` | Mete fallos al azar para practicar el diagnóstico; `restaurar` los deshace |
| `.env.example` | Plantilla de variables para Docker (copiar como `.env`, que no se sube) |

## Resumen ultra corto (cuando ya lo dominas)

```bash
# En la EC2 (Ubuntu), ya conectado por SSH
git clone https://github.com/juan745Guevara/Practica-aws.git && cd Practica-aws
chmod +x scripts/*.sh
sudo ./scripts/setup-apache.sh                                   # web en :80
mysql -h <ENDPOINT> -u admin -p < sql/schema.sql                 # tabla + datos + appuser
sudo ./scripts/configurar-db.sh <ENDPOINT> appuser 'CambiaEsto123!'
sudo ./scripts/setup-docker.sh <ENDPOINT> appuser 'CambiaEsto123!' 8080   # web en :8080
sudo ./scripts/check.sh                                          # todo en [OK]
```

> **En el examen probablemente no tendrás estos scripts.** Cada guía explica primero los comandos
> a mano (lo que debes saber hacer) y luego el atajo con el script.

## Nombres usados en toda la práctica

| Recurso | Nombre |
| --- | --- |
| Región | `us-east-1` (Norte de Virginia) |
| Key pair | `lab-key` (archivo `lab-key.pem`) |
| Security Group de la EC2 | `sg-web` |
| Security Group de RDS | `sg-rds` |
| Instancia EC2 | `lab-web` |
| Base de datos RDS | `lab-db` (usuario maestro `admin`) |
| Base de datos / usuario de la app | `appdb` / `appuser` |
