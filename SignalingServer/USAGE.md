# Signaling Server 사용 가이드

통합 개선된 WebRTC Signaling Server와 Bonjour 자동 디스커버리 사용법

---

## 🚀 서버 실행

### 방법 1: 기본 실행
```bash
cd SignalingServer
npm install
npm start
```

### 방법 2: 환경 변수 커스터마이징
```bash
# .env 파일 수정
PORT=8080
SERVICE_NAME=My-Custom-Server

npm start
```

서버가 시작되면 다음 정보가 표시됩니다:
```
╔═══════════════════════════════════════════════╗
║   WebRTC Signaling Server Started            ║
╚═══════════════════════════════════════════════╝

📍 Server Information:
   Port: 8080
   Local: ws://localhost:8080

🌐 Network Access:
   en0: ws://172.30.1.100:8080

🔍 Bonjour Service Published:
   Name: Hippo-WebRTC-Signaling
   Type: _ws._tcp
   Clients can auto-discover this server!
```

---

## 📱 Swift 클라이언트 사용법

### 옵션 1: Bonjour 자동 디스커버리 (추천)

```swift
import SwiftUI

struct ServerSelectionView: View {
    @StateObject private var discovery = BonjourServiceDiscovery()
    @State private var selectedServer: BonjourServiceDiscovery.DiscoveredServer?

    var body: some View {
        VStack {
            Text("서버 선택")
                .font(.headline)

            if discovery.isSearching {
                ProgressView("서버 검색 중...")
            }

            List(discovery.discoveredServers) { server in
                Button(action: {
                    selectedServer = server
                }) {
                    VStack(alignment: .leading) {
                        Text(server.name)
                            .font(.body)
                        if let url = server.url {
                            Text(url.absoluteString)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }

            Button("서버 검색 시작") {
                discovery.startDiscovery()
            }
        }
        .onAppear {
            discovery.startDiscovery()
        }
        .onDisappear {
            discovery.stopDiscovery()
        }
    }
}
```

**WebRTCReceiver에 적용:**
```swift
// BonjourServiceDiscovery로 서버 찾기
let discovery = BonjourServiceDiscovery()
await discovery.startDiscovery()

// 첫 번째 발견된 서버 사용
if let server = discovery.discoveredServers.first,
   let url = server.url {
    let receiver = WebRTCReceiver(signalingServerURL: url)
    try await receiver.start()
}

// 또는 런타임에 서버 변경
if let newServerURL = discovery.discoveredServers.first?.url {
    try await receiver.updateSignalingServer(url: newServerURL)
}
```

### 옵션 2: 수동 URL 입력

```swift
struct ServerSettingsView: View {
    @AppStorage("serverIP") private var serverIP: String = "172.30.1.100"
    @AppStorage("serverPort") private var serverPort: String = "8080"

    var serverURL: URL {
        URL(string: "ws://\(serverIP):\(serverPort)")!
    }

    var body: some View {
        Form {
            TextField("Server IP", text: $serverIP)
            TextField("Port", text: $serverPort)

            Text("URL: \(serverURL.absoluteString)")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// 사용 예:
let receiver = WebRTCReceiver(signalingServerURL: serverURL)
try await receiver.start()
```

### 옵션 3: 기본값으로 시작 + 나중에 변경

```swift
// 1. 기본값(localhost)으로 시작
let receiver = WebRTCReceiver()
// 또는
let receiver = WebRTCReceiver(signalingServerURL: URL(string: "ws://127.0.0.1:8080")!)

// 2. 나중에 실제 서버로 변경
try await receiver.updateSignalingServer(url: URL(string: "ws://172.30.1.100:8080")!)
```

---

## 🔐 보안 설정 (이미 적용됨)

### Info.plist 설정
VisionApp와 MacApp의 Info.plist에 다음이 자동 추가되었습니다:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
</dict>
<key>NSLocalNetworkUsageDescription</key>
<string>Hippo needs local network access to discover and connect to the streaming server.</string>
<key>NSBonjourServices</key>
<array>
    <string>_ws._tcp</string>
</array>
```

이 설정으로:
- ✅ 로컬 네트워크에서 비보안(ws://) 연결 허용
- ✅ Bonjour 서비스 검색 허용
- ✅ 사용자에게 권한 요청 메시지 표시

---

## 🌐 네트워크 시나리오별 사용법

### 시나리오 1: 같은 Wi-Fi (가장 일반적)
1. Mac과 Vision Pro를 **같은 Wi-Fi**에 연결
2. Mac에서 서버 실행
3. Vision Pro 앱에서 자동 디스커버리 또는 표시된 IP 사용

**서버 로그 예:**
```
🌐 Network Access:
   en0: ws://192.168.1.100:8080
```
→ Vision Pro에서 `ws://192.168.1.100:8080` 사용

### 시나리오 2: 핫스팟
1. Mac의 핫스팟 활성화
2. Vision Pro를 Mac의 핫스팟에 연결
3. 서버 로그에서 표시된 IP 사용

**서버 로그 예:**
```
🌐 Network Access:
   bridge100: ws://172.20.10.1:8080
```
→ Vision Pro에서 `ws://172.20.10.1:8080` 사용

