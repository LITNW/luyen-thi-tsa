# LIT — Proposed Design System (Review Draft)

**Status:** Proposal only; not implemented
**Applies to:** Current PR #41 baseline and all React/legacy surfaces when separately approved
**Visual direction:** Dark-first, Neo-brutalist × Editorial Tech × data-informed; strong hierarchy and angular geometry with restrained electric blue.

## Design principles

1. **Make the next action obvious.** Use clear hierarchy, stable navigation and distinct selected, hover, focus, disabled, loading, success, warning and error states.
2. **Treat learning/admin data as content.** Use tables, labels, counts and explanations only when backed by real data. No fabricated progress, rankings or charts.
3. **Keep the education model visible.** THPT is level → course; University is level → category → course. Categories are Admin-managed. `unclassified` remains valid and uncategorized courses are not auto-assigned.
4. **Use strong, quiet surfaces.** Dark canvas, layered panels, fine borders and limited accent. Avoid gradients, glass effects, decorative glow, pill controls and excessive card grids.
5. **Keep controls usable at every size.** Touch targets, visible keyboard focus, semantic labels and non-color cues are required, not polish.

## Starting color tokens

These are proposed starting values from the approved brief. Contrast values below were calculated using WCAG relative luminance and rounded to two decimals. Do not inline arbitrary colors per screen. The initial border token is intentionally subtle and must not be the sole boundary for essential controls.

| Semantic token | Proposed value | Usage |
|---|---:|---|
| `--color-canvas` | `#080D18` | Global page background |
| `--color-surface` | `#111B2B` | Primary panels, navigation |
| `--color-surface-raised` | `#172438` | Selected/raised panels and menus |
| `--color-border-subtle` | `#29384D` | Decorative separators only; not the sole boundary of essential controls |
| `--color-text-primary` | `#F4F7FF` | Main text |
| `--color-text-secondary` | `#A8B8D0` | Supporting text; confirm AA at actual size/weight |
| `--color-accent` | `#168BFF` | Primary action, selected marker, links |
| `--color-accent-hover` | `#43A5FF` | Hover only; selected state must remain obvious without hover |
| `--color-success` | `#32D6A0` | Success and completed states |
| `--color-warning` | `#FFC857` | Caution and pending states |
| `--color-danger` | `#FF5364` | Destructive/error states |
| `--color-focus` | `#7CC4FF` | High-visibility focus outline; pair with offset/contrast surface |

For selected controls, combine accent border/fill with an icon, weight or explicit label. Do not rely on hue alone. Error/help text must remain readable and associated with fields. Confirm contrast for disabled controls and muted secondary copy against each actual surface.

## Type

- Use one robust UI sans family for Vietnamese and Latin glyph coverage; candidate: Inter, subject to repository asset/license and self-hosting review.
- Optional display face: a geometric family such as Space Grotesk for short headings only, after checking Vietnamese diacritics. Do not use a second family for dense tables/forms.
- Type scale proposal: 12/16px metadata, 14/20px compact labels, 16/24px body, 20/28px section, 28/36px page title, 40/48px landing headline. Use `rem` and responsive clamps for display text.
- Use tabular numerals for scores, IDs and counts; preserve readable line height for Vietnamese diacritics and mathematical content.
- Keep uppercase styling to short codes/eyebrows. Do not uppercase long Vietnamese sentences.

## Layout and geometry

- Content grid: 12 columns on wide viewports, 8 at tablet, 4 at mobile; consistent gutters and max-width around 1440px as a proposal.
- Spacing scale: 4, 8, 12, 16, 24, 32, 48, 64, 96px. Favor consistent vertical rhythm over per-page spacing inventions.
- Breakpoint starting points: 600px (small/mobile), 800px (tablet), 1024px (desktop shell), 1280px (wide). Validate at 360, 390, 768, 1024, 1440px; allow content-driven exceptions for exam/editor surfaces.
- Radius: 0–4px for controls and panels; 6px maximum for functional overlays where it helps. No pill-shaped controls. Use borders and layout rather than shadows to express hierarchy.
- Admin lists may become stacked labeled rows on small screens; do not squeeze dense data tables into unreadable columns.

## Components and states

