# 1 · EC2, acceso SSH y Security Group

**Objetivo:** una instancia Ubuntu encendida, a la que entras por SSH, con un Security Group que deja
pasar SSH (22), la web con Apache (80) y la web con Docker (8080).

Tiempo estimado: 15 minutos.

---

## 1.1 Crear el Security Group `sg-web`

Se crea primero para luego elegirlo al lanzar la instancia (también puedes crearlo dentro del asistente
de lanzamiento, pero así queda con un nombre claro).

1. Consola → busca **EC2** → menú izquierdo **Red y seguridad → Security Groups** → **Crear grupo de seguridad**.
   > ⚠️ No confundir con **AWS Resource Groups** (Grupos de recursos): es otro servicio.
2. Nombre: `sg-web` · Descripción: `Web y SSH para lab-web` · VPC: la **predeterminada**.
3. **Reglas de entrada** → *Agregar regla* tres veces:

   | Tipo | Puerto | Tipo de origen | Origen | Para qué |
   | --- | --- | --- | --- | --- |
   | SSH | 22 | **Mi IP** | tu IP/32 (se llena sola) | Entrar por SSH solo desde tu PC |
   | HTTP | 80 | **Anywhere-IPv4** | 0.0.0.0/0 | Ver la web con Apache |
   | TCP personalizado | 8080 | **Anywhere-IPv4** | 0.0.0.0/0 | Ver la web con Docker |

4. **Reglas de salida**: déjalas como están (todo el tráfico permitido).
5. **Crear grupo de seguridad**. Anota el ID (`sg-0abc...`).

Errores comunes en esta pantalla:

- *"Se debe especificar un bloque de CIDR, un ID de grupo de seguridad o una lista de prefijos"* →
  dejaste el **Origen** vacío con tipo *Personalizada*. Elige *Mi IP* o *Anywhere-IPv4*.
- El aviso amarillo *"Reglas con origen 0.0.0.0/0 permiten que todas las direcciones IP accedan…"*
  aparece si abres el 22 a todo el mundo. Para practicar funciona; en el examen usa **Mi IP**.
- HTTPS (443) no hace falta: la práctica no usa certificado SSL.

> **Conceptos que te pueden preguntar:** un Security Group es un firewall **a nivel de instancia**,
> solo tiene reglas de **permitir** (no de denegar) y es **stateful**: si una conexión entra
> permitida, su respuesta sale sola aunque no haya regla de salida. Los cambios se aplican al
> instante, sin reiniciar la instancia.

## 1.2 Crear el key pair `lab-key`

1. EC2 → **Red y seguridad → Pares de claves** → **Crear par de claves**.
2. Nombre `lab-key` · Tipo **RSA** · Formato **.pem** (Windows/Mac/Linux con OpenSSH) o **.ppk** (solo PuTTY).
3. Se descarga `lab-key.pem` **una sola vez**. Guárdala y quítale permisos como dice
   [0 · Requisitos](00-requisitos.md#03-dónde-guardar-la-llave-pem-lección-aprendida).

## 1.3 Lanzar la instancia `lab-web`

EC2 → **Instancias → Lanzar instancias**:

| Campo | Valor |
| --- | --- |
| Nombre | `lab-web` |
| AMI | **Ubuntu Server 24.04 LTS** (o la más reciente), 64 bits (x86) |
| Tipo de instancia | `t2.micro` o `t3.micro` (*Apto para la capa gratuita*) |
| Par de claves | `lab-key` |
| Configuración de red → *Editar* | VPC predeterminada · Subred: cualquiera · **Asignar IP pública automáticamente: Habilitar** |
| Firewall (grupos de seguridad) | **Seleccionar un grupo existente** → `sg-web` |
| Almacenamiento | 8 GiB gp3 (por defecto) |

**Lanzar instancia** → **Ver todas las instancias**. Espera hasta ver:

- Estado de la instancia: **En ejecución**
- Comprobación de estado: **3/3 comprobaciones superadas** (o 2/2)

Selecciónala y anota la **Dirección IPv4 pública** y el **DNS de IPv4 público**.

## 1.4 Conectarte por SSH

Desde la carpeta donde está la llave:

```bash
ssh -i lab-key.pem ubuntu@<IP-PUBLICA>
```

- La primera vez pregunta `Are you sure you want to continue connecting (yes/no)?` → escribe `yes`.
- El usuario en Ubuntu es **`ubuntu`**. En Amazon Linux sería `ec2-user`.
- Entraste cuando el prompt cambia a algo como `ubuntu@ip-172-31-28-236:~$`.

Primeros comandos dentro de la instancia:

```bash
sudo apt update && sudo apt upgrade -y
hostname -I          # IP privada
curl -s ifconfig.me  # IP pública (para confirmar)
```

**Alternativa sin llave:** EC2 → selecciona la instancia → **Conectar → EC2 Instance Connect → Conectar**.
Abre una terminal en el navegador. Requiere que la regla del 22 acepte el rango de AWS (con *Mi IP*
puede fallar; temporalmente usa 0.0.0.0/0).

### Si SSH falla

| Mensaje | Causa | Solución |
| --- | --- | --- |
| `Connection timed out` | El SG no permite el 22 desde tu IP (o tu IP cambió: otra red, otro wifi) | Edita la regla SSH → *Mi IP* otra vez |
| `UNPROTECTED PRIVATE KEY FILE` / `bad permissions` | La llave tiene permisos abiertos | `chmod 400` (Mac/Linux) o `icacls` (Windows), ver Parte 0 |
| `Permission denied (publickey)` | Usuario incorrecto o llave de otro key pair | Usuario `ubuntu`; usa la llave con la que lanzaste la instancia |
| `Connection refused` | La instancia aún está arrancando | Espera a 3/3 comprobaciones |

## 1.5 Administrar la instancia (lo que te pueden pedir)

| Acción | Dónde | Qué pasa |
| --- | --- | --- |
| Detener / Iniciar | Estado de la instancia | **La IP pública cambia** al volver a iniciar. El disco se conserva |
| Reiniciar | Estado de la instancia | La IP se mantiene |
| Terminar | Estado de la instancia | Borra la instancia (y su disco) para siempre |
| IP fija | Red y seguridad → **IP elásticas** → Asignar → Asociar a `lab-web` | La IP ya no cambia al detener/iniciar |
| Cambiar reglas | Security Groups → `sg-web` → **Editar reglas de entrada** | Aplica al instante |
| Ver qué SG tiene | Instancia → pestaña **Seguridad** | Lista los grupos y sus reglas combinadas |
| Agregar otro SG | Instancia → Acciones → Seguridad → **Cambiar grupos de seguridad** | Una instancia puede tener varios SG; sus reglas se suman |

## ✅ Verificación

- [ ] `sg-web` tiene 22 (Mi IP), 80 y 8080 (0.0.0.0/0).
- [ ] `lab-web` está *En ejecución* con 3/3 comprobaciones.
- [ ] Entro por SSH y veo `ubuntu@ip-...:~$`.
- [ ] Anoté la IP pública y el DNS público.

Siguiente: [2 · Despliegue con Apache](02-despliegue-apache.md)
