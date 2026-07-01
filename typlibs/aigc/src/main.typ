#import "@preview/digestify:0.1.0": sha256, bytes-to-hex
#import std: image as std-image

#let source-digest(
  vendor,
  format,
  content-size,
  model,
  quality,
  prompt,
  chroma-key,
  chroma-key-prompt,
) = {
  let source = (
    "vendor=" + vendor,
    "format=" + format,
    "content-size=" + content-size,
    "model=" + model,
    "quality=" + quality,
    "prompt=" + prompt,
    "chroma-key=" + if chroma-key == none { "" } else { chroma-key },
    "chroma-key-prompt=" + if chroma-key-prompt == none { "" } else { chroma-key-prompt },
  ).join("\n")
  bytes-to-hex(sha256(bytes(source))).slice(0, 16)
}

#let image(
  path,
  render-path: none,
  vendor: "openai",
  model: "gpt-image-2",
  quality: "low",
  content-size: "1024x1024",
  chroma-key: none,
  chroma-key-prompt: none,
  prompt: none,
  ..args,
) = {
  if prompt == none {
    panic("aigc.image requires prompt")
  }

  let format = path.split(".").last()
  let digest = source-digest(
    vendor,
    format,
    content-size,
    model,
    quality,
    prompt,
    chroma-key,
    chroma-key-prompt,
  )

  let meta = (
    kind: "aigc",
    vendor: vendor,
    format: format,
    content-size: content-size,
    source-digest: digest,
    path: path,
    model: model,
    quality: quality,
    prompt: prompt,
  )
  if chroma-key != none {
    meta.insert("chroma-key", chroma-key)
  }
  if chroma-key-prompt != none {
    meta.insert("chroma-key-prompt", chroma-key-prompt)
  }
  metadata(meta)

  if sys.inputs.at("aigc-mode", default: "") == "query" {
    rect(width: 100pt, height: 70pt, stroke: rgb("#ccc"))[
      #text(size: 9pt, fill: rgb("#888"))[AIGC]
    ]
  } else {
    std-image(if render-path == none { path } else { render-path }, ..args)
  }
}

#let image-tool(
  vendor,
  model: "gpt-image-2",
  quality: "low",
  content-size: "1024x1024",
  chroma-key: none,
  chroma-key-prompt: none,
) = {
  (
    path,
    render-path: none,
    model: model,
    quality: quality,
    content-size: content-size,
    chroma-key: chroma-key,
    chroma-key-prompt: chroma-key-prompt,
    prompt: none,
    ..args,
  ) => image(
    path,
    vendor: vendor,
    model: model,
    quality: quality,
    content-size: content-size,
    chroma-key: chroma-key,
    chroma-key-prompt: chroma-key-prompt,
    render-path: render-path,
    prompt: prompt,
    ..args,
  )
}
