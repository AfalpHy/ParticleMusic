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
  mainWindow.webContents.send('initial-songs', songPaths, songBases)
})

const musicMetadata = require('music-metadata');

async function getAudioMetadata(filePath) {
  try {
    const metadata = await musicMetadata.parseFile(filePath);
    return {
      title: metadata.common.title ||
          path.basename(filePath, path.extname(filePath)),
      artist: metadata.common.artist || 'Unknown Artist',
      album: metadata.common.album,
      duration: metadata.format.duration,
      picture: metadata.common.picture
    };
  } catch (error) {
    console.error('Error reading metadata:', error);
    return null;
  }
}


ipcMain.on('open-file', async () => {
  const {filePaths} = await dialog.showOpenDialog({
    properties: ['openFile'],
    filters: [{name: 'Audio Files', extensions: ['mp3']}]
  });

  if (filePaths.length > 0) {
    const metadata = await getAudioMetadata(filePaths[0]);
    console.log(metadata);
  }
});