# Gap Analysis: External GitHub Repositories vs. Active 10-Domain SSoT

Generated on: 2026-05-26T19:50:17.709Z

This report lists the structure and contents of the 4 cloned external repositories, compares them with our active v14 SSoT architecture, and identifies gaps.

## 1. External Repositories Overview

| Repository | Nix Files | Markdown Files | JSON Files | Other Files | Total |
|---|---|---|---|---|---|
| **mynixos** | 115 | 2 | 0 | 10 | 127 |
| **mynixos-knowledge-base** | 0 | 309 | 1 | 5 | 315 |
| **mynixos-v5** | 151 | 167 | 2 | 25 | 345 |
| **nixos** | 336 | 46 | 0 | 8 | 390 |

---

## 2. Detailed File Structures & Key Targets

### 📂 Repository: [mynixos](https://github.com/grapefruit89/mynixos)

#### Nix Configurations (Top 25):
- `.legacy_folders/10-infrastructure/_imports.nix`
- `.legacy_folders/20-automation/service-app-open-webui.nix`
- `.legacy_folders/20-automation/_imports.nix`
- `00-core/auto-locale.nix`
- `00-core/backup.nix`
- `00-core/boot-safeguard.nix`
- `00-core/central-configs-plan.nix`
- `00-core/config-merger.nix`
- `00-core/configs.nix`
- `00-core/defaults.nix`
- `00-core/fail2ban.nix`
- `00-core/firewall.nix`
- `00-core/hardware-configuration.nix`
- `00-core/home-manager.nix`
- `00-core/host-q958-hardware-configuration.nix`
- `00-core/host-q958-hardware-profile.nix`
- `00-core/host.nix`
- `00-core/kernel-slim.nix`
- `00-core/lib-helpers-meta.nix`
- `00-core/lib-helpers.nix`
- `00-core/locale.nix`
- `00-core/logging.nix`
- `00-core/motd.nix`
- `00-core/network.nix`
- `00-core/nix-tuning.nix`
- *...and 90 more Nix files.*

#### Markdown Documentation (Top 25):
- `docs/SPEC_REGISTRY.md`
- `README.md`


---

### 📂 Repository: [mynixos-knowledge-base](https://github.com/grapefruit89/mynixos-knowledge-base)

#### Markdown Documentation (Top 25):
- `00_GOLDEN_HANDBOOK_Dendritic_NixOS.md`
- `00_MASTER_INDEX.md`
- `00_STATUS_DASHBOARD.md`
- `adr/ADR-003-Ejected-Services.md`
- `adr/ADR-004-Media-Engine-VPN-Isolation.md`
- `adr/ADR-005-Hybrid-Identity-Model.md`
- `adr/ADR-006-Secret-Management-Audit.md`
- `adr/ADR-006-Storage-Cluster-Strategy.md`
- `adr/ADR-007-DNS-Naming-Standard.md`
- `adr/ADR-008-SSH-ProxyJump-Standard.md`
- `adr/ADR-009-Media-Stack-Consolidation.md`
- `adr/ADR-010-Headless-Server-Law.md`
- `adr/ADR-011-On-Demand-Services.md`
- `adr/ADR-012-Socket-Activation-Selection.md`
- `adr/ADR-013-Media-Performance-Priority.md`
- `adr/ADR-014-Systemic-Governance.md`
- `adr/ADR-015-Distance-Parity-Mandate.md`
- `adr/ADR-016-Sops-Boot-Timing.md`
- `adr/backup-strategy-v4.2.md`
- `adr/cloudflare-zero-trust-v4.2.md`
- `adr/dashboard-hierarchy.md`
- `adr/den-framework-foundation.md`
- `adr/dendritic-denix-architecture-v4.2.md`
- `adr/disaster-recovery-strategy.md`
- `adr/distribution-strategy-v5.md`
- *...and 284 more Markdown files.*

#### JSON/YAML Configs:
- `metadata.json`


---

### 📂 Repository: [mynixos-v5](https://github.com/grapefruit89/mynixos-v5)

