## 2026-06-30 - Improve Accessibility in SerpPreview.tsx\n**Learning:** Tab-like buttons in filter lists often lack proper ARIA attributes to communicate their state and function. Missing `role="group"` on filter containers and `aria-pressed` on stateful toggle buttons makes keyboard and screen reader navigation unclear.\n**Action:** Always ensure that custom button groups acting as tabs or filters have an appropriate `role="group"` on their container, and use `aria-pressed` on the buttons themselves to indicate the active state. Add `aria-label` to search inputs lacking visible labels.

## 2026-08-03 - Keyboard Accessible CSS Dropdowns
**Learning:** CSS-based dropdown menus that activate on `:hover` are entirely inaccessible to keyboard users unless explicitly handled.
**Action:** Always include `:focus-within` alongside `:hover` for wrapper elements of CSS-only dropdowns, ensuring keyboard navigation via Tab key makes the dropdown visible and usable.
