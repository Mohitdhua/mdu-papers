-- ============================================================
-- MDU Papers — Correction Query
-- Run this ONCE in Supabase SQL Editor to fix existing data.
-- Then re-run seed-part-1 to seed-part-4 (duplicates auto-skip).
-- ============================================================

-- STEP 1: Fix wrong R2 URLs in all existing papers (ee → ae)
UPDATE papers 
SET pdf_url = REPLACE(pdf_url, 'pub-1d2e8338eb23422792f905017ee97fc6', 'pub-1d2e8338eb23422792f905017ae97fc6')
WHERE pdf_url LIKE '%pub-1d2e8338eb23422792f905017ee97fc6%';

-- STEP 2: Add 4 missing courses that 1,043 papers need
INSERT INTO courses (name, full_name, degree_type, slug, total_semesters, icon_emoji, is_popular) VALUES
('BSc', 'Bachelor of Science', 'UG', 'bsc', 6, '🔬', false),
('MA', 'Master of Arts', 'PG', 'ma', 4, '📚', false),
('MSc', 'Master of Science', 'PG', 'msc', 4, '🔬', false),
('M.Tech', 'Master of Technology', 'PG', 'mtech', 4, '🛠️', false)
ON CONFLICT (slug) DO NOTHING;

-- STEP 3: Change UNIQUE constraint on papers (old one rejected 546 valid papers)
ALTER TABLE papers DROP CONSTRAINT IF EXISTS papers_subject_id_year_exam_session_key;
ALTER TABLE papers ADD CONSTRAINT papers_r2_key_key UNIQUE (r2_key);