#### Nix Configurations (Top 25):
- `configuration.nix`
- `flake.nix`
- `hardware/q958/hardware-configuration.template.nix`
- `hardware/q958/hardware-profile.nix`
- `hardware/q958/uuid-map.nix`
- `modules/40-media/41-lib-media.nix`
- `modules/40-media/42-arr-stack.nix`
- `modules/40-media/43-download.nix`
- `modules/40-media/44-streaming.nix`
- `modules/40-media/45-discovery.nix`
- `modules/apps/automation.nix`
- `modules/apps/media-stack.nix`
- `modules/apps/service-app-ai-agents.nix`
- `modules/apps/service-app-ai-tools.nix`
- `modules/apps/service-app-audiobookshelf.nix`
- `modules/apps/service-app-couchdb.nix`
- `modules/apps/service-app-filebrowser.nix`
- `modules/apps/service-app-home-assistant.nix`
- `modules/apps/service-app-karakeep.nix`
- `modules/apps/service-app-linkding.nix`
- `modules/apps/service-app-linkwarden.nix`
- `modules/apps/service-app-matrix-conduit.nix`
- `modules/apps/service-app-miniflux.nix`
- `modules/apps/service-app-monica.nix`
- `modules/apps/service-app-n8n.nix`
- *...and 126 more Nix files.*

#### Markdown Documentation (Top 25):
- `docs/adr/ADR-003-Ejected-Services.md`
- `docs/adr/ADR-004-Media-Engine-VPN-Isolation.md`
- `docs/adr/ADR-008-SSH-ProxyJump-Standard.md`
- `docs/adr/ADR-009-Media-Stack-Consolidation.md`
- `docs/adr/ADR-010-Headless-Server-Law.md`
- `docs/adr/ADR-011-On-Demand-Services.md`
- `docs/adr/ADR-012-Socket-Activation-Selection.md`
- `docs/adr/ADR-013-Media-Performance-Priority.md`
- `docs/adr/ADR-014-Systemic-Governance.md`
- `docs/adr/ADR-016-Sops-Boot-Timing.md`
- `docs/adr/ADR-017-Cloudflare-DNS-Only.md`
- `docs/adr/ADR-018-Media-Stack-Architecture.md`
- `docs/adr/ADR-040-Storage-Strategy.md`
- `docs/adr/ADR-041-Distance-Parity.md`
- `docs/adr/README.md`
- `docs/archive/adr/legacy/ADR-005-Hybrid-Identity-Model.md`
- `docs/archive/adr/legacy/ADR-006-Secret-Management-Audit.md`
- `docs/archive/adr/legacy/ADR-006-Storage-Cluster-Strategy.md`
- `docs/archive/adr/legacy/ADR-007-DNS-Naming-Standard.md`
- `docs/archive/adr/legacy/ADR_Chat_Destillat.md`
- `docs/archive/adr/legacy/backup-strategy-v4.2.md`
- `docs/archive/adr/legacy/cloudflare-zero-trust-v4.2.md`
- `docs/archive/adr/legacy/dashboard-hierarchy.md`
- `docs/archive/adr/legacy/den-framework-foundation.md`
- `docs/archive/adr/legacy/dendritic-denix-architecture-v4.2.md`
- *...and 142 more Markdown files.*

#### JSON/YAML Configs:
- `docs/archive/legacy_specs/NIXMETA_SCHEMA.json`
- `docs/NIXMETA_SCHEMA.json`


---

### 📂 Repository: [nixos](https://github.com/grapefruit89/nixos)

#### Nix Configurations (Top 25):
- `flake.nix`
- `hosts/laptop/configuration.nix`
- `hosts/laptop/default.nix`
- `hosts/laptop/hardware-nixos.nix`
- `hosts/q958/configuration.nix`
- `hosts/q958/default.nix`
- `hosts/q958/hardware-nixos.nix`
- `modules/00-core/00-principles.nix`
- `modules/00-core/01-configs-registry.nix`
- `modules/00-core/01-lib-mkservice.nix`
- `modules/00-core/02-defaults.nix`
- `modules/00-core/02-nix-tuning.nix`
- `modules/00-core/03-hardware-profile.nix`
- `modules/00-core/03-ports.nix`
- `modules/00-core/04-boot-safeguards.nix`
- `modules/00-core/04-registry.nix`
- `modules/00-core/05-system-stability.nix`
- `modules/00-core/05-tpm2.nix`
- `modules/00-core/06-zram-swap.nix`
- `modules/00-core/07-locale-system.nix`
- `modules/00-core/08-tty-info.nix`
- `modules/00-core/08-users-shell.nix`
- `modules/00-core/09-backup.nix`
- `modules/00-core/10-shell-premium.nix`
- `modules/00-core/11-symbiosis.nix`
- *...and 311 more Nix files.*

