import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Expose only the public Supabase URL and publishable key to the browser.
// The fallback supports projects that already store these under SUPABASE_* names.
export default defineConfig({
  plugins: [react()],
  define: {
    'import.meta.env.VITE_SUPABASE_URL': JSON.stringify(
      process.env.VITE_SUPABASE_URL || process.env.SUPABASE_URL || '',
    ),
    'import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY': JSON.stringify(
      process.env.VITE_SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || '',
    ),
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
    emptyOutDir: true,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('/node_modules/@supabase/')) return 'supabase';
          if (id.includes('/node_modules/react-router')) return 'router';
          if (id.includes('/node_modules/react-dom/') || id.includes('/node_modules/react/')) return 'react';
        },
      },
    },
  },
});
