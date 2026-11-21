# JEDF アイデアドキュメント

> **Just Enough Document Format**  
> Repository: `maya0513/jedf`

## このドキュメントについて

この文書は、JEDF（Just Enough Document Format）の初期アイデアを整理したものです。

現時点では**仕様書ではありません**。  
将来の仕様策定に向けて、問題意識、設計原則、ユーザー体験、実装方針、未決事項などをまとめることを目的とします。

この文書は、検討と決定にあわせて随時更新します。決定した事項は「決定事項」に日付つきで記録し、未決定の論点は未決定のまま残します。

---

## 決定事項

### 2026-11-18

- **v0.1の範囲**：Semantic Treeの型定義、validator（構造とリソース上限の検証）、JSONとの往復変換、Flow表示の参照実装としてのHTML生成、Typstソース生成までとする。バイナリcontainer、圧縮、暗号化・署名、ブラウザviewer、画像デコードは初期版に入れず、意味木が固まった後に載る層として後段に回す
- **標準形式**：意味木を表す標準形式はJSONとする。意味木（AST）とシリアライズは分離し、JSONはその一表現とする。バイナリ表現が必要になった場合は、CBORを同じ木の別エンコーディングとして後付けする候補とする
- **インライン表現**：強調・リンクなどを入れ子のノードで表す方式は採らない。テキストの連なり（ラン）にマーク（強調、強い強調、コード、リンク先など）を付ける平坦な表現とする。範囲の重なりを構造として表現できなくすることで、コピーとanchorの扱いを単純にする
- **実装**：実装言語はMoonBitとする。MoonBitのツールチェーンにはタスクランナーが組み込まれていないため、複合的な確認手順（format、型検査、テスト等を束ねたもの）はjustで束ね、実体は`moon`のサブコマンドとする。ツールチェーンの版は更新対応中であり、完了後に版を固定する

### 2026-11-18 実装（v0.1）

v0.1の実装を行った。ツールチェーンは MoonBit 0.10.21+06da1ed44 に固定した（mise.toml）。パッケージ構成は `ast`（意味木の型）、`validate`（検証）、`codec`（JSON変換）、`render_html`、`render_typst`、`cli`（コマンドラインのロジック）、`cmd/jedf`（実行ファイル）とした。依存はライブラリ部分がMoonBit coreのみ、実行ファイルのファイル読み書きだけ `moonbitlang/x` の `fs` を使う。

実装にあたって決めたこと：

- **JSONスキーマ**：文書は `{"type":"document","version":1,"blocks":[...]}` とし、各ブロックは `type` で区別する（heading、paragraph、section、list、table、code、math、figure、footnote、page_break）。ランは `{"text": ...}` を基本形とし、マークがある場合のみ `marks` オブジェクト（emphasis、strong、code、math、link のうち既定値でないものだけ）を付ける。オブジェクトのキーの順序はスキーマで固定し、未知のキー、重複キー、未知のブロック種別はエラーとする
- **ノードの具体化**：Sectionは「見出しラン＋子ブロック」のコンテナとした。表は行の集まりとし、各行は `header` フラグとセル（ブロック列の列）を持つ。セル結合は入れない。コードブロックは独立ノードとした（テキストと言語名）。数式はTeXソースを不透明に保持し、ブロックは `MathBlock`、インラインはランへの `math` マークで表す。脚注は `FootnoteBlock`（idとブロック列）とした。画像は `FigureBlock`（src、alt、任意のキャプション）に含めた
- **validatorの上限値（既定値）**：深さ32、総ブロック数10000、ブロックあたりのラン数1000、1つのテキストのスカラー数100000、文書全体のテキストのスカラー数10000000、表の行数1000、列数100、リストの項目数10000。エラーは安定したコード（`limit.depth`、`structure.heading_level` など）と、ノードへのパス（`blocks[2].runs[0]` など）で返す。見出しレベルは1から6、図のaltが空でないこと、脚注idが空でなく重複しないことも構造規則とした
- **リンクのスキーム**：リンク先は相対参照とフラグメントを許可し、スキームを持つ場合は http、https、mailto のみ許可する（validatorの規則）
- **テキスト範囲の単位**：文字数の数え方と上限はUnicodeスカラー値単位とした（MoonBitのStringはUTF-16のため、コード単位数とは区別する）。Unicode正規化の方針は未決定のままとし、v0.1では正規化も検証も行わない
- **HTML生成**：文書全体ではなくフラグメントを返す。Sectionの見出しレベルは入れ子の深さから決める（最上位はh2）。表は先頭行がheaderの場合のみ `thead` に入れる。脚注は `aside` 要素とする。検証で弾かれる範囲外の見出しレベルは、生成側では1から6に丸める
- **Typst生成**：Sectionの見出しレベルはHTMLと同じ規則。脚注はTypstコメント＋内容のブロック列として出す。数式はTeXソースをそのまま `$...$` に入れる（Typstの数式記法とは互換でない場合がある）。コードブロックのフェンスは内容中のバッククォート列より長くする
- **CLI**：サブコマンドは `validate`、`to-html`、`to-typst`、`fmt`（標準形式への整形）。終了コードは、正常0、文書が不正1、使い方・読み込み・パースのエラー2。`to-html` と `to-typst` は生成前に検証し、不正な文書は生成しない
- **テストとベンチマーク**：ライブラリパッケージはテストカバレッジ100%（行単位、`moon coverage analyze` の未カバー行報告で確認）。実行ファイルの `main` は配線のみとし、実ファイルに対するエンドツーエンド実行で確認する。各パッケージにベンチマークを置き、`just bench` で計測する。検証用の文書コーパスは、当初 `fixtures` に置いたが、2026-11-22に廃止して `examples` に一本化した

