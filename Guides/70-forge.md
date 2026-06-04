---
title: "XX-name: Short Operational Title"
domain: XX
folder: XX-name
status: draft
complexity: 2          # mirrors linked module complexity
last_reviewed: YYYY-MM-DD
links:
  adr:     ADR-XX-name.md
  modules:
    - path: modules/XX-name/primary-module.nix
      anchor: anchor-name-in-module   # matches # (anchor: ...) comment in .nix file
    - path: modules/XX-name/secondary.nix
      anchor: secondary-anchor
---

# XX-name: Short Operational Title

> **One-sentence purpose statement.**
> What this domain does at runtime, for whom, and why it exists as its own domain.

---

## Prerequisites

Before touching anything in this domain, the following must be true:

- [ ] Domain `00-core` is deployed and healthy (`systemctl is-active NAME`)
- [ ] Domain `10-network` is deployed and healthy
- [ ] Secret `NAME_secret` exists in `/run/secrets/` (provisioned via SOPS)
- [ ] Add further hard prerequisites — not nice-to-haves

---

## How It Works (Architecture in Plain Language)

Describe the runtime data flow in 3–5 sentences. No Nix. No code.

Example structure:
1. **What starts it:** Which systemd target pulls this service in.
2. **What it talks to:** Other local services, network endpoints, storage paths.
3. **What depends on it:** Which higher-numbered domains need this running first.

---

## Operational Procedures

### Enable / First Deploy

Step-by-step instructions. Every step is a shell command or a file to check.
Assume the reader is at a recovery console.

```bash
# 1. Verify the service unit loaded correctly
systemctl status NAME.service

# 2. Verify it bound to the expected socket or port
ss -tlnp | grep NAME

# 3. Run the domain-specific smoke test
curl -sf http://127.0.0.1:PORT/health && echo "OK"
```

### Disable / Remove

```bash
# 1. How to safely stop this without breaking dependents
systemctl stop NAME.service

# 2. How to remove persistent state if needed
# (describe, don't always automate)
```

### Routine Maintenance

What an operator does weekly/monthly:

- Log rotation: automatic via `systemd.services.NAME.serviceConfig.LogsDirectory`
- Backup verification: `restic snapshots --tag NAME`
- Secret rotation: See `docs/guides/20-security.md#secret-rotation`

---

## Verification Commands

These must all pass before a deploy is considered healthy.

```bash
# 1. Service is running and not in a restart loop
systemctl is-active --quiet NAME && echo "PASS: active"

# 2. No failed units caused by this domain
systemctl --failed | grep NAME || echo "PASS: no failures"

# 3. Health endpoint responds (adapt per service)
curl -sf http://127.0.0.1:PORT/health | grep -q '"status":"ok"' && echo "PASS: healthy"

# 4. Logs show no ERROR in last 100 lines
journalctl -u NAME --no-pager -n 100 | grep -c ERROR | grep -q "^0$" && echo "PASS: clean logs"
```

---

## Known Failure Modes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Service in restart loop | SOPS secret not decrypted yet | Check `journalctl -u sops-nix` |
| Port already in use | Leftover process from old deploy | `fuser -k PORT/tcp` then redeploy |
| Permission denied on StateDirectory | Wrong uid in users.registry | Verify `config.my.users.registry.NAME` matches service User= |
| Add domain-specific rows | — | — |

---

## Cross-Domain Interactions

- **Depends on:** `00-core` (users/groups), `10-network` (firewall rules must allow PORT)
- **Used by:** `60-apps` (services that authenticate via this domain), `40-monitoring` (health checks)
- **Shared state:** Describe any shared files, sockets, or databases

---

## Decision Reference

Architecture rationale lives in `docs/adr/ADR-XX-name.md`.
This guide deliberately contains no rationale — only operations.
If you find yourself asking *why*, read the ADR.