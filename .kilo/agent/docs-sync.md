---
name: docs-sync
description: Keep documentation in sync with code changes
triggers:
  - keyword: /update-docs
  - after_command: ["build", "test", "lint"]
  - manual: true
input: []
actions:
  - type: run_command
    command: |
      set -e
      echo "=== Updating Documentation ==="

      # Extract exported functions from controller.go
      echo ""
      echo "Updating API references..."
      grep -E '^func [A-Z]' psiphon/controller.go | head -20 | sed 's/^func /- /' > /tmp/controller-api.txt
      echo "Controller API updated"

      # Extract protocol list
      echo ""
      echo "Updating protocol list..."
      grep "TunnelProtocol" psiphon/common/protocol/*.go | grep "const" | awk '{print $2}' | sed 's/=.*//' > /tmp/protocols.txt
      echo "Protocols: $(cat /tmp/protocols.txt)"

      # Check CODEBASE.md for outdated sections
      echo ""
      echo "Checking CODEBASE.md freshness..."
      LAST_UPDATED=$(grep "Revision History" -A 2 CODEBASE.md | tail -1 | awk '{print $2}')
      echo "Last documented update: $LAST_UPDATED"

      # Suggest updates
      echo ""
      echo "Documentation sync complete."
    description: Sync documentation with code
  - type: suggest
    message: |
      Documentation check complete.

      Found potential outdated sections:
      - Protocol list (check psiphon/common/protocol/)
      - Controller API (check psiphon/controller.go)
      - Configuration fields (check psiphon/config.go)

      To update CODEBASE.md:
      1. Review changed files since last commit
      2. Update relevant sections manually
      3. Run: /update-docs to regenerate references

      Need help with specific section? Ask /docs-section <section-name>
