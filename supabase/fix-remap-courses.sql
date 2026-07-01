-- ============================================================
-- Remove empty courses that have 0 subjects/papers
-- These specialized courses don't exist in R2 data
-- Keep only courses that actually have papers
-- ============================================================

DELETE FROM courses WHERE id NOT IN (
  SELECT DISTINCT course_id FROM subjects
);

-- Refresh paper_count on all remaining subjects
UPDATE subjects SET paper_count = (
  SELECT COUNT(*) FROM papers WHERE papers.subject_id = subjects.id
);