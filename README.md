# jedf

Just Enough Document Format — a document format designed around how people
actually read documents today.

A jedf document is a semantic tree: headings, paragraphs, lists, tables,
figures, footnotes, and text runs with marks (emphasis, strong, code, math,
links). Pages are not stored in the document; they are produced from the
tree when printing. On screen, the tree is rendered as flowing HTML. For
print, it is rendered through Typst. Documents contain no executable code,
no macros, and no attachments.

The standard representation is JSON. The AST and its serialization are
separate: the same tree could be encoded differently without changing the
format's meaning.

## Status

v0.1: the semantic tree, a validator with the format's resource limits, the
JSON encoding, an HTML renderer, a Typst renderer, and a command line tool.
Binary containers, compression, encryption, and signatures are later layers
and are not in this version.

## Layout

- `src/ast` — the semantic tree types
- `src/validate` — structural validation and resource limits
- `src/codec` — the standard JSON encoding
- `src/render_html` — HTML (flow) rendering
- `src/render_typst` — Typst source generation for print
- `src/cli` — command line logic
- `src/cmd/jedf` — the `jedf` executable (native)
- `docs/idea` — the design document (in Japanese, updated as decisions are made)

## Usage

```
jedf validate <file>   Check a document against the format rules
jedf to-html <file>    Render a document as an HTML fragment
jedf to-typst <file>   Render a document as Typst source
jedf fmt <file>        Print the document in canonical JSON form
```

## Development

The MoonBit toolchain is pinned in `mise.toml`. Tasks are bundled with just:

```
just ci    # format check, type check, tests, coverage, interface check
just bench # benchmarks
```

Tests cover every line of the library packages; benchmarks live next to the
tests of each package.

## License

MIT
