import { defineConfig } from 'vite';

export default defineConfig({
  base: '/battle-royale-web/',
  server: { port: 3000, host: true },
  build: {
    target: 'es2022',
    minify: false,
    sourcemap: true,
  },
});
