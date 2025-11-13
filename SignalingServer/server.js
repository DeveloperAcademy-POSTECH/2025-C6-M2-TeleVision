/**
 * WebRTC Signaling Server for Hippo
 *
 * Features:
 * - Role-based client management (sender/receiver)
 * - Heartbeat mechanism for dead connection detection
 * - Bonjour (mDNS) auto-discovery
 * - Environment variable configuration
 * - Detailed logging with timestamps
 * - Graceful shutdown
 */

require('dotenv').config();
const WebSocket = require('ws');
const os = require('os');
const bonjourLib = require('bonjour-service');

// Configuration
const PORT = process.env.PORT || 8080;
const SERVICE_NAME = process.env.SERVICE_NAME || 'Hippo-WebRTC-Signaling';
const HEARTBEAT_INTERVAL = 30000; // 30s

// Role-based client storage (v2 structure)
const clients = {
  sender: null,    // Mac
  receiver: null   // Vision Pro
};

// ICE candidate statistics
const iceCandidateCount = new Map();

// Get local IP addresses
function getLocalIPAddresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];

  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
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

// Print connected clients info
function printClientsInfo() {
  const activeClients = [];
  if (clients.sender) activeClients.push('sender');
  if (clients.receiver) activeClients.push('receiver');

  console.log(`   Active Clients [${activeClients.length}]: ${activeClients.join(', ') || 'None'}`);
}

// Create WebSocket server
const wss = new WebSocket.Server({
  port: PORT,
  perMessageDeflate: false
});

// Print server startup information
console.log('\n╔═══════════════════════════════════════════════╗');
console.log('║   WebRTC Signaling Server Started            ║');
console.log('╚═══════════════════════════════════════════════╝');

console.log(`\n📍 Server Information:`);
console.log(`   Port: ${PORT}`);
console.log(`   Local: ws://localhost:${PORT}`);

const ipAddresses = getLocalIPAddresses();
if (ipAddresses.length > 0) {
  console.log(`\n🌐 Network Access:`);
  ipAddresses.forEach(({ name, address }) => {
    console.log(`   ${name}: ws://${address}:${PORT}`);
  });
}

// Bonjour auto-discovery
const Bonjour = bonjourLib.default || bonjourLib;
const bonjour = new Bonjour();

// Don't specify host - let Bonjour advertise on all interfaces (IPv4 and IPv6)
// This is critical for KT hotspot which may use IPv6-only networking
const service = bonjour.publish({
  name: SERVICE_NAME,
  type: 'ws',
  port: PORT,
  // No 'host' specified - allows IPv4 and IPv6 auto-discovery
  txt: {
    service: 'webrtc-signaling',
    version: '1.0'
  }
});

console.log(`\n🔍 Bonjour Service Published:`);
console.log(`   Name: ${SERVICE_NAME}`);
console.log(`   Type: _ws._tcp`);
console.log(`   Clients can auto-discover this server!`);

console.log('\n✓ Server ready - Waiting for connections...\n');
console.log('─'.repeat(50) + '\n');

