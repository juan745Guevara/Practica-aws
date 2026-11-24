# 4 · Base de datos MySQL en RDS y conexión desde EC2

**Objetivo:** una base MySQL en RDS, **sin acceso público**, a la que solo llega la EC2; la tabla de
productos creada; y la app (en Apache y en Docker) mostrando *"Conectado a RDS"* con datos.

Tiempo estimado: 25 minutos (RDS tarda 5–10 en crearse).

---

## 4.1 La regla de oro

```
EC2 (sg-web) ──── 3306 ────▶ RDS (sg-rds)
```

El Security Group de RDS debe aceptar el puerto **3306 con origen = el Security Group de la EC2**
(`sg-web`), **no** una IP ni 0.0.0.0/0. Así solo las instancias que tengan `sg-web` pueden entrar,
aunque cambie su IP.

Hay dos formas de lograrlo. Elige **una**:

| Opción | Cómo | Resultado |
| --- | --- | --- |
| **A · Manual** (recomendada para entender) | Creas `sg-rds` tú mismo (4.2) y lo eliges al crear RDS | Un SG `sg-rds` con la regla 3306 ← `sg-web` |
| **B · Automática** | Al crear RDS eliges *Conectarse a un recurso de computación EC2* → `lab-web` | AWS crea **dos** SG: `ec2-rds-N` (se pega a la EC2, regla de **salida** 3306) y `rds-ec2-N` (en RDS, regla de **entrada** 3306 desde `ec2-rds-N`) |

> Con la opción B verás un SG `ec2-rds-1` con **0 reglas de entrada**. Es normal: su trabajo es la
> regla de salida. No lo edites (su descripción avisa que puede cortar la conexión).

## 4.2 (Opción A) Crear el Security Group `sg-rds`

EC2 → Security Groups → **Crear grupo de seguridad**:

- Nombre `sg-rds` · Descripción `MySQL solo desde sg-web` · VPC predeterminada (**la misma** de la EC2).
- Regla de entrada: Tipo **MYSQL/Aurora** · Puerto 3306 · Origen **Personalizada** → escribe `sg-`
  y elige **`sg-web`** de la lista.
- Crear.

## 4.3 Crear la base de datos `lab-db`

RDS → **Bases de datos → Crear base de datos**:

| Sección | Valor |
| --- | --- |
| Método | **Creación estándar** |
| Motor | **MySQL** (versión por defecto) |
| Plantilla | **Capa gratuita** (si no aparece: *Desarrollo y pruebas* + Single-AZ) |
| Identificador | `lab-db` |
| Nombre de usuario maestro | `admin` |
| Administración de credenciales | **Autoadministrado** · escribe y **anota** la contraseña |
| Clase de instancia | `db.t3.micro` o `db.t4g.micro` |
| Almacenamiento | 20 GiB gp2/gp3 · desmarca *escalado automático* |
| Conectividad → Recurso de computación | **Opción A:** *No conectarse* · **Opción B:** *Conectarse a un recurso de computación EC2* → `lab-web` |
| VPC | la predeterminada (la misma de la EC2) |
| **Acceso público** | **No** |
| Grupo de seguridad de VPC | **Opción A:** *Elegir existente* → `sg-rds` y **quita `default`** · Opción B: lo maneja AWS |
| Configuración adicional → **Nombre de base de datos inicial** | `appdb` (si lo dejas vacío no se crea ninguna base) |
| Copias de seguridad / cifrado / monitoreo | por defecto (puedes desactivar backups para la práctica) |

**Crear base de datos**. Espera el estado **Disponible** (5–10 min).

Entra a `lab-db` → pestaña **Conectividad y seguridad** → copia el **Punto de enlace (endpoint)**:
algo como `lab-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com`. Puerto: 3306.

Comprueba en esa misma pestaña: *Accesible públicamente: No* y el grupo de seguridad correcto.

## 4.4 Probar la conexión desde la EC2

Conectado por SSH a `lab-web`:

