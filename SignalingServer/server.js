const WebSocket = require('ws');
const os = require('os');

const wss = new WebSocket.Server({ port: 8080 });

const clients = new Map();
const iceCandidateCount = new Map(); // Track ICE candidates per connection

// Get local IP addresses
function getLocalIPAddresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];

  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      // Skip internal and non-IPv4 addresses
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push({ name, address: iface.address });
      }
    }
  }

  return addresses;
}

// Get current timestamp
function getTimestamp() {
  return new Date().toLocaleTimeString('ko-KR', { hour12: false });
}

// Print connected clients info (simplified)
function printClientsInfo() {
  const clientList = Array.from(clients.keys()).join(', ');
  console.log(`   Active Clients [${clients.size}]: ${clientList || 'None'}`);
}

wss.on('connection', (ws) => {
  console.log(`[${getTimestamp()}] New client connected (awaiting registration...)`);

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      const senderId = data.senderId || ws.clientId || 'unknown';
      const targetId = data.targetId;

      switch (data.type) {
        case 'register':
          const clientId = data.clientId || data.role || 'unknown';
          clients.set(clientId, ws);
          ws.clientId = clientId;
          iceCandidateCount.set(clientId, { sent: 0, received: 0 });

          console.log(`\n[${getTimestamp()}] CLIENT REGISTERED`);
          console.log(`   Client: ${clientId}`);
          printClientsInfo();
          console.log('');
          break;

        case 'offer':
          const targetClientOffer = clients.get(targetId);
          if (targetClientOffer && targetClientOffer.readyState === WebSocket.OPEN) {
            targetClientOffer.send(JSON.stringify(data));
            console.log(`[${getTimestamp()}] OFFER: ${senderId} → ${targetId}`);
          } else {
            console.log(`[${getTimestamp()}] ⚠️  OFFER FAILED: ${senderId} → ${targetId} (target not available)`);
          }
          break;

        case 'answer':
          const targetClientAnswer = clients.get(targetId);
          if (targetClientAnswer && targetClientAnswer.readyState === WebSocket.OPEN) {
            targetClientAnswer.send(JSON.stringify(data));
            console.log(`[${getTimestamp()}] ANSWER: ${senderId} → ${targetId}`);
          } else {
            console.log(`[${getTimestamp()}] ⚠️  ANSWER FAILED: ${senderId} → ${targetId} (target not available)`);
          }
          break;

        case 'ice-candidate':
        case 'iceCandidate':
          const targetClientIce = clients.get(targetId);
          if (targetClientIce && targetClientIce.readyState === WebSocket.OPEN) {
            targetClientIce.send(JSON.stringify(data));

            // Count ICE candidates
            const count = iceCandidateCount.get(senderId);
            if (count) {
              count.sent++;
              iceCandidateCount.set(senderId, count);
            }
            const recvCount = iceCandidateCount.get(targetId);
            if (recvCount) {
              recvCount.received++;
              iceCandidateCount.set(targetId, recvCount);
            }

            // Only log summary occasionally (every 5 candidates)
            if (count && count.sent % 5 === 0) {
              console.log(`[${getTimestamp()}] ICE: ${senderId} → ${targetId} (${count.sent} sent)`);
            }
          }
          break;

        default:
          console.log(`[${getTimestamp()}] Unknown message type: ${data.type}`);
      }
    } catch (error) {
      console.error(`[${getTimestamp()}] Error processing message:`, error);
    }
  });

  ws.on('close', () => {
    // Remove client from map using stored clientId
    if (ws.clientId) {
      const stats = iceCandidateCount.get(ws.clientId);
      clients.delete(ws.clientId);
      iceCandidateCount.delete(ws.clientId);

      console.log(`\n[${getTimestamp()}] CLIENT DISCONNECTED`);
      console.log(`   Client: ${ws.clientId}`);
      if (stats) {
        console.log(`   ICE Stats: ${stats.sent} sent, ${stats.received} received`);
      }
      printClientsInfo();
      console.log('');
    }
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

// Print server startup information
console.log('\n╔═══════════════════════════════════════════════╗');
console.log('║   WebRTC Signaling Server Started            ║');
console.log('╚═══════════════════════════════════════════════╝');

console.log(`\n📍 Server Information:`);
console.log(`   Port: 8080`);
console.log(`   Local: ws://localhost:8080`);

const ipAddresses = getLocalIPAddresses();
if (ipAddresses.length > 0) {
  console.log(`\n🌐 Network Access:`);
  ipAddresses.forEach(({ name, address }) => {
    console.log(`   ${name}: ws://${address}:8080`);
  });
}

console.log('\n✓ Server ready - Waiting for connections...\n');
console.log('─'.repeat(50) + '\n');
