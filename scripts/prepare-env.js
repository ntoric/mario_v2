#!/usr/bin/env node
/**
 * Prepare environment variables for embedding in the app
 * Reads from root .env file and generates config files
 */

const fs = require('fs');
const path = require('path');

const rootDir = path.join(__dirname, '..');
const envPath = path.join(rootDir, '.env');
const envProdPath = path.join(rootDir, '.env.production');

// Read .env file
function readEnvFile(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`Error: ${filePath} not found!`);
    process.exit(1);
  }
  
  const content = fs.readFileSync(filePath, 'utf8');
  const env = {};
  
  content.split('\n').forEach(line => {
    line = line.trim();
    if (line && !line.startsWith('#')) {
      const equalIndex = line.indexOf('=');
      if (equalIndex > 0) {
        const key = line.substring(0, equalIndex).trim();
        const value = line.substring(equalIndex + 1).trim();
        env[key] = value;
      }
    }
  });
  
  return env;
}

// Determine which env file to use
const sourceEnvPath = fs.existsSync(envProdPath) ? envProdPath : envPath;
console.log(`Reading environment from: ${sourceEnvPath}`);

const env = readEnvFile(sourceEnvPath);

// Generate env-config.js for Electron main process
const envConfigContent = `// Auto-generated environment configuration
// Generated at: ${new Date().toISOString()}
// DO NOT EDIT - This file is regenerated on each build

const embeddedEnv = ${JSON.stringify(env, null, 2)};

module.exports = embeddedEnv;
`;

const envConfigPath = path.join(rootDir, 'electron', 'env-config.js');
fs.writeFileSync(envConfigPath, envConfigContent);
console.log(`Generated: ${envConfigPath}`);

// Copy .env to backend build folder for pkg to embed
const backendBuildDir = path.join(rootDir, 'backend', 'build');
if (!fs.existsSync(backendBuildDir)) {
  fs.mkdirSync(backendBuildDir, { recursive: true });
}

fs.copyFileSync(sourceEnvPath, path.join(backendBuildDir, '.env'));
console.log(`Copied .env to: ${path.join(backendBuildDir, '.env')}`);

console.log('\nEnvironment variables prepared:');
Object.keys(env).forEach(key => {
  const value = key.toLowerCase().includes('password') || key.toLowerCase().includes('secret') 
    ? '***' 
    : env[key];
  console.log(`  ${key}=${value}`);
});

console.log('\nDone!');