```bash
sudo apt install -y mysql-client

# 1) ¿Resuelve el nombre?
nslookup <ENDPOINT-RDS>              # debe dar una IP 172.31.x.x (privada)

# 2) ¿Llega la red al puerto 3306?
nc -zv <ENDPOINT-RDS> 3306           # "succeeded" = Security Groups OK

# 3) ¿Entra el usuario?
mysql -h <ENDPOINT-RDS> -u admin -p
```

Al escribir la contraseña **no se ve nada**: es normal. Entraste cuando ves `mysql>`.

| Resultado | Significado |
| --- | --- |
| `nc` se queda esperando / timeout | Security Group de RDS mal (falta 3306 desde `sg-web`) o VPC distinta |
| `ERROR 1045 Access denied for user 'ubuntu'@...` | Olvidaste **`-u admin`**: MySQL usó tu usuario de Linux |
| `ERROR 1045 Access denied for user 'admin'@...` | Contraseña incorrecta → RDS → Modificar → nueva contraseña maestra → Aplicar inmediatamente |
| `Connections using insecure transport are prohibited` | El servidor exige SSL → agrega `--ssl-mode=REQUIRED` |
| `Unknown MySQL server host` | Endpoint mal copiado o RDS aún creándose |

## 4.5 Crear la tabla, los datos y el usuario de la app

```bash
cd ~/Practica-aws
mysql -h <ENDPOINT-RDS> -u admin -p < sql/schema.sql
```

El script `sql/schema.sql` crea:

- la base `appdb` (si no existe) y la tabla `productos`;
- 3 productos de ejemplo;
- el usuario **`appuser`** / `CambiaEsto123!` con permisos solo sobre `appdb`
  (buena práctica: la app no usa la cuenta `admin`).

Compruébalo:

```bash
mysql -h <ENDPOINT-RDS> -u appuser -p -e "SELECT * FROM appdb.productos;"
```

Comandos SQL útiles dentro de `mysql>`:

```sql
SHOW DATABASES;
USE appdb;
SHOW TABLES;
DESCRIBE productos;
SELECT * FROM productos;
SELECT user, host FROM mysql.user;
EXIT;
```

## 4.6 Conectar la app de Apache

La app lee los datos de `/var/www/html/config.php`. Edítalo a mano:

```bash
sudo nano /var/www/html/config.php
```

Cambia los valores por defecto (`__DB_HOST__`, `__DB_USER__`, `__DB_PASS__`):

```php
define('DB_HOST', getenv('DB_HOST') ?: 'lab-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com');
define('DB_USER', getenv('DB_USER') ?: 'appuser');
define('DB_PASS', getenv('DB_PASS') ?: 'CambiaEsto123!');
```

Guarda (`Ctrl+O`, `Enter`, `Ctrl+X`) y reinicia: `sudo systemctl restart apache2`.

**Atajo con el script:**

```bash
sudo ./scripts/configurar-db.sh <ENDPOINT-RDS> appuser 'CambiaEsto123!'
```

Abre `http://<IP-PUBLICA>/` → recuadro verde **"Conectado a RDS"** y los 3 productos.
Agrega uno y elimínalo para comprobar que también **escribe** en la base.

## 4.7 Conectar la app de Docker

```bash
docker rm -f lab-app
docker run -d --name lab-app --restart unless-stopped -p 8080:80 \
  -e DB_HOST=<ENDPOINT-RDS> -e DB_USER=appuser -e DB_PASS='CambiaEsto123!' -e DB_NAME=appdb \
  lab-app
```

(o `sudo ./scripts/setup-docker.sh <ENDPOINT-RDS> appuser 'CambiaEsto123!' 8080`)

Abre `http://<IP-PUBLICA>:8080/` → los **mismos productos** que en el puerto 80: las dos apps
comparten la misma base de datos. Agrega un producto en una y recarga la otra.

## ✅ Verificación

- [ ] `lab-db` *Disponible*, **sin acceso público**, en la misma VPC que `lab-web`.
- [ ] `nc -zv <ENDPOINT> 3306` → *succeeded*.
- [ ] `mysql -u appuser` muestra los productos.
- [ ] `http://<IP>/` y `http://<IP>:8080/` dicen **Conectado a RDS** y muestran los mismos datos.

Siguiente: [5 · Troubleshooting](05-troubleshooting.md)
