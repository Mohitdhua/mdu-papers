import { useEffect, useState } from 'react';
import type { Course, Subject, Paper, ExamSession } from '../lib/types';
import {
  listCourses,
  listSubjects,
  listPapers,
  createPaper,
  deletePaper,
  uploadPaperPdf,
  deletePaperPdf,
  verifyPaper,
  listUnverifiedPapers,
  EXAM_SESSIONS,
} from '../lib/admin';
import { slugify, semesterLabel, formatFileSize } from '../lib/utils';
import SolutionEditor from './SolutionEditor';

const CURRENT_YEAR = new Date().getFullYear();

export default function PapersTab() {
  const [courses, setCourses] = useState<Course[]>([]);
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [papers, setPapers] = useState<Paper[]>([]);
  const [unverifiedPapers, setUnverifiedPapers] = useState<any[]>([]);
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
    topics: '',
    is_verified: true,
  });

  const loadUnverified = () => {
    listUnverifiedPapers()
      .then(setUnverifiedPapers)
      .catch((e) => console.error('[admin] Failed to load unverified papers:', e));
  };

  useEffect(() => {
    listCourses()
      .then(setCourses)
      .catch((e) => setMsg({ type: 'error', text: e.message }));
    loadUnverified();
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

  const onFile = (e: any) => {
    const f = (e.target as HTMLInputElement).files?.[0] ?? null;
    if (f && f.type !== 'application/pdf') {
      setMsg({ type: 'error', text: 'Please select a PDF file.' });
      return;
    }
    setFile(f);
  };

  const submit = async (e: any) => {
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
      // Build a clean R2 object key: course/sem-N/subject-session-year.pdf
      const sessionSlug = slugify(form.exam_session);
      const key = `${selectedCourse.slug}/sem-${selectedSubject.semester}/${selectedSubject.slug}-${sessionSlug}-${form.year}.pdf`;
      const { url, sizeKb, key: storedKey } = await uploadPaperPdf(file, key);

      const { error } = await createPaper({
        subject_id: form.subject_id as number,
        year: form.year,
        exam_session: form.exam_session,
        pdf_url: url,
        r2_key: storedKey,
        topics: form.topics.trim() || null,
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
      setForm((f) => ({ ...f, page_count: '', topics: '' }));
      listPapers(form.subject_id as number).then(setPapers);
    } catch (err) {
      setMsg({ type: 'error', text: (err as Error).message });
    } finally {
      setBusy(false);
    }
  };

  const approve = async (pId: number) => {
    try {
      setBusy(true);
      setMsg({ type: 'info', text: 'Approving paper…' });
      await verifyPaper(pId);
      setMsg({ type: 'success', text: 'Paper approved successfully! Rebuild the site to publish it.' });
      loadUnverified();
      if (form.subject_id) {
        listPapers(form.subject_id as number).then(setPapers);
      }
    } catch (err) {
      setMsg({ type: 'error', text: (err as Error).message });
    } finally {
      setBusy(false);
    }
  };

  const remove = async (p: Paper) => {
    if (!confirm(`Delete the ${p.exam_session} ${p.year} paper?`)) return;
    const { error } = await deletePaper(p.id);
    if (error) {
      setMsg({ type: 'error', text: error.message });
      return;
    }
    // Best-effort: also remove the PDF from R2.
    if (p.r2_key) {
      try {
        await deletePaperPdf(p.r2_key);
      } catch {
        /* ignore — DB record already gone */
      }
    }
    if (form.subject_id) {
      listPapers(form.subject_id as number).then(setPapers);
    }
    loadUnverified();
  };

  return (
    <div>
      <div className="card" style={{ marginBottom: '2rem' }}>
        <h3 style={{ marginBottom: '1rem' }}>Upload Paper</h3>
        {msg && <div className={`admin-alert ${msg.type}`}>{msg.text}</div>}
        <form onSubmit={submit}>
          <div className="form-row cols-2">
            <div className="form-group">
              <label>Course</label>
              <select
                className="form-control"
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
            <div className="form-group">
              <label>Subject</label>
              <select
                className="form-control"
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

          <div className="form-row cols-3">
            <div className="form-group">
              <label>Year</label>
              <input
                type="number"
                min="2015"
                max="2030"
                className="form-control"
                value={form.year}
                onInput={(e) => set('year', Number((e.target as HTMLInputElement).value))}
                required
              />
            </div>
            <div className="form-group">
              <label>Exam Session</label>
              <select
                className="form-control"
                value={form.exam_session}
                onChange={(e) => set('exam_session', (e.target as HTMLSelectElement).value)}
              >
                {EXAM_SESSIONS.map((s) => (
                  <option value={s}>{s}</option>
                ))}
              </select>
            </div>
            <div className="form-group">
              <label>Page Count (optional)</label>
              <input
                type="number"
                min="1"
                className="form-control"
                value={form.page_count}
                onInput={(e) => {
                  const v = (e.target as HTMLInputElement).value;
                  set('page_count', v ? Number(v) : '');
                }}
              />
            </div>
          </div>

          <div className="form-group">
            <label>Main Topics Asked (optional, comma separated)</label>
            <input
              className="form-control"
              placeholder="e.g. Matrices, Differential Equations, Vector Calculus"
              value={form.topics}
              onInput={(e) => set('topics', (e.target as HTMLInputElement).value)}
            />
            <p className="text-muted" style={{ fontSize: '0.75rem', marginTop: '0.25rem' }}>
              Listing the real topics from this paper creates unique page content (great for SEO).
            </p>
          </div>

          <div className="form-group">
            <label>PDF File</label>
            <label className={`upload-drop ${file ? 'has-file' : ''}`}>
              <input type="file" accept="application/pdf" onChange={onFile} style={{ display: 'none' }} />
              {file ? (
                <span>
                  ✅ {file.name} ({formatFileSize(Math.round(file.size / 1024))})
                </span>
              ) : (
                <span>📎 Click to choose a PDF file</span>
              )}
            </label>
          </div>

          <div className="form-group">
            <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', fontWeight: 500 }}>
              <input
                type="checkbox"
                checked={form.is_verified}
                onChange={(e) => set('is_verified', (e.target as HTMLInputElement).checked)}
              />
              Mark as verified
            </label>
          </div>

          <button type="submit" className="btn btn-primary" disabled={busy}>
            {busy ? 'Uploading…' : 'Upload Paper'}
          </button>
        </form>
      </div>

      {unverifiedPapers.length > 0 && (
        <div className="card" style={{ marginBottom: '2rem', border: '1px solid var(--accent-warning)' }}>
          <h3 style={{ marginBottom: '1rem', color: 'var(--accent-warning)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            ⚠️ Pending Student Submissions ({unverifiedPapers.length})
          </h3>
          <div style={{ overflowX: 'auto' }}>
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Course</th>
                  <th>Subject</th>
                  <th>Session</th>
                  <th>Year</th>
                  <th>Size</th>
                  <th>Uploaded By</th>
                  <th>PDF</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {unverifiedPapers.map((p) => (
                  <tr key={p.id}>
                    <td style={{ fontWeight: 600 }}>{p.course_name}</td>
                    <td>{p.subject_name}</td>
                    <td>{p.exam_session}</td>
                    <td>{p.year}</td>
                    <td>{formatFileSize(p.pdf_size_kb)}</td>
                    <td>{p.uploaded_by || 'student'}</td>
                    <td>
                      <a href={p.pdf_url} target="_blank" rel="noopener noreferrer" style={{ color: 'var(--accent-primary)', fontWeight: 600 }}>
                        Open PDF
                      </a>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        <button className="btn btn-primary btn-sm" onClick={() => approve(p.id)}>
                          Approve
                        </button>
                        <button className="btn btn-danger btn-sm" onClick={() => remove(p)}>
                          Reject
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

      {form.subject_id && (
        <div className="card">
          <h3 style={{ marginBottom: '1rem' }}>
            Papers for {selectedSubject?.name} ({papers.length})
          </h3>
          <div style={{ overflowX: 'auto' }}>
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Session</th>
                  <th>Year</th>
                  <th>Size</th>
                  <th>Status</th>
                  <th>Downloads</th>
                  <th>PDF</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {papers.map((p) => (
                  <tr key={p.id}>
                    <td>{p.exam_session}</td>
                    <td>{p.year}</td>
                    <td>{formatFileSize(p.pdf_size_kb)}</td>
                    <td>
                      {p.is_verified ? (
                        <span style={{ color: 'var(--accent-success)', fontWeight: 600 }}>Verified</span>
                      ) : (
                        <span style={{ color: 'var(--accent-warning)', fontWeight: 600 }}>Pending</span>
                      )}
                    </td>
                    <td>{p.download_count}</td>
                    <td>
                      <a href={p.pdf_url} target="_blank" rel="noopener noreferrer" style={{ color: 'var(--accent-primary)' }}>
                        View
                      </a>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        {!p.is_verified && (
                          <button className="btn btn-primary btn-sm" onClick={() => approve(p.id)}>
                            Approve
                          </button>
                        )}
                        <button className="btn btn-secondary btn-sm" onClick={() => setEditingSolution(p)}>
                          Solution
                        </button>
                        <button className="btn btn-danger btn-sm" onClick={() => remove(p)}>
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
