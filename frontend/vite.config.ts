import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    chunkSizeWarningLimit: 1000,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom', 'react-router-dom'],
          ui: ['lucide-react', 'zustand'],
        },
      },
    },
  },
  esbuild: {
    // Skip type checking during build
    logOverride: { 'this-is-undefined-in-esm': 'silent' },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'https://mario-v2-backend.ntoric.com',
        // target: 'http://localhost:8088',
        changeOrigin: true,
      },
    },
  },
})