未決定のまま残したもの：Unicode正規化の方針、スタイルシートの扱い、注釈（アノテーション）の範囲指定の単位と形式、拡張子とMIMEタイプ。

### 2026-11-22 実装判断の確定

- 「2026-11-18 実装（v0.1）」に記録した判断事項（JSONスキーマ、ノードの具体化、validatorの上限値、リンクのスキーム、テキスト範囲の単位、HTML生成、Typst生成、CLI、テストとベンチマーク、`preferred_target = "native"` とツールチェーンの固定）は、検討の結果、いずれも現行どおりで確定とした
- CIで使うMoonBitの版は、現行どおりGitHub Actionsでは公式インストーラの最新を使い、ローカルのmise固定版とずれる可能性を許容する（未決定から決定へ移した）
- カバレッジ100%の対象はライブラリパッケージとし、`src/cmd/jedf` の `main`（配線のみ）は対象外として、エンドツーエンド実行で確認する扱いを確定とした
- ディレクトリ配置を見直した。パッケージは `src/` 配下（`src/ast`、`src/validate`、`src/codec`、`src/render_html`、`src/render_typst`、`src/cli`、`src/cmd/jedf`）に移し、サンプル文書は `examples/` に置く。mizchiのMoonBitプロジェクト（sol.mbt、luna.mbt）の構成を参考にした
- ライブラリ6パッケージのテストをwasm-gcターゲットで実行し、全41件が通過した。§12のブラウザviewerの前提として、ライブラリがwasm上で動作することを確認済みとする
- 検証のターゲットは、型検査（`moon check`）を全ターゲット（all）、テスト実行をjsを除く全ターゲット（native、wasm、wasm-gc）とした。justfileとCIに反映済み
- 確定した形式の仕様を `docs/spec.md` に切り出した。この文書には思想と未決定の論点を残す
- ファイル拡張子は `.jedf`、MIME typeは `application/vnd.jedf+json` と決定した（未決定から決定へ移した）。`examples/` のサンプル文書も `.jedf` に改名した
- Unicode正規化の方針を決定した（未決定から決定へ移した）。正規化は行わず、テキストは書かれたまま保持し、同一性はUnicodeスカラー値の列で判定する。正規化は文書を書く側の関心事とする。分解済みのテキストがそのまま往復することをテストで固定した
- moon proveを本採用した。見出しレベルの丸め（1から6）を `src/level` に切り出して両描画から使い、結果の範囲を契約の証明で保証する。実行は `just prove`（mise経由でZ3を解決する）。GitHub ActionsのCIには入れていない
- ブラウザビューアを試作した。`src/web` の `render_document`（パース、検証、HTML描画をまとめた入口）をJSターゲットでコンパイルし、`viewer/` のページから使う。起動は `just viewer`。§12の将来段階ではWasm版が本命で、JSターゲットは試作の近道として使った
- コンテナ形式の最小設計を決定し、実装した（§13の将来案を前倒しした）。マジック `JEDF`、バージョンとマニフェスト長、JSONマニフェスト（チャンクの名前・長さ・FNV-1aハッシュ）、チャンク列の順序どおりの格納とし、先頭チャンクを標準形式の文書とする。仕様は仕様書§8。CLIに `pack` / `unpack` を追加した（`unpack` はアセットを取り出さない）。コンテナのファイル拡張子は未決定のまま残す
- CBOR符号化を実装した。標準形式と同じスキーマをCBORで表す第二の符号化で、メディアタイプは `application/vnd.jedf+cbor` とする。`src/codec_cbor` に符号化と復号を置き、CLIに `to-cbor` / `from-cbor` を追加した。仕様は仕様書§9
- コンテナのファイル拡張子を `.jedfc` と決定した（未決定から決定へ移した）。あわせて `unpack` でアセットも取り出せるようにした。取り出し先は文書の出力先のディレクトリで、ファイル名だけを使う。空の名前や `..` を含む名前は取り出さない
- ブラウザビューアのWasm化を試した。wasm-gcターゲットでは `use-js-builtin-string` 付きで `render_document` をエクスポートでき、ビルド自体は通る。しかし生成されたモジュールは定数プール（文字列と数値）を `_` というモジュールのグローバルとしてインポートする形で、現在のツールチェーンはそれを供給するローダを生成しないため、ブラウザやNodeでそのままインスタンス化できない。ビューアはJSターゲットのまま据え置き、Wasm版はローダの供給方法が整ってから再検討する
- ビューアで `.jedfc` コンテナを開けるようにした。`src/web` に `render_container` を追加し、ファイル選択とサンプルのボタンから開ける。コンテナから取り出した文書は、標準形式から開いた場合と同一のHTMLになることを確認した
- HTML描画の標準スタイルを定めた。ビューアのスタイルシートを標準スタイルとし、描画器は意味要素だけを出す。仕様書§6に記録した

