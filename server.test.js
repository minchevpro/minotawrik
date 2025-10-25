const test = require('node:test');
const assert = require('node:assert');
const { createServer } = require('./server');

function startServer() {
  return new Promise(resolve => {
    const server = createServer();
    server.listen(0, () => {
      const port = server.address().port;
      resolve({ server, port });
    });
  });
}

test('booking flow', async () => {
  const { server, port } = await startServer();
  const base = `http://localhost:${port}`;

  // Create booking
  let res = await fetch(`${base}/bookings`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      boxId: 'A',
      start: '2024-01-01T10:00',
      end: '2024-01-01T11:00'
    })
  });
  assert.strictEqual(res.status, 201);
  const created = await res.json();

  // Attempt conflicting booking
  res = await fetch(`${base}/bookings`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      boxId: 'A',
      start: '2024-01-01T10:30',
      end: '2024-01-01T11:30'
    })
  });
  assert.strictEqual(res.status, 409);

  // Fetch bookings
  res = await fetch(`${base}/bookings?boxId=A&date=2024-01-01`);
  const list = await res.json();
  assert.strictEqual(list.length, 1);
  assert.strictEqual(list[0].id, created.id);

  // Update booking
  res = await fetch(`${base}/bookings/${created.id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ end: '2024-01-01T12:00' })
  });
  assert.strictEqual(res.status, 200);
  const updated = await res.json();
  assert.strictEqual(updated.end, '2024-01-01T12:00');

  // Delete booking
  res = await fetch(`${base}/bookings/${created.id}`, { method: 'DELETE' });
  assert.strictEqual(res.status, 204);

  server.close();
});
