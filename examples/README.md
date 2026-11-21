# Examples

Small jedf documents that can be read, validated, and rendered as they are.

| File | What it shows |
| --- | --- |
| `showcase.json` | Every block type: headings, sections, lists, a table, a code block, a math block, a figure, a footnote, a page break, and all five marks |
| `letter.json` | A short letter: a heading, paragraphs, a list, and a mailto link |
| `meeting-notes.json` | Sections holding a table and lists, in the shape of meeting notes |

Try them with the command line tool:

```sh
jedf validate examples/showcase.json
jedf to-html examples/showcase.json
jedf to-typst examples/meeting-notes.json
jedf fmt examples/letter.json
```

The test in this directory (`examples_test.mbt`) parses each file, checks
that validation reports no issues, renders it to HTML and Typst, and checks
that a JSON round trip returns the same document. It runs as part of
`moon test`.
