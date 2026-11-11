# Button 按钮文档设计图生成提示词

使用 Codex 内置 ImageGen 生成。桌面端与移动端各有浅色展开、浅色折叠、暗色展开三张。后续状态以同端的浅色展开图为视觉参考。

## 浅色展开的共同提示词

```text
Create ONE high-fidelity ui-mockup: a screenshot of a Flutter developer documentation detail page for El UI, based on a real shippable app. The raster canvas is entirely the live product viewport, edge to edge, crisp flat front view. No device bezel, frame, collage, ads, illustration, annotations, watermark, gradients or shadows. Calm, clean documentation with practical whitespace. Use modern Noto Sans SC / Inter UI typography, strong clear heading hierarchy, regular paragraphs, subtle separators, consistent left alignment. Every visible UI label must be verbatim legible Chinese. Blue is used sparingly for button variants and navigation selection.

Content hierarchy at the top of the body, in this exact order. H1 "Button 按钮", bold. Intro paragraph "常用的操作按钮，支持实心、描边、文字、链接与图标等外观。" Then H2 "基础使用", bold but clearly smaller than H1. Small regular sentence "比较实心、描边和文字按钮。" Next a single full-body-width example card with restrained 12 px corners and thin neutral border. Stage is a white panel with three short blue buttons all labeled "Hello": solid filled blue with white text, blue outline, plain blue text. They share one left-aligned row, simple compact rounded rectangles with equal visual height and clear gaps. Next a full width 44 px control row in the card, a thin top separator, ONLY a centered small upward chevron for the expanded state. No visible label on the control in its idle state. Immediately under this light control, the expanded source is joined flush to all edges of the card, only the two bottom corners rounded. The dark source is a flat, uniform Atom One Dark #282C34. Consolas-style 14 px monospace with 1.7 line height, 20–24 px inner padding. Match the exact syntax colors: Widget name #E5C07B, named args #61AFEF, strings #98C379, default text and punctuation #ABB2BF. Code has no toolbars, filename tabs, labels, line numbers, copy icons or line separators. Render exactly this six-line snippet, with only one snippet:
ElButton(
  type: .primary,
  variant: .outline,
  onPressed: () {},
  child: 'Hello',
)
After the card, if space permits, the next H2 "自定义颜色" and a small gray sentence "通过主题设置按钮颜色。" appear in normal document flow, with a generous section gap. Focus on readable authentic Chinese and perfectly formed monospace code. All chrome is part of a real product viewport.
```

## 桌面布局

```text
DESKTOP landscape viewport with a composition close to a 1440×900 UI, landscape canvas. Light theme. Fixed slim white top bar spans the viewport with a blue outlined layers icon and label "Button 按钮" aligned left, hairline rule underneath. Below the bar, build a sober three-column layout: 260 px left white component nav, center reading column with 32 px side padding and a readable 730–840 px width, and a right-side approximately 168 px unobtrusive "本页目录". Keep side nav visibly distinct with a vertical hairline. Only use these left labels: "组件", "基础", "Button 按钮", "Icon 图标", "表单", "Input 输入框". Highlight "Button 按钮" with blue and a faint blue row background. The right column lists only "基础使用", "自定义颜色", "禁用按钮", with "基础使用" in blue. Typography approximate actual UI scale: H1 30 px, H2 22 px, body 14–15 px. Main column begins around 25 px below header. Keep vertical rhythm, no large hero gap, enough room for full first card. Desktop theme blue #409EFF.
```

## 移动布局

```text
MOBILE portrait canvas, a composition close to a 390×844 phone viewport, full edge-to-edge screenshot of the app. Light theme. A modest native top title bar, with back arrow at left and "组件文档", followed by a single scrollable reading column with 16 px side margins. A small status bar and bottom safe area are appropriate. The detail screen has no sidebar, bottom nav, sticky CTA or right table of contents. H1 28 px, H2 21–22 px, body 14–15 px, generous readable line height. Keep the three Hello buttons in one row within the card. The full dark source panel is visible at comfortable reading size, and "自定义颜色" appears below when there is room. Use mobile theme blue #1076FD.
```

## 浅色折叠