---

## 1. 背景

PDFは、印刷結果やページレイアウトを異なる環境で再現するという目的において非常に優れています。

一方で、現代の電子文書として利用する場合には、次のような問題があります。

- テキストのコピー＆ペーストが壊れやすい
- 見た目上の配置と論理的な読み順が一致しないことがある
- 段組、合字、改行時のハイフンなどによってテキスト抽出が難しくなる
- 小さな画面では、1枚の紙面をズーム・スクロールしながら読む必要がある
- アクセシビリティのために、視覚表現とは別に構造情報を持たせる必要がある
- 長い歴史の中で非常に多くの機能を抱えており、安全な実装が難しい
- JavaScript、フォーム、添付ファイル、外部アクションなど、単純な「文書閲覧」には不要な機能まで扱う必要がある
- 「コピー禁止」「印刷禁止」のような権限制御が、暗号学的なセキュリティと混同されやすい

JEDFでは、PDFの「どこでも同じ紙面を表示・印刷できる」という利点を残しつつ、電子文書としての扱いやすさを改善したいと考えます。

---

## 2. JEDFの中心的な考え方

JEDFの基本方針として、次の3つを中心に据えます。

- **Semantic-first**
- **Inert-by-default**
- **Print-stable**

### Semantic-first

文書の本体は、ページ上の座標や描画命令ではなく、文章の意味構造とします。

たとえば、JEDF内部では次のような構造を持ちます。

```text
Document
 ├─ Heading
 ├─ Paragraph
 │   ├─ TextRun（marks: なし）
 │   ├─ TextRun（marks: 強調）
 │   └─ TextRun（marks: リンク）
 ├─ Figure
 │   ├─ Image
 │   └─ Caption
 ├─ Table
 ├─ Math
 └─ Paragraph
```

つまり、

> ページは文書そのものではなく、文書から生成される projection の一つ

と考えます。

インラインの装飾やリンクは、入れ子のノードではなく、テキストの連なり（ラン）へのマークとして表します（2026-11-18決定）。これにより、装飾範囲同士の重なりという、HTMLが抱えた種類の問題を構造の時点で表現できなくします。

### Inert-by-default

JEDF文書そのものは、原則としてプログラムを実行しません。

文書を開いただけで、

- JavaScriptを実行する
- 外部アプリケーションを起動する
- ネットワークアクセスを行う
- 任意コードを評価する

といった挙動は、JEDF v1では持たせない方針とします。

### Print-stable

