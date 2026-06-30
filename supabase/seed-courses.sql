-- ============================================================
-- MDU Papers — Comprehensive course catalog (researched)
-- Run this in the Supabase SQL editor to add all MDU courses.
-- Safe to re-run: ON CONFLICT (slug) DO NOTHING skips duplicates.
--
-- Semester counts:
--   UG general (BA/BSc/BCom/BCA/BBA/BTTM): 6
--   B.Tech / B.Pharm / BHMCT / BFA:        8
--   5-year integrated law (BA-LLB/BBA-LLB):10
--   LLB (3-year):                          6
--   B.Ed / B.P.Ed:                         4
--   PG (MA/MSc/MCom/MBA/MCA/MTech/LLM...): 4
-- ============================================================

INSERT INTO courses (name, full_name, degree_type, slug, total_semesters, icon_emoji, is_popular) VALUES
-- ---------- Undergraduate (UG) ----------
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
('LLB', 'Bachelor of Laws', 'UG', 'llb', 6, '📋', false),
('B.Ed', 'Bachelor of Education', 'UG', 'bed', 4, '🎓', false),
('B.P.Ed', 'Bachelor of Physical Education', 'UG', 'bped', 4, '🏅', false),
-- ---------- Postgraduate (PG) ----------
('MBA', 'Master of Business Administration', 'PG', 'mba', 4, '🎯', true),
('MCA', 'Master of Computer Applications', 'PG', 'mca', 4, '🖥️', true),
('MCom', 'Master of Commerce', 'PG', 'mcom', 4, '📈', false),
('MA (English)', 'Master of Arts - English', 'PG', 'ma-english', 4, '📚', false),
('MA (Hindi)', 'Master of Arts - Hindi', 'PG', 'ma-hindi', 4, '🖊️', false),
('MA (History)', 'Master of Arts - History', 'PG', 'ma-history', 4, '🏺', false),
('MA (Political Science)', 'Master of Arts - Political Science', 'PG', 'ma-political-science', 4, '🏛️', false),
('MA (Economics)', 'Master of Arts - Economics', 'PG', 'ma-economics', 4, '💱', false),
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
