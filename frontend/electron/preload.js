const { contextBridge } = require('electron');

// Load embedded environment configuration
const embeddedEnv = require('./env-config');

// Expose protected methods that allow the renderer process to use
// the ipcRenderer without exposing the entire object
contextBridge.exposeInMainWorld('electronAPI', {
  // Add any electron APIs you need here
  platform: process.platform,
});

// Expose embedded environment to renderer process
contextBridge.exposeInMainWorld('embeddedEnv', embeddedEnv);
