# Psiphon Tunnel Core - Codebase Documentation

> **Important**: Read this document before making changes to understand the architecture and design philosophy.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Project Structure](#2-project-structure)
3. [Directory Organization](#3-directory-organization)
4. [Core Components](#4-core-components)
5. [How the Client Works](#5-how-the-client-works)
6. [How the Server Works](#6-how-the-server-works)
7. [Obfuscation & Anti-Censorship](#7-obfuscation--anti-censorship)
8. [Inproxy & Refraction Networking](#8-inproxy--refraction-networking)
9. [Configuration System](#9-configuration-system)
10. [Server Entry Distribution](#10-server-entry-distribution)
11. [Design Patterns](#11-design-patterns)
12. [Build System](#12-build-system)
13. [Dependencies](#13-dependencies)
14. [Testing Strategy](#14-testing-strategy)
15. [Development Guidelines](#15-development-guidelines)

---

## 1. Overview

**Psiphon Tunnel Core** is a sophisticated Internet censorship circumvention system. It implements a tunneling client and server that work together to relay client traffic through proxy servers located beyond censoring entities, using multiple layers of obfuscation and anti-blocking techniques.

**Core Principles:**
- SSH-based tunneling for confidentiality and integrity
- Multi-protocol support (OSSH, Meek, QUIC, Shadowsocks, WireGuard, etc.)
- Traffic obfuscation to evade DPI and blocking
- Parallel connection attempts for load balancing and reliability
- Remote configuration via "tactics" system
- Obfuscated server list (OSL) distribution for server protection

**Language:** Go 1.24+

**License:** See LICENSE file

---

## 2. Project Structure

```
psiphon-tunnel-core/
├── psiphon/              # Core client package
│   ├── common/          # Shared code between client & server
│   ├── server/          # Server implementation (embedded in server binary)
│   ├── upstreamproxy/   # Upstream proxy chaining
│   ├── transferstats/   # Traffic statistics tracking
│   └── *.go             # Main client types (Controller, Tunnel, etc.)
├── ConsoleClient/       # CLI client executable
├── Server/              # Server daemon (psiphond)
├── ClientLibrary/       # Client library for embedding
├── MobileLibrary/       # Android/iOS specific libraries
├── replace/             # Forked/vendored dependencies with customizations
│   ├── dtls/           # Modified pion/dtls for DTLS randomization
│   ├── ice/            # Modified pion/ice for Psiphon customizations
│   ├── webrtc/         # Modified pion/webrtc for Psiphon features
│   └── webrtc/rtptransceiverdirection.go
├── vendor/             # Standard vendored dependencies
├── .github/            # CI/CD workflows
├── go.mod              # Go module definition
├── README.md           # User-facing documentation
└── CONTRIBUTING.md     # Contribution guidelines
```

---

## 3. Directory Organization

### 3.1 `psiphon/` - Core Client Package

The main entry point for using Psiphon as a library. Contains:

- **`controller.go`**: Main orchestrator - manages tunnel lifecycle, server selection, connection attempts
- **`tunnel.go`**: Individual tunnel representation - handles SSH connection, traffic routing
- **`config.go`**: Client configuration structure and validation
- **`net.go`**: Network abstraction layer for platform-specific implementations
- **`inproxy.go`**: Inproxy client integration
- **`notice.go`**: Logging and user notification system
- **`establishment.go`**: Tunnel establishment protocols and shared secrets
- **`trafficRules.go`**: Split-tunneling and traffic routing rules
- **`api.go`**: Psiphon server API communication (handshake, status, etc.)

#### `psiphon/common/` - Shared Libraries

Common code used by both client and server:

- **`protocol/`**: Server entry encoding/decoding, API protocol definitions, meek protocol
- **`obfuscator/`**: OSSH (Obfuscated SSH) implementation with RC4/ChaCha20
- **`tactics/`**: Remote configuration delivery system
- **`inproxy/`**: Inproxy broker and client implementations
  - `broker/`: Broker server-side
  - `client/`: Client-side inproxy connectivity
  - `dtls/`: DTLS over WebRTC data channels
- **`refraction/`**: Refraction networking (TapDance, Conjure)
- **`crypto/`**: Cryptographic utilities (ssh, nacl, chacha20)
- **`transforms/`**: Traffic transformation specifications
- **`osl/`**: Obfuscated Server List encryption/decryption
- **`push/`**: Push notification system for server delivery
- **`tun/`**: Packet tunnel (VPN) mode implementation
- **`networkid/`**: Network/geolocation identification
- **`accesscontrol/`**: Authorization and access control
- **`sss/`**: Shamir's Secret Sharing for key splitting
- **`prng/`**: Pseudorandom number generation
- **`values/`**: Constants, version info, build tags
- **`errors/`**: Error handling utilities
- **`subnet.go`**: IP subnet utilities
- **`portlist.go`**: Port range management
- **`redact.go`**: Sensitive data redaction for logs

#### `psiphon/server/` - Server Implementation

Server-side code (also embedded in `Server/` binary):

- **`server.go`**: Main server implementation
- **`listener.go`**: Protocol-specific listeners (SSH, Meek, QUIC, etc.)
- **`api.go`**: HTTP/SSH API endpoints
- **`trafficRules.go`**: Server-side traffic filtering
- **`tactics.go`**: Tactics server implementation
- **`inproxy.go`**: Inproxy broker server
- **`demux.go`**: Packet demultiplexing for refraction
- **`packetman.go`**: Packet manipulation
- **`config.go`**: Server configuration

### 3.2 `ConsoleClient/` - Command-Line Client

- **`main.go`**: CLI entry point - parses flags, loads config, starts controller
- **`signal.go`**: Signal handling (graceful shutdown)

### 3.3 `Server/` - Server Daemon

- **`main.go`**: psiphond entry point - supports `generate` and `run` modes
- Uses `panicwrap` for crash protection and automatic restart

### 3.4 `ClientLibrary/` & `MobileLibrary/`

Library variants optimized for embedding in other applications (Android, iOS, etc.)

### 3.5 `replace/` - Modified Dependencies

Forked libraries with Psiphon-specific modifications:

- **`dtls/`**: pion/dtls fork with ClientHello randomization support
- **`ice/`**: pion/ice fork with Psiphon customizations
- **`webrtc/`**: pion/webrtc fork for inproxy DTLS over WebRTC

---

## 4. Core Components

### 4.1 Controller (`psiphon/controller.go`)

The brain of the client. Responsibilities:
- Load and validate configuration
- Initialize data store (for persistent server entries)
- Select servers and protocols to attempt
- Manage connection worker pool
- Monitor tunnel health and establish replacements
- Handle remote commands (tactics, server list push)

**Key Methods:**
- `NewController(config *Config)`: Creates controller
- `Run()`: Main loop - continually attempts to establish and maintain tunnels
- `getNextDialParams()`: Server and protocol selection algorithm
- `dial tunnel()`: Creates a single tunnel connection attempt
- `handleNotice()`: Processes notices from components

### 4.2 Tunnel (`psiphon/tunnel.go`)

Represents an active tunnel connection:
- Wraps SSH connection with optional obfuscation
- Manages local proxy listeners (SOCKS5, HTTPS)
- Handles packet tunnel (TUN) device if enabled
- Monitors liveness via pings
- Tracks traffic statistics
- Lifecycle: connecting → connected → activated → operating → closed

**Key Methods:**
- `ConnectTunnel()`: Establishes tunnel to server
- `Activate()`: Performs handshake and activates tunnel
- `operateTunnel()`: Main tunnel goroutine for monitoring
- `Close()`: Gracefully shuts down tunnel

### 4.3 Configuration (`psiphon/config.go`)

Extensive JSON-based configuration with hundreds of options organized into:

**Client Identity:**
- `PropagationChannelId`, `SponsorId` - attribution tracking
- `ClientVersion`, `ClientPlatform` - user agent identification

**Connection:**
- `ConnectionWorkerPoolSize` - parallel dial attempts
- `ConnectionWorkerLifetime` - worker rotation
- `DialTimeout` - network timeout
- `EgressRegion` - preferred egress country

**Proxies:**
- `LocalSocksProxyPort`, `LocalHttpProxyPort`
- `DisableLocalSocksProxy`, `DisableLocalHTTPProxy`
- `SplitTunnel` - traffic routing rules

**Protocols & Obfuscation:**
- `TunnelProtocol` - allowed protocols (empty = all)
- `ObfuscatedSSH` - OSSH settings (seed, padding, etc.)
- `MeekSettings`, `QUICSettings`, `ShadowsocksSettings`

**Obfuscated Server List (OSL):**
- `ObfuscatedSSHSeed`, `ObfuscatedSSHPadding` - shared secrets

**Features:**
- `RunPacketTunnel` - VPN mode
- `TargetServerEntry` - specific server to connect to
- `RemoteServerListURLs` - where to fetch server lists
- `EnableTactics` - remote configuration
- `EnableQualityFeedback` - bandwidth reporting

**Testing Parameters** (prefixed `Test `):
Extensive set of parameters for deterministic testing and experiments.

### 4.4 Data Store

Persistent storage for server entries and state:
- BoltDB database (vendored)
- Stores discovered and pushed server entries
- Maintains tunnel history for analytics
- Location: configurable via `DataStore` config

---

## 5. How the Client Works

### 5.1 Startup Flow

```
1. LoadConfig() - Parse JSON configuration
   ↓
2. NewController() - Create controller with config
   ↓
3. controller.Run() - Main connection loop (blocking)
```

### 5.2 Tunnel Establishment Process

Detailed flow for establishing a single tunnel:

```
1. getNextDialParams()
   - Select target server entry from pool
   - Choose protocol/obfuscation combination
   ↓
2. dialTunnel()
   - Build transport (direct, meek, quic, etc.)
   - Wrap with obfuscator if required
   - Create SSH client
   - Dial network connection
   ↓
3. SSH Handshake
   - Client authenticates server using pre-shared public key
   - Key exchange encrypted with obfuscator if active
   - Session established
   ↓
4. ConnectTunnel (psiphon/tunnel.go)
   - Assign tunnel to controller
   - Open SSH channel for tunnel protocol
   ↓
5. Activate()
   - Send handshake request via SSH channel
   - Server validates and assigns tunnel ID
   - Start operateTunnel() goroutine
   ↓
6. operateTunnel()
   - Monitor connection liveness (pings)
   - Route traffic through SOCKS/HTTP proxies or TUN device
   - Handle tunnel closure and reconnection
```

### 5.3 Connection Worker Pool

The controller spawns multiple workers to attempt connections in parallel:

- Workers are rate-limited with staggered start times
- Each worker dials a different server/protocol combination
- Workers that fail are recycled after `ConnectionWorkerLifetime`
- Successful tunnel causes workers to shut down

### 5.4 Traffic Routing

**SOCKS5 Proxy** (default):
- Listens on `LocalSocksProxyPort` (typically 1080)
- Handles SOCKS5 protocol
- Each connection multiplexed over SSH channel

**HTTPS Proxy** (optional):
- Listens on `LocalHttpProxyPort` (typically 8080)
- Implements HTTP CONNECT method
- Compatible with browser proxy settings

**Packet Tunnel Mode** (VPN):
- Creates TUN device (Linux/macOS/Windows)
- All IP packets routed through tunnel
- Requires root/admin privileges
- Implemented in `psiphon/tun/` (platform-specific)

**Split Tunneling**:
- Traffic rules specify which destinations use tunnel
- GeoIP-based routing for local traffic bypass
- Configured via `TrafficRules` config

### 5.5 Multi-Protocol Support

The client attempts connections using multiple protocols:

- **SSH/OSSH**: Direct SSH with optional obfuscation
- **Meek**: HTTP/HTTPS fronted via CDN (looks like web browsing)
- **QUIC**: UDP-based withQUIC protocol wrapper
- **Shadowsocks**: SOCKS5 proxy over Shadowsocks
- **WireGuard**: VPN via WireGuard protocol
- **Conjure/TapDance**: Refraction networking via STUN/TURN

Protocol selection determined by:
1. `TunnelProtocol` config restriction
2. Server entry capabilities
3. Obfuscation requirements (OSL)
4. Historical success rates (tactics)

### 5.6 Automatic Recovery

- Failed tunnels trigger new connection attempts
- Controller runs continuously, maintaining up to `MaxTunnels` concurrent tunnels
- Failed servers temporarily blacklisted
- Server list continually refreshed from pushes and remote fetches

---

## 6. How the Server Works

### 6.1 Server Types

Psiphon supports multiple server types:

- **Psiphon Server**: Full-featured server (SSH, Meek, Obfuscated SSH, etc.)
- **Inproxy Broker**: Specialized for Meek protocols
- **Tactics Server**: Serves remote configuration
- **OSL Server**: Distributes obfuscated server lists

### 6.2 Server Startup

```
1. LoadConfig() - Parse server JSON config
   ↓
2. RunServices() - Start protocol listeners
   ↓
3. Listen for connections on each port
```

### 6.3 Protocol Handlers

For each incoming connection:

1. **Protocol Detection** - Identify protocol from port or handshake
2. **Upgrade/Transform** - Apply obfuscation removal or protocol upgrade
3. **SSH Handshake** - For SSH-based protocols, authenticate client
4. **API Request** - Client sends handshake request with server entry
5. **Tunnel Activation** - Server allocates tunnel ID and resources
6. **Traffic Forwarding** - Client traffic forwarded to internet

### 6.4 API Endpoints

Server exposes API via SSH channel or HTTP (for tactics/OSL):

- `HandshakeRequest`: Client authentication, tunnel establishment
- `ConnectedRequest`: Tunnel established notification
- `StatusRequest`: Client reports bandwidth usage
- `FetchServerListRequest`: Obfuscated server list fetch
- `FetchTacticsRequest`: Remote configuration fetch
- `LogRequest`: Client log upload
- `DemuxRequest`: Refraction networking packet forwarding

### 6.5 Traffic Processing

**Port Forwarding:**
- SSH channel opened per client connection
- Client opens "direct-tcpip" channels for each outbound connection
- Server dials destination and relays bytes bidirectionally

**Traffic Rules:**
- Server can filter traffic by destination IP/port
- Configured via `TrafficRules` in server config
- Applied before forwarding

**Meek Protocol:**
- Client makes HTTP requests to server (appears as normal web traffic)
- Cookie encryption for session continuity
- Turnaround time configuration for timing obfuscation

### 6.6 Server Configuration

Key server settings (JSON):

- `ServerIp` - public IP address
- `TunnelProtocolPorts` - map of protocol → port
- `SSHHostKey` - server SSH private key
- `ObfuscatedSSHSeed`, `ObfuscatedSSHPadding` - OSSH shared secrets
- `MeekCookieEncryptionKey` - session cookie encryption
- `InproxyBrokerKey`, `InproxyObfuscatedSSHSeed` - inproxy settings
- `GeoIPDatabasePath` - MaxMind GeoIP2 database location
- `TrafficRules` - network access control list
- `OSLSeed` - obfuscated server list encryption
- `TacticsSigningKey` - tactics payload signature

---

## 7. Obfuscation & Anti-Censorship

### 7.1 OSSH (Obfuscated SSH)

**Location:** `psiphon/common/obfuscator/`

Wraps SSH traffic to evade deep packet inspection (DPI):

- Uses RC4 stream cipher (or ChaCha20) with key derived from:
  ```
  key = HMAC-SHA256(seed, "OSSH")
  ```
- Each SSH packet encrypted and appended with random padding
- Establishes "magic" value in preamble for protocol detection
- Makes traffic appear random and protocol-agnostic

**Configuration:**
- `ObfuscatedSSHSeed`: Shared secret (hex)
- `ObfuscatedSSHPadding`: Minimum padding per packet
- `ObfuscatedSSHPreambleLength`: Negotiated preamble size

### 7.2 Meek Protocol

**Location:** `psiphon/common/protocol/meek.go`

Uses HTTP/HTTPS to tunnel traffic, making it appear as normal web browsing:

- Client makes HTTP GET requests to CDN domains (fronting)
- Request/response bodies carry tunnel data
- Session cookies maintain state across requests
- Rate-limited to mimic human browsing patterns
- Turnaround time adds artificial delays to confuse timing analysis

**Versions:**
- **Meek**: Plain HTTP with Cookie encryption
- **Fronted Meek**: HTTPS with SNI fronting (TLS)
- **Meek-OSSH**: Meek + OSSH layer (double obfuscation)

### 7.3 QUIC Tunneling

**Location:** `psiphon/common/protocol/quic.go`

Wraps traffic in QUIC protocol (UDP-based):

- Uses custom quic-go fork with Psiphon modifications
- OSI-layer obfuscation - traffic looks like QUIC
- Resistant to UDP blocking via fallback mechanisms
- Can be combined with OSSH (QUIC-OSSH)

### 7.4 Tactics System

**Location:** `psiphon/common/tactics/`

Remote configuration delivery mechanism:

- Server signs tactics payload with Ed25519
- Client fetches from configured URL or via API
- Payload contains JSON with parameter overrides
- Parameters adjust timeouts, buffer sizes, limits, feature flags
- Enables rapid deployment without client updates

**Benefits:**
- A/B testing of configurations
- Targeted optimization per region/network
- Emergency response to blocking events

### 7.5 Obfuscated Server Lists (OSL)

**Location:** `psiphon/common/osl/`

Encrypts server list to prevent enumeration:

- Server list encrypted with symmetric key
- Key derived using Shamir's Secret Sharing (SSS)
- Clients must have sufficient required keys to decrypt
- Partitioning prevents any one client from learning all servers
- Distribution via HTTPS with additional layer of encryption

**Configuration:**
- `ObfuscatedSSHSeed` used as encryption base
- `OSLRequiredKeyCount` - SSS threshold
- `OSLClientKeyIndex` - which SSS share this client has

---

## 8. Inproxy & Refraction Networking

### 8.1 Inproxy System

**Location:** `psiphon/common/inproxy/`

Enables connections through intermediate brokers:

**Use Cases:**
- Clients behind restrictive firewalls connect to broker (allowed domain)
- Broker forwards to Psiphon server via DTLS
- Client and server never connect directly

**Components:**

1. **Broker** (`broker/`):
   - Intermediate relay that accepts client connections
   - Forwards to actual Psiphon server
   - Runs on allowed domains (e.g., cloudfront.net)

2. **Client** (`client/`):
   - Establishes DTLS connection to broker
   - Carries tunnel traffic over DTLS data channel
   - Implemented via WebRTC data channel stack

3. **DTLS** (`dtls/`):
   - Fork of pion/dtls with ClientHello randomization
   - Makes DTLS handshake appear as different clients each time
   - Resists JA3/JA3S fingerprinting

**Flow:**
```
Client → DTLS over WebRTC → Inproxy Broker → Psiphon Server → Internet
```

### 8.2 Refraction Networking

**Location:** `psiphon/common/refraction/`

Advanced circumvention using pseudorandom routing:

#### TapDance
- Routes traffic through multiple relays
- Each relay adds/removes layers of obfuscation
- Makes traffic analysis extremely difficult
- Uses `replace/ice/` for NAT traversal

#### Conjure
- Builds on STUN/TURN protocol
- Makes traffic appear as WebRTC/STUN traffic
- Uses TURN servers as relays
- Resists active probing attacks

**How it works:**
1. Client sends STUN binding request to TURN server
2. TURN allocates relay address
3. Connection to relay looks like legitimate WebRTC
4. Relay forwards to Psiphon server
5. Server extracts real client connection

**Integration:**
- Client tries refraction first in connection attempts
- Falls back to other protocols if refraction fails
- Configured via build tag `PSIPHON_ENABLE_REFRACTION_NETWORKING`

---

## 9. Configuration System

### 9.1 Client Configuration

**File:** `psiphon/config.go`

Client configuration is a JSON object mapped to `Config` struct:

```go
type Config struct {
    // Identity
    PropagationChannelId string
    SponsorId            string
    ClientVersion        string
    ClientPlatform       string

    // Network
    LocalSocksProxyPort  int
    LocalHttpProxyPort   int

    // Server selection
    TargetServerEntry    string  // base64 encoded
    RemoteServerListURLs []string

    // Protocols
    TunnelProtocol       string  // comma-separated
    ObfuscatedSSH        ObfuscatedSSHConfig

    // Features
    RunPacketTunnel      bool
    SplitTunnel          bool
    EnableTactics        bool
    EnableUpgradeDownload bool

    // ... hundreds more parameters
}
```

**Loading:**
- `LoadConfig(filePath string) (*Config, error)`
- Validates required fields
- Applies defaults from `defaultConfig`
- Commits immutable config (protected after load)

**Access:**
- After `LoadConfig`, config is immutable
- Use `GetConfig()` to retrieve current config
- Modifications require creating new config

### 9.2 Server Configuration

**File:** `server/config.go`

Mirrors client config but server-specific:

```go
type Config struct {
    ServerIp                   string
    TunnelProtocolPorts        map[string]int
    SSHHostKey                 string
    ObfuscatedSSHSeed          string
    MeekCookieEncryptionKey   string
    // ... server-specific fields
}
```

**Loading:**
- `LoadConfig(filePath string) (*Config, error)`
- Validates all required fields present

### 9.3 Configuration Sources

Client can receive configuration from multiple sources:

1. **Static JSON file** - initial config
2. **Tactics** - remote JSON overrides
3. **Server push** - pushed configuration via API
4. **Upgrade download** - new config bundled with binary update

Sources are merged in priority order (later overrides earlier):
```
Static config < Tactics < Server push < Upgrade bundle
```

---

## 10. Server Entry Distribution

### 10.1 Server Entry Format

**Location:** `psiphon/common/protocol/serverEntry.go`

Server entry is a signed, encoded structure:

```go
type ServerEntry struct {
    IpAddress            net.IP
    Port                 int
    ProviderId           string
    Region               string
    Tags                 []string
    Protocols            []string
    ObfuscatedSSHSeed    string
    ObfuscatedSSHPadding int
    // ... more fields
    Signature            []byte  // Ed25519 signature
}
```

**Encoding:**
- CBOR serialization (compact binary)
- Base64-encoded for transport
- Signed with server's private key
- Client verifies with server's public key

### 10.2 Distribution Mechanisms

**1. Embedded Server Entries:**
- Compiled into client binary
- `psiphon.ImportEmbeddedServerEntries()`
- Used as fallback when all else fails

**2. Remote Server List Fetch:**
- HTTP GET from `RemoteServerListURLs`
- JSON response with array of server entries
- Optional OSL when `UseObfuscatedSSH` enabled
- Partitioned to prevent enumeration

**3. Server Push:**
- Connected server sends new server entries
- Via `ImportPushPayload` API call
- Enables dynamic network expansion

**4. Tactics Delivery:**
- Tactics payloads may include server entries
- Used for targeted server distribution

---

## 11. Design Patterns

### 11.1 Dependency Injection

Components receive dependencies via parameters rather than global state:

```go
// Example: Controller depends on config, dataStore, noticeWriter
controller := NewController(config, dataStore, noticeWriter)
```

### 11.2 Strategy Pattern

Pluggable algorithms selected at runtime:

- Tunnel dialing strategies (`protocol.TunnelProtocolUses*`)
- Obfuscation implementations (`NewClientObfuscator`)
- Traffic routing (SOCKS vs. packet tunnel)

### 11.3 Worker Pool

Parallel connection attempts with lifecycle management:

```go
for i := 0; i < config.ConnectionWorkerPoolSize; i++ {
    go worker.Run()
    time.Sleep(staggerDuration)
}
```

### 11.4 State Machine

Tunnel has clear lifecycle states:

```go
type Tunnel struct {
    isActivated   bool
    isClosed      bool
    // ...
}
```

State transitions enforced with guards.

### 11.5 Decorator Pattern

Connections wrapped with monitoring/transformation:

```go
conn = &BurstMonitoredConn{conn: conn, ...}
conn = &ActivityMonitoredConn{conn: conn, ...}
conn = &ThrottledConn{conn: conn, ...}
```

### 11.6 Observer Pattern

Notice system for events:

```go
psiphon.SetNoticeWriter(noticeWriter)
psiphon.Notice("TunnelEstablished", data)
```

Components register to receive notices.

### 11.7 Factory Pattern

Complex object creation:

```go
func NewClientObfuscator(sshConn net.Conn, seed []byte, padding int) (net.Conn, error)
func NewTCPDialer(config *Config) *TCPDialer
```

### 11.8 Chain of Responsibility

Connection layers processed in sequence:

```
Network dialer → Obfuscator → SSH → Monitors → Proxy listeners
```

---

## 12. Build System

### 12.1 Go Modules

Uses Go 1.24+ with modules:

```bash
go mod tidy      # Update dependencies
go mod vendor    # Vendor dependencies
go build ./...   # Build all packages
```

### 12.2 Build Tags

Conditional compilation via build constraints:

**Platform-specific:**
- `linux`, `darwin`, `windows`, `android` embedded in filenames

**Feature flags:**
- `PSIPHON_ENABLE_REFRACTION_NETWORKING` - enable TapDance/Conjure
- `PSIPHON_DISABLE_INPROXY` - disable inproxy
- Custom tags for race detector, profiler

**Usage:**
```bash
go build -tags "PSIPHON_ENABLE_REFRACTION_NETWORKING"
```

### 12.3 Replacement Modules

`replace` directives in `go.mod` override upstream dependencies:

```go
replace github.com/pion/ice/v2 => ./replace/ice
replace github.com/pion/webrtc/v3 => ./replace/webrtc
replace github.com/pion/dtls/v2 => ./replace/dtls
```

These forks contain Psiphon-specific modifications.

### 12.4 Target Platforms

- Linux (x86_64, ARM, ARM64)
- macOS (x86_64, ARM64)
- Windows (x86_64, ARM64)
- Android (ARM, ARM64)
- iOS (ARM64)

### 12.5 Binary Targets

```bash
# Build console client
go build -o ConsoleClient ./ConsoleClient

# Build server daemon
go build -o psiphond ./Server

# Build library
go build -o psiphon.a ./psiphon  # static library
```

---

## 13. Dependencies

### 13.1 Core Libraries

| Dependency | Purpose |
|------------|---------|
| `golang.org/x/crypto` | SSH implementation, cryptographic primitives |
| `fxamacker/cbor/v2` | Binary serialization (replaces JSON for efficiency) |
| `pion/ice/v2` | ICE/STUN/TURN for WebRTC and refraction |
| `pion/webrtc/v3` | WebRTC data channels for inproxy DTLS |
| `pion/dtls/v2` | DTLS for inproxy encrypted transport |
| `cloudflare/quic-go` | QUIC protocol support |
| `tailscale/wireguard` | WireGuard VPN protocol |
| `mitchellh/panicwrap` | Crash protection with restart |
| `google.golang.org/protobuf` | Metrics and structured logging |
| `patrickmn/go-cache` | In-memory caching |
| `golang.org/x/net` | Network utilities and HTTP/2 |

### 13.2 Psiphon-Specific Forks

| Module | Modification |
|--------|--------------|
| `github.com/Psiphon-Labs/psiphon-tls` | Customized TLS profiles and fingerprinting resistance |
| `github.com/Psiphon-Labs/quic-go` | Psiphon-specific QUIC adjustments |
| `github.com/Psiphon-Labs/utls` | ULS (TLS) for mimicking real clients |
| `github.com/refraction-networking/obfs4` | Obfs4 pluggable transport (via replace) |
| `github.com/refraction-networking/conjure` | Conjure refraction protocol |
| `github.com/refraction-networking/gotapdance` | TapDance refraction protocol |

### 13.3 Third-Party Libraries

Full list in `go.mod`. Key groups:
- **Crypto**: `ed25519`, `nacl/secretbox`, `hkdf`, `aes`, `chacha20`
- **Networking**: `dns`, `gopacket` (raw packets), `nfqueue` (Linux netfilter)
- **Storage**: `badger` (KV store), `bolt` (embedded DB), `leveldb`
- **Utilities**: `logrus` (logging), `cache-lru`, `groupcache`, `xxhash`
- **Platform**: `go-ole` (Windows COM), `gopsutil` (system info)

### 13.4 Vendoring

All dependencies vendored in `/vendor` for reproducible builds:
- Git submodules or `go mod vendor`
- Ensures builds work without network access
- Allows modification of dependencies

---

## 14. Testing Strategy

### 14.1 Unit Testing

Every package includes `_test.go` files:

```bash
go test ./...           # Run all tests
go test -v ./psiphon/...   # Verbose
go test -run TestName     # Specific test
go test -cover           # Coverage report
```

**Patterns:**
- Table-driven tests
- Test fixtures in `testdata/` directories
- Mock dependencies with interfaces

### 14.2 Integration Testing

End-to-end tests establishing real tunnels:

- `psiphon/controller_test.go`: Controller orchestration
- `psiphon/tunnel_test.go`: Full tunnel lifecycle
- `psiphon/common/tactics/tactics_test.go`: Tactics round-trips

**Test Server:**
- Tests spawn embedded server with test config
- Client connects to local server
- Verify traffic routing and statistics

### 14.3 CI/CD

**GitHub Actions:** `.github/workflows/tests.yml`
- Runs on multiple OS/arch combinations
- Linting (`go vet`, `staticcheck`)
- Test coverage upload to Coveralls
- Race detector enabled

**Local Testing:**
```bash
# Run tests
go test ./...

# Run with race detector
go test -race ./...

# Generate coverage
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

### 14.4 Testability Features

**Configuration parameters for deterministic testing:**
- `TestSkipServerListFetch` - disable network fetches
- `TestOnlyForceDialAddress` - force specific server
- `TestOnlyFixedRTT` - fixed latency for tests
- `TestOnlyNoStagger` - immediate worker start

**Mockable interfaces:**
- `TunnelOwner` - tunnel lifecycle callbacks
- `NoticeWriter` - logging abstraction
- `DataStore` - persistence abstraction

---

## 15. Development Guidelines

### 15.1 Code Style

- Standard Go formatting (`go fmt`)
- No trailing whitespace
- Comments for exported functions/types
- Readable error messages with `errors.Trace()` where applicable

### 15.2 Important Conventions

**Never log secrets:**
- Use `redact` package to redact keys, tokens, PII
- `redact.RedactableString` for sensitive strings

**Use notices for user-visible messages:**
```go
psiphon.Notice(NoticeConnectionEstablished, noticeData)
```

**Graceful shutdown:**
- Handle context cancellation
- Close resources in `defer` statements
- Respect `config.ShutdownOnClose`

**Configuration immutability:**
- Once loaded, config must not change
- Use `SetConfig()` only before operations start

**Concurrency safety:**
- Controller serializes access to shared state
- Tunnels use mutexes for concurrent access
- Check race conditions with `-race` flag

### 15.3 Adding New Protocols

To add a new tunnel protocol:

1. Define protocol constants in `psiphon/constants.go`
2. Add protocol detection in `dialTunnel()` switch
3. Implement dialer in `psiphon/dialer.go` or new file
4. Update `protocol.Supports*` functions
5. Add server-side listener in `server/listener.go`
6. Update protocol documentation

### 15.4 Adding New Obfuscation Methods

1. Implement `Obfuscator` interface in `psiphon/common/obfuscator/`
2. Add negotiation in `negotiateObfuscatedSSH()`
3. Update config with method-specific parameters
4. Maintain backward compatibility with seed-based OSSH

### 15.5 Debugging

**Enable verbose logging:**
```go
Config.LogLevel = "debug"
```

**Dump traffic:**
```go
Config.DumpTraffic = true  // logs all bytes (very verbose)
```

**Profile performance:**
```bash
go tool pprof http://localhost:6060/debug/pprof/profile
```

**Monitor notices:**
- Set `NoticeWriter` to console or file
- Filter by `NoticeType`

### 15.6 Common Pitfalls

**Blocking operations in dialTunnel:**
- Don't block indefinitely; respect `DialTimeout`
- Use context cancellation

**Leaking goroutines:**
- Ensure all goroutines exit on context cancellation
- Use `sync.WaitGroup` or channels for coordination

**Memory leaks:**
- Close `http.Response.Body` after reading
- Release references in data store cleanup

**Race conditions:**
- Protect shared state with mutexes or channels
- Test with `-race` flag

**Platform-specific code:**
- Create separate files with build tags (`//go:build windows`)
- Provide fallback implementation for other platforms

### 15.7 Pull Request Process

1. Fork repository
2. Create feature branch
3. Write code + tests
4. Run `go fmt`, `go vet`, tests
5. Ensure CI passes
6. Submit PR with description
7. Address review comments

**Note:** Psiphon Inc. may have additional internal processes.

---

## 16. Architecture Diagrams

### 16.1 Client Connection Flow

```
┌─────────────────┐
│   ConsoleClient │
│    or Library   │
└────────┬────────┘
         │
    LoadConfig()
         │
    ┌────▼─────────┐
    │  Controller   │◄────┐
    └────┬──────────┘     │
         │                │ (server list)
    Select Server         │
    & Protocol           │
         │                │
    ┌────▼─────────┐     │
    │ dialTunnel() │     │
    └────┬──────────┘     │
         │                │
    ┌────▼─────────┐     │
    │  Obfuscator  │     │ (optional)
    └────┬──────────┘     │
         │                │
    ┌────▼─────────┐     │
    │ SSH Client   │     │
    └────┬──────────┘     │
         │                │
    ┌────▼─────────┐     │
    │  Activate()  │─────┘
    └────┬──────────┘
         │
    ┌────▼─────────┐
    │ operateTunnel│
    │              │
    │ • SOCKS/HTTP │
    │ • PacketTun  │
    │ • Monitor    │
    └──────────────┘
```

### 16.2 Server Architecture

```
┌──────────────┐
│  Listener    │  (port 22 for SSH, 80/443 for Meek, etc.)
└──────┬───────┘
       │ Accept
       ↓
┌──────────────┐
│  Connection  │  Handle network connection
└──────┬───────┘
       │
    Detect Protocol
       │
       ├─ SSH → Upgrade to SSH session
       ├─ Meek → Parse HTTP request
       ├─ QUIC → Handle QUIC stream
       └─ ...
       │
┌──────▼──────────┐
│  API Handler    │  Handshake/Connected/Status requests
└──────┬──────────┘
       │
┌──────▼──────────┐
│  Tunnel Context │  Client IP, tunnel ID, auth
└──────┬──────────┘
       │
┌──────▼──────────┐
│ Traffic Forward │  Dial destination, relay bytes
│   + Filter     │  Apply traffic rules
└─────────────────┘
```

---

## 17. Frequently Asked Questions

**Q: Why Go?**
A: Strong concurrency model suits tunnel multiplexing; cross-platform; efficient networking.

**Q: How does client find servers?**
A: Embedded + remote fetch + push + tactics. See Section 10.

**Q: What's the difference between OSSH and Meek?**
A: OSSH wraps SSH traffic to look random; Meek makes traffic appear as HTTP/HTTPS to allowed domains.

**Q: Can I run my own server?**
A: Yes! Build `psiphond` from source or use binaries. See README.md.

**Q: How to add a new obfuscation method?**
A: See Section 15.4. Implement `Obfuscator` interface and wire into dialer.

**Q: Why are there so many configuration options?**
A: Psiphon operates in diverse environments; fine-tuning needed for different networks and censorship conditions.

**Q: How does the tactics system work securely?**
A: Tactics payloads are signed with Ed25519; clients verify signature using embedded public key.

**Q: What's inproxy/refraction?**
A: Advanced techniques to avoid direct client-server connections. See Section 8.

---

## 18. Key References

### Source Files
- **Main client logic:** `psiphon/controller.go`, `psiphon/tunnel.go`
- **Main server logic:** `psiphon/server/server.go`, `Server/main.go`
- **Protocol handling:** `psiphon/common/protocol/`
- **Obfuscation:** `psiphon/common/obfuscator/`
- **Configuration:** `psiphon/config.go`, `server/config.go`

### Documentation
- README.md - User guide
- `psiphon/common/inproxy/README.md` - Inproxy design notes
- `psiphon/common/refraction/README.md` - Refraction documentation (if exists)
- `CLA-*.md` - contributor license agreements

### External Resources
- Official site: https://psiphon.ca
- GitHub: https://github.com/Psiphon-Inc/psiphon-tunnel-core
- Research papers: Search "Psiphon" for academic publications on circumvention

---

## 19. Revision History

- **2026-05-10**: Initial documentation creation based on codebase analysis

---

*This document is auto-generated from codebase exploration. For questions or corrections, please open an issue on GitHub.*
