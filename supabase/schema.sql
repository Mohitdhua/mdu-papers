-- ============================================================
-- MDU Papers — Supabase schema, functions, RLS and seed data
-- Run this in the Supabase SQL editor to set up your database.
-- ============================================================

-- ---------- Tables ----------

CREATE TABLE IF NOT EXISTS courses (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  full_name TEXT NOT NULL,
  degree_type TEXT NOT NULL CHECK (degree_type IN ('UG', 'PG')),
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
  subject_code TEXT,
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
  pdf_size_kb INTEGER,
  page_count INTEGER,
  download_count INTEGER DEFAULT 0,
  is_verified BOOLEAN DEFAULT true,
  uploaded_by TEXT DEFAULT 'admin',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(subject_id, year, exam_session)
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

-- Public read access
DROP POLICY IF EXISTS "Public read courses" ON courses;
CREATE POLICY "Public read courses" ON courses FOR SELECT USING (true);
DROP POLICY IF EXISTS "Public read subjects" ON subjects;
CREATE POLICY "Public read subjects" ON subjects FOR SELECT USING (true);
DROP POLICY IF EXISTS "Public read papers" ON papers;
CREATE POLICY "Public read papers" ON papers FOR SELECT USING (true);
DROP POLICY IF EXISTS "Public read solutions" ON solutions;
CREATE POLICY "Public read solutions" ON solutions FOR SELECT USING (true);

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

-- ---------- Seed data ----------

INSERT INTO courses (name, full_name, degree_type, slug, total_semesters, icon_emoji, is_popular) VALUES
('BCA', 'Bachelor of Computer Applications', 'UG', 'bca', 6, '💻', true),
('B.Tech CSE', 'Bachelor of Technology - Computer Science', 'UG', 'btech-cse', 8, '⚙️', true),
('BSc (CS)', 'Bachelor of Science - Computer Science', 'UG', 'bsc-cs', 6, '🔬', true),
('BCom', 'Bachelor of Commerce', 'UG', 'bcom', 6, '📊', true),
('BA (English)', 'Bachelor of Arts - English', 'UG', 'ba-english', 6, '📖', false),
('BBA', 'Bachelor of Business Administration', 'UG', 'bba', 6, '💼', true),
('MBA', 'Master of Business Administration', 'PG', 'mba', 4, '🎯', true),
('MCA', 'Master of Computer Applications', 'PG', 'mca', 4, '🖥️', true),
('MSc (CS)', 'Master of Science - Computer Science', 'PG', 'msc-cs', 4, '🧪', false),
('MCom', 'Master of Commerce', 'PG', 'mcom', 4, '📈', false),
('B.Tech ECE', 'Bachelor of Technology - Electronics', 'UG', 'btech-ece', 8, '📡', false),
('B.Tech ME', 'Bachelor of Technology - Mechanical', 'UG', 'btech-me', 8, '🔧', false),
('BSc (Physics)', 'Bachelor of Science - Physics', 'UG', 'bsc-physics', 6, '⚛️', false),
('BSc (Math)', 'Bachelor of Science - Mathematics', 'UG', 'bsc-math', 6, '🔢', false),
('BA (Hindi)', 'Bachelor of Arts - Hindi', 'UG', 'ba-hindi', 6, '📝', false)
ON CONFLICT (slug) DO NOTHING;
