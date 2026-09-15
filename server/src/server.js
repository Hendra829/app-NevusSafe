import { createServer } from 'node:http';

const port = Number(process.env.PORT || 8080);
const json = (res, status, body) => {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
};

const server = createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') {
    return json(res, 200, { status: 'ok', service: 'nevus-safe-api' });
  }
  if (req.method === 'GET' && req.url === '/metrics') {
    return json(res, 200, {
      uptimeSeconds: Math.round(process.uptime()),
      memoryBytes: process.memoryUsage().heapUsed,
      timestamp: new Date().toISOString(),
    });
  }
  if (req.method === 'GET' && req.url === '/v1/policy') {
    return json(res, 200, {
      maxFileBytes: Number(process.env.MAX_FILE_BYTES || 67108864),
      uploadChunkBytes: Number(process.env.UPLOAD_CHUNK_BYTES || 8388608),
      driveScope: 'https://www.googleapis.com/auth/drive.file',
    });
  }
  return json(res, 404, { error: 'not_found' });
});

server.listen(port, () => console.log(`NevusSafe API listening on ${port}`));
