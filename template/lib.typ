// ArtiVisi proposal template
//
// Usage from a sibling folder (e.g. ../bsi-ai-islamic-ecosystem/PROPOSAL.typ):
//
//   #import "../_template/artivisi-proposal.typ": proposal
//
//   #show: proposal.with(
//     title: "Workshop Penggunaan AI",
//     subtitle: "untuk Islamic Ecosystem Business Development",
//     client: "PT Bank Syariah Indonesia, Tbk",
//     client-detail: "Islamic Ecosystem Business Development",
//     date: "19 Mei 2026",
//     reference: "AVI-2026-05-19-BSI-001",
//     metadata: (
//       ("Tipe Engagement", "Workshop (full-day onsite)"),
//       ("Durasi",          "1 hari · 6 jam efektif"),
//       ("Peserta",         "15–25 orang"),
//       ("Instruktur",      "Endy Muhardin"),
//     ),
//   )
//
//   = 1. Latar Belakang
//   ...
//
// Body uses standard Typst markup: `=` headings, `*bold*`, `_italic_`,
// `#table(...)`, `#image(...)`, `#link(...)`, etc.

// ----- Palette (ArtiVisi brand) ----------------------------------------------
// Primary: indigo #2e3192 — letters and underline in the official logo
// Accent : kelly green #58c034 — the swoosh over the V in the logo

#let brand-blue  = rgb("#2e3192")
#let brand-green = rgb("#58c034")

// Functional tokens derived from / complementing the brand pair
#let blue-deep   = rgb("#1f2272")  // a darker shade for header chrome
#let blue-tint   = rgb("#eef0f9")  // very light indigo wash, table headers
#let cream       = rgb("#f8f7fa")  // page panel / callout fill
#let slate       = rgb("#4b5563")
#let muted       = rgb("#9ca3af")
#let border      = rgb("#cbd5e1")
#let panel       = blue-tint

// Backwards-compatible aliases used throughout the template body
#let navy = brand-blue
#let gold = brand-green

// ----- Reusable helpers (exported) -------------------------------------------

