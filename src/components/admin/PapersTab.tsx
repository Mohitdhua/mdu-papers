import { useEffect, useState } from 'preact/hooks';
import type { Course, Subject, Paper, ExamSession } from '@lib/types';
import {
  listCourses,
  listSubjects,
  listPapers,
  createPaper,
  deletePaper,
  uploadPaperPdf,
  EXAM_SESSIONS,
} from '@lib/admin';
import { slugify, semesterLabel, formatFileSize } from '@lib/utils';
import SolutionEditor from './SolutionEditor';

const CURRENT_YEAR = new Date().getFullYear();

export default function PapersTab() {
  const [courses, setCourses] = useState<Course[]>([]);
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [papers, setPapers] = useState<Paper[]>([]);
  const [msg, setMsg] = useState<{ type: string; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [file, setFile] = useState<File | null>(null);
  const [editingSolution, setEditingSolution] = useState<Paper | null>(null);

  const [form, setForm] = useState({
    course_id: '' as number | '',
    subject_id: '' as number | '',
    year: CURRENT_YEAR,
    exam_session: 'Nov/Dec' as ExamSession,
    page_count: '' as number | '',
    is_verified: true,
  });

  useEffect(() => {
    listCourses()
      .then(setCourses)
      .catch((e) => setMsg({ type: 'error', text: e.message }));
  }, []);

  // Load subjects when course changes.
  useEffect(() => {
    if (form.course_id) {
      listSubjects(form.course_id as number).then(setSubjects);
    } else {
      setSubjects([]);
    }
    setForm((f) => ({ ...f, subject_id: '' }));
  }, [form.course_id]);

  // Load papers when subject changes.
  useEffect(() => {
    if (form.subject_id) {
      listPapers(form.subject_id as number).then(setPapers);
    } else {
      setPapers([]);
    }
  }, [form.subject_id]);

  const set = (k: string, v: unknown) => setForm((f) => ({ ...f, [k]: v }));

  const selectedCourse = courses.find((c) => c.id === form.course_id);
  const selectedSubject = subjects.find((s) => s.id === form.subject_id);

  const onFile = (e: Event) => {
    const f = (e.target as HTMLInputElement).files?.[0] ?? null;
    if (f && f.type !== 'application/pdf') {
      setMsg({ type: 'error', text: 'Please select a PDF file.' });
      return;
    }
    setFile(f);
  };

  const submit = async (e: Event) => {
    e.preventDefault();
    if (!form.subject_id || !selectedCourse || !selectedSubject) {
      setMsg({ type: 'error', text: 'Select a course and subject first.' });
      return;
    }
    if (!file) {
      setMsg({ type: 'error', text: 'Please choose a PDF file to upload.' });
      return;
    }
    setBusy(true);
    setMsg({ type: 'info', text: 'Uploading PDF…' });

    try {
      // Build a clean storage path: course/sem/subject-session-year.pdf
      const sessionSlug = slugify(form.exam_session);
      const path = `${selectedCourse.slug}/sem-${selectedSubject.semester}/${selectedSubject.slug}-${sessionSlug}-${form.year}.pdf`;
      const { url, sizeKb } = await uploadPaperPdf(file, path);

      const { error } = await createPaper({
        subject_id: form.subject_id as number,
        year: form.year,
        exam_session: form.exam_session,
        pdf_url: url,
        pdf_size_kb: sizeKb,
        page_count: form.page_count ? Number(form.page_count) : null,
        is_verified: form.is_verified,
      });
      if (error) throw error;

      setMsg({
        type: 'success',
        text: `Uploaded "${selectedSubject.name} ${form.exam_session} ${form.year}". Rebuild the site to publish it.`,
      });
      setFile(null);
      setForm((f) => ({ ...f, page_count: '' }));
      listPapers(form.subject_id as number).then(setPapers);
    } catch (err) {
      setMsg({ type: 'error', text: (err as Error).message });
    } finally {
      setBusy(false);
    }
  };

  const remove = async (p: Paper) => {
    if (!confirm(`Delete the ${p.exam_session} ${p.year} paper?`)) return;
    const { error } = await deletePaper(p.id);
    if (error) setMsg({ type: 'error', text: error.message });
    else listPapers(form.subject_id as number).then(setPapers);
  };

  return (
    <div>
      <div class="card" style="margin-bottom: 2rem;">
        <h3 style="margin-bottom: 1rem;">Upload Paper</h3>
        {msg && <div class={`admin-alert ${msg.type}`}>{msg.text}</div>}
        <form onSubmit={submit}>
          <div class="form-row cols-2">
            <div class="form-group">
              <label>Course</label>
              <select
                class="form-control"
                value={form.course_id}
                onChange={(e) => set('course_id', Number((e.target as HTMLSelectElement).value))}
                required
              >
                <option value="">Select course…</option>
                {courses.map((c) => (
                  <option value={c.id}>{c.name}</option>
                ))}
              </select>
            </div>
            <div class="form-group">
              <label>Subject</label>
              <select
                class="form-control"
                value={form.subject_id}
                onChange={(e) => set('subject_id', Number((e.target as HTMLSelectElement).value))}
                required
                disabled={!form.course_id}
              >
                <option value="">
                  {form.course_id ? 'Select subject…' : 'Select course first'}
                </option>
                {subjects.map((s) => (
                  <option value={s.id}>
                    {semesterLabel(s.semester)} · {s.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div class="form-row cols-3">
            <div class="form-group">
              <label>Year</label>
              <input
                type="number"
                min="2015"
                max="2030"
                class="form-control"
                value={form.year}
                onInput={(e) => set('year', Number((e.target as HTMLInputElement).value))}
                required
              />
            </div>
            <div class="form-group">
              <label>Exam Session</label>
              <select
                class="form-control"
                value={form.exam_session}
                onChange={(e) => set('exam_session', (e.target as HTMLSelectElement).value)}
              >
                {EXAM_SESSIONS.map((s) => (
                  <option value={s}>{s}</option>
                ))}
              </select>
            </div>
            <div class="form-group">
              <label>Page Count (optional)</label>
              <input
                type="number"
                min="1"
                class="form-control"
                value={form.page_count}
                onInput={(e) => {
                  const v = (e.target as HTMLInputElement).value;
                  set('page_count', v ? Number(v) : '');
                }}
              />
            </div>
          </div>

          <div class="form-group">
            <label>PDF File</label>
            <label class={`upload-drop ${file ? 'has-file' : ''}`}>
              <input type="file" accept="application/pdf" onChange={onFile} style="display:none;" />
              {file ? (
                <span>
                  ✅ {file.name} ({formatFileSize(Math.round(file.size / 1024))})
                </span>
              ) : (
                <span>📎 Click to choose a PDF file</span>
              )}
            </label>
          </div>

          <div class="form-group">
            <label style="display: flex; gap: 0.5rem; align-items: center; font-weight: 500;">
              <input
                type="checkbox"
                checked={form.is_verified}
                onChange={(e) => set('is_verified', (e.target as HTMLInputElement).checked)}
              />
              Mark as verified
            </label>
          </div>

          <button type="submit" class="btn btn-primary" disabled={busy}>
            {busy ? 'Uploading…' : 'Upload Paper'}
          </button>
        </form>
      </div>

      {form.subject_id && (
        <div class="card">
          <h3 style="margin-bottom: 1rem;">
            Papers for {selectedSubject?.name} ({papers.length})
          </h3>
          <div style="overflow-x: auto;">
            <table class="admin-table">
              <thead>
                <tr>
                  <th>Session</th>
                  <th>Year</th>
                  <th>Size</th>
                  <th>Downloads</th>
                  <th>PDF</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {papers.map((p) => (
                  <tr>
                    <td>{p.exam_session}</td>
                    <td>{p.year}</td>
                    <td>{formatFileSize(p.pdf_size_kb)}</td>
                    <td>{p.download_count}</td>
                    <td>
                      <a href={p.pdf_url} target="_blank" rel="noopener noreferrer" style="color: var(--accent-primary);">
                        View
                      </a>
                    </td>
                    <td>
                      <div style="display: flex; gap: 0.5rem;">
                        <button class="btn btn-secondary btn-sm" onClick={() => setEditingSolution(p)}>
                          Solution
                        </button>
                        <button class="btn btn-danger btn-sm" onClick={() => remove(p)}>
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {editingSolution && (
        <SolutionEditor
          paper={editingSolution}
          label={`${selectedSubject?.name ?? ''} ${editingSolution.exam_session} ${editingSolution.year}`}
          onClose={() => setEditingSolution(null)}
        />
      )}
    </div>
  );
}
