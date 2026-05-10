---
name: protocol-scaffold
description: Generate scaffold code for a new tunnel protocol implementation
triggers:
  - keyword: /new-protocol
  - keyword: /scaffold-protocol
  - pattern: "add.*protocol"
input:
  - name: protocol_name
    type: string
    prompt: "Protocol name (e.g., MyProtocol)"
  - name: has_obfuscation
    type: boolean
    prompt: "Requires obfuscation layer?"
  - name: is_udp_based
    type: boolean
    prompt: "UDP-based protocol?"
actions:
  - type: create_file
    path: "psiphon/dial_{{protocol_name|lower}}.go"
    template: |
      package psiphon

      import (
          "context"
          "net"
          "time"

          "github.com/Psiphon-Labs/psiphon-tunnel-core/psiphon/common"
          "github.com/Psiphon-Labs/psiphon-tunnel-core/psiphon/common/errors"
      )

      // dial{{protocol_name}} establishes a tunnel using {{protocol_name}} protocol.
      func dial{{protocol_name}}(ctx context.Context, config *Config, dialParams *dialParams) (*Tunnel, error) {
          // TODO: Implement {{protocol_name}} dialing
          // 1. Create network connection (TCP/UDP)
          // 2. Wrap with obfuscator if dialParams.obfuscator != nil
          // 3. Perform SSH handshake
          // 4. Create tunnel and return

          return nil, errors.TraceNew("not implemented")
      }

  - type: create_file
    path: "psiphon/common/protocol/{{protocol_name|lower}}.go"
    template: |
      package protocol

      import "github.com/Psiphon-Labs/psiphon-tunnel-core/psiphon/common"

      // {{protocol_name}} implements TunnelProtocol for {{protocol_name}} protocol.

      const (
          TunnelProtocol{{protocol_name}} = "{{protocol_name|upper}}"
      )

      func init() {
          RegisterProtocol(TunnelProtocol{{protocol_name}})
      }

      // UsesObfuscatedSSH returns true if {{protocol_name}} requires OSSH.
      func (p *{{protocol_name}}Protocol) UsesObfuscatedSSH() bool {
          return {{has_obfuscation}}
      }

      // UsesQUIC returns true if {{protocol_name}} is QUIC-based.
      func (p *{{protocol_name}}Protocol) UsesQUIC() bool {
          return false
      }

      // UsesMeek returns true if {{protocol_name}} uses HTTP fronting.
      func (p *{{protocol_name}}Protocol) UsesMeek() bool {
          return false
      }

  - type: insert_code
    path: "psiphon/config.go"
    marker: "// Protocol-specific settings"
    code: |
      // {{protocol_name}}Settings configures {{protocol_name}} behavior.
      type {{protocol_name}}Settings struct {
          Enable bool `json:"enable"`
          // Add protocol-specific fields
      }

  - type: insert_code
    path: "psiphon/dialer.go"
    marker: "case protocol.TunnelProtocolXXX:"
    code: |
      case protocol.TunnelProtocol{{protocol_name}}:
          return dial{{protocol_name}}(ctx, config, dialParams)

  - type: suggest
    message: |
      Protocol scaffold created! Next steps:
      1. Implement dial{{protocol_name}}() in psiphon/dial_{{protocol_name|lower}}.go
      2. Add server-side listener in server/listener.go
      3. Register protocol in psiphon/common/protocol/register.go
      4. Add unit tests in psiphon/dial_{{protocol_name|lower}}_test.go
      5. Update documentation in CODEBASE.md
    actions:
      - label: "View generated files"
        prompt: "ls -la psiphon/dial_{{protocol_name|lower}}.go psiphon/common/protocol/{{protocol_name|lower}}.go"
      - label: "Run tests"
        prompt: "go test ./psiphon/... -run Test{{protocol_name}}"
