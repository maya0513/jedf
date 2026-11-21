# Examples

Small jedf documents that can be read, validated, and rendered as they are.

| File | What it shows |
| --- | --- |
| `showcase.jedf` | Every block type: headings, sections, lists, a table, a code block, a math block, a figure, a footnote, a page break, and all five marks |
| `letter.jedf` | A short letter: a heading, paragraphs, a list, and a mailto link |
| `meeting-notes.jedf` | Sections holding a table and lists, in the shape of meeting notes |
| `nested.jedf` | Deep nesting: sections inside sections, a list inside a list item, a table cell holding several blocks, a multi-block footnote |
| `invalid.jedf` | A document that parses but fails validation in five ways; for trying `validate` and the viewer's error display |
| `semantic-tree.png` | The image the showcase figure refers to |
| `showcase.jedfc` | The showcase packed as a container, with `semantic-tree.png` as an asset |

Try them with the command line tool:

```sh
jedf validate examples/showcase.jedf
jedf to-html examples/showcase.jedf
jedf to-typst examples/meeting-notes.jedf
jedf fmt examples/letter.jedf
jedf validate examples/invalid.jedf   # reports five issues, exits 1
jedf unpack examples/showcase.jedfc /tmp/showcase.jedf
jedf to-cbor examples/nested.jedf /tmp/nested.cbor
jedf from-cbor /tmp/nested.cbor
```

The test in this directory (`examples_test.mbt`) parses each valid file,
checks that validation reports no issues, renders it to HTML and Typst,
and checks that JSON, CBOR, and container round trips return the same
document. It also checks that the committed container matches its
sources and that `invalid.jedf` reports the expected issues. It runs as
part of `moon test`.