// Handle new connections
wss.on('connection', (ws, req) => {
  const clientIP = req.socket.remoteAddress;
  console.log(`[${getTimestamp()}] New client connected (IP: ${clientIP}, awaiting registration...)`);

  let clientRole = null;
  ws.isAlive = true;  // Use ws property instead of local variable

  // Heartbeat mechanism (v2)
  ws.on('pong', () => {
    ws.isAlive = true;  // Update ws property
  });

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);

      switch (data.type) {
        case 'register':
          clientRole = data.role || data.clientId; // Support both 'role' and 'clientId'

          // Handle sender registration
          if (clientRole === 'sender') {
            if (clients.sender) {
              console.log(`[${getTimestamp()}] ⚠️  Replacing existing sender connection`);
              clients.sender.close();
            }
            clients.sender = ws;
            ws.clientRole = 'sender';
            iceCandidateCount.set('sender', { sent: 0, received: 0 });

            console.log(`\n[${getTimestamp()}] SENDER REGISTERED (Mac)`);
            console.log(`   IP: ${clientIP}`);
            printClientsInfo();
            console.log('');

            // Send registration confirmation (v2)
            ws.send(JSON.stringify({
              type: 'registered',
              role: 'sender'
            }));

            // If receiver is already connected, notify sender to start offer
            if (clients.receiver && clients.receiver.readyState === WebSocket.OPEN) {
              console.log(`[${getTimestamp()}] 📤 Notifying sender to start (receiver already connected)`);
              ws.send(JSON.stringify({
                type: 'ready',
                message: 'Both clients connected, you can start offer'
              }));
            }
          }
          // Handle receiver registration
          else if (clientRole === 'receiver') {
            if (clients.receiver) {
              console.log(`[${getTimestamp()}] ⚠️  Replacing existing receiver connection`);
              clients.receiver.close();
            }
            clients.receiver = ws;
            ws.clientRole = 'receiver';
            iceCandidateCount.set('receiver', { sent: 0, received: 0 });

            console.log(`\n[${getTimestamp()}] RECEIVER REGISTERED (Vision Pro)`);
            console.log(`   IP: ${clientIP}`);
            printClientsInfo();
            console.log('');

            // Send registration confirmation (v2)
            ws.send(JSON.stringify({
              type: 'registered',
              role: 'receiver'
            }));

            // If sender is already connected, notify it to start offer
            if (clients.sender && clients.sender.readyState === WebSocket.OPEN) {
              console.log(`[${getTimestamp()}] 🎉 Both clients connected! Ready for WebRTC signaling.`);
              console.log(`[${getTimestamp()}] 📤 Notifying sender to start offer\n`);
              clients.sender.send(JSON.stringify({
                type: 'ready',
                message: 'Both clients connected, you can start offer'
              }));
            }
          }
          break;

        case 'offer':
          if (clients.receiver && clients.receiver.readyState === WebSocket.OPEN) {
            // Forward using v2's approach but with improved logging
            const forwardMessage = {
              type: 'offer',
              sdp: data.sdp
            };
            clients.receiver.send(JSON.stringify(forwardMessage));
            console.log(`[${getTimestamp()}] OFFER: sender → receiver`);
          } else {
            console.log(`[${getTimestamp()}] ⚠️  OFFER FAILED: receiver not available`);
          }
          break;

        case 'answer':
          if (clients.sender && clients.sender.readyState === WebSocket.OPEN) {
            const forwardMessage = {
              type: 'answer',
              sdp: data.sdp
            };
            clients.sender.send(JSON.stringify(forwardMessage));
            console.log(`[${getTimestamp()}] ANSWER: receiver → sender`);
          } else {
            console.log(`[${getTimestamp()}] ⚠️  ANSWER FAILED: sender not available`);
          }
          break;

        case 'ice-candidate':
        case 'iceCandidate':
          const fromClient = (ws === clients.sender) ? 'sender' : 'receiver';
          const toClient = (ws === clients.sender) ? clients.receiver : clients.sender;
          const toClientName = (ws === clients.sender) ? 'receiver' : 'sender';

          if (toClient && toClient.readyState === WebSocket.OPEN) {
            // Forward with v2's clean message format
            const forwardMessage = {
              type: 'iceCandidate',
              candidate: data.candidate,
              sdpMid: data.sdpMid,
              sdpMLineIndex: data.sdpMLineIndex
            };
            toClient.send(JSON.stringify(forwardMessage));

            // Count ICE candidates
            const count = iceCandidateCount.get(fromClient);
            if (count) {
              count.sent++;
              iceCandidateCount.set(fromClient, count);
            }
            const recvCount = iceCandidateCount.get(toClientName);
            if (recvCount) {
              recvCount.received++;
              iceCandidateCount.set(toClientName, recvCount);
            }

            // Log every 5 candidates to reduce noise
            if (count && count.sent % 5 === 0) {
              console.log(`[${getTimestamp()}] ICE: ${fromClient} → ${toClientName} (${count.sent} sent)`);
            }
          } else {
            console.log(`[${getTimestamp()}] ⚠️  ICE FAILED: ${toClientName} not available`);
          }
          break;

        default:
          console.log(`[${getTimestamp()}] Unknown message type: ${data.type}`);
      }
    } catch (error) {
      console.error(`[${getTimestamp()}] Error processing message:`, error);
    }
  });

  // Handle disconnection
  ws.on('close', () => {
    if (ws.clientRole) {
      const roleName = ws.clientRole === 'sender' ? 'Mac (Sender)' : 'Vision Pro (Receiver)';
      const stats = iceCandidateCount.get(ws.clientRole);

      console.log(`\n[${getTimestamp()}] CLIENT DISCONNECTED: ${roleName}`);
      if (stats) {
        console.log(`   ICE Stats: ${stats.sent} sent, ${stats.received} received`);
      }

      // Remove client reference
      if (ws.clientRole === 'sender') {
        clients.sender = null;
      } else if (ws.clientRole === 'receiver') {
        clients.receiver = null;
      }

      iceCandidateCount.delete(ws.clientRole);
      printClientsInfo();
      console.log('');
    } else {
      console.log(`\n[${getTimestamp()}] Unregistered client disconnected`);
    }
  });

  // Handle errors
  ws.on('error', (error) => {
    console.error(`[${getTimestamp()}] WebSocket error:`, error);
  });
});

// Heartbeat interval to detect dead connections (v2)
const heartbeatInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      console.log(`[${getTimestamp()}] 💀 Terminating dead connection`);
      return ws.terminate();
    }

    ws.isAlive = false;
    ws.ping();
  });
}, HEARTBEAT_INTERVAL);

// Graceful shutdown (v2)
process.on('SIGINT', () => {
  console.log(`\n[${getTimestamp()}] 🛑 Shutting down server...`);

  // Unpublish Bonjour service
  service.stop(() => {
    console.log(`[${getTimestamp()}] ✅ Bonjour service unpublished`);
  });

  // Close WebSocket server
  clearInterval(heartbeatInterval);
  wss.close(() => {
    console.log(`[${getTimestamp()}] ✅ WebSocket server closed`);
    process.exit(0);
  });
});

// Cleanup on server shutdown
wss.on('close', () => {
  clearInterval(heartbeatInterval);
  bonjour.destroy();
  console.log(`\n[${getTimestamp()}] 🛑 Signaling Server stopped`);
});

console.log(`[${getTimestamp()}] Server is running. Press Ctrl+C to stop.\n`);