#### Markdown Documentation (Top 25):
- `docs/adr/ADR-00-core.md`
- `docs/adr/ADR-10-network.md`
- `docs/adr/ADR-20-security.md`
- `docs/adr/ADR-30-storage.md`
- `docs/adr/ADR-40-monitoring.md`
- `docs/adr/ADR-50-media.md`
- `docs/adr/ADR-60-apps.md`
- `docs/adr/ADR-70-forge.md`
- `docs/adr/ADR-80-gaming.md`
- `docs/adr/ADR-90-policy.md`
- `docs/guides/00-core.md`
- `docs/guides/10-network.md`
- `docs/guides/13-mtls-setup.md`
- `docs/guides/20-security.md`
- `docs/guides/30-storage.md`
- `docs/guides/40-monitoring.md`
- `docs/guides/50-media.md`
- `docs/guides/60-apps.md`
- `docs/guides/70-forge.md`
- `docs/guides/80-gaming.md`
- `docs/guides/90-policy.md`
- `docs/SPEC_REGISTRY_METABIBLIOTHEK.md`
- `Gemini.md`
- `hosts/laptop/README.md`
- `hosts/q958/README.md`
- *...and 21 more Markdown files.*


---

## 3. Specific Gap Analysis against Active 10 Domains

Below is a comparison of configurations and architectures between the external repositories and our active modernized configuration.

### Keyword Search Across Repositories:

#### 🔍 Term: `zigbee`
- **mynixos**: `.legacy_folders/20-automation/_imports.nix`, `00-core/configs.nix`, `00-core/ports.nix`, `00-core/registry.nix`, `20-infrastructure/service-app-zigbee-stack.nix`, `20-infrastructure/_imports.nix`, `30-automation/service-app-home-assistant.nix`, `docs/SPEC_REGISTRY.md`
- **mynixos-knowledge-base**: `00_GOLDEN_HANDBOOK_Dendritic_NixOS.md`, `adr/nixhome-architecture.md`, `GUIDE-Home-Assistant-Blueprint.md`, `guides/GUIDE-Radar-Services-Master-Config.md`, `guides/MASTER-HA-INTERFACES.md`, `ironic-auto-awesome-home-assistant.md`, `metadata.json`, `services/service-automation-home-assistant.md`, `services/service-infrastructure-zigbee.md`
- **mynixos-v5**: `docs/archive/adr/legacy/ADR_Chat_Destillat.md`, `docs/archive/adr/legacy/nixhome-architecture.md`, `docs/archive/audits/09-mkservice-hardening.md`, `docs/archive/audits/Claude-Iterative Zero-Trust Code-Analyse für NixOS repo_v5.md`, `docs/archive/audits/Grok-NixMeta Bash Feasibility Audit (1).md`, `docs/archive/audits/SERVICE_MEMORY_LIMITS.md`, `docs/archive/compress/ADR_Chat_Destillat.md`, `docs/archive/compress/ADR_Chat_Destillat_1.md`, `docs/archive/compress/SERVICE_MEMORY_LIMITS.md`, `docs/archive/compress/__compress_Bundle.md` *(and 9 more)*
- **nixos**: `docs/adr/ADR-10-network.md`, `docs/adr/ADR-60-apps.md`, `docs/guides/10-network.md`, `docs/guides/60-apps.md`, `docs/SPEC_REGISTRY_METABIBLIOTHEK.md`, `hosts/laptop/configuration.nix`, `hosts/q958/configuration.nix`, `modules/00-core/01-configs-registry.nix`, `modules/00-core/03-ports.nix`, `modules/00-core/14-uid-registry.nix` *(and 12 more)*

