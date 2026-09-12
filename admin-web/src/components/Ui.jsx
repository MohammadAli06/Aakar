import { Fragment } from 'react'
import { Icon } from './Icons.jsx'
import { toneFor, label as titleCase } from '../lib/format.js'

export function Card({ title, sub, actions, children, className = '', flush = false }) {
  const hasHead = title || sub || actions
  return (
    <section className={['card', className].filter(Boolean).join(' ')}>
      {hasHead ? (
        <header className="card-head">
          <div style={{ minWidth: 0 }}>
            {title ? <div className="card-title">{title}</div> : null}
            {sub ? <div className="card-sub">{sub}</div> : null}
          </div>
          {actions ? <div className="card-actions">{actions}</div> : null}
        </header>
      ) : null}
      {children === undefined || children === null ? null : (
        <div className={flush ? 'card-body flush' : 'card-body'}>{children}</div>
      )}
    </section>
  )
}

export function PageHead({ title, desc, actions }) {
  return (
    <header className="page-head">
      <div style={{ minWidth: 0 }}>
        <h1 className="page-title">{title}</h1>
        {desc ? <p className="page-desc">{desc}</p> : null}
      </div>
      {actions ? <div className="page-actions">{actions}</div> : null}
    </header>
  )
}

export function Button({ variant = 'primary', size, block, className = '', children, ...rest }) {
  const classes = ['btn', variant === 'primary' ? '' : variant, size || '', block ? 'block' : '', className]
    .filter(Boolean)
    .join(' ')
  return (
    <button type="button" className={classes} {...rest}>
      {children}
    </button>
  )
}

export function Pill({ status, tone, children, dot = true }) {
  return (
    <span className={'pill ' + (tone || toneFor(status))}>
      {dot ? <span className="dot" /> : null}
      {children ?? titleCase(status)}
    </span>
  )
}

export function Banner({ tone = 'info', icon = 'sparkle', children }) {
  return (
    <div className={'banner' + (tone === 'info' ? '' : ' ' + tone)}>
      <span className="banner-icon">
        <Icon name={icon} size={16} />
      </span>
      <div>{children}</div>
    </div>
  )
}

export function SearchInput({ value, onChange, placeholder = 'Search…' }) {
  return (
    <div className="search">
      <span className="search-icon">
        <Icon name="search" size={16} />
      </span>
      <input
        className="input"
        type="search"
        value={value}
        placeholder={placeholder}
        aria-label={placeholder}
        onChange={(event) => onChange(event.target.value)}
      />
    </div>
  )
}

export function Select({ value, onChange, options, label: ariaLabel, disabled, style }) {
  return (
    <div className="select-wrap" style={style}>
      <select
        className="select"
        value={value}
        disabled={disabled}
        aria-label={ariaLabel}
        onChange={(event) => onChange(event.target.value)}
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </div>
  )
}

export function Field({ label: text, hint, children }) {
  return (
    <div className="field">
      {text ? <label>{text}</label> : null}
      {children}
      {hint ? <span className="hint">{hint}</span> : null}
    </div>
  )
}

