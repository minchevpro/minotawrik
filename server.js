const http = require('http');
const { URL } = require('url');
const { randomUUID } = require('crypto');

function createServer() {
  const bookings = [];

  return http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);

    if (req.method === 'GET' && url.pathname === '/bookings') {
      const boxId = url.searchParams.get('boxId');
      const date = url.searchParams.get('date'); // YYYY-MM-DD

      let result = bookings;
      if (boxId) result = result.filter(b => b.boxId === boxId);
      if (date) result = result.filter(b => b.start.startsWith(date));

      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify(result));
    }

    if (req.method === 'POST' && url.pathname === '/bookings') {
      const body = await readBody(req);
      const { boxId, start, end } = body;
      const startDate = new Date(start);
      const endDate = new Date(end);

      const conflict = bookings.some(b => b.boxId === boxId &&
        !(endDate <= new Date(b.start) || startDate >= new Date(b.end)));

      if (conflict) {
        res.writeHead(409);
        return res.end('Conflict');
      }

      const booking = { id: randomUUID(), boxId, start, end };
      bookings.push(booking);

      res.writeHead(201, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify(booking));
    }

    if (req.method === 'PATCH' && url.pathname.startsWith('/bookings/')) {
      const id = url.pathname.split('/')[2];
      const body = await readBody(req);
      const booking = bookings.find(b => b.id === id);
      if (!booking) {
        res.writeHead(404);
        return res.end('Not Found');
      }
      if (body.boxId) booking.boxId = body.boxId;
      if (body.start) booking.start = body.start;
      if (body.end) booking.end = body.end;
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify(booking));
    }

    if (req.method === 'DELETE' && url.pathname.startsWith('/bookings/')) {
      const id = url.pathname.split('/')[2];
      const index = bookings.findIndex(b => b.id === id);
      if (index === -1) {
        res.writeHead(404);
        return res.end('Not Found');
      }
      bookings.splice(index, 1);
      res.writeHead(204);
      return res.end();
    }

    res.writeHead(404);
    res.end('Not Found');
  });
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  const data = Buffer.concat(chunks).toString() || '{}';
  try {
    return JSON.parse(data);
  } catch {
    return {};
  }
}

module.exports = { createServer };

if (require.main === module) {
  const server = createServer();
  const port = process.env.PORT || 3000;
  server.listen(port, () => {
    console.log(`Server running on port ${port}`);
  });
}
