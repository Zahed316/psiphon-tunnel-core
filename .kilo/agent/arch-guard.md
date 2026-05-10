---
name: arch-guard
description: Enforce architectural patterns and dependency rules
triggers:
  - keyword: /check-architecture
  - before_commit: true
  - file_patterns: ["psiphon/**/*.go", "server/**/*.go"]
input: []
actions:
  - type: run_command
    command: |
      set -e
      echo "=== Architecture Guard ==="
      echo ""

      # Check 1: No direct config access in common/ packages
      echo "1. Checking dependency rules..."
      if grep -r "psiphon.GetConfig()" psiphon/common/ 2>/dev/null; then
        echo "WARNING: common/ package should not directly access GetConfig()"
        echo "         Use config passed as parameter instead"
      fi

      # Check 2: No logging without redact in sensitive areas
      echo ""
      echo "2. Checking for secret logging..."
      if grep -r "Notice.*key" psiphon/ 2>/dev/null | grep -v "redact"; then
        echo "WARNING: Potential secret logging detected"
        echo "         Use redact package for sensitive data"
      fi

      # Check 3: Ensure tunnels use notice system not fmt.Printf
      echo ""
      echo "3. Checking notice system usage..."
      if grep -r "fmt.Printf" psiphon/controller.go psiphon/tunnel.go 2>/dev/null; then
        echo "NOTE: Consider using psiphon.Notice() for user-visible messages"
      fi

      # Check 4: Verify context propagation
      echo ""
      echo "4. Checking context usage..."
      if grep -L "ctx context.Context" psiphon/*.go | grep -v "_test.go"; then
        echo "WARNING: Some files missing context parameter"
      fi

      # Check 5: No global variables in critical paths
      echo ""
      echo "5. Checking for problematic globals..."
      if grep -r "var.*=.*make(" psiphon/controller.go psiphon/tunnel.go 2>/dev/null; then
        echo "WARNING: Global mutable state detected"
      fi

      echo ""
      echo "Architecture check complete."
    description: Validate architectural patterns
  - type: suggest
    message: |
      Architecture analysis complete.

      Key principles:
      ✓ Dependency injection (configs passed as params)
      ✓ Context propagation for cancellation
      ✓ Notice system for logging
      ✓ Redact for secrets
      ✓ Minimal global state

      Fix violations before committing.