画面閲覧ではリフロー可能な表示を採用しつつ、印刷時には安定した紙面レイアウトを生成できるようにします。

この部分ではTypstを活用します。

---

## 3. PDFから改善したい点

| 領域 | PDFで起きる問題 | JEDFで目指す方向 |
|---|---|---|
| テキスト | 描画結果と論理テキストが一致しない場合がある | Unicodeテキストそのものを文書の内容にする |
| 読み順 | 見た目と論理順序がずれる場合がある | 文書木の順序を唯一の読み順にする |
| コピペ | 段組、ハイフン、合字などで壊れやすい | 意味構造からコピーする |
| アクセシビリティ | タグ情報が不足すると構造を復元しにくい | 構造を必須にする |
| 小画面 | ページ全体のズームと横スクロールが必要 | 通常表示をリフロー対応にする |
| セキュリティ | 多機能で攻撃面が広い | 文書を原則passiveにする |
| 権限制御 | コピー禁止等がviewer依存 | 暗号学的セキュリティとは分離する |
| 実装 | 長い歴史により仕様が巨大 | 最小限の機能から設計する |
| 印刷 | 非常に強い | Typstを利用して維持する |

---

## 4. 表示モデル

JEDFでは、ひとつの文書に対して少なくとも2種類の表示方式を持たせることを検討します。

## 4.1 Flow View

ブラウザやスマートフォンなどで読むための標準表示です。

特徴:

- 画面幅に合わせてリフローする
- 原則としてページ境界を持たない
- スマートフォンでは1カラム
- デスクトップでは読みやすい最大幅を設定可能
- HTMLやEPUBに近い読書体験
- ズームを前提としない

イメージ:

```text
JEDF Semantic Document
        │
        ├── Flow View
        │     └── Browser / Mobile
        │
        └── Print Layout
              └── Typst
                    ├── Page View
                    ├── PDF Export
                    └── Printer
```

## 4.2 Page View

印刷結果や固定ページとしての見た目を確認するための表示です。

用途:

- 印刷プレビュー
- PDF的な紙面閲覧
- 「何ページ目」という参照
- 紙面上でのレイアウト確認

通常の読書ではFlow Viewを使い、必要な場合のみPage Viewに切り替える構成が理想です。

なお、v0.1で作るFlow表示は、ブラウザviewerそのものではなく、意味木からHTMLを生成する参照実装までとします（2026-11-18決定）。

---

## 5. ページ番号を文書のアイデンティティにしない

リフロー表示と固定ページ表示を共存させる場合、注釈や選択範囲をページ座標に紐付けると問題が発生します。

避けたい例:

```text
page = 7
x = 128
y = 392
```

代わりに、意味構造上のノードへ紐付けます。

```text
node = paragraph:01JEDF...
range = chars 43..81
```

この方式なら、同じ注釈を、

```text
Flow View
  → 本文中の該当箇所

Page View
  → レイアウト後の該当箇所
```

として表示できます。

文書中の位置は、ページ番号ではなく、semantic nodeとテキスト範囲で表現します。

---

## 6. コピペビリティ

JEDFの主要なユーザー体験の一つとして、優れたコピー＆ペーストを重視します。

### 基本原則

コピー処理は、画面上に描画されたglyphや座標から逆算しません。

代わりに、JEDFのsemantic treeから直接テキストを取得します。

たとえば画面上で、

```text
inter-
national
```

と折り返されていても、内部データは、

```text
international
```

です。

改行用のハイフンはレンダラによる表現なので、コピーされません。

同様に、フォント上で`fi`が合字`ﬁ`として表示されていても、コピーされる文字列は元の`fi`とします。

段組の場合も、コピー順序は画面上の座標ではなく文書木の順序に従います。

### Clipboardへの複数形式出力

コピー時には、複数のMIMEタイプを同時に提供できます。

例:

```text
text/plain
text/html
application/x-jedf-fragment
```

これにより、

- テキストエディタへ貼り付ける → プレーンUnicode
- Webエディタへ貼り付ける → 構造付きHTML
- JEDF対応エディタへ貼り付ける → 数式、リンク、表などを保持

といった動作が可能になります。

---

## 7. セキュリティ

JEDFでは、機能追加によって安全性を作るのではなく、不要な機能を持たないことで攻撃面を減らします。

### v1で持たせない候補

