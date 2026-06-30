-- ============================================================
-- MDU Papers — Supabase Storage setup for paper PDFs
-- Run this AFTER schema.sql, in the Supabase SQL editor.
-- ============================================================

-- Create a public bucket named "papers" for PDF files.
INSERT INTO storage.buckets (id, name, public)
VALUES ('papers', 'papers', true)
ON CONFLICT (id) DO NOTHING;

-- ---------- Storage RLS policies ----------

-- Anyone can read (download/preview) papers.
DROP POLICY IF EXISTS "Public read papers bucket" ON storage.objects;
CREATE POLICY "Public read papers bucket" ON storage.objects
  FOR SELECT USING (bucket_id = 'papers');

-- Only authenticated admins can upload.
DROP POLICY IF EXISTS "Admin upload papers bucket" ON storage.objects;
CREATE POLICY "Admin upload papers bucket" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'papers' AND auth.role() = 'authenticated');

-- Only authenticated admins can update (upsert).
DROP POLICY IF EXISTS "Admin update papers bucket" ON storage.objects;
CREATE POLICY "Admin update papers bucket" ON storage.objects
  FOR UPDATE USING (bucket_id = 'papers' AND auth.role() = 'authenticated');

-- Only authenticated admins can delete.
DROP POLICY IF EXISTS "Admin delete papers bucket" ON storage.objects;
CREATE POLICY "Admin delete papers bucket" ON storage.objects
  FOR DELETE USING (bucket_id = 'papers' AND auth.role() = 'authenticated');

-- ============================================================
-- Create an admin user:
--   1. Go to Authentication → Users in the Supabase dashboard
--   2. Click "Add user" → enter email + password
--   3. Use those credentials to log in at /admin on your site
-- ============================================================
