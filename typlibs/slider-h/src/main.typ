#import "../../slider/lib.typ": fill-slots
#import "@preview/shadowed:0.3.0": shadow

#let page-progress(c-minor) = {
  let n = here().page()
  let t = counter(page).final().at(0)
  text(size: 1.8em, [#n])
  text(fill: c-minor, [ \/ #t])
}

#let page-progress-bar(fill) = {
  let n = here().page()
  let t = counter(page).final().at(0)
  let percent = (n / calc.max(t, 1)) * 100%
  rect(width: percent, height: 2pt, fill: fill)
}

#let display-restriction(level, items) = {
  let level = calc.min(level, items.len() - 1)
  let it = items.at(level)
  rotate(
    reflow: true,
    45deg,
    block(
      fill: it.fill,
      height: 1.2em,
      width: 2em,
      outset: (x: 1.2em),
      align(horizon + center, text(size: 0.5em, fill: white, it.text))
    )
  )
}

#let display-author-and-institution(c-minor, sep, institution, author) = {
  let authors = if author == none {
    none
  } else if type(author) == array {
    if author.len() > 0 {
      let cont = false
      for it in author {
        if not cont {
          cont = true
        } else {
          sep
        }
        it
      }
    } else {
      none
    }
  } else {
    [#author]
  }

  if authors == none {
    text(size: 1.5em, institution)
  } else {
    text(size: 1.5em, authors)
    linebreak()
    text(size: 0.9em, fill: c-minor, institution)
  }
}

#let display-path(c-text, sep, title, parents) = {
  title
  for it in parents {
    sep
    text(fill: c-text, it.title)
  }
}

