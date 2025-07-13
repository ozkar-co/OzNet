const express = require('express');
const exphbs = require('express-handlebars');
const path = require('path');
const fs = require('fs-extra');
const { exec } = require('child_process');
const util = require('util');
const execAsync = util.promisify(exec);

const app = express();

// Registrar helpers
const hbs = exphbs.create({
  defaultLayout: 'main',
  layoutsDir: path.join(__dirname, 'views/layouts'),
  partialsDir: path.join(__dirname, 'views/partials'),
  helpers: {
    eq: (a, b) => a === b,
    encodeURIComponent: (str) => encodeURIComponent(str),
    getFileIcon: (filename, isDirectory) => {
      if (isDirectory) return '📁';
      const ext = path.extname(filename).toLowerCase();
      const imageExts = ['.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp'];
      const archiveExts = ['.zip', '.tar', '.gz', '.rar', '.7z'];
      if (imageExts.includes(ext)) return '🖼️';
      if (archiveExts.includes(ext)) return '📦';
      return '📄';
    },
    formatDate: (date) => {
      if (!date) return '';
      return new Date(date).toLocaleString('es-ES');
    }
  }
});
app.engine('handlebars', hbs.engine);
app.set('view engine', 'handlebars');
app.set('views', path.join(__dirname, 'views'));

// Middleware para parsear JSON
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Servir archivos estáticos
app.use('/static', express.static(path.join(__dirname, 'public')));

// Configuración del directorio de archivos
const FILES_ROOT = process.env.FILES_ROOT || '/var/oznet/files';
const MAX_FILE_SIZE = 1024 * 1024 * 1024; // 1GB

// Función para obtener información de archivos
async function getFileInfo(filePath) {
  try {
    const stats = await fs.stat(filePath);
    const isDirectory = stats.isDirectory();
    
    return {
      name: path.basename(filePath),
      path: filePath,
      size: isDirectory ? null : formatBytes(stats.size),
      modified: stats.mtime,
      isDirectory,
      isFile: stats.isFile(),
      permissions: stats.mode.toString(8).slice(-3)
    };
  } catch (error) {
    return null;
  }
}

// Función para formatear bytes
function formatBytes(bytes) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Función para obtener el tipo MIME
function getMimeType(filename) {
  const ext = path.extname(filename).toLowerCase();
  const mimeTypes = {
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.webp': 'image/webp',
    '.pdf': 'application/pdf',
    '.txt': 'text/plain',
    '.md': 'text/markdown',
    '.epub': 'application/epub+zip',
    '.zip': 'application/zip',
    '.tar': 'application/x-tar',
    '.gz': 'application/gzip',
    '.rar': 'application/vnd.rar',
    '.7z': 'application/x-7z-compressed',
    '.exe': 'application/x-msdownload',
    '.msi': 'application/x-msi',
    '.deb': 'application/vnd.debian.binary-package',
    '.iso': 'application/x-iso9660-image',
    '.sh': 'application/x-sh'
  };
  return mimeTypes[ext] || 'application/octet-stream';
}

// Función para listar directorio
async function listDirectory(dirPath) {
  try {
    const items = await fs.readdir(dirPath);
    const fileInfos = [];
    
    for (const item of items) {
      const fullPath = path.join(dirPath, item);
      const fileInfo = await getFileInfo(fullPath);
      if (fileInfo) {
        fileInfos.push(fileInfo);
      }
    }
    
    // Ordenar: directorios primero, luego archivos, ambos alfabéticamente
    return fileInfos.sort((a, b) => {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.localeCompare(b.name);
    });
  } catch (error) {
    return [];
  }
}

