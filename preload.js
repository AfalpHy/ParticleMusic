const {contextBridge, ipcRenderer} = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  minimizeWindow: () => ipcRenderer.send('window-minimize'),

  toggleWindow: () => ipcRenderer.send('window-toggle'),

  closeWindow: () => ipcRenderer.send('window-close'),

  openFileDialog: () => ipcRenderer.invoke('open-file-dialog'),

  sendPlayerCommand: (command) => ipcRenderer.send('player-control', command),

  setVolume: (volume) => ipcRenderer.send('set-volume', volume),

  onPlayerControl: (callback) => {
    ipcRenderer.on('player-control', (event, command) => callback(command));
  },
  onVolumeChanged: (callback) => {
    ipcRenderer.on('volume-changed', (event, volume) => callback(volume));
  }
});