- **Application shell:** shared header/navigation, content frame, breadcrumbs where hierarchy matters, account menu and responsive navigation. Keep exam session chrome task-focused.
- **Buttons:** primary, secondary, quiet, destructive; explicit size and icon-only label contract. Disabled/loading states retain legible copy and avoid accidental double submission.
- **Selection controls:** selected/unselected distinction visible at rest; hover, `:focus-visible`, disabled and error states; keyboard operation; non-color marker.
- **Fields:** label, optional hint, validation/error association, required indication and pending state. Category code helper explains `2–64` ASCII characters, starts `a–z`, remainder `a–z`, `0–9`, `_`.
- **Lists/data tables:** align numeric data, retain labels on mobile, disclose archived/hidden/locked items, and explain why an action is unavailable.
- **Dialogs/destructive actions:** accessible name/description, initial focus and focus return, Escape behavior when safe, explicit cancel/confirm labels, busy lockout and server error feedback. Do not use confirm dialogs as a substitute for server authorization/constraints.
- **Empty/loading/error:** consistent layout and recovery action; never silently drop meaningful failure.
- **Education delete safeguards:** preserve category/course guard behavior from PR #41; frontend confirms intent while database remains authoritative. No cascade of exams/history/attempts/answers/results.
- **Math/exam content:** preserve equation readability and exam timer/answer interaction; provide fallback content if external math rendering fails.

## Motion and accessibility

- Target WCAG 2.2 AA for text, controls, focus, keyboard and reflow. Verify contrast programmatically and manually for every semantic pair.
- `:focus-visible` ring: at least 2px with offset and contrast against both light content exceptions and dark surfaces; apply consistently to links, buttons, inputs, selects, textareas and custom widgets.
- Never encode selected, error, completion or status solely through color.
- Support reduced motion globally, including legacy; avoid motion that hides status or blocks interaction.
- Preserve semantic heading order, landmarks, accessible names, live-region status feedback and dialog keyboard behavior.
- Minimum interactive target: aim for 44×44 CSS px where practical; ensure adjacent controls remain separable on touch.

## Data visualization

There is no chart library in the inspected dependency manifest. Charts are optional and must not be introduced as a visual motif. Use only verified product data, label its time range and denominator, and provide accessible table/text equivalents. For current score/result surfaces, prioritize clear numeric summaries before charts.

## Theme and legacy strategy

The proposal replaces the current mixed default light/dark presentation with a cohesive dark-first system. Existing LIT logo assets and brand recognition remain. During migration, avoid a big-bang rewrite: React tokens/shell first, then route groups, then legacy exam/editor. A single token reference should be consumable by legacy CSS without changing its business logic. Any light reading surface is an explicit semantic exception and must meet the same contrast standard.

## Approval gate

Review these tokens, typography, geometry and screen principles before UI implementation. After approval, complete the required product-truth interview/context before defining the implementation's visual world. Do not treat this proposal as an approved final palette or as implementation evidence.

## Contrast verification matrix

Ratios use the WCAG 2.x contrast formula on the sRGB hex values. Normal text needs at least 4.5:1; large text needs 3:1. Essential control boundaries and focus/state indicators should reach 3:1 against adjacent colors. Disabled controls are still kept readable here rather than relying on a low-opacity exception.

| Foreground / state | Background | Contrast | Decision |
|---|---|---:|---|
| Primary text `#F4F7FF` | Canvas `#080D18` | 18.13:1 | Pass |
| Primary text `#F4F7FF` | Surface `#111B2B` | 16.12:1 | Pass |
| Primary text `#F4F7FF` | Raised `#172438` | 14.56:1 | Pass |
| Secondary text `#A8B8D0` | Canvas `#080D18` | 9.65:1 | Pass |
| Secondary text `#A8B8D0` | Surface `#111B2B` | 8.58:1 | Pass |
| Secondary text `#A8B8D0` | Raised `#172438` | 7.75:1 | Pass |
| Accent text/link `#168BFF` | Canvas `#080D18` | 5.71:1 | Pass |
| Accent text/link `#168BFF` | Surface `#111B2B` | 5.08:1 | Pass |
| Accent text/link `#168BFF` | Raised `#172438` | 4.59:1 | Pass, narrowest text pairing |
| Hover accent `#43A5FF` | Canvas `#080D18` | 7.46:1 | Pass |
| Success `#32D6A0` | Surface `#111B2B` | 9.27:1 | Pass |
| Warning `#FFC857` | Surface `#111B2B` | 11.23:1 | Pass |
| Danger `#FF5364` | Surface `#111B2B` | 5.49:1 | Pass |
| Focus `#7CC4FF` | Raised `#172438` | 8.32:1 | Pass |
| Strong border `#60748F` | Canvas / surface / raised | 4.06 / 3.61 / 3.26:1 | Pass for essential outlines |
| Subtle border `#29384D` | Canvas / surface / raised | 1.63 / 1.45 / 1.31:1 | Fail as sole control boundary; decorative only |
| White `#FFFFFF` on accent `#168BFF` | Accent fill | 3.40:1 | **Fail for normal text**; do not use white text here |
| Dark ink `#080D18` on accent `#168BFF` | Accent fill | 5.71:1 | Pass; use for accent-filled primary buttons |

