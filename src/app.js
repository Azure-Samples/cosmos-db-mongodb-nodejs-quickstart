import express from 'express';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { Server } from 'socket.io';
import favicon from 'serve-favicon';
// Read .env file and set environment variables
import { main } from './cosmos.js'

const app = express();
const server = createServer(app);
const io = new Server(server);

const __dirname = dirname(fileURLToPath(import.meta.url));

app.get('/', (_, res) => {
  res.sendFile(join(__dirname, 'static', 'index.html'));
});

app.use(
  favicon(join(__dirname, 'static', 'favicon.ico'))
);

io.on('connection', (socket) => {
  console.log(`Connected: ${socket.id}`);

  socket.on('start', async (_) => {
    console.log('Started');
    await main(function emitMessage(message) {
      //console.log(message);
      io.emit('new_message', message);
    });
  });
});

io.on('error', (_, error) => {
  console.log(`Error: ${error}`);
});

io.on('disconnect', (_, reason) => {
  console.log(`Disconnected: ${reason}`);
});

const port = process.env.PORT || 3000;
server.listen(port, () => {
  console.log(`Server running: \\:${port}`);
});
