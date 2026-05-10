---
name: obfuscator-gen
description: Generate scaffolding for new traffic obfuscation method
triggers:
  - keyword: /new-obfuscator
  - keyword: /obfuscator-scaffold
input:
  - name: obfuscator_name
    type: string
    prompt: "Obfuscator name (e.g., XorScramble, RandomPad)"
  - name: uses_encryption
    type: boolean
    prompt: "Uses encryption (not just transformation)?"
actions:
  - type: create_file
    path: "psiphon/common/obfuscator/{{obfuscator_name|lower}}.go"
    template: |
      package obfuscator

      import (
          "io"
          "github.com/Psiphon-Labs/psiphon-tunnel-core/psiphon/common/errors"
      )

      // {{obfuscator_name}} obfuscates traffic by {{description}}.
      //
      // This is a client-side implementation. Server-side must match.
      type {{obfuscator_name}} struct {
          reader io.Reader
          writer io.Writer
          // Add state fields
      }

      // NewClient{{obfuscator_name}} creates a new client obfuscator.
      func NewClient{{obfuscator_name}}(conn io.ReadWriteCloser, params map[string]interface{}) (io.ReadWriteCloser, error) {
          o := &{{obfuscator_name}}{
              reader: conn,
              writer: conn,
          }
          // Initialize with params (e.g., seed, key, iterations)
          return o, nil
      }

      // NewServer{{obfuscator_name}} creates a new server obfuscator.
      func NewServer{{obfuscator_name}}(conn io.ReadWriteCloser, params map[string]interface{}) (io.ReadWriteCloser, error) {
          // Server-side implementation (usually symmetric with client)
          return NewClient{{obfuscator_name}}(conn, params)
      }

      func (o *{{obfuscator_name}}) Read(p []byte) (n int, err error) {
          // TODO: Deobfuscate incoming data
          return o.reader.Read(p)
      }

      func (o *{{obfuscator_name}}) Write(p []byte) (n int, err error) {
          // TODO: Obfuscate outgoing data
          return o.writer.Write(p)
      }

      func (o *{{obfuscator_name}}) Close() error {
          if c, ok := o.reader.(io.Closer); ok {
              return c.Close()
          }
          return nil
      }

  - type: create_file
    path: "psiphon/common/obfuscator/{{obfuscator_name|lower}}_test.go"
    template: |
      package obfuscator

      import (
          "bytes"
          "testing"

          "github.com/Psiphon-Labs/psiphon-tunnel-core/psiphon/common/errors"
      )

      func Test{{obfuscator_name}}(t *testing.T) {
          // TODO: Test obfuscation round-trip
          // 1. Create client obfuscator with test params
          // 2. Write data, read back
          // 3. Verify data matches (or intentionally differs for obfuscation)
          // 4. Test with server obfuscator
      }

  - type: suggest
    message: |
      Obfuscator scaffold created! Next steps:
      1. Implement obfuscation logic in {{obfuscator_name}}.Read/Write
      2. Define parameter structure (seed, key, etc.)
      3. Add negotiation in negotiateObfuscatedSSH()
      4. Update ObfuscatedSSHConfig to support this method
      5. Write comprehensive tests
    actions:
      - label: "View obfuscator file"
        prompt: "cat psiphon/common/obfuscator/{{obfuscator_name|lower}}.go"
      - label: "Run obfuscator tests"
        prompt: "go test ./psiphon/common/obfuscator/ -v"
