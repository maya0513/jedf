# jedf

Just Enough Document Format — a document format designed around how people
actually read documents today.

A jedf document is a semantic tree: headings, paragraphs, lists, tables,
figures, footnotes, and text runs with marks (emphasis, strong, code, math,
links). Pages are not stored in the document; they are produced from the
tree when printing. On screen, the tree is rendered as flowing HTML. For
print, it is rendered through Typst. Documents contain no executable code
and no macros.

The document itself is the semantic tree; serializations are separate.
The standard form is JSON (`.jedf`, `application/vnd.jedf+json`). The same
tree also has a CBOR encoding (`application/vnd.jedf+cbor`), and a
container format (`.jedfc`) packs a document together with asset files
such as images into a single file for distribution.

## Status

Implemented: the semantic tree, a validator with the format's resource
limits, the JSON and CBOR encodings, the container format, an HTML
renderer, a Typst renderer, a command line tool, and a browser viewer
that opens both `.jedf` and `.jedfc` files. Compression, encryption, and
signatures are later layers and are not in yet.

## Layout

- `src/ast` — the semantic tree types
- `src/validate` — structural validation and resource limits
- `src/codec` — the standard JSON encoding
- `src/codec_cbor` — the CBOR encoding
- `src/container` — the `.jedfc` container format
- `src/render_html` — HTML (flow) rendering
- `src/render_typst` — Typst source generation for print
- `src/level` — heading level clamping, with a machine-checked proof
- `src/web` — the browser viewer entry points (compiled to JS)
- `src/cli` — command line logic
- `src/cmd/jedf` — the `jedf` executable (native)
- `examples` — small documents that parse, validate, and render as they are
- `viewer` — the browser viewer page
- `docs/idea` — the design document (in Japanese, updated as decisions are made)
- `docs/spec.md` — the format specification (in Japanese)

## Usage

```
jedf validate <file>             Check a document against the format rules
jedf to-html <file>              Render a document as an HTML fragment
jedf to-typst <file>             Render a document as Typst source
jedf fmt <file>                  Print the document in canonical JSON form
jedf to-cbor <file> <output>     Write a document in the CBOR encoding
jedf from-cbor <file>            Print a CBOR document in canonical JSON form
jedf pack <file> <output> [assets...]
                                 Pack a document and assets into a container
jedf unpack <file> <output>      Extract a container's document and assets
```

## Development

The MoonBit toolchain is pinned in `mise.toml`. Tasks are bundled with just:

```
just ci     # format check, type check, tests, coverage, interface check
just bench  # benchmarks
just prove  # check the proof in src/level (needs Z3, provided by mise)
just viewer # build the browser viewer and serve it at http://localhost:8000
```

Type checking runs on all targets; tests run on native, wasm, and wasm-gc.
Tests cover every line of the library packages; benchmarks live next to the
tests of each package.

## License

MIT