```text
Create one high-fidelity ui-mockup by editing the attached reference screenshot, which is the expanded-state view of the same page. The new screenshot shows that same document with the "基础使用" code example collapsed. Remove its entire dark Atom One Dark panel so that the first white card ends immediately after its slim light 44 px toggle row and has its normal 12 px rounded white bottom corners. Rotate the small centered chevron to point DOWN. The down chevron alone is the idle toggle. Retain the stage with exactly three "Hello" buttons in the same row. Reflow the next section "自定义颜色" and its paragraph "通过主题设置按钮颜色。" upward into the space released by collapsing. Keep the same regular section gap between the bottom edge of the card and this next H2. Preserve the outer viewport dimensions and placement, white palette, nav, clear bold H1 "Button 按钮", H2 "基础使用", all existing Chinese text and visual sizes. Render all the existing Chinese faithfully. Maintain all left and right margins and columns from the reference. The canvas shows one edge-to-edge actual UI screenshot.
```

## 暗色展开

```text
Create one high-fidelity ui-mockup by editing the attached reference screenshot into the DARK THEME of the same El UI developer documentation page. This is a color/theme change only. Preserve screen proportions, top bar, sidebars or lack thereof, all exact Chinese text, layout, button variants and size, stage, document sections and the already expanded state. The page and chrome are flat neutral near-black #141414 / #191919, with thin charcoal boundaries. Use high contrast off-white #F2F2F3 for H1 and H2 and subdued readable light gray #B4B4BC for paragraphs. Selected nav row a muted deep blue with legible soft blue text. Card stage and toggle row are neutral charcoal #202127, the border is #2E2E32, and the three Hello buttons remain the same three blue variants with accessible contrast. The 44 px control row has only a centered small UP chevron. The source is a solid uniform flat slate rectangle at the very bottom of the card, ONLY its two bottom corners rounded. Match true Atom One Dark #282C34 with syntax colors Widget #E5C07B, named parameters #61AFEF, string #98C379, punctuation and plain text #ABB2BF. Dark code panel must be subtly lighter and bluer than the surrounding stage. Retain its roomy inset and Consolas-style monospaced text. No decorative effects, line numbers, code toolbars, file labels, shadows, gradients or added text. Render this exact original six-line snippet with straight quotes and clear indentation:
ElButton(
  type: .primary,
  variant: .outline,
  onPressed: () {},
  child: 'Hello',
)
Maintain the viewport as a real edge-to-edge static screenshot with crisp text and easy visual hierarchy.
```

两种状态都附带对应的视口约束。

```text
Desktop — Keep the landscape desktop three-column viewport.
Mobile — Keep the narrow portrait phone viewport with a back arrow and single content column.
```

## 桌面目录校正

```text
Use case: precise-object-edit. Edit the RIGHT sidebar heading of this desktop product UI screenshot. The existing heading at the top of the rightmost column has four glyphs. Make it a SHORT TWO-CHARACTER label: 目录. Display exactly “目录” as the heading, left aligned to the entries below, same size and same color. This is a deliberate title change to the common short Chinese word for Contents. There are exactly TWO Chinese characters in the new heading. First character 目, second character 录. Erase the two extra preceding glyphs from the old heading so the title visibly occupies approximately half of its old width. Retain the three subsection links as shown. Everything outside that small heading is exactly the same screenshot with the same light or dark mode, same code state, same layout, exact colors and text. Output one full unframed UI screenshot.
```

## 手机正文换行校正

```text
Use case: precise-object-edit. Refine only the intro paragraph directly below the big “Button 按钮” heading. Use two lines of normal-size, regular weight Chinese text with relaxed reading line height, both lines left-aligned with the heading at the existing inset. This is a deliberate line break in the same paragraph. Use the exact Chinese and punctuation:
常用的操作按钮，支持实心、描边、
文字、链接与图标等外观。
Do not add any extra text and do not stretch or condense the type. The paragraph should use the existing theme's secondary text color and have breathing room above “基础使用”. Preserve the rest of the supplied portrait screenshot precisely, including the navigation, H1, H2, spacing, phone screenshot viewport, all button labels and states, the chevron orientation, and the appearance and presence or absence of the Atom One Dark code area. Output the complete screenshot.
```