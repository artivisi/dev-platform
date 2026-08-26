# WireGuard hub

One per deployment. The platform does not run a hub; it documents how to.

The platform's `wireguard` role installs a *client* config on a box from
`dev_wireguard_config`. It does not build the hub and it does not issue peers for
people's laptops. This directory is that missing half.

## Where it runs

Any host with a public address and a stable name. A small VPS is plenty:
WireGuard is in-kernel, so a hub costs no resident memory, which matters if you
are putting it on a machine that already earns its keep.

Plain `wg-quick`, deliberately, and not wg-easy or another web UI: an interface
that can mint peers is the keys to the whole network, and one reachable from the
internet is an open door. Peers are added over SSH, so root on the hub is the
only thing that can issue them.

Plain `wg-quick`, deliberately, not wg-easy: WireGuard is in-kernel, so a hub
costs no resident memory, which matters on a host with well under a gigabyte free
and no swap. wg-easy would add a Node process and an administrative web UI —
another thing to keep off the internet — to mint a handful of peers a year.

## Addressing

Pick a `/24` and stick to it. Hub `.1`, people `.2`–`.9`, boxes `.10`–`.254`.

Choose a subnet no other hub your people connect to is using. Someone with a
peer on two hubs cannot bring both up if the ranges collide, and the collision
presents as one tunnel mysteriously not working. The person/box split means an
address says what it is without a lookup.

Peers get `AllowedIPs` of the hub subnet only — never `0.0.0.0/0`. Nothing routes its default
through the hub, so there is no NAT here and nothing depends on `iptable_nat`.

## Two things this host needed, which are not obvious

- **`ufw` is active** with `INPUT` policy `DROP`. `51820/udp` must be opened
  explicitly (`ufw allow 51820/udp`) or handshakes fail silently — the client
  shows a sent handshake and nothing received, which reads like a wrong key.
  Note that `ufw status` without `sudo` prints *nothing at all* rather than
  refusing, which is an easy way to convince yourself the firewall is off.
- **`FORWARD` policy is `DROP`.** Peers reach the hub without any rule, but not
  each other. This is provided by ufw, not by `PostUp`, precisely because ufw
  owns that chain:

  ```bash
  ufw route allow in on wg0 out on wg0
  ```

  A rule appended straight to `FORWARD` with `iptables` works until something
  rebuilds the chain, and then peer-to-peer stops with the tunnels still showing
  healthy handshakes. Keep the single ufw-managed rule; do not add a `PostUp`
  duplicate.

  This only holds while ufw is *enabled as a service*. `ufw disable` — run
  once, by anyone, for any reason — leaves the rules in `/etc/ufw/user.rules`
  but nothing loads them at boot, and the next reboot produces exactly the
  symptom above: every peer handshakes, the hub answers ping, peers cannot
  reach each other. Check `systemctl is-enabled ufw` (must say `enabled`),
  and after any change to the hub, **reboot it and confirm a laptop can ssh
  to a box over the tunnel** — that is the only test that proves persistence.
  On a hub that also runs Docker, `FORWARD` policy `DROP` comes from Docker
  too, so with ufw off the drop is silent and total.

## Adding a peer

```bash
sudo wg-add-peer <name> --person        # or --box
```

It allocates the next free address in the right range, generates a preshared
key, appends the peer, applies with `wg syncconf` so live tunnels are not
dropped, and prints the client config on stdout. Redirect it to a file with a
restrictive umask — it contains a private key — and delete the file once the
person has imported it.

By default the hub generates the keypair, so the hub sees the private key. That
is the right trade when handing a colleague a file to import. For anything
long-lived, have the peer run `wg genkey`, keep the private half, and pass only
the public half:

```bash
sudo wg-add-peer <name> --person --pubkey '<base64>'
```

## Removing a peer

```bash
sudo wg-remove-peer <name>
```

Applied with `wg syncconf`, so other tunnels are not dropped. Keep a sense of
proportion about what this achieves on its own: it removes network reach, not
the key. A lost laptop also needs the key out of the roster and off the person's
GitHub account — the Setup Guide's revocation section has the full sequence and
the order to do it in.

The endpoint written into every config comes from `/etc/wireguard/endpoint`. The
script fails rather than guessing if that file is missing, because a peer config
with a wrong endpoint fails in a way that looks like a key problem.

## Open items

- **DNS**: give the hub a name and point `/etc/wireguard/endpoint` at it, so a
  renumbered host does not invalidate every peer config at once. If the zone is
  behind Cloudflare the record must be **DNS-only (grey cloud)**. It
  must stay that way: WireGuard is UDP and Cloudflare's proxy carries only
  HTTP/HTTPS, so switching it to proxied would send handshakes to anycast IPs and
  look like a WireGuard fault rather than a DNS one.

  Depending on a name has a cost — if it will not resolve, the tunnel will not
  start. On Linux `wg-quick@` orders itself `After=nss-lookup.target`, and
  a box with more than one resolver is covered — verify it across a reboot
  before relying on it. On macOS the client resolves at activation and can fail
  there, so keep the hub's address in mind as the manual fallback.
- A VPN peer is **not** an account. Reaching a box and being able to log into it
  are separate: accounts come from `dev_people` plus `dev_users` in the box's
  `host_vars`, applied by the playbook.

# ntfy

Same host. `https://ntfy.example.org`, nginx on 443 proxying to ntfy on
`127.0.0.1:2586`, Let's Encrypt cert on the existing `certbot.timer`.

Boxes post provisioning and standing-loop failures to the `dev-fleet` topic. The
`pull` role bakes `dev_ntfy_url` into the `OnFailure=` unit, so the credential
lives in each box's `/etc/dev-platform/host.yml` and never in git.

## Why it is public rather than VPN-only

It began VPN-only, which was simpler and needed no DNS or TLS. The problem is
what alerting is for: a VPN-only endpoint cannot tell you that the VPN is down,
and it cannot reach a phone that is not connected. Public with authentication
inverts both.

## Access

`auth-default-access: deny-all` — nothing is anonymous, verified 403 for publish
and read from off-network.

| User | Role | Access |
|---|---|---|
| `endy` | admin | read-write on every topic; this is what a phone subscribes as |
| `fleet` | user | **write-only** on `dev-fleet` |

`fleet` is write-only on purpose. A box that is compromised should be able to
report its own failure and learn nothing about the rest of the fleet.

Add a user, then grant:

```bash
sudo NTFY_PASSWORD=... ntfy user add --role=user someone
sudo ntfy access someone dev-fleet write-only     # or read-write for a person
```

## Two settings that are not optional

- **`behind-proxy: true`.** Without it every request looks like `127.0.0.1` and
  ntfy's rate limiter treats the whole internet as one visitor.
- **`proxy_buffering off`, WebSocket upgrade headers, and a long
  `proxy_read_timeout` in the vhost.** Subscribers hold long-lived streaming
  connections; miss any of the three and notifications arrive late or not at
  all. For the same reason the vhost carries no `limit_req` — nginx rate
  limiting would sever those streams. ntfy does its own, protocol-aware.

The DNS record is `A ntfy.<your-zone> → <hub address>`, DNS-only. Proxying it would
be less catastrophic than for `vpn` (this is HTTP, so it would work) but
Cloudflare's buffering and idle timeouts fight the streaming connections.
