---
name: secret-scan
description: Enhanced security scanning for Go code
triggers:
  - keyword: /security-check
  - keyword: /scan
  - before_commit: true
input: []
actions:
  - type: run_command
    command: |
      set -e
      echo "=== Security Scanner ==="
      echo ""

      SCORE=100
      ISSUES=0

      # 1. Check for weak crypto
      echo "[1/6] Checking cryptography..."
      if grep -r "md5\|sha1" --include="*.go" psiphon/ 2>/dev/null | grep -v "testdata"; then
          echo "⚠️  Weak hash functions (MD5/SHA1) detected"
          SCORE=$((SCORE-10))
          ISSUES=$((ISSUES+1))
      else
          echo "✓ No weak hashes"
      fi

      # 2. Check for hardcoded credentials
      echo ""
      echo "[2/6] Checking hardcoded secrets..."
      if grep -r -E '(password|passwd|pwd)\s*[:=]\s*"[^"]{4,}"' --include="*.go" psiphon/ 2>/dev/null | grep -v "_test.go"; then
          echo "❌ Hardcoded credentials found!"
          SCORE=$((SCORE-30))
          ISSUES=$((ISSUES+1))
      else
          echo "✓ No obvious hardcoded secrets"
      fi

      # 3. Check for proper error handling
      echo ""
      echo "[3/6] Checking error handling..."
      if grep -r "if err != nil" psiphon/controller.go | wc -l | grep -q "^0$"; then
          echo "⚠️  No error checks in controller (suspicious)"
      else
          echo "✓ Error handling present"
      fi

      # 4. Input validation
      echo ""
      echo "[4/6] Checking input validation..."
      VALIDATED=false
      if grep -q "Validate()" psiphon/config.go; then
          VALIDATED=true
      fi
      if [ "$VALIDATED" = true ]; then
          echo "✓ Config validation exists"
      else
          echo "⚠️  Config validation may be incomplete"
          SCORE=$((SCORE-15))
          ISSUES=$((ISSUES+1))
      fi

      # 5. Timeouts
      echo ""
      echo "[5/6] Checking timeouts..."
      if grep -q "DialTimeout\|ReadTimeout\|WriteTimeout" psiphon/network.go 2>/dev/null; then
          echo "✓ Timeouts configured"
      else
          echo "⚠️  Check timeout configuration"
      fi

      # 6. Race condition check
      echo ""
      echo "[6/6] Checking for potential race conditions..."
      if grep -r "atomic\." psiphon/controller.go | grep -q "Load\|Store"; then
          echo "✓ Atomic operations used"
      else
          echo "⚠️  Review mutex usage"
          SCORE=$((SCORE-10))
      fi

      echo ""
      echo "─────────────────────"
      echo "Security Score: $SCORE/100"
      echo "Issues found: $ISSUES"
      echo ""

      if [ $SCORE -lt 80 ]; then
          echo "🔴 Review required before deployment"
      elif [ $SCORE -lt 90 ]; then
          echo "🟡 Minor improvements recommended"
      else
          echo "🟢 Good security posture"
      fi
    description: Run security checks
  - type: suggest
    message: |
      Security scan completed with score: {{score}}/100

      Critical items to fix:
      - Hardcoded credentials → use config/env vars
      - Weak crypto → use SHA256+ only
      - Missing validation → add Validate() methods

      Run `go vet` and `staticcheck` for additional analysis.
      Consider adding: `gosec` (github.com/securecodewarrior/gosec)
