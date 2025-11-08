import fs from 'node:fs';
import path from 'node:path';
import { startServer } from './api/server.js';

async function main() {
  const port = Number(process.env.PORT || 8081);
  const host = process.env.HOST || '0.0.0.0';
  const pidPath = path.resolve(process.cwd(), '.server.pid');
  const logPath = path.resolve(process.cwd(), 'logs', 'server.log');
  try {
    // ensure logs directory
    fs.mkdirSync(path.dirname(logPath), { recursive: true });
  } catch (e) {}

  try {
    const server = await startServer(port, host);
    const addr = server.address();
    const actualPort = typeof addr === 'object' && addr ? (addr as any).port : port;
    // write pid
    try { fs.writeFileSync(pidPath, String(process.pid), { encoding: 'utf8' }); } catch (e) {}

    const banner = `Server started on http://${host}:${actualPort} (pid=${process.pid})`;
    console.log(banner);

    // handle signals for graceful shutdown
    const shutdown = (code = 0) => {
      console.log('Shutting down server...');
      server.close(() => {
        try { fs.unlinkSync(pidPath); } catch (e) {}
        console.log('Server stopped');
        process.exit(code);
      });
    };

    process.on('SIGINT', () => shutdown(0));
    process.on('SIGTERM', () => shutdown(0));

  } catch (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
}

main();