#let init-theme(
  ratio: "16-9",
  title: [Slide Title],
  institution: [Institution],
  institution-logo: none,
  brand: none,
  author: none,
  restrict-level: 0,
) = {
  let restriction-items = (
    (fill: rgb("#252"), text: "公开"),
    (fill: rgb("#557"), text: "内部公开"),
    (fill: rgb("#534"), text: "受限公开"),
    (fill: rgb("#722"), text: "不公开"),
  )

  let rem(x) = 18pt * x
  let code-size = 14pt
  let page-margin = (x: rem(2), top: rem(1), bottom: rem(2))
  let cover-margin = (x: rem(4), top: rem(4), bottom: rem(4))
  let c-sep = rgb("#ddd")
  let c-title = rgb(153, 0, 0)
  let c-title-minor = c-title.lighten(50%)
  let c-text = rgb("#333")
  let c-text-minor = c-text.lighten(50%)
  let c-indicator = rgb("#ccf")
  let c-indicator-bar = gradient.linear(c-indicator, c-indicator.darken(30%))
  let sans-font = "Noto Sans CJK SC"
  let serif-font = "Noto Serif CJK SC"
  let mono-font = "Noto Sans Mono CJK SC"
  let normal-safe-inset = (top: rem(2.8), bottom: rem(1.4))
  let ink-outset = (x: rem(0.15), y: 2pt)
  let default-content-view = (
    width: 100%,
    height: 100%,
    align: top + left,
  )

  let text-scaled(scale: 1.0, inner) = {
    set text(font: sans-font, size: rem(scale), fill: c-text)
    set par(justify: true, spacing: 1em, leading: 0.5em)
    set grid(gutter: 2em)
    show heading.where(level: 1): set text(font: serif-font, size: rem(2.25), fill: c-title)
    show heading.where(level: 2): set text(font: serif-font, size: rem(1.75), fill: c-title)
    show heading.where(level: 3): set text(font: serif-font, size: rem(1.5))
    show heading.where(level: 4): set text(font: serif-font, size: rem(1.25))
    show heading.where(level: 5): set text(font: serif-font, size: rem(1))
    show heading.where(level: 6): set text(font: serif-font, size: rem(1))
    show raw.where(block: true): set text(font: mono-font, size: code-size)
    inner
  }

  let paper = "presentation-" + ratio
  let bg = block(
    width: 100%,
    height: 100%,
    fill: white,
    {
      place(right + top, text-scaled(display-restriction(restrict-level, restriction-items)))
      align(left + bottom, context page-progress-bar(c-indicator-bar))
    }
  )

  let footer(parents) = text-scaled(scale: 0.6, block(width: 100%, {
    place(horizon + left, text(fill: c-text-minor, institution))
    place(horizon + right, context page-progress(c-text-minor))
    align(horizon + center, display-path(
      c-text,
      text(fill: c-sep, " | "),
      text(fill: c-text-minor, title),
      parents
    ))
  }))

  let resolve-content-view(content-view) = {
    if content-view == none {
      default-content-view
    } else {
      default-content-view + content-view
    }
  }

  let normal-frame(parents, h, content, content-view: none) = {
    let view = resolve-content-view(content-view)
    page(
    paper: paper,
    margin: page-margin,
    header: none,
    header-ascent: rem(0.25),
    footer-descent: rem(0.75),
    footer: footer(parents),
    background: bg,
    text-scaled({
      place(top + left, h)
      block(
        width: 100%,
        height: 100%,
        inset: normal-safe-inset,
        clip: true,
        align(
          view.align,
          block(
            width: view.width,
            height: view.height,
            outset: ink-outset,
            content,
          ),
        ),
      )
    })
  )}

  let normal(parents, h, body, options, blocks) = normal-frame(
    parents,
    h,
    body,
    content-view: options.at("content-view", default: none),
  )

  let section(parents, h, body, options, blocks) = page(
    paper: paper,
    margin: page-margin,
    header: none,
    footer: none,
    background: bg,
    align(horizon + center, text-scaled({
      h
      body
    }))
  )

  let cover-bg = align(top, block(
    width: 100%,
    height: 100%,
    fill: white,
    {
      image(fit: "stretch", width: 100%, height: 100% - cover-margin.bottom, "../assets/bg/bg-0.svg")
      place(right + top, text-scaled(display-restriction(restrict-level, restriction-items)))
    }
  ))

  let cover-footer = text-scaled(scale: 0.65, block(
    height: cover-margin.bottom,
    align(horizon, grid(
      columns: (1fr, auto, auto),
      column-gutter: 1.6em,
      align: horizon,
      display-author-and-institution(c-text-minor, text(fill: c-sep, ", "), institution, author),
      if institution-logo == none { none } else { block(height: 3.2em, institution-logo()) },
      if brand == none { none } else { block(height: 3.2em, brand) },
    ))
  ))

  let cover(parents, h, body, options, blocks) = page(
    paper: paper,
    header: none,
    footer: cover-footer,
    header-ascent: 0pt,
    footer-descent: 0pt,
    margin: cover-margin,
    background: cover-bg,
    text-scaled({
      hide(place(top, h))
      heading(
        depth: 1,
        outlined: false,
        bookmarked: false,
        title,
      )
      body
    })
  )

  let back-cover(parents, h, body, options, blocks) = page(
    paper: paper,
    header: none,
    footer: none,
    margin: page-margin,
    background: bg,
    align(horizon + center, text-scaled({
      align(center, h)
      parbreak()
      align(center, body)
    }))
  )

  let cell-fill(material) = {
    if material == "soft" {
      rgb("#f5f1ee")
    } else if material == "accent" {
      rgb("#f3dad2")
    } else if material == "reversed" {
      rgb("#27303a")
    } else {
      none
    }
  }

  let base-ink(material) = {
    if material == "reversed" { white } else { c-text }
  }

  let pen-fill(material, pen) = {
    if material == "reversed" {
      if pen == "secondary" {
        rgb("#aeb7bf")
      } else if pen == "normal" {
        rgb("#eef2f5")
      } else {
        white
      }
    } else if pen == "secondary" {
      c-text-minor
    } else if pen == "primary" or pen == "outlined" {
      rgb("#111")
    } else {
      c-text
    }
  }

  let render-item-content(item, material) = {
    let started = false
    let heading-hidden = false
    for b in item.blocks {
      if started { parbreak() }
      started = true
      if item.hide-first-heading and not heading-hidden and b.heading != none {
        heading-hidden = true
        place(hide(b.heading))
        b.body
      } else {
        b.raw
      }
    }
    for _ in range(item.missing) {
      if started { parbreak() }
      started = true
      align(horizon + center, text(weight: "bold", fill: rgb("#8b1d1d"), [ITEM REQUIRED]))
    }
  }

  let render-item(item, material) = {
    let content = {
      set text(fill: pen-fill(material, item.pen))
      if item.pen == "outlined" {
        strong(render-item-content(item, material))
      } else {
        render-item-content(item, material)
      }
    }
    content
  }

  let render-items(items, material) = {
    let started = false
    for item in items {
      if started { parbreak() }
      started = true
      render-item(item, material)
    }
  }

  let cell-box(cell) = {
    let material = cell.material
    let inner-align = if cell.align == none { top + left } else { cell.align }
    let ink = block(outset: ink-outset, {
      set text(fill: base-ink(material))
      render-items(cell.items, material)
    })
    let surface = block(
      width: 100%,
      height: 100%,
      fill: cell-fill(material),
      inset: if cell.items.len() == 0 { 0pt } else { rem(0.8) },
      align(inner-align, ink),
    )

    if cell.items.len() == 0 or material == "plain" {
      surface
    } else {
      shadow(
        dx: 1.8pt,
        dy: 3pt,
        blur: 5pt,
        spread: 0.5pt,
        fill: luma(0%).transparentize(82%),
        radius: 0pt,
        surface,
      )
    }
  }

  let render-cell(cell) = {
    let inner = cell-box(cell)
    let args = (
      colspan: cell.colspan,
      rowspan: cell.rowspan,
      fill: none,
      inset: 0pt,
      align: top + left,
    )
    if cell.x == none and cell.y == none {
      grid.cell(..args, inner)
    } else if cell.x == none {
      grid.cell(y: cell.y, ..args, inner)
    } else if cell.y == none {
      grid.cell(x: cell.x, ..args, inner)
    } else {
      grid.cell(x: cell.x, y: cell.y, ..args, inner)
    }
  }

  let tracks(n, unit: 1fr) = {
    if type(n) == int {
      let r = ()
      for _ in range(n) {
        r.push(unit)
      }
      r
    } else {
      n
    }
  }

  let normal-columned(parents, h, body, options, blocks) = {
    let columns = options.at("columns", default: 2)
    let cells = fill-slots(blocks, options.at("slots", default: none))
    normal-frame(
      parents,
      h,
      block(width: 100%, height: 100%, grid(
        columns: tracks(columns),
        rows: (1fr,),
        gutter: rem(0.8),
        ..cells.map(render-cell),
      )),
      content-view: options.at("content-view", default: none),
    )
  }

  let normal-grid(parents, h, body, options, blocks) = {
    let columns = options.at("columns", default: 2)
    let rows = options.at("rows", default: none)
    let cells = fill-slots(blocks, options.at("slots", default: none))
    let grid-content = if rows == none {
      align(horizon, grid(
        columns: tracks(columns),
        gutter: rem(0.8),
        ..cells.map(render-cell),
      ))
    } else {
      block(width: 100%, height: 100%, grid(
        columns: tracks(columns),
        rows: tracks(rows),
        gutter: rem(0.8),
        ..cells.map(render-cell),
      ))
    }
    normal-frame(
      parents,
      h,
      grid-content,
      content-view: options.at("content-view", default: none),
    )
  }

  let focus(parents, h, body, options, blocks) = page(
    paper: paper,
    margin: page-margin,
    header: none,
    footer: footer(parents),
    background: bg,
    align(horizon + center, text-scaled(scale: 1.35, {
      align(center, h)
      parbreak()
      align(center, body)
    }))
  )

  (
    default: (parents, h, body, options, blocks) => {
      let f = if h.depth == 1 { section } else { normal }
      f(parents, h, body, options, blocks)
    },
    normal: normal,
    normal-columned: normal-columned,
    normal-grid: normal-grid,
    focus: focus,
    section: section,
    cover: cover,
    back-cover: back-cover,
  )
}