#### 🔍 Term: `slzb`
- **mynixos**: `20-infrastructure/service-app-zigbee-stack.nix`
- **mynixos-knowledge-base**: `services/service-infrastructure-zigbee.md`
- **mynixos-v5**: `modules/services/service-app-zigbee-stack.nix`
- **nixos**: `_fetch/v5-services-service-app-zigbee-stack.nix`, `_fetch/v5-svc-service-app-zigbee-stack.nix`

#### 🔍 Term: `caddy`
- **mynixos**: `.legacy_folders/10-infrastructure/_imports.nix`, `.legacy_folders/20-automation/service-app-open-webui.nix`, `00-core/config-merger.nix`, `00-core/fail2ban.nix`, `00-core/lib-helpers.nix`, `00-core/motd.nix`, `00-core/registry.nix`, `00-core/secrets.nix`, `10-gateway/adguardhome.nix`, `10-gateway/caddy.nix` *(and 25 more)*
- **mynixos-knowledge-base**: `00_GOLDEN_HANDBOOK_Dendritic_NixOS.md`, `00_MASTER_INDEX.md`, `adr/ADR-003-Ejected-Services.md`, `adr/ADR-004-Media-Engine-VPN-Isolation.md`, `adr/ADR-005-Hybrid-Identity-Model.md`, `adr/ADR-006-Secret-Management-Audit.md`, `adr/ADR-011-On-Demand-Services.md`, `adr/cloudflare-zero-trust-v4.2.md`, `adr/den-framework-foundation.md`, `adr/distribution-strategy-v5.md` *(and 77 more)*
- **mynixos-v5**: `configuration.nix`, `docs/adr/ADR-003-Ejected-Services.md`, `docs/adr/ADR-008-SSH-ProxyJump-Standard.md`, `docs/adr/ADR-011-On-Demand-Services.md`, `docs/adr/ADR-012-Socket-Activation-Selection.md`, `docs/adr/ADR-017-Cloudflare-DNS-Only.md`, `docs/archive/adr/legacy/ADR-005-Hybrid-Identity-Model.md`, `docs/archive/adr/legacy/ADR-006-Secret-Management-Audit.md`, `docs/archive/adr/legacy/ADR_Chat_Destillat.md`, `docs/archive/adr/legacy/cloudflare-zero-trust-v4.2.md` *(and 106 more)*
- **nixos**: `docs/adr/ADR-00-core.md`, `docs/adr/ADR-10-network.md`, `docs/adr/ADR-20-security.md`, `docs/adr/ADR-30-storage.md`, `docs/adr/ADR-40-monitoring.md`, `docs/adr/ADR-50-media.md`, `docs/adr/ADR-60-apps.md`, `docs/adr/ADR-70-forge.md`, `docs/guides/00-core.md`, `docs/guides/10-network.md` *(and 92 more)*

#### 🔍 Term: `postgres`
- **mynixos**: `.legacy_folders/10-infrastructure/_imports.nix`, `00-core/registry.nix`, `20-infrastructure/postgresql.nix`, `20-infrastructure/_imports.nix`, `30-automation/service-app-n8n.nix`, `docs/SPEC_REGISTRY.md`, `README.md`
- **mynixos-knowledge-base**: `adr/ADR-009-Media-Stack-Consolidation.md`, `adr/impermanence-strategy-v4.2.md`, `adr/media-stack-philosophy.md`, `adr/nixhome-architecture.md`, `adr/software-purism-strategy.md`, `ADR-001-Lightweight-Identity-PocketID.md`, `arch-devenv.md`, `Claude-01-NixOS-Server-IaC-Setup.md`, `GEMINI.md`, `GUIDE-Aviation-Grade-Efficiency.md` *(and 20 more)*
- **mynixos-v5**: `configuration.nix`, `docs/adr/ADR-009-Media-Stack-Consolidation.md`, `docs/archive/adr/legacy/ADR_Chat_Destillat.md`, `docs/archive/adr/legacy/impermanence-strategy-v4.2.md`, `docs/archive/adr/legacy/media-stack-philosophy.md`, `docs/archive/adr/legacy/nixhome-architecture.md`, `docs/archive/adr/legacy/software-purism-strategy.md`, `docs/archive/ARCHITECTURAL_ANALYSIS_REPORT_PART2.md`, `docs/archive/audits/06-logging-monitoring.md`, `docs/archive/audits/Claude-Iterative Zero-Trust Code-Analyse für NixOS repo_v5.md` *(and 50 more)*
- **nixos**: `docs/adr/ADR-00-core.md`, `docs/adr/ADR-50-media.md`, `docs/adr/ADR-60-apps.md`, `docs/adr/ADR-70-forge.md`, `docs/guides/00-core.md`, `docs/guides/50-media.md`, `docs/guides/60-apps.md`, `docs/guides/70-forge.md`, `docs/SPEC_REGISTRY_METABIBLIOTHEK.md`, `hosts/laptop/configuration.nix` *(and 31 more)*

