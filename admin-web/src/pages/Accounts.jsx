import { useMemo, useState } from 'react'
import { api } from '../lib/api.js'
import { useAsync } from '../lib/useAsync.js'
import { navigate } from '../lib/router.jsx'
import { date, label } from '../lib/format.js'
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
  { value: 'all', label: 'Any verification' },
  { value: 'verified', label: 'Verified' },
  { value: 'pending', label: 'Pending' },
  { value: 'needs_correction', label: 'Needs correction' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'not_started', label: 'Not started' },
]

export function Accounts({ reloadKey }) {
  const [query, setQuery] = useState('')
  const [role, setRole] = useState('all')
  const [status, setStatus] = useState('all')
  const state = useAsync(() => api('/admin/accounts'), [reloadKey])

  const rows = useMemo(() => {
    const needle = query.trim().toLowerCase()
    return (state.data || []).filter((row) => {
      if (role !== 'all' && row.role !== role) return false
      if (status !== 'all' && row.verification !== status) return false
      if (!needle) return true
      return [row.name, row.phone, row.email, row.location, row.business_name, row.craft_category]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(needle))
    })
  }, [state.data, query, role, status])

  return (
    <>
      <PageHead
        title="Accounts"
        desc="Every registered phone account with its fixed role, business profile and verification state."
      />

      <Card flush>
        <div className="card-head">
          <div className="toolbar" style={{ flex: 1 }}>
            <SearchInput value={query} onChange={setQuery} placeholder="Search name, phone, business…" />
            <Select value={role} onChange={setRole} options={ROLE_OPTIONS} label="Filter by role" style={{ width: 150 }} />
            <Select
              value={status}
              onChange={setStatus}
              options={STATUS_OPTIONS}
              label="Filter by verification"
              style={{ width: 186 }}
            />
          </div>
          <div className="card-actions">
            <span className="muted" style={{ fontSize: 12 }}>
              {rows.length} shown
            </span>
            <Button variant="ghost" size="sm" onClick={state.reload}>
              <Icon name="refresh" size={14} /> Refresh
            </Button>
          </div>
        </div>

        <Async state={state} label="Loading accounts…">
          {() => (
            <Table
              rows={rows}
              rowKey={(row) => row.id}
              onRowClick={(row) => navigate('/accounts/' + row.id)}
              columns={[
                {
                  key: 'name',
                  header: 'Account',
                  render: (row) => (
                    <div>
                      <div className="primary">{row.name || 'Name not set'}</div>
                      <div className="sub">
                        {row.business_name ||
                          (row.craft_category ? label(row.craft_category) : 'No profile detail')}
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
                  key: 'contact',
                  header: 'Contact',
                  render: (row) => (
                    <div>
                      <div>{row.phone || '—'}</div>
                      {row.email ? <div className="sub">{row.email}</div> : null}
                    </div>
                  ),
                },
                {
                  key: 'location',
                  header: 'Location',
                  render: (row) => <span className="muted">{row.location || '—'}</span>,
                },
                {
                  key: 'verification',
                  header: 'Verification',
                  render: (row) => <Pill status={row.verification} />,
                },
                {
                  key: 'active',
                  header: 'Account',
                  render: (row) =>
                    row.is_active ? (
                      <span className="muted">Active</span>
                    ) : (
                      <Pill tone="danger">Disabled</Pill>
                    ),
                },
                {
                  key: 'joined',
                  header: 'Joined',
                  render: (row) => <span className="muted nowrap">{date(row.created_at)}</span>,
                },
              ]}
              empty={
                <Empty
                  icon="users"
                  title="No accounts match"
                  text="Clear the filters to see every registered artisan and buyer account."
                />
              }
            />
          )}
        </Async>
      </Card>
    </>
  )
}
