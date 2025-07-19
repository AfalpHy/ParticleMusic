const {app, BrowserWindow, ipcMain, dialog} = require('electron');
const fs = require('fs');
const path = require('path');

let mainWindow;

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

function createWindow() {
  mainWindow = new BrowserWindow({
    minWidth: 1050,
    minHeight: 750,
    width: 1050,
    height: 750,
    transparent: true,
    frame: false,
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
}

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

ipcMain.on('window-close', () => {
  mainWindow.close();
})

ipcMain.on('window-minimize', () => {mainWindow.minimize()})

ipcMain.on('window-toggle', () => {
  if (mainWindow.isMaximized()) {
    mainWindow.unmaximize();
    mainWindow.webContents.send('remove-corner');
  } else {
    mainWindow.webContents.send('add-corner');
    mainWindow.maximize();
  }
})

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

ipcMain.on('get-songs', async () => {
  let songPaths = await findSongs(path.resolve('music'))
  let songBases = songPaths.slice(0, songPaths.length);
  for (let i = 0; i < songBases.length; i++) {
    songBases[i] = path.basename(songBases[i], path.extname(songBases[i]));
  }
  // Send to renderer
  mainWindow.webContents.send('initial-songs', songPaths, songBases);
  for (let i = 0; i < songPaths.length; i++) {
    const metadata = await getAudioMetadata(songPaths[i]);
    mainWindow.webContents.send('add-song', metadata);
  }
})

const musicMetadata = require('music-metadata');

const formatDuration = (seconds) => {
  if (isNaN(seconds)) return '00:00';

  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = Math.floor(seconds % 60);

  // Pad with leading zeros
  const paddedMinutes = String(minutes).padStart(2, '0');
  const paddedSeconds = String(remainingSeconds).padStart(2, '0');

  return `${paddedMinutes}:${paddedSeconds}`;
};

async function getAudioMetadata(filePath) {
  try {
    const metadata = await musicMetadata.parseFile(filePath);
    return {
      title: metadata.common.title ||
          path.basename(filePath, path.extname(filePath)),
      artist: metadata.common.artist || 'Unknown Artist',
      album: metadata.common.album || 'Unknown',
      duration: formatDuration(metadata.format.duration)
    };
  } catch (error) {
    console.error('Error reading metadata:', error);
    return null;
  }
}
