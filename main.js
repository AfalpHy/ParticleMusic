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
    transparent: true,
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
    // do nothing when setFullScreen automatically invoke maximize
    if (!fullScreenCall) {
      mainWindow.webContents.send('maximize');
    }
  })

  mainWindow.on('unmaximize', () => {
    // do nothing when setFullScreen automatically invoke unmaximize
    if (!fullScreenCall) {
      mainWindow.webContents.send('unmaximize');
    }
  })
}

ipcMain.on('window-close', () => {
  mainWindow.close();
})

ipcMain.on('window-minimize', () => {mainWindow.minimize()})

let isMaximized = false;
ipcMain.on('window-resize', () => {
  if (isMaximized) {
    mainWindow.unmaximize();
  } else {
    mainWindow.maximize();
  }
  isMaximized = !isMaximized;
})

let fullScreenCall = false;
ipcMain.on('window-enter-fullScreen', () => {
  fullScreenCall = true;
  if (process.platform === 'win32' && isMaximized) {
    mainWindow.unmaximize();
  }
  mainWindow.setFullScreen(true);
  fullScreenCall = false;
});

ipcMain.on('window-leave-fullScreen', () => {
  fullScreenCall = true;
  mainWindow.setFullScreen(false);
  if (process.platform === 'win32' && isMaximized) {
    mainWindow.maximize();
  }
  fullScreenCall = false;
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

ipcMain.handle('get-playlist', async (Event, playlistName) => {
  let songPaths = await findSongs(path.resolve('../Music'));

  let metadatas = [];
  for (let i = 0; i < songPaths.length; i++) {
    const metadata = await getAudioMetadata(songPaths[i]);
    metadatas.push(metadata);
    mainWindow.webContents.send('add-song-to-list', metadata);
  }
  return songPaths;
})

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
      title: metadata.common.title ||
          path.basename(filePath, path.extname(filePath)),
      artist: metadata.common.artist || 'Unknown Artist',
      album: metadata.common.album || 'Unknown',
      duration: metadata.format.duration
    };
  } catch (error) {
    console.error('Error reading metadata:', error, filePath);
    return null;
  }
}
