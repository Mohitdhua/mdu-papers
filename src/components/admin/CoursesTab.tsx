import { useEffect, useState } from 'preact/hooks';
import type { Course, DegreeType } from '@lib/types';
import { listCourses, createCourse, deleteCourse, DEGREE_TYPES } from '@lib/admin';
import { slugify } from '@lib/utils';

const empty = {
  name: '',
  full_name: '',
  degree_type: 'UG' as DegreeType,
  slug: '',
  total_semesters: 6,
  icon_emoji: '📚',
  is_popular: false,
};

export default function CoursesTab() {
  const [courses, setCourses] = useState<Course[]>([]);
  const [form, setForm] = useState({ ...empty });
  const [msg, setMsg] = useState<{ type: string; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  const load = async () => {
    try {
      setCourses(await listCourses());
    } catch (e) {
      setMsg({ type: 'error', text: (e as Error).message });
    }
  };

  useEffect(() => {
    load();
  }, []);

  const set = (k: string, v: unknown) => setForm((f) => ({ ...f, [k]: v }));

  const submit = async (e: Event) => {
    e.preventDefault();
    setBusy(true);
    setMsg(null);
    const payload = { ...form, slug: form.slug || slugify(form.name) };
    const { error } = await createCourse(payload);
    setBusy(false);
    if (error) {
      setMsg({ type: 'error', text: error.message });
    } else {
      setMsg({ type: 'success', text: `Course "${payload.name}" added.` });
      setForm({ ...empty });
      load();
    }
  };

  const remove = async (c: Course) => {
    if (!confirm(`Delete "${c.name}" and ALL its subjects and papers? This cannot be undone.`))
      return;
    const { error } = await deleteCourse(c.id);
    if (error) setMsg({ type: 'error', text: error.message });
    else {
      setMsg({ type: 'success', text: `Deleted "${c.name}".` });
      load();
    }
  };

  return (
    <div>
      <div class="card" style="margin-bottom: 2rem;">
        <h3 style="margin-bottom: 1rem;">Add Course</h3>
        {msg && <div class={`admin-alert ${msg.type}`}>{msg.text}</div>}
        <form onSubmit={submit}>
          <div class="form-row cols-2">
            <div class="form-group">
              <label>Name (short)</label>
              <input
                class="form-control"
                placeholder="BCA"
                value={form.name}
                onInput={(e) => set('name', (e.target as HTMLInputElement).value)}
                required
              />
            </div>
            <div class="form-group">
              <label>Full Name</label>
              <input
                class="form-control"
                placeholder="Bachelor of Computer Applications"
                value={form.full_name}
                onInput={(e) => set('full_name', (e.target as HTMLInputElement).value)}
                required
              />
            </div>
          </div>
          <div class="form-row cols-3">
            <div class="form-group">
              <label>Degree Type</label>
              <select
                class="form-control"
                value={form.degree_type}
                onChange={(e) => set('degree_type', (e.target as HTMLSelectElement).value)}
              >
                {DEGREE_TYPES.map((d) => (
                  <option value={d}>{d}</option>
                ))}
              </select>
            </div>
            <div class="form-group">
              <label>Total Semesters</label>
              <input
                type="number"
                min="1"
                max="10"
                class="form-control"
                value={form.total_semesters}
                onInput={(e) => set('total_semesters', Number((e.target as HTMLInputElement).value))}
              />
            </div>
            <div class="form-group">
              <label>Icon Emoji</label>
              <input
                class="form-control"
                value={form.icon_emoji}
                onInput={(e) => set('icon_emoji', (e.target as HTMLInputElement).value)}
              />
            </div>
          </div>
          <div class="form-row cols-2">
            <div class="form-group">
              <label>Slug (auto if blank)</label>
              <input
                class="form-control"
                placeholder={slugify(form.name) || 'bca'}
                value={form.slug}
                onInput={(e) => set('slug', (e.target as HTMLInputElement).value)}
              />
            </div>
            <div class="form-group" style="display: flex; align-items: flex-end;">
              <label style="display: flex; gap: 0.5rem; align-items: center; font-weight: 500;">
                <input
                  type="checkbox"
                  checked={form.is_popular}
                  onChange={(e) => set('is_popular', (e.target as HTMLInputElement).checked)}
                />
                Show on homepage (popular)
              </label>
            </div>
          </div>
          <button type="submit" class="btn btn-primary" disabled={busy}>
            {busy ? 'Saving…' : 'Add Course'}
          </button>
        </form>
      </div>

      <div class="card">
        <h3 style="margin-bottom: 1rem;">Existing Courses ({courses.length})</h3>
        <div style="overflow-x: auto;">
          <table class="admin-table">
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
                <tr>
                  <td>
                    {c.icon_emoji} {c.name}
                  </td>
                  <td>{c.degree_type}</td>
                  <td>{c.total_semesters}</td>
                  <td>{c.slug}</td>
                  <td>
                    <button class="btn btn-danger btn-sm" onClick={() => remove(c)}>
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
