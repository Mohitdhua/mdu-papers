# ☁️ Cloudflare R2 Setup (PDF Storage — Zero Egress Cost)

PDFs are stored in **Cloudflare R2** instead of Supabase Storage because R2 has
**$0 egress (bandwidth) cost** — serving papers to thousands of students is free.

Supabase is used only for the database (paper metadata) and admin auth.

## Architecture

```
Browser (admin /admin)
   │  upload PDF + Supabase token
   ▼
/api/upload  (Cloudflare Pages Function)
   │  verifies token with Supabase Auth
   │  writes file to R2 bucket binding
   ▼
Cloudflare R2 bucket  ──public──▶  served free to all visitors
   │
   └─ public URL saved in Supabase `papers.pdf_url`
```

## Part 1 — Create the R2 bucket

1. Cloudflare dashboard → **R2 → Create bucket**.
2. Name it e.g. `mdu-papers`.
3. Enable public access:
   - Open the bucket → **Settings → Public access → Allow Access** (R2.dev subdomain),
     **or** connect a custom domain like `files.mdupapers.com`.
4. Copy the **public bucket URL** (looks like `https://pub-xxxxx.r2.dev`).
   - Put it in your env as `PUBLIC_R2_BASE_URL`.

## Part 2 — Bind the bucket to your Pages project

The upload/delete functions use an R2 binding named **`PAPERS_BUCKET`**.

1. Cloudflare → your **Pages project → Settings → Functions → R2 bucket bindings**.
2. Add binding:
   - **Variable name:** `PAPERS_BUCKET`
   - **R2 bucket:** select `mdu-papers`
3. Add it for both **Production** and **Preview** environments.

## Part 3 — Environment variables (Pages project)

Add these under **Settings → Environment variables**:

```
PUBLIC_SUPABASE_URL        = https://your-project.supabase.co
PUBLIC_SUPABASE_ANON_KEY   = your-anon-key
PUBLIC_R2_BASE_URL         = https://pub-xxxxx.r2.dev   (your public bucket URL)
PUBLIC_SITE_URL            = https://your-domain.com
NODE_VERSION               = 20
```

The Pages Functions read `PUBLIC_SUPABASE_URL`, `PUBLIC_SUPABASE_ANON_KEY` and
`PUBLIC_R2_BASE_URL` from the same variables — no extra config needed.

## Part 4 — CORS (only if serving from a different domain)

If your R2 public URL differs from your site domain and previews are blocked, add a CORS
rule on the bucket allowing `GET` from your site origin. For same-origin `<iframe>`
previews and direct downloads this is usually not required.

## Local development

`/api/*` functions only run on Cloudflare's runtime. To test uploads locally, use:

```bash
npx wrangler pages dev dist --r2 PAPERS_BUCKET=mdu-papers
```

(First `pnpm run build`.) Without this, local `/admin` still works for managing
courses/subjects/solutions, but PDF upload needs the deployed environment or wrangler.

## Migration note

If you already created the `papers` table before this change, add the new column:

```sql
ALTER TABLE papers ADD COLUMN IF NOT EXISTS r2_key TEXT;
```