For action controls, use `--color-border-strong: #60748F` where an outline communicates a control boundary. Keep `--color-border-subtle` for nonessential dividers. The existing accent blue is suitable as text on the specified dark surfaces, but white foreground on the blue button fails normal-text contrast; use dark ink text or a separately tested darker action fill. Status text should sit on dark surfaces, not directly on saturated success/danger fills. Use a status icon/label in addition to color.

## Typography specimens

Use specimens to check scale, glyph support and wrapping. Any bracketed data remains a placeholder and must be replaced with a real value only when rendered with actual product data.

| Surface | Specimen | Proposed style | Acceptance |
|---|---|---|---|
| Homepage headline | `Chuẩn bị tốt hơn. Bứt phá giới hạn.` | Display face, 40/48px desktop; clamp to 32/38px mobile; 600–700 weight | Vietnamese diacritics remain intact; line break is intentional; no clipped CTA nearby. |
| Dashboard metric | `{giá trị thật}` / `Cấp học đã chọn` | UI sans, 32/38px tabular numerals for the value; label 14/20px | Value is not fabricated; label remains associated; no metric card implies unsupported progress. |
| Exam title | `[Tên đề đã xuất bản]` | UI sans, 24/32px desktop; 20/28px mobile; 600–700 weight | Long Vietnamese titles wrap without colliding with duration/question metadata. |
| Admin table | `Môn học` / `Trạng thái` / `Thao tác` | UI sans, 14/20px; headers 12/16px 600 weight, sentence case | Labels remain legible at 200% zoom and mobile row conversion retains field names. |
| Vietnamese body text | `Chọn môn học để xem các bài thi đã xuất bản.` | UI sans, 16/24px, regular | Test `ă â ê ô ơ ư đ` and all tone marks; paragraph line length and wrapping remain comfortable. |
| Mathematical content | `x² + 2x + 1 = 0` | MathJax/semantic math rendering; 18/28px equivalent body size | Baseline, superscripts, symbols and fallback text remain readable; no horizontal page overflow. |

Inter remains a candidate, not a verified bundled font. Before implementation, inspect actual font assets and license, test Vietnamese glyph coverage, and choose one UI family. A display family is optional and must pass the same glyph test. Do not load a new external font dependency without checking its availability and runtime implications.

## Interaction state contract

| State | Visual contract | Behavior and accessibility |
|---|---|---|
| Selected/active | Accent border or rule plus persistent fill/weight/check marker; visible without hover | State is also exposed semantically (`aria-current`, `aria-pressed`, selected option, etc. as appropriate); never color alone. |
| Hover | Modest surface/accent shift and pointer where actionable | Hover cannot be the only selected/focus signal; preserve contrast. |
| `:focus-visible` | At least 2px `#7CC4FF` outline with 2px offset; add dark separation where backgrounds are mixed | Visible on links/buttons/inputs/selects/textareas/custom widgets; logical keyboard order and no clipping. |
| Disabled | Keep label at readable contrast; use muted surface, strong disabled affordance and no hover lift | Actual disabled semantics; explain why unavailable when that affects a workflow. Never use opacity that makes text unreadable. |
| Error | `#FF5364` text/icon on dark surface, strong border and concise nearby message | Associate error with field/region and announce relevant async errors; include recovery/action when possible. |
| Loading | Spinner/progress indicator plus explicit text; preserve panel geometry | Announce meaningful async status; disable duplicate submission; respect reduced motion. |

These contracts apply to React and Legacy independently during their separate migrations. No pill-shaped controls: use angular/low-radius geometry and clear borders consistently.
