# Example deployment

A deployment repository holds *one organisation's* fleet and nothing else. The
platform — roles, playbook, documents, tooling — lives once, in
`artivisi/development-environment`, and arrives here as a git submodule pinned
to a commit.

Copy this directory to a new private repository, one per organisation, and fill
it in.

```
platform/                     git submodule -> the platform, pinned
inventory/hosts.ini           your boxes, by name and VPN address
inventory/group_vars/all.yml  your people, your timezone, your repository
inventory/host_vars/<box>.yml who is on each box, and its hardware facts
site.yml                      one line: import the platform's playbook
ansible.cfg                   points Ansible at the submodule's roles
```

## Setting one up

```bash
git init && git submodule add git@github.com:artivisi/development-environment.git platform
cp -r platform/example-deployment/. .
# edit inventory/, then:
git add -A && git commit -m "Initial fleet" && git push
```

## Why a submodule rather than a copy

A copy drifts, and two fleets running subtly different roles is the failure this
split exists to prevent. The submodule pins an exact platform commit, so an
upgrade is a deliberate act with a diff to read:

```bash
git submodule update --remote platform
git -C platform log --oneline HEAD@{1}..HEAD    # what you are about to adopt
git add platform && git commit -m "Adopt platform <version>"
```

One organisation can sit on an older platform than another, safely and visibly.

## What must never be here

Credentials of any kind. Every box in this repository holds a full checkout of
it, so anything committed here is readable from every box listed in it. Per-box
secrets live on the box in `/etc/dev-platform/host.yml`, mode 0600.

## What must never be in the platform

Anything naming this organisation: hostnames, addresses, people, projects. If
you find yourself editing the submodule to make something work here, the change
belongs in the platform in a general form, or here in a specific one — not in a
local edit to a shared repository.