- JavaScript
- 任意コード実行
- Launch executable
- 自動フォーム送信
- 文書オープン時の自動アクション
- 任意ネットワークアクセス
- 任意ファイル添付
- マクロ
- プラグイン

リンクについては、単なる宣言データとして扱います。

例:

```text
https://example.com
mailto:example@example.com
jedf:#section-id
```

実際にリンクを開くかどうかはviewer側が判断します。

---

## 8. 「コピー禁止」とセキュリティを分離する

「閲覧できるがコピーだけは絶対にできない」という状態は、一般的な文書viewerにおいて強い保証が難しいものです。

表示可能な文書は、どこかの段階でユーザーの端末上に内容が存在します。

そのためJEDFでは、「コピー禁止」や「印刷禁止」を強いセキュリティ機能として扱わない方針を検討します。

JEDFで保証したいセキュリティは、主に次の3つです。

### Confidentiality

許可されたユーザーだけが内容を読めること。

### Integrity

文書が改ざんされた場合に検知できること。

### Authenticity

文書が誰によって署名されたものか検証できること。

イメージ:

```text
暗号化されていて鍵がない
  → 読めない

署名後に1bit変更された
  → 検出できる

特定の署名鍵によって署名された
  → 検証できる
```

ただし、暗号化と署名はv0.1の範囲には含めません（2026-11-18決定）。上記3点は、意味木と標準形式が固まった後に載せる層の目標として位置づけます。
---

## 9. Typstの役割

TypstはJEDF内部で実行される言語にはせず、**印刷・ページ組版のbackend**として利用することを想定します。

避けたい構成:

```text
document.jedf
  └─ main.typ
```

この方式では、JEDF文書を開く行為がTypstコードの評価と結びつきます。

代わりに、

```text
JEDF
  ↓
trusted JEDF → Typst generator
  ↓
Typst
  ↓
Print / PDF
```

とします。

コンパイラに例えると、

```text
source language
  ↓
IR
  ↓
backend
```

のような関係です。

JEDFのsemantic treeがIRに相当し、Typstは高品質なページ組版backendとして使います。

---

## 10. Flow表示とTypst表示を分離する

JEDFのFlow Viewを、そのままTypstのHTML出力へ依存させる必要はありません。

むしろ、

```text
JEDF Semantic Tree
   ├── Flow Renderer
   │      └── DOM / browser layout
   │
   └── Print Renderer
          └── Typst
```

という構成が望ましいと考えます。

Typstは紙面組版に強く、ブラウザ側ではWebのレイアウトシステムを活用できます。

---

## 11. SVGなどの視覚層と意味層を分離する

紙面表示にSVG等を利用する場合でも、そこからテキスト情報を復元しようとはしません。

考え方:

```text
Typst SVG
  = 視覚層

JEDF AST
  = 意味・テキスト層
```

選択、コピー、検索、アクセシビリティなどはJEDF AST側の情報を利用します。

---

## 12. MoonBit + WebAssembly

JEDFの実装にはMoonBitを使用します。v0.1の実装範囲はMoonBitのライブラリとCLIまでとし、WebAssemblyとブラウザviewerは将来の段階とします（2026-11-18決定）。

将来のブラウザ実装のイメージ:

```text
┌──────────────── Browser ────────────────┐
│                                         │
│  TypeScript / small JS shell            │
│        │                                │
│        ▼                                │
│  jedf.wasm  ← MoonBit                   │
│    ├ parser                             │
│    ├ validator                          │
│    ├ semantic tree                      │
│    ├ codec（JSON）                      │
│    ├ selection                          │
│    └ flow-layout adapter                │
│        │                                │
│        └──── DOM / browser              │
│                                         │
│  Typst engine / typst.wasm              │
│        │                                │
│        └──── print preview / export      │
└─────────────────────────────────────────┘
```

JEDF本体とTypstエンジンを分離することで、JEDF parserの信頼境界を小さくできます。

### 実装方針（2026-11-18決定）

- パッケージは、意味木の型定義、validator、JSONとの往復変換、HTML生成、Typst生成、CLIに分ける
- 依存は初期版ではMoonBit coreとUnicode処理のライブラリに絞る
- 品質確認は`moon fmt`、`moon check --deny-warn`、`moon test`（スナップショットテストとQuickCheckによる性質テストを含む）、`moon coverage`、`moon info`の差分確認を基本とし、複合手順はjustで束ねる
- parserは、不正な入力に対してpanicせず、エラーとして返すことを性質テストで確認する

