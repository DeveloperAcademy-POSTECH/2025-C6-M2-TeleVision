# Hippo Signaling Server

WebSocket-based signaling server for WebRTC endoscope streaming between Mac and Vision Pro.

## Overview

This server facilitates WebRTC peer connection establishment by relaying signaling messages (SDP offers/answers and ICE candidates) between:
- Mac sender (endoscope video source)
- Vision Pro receiver (immersive view display)

## Setup

Install dependencies:

```bash
npm install
```

## Run

Start the server:

```bash
npm start
```

For development with auto-reload:

```bash
npm run dev
```

## Configuration

- **Default Port**: `8080`
- **Protocol**: WebSocket (`ws://`)
- **URL**: `ws://localhost:8080`

## Message Protocol

### Register Client

```json
{
  "type": "register",
  "clientId": "mac-sender" | "vision-receiver"
}
```

### WebRTC Signaling

**Offer/Answer:**
```json
{
  "type": "offer" | "answer",
  "targetId": "client-id",
  "sdp": "..."
}
```

**ICE Candidate:**
```json
{
  "type": "ice-candidate",
  "targetId": "client-id",
  "candidate": "..."
}
```

## Architecture

```
┌─────────┐                  ┌──────────────┐                  ┌──────────────┐
│   Mac   │ ────offer────>   │   Signaling  │ ────offer────>   │ Vision Pro   │
│ Sender  │                  │    Server    │                  │   Receiver   │
│         │ <───answer────   │  (WebSocket) │ <───answer────   │              │
└─────────┘                  └──────────────┘                  └──────────────┘
     │                              │                                  │
     └──────────────────ICE candidates─────────────────────────────────┘
```

## Deployment

For production deployment:

1. Change to secure WebSocket (`wss://`)
2. Add authentication
3. Use environment variables for configuration
4. Deploy to cloud service (e.g., AWS, Heroku, DigitalOcean)

## Testing

Use the test receiver HTML page:

```bash
open test/test-receiver.html
```

## Troubleshooting

- **Port already in use**: Change port in `server.js`
- **Connection refused**: Check firewall settings
- **Messages not forwarding**: Verify client IDs match
