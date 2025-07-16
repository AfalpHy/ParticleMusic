const {contextBridge, ipcRenderer} = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  minimizeWindow: () => ipcRenderer.send('window-minimize'),

  toggleWindow: () => ipcRenderer.send('window-toggle'),

  closeWindow: () => ipcRenderer.send('window-close'),

  setVolume: (volume) => ipcRenderer.send('set-volume', volume),

  receiveInitialSongs: (callback) => {
    ipcRenderer.on(
        'initial-songs',
        (event, songs, songBases) => callback(songs, songBases))
  }
});