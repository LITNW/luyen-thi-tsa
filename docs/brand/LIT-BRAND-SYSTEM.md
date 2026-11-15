# LIT — Brand system (Canva-independent)

Version: 1.0 · 2026-11-15  
Status: Working brand specification for Phase 3. Logo concept and naming remain subject to final approval.

## 1. Brand definition

**LIT** is the product brand. Use it as a standalone name; do not force an acronym. Descriptor: **Nền tảng học tập và luyện tập**. Suggested tagline: **Learn · Practice · Grow**.

Brand promise: a focused, structured learning environment that helps learners practise, review progress and understand performance.

## 2. Visual direction

- Direction: Education, geometric minimalism.
- Tone: clear, capable, calm, focused and contemporary.
- Prefer a restrained geometric mark, strong typographic hierarchy and generous whitespace.
- Avoid literal graduation caps, books, light bulbs, trophies and decorative school clip-art.
- Do not imitate another education brand's logo or distinctive visual system.

## 3. Color tokens

### Light interface

| Token | Hex | Intended use |
|---|---|---|
| Navy | `#153B70` | Primary brand, headings, navigation |
| Learning Blue | `#2878C8` | Primary actions and links |
| Soft Blue | `#EAF2FC` | Selected states, soft panels |
| Cloud | `#F5F7FA` | App canvas |
| Surface | `#FFFFFF` | Cards and form surfaces |
| Slate | `#202B3C` | Primary text |
| Muted | `#59677A` | Secondary text |
| Border | `#DCE3EC` | Dividers and control outlines |
| Success | `#16794B` | Successful completion |
| Warning | `#946200` | Caution and pending states |
| Danger | `#B42336` | Errors and destructive actions |

### Dark interface

| Token | Hex | Intended use |
|---|---|---|
| Background | `#101827` | Dark canvas |
| Surface | `#182438` | Main panels |
| Elevated | `#22334B` | Elevated panels |
| Primary text | `#F4F7FB` | Main text |
| Secondary text | `#B8C5D6` | Supporting text |
| Border | `#34465D` | Dividers |
| Brand primary | `#75B7F2` | Dark-mode actions and links |
| Brand secondary | `#A7D0F6` | Secondary emphasis |
| Brand soft | `#203B59` | Selected panels |
| Success | `#6AD6A0` | Positive state |
| Warning | `#FFD166` | Caution |
| Danger | `#FF8793` | Error |

The exam experience may retain a dark, low-distraction surface. The marketing, student and admin surfaces use the light palette as the default proposal.

## 4. Typography

- Primary family: Inter; fallback: system-ui, -apple-system, Segoe UI, sans-serif.
- Vietnamese copy must be tested for complete diacritic coverage.
- Use sentence case for headings and controls.
- Avoid all-caps for long labels; reserve uppercase tracking for small section eyebrows.
- Suggested scale: 12 / 14 / 16 / 20 / 24 / 32 / 40 / 48 px.
- Body copy: 14–16 px, line-height 1.5–1.7.

## 5. Shape, spacing and elevation

- Spacing base: 4 px. Common steps: 4, 8, 12, 16, 24, 32, 40, 48, 64.
- Control radius: 8–10 px.
- Card radius: 14–18 px.
- Large feature panel radius: 20–24 px.
- Borders should carry most of the separation; use subtle shadows only for layered surfaces.
- Interactive targets should be at least 40×40 px; aim for 44×44 px on touch.

## 6. Component states

Every interactive component needs default, hover, focus-visible, active, disabled and (where applicable) loading/error states. Focus must remain visible and must not rely on color alone. Disabled styling is not a substitute for explanatory text.

## 7. Logo asset policy

The geometric symbol and wordmark supplied in the LIT asset pack are working concepts, not trademark-cleared assets. Use the vector SVG as the master. Keep clear space equal to at least half the symbol width. Do not stretch, rotate, add effects, or change the symbol geometry. Use monochrome variants only on backgrounds with sufficient contrast.

Canva is optional. The authoritative source of brand colors and component tokens is the version-controlled CSS token file in this repository. A Canva Brand Kit is not required to use or maintain the brand system.

## 8. Accessibility

- Target WCAG 2.2 AA for normal text and UI controls.
- Check contrast for every foreground/background pairing; do not assume brand blue is readable on every surface.
- Provide labels for all form controls and accessible names for icon-only buttons.
- Preserve keyboard access, logical focus order, visible focus, semantic landmarks and status announcements.
- Never communicate status through color alone.

## 9. Legacy naming rule

LIT is the visible brand. TSA remains a protected legacy/technical identifier where it is part of database, Auth, RPC, Storage, Edge Function, cache, local/session storage, migration or integration contracts. Do not globally replace TSA strings. Product copy may be updated only when the text is clearly a brand label, not historical exam content or a technical identifier.
