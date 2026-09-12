/* Shared display formatting and status vocabulary. */

const TONES = {
  verified: 'success',
  approved: 'success',
  published: 'success',
  clear: 'success',
  ready: 'success',
  resolved: 'success',
  yes: 'success',
  pending: 'warning',
  needs_correction: 'warning',
  ai_generated: 'warning',
  artisan_reviewed: 'warning',
  flagged: 'warning',
  in_progress: 'warning',
  submitted: 'warning',
  under_review: 'warning',
  rejected: 'danger',
  blocked: 'danger',
  disabled: 'danger',
  inactive: 'danger',
  not_started: 'neutral',
  draft: 'neutral',
  unknown: 'neutral',
}

export function toneFor(status) {
  return TONES[String(status || '').toLowerCase()] || 'info'
}

export function label(value) {
  const text = String(value ?? '').trim()
  if (!text) return '—'
  return text
    .replace(/[_-]+/g, ' ')
    .replace(/\b\w/g, (character) => character.toUpperCase())
}

export function initials(name, fallback = 'A') {
  const parts = String(name || '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return fallback
  return (parts[0][0] + (parts[1]?.[0] || '')).toUpperCase()
}

export function rupees(value) {
  if (value === null || value === undefined || value === '') return '—'
  return '₹' + Number(value).toLocaleString('en-IN', { maximumFractionDigits: 0 })
}

function parse(value) {
  if (!value) return null
  const stamp = new Date(/[zZ]|[+-]\d\d:?\d\d$/.test(value) ? value : value + 'Z')
  return Number.isNaN(stamp.getTime()) ? null : stamp
}

export function dateTime(value) {
  const stamp = parse(value)
  if (!stamp) return '—'
  return stamp.toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function date(value) {
  const stamp = parse(value)
  if (!stamp) return '—'
  return stamp.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })
}

/** "3 days ago" style hint used in list rows. */
export function relative(value) {
  const stamp = parse(value)
  if (!stamp) return ''
  const seconds = Math.round((Date.now() - stamp.getTime()) / 1000)
  if (seconds < 60) return 'just now'
  const minutes = Math.round(seconds / 60)
  if (minutes < 60) return `${minutes}m ago`
  const hours = Math.round(minutes / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.round(hours / 24)
  if (days < 31) return `${days}d ago`
  const months = Math.round(days / 30)
  if (months < 12) return `${months}mo ago`
  return `${Math.round(months / 12)}y ago`
}

export function percent(part, total) {
  if (!total) return 0
  return Math.round((part / total) * 100)
}
