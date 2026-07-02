import { useEffect, useState } from 'react';
import type { Course, Subject, ExamSession } from '../lib/types';
import {
  listCourses,
  listSubjects,
  updatePaper,
  EXAM_SESSIONS,
} from '../lib/admin';
import { formatFileSize, semesterLabel } from '../lib/utils';

interface Props {
  unverifiedPapers: any[];
  loadUnverified: () => void;
  onApprove: (id: number) => Promise<void>;
  onRemove: (p: any) => Promise<void>;
}

export default function ContributionsTab({
  unverifiedPapers,
  loadUnverified,
  onApprove,
  onRemove,
}: Props) {
  const [courses, setCourses] = useState<Course[]>([]);
  const [editingPaper, setEditingPaper] = useState<any | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Edit Modal form state
  const [editForm, setEditForm] = useState({
    course_id: '' as number | '',
    semester: '' as number | '',
    subject_id: '' as number | '',
    year: new Date().getFullYear(),
    exam_session: 'Nov/Dec' as ExamSession,
    page_count: '' as number | '',
    topics: '',
  });

  const [subjects, setSubjects] = useState<Subject[]>([]);

  useEffect(() => {
    listCourses()
      .then(setCourses)
      .catch((e) => console.error('[submissions] Failed to load courses:', e));
  }, []);

  // Fetch subjects when course changes in the edit modal
  useEffect(() => {
    if (editForm.course_id) {
      listSubjects(editForm.course_id as number)
        .then(setSubjects)
        .catch((e) => console.error('[submissions] Failed to load subjects:', e));
    } else {
      setSubjects([]);
    }
  }, [editForm.course_id]);

  const handleEditClick = (p: any) => {
    // Determine course_id from paper's subject context
    const courseId = p.subject?.course_id || '';
    const semester = p.subject?.semester || '';
    const subjectId = p.subject_id || '';

    setEditForm({
      course_id: courseId,
      semester: semester,
      subject_id: subjectId,
      year: p.year,
      exam_session: p.exam_session,
      page_count: p.page_count || '',
      topics: p.topics || '',
    });
    setError(null);
    setEditingPaper(p);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingPaper) return;
    if (!editForm.subject_id) {
      setError('Please select a subject.');
      return;
    }

    setBusy(true);
    setError(null);

    try {
      const { error: updateErr } = await updatePaper(editingPaper.id, {
        subject_id: editForm.subject_id as number,
        year: Number(editForm.year),
        exam_session: editForm.exam_session,
        page_count: editForm.page_count ? Number(editForm.page_count) : null,
        topics: editForm.topics.trim() || null,
      });

      if (updateErr) throw updateErr;

      setEditingPaper(null);
      loadUnverified();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div>
      <div className="card">
        {unverifiedPapers.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '2rem 0', color: 'var(--text-secondary)' }}>
            <span style={{ fontSize: '3rem', display: 'block', marginBottom: '1rem' }}>🎉</span>
            <h3>No pending submissions!</h3>
            <p style={{ fontSize: '0.875rem', marginTop: '0.5rem' }}>All student contributions have been reviewed.</p>
          </div>
        ) : (
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
                      <a
                        href={p.pdf_url}
                        target="_blank"
                        rel="noopener noreferrer"
                        style={{ color: 'var(--accent-primary)', fontWeight: 600 }}
                      >
                        Open PDF
                      </a>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '0.5rem' }}>
                        <button
                          className="btn btn-primary btn-sm"
                          onClick={() => onApprove(p.id)}
                        >
                          Approve
                        </button>
                        <button
                          className="btn btn-secondary btn-sm"
                          onClick={() => handleEditClick(p)}
                        >
                          Edit
                        </button>
                        <button
                          className="btn btn-danger btn-sm"
                          onClick={() => onRemove(p)}
                        >
                          Reject
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Edit Details Modal */}
      {editingPaper && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ marginBottom: '1.25rem' }}>✏️ Edit Contribution Details</h3>
            {error && <div className="admin-alert error">{error}</div>}
            
            <form onSubmit={handleSave}>
              <div className="form-row cols-2">
                <div className="form-group">
                  <label>Course</label>
                  <select
                    className="form-control"
                    value={editForm.course_id}
                    onChange={(e) => {
                      const val = e.target.value;
                      setEditForm((f) => ({ ...f, course_id: val ? Number(val) : '', subject_id: '' }));
                    }}
                    required
                  >
                    <option value="">Select course...</option>
                    {courses.map((c) => (
                      <option value={c.id}>{c.name}</option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label>Semester</label>
                  <select
                    className="form-control"
                    value={editForm.semester}
                    onChange={(e) => {
                      const val = e.target.value;
                      setEditForm((f) => ({ ...f, semester: val ? Number(val) : '', subject_id: '' }));
                    }}
                    disabled={!editForm.course_id}
                    required
                  >
                    <option value="">Select semester...</option>
                    {editForm.course_id &&
                      Array.from(
                        { length: courses.find((c) => c.id === editForm.course_id)?.total_semesters || 6 },
                        (_, i) => (
                          <option value={i + 1} key={i}>
                            {semesterLabel(i + 1)}
                          </option>
                        )
                      )}
                  </select>
                </div>
              </div>

              <div className="form-group">
                <label>Subject</label>
                <select
                  className="form-control"
                  value={editForm.subject_id}
                  onChange={(e) => {
                    const val = e.target.value;
                    setEditForm((f) => ({ ...f, subject_id: val ? Number(val) : '' }));
                  }}
                  disabled={!editForm.semester}
                  required
                >
                  <option value="">Select subject...</option>
                  {subjects
                    .filter((s) => s.semester === editForm.semester)
                    .map((s) => (
                      <option value={s.id} key={s.id}>
                        {s.name}
                      </option>
                    ))}
                </select>
              </div>

              <div className="form-row cols-3">
                <div className="form-group">
                  <label>Year</label>
                  <input
                    type="number"
                    min="2015"
                    max="2030"
                    className="form-control"
                    value={editForm.year}
                    onInput={(e) =>
                      setEditForm((f) => ({ ...f, year: Number((e.target as HTMLInputElement).value) }))
                    }
                    required
                  />
                </div>

                <div className="form-group">
                  <label>Exam Session</label>
                  <select
                    className="form-control"
                    value={editForm.exam_session}
                    onChange={(e) =>
                      setEditForm((f) => ({ ...f, exam_session: e.target.value as ExamSession }))
                    }
                    required
                  >
                    {EXAM_SESSIONS.map((s) => (
                      <option value={s} key={s}>
                        {s}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="form-group">
                  <label>Page Count (Optional)</label>
                  <input
                    type="number"
                    min="1"
                    className="form-control"
                    value={editForm.page_count}
                    onInput={(e) => {
                      const val = (e.target as HTMLInputElement).value;
                      setEditForm((f) => ({ ...f, page_count: val ? Number(val) : '' }));
                    }}
                  />
                </div>
              </div>

              <div className="form-group">
                <label>Main Topics Asked (Optional)</label>
                <input
                  type="text"
                  className="form-control"
                  placeholder="e.g. Arrays, Recursion, Trees"
                  value={editForm.topics}
                  onInput={(e) =>
                    setEditForm((f) => ({ ...f, topics: (e.target as HTMLInputElement).value }))
                  }
                />
              </div>

              <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'flex-end', marginTop: '1.5rem' }}>
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={() => setEditingPaper(null)}
                  disabled={busy}
                >
                  Cancel
                </button>
                <button type="submit" className="btn btn-primary" disabled={busy}>
                  {busy ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
