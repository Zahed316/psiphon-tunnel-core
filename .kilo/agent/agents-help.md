---
name: agents-help
description: List and explain all available agents
triggers:
  - keyword: /agents
  - keyword: /help-agents
  - keyword: ??
input: []
actions:
  - type: suggest
    message: |
      # Available Agents for Psiphon Tunnel Core

      ## By Category

      ### 🏗️ Code Generation
      **`/new-protocol <name>`** - protocol-scaffold
      > Generate scaffold for new tunnel protocol (dialer, listener, config)

      **`/new-obfuscator <name>`** - obfuscator-gen
      > Create obfuscation method implementation

      **`/codegen <type> <name>`** - codegen
      > Generate boilerplate (config, interface, errors, constants)

      **`/gen-test <pkg> <func>`** - test-gen
      > Generate unit test scaffolding

      ### ✅ Quality Assurance
      **`/check-config <file>`** - config-check
      > Validate configuration files for common issues

      **`/check-architecture`** - arch-guard
      > Enforce architectural patterns (run pre-commit)

      **`/scan-secrets`** - secret-scan / security-check
      > Find hardcoded secrets and security issues

      **`/perf-check`** - perf-analyze
      > Performance profiling and bottleneck analysis

      ### 📚 Documentation
      **`/update-docs`** - docs-sync
      > Sync documentation with code changes

      ### 🔄 Migration
      **`/migrate <type> <from> <to>`** - migrate
      > Assist with breaking changes and upgrades

      ## Usage Examples

      ```bash
      # Create new protocol named "MyProto"
      /new-protocol MyProto

      # Generate obfuscator called "XorPad"
      /new-obfuscator XorPad

      # Check config file
      /check-config client.config

      # Scan for secrets before commit
      /scan-secrets

      # Generate test for function ParseServerEntry
      /gen-test protocol ParseServerEntry

      # Run architecture validation
      /check-architecture

      # Profile performance
      /profile 60 tunnel

      # Migrate config from v1.0 to v1.1
      /migrate config-schema v1.0.0 v1.1.0
      ```

      ## Automatic Triggers

      Some agents run automatically:
      - `arch-guard`: before every commit (if configured)
      - `secret-scan`: on pre-commit hook
      - `docs-sync`: after build/test commands

      Tip: Use `/agents` anytime to see this list.
    show_output: false
