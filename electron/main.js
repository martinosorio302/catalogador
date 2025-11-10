const { app, BrowserWindow } = require("electron");
const path = require("path");

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 820,
    backgroundColor: "#FFFFFF",
    webPreferences: {
      preload: path.join(__dirname, "preload.cjs"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  if (!app.isPackaged) {
    // Dev server during development
    win.loadURL("http://localhost:5173");
    win.webContents.openDevTools({ mode: "detach" });
  } else {
    // When packaged, resources are located under process.resourcesPath
    // Use a robust path that works both when unpacked and when installed
    const indexPath = path.join(process.resourcesPath, 'dist', 'web', 'index.html');
    try {
      win.loadFile(indexPath);
    } catch (err) {
      // Fallback: try relative path inside asar
      win.loadFile(path.join(__dirname, '../dist/web/index.html'));
    }
  }
}

app.whenReady().then(createWindow);
app.on("window-all-closed", () => { if (process.platform !== "darwin") app.quit(); });
