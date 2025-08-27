const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  minimizeWindow: () => ipcRenderer.send('window-minimize'),

  resizeWindow: () => ipcRenderer.send('window-resize'),

  closeWindow: () => ipcRenderer.send('window-close'),

  enterFullScreen: () => ipcRenderer.send('window-enter-fullScreen'),

  leaveFullScreen: () => ipcRenderer.send('window-leave-fullScreen'),

  setLoadingPlaylist: (callback) => {
    ipcRenderer.on('set-loading-playlist', (event) => callback())
  },

  resetPlaylist: (callback) => {
    ipcRenderer.on('reset-playlist', (event, size) => callback(size))
  },

  unsetLoadingPlaylist: (callback) => {
    ipcRenderer.on('unset-loading-playlist', (event) => callback())
  },

  maximize: (callback) => { ipcRenderer.on('maximize', (event) => callback()) },

  unmaximize:
    (callback) => { ipcRenderer.on('unmaximize', (event) => callback()) },

  receiveSongMetadatas: (callback) => {
    ipcRenderer.on('song-metadatas', (event, metadatas) => callback(metadatas))
  },

  getColor: (filePath) => ipcRenderer.invoke('get-color', filePath),

  getLyrics: (filePath) => ipcRenderer.invoke('get-lyrics', filePath),

  setDefaultCover: (callback) => {
    ipcRenderer.on('set-default-cover', (event, result) => callback(result))
  },

  controlMusicPlay: (callback) => {
    ipcRenderer.on('control-music-play', (event, cmd) => callback(cmd))
  }

});