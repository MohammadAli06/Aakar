import { useMemo, useState } from 'react'
import { loadQueue, REQUIRED_EVIDENCE } from '../lib/verification.js'
import { useAsync } from '../lib/useAsync.js'
import { navigate } from '../lib/router.jsx'
import { dateTime, label, relative } from '../lib/format.js'
import {
  Async,
  Button,
  Card,
  Empty,
  PageHead,
  Pill,
  SearchInput,
  Select,
  Table,
} from '../components/Ui.jsx'
import { Icon } from '../components/Icons.jsx'

const ROLE_OPTIONS = [
  { value: 'all', label: 'All roles' },
  { value: 'artisan', label: 'Artisan' },
  { value: 'buyer', label: 'Buyer' },
]

const STATUS_OPTIONS = [
  { value: 'all', label: 'All statuses' },
  { value: 'pending', label: 'Pending review' },
  { value: 'verified', label: 'Verified' },
  { value: 'needs_correction', label: 'Needs correction' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'not_started', label: 'Not started' },
]

export function Verification({ reloadKey }) {
  const [query, setQuery] = useState('')
  const [role, setRole] = useState('all')
  const [status, setStatus] = useState('pending')
  const state = useAsync(loadQueue, [reloadKey])

  const rows = useMemo(() => {
    const data = state.data || []
    const needle = query.trim().toLowerCase()
    return data.filter((row) => {
      if (role !== 'all' && row.role !== role) return false
      if (status !== 'all' && row.status !== status) return false
      if (!needle) return true
      return [row.name, row.phone, row.email, row.location, row.business_name, row.craft_category]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(needle))
    })
  }, [state.data, query, role, status])

  const pending = (state.data || []).filter((row) => row.status === 'pending').length

  return (
    <>
      <PageHead
        title="Verification"
        desc="Artisan and buyer submissions awaiting a manual decision. Evidence is private: it is fetched with the administrator credential and never cached."
        actions={
          pending ? (
            <span className="pill warning">
              <span className="dot" />
              {pending} waiting
            </span>
          ) : null
        }
      />

      <Card flush>
        <div className="card-head">
          <div className="toolbar" style={{ flex: 1 }}>
            <SearchInput value={query} onChange={setQuery} placeholder="Search name, phone, location…" />
            <Select value={role} onChange={setRole} options={ROLE_OPTIONS} label="Filter by role" style={{ width: 150 }} />
            <Select
              value={status}
              onChange={setStatus}
              options={STATUS_OPTIONS}
              label="Filter by status"
              style={{ width: 176 }}
            />
          </div>
          <div className="card-actions">
            <Button variant="ghost" size="sm" onClick={state.reload}>
              <Icon name="refresh" size={14} /> Refresh
            </Button>
          </div>
        </div>

        <Async state={state} label="Loading the review queue…">
          {() => (
            <Table
              rows={rows}
              rowKey={(row) => row.record_id || row.user_id}
              onRowClick={(row) =>
                navigate(row.record_id ? '/verification/' + row.record_id : '/accounts/' + row.user_id)
              }
              columns={[
                {
                  key: 'applicant',
                  header: 'Applicant',
                  render: (row) => (
                    <div>
                      <div className="primary">{row.name || 'Unnamed account'}</div>
                      <div className="sub">
                        {row.business_name || row.phone || 'No contact recorded'}
                      </div>
                    </div>
                  ),
                },
                {
                  key: 'role',
                  header: 'Role',
                  render: (row) => (
                    <Pill status={row.role} tone="role">
                      {label(row.role)}
                    </Pill>
                  ),
                },
                {
                  key: 'location',
                  header: 'Location',
                  render: (row) => <span className="muted">{row.location || '—'}</span>,
                },
                {
                  key: 'evidence',
                  header: 'Evidence',
                  render: (row) => {
                    const required = REQUIRED_EVIDENCE[row.role] || []
                    const uploaded = required.filter((kind) => row.evidence?.[kind]).length
                    return (
                      <span className="muted nowrap">
                        {uploaded}/{required.length} files
                      </span>
                    )
                  },
                },
                {
                  key: 'submitted',
                  header: 'Submitted',
                  render: (row) => (
                    <span className="muted nowrap" title={dateTime(row.submitted_at)}>
                      {row.submitted_at ? relative(row.submitted_at) : '—'}
                    </span>
                  ),
                },
                {
                  key: 'status',
                  header: 'Status',
                  render: (row) => <Pill status={row.status} />,
                },
                {
                  key: 'action',
                  header: '',
                  align: 'right',
                  render: (row) => (
                    <span className="muted">
                      {row.record_id ? <Icon name="chevron" size={14} /> : 'No submission'}
                    </span>
                  ),
                },
              ]}
              empty={
                <Empty
                  icon="shield"
                  title="No submissions match this view"
                  text="Change the status filter, or wait for an account to submit verification from the mobile app."
                />
              }
            />
          )}
        </Async>
      </Card>
    </>
  )
}