#### 🔍 Term: `wireguard`
- **mynixos**: `00-core/registry.nix`, `20-infrastructure/vpn-confinement.nix`, `40-media/service-media-_lib.nix`
- **mynixos-knowledge-base**: `adr/cloudflare-zero-trust-v4.2.md`, `adr/nixhome-architecture.md`, `adr/security-layer-model.md`, `Architecture-Cloudflare-Zero-Trust-Ingress.md`, `guides/MASTER-CONFIG-TAILSCALE.md`, `NixOS-Architecture-Master-Blueprint.md`, `pattern-nixarr.md`, `services/media-stack-hardening.md`, `services/service-infrastructure-vpn-confinement.md`
- **mynixos-v5**: `configuration.nix`, `docs/adr/ADR-003-Ejected-Services.md`, `docs/archive/adr/legacy/cloudflare-zero-trust-v4.2.md`, `docs/archive/adr/legacy/nixhome-architecture.md`, `docs/archive/adr/legacy/security-layer-model.md`, `docs/archive/ARCHITECTURAL_ANALYSIS_REPORT_PART3.md`, `docs/archive/audits/Claude-Iterative Zero-Trust Code-Analyse für NixOS repo_v5.md`, `docs/archive/audits/Grok-NixMeta Bash Feasibility Audit (1).md`, `docs/archive/audits/MCP_VALIDATION_REPORT.md`, `docs/archive/compress/ARCHITECTURAL_ANALYSIS_REPORT_PART3.md` *(and 17 more)*
- **nixos**: `docs/adr/ADR-10-network.md`, `docs/adr/ADR-50-media.md`, `docs/guides/50-media.md`, `modules/10-network/19-zigbee-stack.nix`, `modules/10-network/21-tailscale.nix`, `modules/10-network/21-vpn-confinement.nix`, `modules/10-network/26-wireguard-admin.nix`, `modules/50-media/52-download.nix`, `_fetch/kernel-hardening.nix`, `_fetch/registry.nix` *(and 9 more)*

