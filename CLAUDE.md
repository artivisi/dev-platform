# CLAUDE.md — development-environment (the platform)

Read before any work in this repo.

## What this repo is

The **platform**: hardware tiers, the Ansible that provisions a box, the three
documents, and the tooling. It is organisation-agnostic and intended to be
readable by anyone — including as training material.

It holds **no fleet**. Each organisation keeps a private *deployment repository*
with its own inventory, and pulls this one in as a git submodule pinned to a
commit. `example-deployment/` is the skeleton. Boxes run `ansible-pull` against
their deployment repository, so the platform version a box runs is whatever that
deployment has adopted — one organisation can lag another safely.

## Hard rules

- **Nothing here names an organisation.** No hostnames, addresses, people,
  projects, or engagement details — not in the docs, not in the inventory, not
  in a comment. Those belong to a deployment repository. If a change seems to
  need one, either the change belongs in a deployment, or it belongs here in a
  general form. Worked examples use invented names.
- **No inventory here.** `ansible/group_vars/` holds the tier definitions and
  the platform constants a deployment must not override; everything else —
  `hosts.ini`, `host_vars/`, the roster — lives in the deployment.
- **No fallbacks, no default values** in any script, config, or playbook —
  shown in the docs or shipped in `ansible/`. A missing prerequisite is a hard
  failure with a clear error, not a silent default. In Ansible this means no
  substantive `defaults/main.yml`: required variables are asserted in the
  `preflight` role and the run stops before anything is changed.
- Plain technical register. No marketing language, no bloated or repetitive
  content.

## Document structure

Three documents, one per audience, split at two hand-off points — **the OS
boots** and **the developer logs in**:

- `hardware/spec.typ` — capacity model and build tiers 0–3, plus per-class
  commissioning runbooks that end when the OS boots. Anything after first boot
  is not hardware: hardware-conditional software settings are declared in the
  box's `host_vars` (`dev_lid_ignore`, `dev_mbpfan`,
  `dev_kernel_module_blacklist`, `dev_docker_data_root`,
  `dev_network_optional_interfaces`, `dev_kdump_enabled`) and applied by the
  playbook. Per-tier enforcement values render from
  `ansible/group_vars/tier*.yml` via `shared/capacity.typ` — never retype them.
- `setup/guide.typ` — provisioning and operations, universal across tiers.
  Written as one section per Ansible role: what, why, inventory values,
  verify. It **explains** the roles; it does not reproduce them. Shell only
  where the reader would type it (verify, diagnose). User management is a git
  workflow (roster PR + placement); removal deletes home and the guide says so.
- `workflow/guide.typ` — the developer's guide, identical on every tier. No
  tier mention beyond one paragraph pointing at the hardware capacity card.
  Covers what the account comes with and what the developer brings (own Claude
  login, own runtimes through managers, own credentials in `$HOME`).

Keep the split when editing. Workflow drifting into hardware, a machine number
drifting into the developer guide, or setup shell drifting into either defeats
the reason for the split. The shared unit is the **seat**; any capacity number
must derive from `hardware/spec.typ`'s sizing primitives.

## Toolchain

- Documents are Typst, built with `./build.sh` (invokes `typst --root .` so
  documents can import `/shared/...`, `/template/...` and read `/ansible/...`).
- **Always eyeball the rendered pages after compiling** — render to images and
  check every page. Layout defects like caption misclassification and diagram
  label collisions do not show up as compile errors.
- Compiled PDFs are committed alongside their sources; regenerate in the same
  commit as any source change.

## Template

- `template/lib.typ` — ArtiVisi brand template (indigo `#2e3192`, green
  `#58c034`, logo assets in `template/assets/`). The template's chrome
  defaults to Indonesian (badge SPESIFIKASI TEKNIS, label DISIAPKAN UNTUK) for
  other ArtiVisi documents; these English documents pass `badge:` and
  `prepared-for-label:` in English. Content, filenames, and cover metadata are
  English throughout.
- `shared/blocks.typ` — layout primitives (`cell`, `darr`, `code-blocks`,
  `transcript`) used by all documents.
- `shared/capacity.typ` — the capacity tables, the per-machine
  `capacity-card`, and `tier-limits` (reads the Ansible tier YAML). Every
  hardware claim renders from here.
- Diagrams are **mermaid**, one `.mmd` per diagram under `<doc>/diagrams/`,
  rendered to `.png` by `build.sh` and committed beside the source — the same
  arrangement as the compiled PDFs. Typst cannot read mermaid directly; the
  render goes through `mmdc`, pointed at the system Chrome by
  `scripts/puppeteer-config.json`. Only someone *changing* a diagram needs
  `mmdc` installed; everyone else builds from the committed PNGs. Chosen over
  drawing natively so that people who do not know Typst can edit the pictures,
  and so GitHub renders them in the browser.
- `build.sh` re-renders a diagram only when its `.mmd` is newer than its `.png`,
  and fails loudly if the tool or the browser is missing — a silently skipped
  diagram means a document that builds successfully with a stale picture in it.
- fletcher (`@preview/fletcher`) is still imported for the odd inline
  node/edge graph, and nested `cell` grids for layered architecture.

## Ansible

- `ansible/site.yml` is what the Setup Guide describes. When a role changes,
  the guide's section for that role changes in the same commit.
- Boxes provision themselves with `ansible-pull` on a timer (`pull` role);
  push is for first run and "now". `main` is production — a merge deploys to
  every box. Test on the droplet first.
- Inventory: roster `dev_people` in `group_vars/all.yml` (public keys only);
  placement `dev_users` / `dev_users_absent` in `host_vars/<hostname>.yml`;
  tier by group in `hosts.ini`. Secrets (WireGuard config, ntfy URL, E2E
  projects) live only on the box in `/etc/dev-platform/host.yml`, passed with
  `-e @` for push. Nothing secret in git — every box holds a checkout.
- Preflight enforces: every required variable, exactly one tier group,
  inventory name == hostname, roster/placement consistency, RAM vs tier,
  Ubuntu + systemd + cgroup v2, ext4 for quotas, deploy key and `host.yml`
  present when pull is on. Assert properties, never a release string.
- The playbook installs version *managers* per user, never runtimes.
  Subordinate UID ranges derive from the UID, never from list position.
- Test with `ansible/test/{provision,run,destroy}.sh` on the smallest droplet
  that survives provisioning; `run.sh` asserts `changed=0` on re-runs, a
  self-provisioning pull run, and clean add/remove. Always destroy afterwards.

## Deployments

- One deployment repository per organisation. It contains `inventory/`, a
  `site.yml` of one `import_playbook` line, an `ansible.cfg` pointing at the
  submodule's roles, and nothing else. `example-deployment/` is the template.
- A change here reaches a fleet only when that deployment moves its submodule
  pointer. That is the upgrade, and it is deliberate — never assume a fleet is
  running `main`.
- `scripts/access` and `hub/wg-*-peer` are run from a deployment checkout
  against its inventory. They live here because they are platform tooling; the
  data they edit is the deployment's.

## Git

- Commit and push straight to `main`. Single maintainer today.
- When a role changes, the Setup Guide's section for that role changes in the
  same commit, and the PDFs are rebuilt in it too.
