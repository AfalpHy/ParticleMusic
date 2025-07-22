const {contextBridge, ipcRenderer} = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  minimizeWindow: () => ipcRenderer.send('window-minimize'),

  resizeWindow: () => ipcRenderer.send('window-resize'),

  closeWindow: () => ipcRenderer.send('window-close'),

  enterFullScreen: () => ipcRenderer.send('window-enter-fullScreen'),

  leaveFullScreen: () => ipcRenderer.send('window-leave-fullScreen'),

  getSongs: () => ipcRenderer.send('get-songs'),

  receiveInitialSongs: (callback) => {ipcRenderer.on(
      'initial-songs',
      (event, songPaths, songBases) => callback(songPaths, songBases))},

  maximize:
      (callback) => {ipcRenderer.on('maximize', (event) => callback())},

  unmaximize:
      (callback) => {ipcRenderer.on('unmaximize', (event) => callback())},

  addSong: (callback) => {
    ipcRenderer.on('add-song', (event, metadata) => callback(metadata))
  }
});