import { useEffect, useState } from 'react';
import type { Course, Subject, ExamSession } from '../lib/types';
import {
  listCourses,
  listSubjects,
  createPaper,
  uploadPaperPdf,
  EXAM_SESSIONS,
} from '../lib/admin';
import { slugify, semesterLabel, formatFileSize } from '../lib/utils';

const CURRENT_YEAR = new Date().getFullYear();

export default function PapersTab() {
  const [courses, setCourses] = useState<Course[]>([]);
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [msg, setMsg] = useState<{ type: string; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [file, setFile] = useState<File | null>(null);

  const [form, setForm] = useState({
    course_id: '' as number | '',
    subject_id: '' as number | '',
    year: CURRENT_YEAR,
    exam_session: 'Nov/Dec' as ExamSession,
    page_count: '' as number | '',
    topics: '',
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
      const key = `${selectedCourse.slug}/sem-${selectedSubject.semester}/${selectedSubject.slug}/${sessionSlug}-${form.year}.pdf`;
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
    } catch (err) {
      setMsg({ type: 'error', text: (err as Error).message });
    } finally {
      setBusy(false);
    }
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
    </div>
  );
}
