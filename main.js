const { app, BrowserWindow, ipcMain } = require('electron');
const os = require('os');
const fs = require('fs');
const path = require('path');
const getColors = require('get-image-colors')

let mainWindow;

app.whenReady().then(() => {
  createWindow();
});

function createWindow() {
  mainWindow = new BrowserWindow({
    minWidth: 1050,
    minHeight: 750,
    width: 1050,
    height: 750,
    frame: false,
    icon: path.join(__dirname, 'pictures/icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.loadFile('index.html');

  if (process.env.NODE_ENV === 'development') {
    mainWindow.webContents.openDevTools();
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  mainWindow.on('maximize', () => {
    mainWindow.webContents.send('maximize');
  })

  mainWindow.on('unmaximize', () => {
    mainWindow.webContents.send('unmaximize');
  })

  mainWindow.webContents.on('did-finish-load', async () => {
    const iconBuff = await fs.promises.readFile(path.join(__dirname, 'pictures/icon.png'));
    const colors = (await getColors(iconBuff, 'image/png')).map(color => color.hex());
    const base64String = iconBuff.toString('base64');
    const result = { coverDataUrl: `data:image/png;base64,${base64String}`, color: colors[0] };
    mainWindow.webContents.send('set-default-cover', result);

    await loadPlaylist();
  });
}

ipcMain.on('window-close', () => {
  mainWindow.close();
})

ipcMain.on('window-minimize', () => { mainWindow.minimize() })

ipcMain.on('window-resize', () => {
  if (mainWindow.isMaximized()) {
    mainWindow.unmaximize();
  } else {
    mainWindow.maximize();
  }
})

ipcMain.on('window-enter-fullScreen', () => {
  mainWindow.setFullScreen(true);
});

ipcMain.on('window-leave-fullScreen', () => {
  mainWindow.setFullScreen(false);
});

async function findSongs(dirPath) {
  try {
    const files = await fs.promises.readdir(dirPath)
    return files
      .filter(
        file => ['.mp3', '.wav', '.flac', '.aac', '.ogg'].includes(
          path.extname(file).toLowerCase()))
      .map(file => path.join(dirPath, file))
  } catch (error) {
    console.error('Error finding songs:', error)
    return []
  }
}

const musicDirectory = path.join(os.homedir(), 'Music');

async function loadPlaylist() {
  mainWindow.webContents.send('set-loading-playlist');

  let songPaths = await findSongs(musicDirectory);

  mainWindow.webContents.send('reset-playlist', songPaths.length);

  let taskNum = 4;
  let metadatas = []
  const workerPromises = [];
  for (let i = 0; i < taskNum; i++) {
    workerPromises.push(new Promise((resolve, reject) => {
      const worker = new Worker(path.join(__dirname, './worker.js'));

      worker.on('message', (result) => {
        metadatas.push(result);
        if (metadatas.length == 10) {
          mainWindow.webContents.send('song-metadatas', metadatas);
          metadatas = [];
        }
      });

      worker.on('error', reject);
      worker.on('exit', (code) => {
        if (code !== 0) reject(new Error(`Worker stopped with code ${code}`));
        else resolve(); // resolve if exited normally and no done message
      });

      worker.postMessage({ songPaths: songPaths, id: i, taskNum: taskNum });
    }));
  }

  await Promise.all(workerPromises);
  mainWindow.webContents.send('song-metadatas', metadatas);
  mainWindow.webContents.send('unset-loading-playlist');
}

const chokidar = require('chokidar');
const watcher = chokidar.watch(musicDirectory, { persistent: true });

let enable = 0;
let modified = 0;

async function updatePlaylist() {
  if (modified) {
    await loadPlaylist();
    modified = 0;
  }
  setTimeout(() => {
    updatePlaylist();
  }, 3000);
}

watcher.on('ready', async (event, path) => {
  enable = 1;
  updatePlaylist();
});

watcher.on('all', async (event, path) => {
  if (enable) {
    modified = 1;
  }
});

const { Worker } = require('worker_threads');

const { parseFile } = require('music-metadata');

function hexToRgb(hex) {
  const bigint = parseInt(hex.slice(1), 16);
  return [
    (bigint >> 16) & 255,
    (bigint >> 8) & 255,
    bigint & 255,
  ];
}

function rgbToHex(r, g, b) {
  return "#" + [r, g, b].map(x => x.toString(16).padStart(2, '0')).join('');
}

function mixColors(colors, weights) {
  let r = 0, g = 0, b = 0;
  let totalWeight = 0;

  colors.forEach((color, i) => {
    const weight = weights ? weights[i] : 1;
    const [cr, cg, cb] = hexToRgb(color.hex());
    r += cr * weight;
    g += cg * weight;
    b += cb * weight;
    totalWeight += weight;
  });

  r = Math.round(r / totalWeight);
  g = Math.round(g / totalWeight);
  b = Math.round(b / totalWeight);

  return rgbToHex(r, g, b);
}
function detectImageType(buffer) {
  if (buffer.slice(0, 2).toString('hex') === 'ffd8') return 'image/jpeg';
  if (buffer.slice(0, 8).toString('hex') === '89504e470d0a1a0a') return 'image/png';
  return null;
}

ipcMain.handle('get-color', async (event, filePath) => {
  try {
    const metadata = await parseFile(filePath)
    const picture = metadata.common.picture?.[0];
    if (picture) {
      const pictureBuffer = Buffer.from(picture.data);
      const realType = detectImageType(pictureBuffer);
      if (realType) {
        const colors = await getColors(pictureBuffer, realType);
        return mixColors(colors, [0.6, 0.1, 0.1, 0.1, 0.1]);
      } else {
        const colors = await getColors(pictureBuffer, picture.format);
        return mixColors(colors, [0.6, 0.1, 0.1, 0.1, 0.1]);
      }
    } else {
      return null;
    }
  } catch (error) {
    console.error('Error reading metadata:', error, filePath);
    return null;
  }
})

ipcMain.handle('get-lyrics', async (event, filePath) => {
  try {
    const metadata = await parseFile(filePath);
    if (metadata.common.lyrics) {
      if (metadata.common.lyrics[0].syncText) {
        let lines = [];
        metadata.common.lyrics[0].syncText.forEach(element => {
          lines.push({ time: element.timestamp, text: element.text });
        })
        return { lyrics: lines, pureText: 0 };
      }
      return { lyrics: metadata.common.lyrics[0].text, pureText: 1 };
    }
    return null;
  } catch (error) {
    console.error('Error reading metadata:', error, filePath);
    return null;
  }
})