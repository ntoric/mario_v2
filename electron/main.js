const { app, BrowserWindow } = require('electron');
const path = require('path');
const { spawn } = require('child_process');
const fs = require('fs');

// Load embedded environment configuration
const embeddedEnv = require('./env-config');

const isDev = process.env.NODE_ENV === 'development';
let backendProcess = null;
let printerServiceProcess = null;

// Start the Go backend server binary directly
function startBackend() {
  const binaryName = 'cafe-backend-darwin-arm64';
  const backendPath = isDev 
    ? path.join(__dirname, '..', 'backend-go', 'build', binaryName)
    : path.join(process.resourcesPath, 'backend-go', binaryName);
  
  if (!fs.existsSync(backendPath)) {
    console.error('Backend binary not found at:', backendPath);
    return null;
  }

  // Make binary executable on macOS/Linux
  if (process.platform !== 'win32') {
    try {
      fs.chmodSync(backendPath, 0o755);
    } catch (err) {
      console.error('Failed to make backend executable:', err);
    }
  }

  // Merge embedded env with process env
  // DISABLE_PRINTER_SERVICE=true is passed so Go backend does not spawn its own printer service subprocess.
  // Instead, Electron spawns and manages both as siblings.
  const env = { 
    ...process.env,
    ...embeddedEnv,
    DISABLE_PRINTER_SERVICE: 'true',
    NODE_ENV: isDev ? 'development' : 'production',
  };

  console.log('Starting Go backend at:', backendPath);
  console.log('Go Backend port:', env.PORT || '3001');

  backendProcess = spawn(backendPath, [], {
    cwd: path.dirname(backendPath), // set working directory to backend-go dir so it can load correct contexts
    env,
    stdio: 'pipe',
  });

  backendProcess.stdout?.on('data', (data) => {
    console.log('[Go Backend]:', data.toString().trim());
  });

  backendProcess.stderr?.on('data', (data) => {
    console.error('[Go Backend Error]:', data.toString().trim());
  });

  backendProcess.on('exit', (code) => {
    console.log(`Go backend process exited with code ${code}`);
  });

  return backendProcess;
}

// Start the printer service
function startPrinterService() {
  const platform = process.platform;
  
  let binaryName = 'printer-service-darwin-arm64';
  if (platform === 'win32') {
    binaryName = 'printer-service.exe';
  } else if (platform === 'linux') {
    binaryName = 'printer-service-linux-x64';
  }

  const printerServicePath = isDev 
    ? path.join(__dirname, '..', 'printer_service', 'build', binaryName)
    : path.join(process.resourcesPath, 'printer_service', 'build', binaryName);

  if (!fs.existsSync(printerServicePath)) {
    console.error('Printer service binary not found at:', printerServicePath);
    return null;
  }

  // Make binary executable on macOS/Linux
  if (platform !== 'win32') {
    try {
      fs.chmodSync(printerServicePath, 0o755);
    } catch (err) {
      console.error('Failed to make printer service executable:', err);
    }
  }

  const env = {
    ...process.env,
    ...embeddedEnv,
    PORT: embeddedEnv.PRINTER_SERVICE_PORT || '8085',
  };

  console.log('Starting printer service at:', printerServicePath);

  printerServiceProcess = spawn(printerServicePath, [], {
    env,
    stdio: 'pipe',
  });

  printerServiceProcess.stdout?.on('data', (data) => {
    console.log('[Printer]:', data.toString().trim());
  });

  printerServiceProcess.stderr?.on('data', (data) => {
    console.error('[Printer Error]:', data.toString().trim());
  });

  printerServiceProcess.on('exit', (code) => {
    console.log(`Printer service exited with code ${code}`);
  });

  return printerServiceProcess;
}

// Wait for backend to be ready
async function waitForBackend(maxAttempts = 30) {
  const port = embeddedEnv.PORT || '3001';
  const healthUrl = `http://localhost:${port}/api/health`;
  
  for (let i = 0; i < maxAttempts; i++) {
    try {
      const response = await fetch(healthUrl);
      if (response.ok) {
        console.log('Backend is ready!');
        return true;
      }
    } catch (err) {
      // Backend not ready yet
    }
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  
  console.error('Backend failed to start within timeout');
  return false;
}

// Kill child processes
function killChildProcesses() {
  if (backendProcess) {
    backendProcess.kill('SIGTERM');
    backendProcess = null;
  }
  if (printerServiceProcess) {
    printerServiceProcess.kill('SIGTERM');
    printerServiceProcess = null;
  }
}

function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1200,
    minHeight: 700,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
    titleBarStyle: 'default',
    show: false,
    icon: path.join(__dirname, '..', 'public', 'icon.png'),
  });

  // Load the app
  if (isDev) {
    mainWindow.loadURL('http://localhost:5173');
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'));
  }

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    if (!isDev) {
      mainWindow.maximize();
    }
  });

  return mainWindow;
}

app.whenReady().then(async () => {
  // Start backend and printer service in production
  if (!isDev) {
    console.log('Starting backend services...');
    startBackend();
    startPrinterService();
    
    // Wait for backend to be ready before showing window
    console.log('Waiting for backend to be ready...');
    const backendReady = await waitForBackend();
    if (!backendReady) {
      console.error('Backend failed to start');
    }
  }

  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  killChildProcesses();
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('before-quit', () => {
  killChildProcesses();
});

// Handle crashes
process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
  killChildProcesses();
  app.quit();
});

process.on('SIGTERM', () => {
  killChildProcesses();
  app.quit();
});
