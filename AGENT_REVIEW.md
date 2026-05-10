# Agent Configuration Review (AI tooling)

## Current state

As of 2026-05-10, this repository does **not** define project-level AI agent instruction files such as `AGENTS.md`.

## Risks

- No repository-specific guardrails for AI-assisted edits.
- No explicit boundaries for vendor/third-party folders (e.g., `vendor/`, `replace/webrtc/node_modules/`).
- No standard for required validation steps before automated commits.

## Recommended improvements

1. Add a root `AGENTS.md` to define:
   - where code changes are allowed/preferred;
   - how to handle generated files and vendored dependencies;
   - required tests/lint commands before commit;
   - commit message and PR body expectations.

2. Add scoped `AGENTS.md` files in complex subtrees (for example `psiphon/`, `Server/`, `MobileLibrary/`) where workflows differ.

3. Add explicit “do not edit unless requested” rules for vendored paths:
   - `vendor/`
   - `replace/webrtc/node_modules/`

4. Include security/privacy constraints for agent-authored changes:
   - never log sensitive runtime data;
   - avoid weakening transport/security defaults;
   - require review for any crypto/protocol changes.

## Suggested starter structure for root AGENTS.md

- Project overview and high-level constraints.
- Allowed edit zones and restricted zones.
- Build/test matrix (fast checks + full checks).
- Documentation update expectations.
- PR checklist template.