### 시나리오 3: 다른 네트워크 (프로덕션)
현재는 로컬 네트워크 전용입니다.
인터넷을 통한 연결이 필요하면 `DEPLOYMENT.md` 참조

---

## 🐛 문제 해결

### 비전프로가 서버에 연결 안 됨

**증상:**
```
Connection refused [61]
Could not connect to the server.
```

**해결:**
1. **같은 네트워크 확인**
   ```bash
   # Mac에서
   ifconfig | grep "inet "

   # Vision Pro Settings → Wi-Fi에서 IP 확인
   # 앞 3자리가 같아야 함 (예: 192.168.1.x)
   ```

2. **방화벽 확인**
   ```bash
   # Mac 시스템 설정 → 네트워크 → 방화벽
   # 꺼져있거나 Hippo 허용되어 있어야 함
   ```

3. **서버 실행 확인**
   ```bash
   lsof -i :8080
   # 프로세스가 보여야 함
   ```

### Bonjour 검색 안 됨

**해결:**
1. **Info.plist 확인**
   - NSBonjourServices에 `_ws._tcp` 있는지 확인

2. **권한 확인**
   - 앱 실행 시 "로컬 네트워크 접근 권한" 허용했는지 확인

3. **서버 로그 확인**
   ```
   🔍 Bonjour Service Published:
      Name: Hippo-WebRTC-Signaling
   ```
   이 메시지가 보여야 함

### IP 주소가 계속 바뀜

**해결책 1: DHCP 예약 (라우터 설정)**
- 라우터에서 Mac의 MAC 주소에 고정 IP 할당

**해결책 2: Bonjour 사용**
- IP가 바뀌어도 자동으로 찾아줌

**해결책 3: 수동 IP 설정**
- Mac 시스템 설정 → 네트워크 → Wi-Fi → 고급 → TCP/IP
- "수동" 선택 후 고정 IP 입력

---

## 📊 서버 로그 이해하기

### 정상 연결 흐름
```
[12:34:56] New client connected (IP: ::ffff:172.30.1.200, awaiting registration...)

[12:34:56] SENDER REGISTERED (Mac)
   IP: ::ffff:172.30.1.200
   Active Clients [1]: sender

[12:34:58] RECEIVER REGISTERED (Vision Pro)
   IP: ::ffff:172.30.1.201
   Active Clients [2]: sender, receiver

[12:34:58] 🎉 Both clients connected! Ready for WebRTC signaling.

[12:34:59] OFFER: sender → receiver
[12:35:00] ANSWER: receiver → sender
[12:35:01] ICE: sender → receiver (5 sent)
[12:35:02] ICE: receiver → sender (5 sent)
```

### 연결 해제
```
[12:40:00] CLIENT DISCONNECTED: Vision Pro (Receiver)
   ICE Stats: 23 sent, 19 received
   Active Clients [1]: sender
```

---

## ✨ 주요 개선사항 요약

| 기능 | 이전 | 현재 | 혜택 |
|------|------|------|------|
| **IP 설정** | 하드코딩 | Bonjour 자동 디스커버리 | IP 변경 시 재빌드 불필요 |
| **서버 관리** | 기본 | 역할 기반 + Heartbeat | 연결 안정성 향상 |
| **로그** | 간단 | 타임스탬프 + 통계 | 디버깅 용이 |
| **보안** | 제한적 | ATS 로컬 네트워크 허용 | 연결 차단 문제 해결 |
| **종료** | 강제 종료 | Graceful shutdown | 안전한 종료 |

---

## 🎯 권장 워크플로우

### 개발 중
```swift
// Option 1: Bonjour로 자동 검색 (추천)
let discovery = BonjourServiceDiscovery()
await discovery.startDiscovery()
if let url = discovery.discoveredServers.first?.url {
    let receiver = WebRTCReceiver(signalingServerURL: url)
}

// Option 2: UserDefaults로 저장된 IP 사용
@AppStorage("lastServerURL") var lastServerURL: String = "ws://127.0.0.1:8080"
let receiver = WebRTCReceiver(signalingServerURL: URL(string: lastServerURL)!)
```

### 테스트 시
```bash
# 서버 실행 (터미널 1)
cd SignalingServer
npm start

# 로그 모니터링
tail -f combined.log  # (향후 추가 예정)
```

### 프로덕션
`DEPLOYMENT.md` 참조 (Railway, AWS Lightsail 등)

---

## 📚 참고

- **서버 코드**: `SignalingServer/server.js`
- **Bonjour Helper**: `Hippo/Shared/Core/BonjourServiceDiscovery.swift`
- **WebRTC Receiver**: `Hippo/Features/Vision/WebRTC/WebRTCReceiver.swift`
- **WebRTC Manager (Mac)**: `Hippo/Features/Mac/Streaming/RTCTransport/WebRTCManager.swift`
- **배포 가이드**: `SignalingServer/DEPLOYMENT.md`

---

**문제가 있으면 서버 로그와 Xcode 로그를 함께 확인하세요!**
