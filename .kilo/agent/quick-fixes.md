---
name: quick-fixes
description: Common quick fixes for Psiphon development issues
triggers:
  - keyword: /fix
  - keyword: /quick-fix
input:
  - name: issue_type
    type: choice
    options:
      - "import-cycle"    # Import cycle errors
      - "config-error"    # Configuration validation failures
      - "tunnel-fail"     # Tunnel won't establish
      - "test-fail"       # Tests failing
      - "build-error"     # Build/link errors
    prompt: "What needs fixing?"
actions:
  - type: suggest
    message: |
      # Quick Fix: {{issue_type}}

      {{if eq .issue_type "import-cycle"}}
      ## Import Cycle Fix

      **Symptoms:** `import cycle not allowed`

      **Solution:**
      1. Identify cyclic import with: `go mod graph | grep <pkg>`
      2. Extract shared types to `common/` package
      3. Use interface{} or function parameters to break cycle
      4. Consider: dependency inversion (pass interfaces, not structs)

      **Example:**
      ```go
      // BEFORE (cycle):
      // psiphon imports server
      // server imports psiphon

      // AFTER (break cycle):
      // psiphon/common/protocol defines interfaces
      // server implements, psiphon consumes interfaces
      ```

      Need specific cycle analyzed? Share error output.
      {{end}}

      {{if eq .issue_type "config-error"}}
      ## Config Error Fix

      **Symptoms:** `error processing configuration file`, validation failures

      **Debug Steps:**
      1. Validate JSON: `python3 -m json.tool config.json`
      2. Check required fields:
         ```bash
         grep -E 'required|mandatory' psiphon/config.go
         ```
      3. Use defaults: `"Field": nil` → omit to use default
      4. Run `/check-config` for detailed analysis

      **Common Issues:**
      - ✗ Port 0 or > 65535 → fix: use valid port
      - ✗ Empty string for required field → add value
      - ✗ Negative timeout → set to positive or nil for default
      - ✗ Invalid hex key → ensure even-length hex string

      **Quick validation:**
      ```bash
      go run ./psiphon/configvalidator -config=your.config
      ```
      {{end}}

      {{if eq .issue_type "tunnel-fail"}}
      ## Tunnel Establishment Failure

      **Symptoms:** Tunnel connects then disconnects, or never connects

      **Debug Steps:**
      1. Enable debug logging:
         ```
         "LogLevel": "debug"
         ```
      2. Check notices for:
         - `DialError` → network/firewall issue
         - `SSHHandshakeError` → key mismatch
         - `APIHandshakeError` → server config issue
         - `LivenessCheckFailed` → tunnel died after establishment

      3. Verify server reachability:
         ```bash
         nc -zv <server_ip> <port>
         ```

      4. Common fixes:
         - Server key mismatch → regenerate server-entry.dat
         - Obfuscation seed mismatch → ensure client/server seeds match
         - Port blocked → try different protocol/port
         - GeoIP blocked → use split tunnel or different region

      5. Test with direct connection:
         ```
         "TargetServerEntry": "explicit_server_entry_here"
         ```

      Need help? Share debug log (redacted).
      {{end}}

      {{if eq .issue_type "test-fail"}}
      ## Test Failure Fix

      **Symptoms:** `go test` failing

      **Quick Actions:**
      1. Run specific test: `go test -run TestName -v`
      2. Show race condition: `go test -race`
      3. Update testdata: sometimes testdata/ files need regeneration
      4. Check timestamps: some tests depend on time.Time

      **Common Issues:**
      - **Flaky tests:** Check for time.Sleep, use deterministic timing
      - **Network tests:** May need `-short` flag to skip
      - **Platform-specific:** Ensure test has fallback for all OS

      **Fix template:**
      ```go
      func TestFoo(t *testing.T) {
          t.Parallel()  // Add if test is independent

          // Use testing package
          if got != want {
              t.Fatalf("got %v, want %v", got, want)
          }
      }
      ```

      Still failing? Share error message.
      {{end}}

      {{if eq .issue_type "build-error"}}
      ## Build Error Fix

      **Symptoms:** Compilation/linking errors

      **Common Fixes:**
      1. **Missing dependency:**
         ```bash
         go mod tidy
         go mod vendor
         ```

      2. **Version conflict:**
         ```bash
         go mod why <module>
         go get <module>@latest
         ```

      3. **Platform-specific build:**
         ```bash
         # For Windows:
         GOOS=windows GOARCH=amd64 go build

         # For Android:
         GOOS=android GOARCH=arm64 go build
         ```

      4. **Build tag needed:**
         ```bash
         go build -tags "PSIPHON_ENABLE_REFRACTION_NETWORKING"
         ```

      5. **Vendor out of date:**
         ```bash
         rm -rf vendor
         go mod vendor
         ```

      **Still stuck?**
      - Clean build: `go clean -cache -modcache -i -r`
      - Fresh clone: `git clean -fdx && git reset --hard`
      {{end}}

      ---
      **Need more help?** `/agents` shows all available agents.
    show_output: false
