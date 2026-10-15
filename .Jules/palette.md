## 2026-06-30 - Improve Accessibility in SerpPreview.tsx
**Learning:** Tab-like buttons in filter lists often lack proper ARIA attributes to communicate their state and function. Missing `role="group"` on filter containers and `aria-pressed` on stateful toggle buttons makes keyboard and screen reader navigation unclear.
**Action:** Always ensure that custom button groups acting as tabs or filters have an appropriate `role="group"` on their container, and use `aria-pressed` on the buttons themselves to indicate the active state. Add `aria-label` to search inputs lacking visible labels.

## 2026-07-01 - Modal Focus Management
**Learning:** Modals that do not manage focus disrupt keyboard navigation. Users lose context when closing a modal if focus is not returned to the triggering element.
**Action:** Always store a ref to the trigger button that opens a modal. When closing the modal, set focus back to this ref (using `setTimeout(..., 0)` in Preact to allow DOM updates). Additionally, shift focus inside the modal (e.g., to the close button) when it opens.