---

## 13. ファイル形式の方向性

v0.1の標準形式は、意味木を表すJSONとします（2026-11-18決定）。人が読めて差分を確認できることを優先し、意味木とシリアライズを分離します。ファイル拡張子は `.jedf`、MIME typeは `application/vnd.jedf+json` とします（2026-11-22決定）。

### 将来案: chunk-based container（初期版の対象外）

画像やフォントなどのバイナリを含む単一ファイルが必要になった場合に備え、単純なchunk-based containerにする案があります。これは初期版では作らず、意味木と標準形式が固まった後に改めて検討します。

2026-11-22に最小設計を決定し、先行して実装しました。決定事項の2026-11-22の節と、仕様書の「8. コンテナ形式」を参照してください。

イメージ:

```text
JEDF HEADER
version
flags

MANIFEST
  document metadata
  chunk index
  hashes

CHUNK semantic-tree
CHUNK stylesheet
CHUNK image-001
CHUNK font-001
CHUNK print-cache
CHUNK signatures
```

各chunkには、たとえば次の情報だけを持たせます。

```text
type
compressed-size
uncompressed-size
compression
hash
offset
```

この構成により、

```text
文書を開く
  → manifestとsemantic treeを読む

画像が必要になる
  → 該当chunkのみ読む

印刷する
  → print関連データを読む
```

といった遅延読み込みが可能になります。

HTTP Range Requestとも相性が良い構成を目指せます。

---

## 14. parserの堅牢性

JEDFでは、不正データへの耐性を実装依存にしすぎないことが重要です。

仕様レベルで上限を設けることを検討します。

例:

```text
最大tree depth
最大node数
最大文字列長
最大画像pixel数（宣言値に対する上限）
最大chunkサイズ（container導入時）
最大展開後サイズ（圧縮導入時）
最大圧縮率（圧縮導入時）
最大埋め込みfont数（font埋め込み導入時）
```

異常に巨大な値は「実装側でなんとか処理する」のではなく、JEDFとしてinvalidとします。

---

## 15. JEDF v0.1の設計原則案

初期版では、次の原則を強く保つことを検討します。

1. 文書は必ずsemantic treeを持つ
2. 描画結果だけで構成された文書を許可しない
3. Unicodeテキストそのものを文書の内容とする
4. glyphは文字情報そのものとして扱わない
5. 標準viewerはFlow Viewを基本とする
6. Page View / Print Viewを別表示モードとして持つ
7. 注釈、リンク、選択範囲はsemantic nodeへanchorする
8. TypstコードをJEDF文書内で直接実行しない
9. JEDF→Typstの一方向変換を基本とする
10. JavaScript、macro、plugin、任意コード実行を持たない
11. 任意ファイル添付を初期仕様では持たない
12. 暗号化・署名は初期版では扱わない。導入する場合は既存の標準暗号方式を利用する
13. 独自暗号アルゴリズムを作らない
14. 「コピー禁止」を強いセキュリティ機能として扱わない
15. PDF exportを重要な互換出口として扱う
16. 標準形式はJSONとし、意味木とシリアライズを分離する
17. インラインの装飾とリンクは、入れ子のノードではなくマーク付きのランで表す

---

## 16. Semantic Treeの初期候補

JEDF v0.1では、まず通常の文書に必要な最小限のノードから始めます。

候補:

```text
Document
Section
Heading
Paragraph
TextRun（inline。marksとして強調、強い強調、コード、リンク先などを持つ）
List
ListItem
Table
TableRow
TableCell
Figure
Image
Caption
Math
Footnote
PageBreakHint
```

インライン要素は独立したノードにしません（2026-11-18決定）。`Emphasis`、`Strong`、`Code`、`Link`にあたるものは、すべて`TextRun`のマークとして表します。

コードブロックのように、インラインのコードとは別扱いが必要なブロック要素が要るかどうかは未決定です。

このレベルの構造を最初に確定させ、その表現を標準形式（JSON）で決めます。binary encodingやcontainer仕様は後段で決めます。

---

## 17. 自由配置について

JEDFの思想を崩しやすい要素として、以下があります。

```text
absolute position
x / y coordinate
z-index
freeform canvas
```

これらを通常文書の構造と混在させると、PDFと同様に「見た目上の配置が文書の本体」へ戻ってしまう可能性があります。

そのため初期バージョンでは、

