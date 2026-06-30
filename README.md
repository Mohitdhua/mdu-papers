# 🎓 MDU Papers

A modern, production-ready website for browsing and downloading **Maharshi Dayanand University (MDU)** previous year exam papers. Built with Astro 5, Preact islands, vanilla CSS, Supabase and Cloudflare.

Students can search, browse by Course → Semester → Subject → Year, preview PDFs in-browser, and download — all with a fast, SEO-optimized, dark-mode-ready UI.

## ✨ Features

- ⚡ **Astro 5 (SSG)** — zero JS by default, blazing fast, perfect SEO
- 🏝️ **Preact islands** — live fuzzy search, PDF preview modal, theme toggle
- 🎨 **Custom design system** — CSS variables, light/dark mode, smooth animations
- 🔍 **Client-side fuzzy search** — powered by Fuse.js + a prebuilt JSON index
- 🗄️ **Supabase backend** — PostgreSQL with RLS (falls back to local mock data)
- 📄 **In-browser PDF preview** — native `<iframe>`, no heavy libraries
- 📝 **Markdown blog** — content collections with TOC, reading time, share buttons
- 🔧 **Full SEO** — meta tags, Open Graph, Twitter cards, JSON-LD, sitemap, robots.txt
- ♿ **Accessible** — semantic HTML, keyboard nav, skip links, ARIA labels
- 📱 **Fully responsive** — mobile-first, tested 375px → 1440px

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Astro 5.x (static output) |
| Islands | Preact |
| Styling | Vanilla CSS with CSS variables |
| Database | Supabase (PostgreSQL) |
| Storage | Cloudflare R2 |
| Hosting | Cloudflare Pages |
| Search | Fuse.js |
| Font | Inter (Google Fonts) |

## 🚀 Getting Started

```bash
# Install dependencies
pnpm install

# Start the dev server (runs at http://localhost:4321)
pnpm run dev

# Build for production
pnpm run build

# Preview the production build
pnpm run preview
```

> **Works out of the box.** Without Supabase credentials, the site automatically uses a
> realistic local mock dataset (`src/lib/mockData.ts`) so you can develop and preview
> immediately.

## 🔑 Environment Variables

Copy `.env.example` to `.env` and fill in your values:

```
PUBLIC_SUPABASE_URL=https://your-project.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
PUBLIC_R2_BASE_URL=https://pub-xxxxx.r2.dev
PUBLIC_SITE_URL=https://mdupapers.com
PUBLIC_GA_ID=G-XXXXXXXXXX
```

When the Supabase variables still contain placeholder values, the app uses mock data.

## 🗄️ Database Setup

1. Create a project at [supabase.com](https://supabase.com).
2. Open the SQL editor and run [`supabase/schema.sql`](./supabase/schema.sql). This creates
   all tables, functions, triggers, RLS policies and seeds the course list.
3. Run [`supabase/storage.sql`](./supabase/storage.sql) to create the public `papers` storage
   bucket and its access policies.
4. Fill in your `.env` with the Supabase URL + anon key and rebuild.

## 🔐 Admin Panel (Upload Papers)

The site includes a built-in admin panel at **`/admin`** for managing content — no separate
backend server required. It runs in the browser and talks to Supabase directly, secured by
Supabase Auth + Row Level Security.

**Setup:**

1. Run `supabase/schema.sql` and `supabase/storage.sql` (above).
2. In the Supabase dashboard go to **Authentication → Users → Add user** and create your admin
   account (email + password).
3. Visit `/admin` on your site and sign in.

**What you can do:**

- ➕ Add / delete **courses** (with degree type, semesters, emoji, popular flag)
- ➕ Add / delete **subjects** (per course + semester, with subject code)
- 📄 **Upload paper PDFs** — choose course → subject → year → session, attach the PDF, and it's
  uploaded to Supabase Storage and recorded in the database automatically.

> **Publishing note:** Because the public site is statically generated (SSG), newly uploaded
> papers appear after the next **build/deploy**. On Cloudflare Pages you can trigger a rebuild
> via a deploy hook, or set up a scheduled rebuild. Locally, just run `pnpm run build` again.

## 📁 Project Structure

```
src/
├── components/      Astro components + Preact islands (.tsx)
├── content/blog/    Markdown blog posts
├── layouts/         BaseLayout.astro
├── lib/             config, supabase client, data layer, mock data, utils, types
├── pages/           routes (incl. dynamic [course]/[semester]/[subject])
└── styles/          global.css (full design system)
```

## 🌐 Deploy to Cloudflare Pages

| Setting | Value |
|---------|-------|
| Build command | `pnpm run build` |
| Build output directory | `dist` |
| Root directory | `/` |
| Node.js version | 20+ |

Add the environment variables in the Cloudflare Pages dashboard, then deploy.

## 📝 Adding Blog Posts

Create a new `.md` file in `src/content/blog/` with frontmatter:

```yaml
---
title: "Your Post Title"
description: "A short description for SEO and cards."
pubDate: 2025-01-15
author: "MDU Papers Team"
tags: ["Exam Tips"]
---
```

## ⚠️ Disclaimer

This is **not** the official MDU website. It is an independent educational resource. For
official information visit [mdu.ac.in](https://mdu.ac.in).
