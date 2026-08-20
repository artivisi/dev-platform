// Shared layout primitives used by every document in this repo.
//
//   #import "/shared/blocks.typ": cell, darr, code-blocks
//   #show: code-blocks

#import "/template/lib.typ": brand-blue, brand-green

// A bordered box used to build the layered architecture diagrams. Typst has no
// mermaid; layered stacks are drawn with nested grids of these.
#let cell(body, fill: white) = box(
  fill: fill, stroke: 0.6pt + rgb("#9ca3af"), radius: 3pt,
  inset: 5pt, width: 100%, align(center, text(size: 8pt, body)),
)

// Downward connector between two stacked `cell`s.
#let darr = align(center, text(size: 11pt, fill: brand-blue, sym.arrow.b))

// Show rule for fenced code blocks. Applied per document via `#show: code-blocks`.
#let code-blocks(body) = {
  show raw.where(block: true): it => block(
    fill: rgb("#f8f7fa"), stroke: 0.5pt + rgb("#cbd5e1"), radius: 3pt,
    inset: 8pt, width: 100%, text(size: 8.5pt, it),
  )
  body
}

// Transcript-style block for illustrative agent prompts.
#let transcript(body) = block(
  fill: rgb("#f8f7fa"), stroke: 0.5pt + rgb("#cbd5e1"), radius: 3pt,
  inset: 8pt, width: 100%,
)[
  #set text(size: 8.5pt)
  #body
]
