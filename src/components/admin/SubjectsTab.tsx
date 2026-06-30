import { useEffect, useState } from 'preact/hooks';
import type { Course, Subject } from '@lib/types';
import { listCourses, listSubjects, createSubject, deleteSubject } from '@lib/admin';
import { slugify, semesterLabel } from '@lib/utils';

export default function SubjectsTab() {
  const [courses, setCourses] = useState<Course[]>([]);
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [filterCourse, setFilterCourse] = useState<number | ''>('');
  const [msg, setMsg] = useState<{ type: string; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  const [form, setForm] = useState({
    course_id: '' as number | '',
    semester: 1,
    name: '',
    slug: '',
  });

  const loadCourses = async () => {
    try {
      const c = await listCourses();
      setCourses(c);
    } catch (e) {
      setMsg({ type: 'error', text: (e as Error).message });
    }
  };
  const loadSubjects = async () => {
    try {
      setSubjects(await listSubjects(filterCourse || undefined));
    } catch (e) {
      setMsg({ type: 'error', text: (e as Error).message });
    }
  };

  useEffect(() => {
    loadCourses();
  }, []);
  useEffect(() => {
    loadSubjects();
  }, [filterCourse]);

  const set = (k: string, v: unknown) => setForm((f) => ({ ...f, [k]: v }));
  const selectedCourse = courses.find((c) => c.id === form.course_id);

  const submit = async (e: Event) => {
    e.preventDefault();
    if (!form.course_id) {
      setMsg({ type: 'error', text: 'Please select a course.' });
      return;
    }
    setBusy(true);
    setMsg(null);
    const { error } = await createSubject({
      course_id: form.course_id as number,
      semester: form.semester,
      name: form.name,
      slug: form.slug || slugify(form.name),
    });
    setBusy(false);
    if (error) setMsg({ type: 'error', text: error.message });
    else {
      setMsg({ type: 'success', text: `Subject "${form.name}" added.` });
      setForm({ ...form, name: '', slug: '' });
      loadSubjects();
    }
  };

  const remove = async (s: Subject) => {
    if (!confirm(`Delete "${s.name}" and all its papers?`)) return;
    const { error } = await deleteSubject(s.id);
    if (error) setMsg({ type: 'error', text: error.message });
    else loadSubjects();
  };

  const courseName = (id: number) => courses.find((c) => c.id === id)?.name ?? id;

  return (
    <div>
      <div class="card" style="margin-bottom: 2rem;">
        <h3 style="margin-bottom: 1rem;">Add Subject</h3>
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
              <label>Semester</label>
              <select
                class="form-control"
                value={form.semester}
                onChange={(e) => set('semester', Number((e.target as HTMLSelectElement).value))}
              >
                {Array.from({ length: selectedCourse?.total_semesters ?? 8 }, (_, i) => i + 1).map(
                  (n) => (
                    <option value={n}>{semesterLabel(n)}</option>
                  )
                )}
              </select>
            </div>
          </div>
          <div class="form-row cols-2">
            <div class="form-group">
              <label>Subject Name</label>
              <input
                class="form-control"
                placeholder="Data Structures"
                value={form.name}
                onInput={(e) => set('name', (e.target as HTMLInputElement).value)}
                required
              />
            </div>
            <div class="form-group">
              <label>Slug (auto if blank)</label>
              <input
                class="form-control"
                placeholder={slugify(form.name) || 'data-structures'}
                value={form.slug}
                onInput={(e) => set('slug', (e.target as HTMLInputElement).value)}
              />
            </div>
          </div>
          <button type="submit" class="btn btn-primary" disabled={busy}>
            {busy ? 'Saving…' : 'Add Subject'}
          </button>
        </form>
      </div>

      <div class="card">
        <div class="section-header" style="margin-bottom: 1rem;">
          <h3>Subjects ({subjects.length})</h3>
          <select
            class="form-control"
            style="max-width: 220px;"
            value={filterCourse}
            onChange={(e) => {
              const v = (e.target as HTMLSelectElement).value;
              setFilterCourse(v ? Number(v) : '');
            }}
          >
            <option value="">All courses</option>
            {courses.map((c) => (
              <option value={c.id}>{c.name}</option>
            ))}
          </select>
        </div>
        <div style="overflow-x: auto;">
          <table class="admin-table">
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
                <tr>
                  <td>{s.name}</td>
                  <td>{courseName(s.course_id)}</td>
                  <td>{s.semester}</td>
                  <td>{s.paper_count}</td>
                  <td>
                    <button class="btn btn-danger btn-sm" onClick={() => remove(s)}>
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
  );
}
