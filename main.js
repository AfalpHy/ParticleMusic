const {app, BrowserWindow, ipcMain, dialog} = require('electron');
const fs = require('fs');
const path = require('path');

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
}

ipcMain.on('window-close', () => {
  mainWindow.close();
})

ipcMain.on('window-minimize', () => {mainWindow.minimize()})

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

const {fileTypeFromFile} = require('file-type');
const {parseStream} = require('music-metadata');
const {parseFile} = require('music-metadata');

async function getAudioMetadata(filePath) {
  try {
    const stream = fs.createReadStream(filePath);
    const detected = await fileTypeFromFile(filePath);
    let metadata;
    if (detected.mime == 'audio/ogg') {
      metadata = await parseFile(filePath, {duration: true})
    } else {
      metadata = await parseStream(stream, detected.mime);
    }
    return {
      filePath: filePath,
      title: metadata.common.title ||
          path.basename(filePath, path.extname(filePath)),
      artist: metadata.common.artist || 'Unknown Artist',
      album: metadata.common.album || 'Unknown',
      duration: parseInt(metadata.format.duration)
    };
  } catch (error) {
    console.error('Error reading metadata:', error, filePath);
    return null;
  }
}

ipcMain.handle('load-playlist', async (Event, playlistName) => {
  let songPaths = await findSongs(path.resolve('../Music'));

  for (let i = 0; i < songPaths.length; i++) {
    const metadata = await getAudioMetadata(songPaths[i]);
    mainWindow.webContents.send('song-metadata', metadata);
  }
})