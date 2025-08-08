const { app, BrowserWindow, ipcMain } = require('electron');
const os = require('os');
const fs = require('fs');
const path = require('path');

let mainWindow;
let iconMIME;
let iconBuff;

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
    iconMIME = 'image/png';
    iconBuff = await fs.promises.readFile('pictures/icon.png');
    const colors = (await getColors(iconBuff, iconMIME)).map(color => color.hex());
    const base64String = iconBuff.toString('base64');
    const result = { coverDataUrl: `data:${iconMIME};base64,${base64String}`, color: colors[0] };
    mainWindow.webContents.send('set-default-cover', result);
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

const { fileTypeFromFile } = require('file-type');
const { parseStream } = require('music-metadata');
const { parseFile } = require('music-metadata');
const getColors = require('get-image-colors');

async function getAudioMetadata(filePath) {
  try {
    const stream = fs.createReadStream(filePath);
    const detected = await fileTypeFromFile(filePath);
    let metadata;
    if (detected.mime == 'audio/ogg') {
      metadata = await parseFile(filePath, { duration: true })
    } else {
      metadata = await parseStream(stream, detected.mime);
    }
    const picture = metadata.common.picture?.[0];
    let pictureMIME;
    let buff;
    if (picture) {
      pictureMIME = picture.format;
      buff = Buffer.from(picture.data);
    } else {
      pictureMIME = iconMIME;
      buff = iconBuff;
    }
    let color;
    try {
      colors = (await getColors(buff, pictureMIME)).map(color => color.hex());
    } catch {
      console.log(buff);
      color = "white";
    }
    const base64String = buff.toString('base64');

    return {
      filePath: filePath,
      coverDataUrl: `data:${pictureMIME};base64,${base64String}`,
      color: color,
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
  let songPaths = await findSongs(path.join(os.homedir(), 'Music'));
  for (let i = 0; i < songPaths.length; i++) {
    const metadata = await getAudioMetadata(songPaths[i]);
    mainWindow.webContents.send('song-metadata', metadata);
  }
})