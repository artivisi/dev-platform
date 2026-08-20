// The capacity model — the one place hardware is turned into a number of seats.
//
// Every machine document declares its tier by calling `capacity-card(...)`.
// The tables themselves are rendered once, in the hardware specification.
//
//   #import "/shared/capacity.typ": capacity-card, sizing-primitives, ram-tiers

#import "/template/lib.typ": brand-blue, panel, slate

// ---------------------------------------------------------------------------
// Sizing primitives — every capacity number in this repo derives from these.
// Figures are resident set size under a Spring Boot + Postgres profile,
// measured on a running box, rounded up.
// ---------------------------------------------------------------------------

#let sizing-primitives() = table(
  columns: (1fr, auto, 1.4fr),
  align: (left, right, left),
  table.header([Item], [Resident], [Multiplicity]),

  table.cell(colspan: 3, fill: panel)[*Fixed host overhead*],
  [Ubuntu Server, headless (`multi-user.target`)], [0,7 GB], [per box],
  [Rootless Docker daemon], [0,2 GB], [*per active user*],
  [Registry pull-through mirror], [0,2 GB], [per box, if hosted],

  table.cell(colspan: 3, fill: panel)[*Per seat* — one developer actively working],
  [Claude Code session], [0,6–1,5 GB], [per seat, grows with context],
  [Running application JVM (512 MB heap)], [1,2 GB], [per seat],
  [Build: Maven launcher + forked surefire JVM], [2,0 GB], [per seat, transient],

  table.cell(colspan: 3, fill: panel)[*Per stack* — the services one project needs],
  [Minimal — app + Postgres], [1,5 GB], [per stack],
  [Light — app + Postgres + Redis or one broker], [3,0 GB], [per stack],
  [Full — apps + 3-broker Kafka + Oracle + monitoring], [10–12 GB], [per stack],
)

// ---------------------------------------------------------------------------
// Seat budget
// ---------------------------------------------------------------------------

#let seat-budget() = [
  A *seat* is one developer working: a Claude Code session, an application
  running, and a build that may fire at any moment. Peak and steady state
  differ by the build, and the build is what sizing must survive:

  #table(
    columns: (1fr, auto, auto),
    align: (left, right, right),
    table.header([Seat state], [Components], [Total]),
    [Steady — app running, agent thinking], [1,2 + 1,0], [2,2 GB],
    [Peak — build in flight alongside the app], [1,2 + 2,0 + 1,0], [4,2 GB],
    [Peak, sequenced — build replaces the app], [2,0 + 1,0], [3,0 GB],
  )

  Budget *5 GB per concurrent seat* against peak, plus that seat's stack. A
  seat on a light stack therefore costs 5 + 3 = *8 GB*. _Sequenced_ means the
  developer never builds while the application runs — a real discipline on
  small boxes, and the difference between one seat fitting and not fitting.
]

// ---------------------------------------------------------------------------
// RAM tiers — the primary constraint
// ---------------------------------------------------------------------------

#let ram-tiers() = table(
  columns: (auto, auto, auto, auto, 1.5fr),
  align: (right, right, center, center, left),
  table.header([RAM], [Usable], [Seats], [Full stacks], [What this tier is for]),
  [8 GB],   [7,1 GB],   [1 sequenced], [0], [Standing E2E loop runner. One seat only if it never builds and runs at once. Not multiuser.],
  [16 GB],  [14,9 GB],  [1 comfortable \ 2–3 light], [1], [One seat on the sizing profile above. Two or three seats only where the work is lighter than that profile — site maintenance, docs, interpreted runtimes.],
  [32 GB],  [30,5 GB],  [2–3], [2], [The entry tier for real multiuser work.],
  [64 GB],  [61,9 GB],  [5–7], [4–5], [Team box or heavy single-user stacks.],
  [128 GB], [125,7 GB], [12+ \ (CPU-capped first)], [6–8], [Primary workstation. RAM stops being the binding constraint.],
)

// ---------------------------------------------------------------------------
// CPU tiers — caps concurrent builds, not stack count
// ---------------------------------------------------------------------------

#let cpu-tiers() = table(
  columns: (1.4fr, auto, auto, 1.3fr),
  align: (left, center, center, left),
  table.header([Class], [Cores/threads], [Concurrent builds], [Note]),
  [Dual-core mobile (Broadwell-U)], [2c/4t], [1], [Build and agent contend on the same two cores.],
  [Quad mobile (Haswell-H)], [4c/8t], [1–2], [Thermally limited before it is core-limited.],
  [Quad desktop, no HT (Haswell)], [4c/4t], [2], [Higher sustained clock than its mobile counterpart.],
  [Quad desktop, HT (Haswell)], [4c/8t], [2–3], [],
  [16-core desktop (Zen 5)], [16c/32t], [6–8], [Homogeneous cores — no scheduling jitter.],
)

// ---------------------------------------------------------------------------
// Disk tiers — a gate, then a throughput cap
// ---------------------------------------------------------------------------

