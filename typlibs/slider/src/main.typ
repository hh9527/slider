#let is-empty(it) = {
  let t = it.func()
  if t == parbreak or t == linebreak {
    true
  } else {
    false
  }
}

#let to-content(items) = {
  let started = false
  for it in items {
    if started or not is-empty(it) {
      started = true
      it
    }
  }
}

#let split-by-depth(items, depth) = {
  let tmp = ()
  let r = ()
  for it in items {
    let t = it.func()
    if t == heading and it.depth == depth {
      if tmp.len() != 0 {
        r.push(to-content(tmp))
      }
      tmp = (it,)
    } else {
      if r.len() != 0 or not is-empty(it) {
        tmp.push(it)
      }
    }
  }
  if tmp.len() != 0 {
    r.push(to-content(tmp))
  }
  r
}

#let items-to-block(items) = {
  let h = none
  let body = ()
  let found-heading = false

  for it in items {
    if not found-heading and it.func() == heading {
      h = it
      found-heading = true
    } else if found-heading or not is-empty(it) {
      body.push(it)
    }
  }

  (
    kind: "block",
    heading: h,
    body: to-content(body),
    children: (),
    raw: to-content(items),
  )
}

#let split-blocks(items, depth) = {
  let tmp = ()
  let r = ()
  for it in items {
    let t = it.func()
    if t == heading and it.depth == depth {
      if tmp.len() != 0 {
        r.push(items-to-block(tmp))
      }
      tmp = (it,)
    } else if tmp.len() != 0 {
      tmp.push(it)
    }
  }
  if tmp.len() != 0 {
    r.push(items-to-block(tmp))
  }
  r
}

#let make-slide(ty, options: (:)) = metadata((
  kind: "slide",
  ty: ty,
  options: options,
))

#let slide = (
  normal: (
    content-view: none,
  ) => make-slide("normal", options: (
    content-view: content-view,
  )),
  normal-grid: (
    columns: 2,
    rows: none,
    slots: none,
    content-view: none,
  ) => make-slide("normal-grid", options: (
    columns: columns,
    rows: rows,
    slots: slots,
    content-view: content-view,
  )),
  normal-columned: (
    columns: 2,
    slots: none,
    content-view: none,
  ) => make-slide("normal-columned", options: (
    columns: columns,
    slots: slots,
    content-view: content-view,
  )),
  focus: () => make-slide("focus"),
  section: () => make-slide("section"),
  hidden: () => make-slide("hidden"),
  cover: () => make-slide("cover"),
  back-cover: () => make-slide("back-cover"),
)

#let slot = (
  item: (
    count: 1,
    pen: "normal",
    hide-first-heading: false,
  ) => (
    kind: "slot-item",
    count: count,
    pen: pen,
    hide-first-heading: hide-first-heading,
  ),
  cell: (
    items: auto,
    x: none,
    y: none,
    colspan: 1,
    rowspan: 1,
    align: none,
    fit: "natural",
    material: "plain",
  ) => (
    kind: "slot",
    ty: "cell",
    items: items,
    x: x,
    y: y,
    colspan: colspan,
    rowspan: rowspan,
    align: align,
    fit: fit,
    material: material,
  ),
)

#let default-item-slot = (slot.item)()
#let rest-item-slot = (slot.item)(count: "rest")
#let default-cell-slot = (slot.cell)()
#let rest-cell-slot = (slot.cell)(items: (rest-item-slot,))

#let resolve-cell-items(s) = {
  if s.items == auto {
    (default-item-slot,)
  } else {
    s.items
  }
}

#let item-from-slot(it, blocks: (), missing: 0) = (
  kind: "item",
  blocks: blocks,
  missing: missing,
  slot: it,
  pen: it.at("pen", default: "normal"),
  hide-first-heading: it.at("hide-first-heading", default: false),
)

#let cell-from-slot(s, items: ()) = (
  kind: "cell",
  items: items,
  slot: s,
  x: s.at("x", default: none),
  y: s.at("y", default: none),
  colspan: s.at("colspan", default: 1),
  rowspan: s.at("rowspan", default: 1),
  align: s.at("align", default: none),
  fit: s.at("fit", default: "natural"),
  material: s.at("material", default: "plain"),
)

