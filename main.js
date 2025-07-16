const {app, BrowserWindow, ipcMain, dialog} = require('electron');
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
    width: 800,
    height: 600,
    transparent: true,
    frame: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.loadFile('index.html');

  // if (process.env.NODE_ENV === 'development') {
  // mainWindow.webContents.openDevTools();
  // }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

ipcMain.handle('open-file-dialog', async () => {
  const result = await dialog.showOpenDialog({
    properties: ['openFile'],
    filters: [
      {name: 'Audio Files', extensions: ['mp3', 'wav', 'ogg', 'flac', 'aac']},
      {name: 'All Files', extensions: ['*']}
    ]
  });
  return result.filePaths;
});

ipcMain.on('player-control', (event, command) => {
  if (mainWindow) {
    mainWindow.webContents.send('player-control', command);
  }
});

ipcMain.on('set-volume', (event, volume) => {
  if (mainWindow) {
    mainWindow.webContents.send('volume-changed', volume);
  }
});

ipcMain.on('window-close', () => mainWindow.close())

ipcMain.on('window-minimize', () => {mainWindow.minimize()})

ipcMain.on(
    'window-toggle',
    () => {
        mainWindow.isMaximized() ? mainWindow.unmaximize() :
                                   mainWindow.maximize()})