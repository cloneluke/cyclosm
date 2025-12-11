import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { visualizer } from 'rollup-plugin-visualizer'
import path from 'path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    ...(process.env.ANALYZE === 'true'
      ? [
          visualizer({
            filename: 'dist/bundle-report.html',
            template: 'treemap',
            gzipSize: true,
            brotliSize: true,
          }),
        ]
      : []),
  ],
  build: {
    chunkSizeWarningLimit: 1500,
  },
  server: {
    fs: {
      // Allow serving files from the tile-server data directory
      allow: ['..', '../../infrastructure/tile-server/data']
    }
  }
})
