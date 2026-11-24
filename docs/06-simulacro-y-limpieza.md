# 6 · Simulacro de examen y limpieza

## Simulacro cronometrado (meta: 60 minutos, sin mirar las guías)

Empieza con la cuenta **vacía** (borra todo lo anterior con la sección de limpieza). Usa un
cronómetro y anota cuánto tardas en cada bloque.

| Bloque | Tarea | Meta |
| --- | --- | --- |
| 1 | Crear `sg-web` (22 Mi IP, 80 y 8080 abiertos), key pair, lanzar `lab-web` y entrar por SSH | 12 min |
| 2 | Instalar Apache + PHP **a mano** (sin script) y ver la página por defecto en el navegador | 8 min |
| 3 | Clonar el repo y publicar la app en `/var/www/html` | 5 min |
| 4 | Instalar Docker, construir `lab-app` y publicarlo en el 8080 | 10 min |
| 5 | Crear `sg-rds` y `lab-db` sin acceso público (mientras se crea, sigue con el bloque 4) | 5 min + espera |
| 6 | `nc`, `mysql`, ejecutar `schema.sql`, configurar Apache y Docker con el endpoint | 10 min |
| 7 | Que un compañero rompa 2 cosas (`romper.sh` y una del SG en la consola); encontrarlas y arreglarlas | 10 min |

### Lista de entrega (lo que el evaluador quiere ver)

- [ ] Instancia *En ejecución* y su pestaña **Seguridad** con las reglas.
- [ ] `systemctl status apache2` → *active (running)*.
- [ ] `docker ps` → `lab-app` *Up* con `0.0.0.0:8080->80/tcp`.
- [ ] `http://<IP>/` y `http://<IP>:8080/` mostrando **Conectado a RDS** con productos.
- [ ] RDS *Disponible*, **sin acceso público**, con su SG aceptando 3306 solo desde `sg-web`.
- [ ] Para cada fallo: síntoma → comando de diagnóstico → corrección → prueba.

### Preguntas teóricas que suelen acompañar al práctico

- ¿Qué diferencia hay entre detener y terminar una instancia? *(detener conserva el disco y cambia la IP pública; terminar borra todo)*
- ¿Por qué el origen de la regla 3306 es un Security Group y no una IP? *(la IP de la EC2 puede cambiar; el SG identifica a "las instancias de la app")*
- ¿Qué significa que un Security Group sea *stateful*? *(la respuesta a una conexión permitida sale sola)*
- ¿Por qué RDS sin acceso público? *(la base no debe estar expuesta a internet; solo la app llega a ella)*
- En `-p 8080:80`, ¿qué puerto se abre en el Security Group? *(el 8080, el de la EC2)*
- ¿Dónde se ven los errores de Apache? *(`/var/log/apache2/error.log` y `journalctl -u apache2`)*

---

## Limpieza

Para no generar costos, borra en este orden (RDS primero porque tarda):

1. **RDS** → Bases de datos → `lab-db` → Acciones → **Eliminar** →
   desmarca *Crear instantánea final* y *Retener copias automatizadas* → escribe `delete me` → Eliminar.
2. **EC2** → Instancias → `lab-web` → Estado de la instancia → **Terminar (eliminar) instancia**.
3. **IP elásticas** (si creaste alguna) → Desasociar → **Liberar**.
4. Cuando la instancia y la base ya no existan: **Security Groups** → borra `sg-rds`, `sg-web`
   (y `ec2-rds-*` / `rds-ec2-*` si usaste la opción automática). El grupo `default` no se puede borrar.
5. **Pares de claves** → borra `lab-key` (y la `.pem` de tu PC si ya no la usarás).
6. Revisa **Facturación → Facturas** al día siguiente para confirmar que no queda nada cobrando.

> Si un Security Group no se deja borrar, otro recurso todavía lo usa o lo referencia
> (por ejemplo, `sg-rds` tiene una regla que apunta a `sg-web`: borra primero `sg-rds`).