#### 🔍 Term: `vpn`
- **mynixos**: `.legacy_folders/10-infrastructure/_imports.nix`, `00-core/configs.nix`, `00-core/registry.nix`, `10-gateway/tailscale.nix`, `20-infrastructure/vpn-confinement.nix`, `20-infrastructure/vpn-live-config.nix`, `20-infrastructure/_imports.nix`, `40-media/service-media-_lib.nix`, `docs/SPEC_REGISTRY.md`
- **mynixos-knowledge-base**: `00_MASTER_INDEX.md`, `adr/ADR-004-Media-Engine-VPN-Isolation.md`, `adr/cloudflare-zero-trust-v4.2.md`, `adr/media-stack-philosophy.md`, `adr/nixhome-architecture.md`, `Architecture-Cloudflare-Zero-Trust-Ingress.md`, `Architecture-Deep-Dive-Knowledge-Gems.md`, `caddy-forwardproxy.md`, `Claude-01-NixOS-Server-IaC-Setup.md`, `GEMINI.md` *(and 24 more)*
- **mynixos-v5**: `docs/adr/ADR-004-Media-Engine-VPN-Isolation.md`, `docs/adr/README.md`, `docs/archive/adr/legacy/ADR_Chat_Destillat.md`, `docs/archive/adr/legacy/cloudflare-zero-trust-v4.2.md`, `docs/archive/adr/legacy/media-stack-philosophy.md`, `docs/archive/adr/legacy/nixhome-architecture.md`, `docs/archive/ARCHITECTURAL_ANALYSIS_REPORT_PART3.md`, `docs/archive/audits/Claude-Iterative Zero-Trust Code-Analyse für NixOS repo_v5.md`, `docs/archive/audits/Grok-NixMeta Bash Feasibility Audit (1).md`, `docs/archive/audits/Grok-NixOS CI!CD Secrets Testing Overlays Containers Analysis.md` *(and 22 more)*
- **nixos**: `docs/adr/ADR-10-network.md`, `docs/adr/ADR-50-media.md`, `docs/guides/50-media.md`, `hosts/q958/configuration.nix`, `modules/00-core/01-configs-registry.nix`, `modules/00-core/04-registry.nix`, `modules/00-core/12-lib-helpers.nix`, `modules/10-network/19-zigbee-stack.nix`, `modules/10-network/21-tailscale.nix`, `modules/10-network/21-vpn-confinement.nix` *(and 14 more)*

#### 🔍 Term: `sops`
- **mynixos**: `00-core/secrets.nix`, `10-gateway/caddy.nix`, `10-gateway/dns-automation.nix`, `10-gateway/tailscale.nix`, `20-infrastructure/secret-ingest.nix`, `20-infrastructure/vpn-confinement.nix`, `30-automation/service-app-olivetin.nix`, `40-media/service-media-recyclarr.nix`, `50-knowledge/service-app-linkwarden.nix`, `50-knowledge/service-app-miniflux.nix` *(and 5 more)*
- **mynixos-knowledge-base**: `00_GOLDEN_HANDBOOK_Dendritic_NixOS.md`, `adr/ADR-004-Media-Engine-VPN-Isolation.md`, `adr/ADR-006-Secret-Management-Audit.md`, `adr/ADR-016-Sops-Boot-Timing.md`, `adr/backup-strategy-v4.2.md`, `adr/distribution-strategy-v5.md`, `adr/impermanence-strategy-v4.2.md`, `adr/nixhome-architecture.md`, `Architecture-3-Stage-Boot-Pipeline.md`, `best-of-nix.md` *(and 50 more)*
- **mynixos-v5**: `configuration.nix`, `docs/adr/ADR-016-Sops-Boot-Timing.md`, `docs/adr/ADR-018-Media-Stack-Architecture.md`, `docs/adr/README.md`, `docs/archive/adr/legacy/ADR-006-Secret-Management-Audit.md`, `docs/archive/adr/legacy/ADR_Chat_Destillat.md`, `docs/archive/adr/legacy/backup-strategy-v4.2.md`, `docs/archive/adr/legacy/distribution-strategy-v5.md`, `docs/archive/adr/legacy/impermanence-strategy-v4.2.md`, `docs/archive/adr/legacy/nixhome-architecture.md` *(and 76 more)*
- **nixos**: `docs/adr/ADR-00-core.md`, `docs/adr/ADR-10-network.md`, `docs/adr/ADR-20-security.md`, `docs/adr/ADR-60-apps.md`, `docs/guides/10-network.md`, `docs/guides/20-security.md`, `docs/guides/60-apps.md`, `flake.nix`, `Gemini.md`, `hosts/laptop/configuration.nix` *(and 64 more)*

