## 2026-06-30 - Improve Accessibility in SerpPreview.tsx
**Learning:** Tab-like buttons in filter lists often lack proper ARIA attributes to communicate their state and function. Missing `role="group"` on filter containers and `aria-pressed` on stateful toggle buttons makes keyboard and screen reader navigation unclear.
**Action:** Always ensure that custom button groups acting as tabs or filters have an appropriate `role="group"` on their container, and use `aria-pressed` on the buttons themselves to indicate the active state. Add `aria-label` to search inputs lacking visible labels.

## 2024-07-30 - Handling WebKit Native Search Cancel Buttons
**Learning:** When building custom search inputs (with custom clear buttons), WebKit browsers (Chrome, Safari) automatically render a native clear button (`::-webkit-search-cancel-button`) inside `<input type="search">`. This can lead to duplicate clear icons if not explicitly hidden.
**Action:** When implementing custom clear buttons for search inputs, always hide the native one using `::-webkit-search-cancel-button { -webkit-appearance: none; appearance: none; }` in CSS to ensure a consistent, single-icon experience across browsers.
