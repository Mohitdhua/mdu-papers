import { useEffect, useState } from 'react';
import type { Course, Subject, Paper, ExamSession, DegreeType } from '../lib/types';
import {
  listCourses,
  listSubjects,
  listPapers,
  createCourse,
  deleteCourse,
  createSubject,
  deleteSubject,
  deletePaper,
  deletePaperPdf,
  updatePaper,
  getClient,
  DEGREE_TYPES,
  EXAM_SESSIONS,
} from '../lib/admin';
import { slugify, semesterLabel, formatFileSize } from '../lib/utils';
import SolutionEditor from './SolutionEditor';

// Define inner sub-tabs
type SubTab = 'papers' | 'subjects' | 'courses';

const emptyCourse = {
  name: '',
  full_name: '',
  degree_type: 'UG' as DegreeType,
  slug: '',
  total_semesters: 6,
  icon_emoji: '📚',
  is_popular: false,
};

const emptySubject = {
  course_id: '' as number | '',
  semester: 1,
  name: '',
  slug: '',
};

export default function ManageTab() {
  const [activeSubTab, setActiveSubTab] = useState<SubTab>('papers');
  
  // Shared States
  const [courses, setCourses] = useState<Course[]>([]);
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [papers, setPapers] = useState<Paper[]>([]);
  const [msg, setMsg] = useState<{ type: string; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  // 1. Papers Manager States
  const [paperFilter, setPaperFilter] = useState({
    course_id: '' as number | '',
    subject_id: '' as number | '',
  });
  const [editingPaper, setEditingPaper] = useState<Paper | null>(null);
  const [editingSolution, setEditingSolution] = useState<Paper | null>(null);
  const [editForm, setEditForm] = useState({
    course_id: '' as number | '',
    semester: '' as number | '',
    subject_id: '' as number | '',
    year: new Date().getFullYear(),
    exam_session: 'Nov/Dec' as ExamSession,
    page_count: '' as number | '',
    topics: '',
  });
  const [editSubjectsList, setEditSubjectsList] = useState<Subject[]>([]);

  // 2. Subjects Manager States
  const [subjForm, setSubjForm] = useState({ ...emptySubject });
  const [filterCourse, setFilterCourse] = useState<number | ''>('');

  // 3. Courses Manager States
  const [courseForm, setCourseForm] = useState({ ...emptyCourse });

  // Load basic items on mount
  const loadCoursesList = async () => {
    try {
      const cList = await listCourses();
      setCourses(cList);
    } catch (e) {
      setMsg({ type: 'error', text: (e as Error).message });
    }
  };

  const loadAllSubjects = async () => {
    try {
      const sList = await listSubjects(filterCourse || undefined);
      setSubjects(sList);
    } catch (e) {
      setMsg({ type: 'error', text: (e as Error).message });
    }
  };

  useEffect(() => {
    loadCoursesList();
  }, []);

  useEffect(() => {
    loadAllSubjects();
  }, [filterCourse]);

  // Load papers when subject filter changes in sub-tab 1
  const loadPapersList = async () => {
    if (paperFilter.subject_id) {
      try {
        const pList = await listPapers(paperFilter.subject_id as number);
        setPapers(pList);
      } catch (e) {
        setMsg({ type: 'error', text: (e as Error).message });
      }
    } else {
      setPapers([]);
    }
  };

  useEffect(() => {
    loadPapersList();
  }, [paperFilter.subject_id]);

  // Fetch subject listing inside edit modal
  useEffect(() => {
    if (editForm.course_id) {
      listSubjects(editForm.course_id as number)
        .then(setEditSubjectsList)
        .catch((e) => console.error('[manage] Failed to load edit modal subjects:', e));
    } else {
      setEditSubjectsList([]);
    }
  }, [editForm.course_id]);

  // Dynamic lists helpers
  const selectedCourseForSubject = courses.find((c) => c.id === subjForm.course_id);
  const subjectsForPaperFilter = subjects.filter((s) => s.course_id === paperFilter.course_id);
  const courseName = (id: number) => courses.find((c) => c.id === id)?.name ?? id;

  // ---------- Action Handlers ----------

  // Course Add
  const handleAddCourse = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    const payload = { ...courseForm, slug: courseForm.slug || slugify(courseForm.name) };
    const { error } = await createCourse(payload);
    setBusy(false);
    if (error) {
      setMsg({ type: 'error', text: error.message });
    } else {
      setMsg({ type: 'success', text: `Course "${payload.name}" added successfully.` });
      setCourseForm({ ...emptyCourse });
      loadCoursesList();
    }
  };

  // Course Delete (Cascading)
  const handleDeleteCourse = async (c: Course) => {
    if (
      !confirm(
        `🚨 WARNING: Deleting course "${c.name}" will delete ALL associated subjects and ALL their question papers/solutions from the database and Cloudflare R2 storage! This cannot be undone.`
      )
    ) {
      return;
    }

    setBusy(true);
    setMsg({ type: 'info', text: 'Performing cascading deletion...' });

    try {
      // 1. Fetch subjects
      const { data: subjectsData, error: subErr } = await getClient()
        .from('subjects')
        .select('id')
        .eq('course_id', c.id);
      if (subErr) throw subErr;

      if (subjectsData && subjectsData.length > 0) {
        for (const s of subjectsData) {
          // 2. Fetch papers for each subject
          const { data: papersData, error: papErr } = await getClient()
            .from('papers')
            .select('id, r2_key')
            .eq('subject_id', s.id);
          if (papErr) throw papErr;

          if (papersData && papersData.length > 0) {
            for (const p of papersData) {
              if (p.r2_key) {
                try {
                  await deletePaperPdf(p.r2_key);
                } catch (e) {
                  console.warn(`[manage] Failed to delete R2 key: ${p.r2_key}`, e);
                }
              }
            }
          }
          // 3. Delete papers of this subject
          await getClient().from('papers').delete().eq('subject_id', s.id);
        }
      }

      // 4. Delete subjects of this course
      await getClient().from('subjects').delete().eq('course_id', c.id);

      // 5. Delete course itself
      const { error: courseErr } = await deleteCourse(c.id);
      if (courseErr) throw courseErr;

      setMsg({ type: 'success', text: `Course "${c.name}" and all its contents deleted from DB & R2.` });
      loadCoursesList();
      loadAllSubjects();
      setPaperFilter({ course_id: '', subject_id: '' });
    } catch (err) {
      setMsg({ type: 'error', text: `Delete failed: ${(err as Error).message}` });
    } finally {
      setBusy(false);
    }
  };

  // Subject Add
  const handleAddSubject = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!subjForm.course_id) {
      setMsg({ type: 'error', text: 'Please select a course.' });
      return;
    }
    setBusy(true);
    setMsg(null);
    const { error } = await createSubject({
      course_id: subjForm.course_id as number,
      semester: subjForm.semester,
      name: subjForm.name,
      slug: subjForm.slug || slugify(subjForm.name),
    });
    setBusy(false);
    if (error) {
      setMsg({ type: 'error', text: error.message });
    } else {
      setMsg({ type: 'success', text: `Subject "${subjForm.name}" added successfully.` });
      setSubjForm({ ...subjForm, name: '', slug: '' });
      loadAllSubjects();
    }
  };

  // Subject Delete (Cascading)
  const handleDeleteSubject = async (s: Subject) => {
    if (
      !confirm(
        `🚨 WARNING: Deleting subject "${s.name}" will delete ALL its question papers and solutions from the database and Cloudflare R2 storage! This cannot be undone.`
      )
    ) {
      return;
    }

    setBusy(true);
    setMsg({ type: 'info', text: 'Deleting papers and cleaning R2...' });

    try {
      // 1. Fetch papers for this subject
      const { data: papersData, error: papErr } = await getClient()
        .from('papers')
        .select('id, r2_key')
        .eq('subject_id', s.id);
      if (papErr) throw papErr;

      if (papersData && papersData.length > 0) {
        for (const p of papersData) {
          if (p.r2_key) {
            try {
              await deletePaperPdf(p.r2_key);
            } catch (e) {
              console.warn(`[manage] Failed to delete R2 key: ${p.r2_key}`, e);
            }
          }
        }
      }

      // 2. Delete papers
      await getClient().from('papers').delete().eq('subject_id', s.id);

      // 3. Delete subject
      const { error: subjErr } = await deleteSubject(s.id);
      if (subjErr) throw subjErr;

      setMsg({ type: 'success', text: `Subject "${s.name}" and all its papers deleted.` });
      loadAllSubjects();
      loadPapersList();
    } catch (err) {
      setMsg({ type: 'error', text: `Delete failed: ${(err as Error).message}` });
    } finally {
      setBusy(false);
    }
  };

  // Paper Edit click
  const handleEditPaperClick = (p: Paper) => {
    // Determine course_id using parent subject mapping
    const subj = subjects.find((s) => s.id === p.subject_id);
    const courseId = subj?.course_id || '';
    const semester = subj?.semester || '';

    setEditForm({
      course_id: courseId,
      semester: semester,
      subject_id: p.subject_id,
      year: p.year,
      exam_session: p.exam_session,
      page_count: p.page_count || '',
      topics: p.topics || '',
    });
    setEditingPaper(p);
  };

  // Paper Edit Save
  const handleSavePaper = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingPaper) return;
    if (!editForm.subject_id) {
      alert('Please select a subject.');
      return;
    }

    setBusy(true);
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
      loadPapersList();
    } catch (err) {
      alert(`Failed to save: ${(err as Error).message}`);
    } finally {
      setBusy(false);
    }
  };

  // Paper Delete (Single paper)
  const handleDeletePaper = async (p: Paper) => {
    if (!confirm(`Delete the ${p.exam_session} ${p.year} paper?`)) return;
    setBusy(true);
    setMsg({ type: 'info', text: 'Deleting paper...' });
    
    try {
      const { error } = await deletePaper(p.id);
      if (error) throw error;

      if (p.r2_key) {
        try {
          await deletePaperPdf(p.r2_key);
        } catch (e) {
          console.warn(`[manage] Best-effort R2 deletion failed for key: ${p.r2_key}`, e);
        }
      }

      setMsg({ type: 'success', text: 'Paper deleted.' });
      loadPapersList();
    } catch (err) {
      setMsg({ type: 'error', text: (err as Error).message });
    } finally {
      setBusy(false);
    }
  };

  return (
    <div>
      {/* Horizontal Sub-navigation Menu */}
      <div style={{ display: 'flex', gap: '0.5rem', borderBottom: '1px solid var(--border)', paddingBottom: '1rem', marginBottom: '2rem' }}>
        <button
          className={`btn ${activeSubTab === 'papers' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => { setActiveSubTab('papers'); setMsg(null); }}
        >
          📄 Papers & Materials
        </button>
        <button
          className={`btn ${activeSubTab === 'subjects' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => { setActiveSubTab('subjects'); setMsg(null); }}
        >
          📚 Subjects Manager
        </button>
        <button
          className={`btn ${activeSubTab === 'courses' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => { setActiveSubTab('courses'); setMsg(null); }}
        >
          🎓 Courses Manager
        </button>
      </div>

      {msg && <div className={`admin-alert ${msg.type}`} style={{ marginBottom: '1.5rem' }}>{msg.text}</div>}

      {/* SUB-TAB 1: PAPERS MANAGER */}
      {activeSubTab === 'papers' && (
        <div>
          <div className="card" style={{ marginBottom: '2rem' }}>
            <h3 style={{ marginBottom: '1rem' }}>Filter Papers</h3>
            <div className="form-row cols-2">
              <div className="form-group">
                <label>Course</label>
                <select
                  className="form-control"
                  value={paperFilter.course_id}
                  onChange={(e) => {
                    const val = e.target.value;
                    setPaperFilter({
                      course_id: val ? Number(val) : '',
                      subject_id: '',
                    });
                  }}
                >
                  <option value="">Select course...</option>
                  {courses.map((c) => (
                    <option value={c.id} key={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label>Subject</label>
                <select
                  className="form-control"
                  value={paperFilter.subject_id}
                  onChange={(e) => {
                    const val = e.target.value;
                    setPaperFilter((f) => ({
                      ...f,
                      subject_id: val ? Number(val) : '',
                    }));
                  }}
                  disabled={!paperFilter.course_id}
                >
                  <option value="">Select subject...</option>
                  {subjectsForPaperFilter.map((s) => (
                    <option value={s.id} key={s.id}>
                      {semesterLabel(s.semester)} — {s.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </div>

          {paperFilter.subject_id && (
            <div className="card">
              <h3 style={{ marginBottom: '1rem' }}>Existing Papers ({papers.length})</h3>
              {papers.length === 0 ? (
                <p className="text-muted">No papers uploaded for this subject yet.</p>
              ) : (
                <div style={{ overflowX: 'auto' }}>
                  <table className="admin-table">
                    <thead>
                      <tr>
                        <th>Session</th>
                        <th>Year</th>
                        <th>Size</th>
                        <th>Status</th>
                        <th>PDF</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {papers.map((p) => (
                        <tr key={p.id}>
                          <td>{p.exam_session}</td>
                          <td>{p.year}</td>
                          <td>{formatFileSize(p.pdf_size_kb)}</td>
                          <td>
                            <span className={`badge ${p.is_verified ? 'badge-success' : 'badge-warning'}`}>
                              {p.is_verified ? 'Verified' : 'Pending'}
                            </span>
                          </td>
                          <td>
                            <a href={p.pdf_url} target="_blank" rel="noopener noreferrer" style={{ color: 'var(--primary)', fontWeight: 600 }}>
                              Open PDF
                            </a>
                          </td>
                          <td>
                            <div style={{ display: 'flex', gap: '0.5rem' }}>
                              <button className="btn btn-secondary btn-sm" onClick={() => handleEditPaperClick(p)}>
                                Edit
                              </button>
                              <button className="btn btn-secondary btn-sm" onClick={() => setEditingSolution(p)}>
                                Solutions
                              </button>
                              <button className="btn btn-danger btn-sm" onClick={() => handleDeletePaper(p)}>
                                Delete
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
          )}
        </div>
      )}

      {/* SUB-TAB 2: SUBJECTS MANAGER */}
      {activeSubTab === 'subjects' && (
        <div>
          <div className="card" style={{ marginBottom: '2rem' }}>
            <h3 style={{ marginBottom: '1rem' }}>Add Subject</h3>
            <form onSubmit={handleAddSubject}>
              <div className="form-row cols-2">
                <div className="form-group">
                  <label>Course</label>
                  <select
                    className="form-control"
                    value={subjForm.course_id}
                    onChange={(e) => setSubjForm((f) => ({ ...f, course_id: Number(e.target.value) }))}
                    required
                  >
                    <option value="">Select course...</option>
                    {courses.map((c) => (
                      <option value={c.id} key={c.id}>{c.name}</option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label>Semester</label>
                  <select
                    className="form-control"
                    value={subjForm.semester}
                    onChange={(e) => setSubjForm((f) => ({ ...f, semester: Number(e.target.value) }))}
                  >
                    {Array.from({ length: selectedCourseForSubject?.total_semesters ?? 8 }, (_, i) => i + 1).map((n) => (
                      <option value={n} key={n}>{semesterLabel(n)}</option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="form-row cols-2">
                <div className="form-group">
                  <label>Subject Name</label>
                  <input
                    className="form-control"
                    placeholder="Data Structures"
                    value={subjForm.name}
                    onInput={(e) => setSubjForm((f) => ({ ...f, name: (e.target as HTMLInputElement).value }))}
                    required
                  />
                </div>
                <div className="form-group">
                  <label>Slug (auto if blank)</label>
                  <input
                    className="form-control"
                    placeholder={slugify(subjForm.name) || 'data-structures'}
                    value={subjForm.slug}
                    onInput={(e) => setSubjForm((f) => ({ ...f, slug: (e.target as HTMLInputElement).value }))}
                  />
                </div>
              </div>
              <button type="submit" className="btn btn-primary" disabled={busy}>
                {busy ? 'Saving...' : 'Add Subject'}
              </button>
            </form>
          </div>

          <div className="card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <h3>Subjects ({subjects.length})</h3>
              <select
                className="form-control"
                style={{ maxWidth: '220px' }}
                value={filterCourse}
                onChange={(e) => setFilterCourse(e.target.value ? Number(e.target.value) : '')}
              >
                <option value="">All courses</option>
                {courses.map((c) => (
                  <option value={c.id} key={c.id}>{c.name}</option>
                ))}
              </select>
            </div>
            <div style={{ overflowX: 'auto' }}>
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Subject</th>
                    <th>Course</th>
                    <th>Sem</th>
                    <th>Papers</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {subjects.map((s) => (
                    <tr key={s.id}>
                      <td style={{ fontWeight: 600 }}>{s.name}</td>
                      <td>{courseName(s.course_id)}</td>
                      <td>{s.semester}</td>
                      <td>{s.paper_count}</td>
                      <td>
                        <button className="btn btn-danger btn-sm" onClick={() => handleDeleteSubject(s)} disabled={busy}>
                          Delete
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* SUB-TAB 3: COURSES MANAGER */}
      {activeSubTab === 'courses' && (
        <div>
          <div className="card" style={{ marginBottom: '2rem' }}>
            <h3 style={{ marginBottom: '1rem' }}>Add Course</h3>
            <form onSubmit={handleAddCourse}>
              <div className="form-row cols-2">
                <div className="form-group">
                  <label>Name (short)</label>
                  <input
                    className="form-control"
                    placeholder="BCA"
                    value={courseForm.name}
                    onInput={(e) => setCourseForm((f) => ({ ...f, name: (e.target as HTMLInputElement).value }))}
                    required
                  />
                </div>
                <div className="form-group">
                  <label>Full Name</label>
                  <input
                    className="form-control"
                    placeholder="Bachelor of Computer Applications"
                    value={courseForm.full_name}
                    onInput={(e) => setCourseForm((f) => ({ ...f, full_name: (e.target as HTMLInputElement).value }))}
                    required
                  />
                </div>
              </div>
              <div className="form-row cols-3">
                <div className="form-group">
                  <label>Degree Type</label>
                  <select
                    className="form-control"
                    value={courseForm.degree_type}
                    onChange={(e) => setCourseForm((f) => ({ ...f, degree_type: e.target.value as DegreeType }))}
                  >
                    {DEGREE_TYPES.map((d) => (
                      <option value={d} key={d}>{d}</option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label>Total Semesters</label>
                  <input
                    type="number"
                    min="1"
                    max="10"
                    className="form-control"
                    value={courseForm.total_semesters}
                    onInput={(e) => setCourseForm((f) => ({ ...f, total_semesters: Number((e.target as HTMLInputElement).value) }))}
                  />
                </div>
                <div className="form-group">
                  <label>Icon Emoji</label>
                  <input
                    className="form-control"
                    value={courseForm.icon_emoji}
                    onInput={(e) => setCourseForm((f) => ({ ...f, icon_emoji: (e.target as HTMLInputElement).value }))}
                  />
                </div>
              </div>
              <div className="form-row cols-2">
                <div className="form-group">
                  <label>Slug (auto if blank)</label>
                  <input
                    className="form-control"
                    placeholder={slugify(courseForm.name) || 'bca'}
                    value={courseForm.slug}
                    onInput={(e) => setCourseForm((f) => ({ ...f, slug: (e.target as HTMLInputElement).value }))}
                  />
                </div>
                <div className="form-group" style={{ display: 'flex', alignItems: 'flex-end' }}>
                  <label style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', fontWeight: 500 }}>
                    <input
                      type="checkbox"
                      checked={courseForm.is_popular}
                      onChange={(e) => setCourseForm((f) => ({ ...f, is_popular: e.target.checked }))}
                    />
                    Show on homepage (popular)
                  </label>
                </div>
              </div>
              <button type="submit" className="btn btn-primary" disabled={busy}>
                {busy ? 'Saving...' : 'Add Course'}
              </button>
            </form>
          </div>

          <div className="card">
            <h3 style={{ marginBottom: '1.25rem' }}>Existing Courses ({courses.length})</h3>
            <div style={{ overflowX: 'auto' }}>
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Type</th>
                    <th>Sems</th>
                    <th>Slug</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {courses.map((c) => (
                    <tr key={c.id}>
                      <td style={{ fontWeight: 600 }}>{c.icon_emoji} {c.name}</td>
                      <td>{c.degree_type}</td>
                      <td>{c.total_semesters}</td>
                      <td>{c.slug}</td>
                      <td>
                        <button className="btn btn-danger btn-sm" onClick={() => handleDeleteCourse(c)} disabled={busy}>
                          Delete
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* EDIT PAPER MODAL */}
      {editingPaper && (
        <div className="modal-overlay">
          <div className="modal-content">
            <h3 style={{ marginBottom: '1.25rem' }}>✏️ Edit Paper Details</h3>
            <form onSubmit={handleSavePaper}>
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
                      <option value={c.id} key={c.id}>{c.name}</option>
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
                  {editSubjectsList
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
                  placeholder="e.g. Arrays, Recursion"
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

      {/* SOLUTION EDITOR MODAL */}
      {editingSolution && (
        <SolutionEditor
          paper={editingSolution}
          label={`${subjects.find((s) => s.id === editingSolution.subject_id)?.name || ''} ${editingSolution.exam_session} ${editingSolution.year}`}
          onClose={() => setEditingSolution(null)}
        />
      )}
    </div>
  );
}
