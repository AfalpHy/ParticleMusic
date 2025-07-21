const {contextBridge, ipcRenderer} = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  minimizeWindow: () => ipcRenderer.send('window-minimize'),

  resizeWindow: () => ipcRenderer.send('window-resize'),

  closeWindow: () => ipcRenderer.send('window-close'),

  getSongs: () => ipcRenderer.send('get-songs'),

  receiveInitialSongs: (callback) => {ipcRenderer.on(
      'initial-songs',
      (event, songPaths, songBases) => callback(songPaths, songBases))},

  addCorner:
      (callback) => {ipcRenderer.on('add-corner', (event) => callback())},

  removeCorner:
      (callback) => {ipcRenderer.on('remove-corner', (event) => callback())},

  addSong: (callback) => {
    ipcRenderer.on('add-song', (event, metadata) => callback(metadata))
  }
});