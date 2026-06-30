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

-- ---------- Seed data (see seed-courses.sql for the full catalog) ----------
-- This is the comprehensive MDU course catalog. Safe to re-run.

INSERT INTO courses (name, full_name, degree_type, slug, total_semesters, icon_emoji, is_popular) VALUES
('BCA', 'Bachelor of Computer Applications', 'UG', 'bca', 6, '💻', true),
('BBA', 'Bachelor of Business Administration', 'UG', 'bba', 6, '💼', true),
('BCom', 'Bachelor of Commerce', 'UG', 'bcom', 6, '📊', true),
('BCom (Hons)', 'Bachelor of Commerce (Honours)', 'UG', 'bcom-hons', 6, '📈', false),
('BA', 'Bachelor of Arts', 'UG', 'ba', 6, '📖', true),
('BA (English)', 'Bachelor of Arts - English', 'UG', 'ba-english', 6, '📕', false),
('BA (Hindi)', 'Bachelor of Arts - Hindi', 'UG', 'ba-hindi', 6, '📝', false),
('BA (History)', 'Bachelor of Arts - History', 'UG', 'ba-history', 6, '📜', false),
('BA (Political Science)', 'Bachelor of Arts - Political Science', 'UG', 'ba-political-science', 6, '🏛️', false),
('BA (Economics)', 'Bachelor of Arts - Economics', 'UG', 'ba-economics', 6, '💹', false),
('BSc (CS)', 'Bachelor of Science - Computer Science', 'UG', 'bsc-cs', 6, '🔬', true),
('BSc (Physics)', 'Bachelor of Science - Physics', 'UG', 'bsc-physics', 6, '⚛️', false),
('BSc (Chemistry)', 'Bachelor of Science - Chemistry', 'UG', 'bsc-chemistry', 6, '🧪', false),
('BSc (Maths)', 'Bachelor of Science - Mathematics', 'UG', 'bsc-maths', 6, '🔢', false),
('BSc (Biotech)', 'Bachelor of Science - Biotechnology', 'UG', 'bsc-biotech', 6, '🧬', false),
('BSc (Botany)', 'Bachelor of Science - Botany', 'UG', 'bsc-botany', 6, '🌿', false),
('BSc (Zoology)', 'Bachelor of Science - Zoology', 'UG', 'bsc-zoology', 6, '🦋', false),
('B.Tech CSE', 'Bachelor of Technology - Computer Science & Engineering', 'UG', 'btech-cse', 8, '⚙️', true),
('B.Tech IT', 'Bachelor of Technology - Information Technology', 'UG', 'btech-it', 8, '🖧', false),
('B.Tech AI & ML', 'Bachelor of Technology - Artificial Intelligence & Machine Learning', 'UG', 'btech-ai-ml', 8, '🤖', true),
('B.Tech ECE', 'Bachelor of Technology - Electronics & Communication', 'UG', 'btech-ece', 8, '📡', false),
('B.Tech EE', 'Bachelor of Technology - Electrical Engineering', 'UG', 'btech-ee', 8, '🔌', false),
('B.Tech ME', 'Bachelor of Technology - Mechanical Engineering', 'UG', 'btech-me', 8, '🔧', false),
('B.Tech Civil', 'Bachelor of Technology - Civil Engineering', 'UG', 'btech-civil', 8, '🏗️', false),
('B.Pharm', 'Bachelor of Pharmacy', 'UG', 'bpharm', 8, '💊', false),
('BHMCT', 'Bachelor of Hotel Management & Catering Technology', 'UG', 'bhmct', 8, '🍽️', false),
('BTTM', 'Bachelor of Tourism & Travel Management', 'UG', 'bttm', 6, '✈️', false),
('BFA', 'Bachelor of Fine Arts', 'UG', 'bfa', 8, '🎨', false),
('BA LLB', 'Bachelor of Arts & Bachelor of Laws (Integrated)', 'UG', 'ba-llb', 10, '⚖️', false),
('BBA LLB', 'Bachelor of Business Administration & Bachelor of Laws (Integrated)', 'UG', 'bba-llb', 10, '⚖️', false),
('LLB', 'Bachelor of Laws', 'UG', 'llb', 6, '�', false),
('B.Ed', 'Bachelor of Education', 'UG', 'bed', 4, '🎓', false),
('B.P.Ed', 'Bachelor of Physical Education', 'UG', 'bped', 4, '🏅', false),
('MBA', 'Master of Business Administration', 'PG', 'mba', 4, '🎯', true),
('MCA', 'Master of Computer Applications', 'PG', 'mca', 4, '🖥️', true),
('MCom', 'Master of Commerce', 'PG', 'mcom', 4, '📈', false),
('MA (English)', 'Master of Arts - English', 'PG', 'ma-english', 4, '📚', false),
('MA (Hindi)', 'Master of Arts - Hindi', 'PG', 'ma-hindi', 4, '🖊️', false),
('MA (History)', 'Master of Arts - History', 'PG', 'ma-history', 4, '🏺', false),
('MA (Political Science)', 'Master of Arts - Political Science', 'PG', 'ma-political-science', 4, '🏛️', false),
('MA (Economics)', 'Master of Arts - Economics', 'PG', 'ma-economics', 4, '�', false),
('MSc (CS)', 'Master of Science - Computer Science', 'PG', 'msc-cs', 4, '🧪', false),
('MSc (Physics)', 'Master of Science - Physics', 'PG', 'msc-physics', 4, '🔭', false),
('MSc (Chemistry)', 'Master of Science - Chemistry', 'PG', 'msc-chemistry', 4, '⚗️', false),
('MSc (Maths)', 'Master of Science - Mathematics', 'PG', 'msc-maths', 4, '➗', false),
('MSc (Biotech)', 'Master of Science - Biotechnology', 'PG', 'msc-biotech', 4, '🧬', false),
('M.Tech CSE', 'Master of Technology - Computer Science & Engineering', 'PG', 'mtech-cse', 4, '🛠️', false),
('M.Pharm', 'Master of Pharmacy', 'PG', 'mpharm', 4, '💉', false),
('LLM', 'Master of Laws', 'PG', 'llm', 4, '⚖️', false),
('M.Ed', 'Master of Education', 'PG', 'med', 4, '📔', false),
('M.P.Ed', 'Master of Physical Education', 'PG', 'mped', 4, '🏆', false),
('MTTM', 'Master of Tourism & Travel Management', 'PG', 'mttm', 4, '🧳', false),
('MHMCT', 'Master of Hotel Management & Catering Technology', 'PG', 'mhmct', 4, '🍴', false)
ON CONFLICT (slug) DO NOTHING;
