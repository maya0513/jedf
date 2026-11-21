///|
fn sample_doc() -> @ast.Document {
  {
    blocks: [
      @ast.Block::Heading(1, [@ast.Run::plain("Title")]),
      @ast.Block::Paragraph([
        @ast.Run::plain("a<b & "),
        @ast.Run::marked("link", @ast.Marks::{
          ..@ast.Marks(),
          strong: true,
          link: Some("https://example.com/?a=1&b=2"),
        }),
        @ast.Run::marked("code", @ast.Marks::{ ..@ast.Marks(), code: true, }),
        @ast.Run::marked("x", @ast.Marks::{
          ..@ast.Marks(),
          emphasis: true,
          math: true,
        }),
      ]),
      @ast.Block::Section([@ast.Run::plain("S")], [
        @ast.Block::ListBlock(false, [
          [@ast.Block::Paragraph([@ast.Run::plain("i")])],
        ]),
      ]),
      @ast.Block::TableBlock([
        @ast.TableRow::{
          header: true,
          cells: [[@ast.Block::Paragraph([@ast.Run::plain("h")])]],
        },
        @ast.TableRow::{
          header: false,
          cells: [[@ast.Block::Paragraph([@ast.Run::plain("c")])]],
        },
      ]),
      @ast.Block::CodeBlock("if (a < b) {}", Some("moonbit")),
      @ast.Block::CodeBlock("plain", None),
      @ast.Block::MathBlock("x^2"),
      @ast.Block::FigureBlock(
        "a.png",
        "alt \"quoted\"",
        Some([@ast.Run::plain("cap")]),
      ),
      @ast.Block::FigureBlock("b.png", "alt2", None),
      @ast.Block::FootnoteBlock("n1", [
        @ast.Block::Paragraph([@ast.Run::plain("note")]),
      ]),
      @ast.Block::PageBreakHint,
    ],
  }
}

///|
test "render snapshot" {
  inspect(
    @render_html.render(sample_doc()),
    content=(
      #|<h1>Title</h1>
      #|<p>a&lt;b &amp; <a href="https://example.com/?a=1&amp;b=2"><strong>link</strong></a><code>code</code><em><span class="math">x</span></em></p>
      #|<section>
      #|<h2>S</h2>
      #|<ul>
      #|<li>
      #|<p>i</p>
      #|</li>
      #|</ul>
      #|</section>
      #|<table>
      #|<thead>
      #|<tr>
      #|<th>
      #|<p>h</p>
      #|</th>
      #|</tr>
      #|</thead>
      #|<tbody>
      #|<tr>
      #|<td>
      #|<p>c</p>
      #|</td>
      #|</tr>
      #|</tbody>
      #|</table>
      #|<pre><code class="language-moonbit">if (a &lt; b) {}</code></pre>
      #|<pre><code>plain</code></pre>
      #|<div class="math">x^2</div>
      #|<figure>
      #|<img src="a.png" alt="alt &quot;quoted&quot;">
      #|<figcaption>cap</figcaption>
      #|</figure>
      #|<figure>
      #|<img src="b.png" alt="alt2">
      #|</figure>
      #|<aside class="footnote" id="fn-n1">
      #|<p>note</p>
      #|</aside>
      #|<hr class="page-break">
      #|
    ),
  )
}

///|
test "escape" {
  inspect(
    @render_html.escape("<a href=\"x\">&'</a>"),
    content=(
      #|&lt;a href=&quot;x&quot;&gt;&amp;&#39;&lt;/a&gt;
    ),
  )
}

///|
test "heading level is clamped" {
  let low : @ast.Document = {
    blocks: [@ast.Block::Heading(0, [@ast.Run::plain("x")])],
  }
  inspect(
    @render_html.render(low),
    content=(
      #|<h1>x</h1>
      #|
    ),
  )
  let high : @ast.Document = {
    blocks: [@ast.Block::Heading(9, [@ast.Run::plain("x")])],
  }
  inspect(
    @render_html.render(high),
    content=(
      #|<h6>x</h6>
      #|
    ),
  )
}

///|
test "table without header row and empty table" {
  let doc : @ast.Document = {
    blocks: [
      @ast.Block::TableBlock([
        @ast.TableRow::{
          header: false,
          cells: [[@ast.Block::Paragraph([@ast.Run::plain("c")])]],
        },
      ]),
      @ast.Block::TableBlock([]),
      @ast.Block::ListBlock(true, []),
    ],
  }
  inspect(
    @render_html.render(doc),
    content=(
      #|<table>
      #|<tbody>
      #|<tr>
      #|<td>
      #|<p>c</p>
      #|</td>
      #|</tr>
      #|</tbody>
      #|</table>
      #|<table>
      #|</table>
      #|<ol>
      #|</ol>
      #|
    ),
  )
}

///|
test (b : @bench.T) {
  let doc = sample_doc()
  b.bench(name="render html sample", fn() { b.keep(@render_html.render(doc)) })
}

///|
test "table with header row after the first row" {
  let doc : @ast.Document = {
    blocks: [
      @ast.Block::TableBlock([
        @ast.TableRow::{
          header: false,
          cells: [[@ast.Block::Paragraph([@ast.Run::plain("c")])]],
        },
        @ast.TableRow::{
          header: true,
          cells: [[@ast.Block::Paragraph([@ast.Run::plain("h2")])]],
        },
      ]),
    ],
  }
  inspect(
    @render_html.render(doc),
    content=(
      #|<table>
      #|<tbody>
      #|<tr>
      #|<td>
      #|<p>c</p>
      #|</td>
      #|</tr>
      #|<tr>
      #|<th>
      #|<p>h2</p>
      #|</th>
      #|</tr>
      #|</tbody>
      #|</table>
      #|
    ),
  )
}
