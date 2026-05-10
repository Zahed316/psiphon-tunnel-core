---
name: perf-analyze
description: Analyze performance characteristics and identify bottlenecks
triggers:
  - keyword: /profile
  - keyword: /perf-check
  - manual: true
input:
  - name: duration
    type: integer
    prompt: "Profile duration (seconds)"
    default: 30
  - name: focus_area
    type: choice
    options:
      - "all"        # All subsystems
      - "tunnel"     # Tunnel establishment
      - "obfuscator" # Obfuscation overhead
      - "dialer"     # Connection dialing
    prompt: "Focus area"
actions:
  - type: run_command
    command: |
      set -e
      echo "=== Performance Analysis ==="
      echo "Duration: {{duration}}s"
      echo "Focus: {{focus_area}}"
      echo ""

      # 1. Memory allocation check
      echo "1. Checking for excessive allocations..."
      echo "   Run: go test -bench=. -benchmem ./psiphon/..."
      echo "   Watch for:"
      echo "   - High B/op (bytes per operation)"
      echo "   - High allocs/op"
      echo ""

      # 2. Goroutine leak detection
      echo "2. Checking for goroutine leaks..."
      cat << 'EOF'
      // Add to test:
      func TestNoGoroutineLeak(t *testing.T) {
          before := runtime.NumGoroutine()

          // Execute code
          foo()

          // Wait and check
          time.Sleep(100 * time.Millisecond)
          after := runtime.NumGoroutine()

          if after > before + 5 { // tolerance
              t.Fatalf("goroutine leak: %d → %d", before, after)
          }
      }
      EOF
      echo ""

      # 3. Lock contention analysis
      echo "3. Checking for mutex contention..."
      if grep -r "sync.Mutex" psiphon/controller.go psiphon/tunnel.go | grep -q "Lock"; then
          echo "   Note: Controller uses mutexes - monitor with:"
          echo "   go tool pprof -mutex http://localhost:6060/debug/pprof/mutex"
      fi
      echo ""

      # 4. Common bottlenecks
      echo "4. Common bottlenecks in Psiphon:"
      echo "   - Obfuscator layer adds CPU overhead"
      echo "   - Meek protocol high latency (HTTP roundtrips)"
      echo "   - BoltDB writes on tunnel close"
      echo "   - GeoIP lookups per connection"
      echo ""

      # 5. Quick profiling command
      echo "5. Quick profiling:"
      echo "   go test -cpuprofile=cpu.prof ./psiphon/..."
      echo "   go tool pprof cpu.prof"
      echo "   In pprof: top10, list FuncName, web"
      echo ""

    description: Performance profiling guide
  - type: suggest
    message: |
      Performance analysis configured.

      Quick start:
      1. Run benchmarks: go test -bench=. ./psiphon/ -run=^$ -benchmem
      2. Profile CPU: go test -cpuprofile=cpu.prof ./psiphon/... && go tool pprof cpu.prof
      3. Profile memory: go test -memprofile=mem.prof ./psiphon/... && go tool pprof mem.prof
      4. Profile mutexes: go test -mutexprofile=mux.prof ./psiphon/... && go tool pprof -mutex mux.prof

      Expected baselines (approximate):
      - OSSH overhead: ~5-10% CPU vs plain SSH
      - Meek latency: 500ms-2s per request
      - Tunnel establishment: 1-5s typical

      Got specific bottleneck? Share pprof output for analysis.
