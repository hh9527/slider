#import "/typlibs/slider/lib.typ": slide, slot, show-slides
#import "/typlibs/slider-h/lib.typ": init-theme

#let theme = init-theme(
  title: [你好，SLiDER],
  institution: [SLiDER Team],
  author: [Codex],
  restrict-level: 1,
)

#show: show-slides(theme)

#slide.cover()
= 你好，SLiDER

一种内容结构先行的幻灯片创作方法

#slide.section()
= 理念

SLiDER 的目标不是少排版，而是让内容结构、布局空间和视觉效果各自独立演进。

#slide.normal()
== 结构先行

先把内容写成稳定的三级章节结构，再决定它怎样成为页面。

=== 一级和二级标题确定页面

`= / ==` 是页面边界。它们保留 Typst 文档天然的章节树，也让源文件仍然适合顺序阅读。

=== 三级标题确定逻辑块

`===` 切分页面内的逻辑块。每个块都是一个可被独立搬运、组合和强调的叙事单元。

=== Slide Marker 只解释结构

`slide.normal()`、`slide.focus()` 这些声明不改变内容含义，只说明接下来的结构应该被怎样展示。

#slide.normal()
== 视觉设计与内容解耦

布局不是内容的容器，而是内容流入页面空间时的一组 hint。

=== 内容留在文档流里

标题、段落、列表和代码仍然按自然顺序书写。源文件不因为两栏、三栏或跨列布局而被拆散。

=== Slot 描述布局空间

`slot.cell()` 创建承载区域；`slot.item()` 声明每个区域从内容流中消费多少逻辑块。

=== 内容受控流入空间

逻辑块按顺序进入 slot。一个空间可以接收一个块，也可以接收一组块；未消费的内容不会静默丢失。

#slide.normal()
== 纸张和笔墨

SLiDER 用纸张和笔墨分离空间的视觉效果与内容的视觉效果。

=== 纸张属于空间

`material` 描述 cell 这块空间的承载方式：普通纸面、柔和纸面、强调纸面，或反相纸面。

=== 笔墨属于内容

`pen` 描述 item 中内容的显眼程度：次要、常规、主要，或更强的轮廓强调。

=== 二者可以组合

同一段内容可以换一种纸张承载；同一块空间也可以接收不同笔墨的内容。布局精修因此不必改写内容。

#slide.section()
= 页面的类型

页面类型表达展示语气：有的页面承担叙事，有的页面承担强调。

#slide.normal()
== Normal：常规内容页

`normal` 是最常用的叙事页面：标题在上，正文在下，页脚保留章节路径和进度。

=== 适合承载连续说明

- 概念定义
- 过程解释
- 列表、代码、引用等常规内容

=== 主题负责稳定外观

创作者不需要在内容里反复处理字号、页脚、进度条、角标和基础留白。

#slide.focus()
== Focus：聚焦强调页

当你只想让读者记住一句话，页面类型就应该改变，而不是扭曲内容结构。

#slide.section()
= 高级页面布局

复杂页面不是把内容提前塞进布局容器，而是让自然形成的逻辑块根据 slide 级别的 hint 进入不同版面位置。

#slide.normal-grid(
  columns: 2,
  rows: 2,
  slots: (
    slot.cell(material: "accent"),
    slot.cell(material: "soft"),
    slot.cell(material: "soft"),
    slot.cell(material: "reversed"),
  ),
)
== 格子如何消费逻辑块

=== 先切块

页面内的 `===` 标题切出逻辑块。每个逻辑块保留自己的标题、正文和原始内容。

=== 再分配

`slot.cell()` 创建承载区域；`slot.item()` 声明这个区域从内容流里消费几个逻辑块。

=== 最后渲染

主题根据 cell 的位置、跨度、材质和 item 的笔墨，把已分配的逻辑块画到页面上。

=== 剩余内容不丢失

如果 slot 没有消费完所有逻辑块，剩余内容会进入追加区域，而不是静默消失。

#slide.normal-grid(
  columns: (1.15fr, 1fr),
  rows: 2,
  content-view: (
    width: 94%,
    height: 86%,
    align: center + horizon,
  ),
  slots: (
    slot.cell(rowspan: 2, material: "accent", items: (slot.item(count: 2),)),
    slot.cell(material: "soft", align: center + horizon, items: (slot.item(pen: "secondary"),)),
    slot.cell(material: "reversed", align: center + horizon, items: (slot.item(pen: "primary"),)),
  ),
)
== 一个后置精修示例

=== 主区域

左侧 cell 使用 `rowspan: 2`，并通过 `count: 2` 接收前两个逻辑块，形成页面主叙事区。

=== 补充区域

右上 cell 使用柔和纸面和 `pen: "secondary"`，降低补充信息的视觉权重。

