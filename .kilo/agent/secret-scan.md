---
name: secret-scan
description: Scan for hardcoded secrets and sensitive data leakage
triggers:
  - keyword: /scan-secrets
  - before_commit: true
  - file_patterns: ["**/*.go", "**/*.json", "**/*.yaml", "**/*.yml"]
input: []
actions:
  - type: run_command
    command: |
      set -e
      echo "=== Secret Scanner ==="
      echo ""

      # Patterns that might indicate secrets
      SECRET_PATTERNS=(
        "private.*key.*[A-Za-z0-9+/=]{20,}"
        "secret.*[A-Za-z0-9+/=]{20,}"
        "password.*[A-Za-z0-9]{8,}"
        "token.*[A-Za-z0-9_-]{20,}"
        "api_key.*[A-Za-z0-9_-]{20,}"
        "ssh-rsa.*AAA"
        "-----BEGIN"
      )

      echo "Scanning for hardcoded secrets..."
      FOUND=0

      for pattern in "${SECRET_PATTERNS[@]}"; do
        matches=$(grep -r -i -P "$pattern" --exclude-dir=vendor --exclude-dir=.git . 2>/dev/null | grep -v "_test.go" | grep -v "testdata" || true)
        if [ -n "$matches" ]; then
          echo ""
          echo "FOUND potential secret matching: $pattern"
          echo "$matches"
          FOUND=$((FOUND+1))
        fi
      done

      # Check for unredacted logging
      echo ""
      echo "Checking for unredacted sensitive logging..."

      if grep -r "Notice.*ip" psiphon/ 2>/dev/null | grep -v "redact"; then
        echo "WARNING: IP address logging without redact"
        echo "Use: redact.SanitizeIP() or redact.RedactableString"
      fi

      if grep -r "Notice.*[Kk]ey" psiphon/ 2>/dev/null | grep -v "redact"; then
        echo "WARNING: Key logging without redact"
      fi

      # Check for test keys in non-test files
      echo ""
      echo "Checking for test credentials..."
      if grep -r "TestOnly" --include="*.go" psiphon/ | grep -v "_test.go"; then
        echo "WARNING: Test-only parameters in production code"
      fi

      echo ""
      if [ $FOUND -eq 0 ]; then
        echo "✅ No obvious secrets found"
      else
        echo "❌ Found $FOUND potential secret(s). Review immediately!"
      fi
    description: Scan for hardcoded secrets
  - type: suggest
    message: |
      Secret scan completed.

      If secrets were found:
      1. Immediately rotate/revoke exposed credentials
      2. Remove secrets from code, use environment variables or config
      3. Add to .gitignore if needed
      4. Consider using secret management tools

      Prevention:
      - Never commit keys/tokens
      - Use redact.RedactableString for sensitive strings
      - Preload test data from external files
