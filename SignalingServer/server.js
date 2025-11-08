const WebSocket = require('ws');

const wss = new WebSocket.Server({ port: 8080 });

const clients = new Map();

wss.on('connection', (ws) => {
  console.log('New client connected');

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log('Received:', data.type);

      switch (data.type) {
        case 'register':
          const clientId = data.clientId || data.role || 'unknown';
          clients.set(clientId, ws);
          ws.clientId = clientId;
          console.log(`Client registered: ${clientId}`);
          break;

        case 'offer':
        case 'answer':
        case 'ice-candidate':
        case 'iceCandidate':
          const targetClient = clients.get(data.targetId);
          if (targetClient && targetClient.readyState === WebSocket.OPEN) {
            targetClient.send(JSON.stringify(data));
            console.log(`Forwarded ${data.type} to ${data.targetId}`);
          } else {
            console.log(`Target client ${data.targetId} not found or not ready`);
          }
          break;

        default:
          console.log('Unknown message type:', data.type);
      }
    } catch (error) {
      console.error('Error processing message:', error);
    }
  });

  ws.on('close', () => {
    // Remove client from map using stored clientId
    if (ws.clientId) {
      clients.delete(ws.clientId);
      console.log(`Client disconnected: ${ws.clientId}`);
    }
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

console.log('Signaling server running on ws://localhost:8080');
