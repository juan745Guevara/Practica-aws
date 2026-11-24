<?php
require_once __DIR__ . '/db.php';

[$conn, $error] = conectar();
$mensaje = null;

if ($conn && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $accion = $_POST['accion'] ?? '';
    if ($accion === 'crear' && trim($_POST['nombre'] ?? '') !== '') {
        $stmt = $conn->prepare('INSERT INTO productos (nombre, precio, stock) VALUES (?, ?, ?)');
        $nombre = trim($_POST['nombre']);
        $precio = (float)($_POST['precio'] ?? 0);
        $stock  = (int)($_POST['stock'] ?? 0);
        $stmt->bind_param('sdi', $nombre, $precio, $stock);
        $mensaje = $stmt->execute() ? 'Producto agregado.' : 'Error al insertar: ' . $stmt->error;
    } elseif ($accion === 'eliminar') {
        $stmt = $conn->prepare('DELETE FROM productos WHERE id = ?');
        $id = (int)($_POST['id'] ?? 0);
        $stmt->bind_param('i', $id);
        $mensaje = $stmt->execute() ? 'Producto eliminado.' : 'Error al eliminar: ' . $stmt->error;
    }
    header('Location: ' . strtok($_SERVER['REQUEST_URI'], '?') . '?m=' . urlencode($mensaje));
    exit;
}

$productos = [];
if ($conn) {
    $res = $conn->query('SELECT id, nombre, precio, stock, creado FROM productos ORDER BY id DESC');
    if ($res) {
        $productos = $res->fetch_all(MYSQLI_ASSOC);
    } else {
        $error = 'Conectado, pero la consulta falló: ' . $conn->error . ' (¿ejecutaste sql/schema.sql?)';
    }
}
$mensaje = $_GET['m'] ?? null;
$h = fn($s) => htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8');
?>
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lab AWS · Inventario</title>
<style>
  body { font-family: system-ui, sans-serif; max-width: 860px; margin: 2rem auto; padding: 0 1rem; color: #222; }
  header { display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: .5rem; }
  .estado { padding: .6rem .9rem; border-radius: 6px; margin: 1rem 0; }
  .ok { background: #e5f4e4; } .err { background: #fbebeb; } .info { background: #e7f1fb; }
  table { width: 100%; border-collapse: collapse; margin-top: 1rem; }
  th, td { text-align: left; padding: .45rem; border-bottom: 1px solid #ddd; }
  form.fila { display: flex; gap: .5rem; flex-wrap: wrap; }
  input { padding: .4rem; } button { padding: .4rem .8rem; cursor: pointer; }
  small { color: #666; }
</style>
</head>
<body>
<header>
  <h1>Inventario</h1>
  <small>Servidor: <?= $h(gethostname()) ?> · <a href="health.php">health</a></small>
</header>

<?php if ($error): ?>
  <div class="estado err"><strong>Sin conexión a la base de datos.</strong><br><?= $h($error) ?><br>
  <small>Host: <?= $h(DB_HOST) ?> · Usuario: <?= $h(DB_USER) ?> · BD: <?= $h(DB_NAME) ?></small></div>
<?php else: ?>
  <div class="estado ok">Conectado a RDS: <?= $h(DB_HOST) ?> (<?= $h($conn->server_info) ?>)</div>
<?php endif; ?>

<?php if ($mensaje): ?><div class="estado info"><?= $h($mensaje) ?></div><?php endif; ?>

<?php if ($conn): ?>
<form class="fila" method="post">
  <input type="hidden" name="accion" value="crear">
  <input name="nombre" placeholder="Nombre" required>
  <input name="precio" type="number" step="0.01" min="0" placeholder="Precio S/">
  <input name="stock" type="number" min="0" placeholder="Stock">
  <button>Agregar</button>
</form>

<table>
  <tr><th>ID</th><th>Producto</th><th>Precio (S/)</th><th>Stock</th><th>Creado</th><th></th></tr>
  <?php foreach ($productos as $p): ?>
  <tr>
    <td><?= $h($p['id']) ?></td>
    <td><?= $h($p['nombre']) ?></td>
    <td><?= number_format((float)$p['precio'], 2) ?></td>
    <td><?= $h($p['stock']) ?></td>
    <td><?= $h($p['creado']) ?></td>
    <td><form method="post" style="margin:0">
      <input type="hidden" name="accion" value="eliminar">
      <input type="hidden" name="id" value="<?= $h($p['id']) ?>">
      <button>Eliminar</button></form></td>
  </tr>
  <?php endforeach; ?>
</table>
<?php endif; ?>
</body>
</html>
