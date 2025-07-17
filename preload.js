const {contextBridge, ipcRenderer} = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  minimizeWindow: () => ipcRenderer.send('window-minimize'),

  toggleWindow: () => ipcRenderer.send('window-toggle'),

  closeWindow: () => ipcRenderer.send('window-close'),

  setVolume: (volume) => ipcRenderer.send('set-volume', volume),

  getSongs: () => ipcRenderer.send('get-songs'),

  receiveInitialSongs: (callback) => {
    ipcRenderer.on(
        'initial-songs',
        (event, songPaths, songBases) => callback(songPaths, songBases))
  }
});