> 通常文書と自由配置キャンバスを混ぜない

という方針が有力です。

JEDF v1では通常文書に集中し、必要になった場合のみ別の仕組みとして自由配置を検討します。

---

## 18. JEDFで目指すユーザー体験

理想的には、ユーザーはJEDFをPDFに近い感覚で扱えます。

### 開く

```text
ファイルをダブルクリック
→ viewerで表示
```

### 読む

通常はWebページのように自然にスクロールします。

ズームや横スクロールを基本操作にしません。

### コピーする

普通に範囲選択してコピーすれば、

- 不要な改行が入らない
- 段組順序が壊れない
- 合字で文字化けしない
- 数式や表を対応アプリへ構造付きで貼り付けられる

状態を目指します。

### 印刷する

```text
Print
  ↓
JEDF → Typst
  ↓
ページ組版
  ↓
プリンタ / PDF
```

として、安定した紙面を生成します。

### 検索する

OCRや描画解析ではなく、semantic tree内のUnicode文字列を検索します。

### アクセシビリティ

見出し、段落、表、画像、キャプション等の意味構造が文書形式そのものに含まれるため、viewerが後から推測する必要を減らします。

---

## 19. JEDFの位置づけ

JEDFは、PDFとHTMLの中間のようなものではありますが、単純な折衷ではありません。

概念的には、

```text
PDF
  → visual-first
  → fixed page

HTML
  → semantic-first
  → flow layout
  → interactive / executable ecosystem

JEDF
  → semantic-first
  → flow layout
  → deterministic print projection
  → passive document
```

という位置づけを目指します。

---

## 20. 今後決める必要があること

このドキュメントでは、意図的に詳細仕様を確定していません。

今後検討すべき主要項目:

- Semantic Treeの正式なノード一覧
- block nodeの一覧と区別（inlineはラン方式で決定済み）
- IDの形式
- annotation anchorの仕様
- text rangeの表現方法（単位の候補は提示済みだが未決定）
- Unicode normalization方針（行わないことで決定、2026-11-22）
- bidi対応
- ruby対応
- 縦書き対応
- 数式表現（独自にパースしない候補は提示済みだが未決定）
- 表の構造（セル結合を入れない候補は提示済みだが未決定）
- 脚注・引用・参考文献
- 画像フォーマット
- font embedding
- stylesheetの表現方法（任意のスタイルを持たせない候補は提示済みだが未決定）
- Flow Viewの標準スタイル
- Page Viewとの差異
- JEDF→Typst変換規則
- ページ番号と内部参照の扱い
- PDF export時のtagged PDF生成
- 暗号化方式（初期版の対象外）
- 電子署名方式（初期版の対象外）
- container format（初期版の対象外、後段で検討）
- compression format（初期版の対象外、後段で検討）
- streaming / random access
- versioning
- forward compatibility
- parser resource limits
- MIME type
- file extension
- magic bytes

---

## 21. 最初に決めるべきもの

binary encodingを先に決めるのではなく、まず**JEDF Semantic Tree v0.1**を決めるべきです。

優先順位としては、

```text
1. JEDFの設計原則
2. Semantic Tree
3. 標準形式（JSON）での表現
4. Flow Viewの意味論
5. Print Viewへの変換規則
6. Security model
7. Container / Binary format（後段）
```

の順がよいと考えます。

特に、

> 何を表現できるか

だけではなく、

> 何を表現できないようにするか

を早い段階で定義することが、JEDFの「Just Enough」という思想を守るうえで重要です。

---

## 22. 現時点での短い定義

JEDFを一文で表すなら、次のようになります。

> **JEDF is a semantic-first, passive document format with reflowable reading and deterministic print projection.**

日本語では、

> **JEDFは、意味構造を文書の本体とし、リフロー可能な閲覧と決定的な印刷表現を両立する、受動的な文書形式である。**

という表現が近いと考えます。

---

## 23. 現時点での最重要原則

JEDFの方向性を最も端的に表す原則は、次の4点です。

```text
Text is data, not drawing.

Structure is mandatory.

Pages are a projection, not the document.

Documents do not execute code.
```

日本語では、

```text
文字は描画ではなくデータである。

構造は必須である。

ページは文書そのものではなく、文書から生成される表現である。

文書はコードを実行しない。
```

となります。

この原則を維持できるかどうかを、今後の機能追加判断の基準とします。
