#import "main.typ": make-slide

#let normal(content-view: none) = make-slide("normal", options: (
  content-view: content-view,
))
#let normal-grid(columns: 2, rows: none, slots: none, content-view: none) = make-slide("normal-grid", options: (
  columns: columns,
  rows: rows,
  slots: slots,
  content-view: content-view,
))
#let normal-columned(columns: 2, slots: none, content-view: none) = make-slide("normal-columned", options: (
  columns: columns,
  slots: slots,
  content-view: content-view,
))
#let focus() = make-slide("focus")
#let section() = make-slide("section")
#let hidden() = make-slide("hidden")
#let cover() = make-slide("cover")
#let back-cover() = make-slide("back-cover")