#let disk-tiers() = table(
  columns: (1.2fr, auto, auto, 1.4fr),
  align: (left, center, center, left),
  table.header([Media], [Verdict], [Concurrent builds], [Note]),
  [Spinning HDD], [*Disqualified*], [0], [Docker overlay churn and Maven writes make this unusable at any RAM.],
  [SATA SSD], [Minimum], [2], [≈550 MB/s. Adequate; page cache matters more here than on NVMe.],
  [NVMe Gen3], [Good], [4], [],
  [NVMe Gen4, single], [Good], [6], [],
  [NVMe Gen4, split OS/Docker], [Full], [8+], [Overlay churn and volume I/O leave the OS disk entirely.],
)

// ---------------------------------------------------------------------------
// Disk space, per box
// ---------------------------------------------------------------------------

#let disk-space() = table(
  columns: (1fr, auto),
  align: (left, right),
  table.header([Consumer], [Budget]),
  [Ubuntu Server + toolchains], [20 GB],
  [Per user: rootless image store (no sharing between users)], [25 GB],
  [Per user: dependency caches (`~/.m2`, pnpm store, uv, Composer)], [10 GB],
  [Per user: worktrees and their build output], [5 GB],
  [Registry mirror data, if hosted], [30 GB],
)

// ---------------------------------------------------------------------------
// Per-machine capacity card. Every machine document opens with one.
// ---------------------------------------------------------------------------

#let capacity-card(
  cpu: none,
  threads: none,
  ram: none,
  disk: none,
  seats: none,
  stacks: none,
  builds: none,
  binding: none,
) = {
  // `fill: none` and `stroke: none` are set explicitly on both tables: the
  // document template carries a `set table(...)` rule that shades row zero as a
  // header, which would otherwise tint the first line of every card.
  let row(label, value, bold: false) = (
    text(fill: slate, size: 8.5pt)[#label],
    if bold { text(size: 8.5pt, weight: "bold")[#value] } else { text(size: 8.5pt)[#value] },
  )

  block(
    stroke: 1pt + brand-blue, radius: 4pt, width: 100%, inset: 0pt,
    breakable: false, above: 0.9em, below: 0.9em,
  )[
    #block(fill: brand-blue, width: 100%, inset: (x: 8pt, y: 4pt))[
      #text(size: 9pt, weight: "bold", fill: white)[Capacity declaration]
    ]
    #block(inset: (x: 8pt, y: 6pt), width: 100%)[
      #table(
        columns: (auto, 1fr, auto, 1fr),
        stroke: none,
        fill: none,
        inset: (x: 4pt, y: 2.5pt),
        align: (left, left, left, left),
        ..row([CPU], cpu), ..row([Threads], threads),
        ..row([RAM], ram), ..row([Disk], disk),
      )
      #v(3pt)
      #line(length: 100%, stroke: 0.4pt + rgb("#cbd5e1"))
      #v(3pt)
      #table(
        columns: (auto, 1fr, auto, 1fr),
        stroke: none,
        fill: none,
        inset: (x: 4pt, y: 2.5pt),
        align: (left, left, left, left),
        ..row([Concurrent seats], seats, bold: true),
        ..row([Concurrent builds], builds, bold: true),
        ..row([Stacks], stacks, bold: true),
        ..row([Binding constraint], binding, bold: true),
      )
    ]
  ]
}

// ---------------------------------------------------------------------------
// Per-tier enforcement values, read straight from the Ansible tier files so
// the document cannot drift from what the playbook writes into the box.
// ---------------------------------------------------------------------------

#let tier-limits() = {
  let tiers = (
    ("0", "Salvage", "tier0_salvage"),
    ("1", "Compact", "tier1_compact"),
    ("2", "Salvage, upgraded", "tier2_upgraded"),
    ("3", "Mid-range build", "tier3_mid"),
    ("4", "Primary workstation", "tier4_primary"),
  )
  table(
    columns: (auto, 1fr, auto, auto, auto, auto, auto),
    align: (center, left, right, right, right, right, right),
    table.header([Tier], [Group], [Min RAM], [`MemoryHigh`], [`MemoryMax`], [`TasksMax`], [Quota soft / hard]),
    ..tiers.map(((n, name, group)) => {
      let v = yaml("/ansible/group_vars/" + group + ".yml")
      (
        [#n], [#name \ #text(size: 8pt, fill: slate, raw(group))],
        [#calc.round(v.dev_tier_min_ram_mb / 1000, digits: 0) GB],
        raw(v.dev_user_memory_high), raw(v.dev_user_memory_max),
        raw(str(v.dev_user_tasks_max)),
        // A tier may switch quotas off; the values are then absent from the
        // file rather than set to something meaningless, so read the flag.
        if v.dev_quota_enabled {
          [#raw(v.dev_user_quota_soft) / #raw(v.dev_user_quota_hard)]
        } else { [off] },
      )
    }).flatten()
  )
}
