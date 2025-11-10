const { contextBridge } = require('electron');
contextBridge.exposeInMainWorld('catalogador', {
  ping: () => ({ ok: true, ts: Date.now() })
});
