import { useState } from 'preact/hooks';

interface Option {
  label: string;
  value: string;
}

interface Props {
  label: string;
  options: Option[];
  initialValue?: string;
  /** When set, navigates to `${baseHref}${value}` on change. */
  baseHref?: string;
}

/**
 * Lightweight accessible filter/select. Used for quick course/semester
 * filtering. Falls back to a plain navigation when baseHref is provided.
 */
export default function FilterDropdown({ label, options, initialValue = '', baseHref }: Props) {
  const [value, setValue] = useState(initialValue);

  const onChange = (e: Event) => {
    const v = (e.target as HTMLSelectElement).value;
    setValue(v);
    if (baseHref && v) window.location.href = `${baseHref}${v}`;
  };

  return (
    <label class="filter-dropdown">
      <span class="sr-only">{label}</span>
      <select class="form-control" value={value} onChange={onChange} aria-label={label}>
        <option value="">{label}</option>
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </label>
  );
}
