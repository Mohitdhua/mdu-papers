-- ============================================================
-- MDU Papers — COMPLETE one-shot setup (run this entire file once)
-- ============================================================

-- ============================================================
-- MDU Papers — Supabase schema, functions, RLS and seed data
-- Run this in the Supabase SQL editor to set up your database.
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


-- ============================================================
-- MDU Papers — Subjects seed for ALL courses (semester-wise)
-- Researched real MDU data for 10 major courses (BCA, BBA, BCom, BA,
-- BSc-CS, B.Tech CSE, MBA, MCA, MA English, MCom). Others use standard
-- curricula as a starting point. Edit/add/remove via the admin panel.
-- Safe to re-run: ON CONFLICT (course_id, semester, slug) DO NOTHING.
-- Run AFTER seed-courses.sql.
-- ============================================================

-- bca
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer & Programming Fundamentals', 'computer-programming-fundamentals' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Logical Organization of Computer - Part-I', 'logical-organization-of-computer-part-i' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'PC Software', 'pc-software' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics', 'mathematics' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Programming in C', 'programming-in-c' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Logical Organization of Computer - Part-II', 'logical-organization-of-computer-part-ii' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Structured System Analysis and Design', 'structured-system-analysis-and-design' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematical Foundation of Computer Science', 'mathematical-foundation-of-computer-science' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Data Structure-I', 'data-structure-i' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Database Management System', 'database-management-system' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Operating System', 'operating-system' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Communication Skills (English)', 'communication-skills-english' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Web Designing', 'web-designing' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Data Structure-II', 'data-structure-ii' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Object Oriented Programming Using C++', 'object-oriented-programming-using-c' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Software Engineering', 'software-engineering' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Visual Basic', 'visual-basic' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Computer Graphics', 'computer-graphics' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Management Information System', 'management-information-system' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Data Communication & Networks', 'data-communication-networks' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'E-Commerce', 'e-commerce' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Object Technologies & Programming Using Java', 'object-technologies-programming-using-java' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Artificial Intelligence', 'artificial-intelligence' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Introduction to .NET', 'introduction-to-net' FROM courses WHERE slug='bca' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bba
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Organization', 'business-organization' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Mathematics', 'business-mathematics' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Financial Accounting', 'financial-accounting' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer Fundamentals', 'computer-fundamentals' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Communication', 'business-communication' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Micro-economics for Business Decisions', 'micro-economics-for-business-decisions' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Principles of Management', 'principles-of-management' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Macro-Economic Analysis and Policy', 'macro-economic-analysis-and-policy' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Company Accounts', 'company-accounts' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computer Applications in Management', 'computer-applications-in-management' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Organizational Behavior', 'organizational-behavior' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Business Statistics', 'business-statistics' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Cost and Management Accounting', 'cost-and-management-accounting' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Marketing Management', 'marketing-management' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Capital Markets', 'capital-markets' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Introduction to Information Technology', 'introduction-to-information-technology' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Disaster Management', 'disaster-management' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Financial Management', 'financial-management' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Human Resource Management', 'human-resource-management' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Business Research Methods', 'business-research-methods' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Business Laws', 'business-laws' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Database Management System', 'database-management-system' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Human Rights and Values', 'human-rights-and-values' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Production and Materials Management', 'production-and-materials-management' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Company Law', 'company-law' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Indian Business Environment', 'indian-business-environment' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Computer Networking & Internet', 'computer-networking-internet' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Cyber Security', 'cyber-security' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Income Tax', 'income-tax' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'System Analysis and Design', 'system-analysis-and-design' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Foundations of International Business', 'foundations-of-international-business' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Consumer Protection', 'consumer-protection' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'E-Commerce', 'e-commerce' FROM courses WHERE slug='bba' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bcom
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Financial Accounting', 'financial-accounting' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Mathematics', 'business-mathematics' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Economics', 'business-economics' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Management', 'business-management' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Communication', 'business-communication' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Financial Accounting-II', 'financial-accounting-ii' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Business Statistics', 'business-statistics' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Macro Economics', 'macro-economics' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Business Regulatory Framework', 'business-regulatory-framework' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Principles of Marketing', 'principles-of-marketing' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Corporate Accounting', 'corporate-accounting' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Company Law', 'company-law' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Cost Accounting', 'cost-accounting' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Banking & Insurance', 'banking-insurance' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Indian Economy', 'indian-economy' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Corporate Accounting-II', 'corporate-accounting-ii' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Income Tax Law & Practice', 'income-tax-law-practice' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Management Accounting', 'management-accounting' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Business Environment', 'business-environment' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'E-Commerce', 'e-commerce' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Auditing', 'auditing' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Financial Management', 'financial-management' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Goods & Services Tax (GST)', 'goods-services-tax-gst' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Human Resource Management', 'human-resource-management' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Entrepreneurship', 'entrepreneurship' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Cost Accounting', 'advanced-cost-accounting' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Indirect Tax', 'indirect-tax' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'International Business', 'international-business' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Financial Markets & Institutions', 'financial-markets-institutions' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project Work', 'project-work' FROM courses WHERE slug='bcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bcom-hons
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Financial Accounting', 'financial-accounting' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Economics', 'business-economics' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Law', 'business-law' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Organization & Management', 'business-organization-management' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Communication', 'business-communication' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer Fundamentals', 'computer-fundamentals' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Corporate Accounting', 'corporate-accounting' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Macro Economics', 'macro-economics' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Company Law', 'company-law' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Principles of Marketing', 'principles-of-marketing' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Business Statistics', 'business-statistics' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Cost Accounting', 'cost-accounting' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Income Tax Law & Practice', 'income-tax-law-practice' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Banking & Insurance', 'banking-insurance' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Business Mathematics', 'business-mathematics' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Indian Economy', 'indian-economy' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'E-Commerce', 'e-commerce' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Management Accounting', 'management-accounting' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Goods & Services Tax (GST)', 'goods-services-tax-gst' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Auditing', 'auditing' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Financial Management', 'financial-management' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Human Resource Management', 'human-resource-management' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Entrepreneurship', 'entrepreneurship' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Accounting', 'advanced-accounting' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Corporate Tax Planning', 'corporate-tax-planning' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Financial Markets & Institutions', 'financial-markets-institutions' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'International Business', 'international-business' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Principles of Investment', 'principles-of-investment' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Business Environment', 'business-environment' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Cost Accounting', 'advanced-cost-accounting' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Indirect Tax', 'indirect-tax' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Strategic Management', 'strategic-management' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project Work', 'project-work' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Office Management', 'office-management' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Goods & Services Tax-II', 'goods-services-tax-ii' FROM courses WHERE slug='bcom-hons' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ba
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English (Compulsory)', 'english-compulsory' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Hindi / MIL (Compulsory)', 'hindi-mil-compulsory' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'History Paper-I', 'history-paper-i' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Political Science Paper-I', 'political-science-paper-i' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Economics Paper-I', 'economics-paper-i' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Geography Paper-I', 'geography-paper-i' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Sociology Paper-I', 'sociology-paper-i' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Public Administration Paper-I', 'public-administration-paper-i' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Psychology Paper-I', 'psychology-paper-i' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Sanskrit Paper-I', 'sanskrit-paper-i' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'English (Compulsory)', 'english-compulsory' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi / MIL (Compulsory)', 'hindi-mil-compulsory' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'History Paper-II', 'history-paper-ii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Political Science Paper-II', 'political-science-paper-ii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Economics Paper-II', 'economics-paper-ii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Geography Paper-II', 'geography-paper-ii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Sociology Paper-II', 'sociology-paper-ii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Public Administration Paper-II', 'public-administration-paper-ii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Psychology Paper-II', 'psychology-paper-ii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Sanskrit Paper-II', 'sanskrit-paper-ii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'English (Compulsory)', 'english-compulsory' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Hindi / MIL (Compulsory)', 'hindi-mil-compulsory' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'History Paper-III', 'history-paper-iii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Political Science Paper-III', 'political-science-paper-iii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Economics Paper-III', 'economics-paper-iii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Geography Paper-III', 'geography-paper-iii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Sociology Paper-III', 'sociology-paper-iii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Public Administration Paper-III', 'public-administration-paper-iii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Psychology Paper-III', 'psychology-paper-iii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Sanskrit Paper-III', 'sanskrit-paper-iii' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'English (Compulsory)', 'english-compulsory' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Hindi / MIL (Compulsory)', 'hindi-mil-compulsory' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'History Paper-IV', 'history-paper-iv' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Political Science Paper-IV', 'political-science-paper-iv' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Economics Paper-IV', 'economics-paper-iv' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Geography Paper-IV', 'geography-paper-iv' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Sociology Paper-IV', 'sociology-paper-iv' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Public Administration Paper-IV', 'public-administration-paper-iv' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Psychology Paper-IV', 'psychology-paper-iv' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Sanskrit Paper-IV', 'sanskrit-paper-iv' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'English (Compulsory)', 'english-compulsory' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'History Paper-V', 'history-paper-v' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Political Science Paper-V', 'political-science-paper-v' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Economics Paper-V', 'economics-paper-v' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Geography Paper-V', 'geography-paper-v' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Sociology Paper-V', 'sociology-paper-v' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Public Administration Paper-V', 'public-administration-paper-v' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Psychology Paper-V', 'psychology-paper-v' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Sanskrit Paper-V', 'sanskrit-paper-v' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'English (Compulsory)', 'english-compulsory' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'History Paper-VI', 'history-paper-vi' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Political Science Paper-VI', 'political-science-paper-vi' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Economics Paper-VI', 'economics-paper-vi' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Geography Paper-VI', 'geography-paper-vi' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Sociology Paper-VI', 'sociology-paper-vi' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Public Administration Paper-VI', 'public-administration-paper-vi' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Psychology Paper-VI', 'psychology-paper-vi' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Sanskrit Paper-VI', 'sanskrit-paper-vi' FROM courses WHERE slug='ba' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ba-english
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Literature-I', 'english-literature-i' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-I', 'elective-i' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-II', 'elective-ii' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'English Literature-II', 'english-literature-ii' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi/MIL', 'hindimil' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Information Technology', 'information-technology' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-III', 'elective-iii' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'English Literature-III', 'english-literature-iii' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'English Literature Special-I', 'english-literature-special-i' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Skills', 'research-skills' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-V', 'elective-v' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-VI', 'elective-vi' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'English Literature-IV', 'english-literature-iv' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'English Literature Special-II', 'english-literature-special-ii' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Statistical Methods', 'statistical-methods' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-VII', 'elective-vii' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-VIII', 'elective-viii' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced English Literature-I', 'advanced-english-literature-i' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'English Literature Optional-I', 'english-literature-optional-i' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Project-I', 'project-i' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-IX', 'elective-ix' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Skill Course-I', 'skill-course-i' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced English Literature-II', 'advanced-english-literature-ii' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'English Literature Optional-II', 'english-literature-optional-ii' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project-II', 'project-ii' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-X', 'elective-x' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Skill Course-II', 'skill-course-ii' FROM courses WHERE slug='ba-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ba-hindi
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Hindi Literature-I', 'hindi-literature-i' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-I', 'elective-i' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-II', 'elective-ii' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi Literature-II', 'hindi-literature-ii' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi/MIL', 'hindimil' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Information Technology', 'information-technology' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-III', 'elective-iii' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Hindi Literature-III', 'hindi-literature-iii' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Hindi Literature Special-I', 'hindi-literature-special-i' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Skills', 'research-skills' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-V', 'elective-v' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-VI', 'elective-vi' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Hindi Literature-IV', 'hindi-literature-iv' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Hindi Literature Special-II', 'hindi-literature-special-ii' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Statistical Methods', 'statistical-methods' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-VII', 'elective-vii' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-VIII', 'elective-viii' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Hindi Literature-I', 'advanced-hindi-literature-i' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Hindi Literature Optional-I', 'hindi-literature-optional-i' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Project-I', 'project-i' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-IX', 'elective-ix' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Skill Course-I', 'skill-course-i' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Hindi Literature-II', 'advanced-hindi-literature-ii' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Hindi Literature Optional-II', 'hindi-literature-optional-ii' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project-II', 'project-ii' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-X', 'elective-x' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Skill Course-II', 'skill-course-ii' FROM courses WHERE slug='ba-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ba-history
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'History-I', 'history-i' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-I', 'elective-i' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-II', 'elective-ii' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'History-II', 'history-ii' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi/MIL', 'hindimil' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Information Technology', 'information-technology' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-III', 'elective-iii' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'History-III', 'history-iii' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'History Special-I', 'history-special-i' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Skills', 'research-skills' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-V', 'elective-v' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-VI', 'elective-vi' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'History-IV', 'history-iv' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'History Special-II', 'history-special-ii' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Statistical Methods', 'statistical-methods' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-VII', 'elective-vii' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-VIII', 'elective-viii' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced History-I', 'advanced-history-i' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'History Optional-I', 'history-optional-i' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Project-I', 'project-i' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-IX', 'elective-ix' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Skill Course-I', 'skill-course-i' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced History-II', 'advanced-history-ii' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'History Optional-II', 'history-optional-ii' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project-II', 'project-ii' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-X', 'elective-x' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Skill Course-II', 'skill-course-ii' FROM courses WHERE slug='ba-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ba-political-science
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Political Science-I', 'political-science-i' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-I', 'elective-i' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-II', 'elective-ii' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Political Science-II', 'political-science-ii' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi/MIL', 'hindimil' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Information Technology', 'information-technology' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-III', 'elective-iii' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Political Science-III', 'political-science-iii' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Political Science Special-I', 'political-science-special-i' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Skills', 'research-skills' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-V', 'elective-v' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-VI', 'elective-vi' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Political Science-IV', 'political-science-iv' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Political Science Special-II', 'political-science-special-ii' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Statistical Methods', 'statistical-methods' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-VII', 'elective-vii' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-VIII', 'elective-viii' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Political Science-I', 'advanced-political-science-i' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Political Science Optional-I', 'political-science-optional-i' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Project-I', 'project-i' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-IX', 'elective-ix' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Skill Course-I', 'skill-course-i' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Political Science-II', 'advanced-political-science-ii' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Political Science Optional-II', 'political-science-optional-ii' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project-II', 'project-ii' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-X', 'elective-x' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Skill Course-II', 'skill-course-ii' FROM courses WHERE slug='ba-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ba-economics
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Economics-I', 'economics-i' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-I', 'elective-i' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-II', 'elective-ii' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Economics-II', 'economics-ii' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi/MIL', 'hindimil' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Information Technology', 'information-technology' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-III', 'elective-iii' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Economics-III', 'economics-iii' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Economics Special-I', 'economics-special-i' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Skills', 'research-skills' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-V', 'elective-v' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-VI', 'elective-vi' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Economics-IV', 'economics-iv' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Economics Special-II', 'economics-special-ii' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Statistical Methods', 'statistical-methods' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-VII', 'elective-vii' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-VIII', 'elective-viii' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Economics-I', 'advanced-economics-i' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Economics Optional-I', 'economics-optional-i' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Project-I', 'project-i' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-IX', 'elective-ix' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Skill Course-I', 'skill-course-i' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Economics-II', 'advanced-economics-ii' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Economics Optional-II', 'economics-optional-ii' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project-II', 'project-ii' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-X', 'elective-x' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Skill Course-II', 'skill-course-ii' FROM courses WHERE slug='ba-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bsc-cs
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer Fundamentals & MS-Office', 'computer-fundamentals-ms-office' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer Architecture', 'computer-architecture' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Programming in C', 'programming-in-c' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Structured Systems Analysis and Design', 'structured-systems-analysis-and-design' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Data Communication and Networking', 'data-communication-and-networking' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Object-Oriented Design and C++', 'object-oriented-design-and-c' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Data Structures with C/C++', 'data-structures-with-cc' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Operating Systems', 'operating-systems' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Database Management System', 'database-management-system' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Introduction to Internet & Web Technologies', 'introduction-to-internet-web-technologies' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Visual Basic Programming', 'visual-basic-programming' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Software Engineering', 'software-engineering' FROM courses WHERE slug='bsc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bsc-physics
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Physics-I', 'physics-i' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics-I', 'mathematics-i' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Physics Lab-I', 'physics-lab-i' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Physics-II', 'physics-ii' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics-II', 'mathematics-ii' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Technical Writing', 'technical-writing' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Physics Lab-II', 'physics-lab-ii' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Physics-III', 'physics-iii' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Applied Mathematics', 'applied-mathematics' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Physics Practical-III', 'physics-practical-iii' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Physics-IV', 'physics-iv' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Statistics', 'statistics' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Physics Practical-IV', 'physics-practical-iv' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Computational Methods', 'computational-methods' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Physics-I', 'advanced-physics-i' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Physics Special Paper-I', 'physics-special-paper-i' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Physics Lab-V', 'physics-lab-v' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Instrumentation', 'instrumentation' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Physics-II', 'advanced-physics-ii' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Physics Special Paper-II', 'physics-special-paper-ii' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project Work', 'project-work' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Physics Lab-VI', 'physics-lab-vi' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-V', 'elective-v' FROM courses WHERE slug='bsc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bsc-chemistry
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Chemistry-I', 'chemistry-i' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics-I', 'mathematics-i' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Chemistry Lab-I', 'chemistry-lab-i' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Chemistry-II', 'chemistry-ii' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics-II', 'mathematics-ii' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Technical Writing', 'technical-writing' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Chemistry Lab-II', 'chemistry-lab-ii' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Chemistry-III', 'chemistry-iii' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Applied Mathematics', 'applied-mathematics' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Chemistry Practical-III', 'chemistry-practical-iii' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Chemistry-IV', 'chemistry-iv' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Statistics', 'statistics' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Chemistry Practical-IV', 'chemistry-practical-iv' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Computational Methods', 'computational-methods' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Chemistry-I', 'advanced-chemistry-i' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Chemistry Special Paper-I', 'chemistry-special-paper-i' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Chemistry Lab-V', 'chemistry-lab-v' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Instrumentation', 'instrumentation' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Chemistry-II', 'advanced-chemistry-ii' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Chemistry Special Paper-II', 'chemistry-special-paper-ii' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project Work', 'project-work' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Chemistry Lab-VI', 'chemistry-lab-vi' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-V', 'elective-v' FROM courses WHERE slug='bsc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bsc-maths
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics-I', 'mathematics-i' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics-I', 'mathematics-i' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics Lab-I', 'mathematics-lab-i' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics-II', 'mathematics-ii' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics-II', 'mathematics-ii' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Technical Writing', 'technical-writing' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics Lab-II', 'mathematics-lab-ii' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Mathematics-III', 'mathematics-iii' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Applied Mathematics', 'applied-mathematics' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Mathematics Practical-III', 'mathematics-practical-iii' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Mathematics-IV', 'mathematics-iv' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Statistics', 'statistics' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Mathematics Practical-IV', 'mathematics-practical-iv' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Computational Methods', 'computational-methods' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Mathematics-I', 'advanced-mathematics-i' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Mathematics Special Paper-I', 'mathematics-special-paper-i' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Mathematics Lab-V', 'mathematics-lab-v' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Instrumentation', 'instrumentation' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Mathematics-II', 'advanced-mathematics-ii' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Mathematics Special Paper-II', 'mathematics-special-paper-ii' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project Work', 'project-work' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Mathematics Lab-VI', 'mathematics-lab-vi' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-V', 'elective-v' FROM courses WHERE slug='bsc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bsc-biotech
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Biotechnology-I', 'biotechnology-i' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics-I', 'mathematics-i' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Biotechnology Lab-I', 'biotechnology-lab-i' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Biotechnology-II', 'biotechnology-ii' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics-II', 'mathematics-ii' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Technical Writing', 'technical-writing' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Biotechnology Lab-II', 'biotechnology-lab-ii' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Biotechnology-III', 'biotechnology-iii' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Applied Mathematics', 'applied-mathematics' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Biotechnology Practical-III', 'biotechnology-practical-iii' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Biotechnology-IV', 'biotechnology-iv' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Statistics', 'statistics' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Biotechnology Practical-IV', 'biotechnology-practical-iv' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Computational Methods', 'computational-methods' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Biotechnology-I', 'advanced-biotechnology-i' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Biotechnology Special Paper-I', 'biotechnology-special-paper-i' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Biotechnology Lab-V', 'biotechnology-lab-v' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Instrumentation', 'instrumentation' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Biotechnology-II', 'advanced-biotechnology-ii' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Biotechnology Special Paper-II', 'biotechnology-special-paper-ii' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project Work', 'project-work' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Biotechnology Lab-VI', 'biotechnology-lab-vi' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-V', 'elective-v' FROM courses WHERE slug='bsc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bsc-botany
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Botany-I', 'botany-i' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics-I', 'mathematics-i' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Botany Lab-I', 'botany-lab-i' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Botany-II', 'botany-ii' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics-II', 'mathematics-ii' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Technical Writing', 'technical-writing' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Botany Lab-II', 'botany-lab-ii' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Botany-III', 'botany-iii' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Applied Mathematics', 'applied-mathematics' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Botany Practical-III', 'botany-practical-iii' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Botany-IV', 'botany-iv' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Statistics', 'statistics' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Botany Practical-IV', 'botany-practical-iv' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Computational Methods', 'computational-methods' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Botany-I', 'advanced-botany-i' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Botany Special Paper-I', 'botany-special-paper-i' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Botany Lab-V', 'botany-lab-v' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Instrumentation', 'instrumentation' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Botany-II', 'advanced-botany-ii' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Botany Special Paper-II', 'botany-special-paper-ii' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project Work', 'project-work' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Botany Lab-VI', 'botany-lab-vi' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-V', 'elective-v' FROM courses WHERE slug='bsc-botany' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bsc-zoology
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Zoology-I', 'zoology-i' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics-I', 'mathematics-i' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Zoology Lab-I', 'zoology-lab-i' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Zoology-II', 'zoology-ii' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics-II', 'mathematics-ii' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Technical Writing', 'technical-writing' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Zoology Lab-II', 'zoology-lab-ii' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Zoology-III', 'zoology-iii' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Applied Mathematics', 'applied-mathematics' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Zoology Practical-III', 'zoology-practical-iii' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Zoology-IV', 'zoology-iv' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Statistics', 'statistics' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Zoology Practical-IV', 'zoology-practical-iv' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Computational Methods', 'computational-methods' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Zoology-I', 'advanced-zoology-i' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Zoology Special Paper-I', 'zoology-special-paper-i' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Zoology Lab-V', 'zoology-lab-v' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Instrumentation', 'instrumentation' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Zoology-II', 'advanced-zoology-ii' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Zoology Special Paper-II', 'zoology-special-paper-ii' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project Work', 'project-work' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Zoology Lab-VI', 'zoology-lab-vi' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-V', 'elective-v' FROM courses WHERE slug='bsc-zoology' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- btech-cse
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics-I', 'mathematics-i' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Physics (Semiconductor Physics)', 'physics-semiconductor-physics' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Basic Electrical Engineering', 'basic-electrical-engineering' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Programming for Problem Solving', 'programming-for-problem-solving' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English / Communication Skills', 'english-communication-skills' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics-II', 'mathematics-ii' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Chemistry', 'chemistry' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Graphics & Design', 'engineering-graphics-design' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Workshop / Manufacturing Practices', 'workshop-manufacturing-practices' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Communication Skills / English', 'communication-skills-english' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Mathematics-III', 'mathematics-iii' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Data Structures and Algorithms', 'data-structures-and-algorithms' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Object Oriented Programming using C++', 'object-oriented-programming-using-c' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Discrete Mathematics', 'discrete-mathematics' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Computer Organisation and Architecture', 'computer-organisation-and-architecture' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Database Management Systems', 'database-management-systems' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Operating Systems', 'operating-systems' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Digital Electronics', 'digital-electronics' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Design and Analysis of Algorithms', 'design-and-analysis-of-algorithms' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Python Programming', 'python-programming' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Principles of Operating Systems', 'principles-of-operating-systems' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Computer Networks', 'computer-networks' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Formal Languages and Automata Theory', 'formal-languages-and-automata-theory' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Software Engineering', 'software-engineering' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Professional Elective-I', 'professional-elective-i' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Compiler Design', 'compiler-design' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Web Technologies', 'web-technologies' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Machine Learning', 'machine-learning' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Theory of Computation', 'theory-of-computation' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Professional Elective-II', 'professional-elective-ii' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Artificial Intelligence', 'artificial-intelligence' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Computer Graphics', 'computer-graphics' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Professional Elective-III', 'professional-elective-iii' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Professional Elective-IV', 'professional-elective-iv' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Project-I / Industrial Training', 'project-i-industrial-training' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Big Data Analytics', 'big-data-analytics' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Professional Elective-V', 'professional-elective-v' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Professional Elective-VI', 'professional-elective-vi' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Open Elective-IV', 'open-elective-iv' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Project-II / Major Project', 'project-ii-major-project' FROM courses WHERE slug='btech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- btech-it
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Mathematics-I', 'engineering-mathematics-i' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Physics', 'engineering-physics' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Programming for Problem Solving', 'programming-for-problem-solving' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Basic Electrical Engineering', 'basic-electrical-engineering' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Mathematics-II', 'engineering-mathematics-ii' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Chemistry', 'engineering-chemistry' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Graphics & Design', 'engineering-graphics-design' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Basic Electronics', 'basic-electronics' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Environmental Sciences', 'environmental-sciences' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Data Structures', 'data-structures' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Discrete Structures', 'discrete-structures' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Digital Electronics', 'digital-electronics' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'OOP with Java', 'oop-with-java' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Computer Architecture', 'computer-architecture' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Algorithms', 'algorithms' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'DBMS', 'dbms' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Operating Systems', 'operating-systems' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Data Communication', 'data-communication' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Automata Theory', 'automata-theory' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Computer Networks', 'computer-networks' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Software Engineering', 'software-engineering' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Web Engineering', 'web-engineering' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Microprocessors', 'microprocessors' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Statistics', 'statistics' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Information Security', 'information-security' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Mobile Computing', 'mobile-computing' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Computer Graphics', 'computer-graphics' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Data Warehousing', 'data-warehousing' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-I', 'elective-i' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Cloud Computing', 'cloud-computing' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Machine Learning', 'machine-learning' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Network Security', 'network-security' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Project-I', 'project-i' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Elective-II', 'elective-ii' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'IoT', 'iot' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Big Data', 'big-data' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Project-II', 'project-ii' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Elective-III', 'elective-iii' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Industrial Training', 'industrial-training' FROM courses WHERE slug='btech-it' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- btech-ai-ml
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Mathematics-I', 'engineering-mathematics-i' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Physics', 'engineering-physics' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Programming for Problem Solving', 'programming-for-problem-solving' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Basic Electrical Engineering', 'basic-electrical-engineering' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Mathematics-II', 'engineering-mathematics-ii' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Chemistry', 'engineering-chemistry' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Graphics & Design', 'engineering-graphics-design' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Basic Electronics', 'basic-electronics' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Environmental Sciences', 'environmental-sciences' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Data Structures', 'data-structures' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Discrete Mathematics', 'discrete-mathematics' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Python for AI', 'python-for-ai' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Digital Logic Design', 'digital-logic-design' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Probability & Statistics', 'probability-statistics' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Algorithms', 'algorithms' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Database Systems', 'database-systems' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Operating Systems', 'operating-systems' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Foundations of AI', 'foundations-of-ai' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Linear Algebra', 'linear-algebra' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Machine Learning', 'machine-learning' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Computer Networks', 'computer-networks' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Data Mining', 'data-mining' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Neural Networks', 'neural-networks' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Optimization Techniques', 'optimization-techniques' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Deep Learning', 'deep-learning' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Natural Language Processing', 'natural-language-processing' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Computer Vision', 'computer-vision' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Reinforcement Learning', 'reinforcement-learning' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-I', 'elective-i' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Generative AI', 'generative-ai' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Big Data Analytics', 'big-data-analytics' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'AI Ethics', 'ai-ethics' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Project-I', 'project-i' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Elective-II', 'elective-ii' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'MLOps', 'mlops' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Edge AI', 'edge-ai' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Project-II', 'project-ii' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Elective-III', 'elective-iii' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Industrial Training', 'industrial-training' FROM courses WHERE slug='btech-ai-ml' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- btech-ece
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Mathematics-I', 'engineering-mathematics-i' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Physics', 'engineering-physics' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Programming for Problem Solving', 'programming-for-problem-solving' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Basic Electrical Engineering', 'basic-electrical-engineering' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Mathematics-II', 'engineering-mathematics-ii' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Chemistry', 'engineering-chemistry' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Graphics & Design', 'engineering-graphics-design' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Basic Electronics', 'basic-electronics' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Environmental Sciences', 'environmental-sciences' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Network Analysis', 'network-analysis' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Electronic Devices & Circuits', 'electronic-devices-circuits' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Signals & Systems', 'signals-systems' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Digital Electronics', 'digital-electronics' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Engineering Mathematics-III', 'engineering-mathematics-iii' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Analog Communication', 'analog-communication' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Microprocessors', 'microprocessors' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Control Systems', 'control-systems' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Electromagnetic Field Theory', 'electromagnetic-field-theory' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Linear Integrated Circuits', 'linear-integrated-circuits' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Digital Communication', 'digital-communication' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Digital Signal Processing', 'digital-signal-processing' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Antenna & Wave Propagation', 'antenna-wave-propagation' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'VLSI Design', 'vlsi-design' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Microcontrollers', 'microcontrollers' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Microwave Engineering', 'microwave-engineering' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Optical Communication', 'optical-communication' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Embedded Systems', 'embedded-systems' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Information Theory & Coding', 'information-theory-coding' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-I', 'elective-i' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Wireless Communication', 'wireless-communication' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Satellite Communication', 'satellite-communication' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'CMOS Design', 'cmos-design' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Project-I', 'project-i' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Elective-II', 'elective-ii' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Mobile Communication', 'mobile-communication' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Project-II', 'project-ii' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Elective-III', 'elective-iii' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Industrial Training', 'industrial-training' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Seminar', 'seminar' FROM courses WHERE slug='btech-ece' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- btech-ee
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Mathematics-I', 'engineering-mathematics-i' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Physics', 'engineering-physics' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Programming for Problem Solving', 'programming-for-problem-solving' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Basic Electrical Engineering', 'basic-electrical-engineering' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Mathematics-II', 'engineering-mathematics-ii' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Chemistry', 'engineering-chemistry' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Graphics & Design', 'engineering-graphics-design' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Basic Electronics', 'basic-electronics' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Environmental Sciences', 'environmental-sciences' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Circuit Analysis', 'circuit-analysis' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Electrical Machines-I', 'electrical-machines-i' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Electromagnetic Fields', 'electromagnetic-fields' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Analog Electronics', 'analog-electronics' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Engineering Mathematics-III', 'engineering-mathematics-iii' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Electrical Machines-II', 'electrical-machines-ii' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Power Systems-I', 'power-systems-i' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Control Systems', 'control-systems' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Digital Electronics', 'digital-electronics' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Measurements & Instrumentation', 'measurements-instrumentation' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Power Systems-II', 'power-systems-ii' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Power Electronics', 'power-electronics' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Microprocessors', 'microprocessors' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Signals & Systems', 'signals-systems' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Electrical Drives', 'electrical-drives' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Switchgear & Protection', 'switchgear-protection' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Digital Signal Processing', 'digital-signal-processing' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Renewable Energy Systems', 'renewable-energy-systems' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'High Voltage Engineering', 'high-voltage-engineering' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-I', 'elective-i' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Power System Operation & Control', 'power-system-operation-control' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Industrial Drives', 'industrial-drives' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Project-I', 'project-i' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Elective-II', 'elective-ii' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Elective-III', 'elective-iii' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Smart Grid', 'smart-grid' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Project-II', 'project-ii' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Industrial Training', 'industrial-training' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Seminar', 'seminar' FROM courses WHERE slug='btech-ee' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- btech-me
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Mathematics-I', 'engineering-mathematics-i' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Physics', 'engineering-physics' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Programming for Problem Solving', 'programming-for-problem-solving' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Basic Electrical Engineering', 'basic-electrical-engineering' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Mathematics-II', 'engineering-mathematics-ii' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Chemistry', 'engineering-chemistry' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Graphics & Design', 'engineering-graphics-design' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Basic Electronics', 'basic-electronics' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Environmental Sciences', 'environmental-sciences' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Thermodynamics', 'thermodynamics' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Strength of Materials', 'strength-of-materials' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Manufacturing Processes', 'manufacturing-processes' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Engineering Mechanics', 'engineering-mechanics' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Engineering Mathematics-III', 'engineering-mathematics-iii' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Fluid Mechanics', 'fluid-mechanics' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Theory of Machines-I', 'theory-of-machines-i' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Material Science', 'material-science' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Machine Drawing', 'machine-drawing' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Applied Thermodynamics', 'applied-thermodynamics' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Heat & Mass Transfer', 'heat-mass-transfer' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Theory of Machines-II', 'theory-of-machines-ii' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Machine Design-I', 'machine-design-i' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Internal Combustion Engines', 'internal-combustion-engines' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Industrial Engineering', 'industrial-engineering' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Refrigeration & Air Conditioning', 'refrigeration-air-conditioning' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Machine Design-II', 'machine-design-ii' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Manufacturing Technology', 'manufacturing-technology' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Dynamics of Machines', 'dynamics-of-machines' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-I', 'elective-i' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Automobile Engineering', 'automobile-engineering' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'CAD/CAM', 'cadcam' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Power Plant Engineering', 'power-plant-engineering' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Project-I', 'project-i' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Elective-II', 'elective-ii' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Mechatronics', 'mechatronics' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Operations Management', 'operations-management' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Project-II', 'project-ii' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Industrial Training', 'industrial-training' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Elective-III', 'elective-iii' FROM courses WHERE slug='btech-me' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- btech-civil
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Mathematics-I', 'engineering-mathematics-i' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Engineering Physics', 'engineering-physics' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Programming for Problem Solving', 'programming-for-problem-solving' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Basic Electrical Engineering', 'basic-electrical-engineering' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English Communication', 'english-communication' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Mathematics-II', 'engineering-mathematics-ii' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Chemistry', 'engineering-chemistry' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Engineering Graphics & Design', 'engineering-graphics-design' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Basic Electronics', 'basic-electronics' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Environmental Sciences', 'environmental-sciences' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Strength of Materials', 'strength-of-materials' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Surveying-I', 'surveying-i' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Fluid Mechanics', 'fluid-mechanics' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Building Materials & Construction', 'building-materials-construction' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Engineering Mathematics-III', 'engineering-mathematics-iii' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Structural Analysis-I', 'structural-analysis-i' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Surveying-II', 'surveying-ii' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Concrete Technology', 'concrete-technology' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Soil Mechanics', 'soil-mechanics' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Hydraulics', 'hydraulics' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Structural Analysis-II', 'structural-analysis-ii' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Design of RC Structures', 'design-of-rc-structures' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Geotechnical Engineering', 'geotechnical-engineering' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Transportation Engineering-I', 'transportation-engineering-i' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Water Resources Engineering', 'water-resources-engineering' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Design of Steel Structures', 'design-of-steel-structures' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Environmental Engineering-I', 'environmental-engineering-i' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Transportation Engineering-II', 'transportation-engineering-ii' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Foundation Engineering', 'foundation-engineering' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-I', 'elective-i' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Environmental Engineering-II', 'environmental-engineering-ii' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Estimation & Costing', 'estimation-costing' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Construction Management', 'construction-management' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Project-I', 'project-i' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Elective-II', 'elective-ii' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Earthquake Engineering', 'earthquake-engineering' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Project-II', 'project-ii' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Industrial Training', 'industrial-training' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Elective-III', 'elective-iii' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Seminar', 'seminar' FROM courses WHERE slug='btech-civil' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bpharm
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Human Anatomy & Physiology-I', 'human-anatomy-physiology-i' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Pharmaceutical Analysis-I', 'pharmaceutical-analysis-i' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Pharmaceutics-I', 'pharmaceutics-i' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Pharmaceutical Inorganic Chemistry', 'pharmaceutical-inorganic-chemistry' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Communication Skills', 'communication-skills' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Human Anatomy & Physiology-II', 'human-anatomy-physiology-ii' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Pharmaceutical Organic Chemistry-I', 'pharmaceutical-organic-chemistry-i' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Biochemistry', 'biochemistry' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Pathophysiology', 'pathophysiology' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computer Applications in Pharmacy', 'computer-applications-in-pharmacy' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Pharmaceutical Organic Chemistry-II', 'pharmaceutical-organic-chemistry-ii' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Physical Pharmaceutics-I', 'physical-pharmaceutics-i' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Pharmaceutical Microbiology', 'pharmaceutical-microbiology' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Pharmaceutical Engineering', 'pharmaceutical-engineering' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Pharmacognosy-I', 'pharmacognosy-i' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Pharmaceutical Organic Chemistry-III', 'pharmaceutical-organic-chemistry-iii' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Medicinal Chemistry-I', 'medicinal-chemistry-i' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Physical Pharmaceutics-II', 'physical-pharmaceutics-ii' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Pharmacology-I', 'pharmacology-i' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Pharmacognosy-II', 'pharmacognosy-ii' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Medicinal Chemistry-II', 'medicinal-chemistry-ii' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Industrial Pharmacy-I', 'industrial-pharmacy-i' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Pharmacology-II', 'pharmacology-ii' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Pharmaceutical Jurisprudence', 'pharmaceutical-jurisprudence' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Pharmacognosy-III', 'pharmacognosy-iii' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Medicinal Chemistry-III', 'medicinal-chemistry-iii' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Pharmacology-III', 'pharmacology-iii' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Herbal Drug Technology', 'herbal-drug-technology' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Biopharmaceutics & Pharmacokinetics', 'biopharmaceutics-pharmacokinetics' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Pharmaceutical Biotechnology', 'pharmaceutical-biotechnology' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Industrial Pharmacy-II', 'industrial-pharmacy-ii' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Pharmacy Practice', 'pharmacy-practice' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Novel Drug Delivery Systems', 'novel-drug-delivery-systems' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Instrumental Methods of Analysis', 'instrumental-methods-of-analysis' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Elective-I', 'elective-i' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Biostatistics & Research Methodology', 'biostatistics-research-methodology' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Social & Preventive Pharmacy', 'social-preventive-pharmacy' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Pharmacovigilance', 'pharmacovigilance' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Project Work', 'project-work' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Quality Control & Quality Assurance', 'quality-control-quality-assurance' FROM courses WHERE slug='bpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bhmct
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Foundation of Food Production-I', 'foundation-of-food-production-i' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Foundation of Food & Beverage Service-I', 'foundation-of-food-beverage-service-i' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Front Office Operations-I', 'front-office-operations-i' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Housekeeping Operations-I', 'housekeeping-operations-i' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Hotel Engineering', 'hotel-engineering' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Foundation of Food Production-II', 'foundation-of-food-production-ii' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Food & Beverage Service-II', 'food-beverage-service-ii' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Front Office-II', 'front-office-ii' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Housekeeping-II', 'housekeeping-ii' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Nutrition & Food Science', 'nutrition-food-science' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Food Production-III', 'food-production-iii' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Food & Beverage Service-III', 'food-beverage-service-iii' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Accommodation Management', 'accommodation-management' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Hotel Accounting', 'hotel-accounting' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Communication Skills', 'communication-skills' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Quantity Food Production', 'quantity-food-production' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Beverage Management', 'beverage-management' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Food Safety & Hygiene', 'food-safety-hygiene' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Hotel French', 'hotel-french' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Industrial Training', 'industrial-training' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Food Production', 'advanced-food-production' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Bar & Beverage Operations', 'bar-beverage-operations' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Hotel Marketing', 'hotel-marketing' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Human Resource Management', 'human-resource-management' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Facility Planning', 'facility-planning' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Larder & Bakery', 'larder-bakery' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Food & Beverage Controls', 'food-beverage-controls' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Financial Management', 'financial-management' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Tourism Management', 'tourism-management' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-I', 'elective-i' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Hotel Operations Management', 'hotel-operations-management' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Entrepreneurship in Hospitality', 'entrepreneurship-in-hospitality' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Research Project-I', 'research-project-i' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Strategic Management', 'strategic-management' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Elective-II', 'elective-ii' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Hospitality Law', 'hospitality-law' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Event Management', 'event-management' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Research Project-II', 'research-project-ii' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Industrial Exposure Training', 'industrial-exposure-training' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Elective-III', 'elective-iii' FROM courses WHERE slug='bhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bttm
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Foundation of Tourism', 'foundation-of-tourism' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Indian History & Culture', 'indian-history-culture' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Tourism Geography', 'tourism-geography' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Communication Skills', 'communication-skills' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer Applications', 'computer-applications' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Tourism Products of India', 'tourism-products-of-india' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Travel Agency & Tour Operations', 'travel-agency-tour-operations' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Tourism Marketing', 'tourism-marketing' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hospitality Management', 'hospitality-management' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Tour Guiding & Escorting', 'tour-guiding-escorting' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Airline & Airport Management', 'airline-airport-management' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Tourism Economics', 'tourism-economics' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Cultural Tourism', 'cultural-tourism' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Event Management', 'event-management' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Travel Management', 'travel-management' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Eco & Sustainable Tourism', 'eco-sustainable-tourism' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Tourism Policy & Planning', 'tourism-policy-planning' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Foreign Language', 'foreign-language' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Industrial Training', 'industrial-training' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'International Tourism', 'international-tourism' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Tourism Entrepreneurship', 'tourism-entrepreneurship' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Destination Management', 'destination-management' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Human Resource Management', 'human-resource-management' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-I', 'elective-i' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Tourism Research', 'tourism-research' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Adventure & Medical Tourism', 'adventure-medical-tourism' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'E-Tourism', 'e-tourism' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Project Work', 'project-work' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-II', 'elective-ii' FROM courses WHERE slug='bttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bfa
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Fundamentals of Visual Arts', 'fundamentals-of-visual-arts' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Drawing-I', 'drawing-i' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'History of Indian Art-I', 'history-of-indian-art-i' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Colour Theory', 'colour-theory' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Design Basics', 'design-basics' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Drawing-II', 'drawing-ii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Painting-I', 'painting-i' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'History of Indian Art-II', 'history-of-indian-art-ii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Sculpture Basics', 'sculpture-basics' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computer Graphics', 'computer-graphics' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Painting-II', 'painting-ii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Applied Art-I', 'applied-art-i' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'History of Western Art-I', 'history-of-western-art-i' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Printmaking-I', 'printmaking-i' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Photography', 'photography' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Painting-III', 'painting-iii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Applied Art-II', 'applied-art-ii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'History of Western Art-II', 'history-of-western-art-ii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Printmaking-II', 'printmaking-ii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Digital Art', 'digital-art' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Advanced Painting-I', 'advanced-painting-i' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Mural Design', 'mural-design' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Aesthetics-I', 'aesthetics-i' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Portfolio Development', 'portfolio-development' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Elective-I', 'elective-i' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Advanced Painting-II', 'advanced-painting-ii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Illustration', 'illustration' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Aesthetics-II', 'aesthetics-ii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Art Appreciation', 'art-appreciation' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Elective-II', 'elective-ii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Studio Practice-I', 'studio-practice-i' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Contemporary Art', 'contemporary-art' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Project-I', 'project-i' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Exhibition Design', 'exhibition-design' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Elective-III', 'elective-iii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Studio Practice-II', 'studio-practice-ii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Art Criticism', 'art-criticism' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Project-II', 'project-ii' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Final Display', 'final-display' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Portfolio & Viva', 'portfolio-viva' FROM courses WHERE slug='bfa' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ba-llb
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'English-I', 'english-i' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Hindi-I', 'hindi-i' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Environmental Studies', 'environmental-studies' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Legal Method', 'legal-method' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Law of Torts', 'law-of-torts' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'English-II', 'english-ii' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi-II', 'hindi-ii' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'History of India-II', 'history-of-india-ii' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Law of Contract-I', 'law-of-contract-i' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Political Science / Management-I', 'political-science-management-i' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Law of Contract-II', 'law-of-contract-ii' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Constitutional Law-I', 'constitutional-law-i' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Family Law-I', 'family-law-i' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Economics / Management-II', 'economics-management-ii' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Sociology / Marketing', 'sociology-marketing' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Constitutional Law-II', 'constitutional-law-ii' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Family Law-II', 'family-law-ii' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Law of Crimes (IPC)', 'law-of-crimes-ipc' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'History / Finance', 'history-finance' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Jurisprudence', 'jurisprudence' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Property Law', 'property-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Administrative Law', 'administrative-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Company Law', 'company-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Public International Law', 'public-international-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Labour Law', 'labour-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Civil Procedure Code', 'civil-procedure-code' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Criminal Procedure Code', 'criminal-procedure-code' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Law of Evidence', 'law-of-evidence' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Environmental Law', 'environmental-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Intellectual Property Law', 'intellectual-property-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Land Laws', 'land-laws' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Interpretation of Statutes', 'interpretation-of-statutes' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Banking & Insurance Law', 'banking-insurance-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Human Rights Law', 'human-rights-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Clinical Course-I', 'clinical-course-i' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Taxation Law', 'taxation-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Arbitration & ADR', 'arbitration-adr' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Competition Law', 'competition-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Clinical Course-II', 'clinical-course-ii' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Elective-I', 'elective-i' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 9, 'Drafting, Pleading & Conveyancing', 'drafting-pleading-conveyancing' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 9, 'Professional Ethics', 'professional-ethics' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 9, 'Moot Court', 'moot-court' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 9, 'Elective-II', 'elective-ii' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 9, 'Seminar', 'seminar' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 10, 'Internship / Dissertation', 'internship-dissertation' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 10, 'Cyber Law', 'cyber-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 10, 'International Trade Law', 'international-trade-law' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 10, 'Elective-III', 'elective-iii' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 10, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='ba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bba-llb
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Principles of Management', 'principles-of-management' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Economics', 'business-economics' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Financial Accounting', 'financial-accounting' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Legal Method', 'legal-method' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Law of Torts', 'law-of-torts' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Organizational Behaviour', 'organizational-behaviour' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Managerial Economics', 'managerial-economics' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Cost Accounting', 'cost-accounting' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Law of Contract-I', 'law-of-contract-i' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Political Science / Management-I', 'political-science-management-i' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Law of Contract-II', 'law-of-contract-ii' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Constitutional Law-I', 'constitutional-law-i' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Family Law-I', 'family-law-i' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Economics / Management-II', 'economics-management-ii' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Sociology / Marketing', 'sociology-marketing' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Constitutional Law-II', 'constitutional-law-ii' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Family Law-II', 'family-law-ii' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Law of Crimes (IPC)', 'law-of-crimes-ipc' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'History / Finance', 'history-finance' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Jurisprudence', 'jurisprudence' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Property Law', 'property-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Administrative Law', 'administrative-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Company Law', 'company-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Public International Law', 'public-international-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Labour Law', 'labour-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Civil Procedure Code', 'civil-procedure-code' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Criminal Procedure Code', 'criminal-procedure-code' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Law of Evidence', 'law-of-evidence' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Environmental Law', 'environmental-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Intellectual Property Law', 'intellectual-property-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Land Laws', 'land-laws' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Interpretation of Statutes', 'interpretation-of-statutes' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Banking & Insurance Law', 'banking-insurance-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Human Rights Law', 'human-rights-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 7, 'Clinical Course-I', 'clinical-course-i' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Taxation Law', 'taxation-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Arbitration & ADR', 'arbitration-adr' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Competition Law', 'competition-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Clinical Course-II', 'clinical-course-ii' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 8, 'Elective-I', 'elective-i' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 9, 'Drafting, Pleading & Conveyancing', 'drafting-pleading-conveyancing' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 9, 'Professional Ethics', 'professional-ethics' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 9, 'Moot Court', 'moot-court' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 9, 'Elective-II', 'elective-ii' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 9, 'Seminar', 'seminar' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 10, 'Internship / Dissertation', 'internship-dissertation' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 10, 'Cyber Law', 'cyber-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 10, 'International Trade Law', 'international-trade-law' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 10, 'Elective-III', 'elective-iii' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 10, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='bba-llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- llb
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Legal Method', 'legal-method' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Law of Contract-I', 'law-of-contract-i' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Law of Torts', 'law-of-torts' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Constitutional Law-I', 'constitutional-law-i' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Family Law-I', 'family-law-i' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Law of Contract-II', 'law-of-contract-ii' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Constitutional Law-II', 'constitutional-law-ii' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Family Law-II', 'family-law-ii' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Law of Crimes (IPC)', 'law-of-crimes-ipc' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Professional Ethics', 'professional-ethics' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Property Law', 'property-law' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Administrative Law', 'administrative-law' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Company Law', 'company-law' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Public International Law', 'public-international-law' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Jurisprudence', 'jurisprudence' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Labour Law', 'labour-law' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Civil Procedure Code', 'civil-procedure-code' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Criminal Procedure Code', 'criminal-procedure-code' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Environmental Law', 'environmental-law' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Law of Evidence', 'law-of-evidence' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Land Laws', 'land-laws' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Interpretation of Statutes', 'interpretation-of-statutes' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Intellectual Property Law', 'intellectual-property-law' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Banking Law', 'banking-law' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 5, 'Clinical Course-I', 'clinical-course-i' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Human Rights Law', 'human-rights-law' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Taxation Law', 'taxation-law' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Arbitration & ADR', 'arbitration-adr' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Clinical Course-II', 'clinical-course-ii' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 6, 'Moot Court & Internship', 'moot-court-internship' FROM courses WHERE slug='llb' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bed
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Childhood & Growing Up', 'childhood-growing-up' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Contemporary India & Education', 'contemporary-india-education' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Learning & Teaching', 'learning-teaching' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Language across the Curriculum', 'language-across-the-curriculum' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Understanding Disciplines & Subjects', 'understanding-disciplines-subjects' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Knowledge & Curriculum', 'knowledge-curriculum' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Assessment for Learning', 'assessment-for-learning' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Pedagogy of School Subject-I', 'pedagogy-of-school-subject-i' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Pedagogy of School Subject-II', 'pedagogy-of-school-subject-ii' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'School Internship', 'school-internship' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Gender, School & Society', 'gender-school-society' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Inclusive Education', 'inclusive-education' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Educational Technology & ICT', 'educational-technology-ict' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Optional Course-I', 'optional-course-i' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'School Internship-II', 'school-internship-ii' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Creating an Inclusive School', 'creating-an-inclusive-school' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Health, Yoga & Physical Education', 'health-yoga-physical-education' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Understanding the Self', 'understanding-the-self' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Optional Course-II', 'optional-course-ii' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Final Practicum', 'final-practicum' FROM courses WHERE slug='bed' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- bped
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'History & Foundation of Physical Education', 'history-foundation-of-physical-education' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Anatomy & Physiology', 'anatomy-physiology' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Health Education', 'health-education' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Track & Field-I', 'track-field-i' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Gymnastics', 'gymnastics' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Educational Psychology in PE', 'educational-psychology-in-pe' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Kinesiology & Biomechanics', 'kinesiology-biomechanics' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Sports Training', 'sports-training' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Track & Field-II', 'track-field-ii' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Yoga', 'yoga' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Sports Medicine', 'sports-medicine' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Sports Management', 'sports-management' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Officiating & Coaching', 'officiating-coaching' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Games Specialization-I', 'games-specialization-i' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Recreation', 'recreation' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Research Methods in PE', 'research-methods-in-pe' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Test & Measurement in PE', 'test-measurement-in-pe' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Sports Psychology', 'sports-psychology' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Games Specialization-II', 'games-specialization-ii' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Internship', 'internship' FROM courses WHERE slug='bped' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- mba
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Principles and Practices of Management', 'principles-and-practices-of-management' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Organizational Behaviour', 'organizational-behaviour' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Accounting for Management', 'accounting-for-management' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Quantitative Techniques', 'quantitative-techniques' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Managerial Economics', 'managerial-economics' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Communication', 'business-communication' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer Applications in Management', 'computer-applications-in-management' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Business Environment', 'business-environment' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Production and Operations Management', 'production-and-operations-management' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Human Resource Management', 'human-resource-management' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Marketing Management', 'marketing-management' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Financial Management', 'financial-management' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Business Research Methods', 'business-research-methods' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Management Information Systems', 'management-information-systems' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Strategic Management', 'strategic-management' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Legal Aspects of Business', 'legal-aspects-of-business' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Entrepreneurship Development', 'entrepreneurship-development' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Specialization Elective-I', 'specialization-elective-i' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Specialization Elective-II', 'specialization-elective-ii' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'International Business Management', 'international-business-management' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Project Work / Dissertation', 'project-work-dissertation' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Specialization Elective-III', 'specialization-elective-iii' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Specialization Elective-IV', 'specialization-elective-iv' FROM courses WHERE slug='mba' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- mca
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Object Oriented Programming using Java', 'object-oriented-programming-using-java' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'System & Compiler Programming', 'system-compiler-programming' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer Graphics & Multimedia', 'computer-graphics-multimedia' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer Organization & Architecture', 'computer-organization-architecture' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Advance Data Structures using C++/Java', 'advance-data-structures-using-cjava' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Advance Object Technology', 'advance-object-technology' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Advance Database Systems & Data Warehouse', 'advance-database-systems-data-warehouse' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Operating Systems & Shell Programming', 'operating-systems-shell-programming' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-II', 'elective-ii' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Dissertation-I / Industry Internship', 'dissertation-i-industry-internship' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Data Mining & Big Data Analytics', 'data-mining-big-data-analytics' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Artificial Intelligence & Computational Intelligence', 'artificial-intelligence-computational-intelligence' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Android Mobile Application Development', 'android-mobile-application-development' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-I', 'elective-i' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Project Work / Dissertation', 'project-work-dissertation' FROM courses WHERE slug='mca' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- mcom
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Managerial Economics', 'managerial-economics' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Management Concepts & Organizational Behaviour', 'management-concepts-organizational-behaviour' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Statistical Analysis', 'statistical-analysis' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Financial Management', 'financial-management' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Accounting for Managerial Decisions', 'accounting-for-managerial-decisions' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Business Environment', 'business-environment' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Management Accounting', 'management-accounting' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Organizational Behaviour', 'organizational-behaviour' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Marketing Management', 'marketing-management' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Corporate Tax Planning', 'corporate-tax-planning' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Business Research Methods', 'business-research-methods' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Indirect Tax (GST)', 'indirect-tax-gst' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Security Analysis & Portfolio Management', 'security-analysis-portfolio-management' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'International Business', 'international-business' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Strategic Management', 'strategic-management' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Financial Markets & Institutions', 'financial-markets-institutions' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Strategic Financial Management', 'strategic-financial-management' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Entrepreneurship Development', 'entrepreneurship-development' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'E-Commerce', 'e-commerce' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Project Work / Dissertation', 'project-work-dissertation' FROM courses WHERE slug='mcom' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ma-english
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'British Drama', 'british-drama' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'British Poetry', 'british-poetry' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'British Fiction', 'british-fiction' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Pre-Modern Criticism', 'pre-modern-criticism' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Linguistics', 'linguistics' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Indian Knowledge Systems', 'indian-knowledge-systems' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, '18th Century and Romantic British Literature', '18th-century-and-romantic-british-literature' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Victorian Literature', 'victorian-literature' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Modern British Literature', 'modern-british-literature' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Literary Criticism', 'literary-criticism' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Indian Writing in English', 'indian-writing-in-english' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'American Literature', 'american-literature' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Postcolonial Literature', 'postcolonial-literature' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Literary Theory', 'literary-theory' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'English Language Teaching', 'english-language-teaching' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-I', 'elective-i' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Contemporary Literature', 'contemporary-literature' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Cultural Studies', 'cultural-studies' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Indian English Drama & Fiction', 'indian-english-drama-fiction' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation / Project', 'dissertation-project' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-II', 'elective-ii' FROM courses WHERE slug='ma-english' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ma-hindi
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Hindi Literature Paper-I', 'hindi-literature-paper-i' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Hindi Literature Paper-II', 'hindi-literature-paper-ii' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Hindi Literature Paper-III', 'hindi-literature-paper-iii' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Hindi Literature Paper-IV', 'hindi-literature-paper-iv' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi Literature Paper-V', 'hindi-literature-paper-v' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi Literature Paper-VI', 'hindi-literature-paper-vi' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi Literature Paper-VII', 'hindi-literature-paper-vii' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hindi Literature Paper-VIII', 'hindi-literature-paper-viii' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computer Applications', 'computer-applications' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Hindi Literature-I', 'advanced-hindi-literature-i' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Hindi Literature-II', 'advanced-hindi-literature-ii' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Hindi Literature Elective-I', 'hindi-literature-elective-i' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Hindi Literature Elective-II', 'hindi-literature-elective-ii' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Advanced Hindi Literature-III', 'advanced-hindi-literature-iii' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Hindi Literature Elective-III', 'hindi-literature-elective-iii' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Hindi Literature Elective-IV', 'hindi-literature-elective-iv' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation / Project', 'dissertation-project' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='ma-hindi' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ma-history
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'History Paper-I', 'history-paper-i' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'History Paper-II', 'history-paper-ii' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'History Paper-III', 'history-paper-iii' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'History Paper-IV', 'history-paper-iv' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'History Paper-V', 'history-paper-v' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'History Paper-VI', 'history-paper-vi' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'History Paper-VII', 'history-paper-vii' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'History Paper-VIII', 'history-paper-viii' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computer Applications', 'computer-applications' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced History-I', 'advanced-history-i' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced History-II', 'advanced-history-ii' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'History Elective-I', 'history-elective-i' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'History Elective-II', 'history-elective-ii' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Advanced History-III', 'advanced-history-iii' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'History Elective-III', 'history-elective-iii' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'History Elective-IV', 'history-elective-iv' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation / Project', 'dissertation-project' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='ma-history' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ma-political-science
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Political Science Paper-I', 'political-science-paper-i' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Political Science Paper-II', 'political-science-paper-ii' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Political Science Paper-III', 'political-science-paper-iii' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Political Science Paper-IV', 'political-science-paper-iv' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Political Science Paper-V', 'political-science-paper-v' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Political Science Paper-VI', 'political-science-paper-vi' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Political Science Paper-VII', 'political-science-paper-vii' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Political Science Paper-VIII', 'political-science-paper-viii' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computer Applications', 'computer-applications' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Political Science-I', 'advanced-political-science-i' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Political Science-II', 'advanced-political-science-ii' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Political Science Elective-I', 'political-science-elective-i' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Political Science Elective-II', 'political-science-elective-ii' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Advanced Political Science-III', 'advanced-political-science-iii' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Political Science Elective-III', 'political-science-elective-iii' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Political Science Elective-IV', 'political-science-elective-iv' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation / Project', 'dissertation-project' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='ma-political-science' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- ma-economics
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Economics Paper-I', 'economics-paper-i' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Economics Paper-II', 'economics-paper-ii' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Economics Paper-III', 'economics-paper-iii' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Economics Paper-IV', 'economics-paper-iv' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Economics Paper-V', 'economics-paper-v' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Economics Paper-VI', 'economics-paper-vi' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Economics Paper-VII', 'economics-paper-vii' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Economics Paper-VIII', 'economics-paper-viii' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computer Applications', 'computer-applications' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Economics-I', 'advanced-economics-i' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Economics-II', 'advanced-economics-ii' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Economics Elective-I', 'economics-elective-i' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Economics Elective-II', 'economics-elective-ii' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Advanced Economics-III', 'advanced-economics-iii' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Economics Elective-III', 'economics-elective-iii' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Economics Elective-IV', 'economics-elective-iv' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation / Project', 'dissertation-project' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='ma-economics' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- msc-cs
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer Science-I', 'computer-science-i' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer Science-II', 'computer-science-ii' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Computer Science Lab-I', 'computer-science-lab-i' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematical Methods', 'mathematical-methods' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computer Science-III', 'computer-science-iii' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computer Science-IV', 'computer-science-iv' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computer Science Lab-II', 'computer-science-lab-ii' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computational Techniques', 'computational-techniques' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Computer Science-I', 'advanced-computer-science-i' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Computer Science-II', 'advanced-computer-science-ii' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Computer Science Lab-III', 'computer-science-lab-iii' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Advanced Computer Science-III', 'advanced-computer-science-iii' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Computer Science Special Paper', 'computer-science-special-paper' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation / Project', 'dissertation-project' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='msc-cs' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- msc-physics
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Physics-I', 'physics-i' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Physics-II', 'physics-ii' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Physics Lab-I', 'physics-lab-i' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematical Methods', 'mathematical-methods' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Physics-III', 'physics-iii' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Physics-IV', 'physics-iv' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Physics Lab-II', 'physics-lab-ii' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computational Techniques', 'computational-techniques' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Physics-I', 'advanced-physics-i' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Physics-II', 'advanced-physics-ii' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Physics Lab-III', 'physics-lab-iii' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Advanced Physics-III', 'advanced-physics-iii' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Physics Special Paper', 'physics-special-paper' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation / Project', 'dissertation-project' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='msc-physics' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- msc-chemistry
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Chemistry-I', 'chemistry-i' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Chemistry-II', 'chemistry-ii' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Chemistry Lab-I', 'chemistry-lab-i' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematical Methods', 'mathematical-methods' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Chemistry-III', 'chemistry-iii' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Chemistry-IV', 'chemistry-iv' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Chemistry Lab-II', 'chemistry-lab-ii' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computational Techniques', 'computational-techniques' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Chemistry-I', 'advanced-chemistry-i' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Chemistry-II', 'advanced-chemistry-ii' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Chemistry Lab-III', 'chemistry-lab-iii' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Advanced Chemistry-III', 'advanced-chemistry-iii' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Chemistry Special Paper', 'chemistry-special-paper' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation / Project', 'dissertation-project' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='msc-chemistry' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- msc-maths
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics-I', 'mathematics-i' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics-II', 'mathematics-ii' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematics Lab-I', 'mathematics-lab-i' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematical Methods', 'mathematical-methods' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics-III', 'mathematics-iii' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics-IV', 'mathematics-iv' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Mathematics Lab-II', 'mathematics-lab-ii' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computational Techniques', 'computational-techniques' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Mathematics-I', 'advanced-mathematics-i' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Mathematics-II', 'advanced-mathematics-ii' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Mathematics Lab-III', 'mathematics-lab-iii' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Advanced Mathematics-III', 'advanced-mathematics-iii' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Mathematics Special Paper', 'mathematics-special-paper' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation / Project', 'dissertation-project' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='msc-maths' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- msc-biotech
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Biotechnology-I', 'biotechnology-i' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Biotechnology-II', 'biotechnology-ii' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Biotechnology Lab-I', 'biotechnology-lab-i' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematical Methods', 'mathematical-methods' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Biotechnology-III', 'biotechnology-iii' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Biotechnology-IV', 'biotechnology-iv' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Biotechnology Lab-II', 'biotechnology-lab-ii' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Computational Techniques', 'computational-techniques' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Biotechnology-I', 'advanced-biotechnology-i' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Advanced Biotechnology-II', 'advanced-biotechnology-ii' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Biotechnology Lab-III', 'biotechnology-lab-iii' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Advanced Biotechnology-III', 'advanced-biotechnology-iii' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Biotechnology Special Paper', 'biotechnology-special-paper' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation / Project', 'dissertation-project' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='msc-biotech' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- mtech-cse
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Advanced Algorithms', 'advanced-algorithms' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Advanced Computer Architecture', 'advanced-computer-architecture' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Mathematical Foundations of CS', 'mathematical-foundations-of-cs' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Advanced Database Systems', 'advanced-database-systems' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-I', 'elective-i' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Machine Learning', 'machine-learning' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Distributed Systems', 'distributed-systems' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Advanced Computer Networks', 'advanced-computer-networks' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Cloud Computing', 'cloud-computing' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-II', 'elective-ii' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Seminar', 'research-seminar' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Dissertation Phase-I', 'dissertation-phase-i' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-III', 'elective-iii' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Deep Learning', 'deep-learning' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation Phase-II', 'dissertation-phase-ii' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Research Publication', 'research-publication' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-V', 'elective-v' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Project Defense', 'project-defense' FROM courses WHERE slug='mtech-cse' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- mpharm
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Modern Pharmaceutical Analytical Techniques', 'modern-pharmaceutical-analytical-techniques' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Drug Delivery Systems', 'drug-delivery-systems' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Pharmaceutical Formulation Development', 'pharmaceutical-formulation-development' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology & Biostatistics', 'research-methodology-biostatistics' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Elective-I', 'elective-i' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Molecular Pharmaceutics', 'molecular-pharmaceutics' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Advanced Pharmaceutical Analysis', 'advanced-pharmaceutical-analysis' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Regulatory Affairs', 'regulatory-affairs' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Cosmetic & Herbal Technology', 'cosmetic-herbal-technology' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-II', 'elective-ii' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Research Project Phase-I', 'research-project-phase-i' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Journal Club', 'journal-club' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Discussion / Final Year', 'discussion-final-year' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-III', 'elective-iii' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Research Project Phase-II', 'research-project-phase-ii' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation', 'dissertation' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Research Publication', 'research-publication' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-IV', 'elective-iv' FROM courses WHERE slug='mpharm' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- llm
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Constitutionalism', 'constitutionalism' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Legal Research Methodology', 'legal-research-methodology' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Law & Social Transformation', 'law-social-transformation' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Comparative Public Law', 'comparative-public-law' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Judicial Process', 'judicial-process' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Specialization Paper-I', 'specialization-paper-i' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Specialization Paper-II', 'specialization-paper-ii' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Human Rights & International Law', 'human-rights-international-law' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Intellectual Property Rights', 'intellectual-property-rights' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Specialization Paper-III', 'specialization-paper-iii' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Specialization Paper-IV', 'specialization-paper-iv' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Dissertation Phase-I', 'dissertation-phase-i' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Specialization Paper-V', 'specialization-paper-v' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation Phase-II', 'dissertation-phase-ii' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Research Publication', 'research-publication' FROM courses WHERE slug='llm' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- med
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Philosophy of Education', 'philosophy-of-education' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Sociology of Education', 'sociology-of-education' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Psychology of Learning', 'psychology-of-learning' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Educational Research-I', 'educational-research-i' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'History of Education', 'history-of-education' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Curriculum Studies', 'curriculum-studies' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Educational Measurement & Evaluation', 'educational-measurement-evaluation' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Educational Research-II', 'educational-research-ii' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Teacher Education', 'teacher-education' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Educational Technology', 'educational-technology' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Comparative Education', 'comparative-education' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Dissertation Phase-I', 'dissertation-phase-i' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Educational Administration & Management', 'educational-administration-management' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Guidance & Counselling', 'guidance-counselling' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation Phase-II', 'dissertation-phase-ii' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='med' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- mped
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Scientific Principles of Sports Training', 'scientific-principles-of-sports-training' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Exercise Physiology', 'exercise-physiology' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology in PE', 'research-methodology-in-pe' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Sports Management', 'sports-management' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Athletics-I', 'athletics-i' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Sports Biomechanics', 'sports-biomechanics' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Sports Psychology', 'sports-psychology' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Statistics in Physical Education', 'statistics-in-physical-education' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Sports Medicine', 'sports-medicine' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Game Specialization-I', 'game-specialization-i' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Test, Measurement & Evaluation', 'test-measurement-evaluation' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Yogic Sciences', 'yogic-sciences' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Dissertation Phase-I', 'dissertation-phase-i' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Game Specialization-II', 'game-specialization-ii' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Sports Nutrition', 'sports-nutrition' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Curriculum Design in PE', 'curriculum-design-in-pe' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation Phase-II', 'dissertation-phase-ii' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Coaching Specialization', 'coaching-specialization' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='mped' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- mttm
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Principles of Tourism Management', 'principles-of-tourism-management' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Tourism Products & Resources', 'tourism-products-resources' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Travel Agency & Tour Operations Management', 'travel-agency-tour-operations-management' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Tourism Marketing', 'tourism-marketing' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Tourism Planning & Development', 'tourism-planning-development' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Airline & Cargo Management', 'airline-cargo-management' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Hospitality & Event Management', 'hospitality-event-management' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Financial Management in Tourism', 'financial-management-in-tourism' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'International Tourism Management', 'international-tourism-management' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Sustainable Tourism', 'sustainable-tourism' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Dissertation Phase-I', 'dissertation-phase-i' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Tourism Entrepreneurship', 'tourism-entrepreneurship' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Destination Branding', 'destination-branding' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation Phase-II', 'dissertation-phase-ii' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='mttm' ON CONFLICT (course_id, semester, slug) DO NOTHING;

-- mhmct
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Principles of Management', 'principles-of-management' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Advanced Food Production', 'advanced-food-production' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Accommodation Management', 'accommodation-management' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Hospitality Marketing', 'hospitality-marketing' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 1, 'Research Methodology', 'research-methodology' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Food & Beverage Management', 'food-beverage-management' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Financial Management in Hospitality', 'financial-management-in-hospitality' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Human Resource Management', 'human-resource-management' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Tourism & Travel Management', 'tourism-travel-management' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 2, 'Elective-I', 'elective-i' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Strategic Hospitality Management', 'strategic-hospitality-management' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Facility Planning & Design', 'facility-planning-design' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Dissertation Phase-I', 'dissertation-phase-i' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Elective-II', 'elective-ii' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 3, 'Seminar', 'seminar' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Hospitality Law & Ethics', 'hospitality-law-ethics' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Entrepreneurship Development', 'entrepreneurship-development' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Dissertation Phase-II', 'dissertation-phase-ii' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Elective-III', 'elective-iii' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;
INSERT INTO subjects (course_id, semester, name, slug) SELECT id, 4, 'Viva Voce', 'viva-voce' FROM courses WHERE slug='mhmct' ON CONFLICT (course_id, semester, slug) DO NOTHING;

