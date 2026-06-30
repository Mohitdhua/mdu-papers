# 🚀 Deploying MDU Papers to Cloudflare Pages

This guide walks through deploying the site live, connecting Supabase, and setting up
automatic rebuilds when you upload new papers.

---

## Part 1 — Supabase (Database + Auth + Storage)

1. Create a free project at [supabase.com](https://supabase.com).
2. In the **SQL Editor**, run these two files in order:
   - `supabase/schema.sql` — tables, functions, RLS, seed courses, solutions table
   - `supabase/storage.sql` — public `papers` storage bucket + policies
3. Create your admin login: **Authentication → Users → Add user** (email + password).
4. Copy your project's **URL** and **anon public key** from **Project Settings → API**.

---

## Part 2 — Push the code to GitHub

```bash
git init
git add .
git commit -m "Initial commit: MDU Papers"
git branch -M main
git remote add origin https://github.com/<you>/mdu-papers.git
git push -u origin main
```

> `.env` is gitignored, so your secrets won't be committed. You'll add them in Cloudflare.

---

## Part 3 — Cloudflare Pages

1. Go to the [Cloudflare dashboard](https://dash.cloudflare.com) → **Workers & Pages → Create → Pages → Connect to Git**.
2. Select your repository.
3. Set build configuration:

   | Setting | Value |
   |---------|-------|
   | Framework preset | Astro |
   | Build command | `pnpm run build` |
   | Build output directory | `dist` |
   | Root directory | `/` |

4. Add **Environment variables** (Settings → Environment variables):

   ```
   PUBLIC_SUPABASE_URL        = https://your-project.supabase.co
   PUBLIC_SUPABASE_ANON_KEY   = your-anon-key
   PUBLIC_SITE_URL            = https://your-domain.com
   PUBLIC_GA_ID               = G-XXXXXXXXXX        (optional)
   PUBLIC_DEPLOY_HOOK_URL     = (added in Part 5)
   ```

5. Set the Node version: add an environment variable `NODE_VERSION = 20` (or use a
   `.nvmrc` file).
6. Click **Save and Deploy**.

---

## Part 4 — Custom domain

1. In your Pages project → **Custom domains → Set up a custom domain**.
2. Enter your domain (e.g. `mdupapers.com`) and follow the DNS instructions.
3. Update `astro.config.mjs` `site:` and `PUBLIC_SITE_URL` to your real domain, then
   redeploy so the sitemap and canonical URLs are correct.

---

## Part 5 — Auto-rebuild on new uploads (Deploy Hook)

Because the public site is statically generated, new papers/solutions appear after a
rebuild. A Deploy Hook lets you trigger that rebuild from the admin panel.

1. Pages project → **Settings → Builds & deployments → Deploy hooks → Add deploy hook**.
2. Name it (e.g. `admin-publish`), select the `main` branch, and **Create**.
3. Copy the generated URL.
4. Add it as an environment variable and redeploy:

   ```
   PUBLIC_DEPLOY_HOOK_URL = https://api.cloudflare.com/client/v4/pages/webhooks/deploy_hooks/xxxxx
   ```

Now a **🚀 Publish changes** button appears in `/admin`. After uploading papers, click it
to rebuild and go live (takes ~1-2 minutes).

> **Tip:** You can also set up a scheduled rebuild (e.g. nightly) using a Cron Trigger or
> GitHub Action if you prefer batching.

---

## Part 6 — Post-deploy SEO

1. **Google Search Console** ([search.google.com/search-console](https://search.google.com/search-console)):
   - Add your domain, verify ownership (the `google-site-verification` meta tag is in
     `src/components/SEO.astro` — replace the placeholder token).
   - Submit your sitemap: `https://your-domain.com/sitemap-index.xml`.
2. **Google Analytics**: set `PUBLIC_GA_ID` and redeploy.
3. Verify `robots.txt` points to your real sitemap URL.

---

## Local commands recap

```bash
pnpm install      # install deps
pnpm run dev      # local dev at http://localhost:4321
pnpm run build    # production build into dist/
pnpm run preview  # preview the production build
```