export function Table({ columns, rows, rowKey, onRowClick, empty }) {
  if (!rows.length) return empty || <Empty />
  return (
    <div className="table-wrap">
      <table className="data">
        <thead>
          <tr>
            {columns.map((column) => (
              <th
                key={column.key}
                className={column.align === 'right' ? 'cell-actions' : undefined}
                style={column.width ? { width: column.width } : undefined}
              >
                {column.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, index) => (
            <tr
              key={rowKey ? rowKey(row, index) : index}
              className={onRowClick ? 'clickable' : undefined}
              onClick={onRowClick ? () => onRowClick(row) : undefined}
            >
              {columns.map((column) => (
                <td key={column.key} className={column.align === 'right' ? 'cell-actions' : undefined}>
                  {column.render(row)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export function Empty({ icon = 'inbox', title = 'Nothing here yet', text, action }) {
  return (
    <div className="empty">
      <div className="empty-icon">
        <Icon name={icon} size={22} />
      </div>
      <div className="empty-title">{title}</div>
      {text ? <p className="empty-text">{text}</p> : null}
      {action ? <div style={{ marginTop: 16, display: 'flex', justifyContent: 'center' }}>{action}</div> : null}
    </div>
  )
}

export function Loading({ label: text = 'Loading…' }) {
  return (
    <div className="loading">
      <span className="spinner" />
      {text}
    </div>
  )
}

export function ErrorState({ error, onRetry }) {
  return (
    <div className="error-state">
      <Banner tone="danger" icon="alert">
        {error?.message || 'Something went wrong.'}
      </Banner>
      {onRetry ? (
        <div style={{ marginTop: 12 }}>
          <Button variant="ghost" size="sm" onClick={onRetry}>
            <Icon name="refresh" size={14} /> Try again
          </Button>
        </div>
      ) : null}
    </div>
  )
}

/** Renders loading / error / content for a `useAsync` result. */
export function Async({ state, children, label: text }) {
  if (state.loading) return <Loading label={text} />
  if (state.error) return <ErrorState error={state.error} onRetry={state.reload} />
  return children(state.data)
}

export function StatCard({ icon, tone, label: text, value, foot }) {
  return (
    <div className="card">
      <div className="stat">
        <div className={'stat-icon' + (tone ? ' ' + tone : '')}>
          <Icon name={icon} size={19} />
        </div>
        <div style={{ minWidth: 0 }}>
          <div className="stat-label">{text}</div>
          <div className="stat-value">{value}</div>
          {foot ? <div className="stat-foot">{foot}</div> : null}
        </div>
      </div>
    </div>
  )
}

export function Bar({ label: name, value, total, tone }) {
  const width = total ? Math.max(value > 0 ? 3 : 0, Math.round((value / total) * 100)) : 0
  return (
    <div className="bar-row">
      <div className="bar-label">{name}</div>
      <div className="bar-track">
        <div className={'bar-fill' + (tone ? ' ' + tone : '')} style={{ width: width + '%' }} />
      </div>
      <div className="bar-value">{value}</div>
    </div>
  )
}

export function Donut({ segments, total, center, size = 138, thickness = 17 }) {
  const sum = total ?? segments.reduce((accumulator, segment) => accumulator + segment.value, 0)
  const radius = (size - thickness) / 2
  const circumference = 2 * Math.PI * radius
  let offset = 0

  return (
    <svg className="donut" width={size} height={size} viewBox={`0 0 ${size} ${size}`} role="img">
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        fill="none"
        stroke="var(--line)"
        strokeWidth={thickness}
      />
      {sum > 0
        ? segments.map((segment) => {
            const length = (segment.value / sum) * circumference
            const circle = (
              <circle
                key={segment.label}
                cx={size / 2}
                cy={size / 2}
                r={radius}
                fill="none"
                stroke={segment.color}
                strokeWidth={thickness}
                strokeDasharray={`${length} ${circumference - length}`}
                strokeDashoffset={-offset}
                transform={`rotate(-90 ${size / 2} ${size / 2})`}
              />
            )
            offset += length
            return circle
          })
        : null}
      {center ? (
        <text
          x="50%"
          y="50%"
          textAnchor="middle"
          dominantBaseline="central"
          fill="var(--ink)"
          style={{ font: '600 20px var(--sans)' }}
        >
          {center}
        </text>
      ) : null}
    </svg>
  )
}

export function Legend({ segments }) {
  return (
    <div className="legend">
      {segments.map((segment) => (
        <div className="legend-item" key={segment.label}>
          <span className="swatch" style={{ background: segment.color }} />
          {segment.label}
          <span className="legend-value">{segment.value}</span>
        </div>
      ))}
    </div>
  )
}

export function KV({ items }) {
  const rows = items.filter(Boolean)
  return (
    <dl className="kv">
      {rows.map(([key, value]) => (
        <Fragment key={key}>
          <dt>{key}</dt>
          <dd>{value === null || value === undefined || value === '' ? '—' : value}</dd>
        </Fragment>
      ))}
    </dl>
  )
}

export function SectionLabel({ children }) {
  return <div className="section-label">{children}</div>
}

export function Modal({ open, title, sub, onClose, children, footer, wide = false }) {
  if (!open) return null
  return (
    <div className="modal-backdrop" role="presentation" onClick={onClose}>
      <div
        className={'modal' + (wide ? ' wide' : '')}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(event) => event.stopPropagation()}
      >
        <header className="modal-head">
          <div style={{ minWidth: 0 }}>
            <h3>{title}</h3>
            {sub ? <div className="card-sub">{sub}</div> : null}
          </div>
          <button
            type="button"
            className="icon-btn"
            style={{ marginLeft: 'auto' }}
            onClick={onClose}
            aria-label="Close"
          >
            <Icon name="close" size={16} />
          </button>
        </header>
        <div className="modal-body">{children}</div>
        {footer ? <div className="modal-foot">{footer}</div> : null}
      </div>
    </div>
  )
}

export function Avatar({ name }) {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  const text = parts.length
    ? (parts[0][0] + (parts[1]?.[0] || '')).toUpperCase()
    : '··'
  return <span className="avatar">{text}</span>
}