// Rutas
app.get('/', async (req, res) => {
  const currentPath = req.query.path || FILES_ROOT;
  
  try {
    // Verificar que el path esté dentro del directorio raíz
    const normalizedPath = path.resolve(currentPath);
    if (!normalizedPath.startsWith(path.resolve(FILES_ROOT))) {
      return res.redirect('/');
    }
    
    const stats = await fs.stat(normalizedPath);
    if (!stats.isDirectory()) {
      return res.redirect('/');
    }
    
    const files = await listDirectory(normalizedPath);
    const breadcrumbs = getBreadcrumbs(normalizedPath);
    
    res.render('browser', {
      title: 'Files - OzNet',
      currentPath: normalizedPath,
      files: files,
      breadcrumbs: breadcrumbs,
      relativePath: path.relative(FILES_ROOT, normalizedPath) || '.'
    });
  } catch (error) {
    res.status(500).render('error', {
      title: 'Error - OzNet Files',
      error: 'No se pudo acceder al directorio'
    });
  }
});

// Función para generar breadcrumbs
function getBreadcrumbs(currentPath) {
  const relativePath = path.relative(FILES_ROOT, currentPath);
  if (!relativePath || relativePath === '.') {
    return [{ name: 'Inicio', path: FILES_ROOT }];
  }
  
  const parts = relativePath.split(path.sep);
  const breadcrumbs = [{ name: 'Inicio', path: FILES_ROOT }];
  
  let current = FILES_ROOT;
  for (const part of parts) {
    current = path.join(current, part);
    breadcrumbs.push({
      name: part,
      path: current
    });
  }
  
  return breadcrumbs;
}

// Servir archivos
app.get('/download', async (req, res) => {
  const filePath = req.query.path;
  
  if (!filePath) {
    return res.status(400).send('Path requerido');
  }
  
  try {
    const normalizedPath = path.resolve(filePath);
    
    // Verificar que el archivo esté dentro del directorio raíz
    if (!normalizedPath.startsWith(path.resolve(FILES_ROOT))) {
      return res.status(403).send('Acceso denegado');
    }
    
    const stats = await fs.stat(normalizedPath);
    if (!stats.isFile()) {
      return res.status(400).send('No es un archivo');
    }
    
    // Verificar tamaño del archivo
    if (stats.size > MAX_FILE_SIZE) {
      return res.status(413).send('Archivo demasiado grande');
    }
    
    const mimeType = getMimeType(normalizedPath);
    const filename = path.basename(normalizedPath);
    
    res.setHeader('Content-Type', mimeType);
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    
    const stream = fs.createReadStream(normalizedPath);
    stream.pipe(res);
  } catch (error) {
    res.status(500).send('Error al descargar archivo');
  }
});

// API para obtener información de archivos
app.get('/api/info', async (req, res) => {
  const filePath = req.query.path;
  
  if (!filePath) {
    return res.status(400).json({ error: 'Path requerido' });
  }
  
  try {
    const normalizedPath = path.resolve(filePath);
    
    if (!normalizedPath.startsWith(path.resolve(FILES_ROOT))) {
      return res.status(403).json({ error: 'Acceso denegado' });
    }
    
    const fileInfo = await getFileInfo(normalizedPath);
    if (!fileInfo) {
      return res.status(404).json({ error: 'Archivo no encontrado' });
    }
    
    res.json(fileInfo);
  } catch (error) {
    res.status(500).json({ error: 'Error interno' });
  }
});

// Estadísticas del servidor de archivos
app.get('/stats', async (req, res) => {
  try {
    const { stdout: diskUsage } = await execAsync(`df -h "${FILES_ROOT}" | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}'`);
    const { stdout: fileCount } = await execAsync(`find "${FILES_ROOT}" -type f | wc -l`);
    const { stdout: dirCount } = await execAsync(`find "${FILES_ROOT}" -type d | wc -l`);
    
    res.render('stats', {
      title: 'Estadísticas - OzNet Files',
      stats: {
        diskUsage: diskUsage.trim(),
        fileCount: parseInt(fileCount.trim()),
        dirCount: parseInt(dirCount.trim()),
        rootPath: FILES_ROOT
      }
    });
  } catch (error) {
    res.render('stats', {
      title: 'Estadísticas - OzNet Files',
      stats: {
        diskUsage: 'Error',
        fileCount: 0,
        dirCount: 0,
        rootPath: FILES_ROOT
      }
    });
  }
});

module.exports = app; 