// Highlighted total row for budget tables.
#let total-row(..cells) = {
  cells.pos().map(c => table.cell(fill: panel, [*#c*]))
}

// Subtle callout box.
#let note(body) = block(
  fill: cream,
  stroke: (left: 2pt + gold),
  width: 100%,
  inset: (left: 1em, right: 1em, top: 0.7em, bottom: 0.7em),
  radius: 2pt,
)[#body]

// ----- The template function -------------------------------------------------

#let proposal(
  title: "",
  subtitle: none,
  client: "",
  client-detail: none,
  date: datetime.today().display("[day padding:zero] [month repr:long] [year]"),
  reference: none,
  badge: "SPESIFIKASI TEKNIS",
  prepared-for-label: "DISIAPKAN UNTUK",
  lang: "id",
  metadata: (),
  vendor-name: "PT ArtiVisi Intermedia",
  vendor-tagline: "Software engineering & technical training",
  vendor-contact: "info@artivisi.com · artivisi.com",
  font: ("New Computer Modern", "Times New Roman", "Libertinus Serif"),
  body,
) = {
  set document(
    title: title,
    author: vendor-name,
  )

  set text(
    font: font,
    size: 10.5pt,
    lang: lang,
  )

  set par(justify: true, leading: 0.65em)

  // === Cover page =============================================================

  set page(
    paper: "a4",
    margin: 0pt,
    numbering: none,
  )

  // Top hero band
  block(
    fill: navy,
    width: 100%,
    height: 11cm,
    inset: (left: 2.5cm, right: 2.5cm, top: 2cm, bottom: 1.6cm),
  )[
    #set text(fill: white)

    // ArtiVisi logo (dark variant — white letters + green swoosh)
    #image("assets/logo-artivisi-dark.svg", width: 4.5cm)

    #v(1.3cm)

    #text(size: 10pt, tracking: 3pt, weight: "regular", fill: gold)[#badge]

    #v(0.4em)

    #text(size: 24pt, weight: "bold")[#title]

    #if subtitle != none {
      v(0.3em)
      text(size: 13pt, weight: "regular", fill: rgb("#e2e8f0"))[#subtitle]
    }
  ]

  // White middle band with client + metadata
  block(
    width: 100%,
    inset: (left: 2.5cm, right: 2.5cm, top: 1.8cm, bottom: 1.5cm),
  )[
    // Client card
    #block(
      fill: cream,
      stroke: (left: 3pt + gold),
      width: 100%,
      inset: (left: 1.2em, right: 1.2em, top: 0.9em, bottom: 0.9em),
    )[
      #text(size: 8pt, fill: slate, tracking: 2pt)[#prepared-for-label]
      #v(0.25em)
      #text(size: 14pt, weight: "bold", fill: navy)[#client]
      #if client-detail != none {
        v(0.15em)
        text(size: 10pt, fill: slate)[#client-detail]
      }
    ]

    #v(1.4cm)

    // Metadata grid
    #if metadata.len() > 0 {
      table(
        columns: (auto, 1fr),
        stroke: (x, y) => (bottom: 0.4pt + border),
        inset: (x: 0pt, y: 8pt),
        align: (left, right),
        ..metadata.map(((k, v)) => (
          text(fill: slate)[#k],
          text(weight: "bold", fill: navy)[#v],
        )).flatten()
      )
    }
  ]

  v(1fr)

  // Bottom navy strip
  block(
    fill: navy,
    width: 100%,
    height: 2.6cm,
    inset: (left: 2.5cm, right: 2.5cm, top: 0.7cm, bottom: 0.7cm),
  )[
    #set text(fill: white, size: 9pt)
    #grid(
      columns: (1fr, auto),
      align: (left + horizon, right + horizon),
      gutter: 1em,
      [
        #text(weight: "bold", size: 10pt)[#vendor-name] \
        #text(fill: rgb("#cbd5e1"), size: 8.5pt)[#vendor-tagline] \
        #text(fill: rgb("#cbd5e1"), size: 8.5pt)[#vendor-contact]
      ],
      [
        #text(fill: gold, weight: "bold")[#date]
        #if reference != none {
          v(0.2em)
          text(fill: rgb("#cbd5e1"), size: 8pt)[Ref: #reference]
        }
      ]
    )
  ]

  pagebreak()

  // === Body pages =============================================================

  set page(
    paper: "a4",
    margin: (top: 2.5cm, bottom: 2.2cm, left: 2.2cm, right: 2.2cm),
    numbering: none,
    header: context {
      let n = counter(page).get().first()
      if n > 1 {
        set text(size: 8pt, fill: slate)
        grid(
          columns: (1fr, auto),
          align: (left, right),
          text(weight: "bold", fill: navy, tracking: 1.5pt)[ARTIVISI],
          text(fill: slate)[#title],
        )
        v(-0.4em)
        line(length: 100%, stroke: 0.3pt + border)
      }
    },
    footer: context {
      let n = counter(page).get().first()
      if n > 1 {
        line(length: 100%, stroke: 0.3pt + border)
        v(-0.2em)
        set text(size: 8pt, fill: slate)
        grid(
          columns: (1fr, auto, 1fr),
          align: (left, center, right),
          [#vendor-name],
          [#n],
          [#date],
        )
      }
    },
  )

  // Heading styles for body
  show heading.where(level: 1): it => {
    set text(size: 14pt, weight: "bold", fill: navy)
    block(above: 1.4em, below: 0.4em)[
      #it
    ]
    v(-0.6em)
    line(length: 100%, stroke: 0.6pt + gold)
    v(0.55em)
  }

  show heading.where(level: 2): it => {
    set text(size: 11.5pt, weight: "bold", fill: navy)
    block(above: 1.1em, below: 0.7em)[#it]
  }

  show heading.where(level: 3): it => {
    set text(size: 10.5pt, weight: "bold", fill: slate)
    block(above: 0.85em, below: 0.55em)[#it]
  }

  // Table default styling — clean grid lines, slate borders
  set table(
    stroke: 0.4pt + border,
    inset: 6pt,
    fill: (_, y) => if y == 0 { panel } else { none },
  )

  show table.cell.where(y: 0): set text(weight: "bold", fill: navy)

  // Link styling
  show link: it => text(fill: navy, underline(it))

  body
}
