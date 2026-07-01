## 2024-07-01 - Improve Keyboard Accessibility of Header Dropdown
**Learning:** The 123apps-style dropdown megamenu in `Header.astro` was only accessible via mouse hover. Keyboard users navigating with `Tab` could not open or interact with the dropdown content.
**Action:** Add `:focus-within` to CSS selectors controlling dropdown visibility and animations to ensure keyboard accessibility alongside mouse hover.
