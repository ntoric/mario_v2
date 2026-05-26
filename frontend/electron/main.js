const { app, BrowserWindow } = require('electron');
const path = require('path');
const { spawn } = require('child_process');
const fs = require('fs');

// Load embedded environment configuration
const embeddedEnv = require('./env-config');

const isDev = process.env.NODE_ENV === 'development';
let backendProcess = null;
let printerProcess = null;

// Start the Go backend server binary directly
function startBackend() {
  let binaryName;
  
  // Determine the correct binary based on platform and architecture
  if (process.platform === 'darwin') {
    if (process.arch === 'arm64') {
      binaryName = 'cafe-backend-darwin-arm64';
    } else {
      binaryName = 'cafe-backend-darwin-amd64';
    }
  } else if (process.platform === 'win32') {
    binaryName = 'cafe-backend-windows-amd64.exe';
  } else {
    console.error('Unsupported platform:', process.platform);
    return null;
  }

  const backendPath = isDev 
    ? path.join(__dirname, '..', '..', 'backend', 'build', binaryName)
    : path.join(process.resourcesPath, 'backend', binaryName);
  
  if (!fs.existsSync(backendPath)) {
    console.warn('Backend binary not found at:', backendPath, '- backend will not be available');
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

  const env = { 
    ...process.env,
    ...embeddedEnv,
    NODE_ENV: isDev ? 'development' : 'production',
  };

  console.log('Starting Go backend at:', backendPath);
  console.log('Go Backend port:', env.PORT || '8088');

  backendProcess = spawn(backendPath, [], {
    cwd: path.dirname(backendPath), // set working directory to backend dir so it can load correct contexts
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

// Start the Mario Printer binary
function startPrinter() {
  let binaryName;
  
  // Determine the correct binary based on platform and architecture
  if (process.platform === 'darwin') {
    if (process.arch === 'arm64') {
      binaryName = 'mario-printer-darwin-arm64';
    } else {
      binaryName = 'mario-printer-darwin-amd64';
    }
  } else if (process.platform === 'win32') {
    binaryName = 'mario-printer-windows-amd64.exe';
  } else {
    console.error('Unsupported platform:', process.platform);
    return null;
  }

  const printerPath = isDev 
    ? path.join(__dirname, '..', '..', 'mario-printer', 'build', binaryName)
    : path.join(process.resourcesPath, 'printer', binaryName);
  
  if (!fs.existsSync(printerPath)) {
    console.warn('Printer binary not found at:', printerPath, '- printer service will not be available');
    return null;
  }

  // Make binary executable on macOS/Linux
  if (process.platform !== 'win32') {
    try {
      fs.chmodSync(printerPath, 0o755);
    } catch (err) {
      console.error('Failed to make printer executable:', err);
    }
  }

  console.log('Starting Mario Printer at:', printerPath);

  printerProcess = spawn(printerPath, [], {
    cwd: path.dirname(printerPath),
    env: process.env,
    stdio: 'pipe',
  });

  printerProcess.stdout?.on('data', (data) => {
    console.log('[Mario Printer]:', data.toString().trim());
  });

  printerProcess.stderr?.on('data', (data) => {
    console.error('[Mario Printer Error]:', data.toString().trim());
  });

  printerProcess.on('exit', (code) => {
    console.log(`Mario Printer process exited with code ${code}`);
  });

  return printerProcess;
}

// Wait for backend to be ready
async function waitForBackend(maxAttempts = 30) {
  const port = embeddedEnv.PORT || '8088';
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
  if (printerProcess) {
    printerProcess.kill('SIGTERM');
    printerProcess = null;
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
    icon: path.join(__dirname, '..', 'public', 'logo.png'),
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
  // Start backend and printer in production
  if (!isDev) {
    console.log('Starting backend...');
    startBackend();
    
    console.log('Starting printer service...');
    startPrinter();
    
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
