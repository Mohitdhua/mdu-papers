-- ============================================================
-- MDU Papers — Supabase schema, functions & RLS
-- Run this ONCE in the Supabase SQL editor to set up your DB.
-- Then run the seed files (seed-courses.sql, seed-part-1…4.sql)
-- ============================================================

-- ---------- Tables ----------

CREATE TABLE IF NOT EXISTS courses (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  full_name TEXT NOT NULL,
  degree_type TEXT NOT NULL CHECK (degree_type IN ('UG', 'PG', 'Others')),
  slug TEXT NOT NULL UNIQUE,
  total_semesters INTEGER NOT NULL DEFAULT 6,
  icon_emoji TEXT DEFAULT '📚',
  is_popular BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subjects (
  id SERIAL PRIMARY KEY,
  course_id INTEGER NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  semester INTEGER NOT NULL CHECK (semester >= 1 AND semester <= 10),
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  paper_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(course_id, semester, slug)
);

CREATE TABLE IF NOT EXISTS papers (
  id SERIAL PRIMARY KEY,
  subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  year INTEGER NOT NULL CHECK (year >= 2015 AND year <= 2030),
  exam_session TEXT NOT NULL CHECK (exam_session IN ('May/June', 'Nov/Dec', 'Supplementary', 'Re-appear')),
  pdf_url TEXT NOT NULL,
  r2_key TEXT,                           -- object key in Cloudflare R2 (for deletion)
  topics TEXT,                           -- comma/line separated main topics asked (for FAQ content)
  pdf_size_kb INTEGER,
  page_count INTEGER,
  download_count INTEGER DEFAULT 0,
  is_verified BOOLEAN DEFAULT true,
  uploaded_by TEXT DEFAULT 'admin',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(r2_key)
);

CREATE TABLE IF NOT EXISTS blog_metadata (
  id SERIAL PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  view_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS solutions (
  id SERIAL PRIMARY KEY,
  paper_id INTEGER NOT NULL REFERENCES papers(id) ON DELETE CASCADE UNIQUE,
  content TEXT,                          -- markdown solution content
  solution_pdf_url TEXT,                 -- optional separate solution PDF
  author TEXT DEFAULT 'admin',
  is_published BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS blog_posts (
  id SERIAL PRIMARY KEY,
  slug TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  content TEXT NOT NULL,                  -- markdown body
  author TEXT DEFAULT 'MDU Papers Team',
  tags TEXT[] DEFAULT '{}',
  is_published BOOLEAN DEFAULT true,
  pub_date TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ---------- Functions ----------

CREATE OR REPLACE FUNCTION increment_download(paper_id INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE papers SET download_count = download_count + 1 WHERE id = paper_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_paper_count()
RETURNS TRIGGER AS $$
DECLARE
  target_subject INTEGER;
BEGIN
  target_subject := COALESCE(NEW.subject_id, OLD.subject_id);
  UPDATE subjects
    SET paper_count = (SELECT COUNT(*) FROM papers WHERE subject_id = target_subject)
    WHERE id = target_subject;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS papers_count_trigger ON papers;
CREATE TRIGGER papers_count_trigger
AFTER INSERT OR DELETE ON papers
FOR EACH ROW EXECUTE FUNCTION update_paper_count();

-- ---------- Row Level Security ----------

ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE papers ENABLE ROW LEVEL SECURITY;
ALTER TABLE solutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE blog_posts ENABLE ROW LEVEL SECURITY;

-- Public read access
DROP POLICY IF EXISTS "Public read courses" ON courses;
CREATE POLICY "Public read courses" ON courses FOR SELECT USING (true);
DROP POLICY IF EXISTS "Public read subjects" ON subjects;
CREATE POLICY "Public read subjects" ON subjects FOR SELECT USING (true);
DROP POLICY IF EXISTS "Public read papers" ON papers;
CREATE POLICY "Public read papers" ON papers FOR SELECT USING (true);
DROP POLICY IF EXISTS "Public read solutions" ON solutions;
CREATE POLICY "Public read solutions" ON solutions FOR SELECT USING (true);
DROP POLICY IF EXISTS "Public read blog" ON blog_posts;
CREATE POLICY "Public read blog" ON blog_posts FOR SELECT USING (true);

-- Admin (authenticated) write access
DROP POLICY IF EXISTS "Admin write courses" ON courses;
CREATE POLICY "Admin write courses" ON courses FOR ALL
  USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Admin write subjects" ON subjects;
CREATE POLICY "Admin write subjects" ON subjects FOR ALL
  USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Admin write papers" ON papers;
CREATE POLICY "Admin write papers" ON papers FOR ALL
  USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Admin write solutions" ON solutions;
CREATE POLICY "Admin write solutions" ON solutions FOR ALL
  USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');
DROP POLICY IF EXISTS "Admin write blog" ON blog_posts;
CREATE POLICY "Admin write blog" ON blog_posts FOR ALL
  USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- ---------- Seed data ----------
-- Course and paper seed data is maintained in separate files:
--   seed-courses.sql        — All MDU courses (UG / PG / Others)
--   seed-part-1 … 4.sql     — Subjects & papers (R2-verified)
-- Run seed-courses.sql first, then seed-part-*.sql in order.
