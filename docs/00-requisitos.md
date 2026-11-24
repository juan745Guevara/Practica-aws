# 0 · Requisitos: tu PC y tu cuenta de AWS

Antes de crear nada en AWS, deja lista tu computadora y revisa la cuenta. Toma unos 10 minutos.

## 0.1 Cuenta de AWS

- Una cuenta propia con capa gratuita, o la cuenta del curso (AWS Academy / Learner Lab).
  - **AWS Academy:** entra al laboratorio → **Start Lab** → espera el círculo verde → botón **AWS**.
    Se abre la consola ya iniciada. La región suele ser obligatoriamente `us-east-1`.
- Arriba a la derecha de la consola, elige la región **Estados Unidos (Norte de Virginia) us-east-1**.
  Todos los recursos de esta práctica deben estar en la **misma región**: si creas la EC2 en una
  región y RDS en otra, no se verán entre sí.

### Costos (para no llevarte sorpresas)

| Recurso | Elige esto | Evita esto |
| --- | --- | --- |
| EC2 | `t2.micro` / `t3.micro` (marcados *Apto para la capa gratuita*) | Tipos más grandes, como `t3.small`, cobran más por hora |
| RDS | Plantilla **Capa gratuita**, `db.t3.micro` / `db.t4g.micro`, 20 GB | Multi-AZ, más almacenamiento, *Producción* |
| IP pública | La IP pública automática de la instancia | IPs elásticas sueltas (cobran) |

Las condiciones de la capa gratuita cambian según la antigüedad y el tipo de cuenta. Revisa
**Facturación → Capa gratuita** en tu consola y apaga todo al terminar.

Al terminar de practicar, sigue la [guía de limpieza](06-simulacro-y-limpieza.md#limpieza).

## 0.2 Cliente SSH en tu PC

| Sistema | Qué usar |
| --- | --- |
| Windows 10/11 | **PowerShell** ya trae `ssh` y `scp`. Compruébalo con `ssh -V` |
| Mac / Linux | La terminal ya trae `ssh` y `scp` |
| Alternativa sin instalar nada | **EC2 Instance Connect** desde la consola (botón *Conectar*) |

## 0.3 Dónde guardar la llave `.pem` (lección aprendida)

La llave privada se descarga **una sola vez** cuando creas el key pair (Parte 1). SSH se niega a usarla
si otros usuarios del PC pueden leerla.

- **Mac / Linux:**
  ```bash
  mv ~/Downloads/lab-key.pem ~/.ssh/
  chmod 400 ~/.ssh/lab-key.pem
  ```
- **Windows (PowerShell):** `chmod` **no funciona** en PowerShell. Usa `icacls`:
  ```powershell
  cd C:\ruta\donde\esta\la\llave
  icacls .\lab-key.pem /reset
  icacls .\lab-key.pem /inheritance:r
  icacls .\lab-key.pem /grant:r "$($env:USERNAME):(R)"
  icacls .\lab-key.pem          # debe mostrar SOLO tu usuario con (R)
  ```
  Si guardas la llave en `C:\` (raíz del disco) Windows le da permisos a todos los usuarios;
  los comandos de arriba los quitan. Si alguno dice *Acceso denegado*, abre PowerShell como
  administrador.

Error típico si no haces esto:

```
WARNING: UNPROTECTED PRIVATE KEY FILE!
Load key "lab-key.pem": bad permissions
Permission denied (publickey).
```

## 0.4 Datos que vas a ir anotando

Ten a mano un bloc de notas con esta plantilla y complétala a medida que avanzas:

```
IP pública EC2 .......:
DNS público EC2 ......:
ID sg-web ............:
ID sg-rds ............:
Endpoint RDS .........:
Usuario maestro RDS ..: admin
Clave maestra RDS ....:
```

## ✅ Verificación

- [ ] Estoy en la región `us-east-1`.
- [ ] `ssh -V` responde en mi terminal.
- [ ] Sé dónde voy a guardar la llave y cómo quitarle permisos.

Siguiente: [1 · EC2, SSH y Security Group](01-ec2-ssh-security-group.md)
