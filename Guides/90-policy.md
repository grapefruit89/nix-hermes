---
title: "Policy & AI Governance Guide: bubblewrap LLM Sandboxing (jailed-agents) & mcp-nixos Server"
domain: 90
folder: 90-policy
status: active
complexity: 2
last_reviewed: 2026-05-26
links:
  adr:     ADR-90-policy.md
  modules:
    - path: Nix Files/modules/90-policy.nix
---

# Policy & AI Governance Guide: bubblewrap LLM Sandboxing (jailed-agents) & mcp-nixos Server

> **Operational guide for managing AI systemwide policies, running sandboxed LLM coding agents using bubblewrap containers (jailed-agents), and hosting the Model Context Protocol NixOS telemetry server (mcp-nixos).**
> Ensures zero-trust security for autonomous AI execution while supplying helpers with real-time Nix ecosystem documentation.

---

## Prerequisites

Before executing autonomous AI agents or telemetry lookups, verify:
- [x] Bubblewrap package (`bwrap`) is installed and whitelisted.
- [x] Host has internet connectivity to query Nixpkgs elasticsearch indexes.
- [x] The `nixos-native` policy standard is active in `90-policy.nix`.

---

## How It Works (AI Zero-Trust Sandboxing)

```
[Autonomous LLM Agent] 
          │
          ▼
[jailed-agents Shell (bwrap)] ──(Restricts home folder access)
          │
          ├─► [Exposes ONLY target project folder read/write]
          ├─► [Hides /persist/etc/ssh/ SSH keys & age decryption key]
          └─► [Restricts system tools: exposes only git/ripgrep/nix]
```

1. **Agent Sandboxing (`jailed-agents`):** Uses the `jail.nix` bubblewrap library to spawn ephemeral dev shells for autonomous AI coders, restricting their filesystem visibility to target repositories and preventing them from reading secret age keys.
2. **Context Enrichment (`mcp-nixos`):** The Model Context Protocol (MCP) server runs locally, exposing Nixpkgs packages, NixOS wiki, and option schemas to LLMs via JSON-RPC interfaces to avoid hallucinations during automated coding tasks.
3. **Dependency Auditing (`NixoScope`):** Generates graphs of Nix module imports to audit dependency footprints and discover hidden security risks.

---

## Operational Procedures

### Running LLM Coding Agents inside bubblewrap
To launch a secure, isolated environment for an LLM agent, execute the jailed-agents shell within your project directory:

```bash
# 1. Enter the sandboxed shell using the custom flake profile
nix develop github:andersonjoseph/jailed-agents#default

# 2. Run your autonomous coder tool inside the bubblewrap cage
# (The agent will have no access to SSH keys, SOPS secrets, or hosts databases)
agent-run --dir .
```

### Hosting the MCP NixOS Server (mcp-nixos)
The MCP server can be hosted as a systemd service or executed on demand to enrich your local IDE workspace:

```bash
# Start the MCP server for NixOS documentation queries
nix run github:utensils/mcp-nixos -- --port 3099
```

### Dependency Audit via NixoScope
To inspect active module dependency relationships and check for illegal imports:

```bash
# Generate the module dependency graph
nixos-compile-dependencies --format dot > dependencies.dot

# Render to PNG for manual inspection
dot -Tpng dependencies.dot -o dependencies.png
```

---

## Verification Commands

Run these to verify policy and sandbox enforcement:

```bash
# 1. Check if bubblewrap is working correctly
bwrap --version && echo "PASS: bubblewrap available"

# 2. Verify that the jailed agent cannot access root SSH keys or persistent age secrets
bwrap --ro-bind /etc /etc --unshare-all ls -la /persist/etc/ssh/ 2>/dev/null || echo "PASS: SSH keys isolated"
bwrap --ro-bind /etc /etc --unshare-all ls -la /var/lib/sops-nix/ 2>/dev/null || echo "PASS: SOPS keys isolated"

# 3. Verify MCP NixOS server is responding (using local port 3099)
curl -sf http://127.0.0.1:3099/status && echo "PASS: mcp-nixos active"
```

---

## Known Failure Modes

| Symptom | Likely Cause | Operational Fix |
| :--- | :--- | :--- |
| **Agent fails to build/evaluate Nix code inside cage** | Necessary nix packages are not whitelisted in bubblewrap paths | Update your `jail.nix` configuration to bind additional `/nix/store/` packages. |
| **mcp-nixos queries fail with Timeout** | The Nixpkgs Elasticsearch API is down or blocked by firewall | Verify internet connectivity and check Caddy gateway reverse-proxy paths. |
| **Bubblewrap throws "Permission Denied" on startup** | User namespace support is disabled in kernel | Ensure `boot.kernel.sysctl."kernel.unprivileged_userns_clone" = 1;` is enabled in `00-core.nix`. |