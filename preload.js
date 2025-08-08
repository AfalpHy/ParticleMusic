const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  minimizeWindow: () => ipcRenderer.send('window-minimize'),

  resizeWindow: () => ipcRenderer.send('window-resize'),

  closeWindow: () => ipcRenderer.send('window-close'),

  enterFullScreen: () => ipcRenderer.send('window-enter-fullScreen'),

  leaveFullScreen: () => ipcRenderer.send('window-leave-fullScreen'),

  addDirectory: () => ipcRenderer.send('add-directory'),

  displayDirectory: (callback) => {
    ipcRenderer.on(
      'display-directory', (event, filePath) => callback(filePath))
  },

  loadPlaylist: (playlistName) =>
    ipcRenderer.invoke('load-playlist', playlistName),

  maximize: (callback) => { ipcRenderer.on('maximize', (event) => callback()) },

  unmaximize:
    (callback) => { ipcRenderer.on('unmaximize', (event) => callback()) },

  receiveSongMetadata: (callback) => {
    ipcRenderer.on('song-metadata', (event, metadata) => callback(metadata))
  },

  getColor: (filePath) => ipcRenderer.invoke('get-color', filePath),

  setDefaultCover: (callback) => {
    ipcRenderer.on('set-default-cover', (event, result) => callback(result))
  },
});