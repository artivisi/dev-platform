# development-environment

ArtiVisi internal documentation for development infrastructure — the hardware
tiers, the playbook that provisions them, and the workflow developers run on
them. Documents here are genericized (no client or engagement references) so
they can be shared directly with infra staff and vendors.

## Structure

Three documents, one per audience, split at two hand-off points:

| Path | Audience | Contents |
|---|---|---|
| `hardware/spec.typ` | People who buy, assemble, triage | Capacity model (sizing primitives → seats), build tiers 0–3, per-hardware-class runbooks **up to the OS booting**, and the per-tier values the playbook writes into a box (rendered from `ansible/group_vars/tier*.yml`) |
| `setup/guide.typ` | People who provision and operate boxes | How a box provisions itself (`ansible-pull`) or is pushed to; what lives where (roster, placement, secrets); user management as a git workflow; one section per Ansible role — what, why, inventory values, verify; troubleshooting; the droplet harness. **Universal across tiers.** |
| `workflow/guide.typ` | Developers with an account | What you get and what you bring (own Claude login, own runtimes via managers, own credentials); limits and how to read them; folder conventions, caches, ports; agent workflow, tmux session model, juggling; standing E2E loops; what does not run here. **Identical on every tier** — a tier changes how many people and stacks fit, never the workflow. |
| `ansible/` | — | The playbook the Setup Guide describes: `site.yml`, roles, inventory (roster + placement + tiers), `host.yml.example` for per-box secrets, `inventory-check.yml` for CI, and the DigitalOcean harness under `test/` |
| `shared/` | — | Typst modules imported by the documents — layout primitives and the capacity tables |
| `template/` | — | ArtiVisi Typst template (brand palette + logo); English cover chrome via `badge:` / `prepared-for-label:` |

The unit shared by all three is the **seat**: one developer actively working.
Hardware says how many seats a box has; setup enforces the seat's ceilings;
the developer guide says what a seat does.

## Build

```bash
./build.sh
```

Documents import shared modules by root-relative path and the hardware
document reads the Ansible tier files, so `typst` is always invoked with
`--root .`. Typst downloads the `fletcher` diagram package on first compile.

Always eyeball the rendered pages after compiling — caption misclassification
and diagram label collisions are not compile errors.

## Provisioning

Boxes provision themselves: each runs `ansible-pull` against this repository
on a timer. Adding a developer is a pull request to the roster
(the deployment's `inventory/group_vars/all.yml`) plus a name in the box's
`host_vars`; removing one is moving the name to `dev_users_absent`. Push from
a laptop is used for a box's first run and for "now":

```bash
cd ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/hosts.ini -e @/path/to/<hostname>.yml site.yml
```

`-e @…` is the box's secrets file (WireGuard config, ntfy URL, E2E projects)
— on the box it lives at `/etc/dev-platform/host.yml`, never in git. See
`ansible/host.yml.example` and the Setup Guide.

No role carries fallback values. The `preflight` role asserts every required
variable and fails the run before anything is changed. `inventory-check.yml`
runs the roster and placement subset of those assertions in CI, so a bad pull
request fails there rather than on every box.

### Testing against a throwaway droplet

```bash
cd ansible
export DO_SSH_KEY_ID=<id from `doctl compute ssh-key list`>
export DEV_TEST_PUBKEY=$HOME/.ssh/id_rsa.pub
./test/provision.sh && ./test/run.sh && ./test/destroy.sh
```

`run.sh` proves, in order: push provisioning passes `verify.yml`; a re-run is
`changed=0`; the droplet provisions *itself* by `ansible-pull` with
`changed=0`; removing one account and adding another leaves a surviving
user's running container untouched; the churn re-run is `changed=0`. It
verifies mechanism, not capacity — `s-1vcpu-2gb` is the smallest droplet that
survives its own provisioning. Destroy the droplet when finished; nothing else
reclaims it.

## Conventions

See [CLAUDE.md](CLAUDE.md): genericization is a hard rule, no fallbacks or
default values anywhere, PDFs are committed alongside their sources, plain
technical register throughout.
