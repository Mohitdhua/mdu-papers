-- ============================================================
-- MDU Papers — Submissions & Verification Updates
-- ============================================================

-- 1. Update the trigger function to only count verified papers.
CREATE OR REPLACE FUNCTION update_paper_count()
RETURNS TRIGGER AS $$
DECLARE
  target_subject INTEGER;
BEGIN
  target_subject := COALESCE(NEW.subject_id, OLD.subject_id);
  UPDATE subjects
    SET paper_count = (SELECT COUNT(*) FROM papers WHERE subject_id = target_subject AND is_verified = true)
    WHERE id = target_subject;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 2. Modify the trigger to fire on UPDATE (when is_verified is toggled)
--    in addition to INSERT and DELETE.
DROP TRIGGER IF EXISTS papers_count_trigger ON papers;
CREATE TRIGGER papers_count_trigger
AFTER INSERT OR DELETE OR UPDATE OF is_verified ON papers
FOR EACH ROW EXECUTE FUNCTION update_paper_count();

-- 3. Add Row Level Security (RLS) policies to allow public submissions.
--    This allows anonymous users to insert unverified papers and subjects.

ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE papers ENABLE ROW LEVEL SECURITY;

-- Allow public to insert a subject (must start with 0 paper count)
DROP POLICY IF EXISTS "Public insert subjects" ON subjects;
CREATE POLICY "Public insert subjects" ON subjects FOR INSERT 
  WITH CHECK (paper_count = 0 OR paper_count IS NULL);

-- Allow public to insert a paper (must be unverified)
DROP POLICY IF EXISTS "Public insert papers" ON papers;
CREATE POLICY "Public insert papers" ON papers FOR INSERT 
  WITH CHECK (is_verified = false);