=== 落点区域

右下 cell 使用反相纸面和主要笔墨，作为这一页最后的视觉落点。

=== 内容仍在下方

这三个区域的内容都来自后续 `===` 逻辑块，而不是直接写进 grid 内部。

#slide.normal-grid(
  columns: 2,
  rows: 1,
  content-view: (
    width: 94%,
    height: 82%,
    align: center + horizon,
  ),
  slots: (
    slot.cell(material: "soft", items: (slot.item(pen: "normal", hide-first-heading: true),)),
    slot.cell(material: "soft", align: center + horizon, items: (slot.item(pen: "secondary"),)),
  ),
)
== 两栏布局

=== Code

```typ
#slide.normal-columned(
  columns: 2,
  slots: (
    slot.cell(),
    slot.cell(),
  ),
)
```

=== 右栏

#slide.normal-grid(
  columns: (1fr, 1.05fr, 1fr),
  rows: 1,
  content-view: (
    width: 94%,
    height: 82%,
    align: center + horizon,
  ),
  slots: (
    slot.cell(x: 1, material: "soft", items: (slot.item(pen: "normal", hide-first-heading: true),)),
    slot.cell(x: 0, material: "soft", align: center + horizon, items: (slot.item(pen: "secondary"),)),
    slot.cell(x: 2, material: "soft", align: center + horizon, items: (slot.item(pen: "secondary"),)),
  ),
)
== 三栏布局

=== Code

```typ
#slide.normal-grid(
  columns: 3,
  slots: (
    slot.cell(x: 1),
    slot.cell(x: 0),
    slot.cell(x: 2),
  ),
)
```

=== 左栏

=== 右栏

#slide.normal-grid(
  columns: (1.1fr, 1fr, 1fr),
  rows: 2,
  content-view: (
    width: 94%,
    height: 88%,
    align: center + horizon,
  ),
  slots: (
    slot.cell(rowspan: 2, material: "soft", items: (slot.item(pen: "normal", hide-first-heading: true),)),
    slot.cell(colspan: 2, material: "soft", align: center + horizon, items: (slot.item(pen: "secondary"),)),
    slot.cell(material: "soft", align: center + horizon, items: (slot.item(pen: "secondary"),)),
    slot.cell(material: "soft", align: center + horizon, items: (slot.item(pen: "secondary"),)),
  ),
)
== 更复杂的栅格化布局

=== Code

```typ
#slide.normal-grid(
  columns: 2,
  rows: 2,
  slots: (
    slot.cell(rowspan: 2),
    slot.cell(colspan: 2),
    slot.cell(),
    slot.cell(),
  ),
)
```

=== 大格子

=== 小格子

=== 小格子

#slide.section()
= 纸与笔墨

纸决定内容落在哪里、以什么材质承载；笔墨决定内容本身的显眼程度。

#slide.normal-grid(
  columns: 2,
  rows: 2,
  content-view: (
    width: 92%,
    height: 90%,
    align: center + horizon,
  ),
  slots: (
    slot.cell(material: "plain"),
    slot.cell(material: "soft"),
    slot.cell(material: "accent"),
    slot.cell(material: "reversed"),
  ),
)
== 不同材质的纸张

=== Plain

```typ #slot.cell(material: "plain")```

无背景、无阴影，让内容自然落在页面上。

=== Soft

```typ #slot.cell(material: "soft")```

轻量纸面，用淡色块形成分区感。

=== Accent

```typ #slot.cell(material: "accent")```

更明显的纸面，用来强调当前页的关键区域。

=== Reversed

```typ #slot.cell(material: "reversed")```

反相纸面，用深色承载高对比内容。

#slide.normal-grid(
  columns: 2,
  rows: 2,
  content-view: (
    width: 92%,
    height: 90%,
    align: center + horizon,
  ),
  slots: (
    slot.cell(material: "soft", items: (slot.item(pen: "secondary"),)),
    slot.cell(material: "soft", items: (slot.item(pen: "normal"),)),
    slot.cell(material: "soft", items: (slot.item(pen: "primary"),)),
    slot.cell(material: "soft", items: (slot.item(pen: "outlined"),)),
  ),
)
== 不同的笔墨效果

=== Secondary

```typ #slot.item(pen: "secondary")```

降低显眼度，适合补充说明和背景信息。

=== Normal

```typ #slot.item(pen: "normal")```

默认书写状态，保持清晰但不过度强调。

=== Primary

```typ #slot.item(pen: "primary")```

提高显眼度，让读者先看到这一块。

=== Outlined

```typ #slot.item(pen: "outlined")```

最高强调等级：提升对比和字重，但不额外画内部框，避免干扰格子的布局。

#slide.back-cover()
= 感谢聆听

画面，源自内容，成于结构
