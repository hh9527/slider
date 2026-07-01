#import "main.typ": slot

#let item(
  count: 1,
  pen: "normal",
  hide-first-heading: false,
) = (slot.item)(
  count: count,
  pen: pen,
  hide-first-heading: hide-first-heading,
)

#let cell(
  items: auto,
  x: none,
  y: none,
  colspan: 1,
  rowspan: 1,
  align: none,
  fit: "natural",
  material: "plain",
) = (slot.cell)(
  items: items,
  x: x,
  y: y,
  colspan: colspan,
  rowspan: rowspan,
  align: align,
  fit: fit,
  material: material,
)
