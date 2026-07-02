## 2023-07-02 - Dropdown keyboard accessibility
**Learning:** CSS-only hover dropdowns are inaccessible to keyboard and screen reader users by default. Without JS, `aria-expanded` doesn't dynamically update, but adding `:focus-within` to CSS provides basic keyboard operability. Adding `aria-haspopup` and `aria-controls` helps establish relationships for screen readers.
**Action:** When working on navigation menus, ensure dropdown triggers have `aria-haspopup` and that the CSS rules for opening the dropdown (`:hover`) are paired with `:focus-within` for keyboard support.
