import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv } from 'vite'

// The console talks to the FastAPI backend. In development we proxy /api to the
// backend so the browser never needs cross-origin configuration; set BACKEND_URL
// (or VITE_API_BASE_URL) to point at a tunnel or a remote deployment.
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  return {
    plugins: [react()],
    server: {
      port: 5173,
      proxy: {
        '/api': {
          target: env.BACKEND_URL || 'http://localhost:8000',
          changeOrigin: true,
        },
      },
    },
  }
})
