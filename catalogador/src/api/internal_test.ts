import { startServer } from "./server.js";

async function run() {
  console.log("Starting internal integration test: starting server...");
  const server = await startServer(0, '127.0.0.1');
  const addr = server.address();
  let port: number;
  if (addr && typeof addr === 'object') port = (addr as any).port;
  else port = Number(process.env.PORT || 8081);

  const url = `http://127.0.0.1:${port}/health`;
  console.log(`Querying ${url}`);

  try {
    // use global fetch (Node >=18)
    const res = await fetch(url, { method: 'GET' });
    const json = await res.json();
    console.log('Health response:', json);
    if (!json || typeof json.series !== 'number') {
      throw new Error('Unexpected /health payload');
    }
    console.log('Internal test succeeded: server served /health');
  } catch (err) {
    console.error('Internal test failed:', err);
    process.exitCode = 2;
  } finally {
    server.close(() => console.log('Server closed (internal test)'));
  }
}

run().catch(e => { console.error(e); process.exit(1); });
