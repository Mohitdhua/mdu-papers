## 2026-06-30 - Improve Accessibility in SerpPreview.tsx\n**Learning:** Tab-like buttons in filter lists often lack proper ARIA attributes to communicate their state and function. Missing `role="group"` on filter containers and `aria-pressed` on stateful toggle buttons makes keyboard and screen reader navigation unclear.\n**Action:** Always ensure that custom button groups acting as tabs or filters have an appropriate `role="group"` on their container, and use `aria-pressed` on the buttons themselves to indicate the active state. Add `aria-label` to search inputs lacking visible labels.

## 2026-07-19 - Preact Modal Focus Management
**Learning:** When managing focus transitions after state changes (e.g., closing a modal or unmounting) in Preact components, restoring focus synchronously can fail because the DOM update might be asynchronous.
**Action:** Always wrap `ref.current?.focus()` in a `setTimeout(..., 0)` to ensure the focus transition occurs after the DOM has fully updated.
