---
name: config-check
description: Validate Psiphon configuration files for common issues
triggers:
  - keyword: /check-config
  - file_patterns: ["*.config", "*.json"]
  - manual: true
input: []
actions:
  - type: run_command
    command: |
      set -e
      CONFIG_FILE="{{files[0]}}"
      echo "Validating config: $CONFIG_FILE"

      # Check required fields
      echo "Checking required fields..."
      REQUIRED_FIELDS=(
        "LocalSocksProxyPort"
        "LocalHttpProxyPort"
        "PropagationChannelId"
        "SponsorId"
      )

      for field in "${REQUIRED_FIELDS[@]}"; do
        if ! grep -q "\"$field\"" "$CONFIG_FILE" 2>/dev/null; then
          echo "WARNING: Missing recommended field: $field"
        fi
      done

      # Check port ranges
      echo "Checking port validity..."
      if grep -oP '"LocalSocksProxyPort"\s*:\s*\K[0-9]+' "$CONFIG_FILE" | grep -qE '^(0|[1-9][0-9]{1,4}|6[0-5][0-9]{4})$'; then
        echo "WARNING: Port out of range (0-65535)"
      fi

      # Check for test-only configs in production
      echo "Checking for test parameters..."
      if grep -q '"Test' "$CONFIG_FILE"; then
        echo "WARNING: Config contains test parameters"
      fi

      # Validate JSON syntax
      echo "Validating JSON syntax..."
      python3 -m json.tool "$CONFIG_FILE" > /dev/null

      # Check ObfuscatedSSHSeed format (if present)
      if grep -q "ObfuscatedSSHSeed" "$CONFIG_FILE"; then
        echo "Checking ObfuscatedSSHSeed format..."
        SEED=$(grep -oP '"ObfuscatedSSHSeed"\s*:\s*"\K[^"]+' "$CONFIG_FILE" | head -1)
        if [[ ! $SEED =~ ^[0-9a-fA-F]+$ ]]; then
          echo "WARNING: ObfuscatedSSHSeed should be hex string"
        fi
      fi

      echo "Config validation complete."
    description: Validate configuration file
  - type: suggest
    message: |
      Config validation finished. Review warnings above.

      Common issues:
      - Port conflicts (both SOCKS and HTTP using same port)
      - Missing required fields
      - Test parameters left in production config
      - Invalid hex strings for keys/seeds

      Need fixes? Ask me to /fix-config-issues.
    actions:
      - label: "Show config summary"
        prompt: "grep -E '^(//|[A-Z])' {{files[0]}} | head -20"
      - label: "Validate JSON only"
        prompt: "python3 -m json.tool {{files[0]}}"