#### 🔍 Term: `impermanence`
- **mynixos-knowledge-base**: `adr/ADR-016-Sops-Boot-Timing.md`, `adr/impermanence-strategy-v4.2.md`, `best-of-nix.md`, `GUIDE-Hygiene-Persistence.md`, `guides/GUIDE-Cloud-Storage-OCIS.md`, `guides/GUIDE-Paperless-Master-Config.md`, `Knowledge-Extraction-Third-Run.md`, `learnings/homelab-architecture-review.md`, `learnings/sre-audit-v4.2.md`, `MASTER-SOURCES.md` *(and 9 more)*
- **mynixos-v5**: `configuration.nix`, `docs/adr/ADR-016-Sops-Boot-Timing.md`, `docs/adr/ADR-018-Media-Stack-Architecture.md`, `docs/archive/adr/legacy/ADR_Chat_Destillat.md`, `docs/archive/adr/legacy/impermanence-strategy-v4.2.md`, `docs/archive/ARCHITECTURAL_ANALYSIS_REPORT.md`, `docs/archive/ARCHITECTURAL_ANALYSIS_REPORT_PART2.md`, `docs/archive/ARCHITECTURAL_ANALYSIS_REPORT_PART3.md`, `docs/archive/audits/02-impermanence-correction.md`, `docs/archive/audits/07-sops-tpm-recovery.md` *(and 45 more)*
- **nixos**: `docs/adr/ADR-30-storage.md`, `docs/guides/30-storage.md`, `docs/SPEC_REGISTRY_METABIBLIOTHEK.md`, `flake.nix`, `Gemini.md`, `hosts/laptop/README.md`, `hosts/q958/configuration.nix`, `hosts/q958/README.md`, `hosts/README.md`, `modules/30-storage/32-impermanence.nix` *(and 13 more)*

#### 🔍 Term: `mergerfs`
- **mynixos**: `00-core/registry.nix`, `00-core/storage.nix`, `docs/SPEC_REGISTRY.md`, `README.md`
- **mynixos-knowledge-base**: `00_GOLDEN_HANDBOOK_Dendritic_NixOS.md`, `adr/ADR-006-Storage-Cluster-Strategy.md`, `adr/nixhome-architecture.md`, `adr/storage-broker-hal-v4.2.md`, `adr/storage-tiering-strategy.md`, `guides/GUIDE-ABC-Storage-Tiering.md`, `guides/GUIDE-Pattern-Mining-Nixpkgs.md`, `guides/GUIDE-S3-Object-Vault-Garage.md`, `ironic-pms-bible.md`, `NixOS-Architecture-Master-Blueprint.md` *(and 1 more)*
- **mynixos-v5**: `docs/archive/adr/legacy/ADR-006-Storage-Cluster-Strategy.md`, `docs/archive/adr/legacy/nixhome-architecture.md`, `docs/archive/adr/legacy/storage-broker-hal-v4.2.md`, `docs/archive/adr/legacy/storage-tiering-strategy.md`, `docs/archive/ARCHITECTURAL_ANALYSIS_REPORT_PART3.md`, `docs/archive/audits/Grok-NixMeta Bash Feasibility Audit (1).md`, `docs/archive/audits/Grok-NixOS CI!CD Secrets Testing Overlays Containers Analysis.md`, `docs/archive/compress/ARCHITECTURAL_ANALYSIS_REPORT_PART3.md`, `docs/archive/compress/__compress_Bundle.md`, `docs/archive/obsidian_export/00-core.md` *(and 8 more)*
- **nixos**: `docs/adr/ADR-30-storage.md`, `modules/30-storage/34-storage-mover.nix`, `_fetch/registry.nix`, `_fetch/storage.nix`, `_fetch/v5-core-storage-policy.nix`, `_fetch/v5-core-storage.nix`

