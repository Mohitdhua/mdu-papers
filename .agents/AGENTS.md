# Project-Scoped Agent Guidelines (MDU Papers)

This document contains rules, design patterns, and storage policies that all Antigravity AI agents working on this codebase must follow.

---

## 1. Branding & Naming System

* **Brand Name:** **MDU Papers** (visible user-facing brand).
* **Project Name/Handle:** `mdupapers` (e.g., `SITE.name = 'mdupapers'`).
* **Legacy Ref:** Never use the old branding name `mdupyq` in headers, logos, meta tags, or user-facing templates.

---

## 2. Multi-Bucket Storage Firewall Architecture

We separate unverified public uploads from verified production files using two distinct Cloudflare R2 buckets:
1. **`SUBMISSIONS_BUCKET`**: Public-facing bucket for temporary student contributions.
2. **`PAPERS_BUCKET`**: Protected bucket for verified production papers.

### Code & Binding Policies:
- **Write Actions:** All student uploads must write only to `env.SUBMISSIONS_BUCKET` under the `submissions/` prefix using random UUIDs (`submissions/[uuid].pdf`).
- **Approval Actions:** Moving files from submissions to clean folders must run cross-bucket (since R2 native copy does not support inter-bucket operations):
  1. Retrieve the file stream from `env.SUBMISSIONS_BUCKET`.
  2. Put it into `env.PAPERS_BUCKET` under the clean course directory path.
  3. Purge the old object from `env.SUBMISSIONS_BUCKET`.
- **Deletion Actions:** The delete endpoint must check the key prefix:
  - If `key.startsWith('submissions/')`, delete it from `env.SUBMISSIONS_BUCKET`.
  - Otherwise, delete it from `env.PAPERS_BUCKET`.
- **R2 URL Resolution:**
  - Verified files resolve using `PUBLIC_R2_BASE_URL`.
  - Unverified submissions resolve using `PUBLIC_SUBMISSIONS_R2_BASE_URL` (falling back to `PUBLIC_R2_BASE_URL` if not set).

---

## 3. SEO-Optimized Consolidated Architecture

- **Page Minimization:** Keep the site compiled strictly under **250 static pages** (generating only course index and semester pages).
- **Consolidated Semesters:** Subjects list, syllabus, FAQs, prep guides, and question papers must all render directly on the **Semester page** (`/[course]/[semester].astro`). Do not create or generate separate pages for individual subjects or papers.
- **Internal Linking:** Every semester page must display popular course recommendations at the bottom and link to the 3 latest blog posts to pass PageRank.

---

## 4. Monetization & Ad Placements

- **Vertical Sidebar Skyscrapers:** Banners (160px width) are positioned left/right of the main layout, sticking to the viewport during scroll.
- **Responsiveness:** Sidebar ad slots must be hidden below `1480px` viewport width to prevent breaking layouts.
- **Empty Ad Fallback:** Always style ad containers with CSS `:empty` and `:has()` so they shrink and remain completely hidden if ad script assets fail to load.

---

## 5. Performance, Accessibility & CLS Rules

- **Native Fonts:** Never integrate third-party font networks (such as Google Fonts). Use native system fonts for 0ms font loading overhead.
- **Zero CLS:** Avoid animations that translate elements physically (e.g. `translateY` on page load). Prefer simple opacity fades to ensure a Cumulative Layout Shift of `0.000`.
- **WCAG AA Compliance:** Muted and description text colors must satisfy at least a `4.5:1` contrast ratio in both light and dark themes.