#let take-blocks(blocks, start, count) = {
  let remaining = calc.max(blocks.len() - start, 0)
  let n = if count == "rest" {
    remaining
  } else if type(count) == int and count >= 0 {
    count
  } else {
    panic("slot.item count must be a non-negative integer or rest")
  }
  let end = calc.min(start + n, blocks.len())
  let picked = if end > start { blocks.slice(start, end) } else { () }
  (blocks: picked, consumed: picked.len(), missing: calc.max(n - picked.len(), 0))
}

#let fill-slots(blocks, slots) = {
  let plan = if slots == none {
    let generated = ()
    for _ in blocks {
      generated.push(default-cell-slot)
    }
    generated
  } else {
    slots
  }
  let cells = ()
  let block-i = 0

  for s in plan {
    if s.at("kind", default: none) != "slot" or s.at("ty", default: none) != "cell" {
      panic("slot plan contains a non-cell slot")
    }

    let filled-items = ()
    for it in resolve-cell-items(s) {
      if it.at("kind", default: none) != "slot-item" {
        panic("slot cell items must contain slot.item values")
      }
      let picked = take-blocks(blocks, block-i, it.count)
      filled-items.push(item-from-slot(it, blocks: picked.blocks, missing: picked.missing))
      block-i += picked.consumed
    }
    cells.push(cell-from-slot(s, items: filled-items))
  }

  if slots != none and block-i < blocks.len() {
    let picked = take-blocks(blocks, block-i, "rest")
    cells.push(cell-from-slot(rest-cell-slot, items: (item-from-slot(rest-item-slot, blocks: picked.blocks),)))
  }

  cells
}

#let finalize-slide(cur) = (
  meta: cur.meta,
  parents: cur.parents,
  heading: cur.heading,
  content: cur.content,
  body: to-content(cur.content),
  blocks: split-blocks(cur.content, 3),
)

#let render-slide(theme, cur) = {
  let options = if cur.meta == none { (:) } else { cur.meta.at("options", default: (:)) }
  let ty = if cur.meta == none { none } else { cur.meta.at("ty", default: none) }
  let r = if ty == none {
    theme.default
  } else {
    theme.at(ty, default: theme.default)
  }
  r(cur.parents, cur.heading, cur.body, options, cur.blocks)
}

#let render-slides(theme, slides) = {
  for cur in slides {
    render-slide(theme, cur)
  }
}

#let update-heading-stack(hstack, it) = {
  let i = hstack.position(i => i.depth >= it.depth)
  if i != none {
    let n = hstack.len() - i
    for _ in range(0, n) {
      let _ = hstack.pop()
    }
  }
  let parents = hstack.slice(0)
  hstack.push((depth: it.depth, title: it.body))
  (parents: parents, hstack: hstack)
}

#let parse-slides(body) = {
  let items = body.children
  let slides = ()
  let meta = none
  let cur = none
  let hstack = ()
  for it in items {
    let t = it.func()
    if t == metadata and it.value.at("kind", default: none) == "slide" {
      if meta != none {
        panic("slide marker must be followed by a heading before another slide marker")
      }
      if cur != none {
        slides.push(finalize-slide(cur))
        cur = none
      }
      meta = it.value
    } else if t == heading and it.depth <= 2 {
      if cur != none {
        slides.push(finalize-slide(cur))
      }

      let updated = update-heading-stack(hstack, it)
      hstack = updated.hstack

      if meta != none and meta.ty == "hidden" {
        meta = none
        cur = none
      } else {
        cur = (meta: meta, parents: updated.parents, heading: it, content: ())
        meta = none
      }
    } else {
      if cur != none {
        if cur.content.len() != 0 or not is-empty(it) {
          cur.content.push(it)
        }
      }
    }
  }

  if meta != none {
    panic("slide marker must be followed by a heading")
  }

  if cur != none {
    slides.push(finalize-slide(cur))
  }

  slides
}

#let show-slides(theme) = (body) => {
  render-slides(theme, parse-slides(body))
}