#### 🔍 Term: `zfs`
- **mynixos-knowledge-base**: `00_GOLDEN_HANDBOOK_Dendritic_NixOS.md`, `adr/ADR-006-Storage-Cluster-Strategy.md`, `adr/backup-strategy-v4.2.md`, `adr/hardware-spec-q958.md`, `adr/storage-tiering-strategy.md`, `GUIDE-Hygiene-Persistence.md`, `GUIDE-Perfect-Media-Server-Architecture.md`, `GUIDE-Stick-Ready-NixOS-Deployment.md`, `guides/GUIDE-ABC-Storage-Tiering.md`, `guides/GUIDE-Future-Storage-Scaling.md` *(and 12 more)*
- **mynixos-v5**: `docs/adr/ADR-018-Media-Stack-Architecture.md`, `docs/archive/adr/legacy/ADR-006-Storage-Cluster-Strategy.md`, `docs/archive/adr/legacy/ADR_Chat_Destillat.md`, `docs/archive/adr/legacy/backup-strategy-v4.2.md`, `docs/archive/adr/legacy/hardware-spec-q958.md`, `docs/archive/adr/legacy/storage-tiering-strategy.md`, `docs/archive/audits/Grok-NixMeta Bash Feasibility Audit (1).md`, `docs/archive/compress/ADR_Chat_Destillat.md`, `docs/archive/compress/ADR_Chat_Destillat_1.md`, `docs/archive/compress/__compress_Bundle.md` *(and 7 more)*
- **nixos**: `docs/adr/ADR-30-storage.md`, `docs/guides/30-storage.md`, `modules/30-storage/30-storage.nix`, `modules/30-storage/31-backup.nix`, `modules/30-storage/32-impermanence.nix`, `modules/30-storage/33-storage-policy.nix`

#### 🔍 Term: `homeassistant`
- **mynixos**: `00-core/registry.nix`, `10-gateway/dns-map.nix`, `20-infrastructure/service-app-zigbee-stack.nix`, `30-automation/service-app-home-assistant.nix`
- **mynixos-knowledge-base**: `ironic-auto-awesome-home-assistant.md`, `Services-MCP-Integrations-HA-Unraid.md`
- **mynixos-v5**: `docs/archive/audits/Claude-Iterative Zero-Trust Code-Analyse für NixOS repo_v5.md`, `modules/apps/service-app-home-assistant.nix`, `modules/core/registry.nix`, `modules/services/dns-map.nix`, `modules/services/service-app-zigbee-stack.nix`
- **nixos**: `docs/guides/60-apps.md`, `modules/00-core/01-configs-registry.nix`, `modules/00-core/03-ports.nix`, `modules/10-network/24-dns-map.nix`, `_fetch/registry.nix`, `_fetch/v5-apps-correct-service-app-home-assistant.nix`, `_fetch/v5-apps-service-app-home-assistant.nix`, `_fetch/v5-services-dns-map.nix`, `_fetch/v5-services-service-app-zigbee-stack.nix`, `_fetch/v5-svc-dns-map.nix` *(and 1 more)*

#### 🔍 Term: `mosquitto`
- **mynixos**: `20-infrastructure/service-app-zigbee-stack.nix`
- **mynixos-knowledge-base**: `adr/nixhome-architecture.md`, `GUIDE-Home-Assistant-Blueprint.md`, `guides/GUIDE-Radar-Services-Master-Config.md`, `guides/MASTER-HA-INTERFACES.md`, `ironic-auto-awesome-home-assistant.md`, `services/service-automation-home-assistant.md`, `services/service-infrastructure-zigbee.md`
- **mynixos-v5**: `docs/archive/adr/legacy/nixhome-architecture.md`, `docs/archive/__archive_Bundle.md`, `docs/guides/15-iot-services.md`, `modules/core/uid-registry.nix`, `modules/services/service-app-zigbee-stack.nix`
- **nixos**: `docs/adr/ADR-10-network.md`, `docs/guides/10-network.md`, `modules/00-core/01-configs-registry.nix`, `modules/00-core/14-uid-registry.nix`, `_fetch/v5-core-extra-uid-registry.nix`, `_fetch/v5-services-service-app-zigbee-stack.nix`, `_fetch/v5-svc-service-app-zigbee-stack.nix`


---

## 4. Proposed Refinement & Integration Plan

Based on the repository scanning, here are the target directories and files to extract:

1. **Compare homeassistant/mosquitto configurations:** Verify if there are direct Nix declarations for Home Assistant or MQTT broker configurations in `nixos` or `mynixos-v5` that we should merge into `60-apps.nix`.
2. **Verify Caddy Gateway parameters:** Check if `mynixos-v5` has customized reverse proxy setups or TLS credentials that we missed in `60-apps.nix`.
3. **Storage & MergerFS parameters:** Check for any specific udev rules or systemd mount scripts in the external repos.

