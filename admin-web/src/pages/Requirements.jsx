import { useMemo, useState } from 'react'
import { api } from '../lib/api.js'
import { useAsync } from '../lib/useAsync.js'
import { dateTime, rupees } from '../lib/format.js'
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

const STATUS_OPTIONS = [
  { value: 'all', label: 'Any state' },
  { value: 'open', label: 'Open' },
  { value: 'closed', label: 'Closed' },
]

export function Requirements({ reloadKey }) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('all')
  const state = useAsync(() => api('/admin/requirements'), [reloadKey])

  const rows = useMemo(() => {
    const needle = query.trim().toLowerCase()
    return (state.data || []).filter((row) => {
      if (status !== 'all' && row.status !== status) return false
      if (!needle) return true
      return [row.product, row.original, row.buyer_name, row.business_name, row.location, row.buyer_phone]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(needle))
    })
  }, [state.data, query, status])

  return (
    <>
      <PageHead
        title="Requirements"
        desc="What buyers have asked for, posted from the marketplace. A requirement records demand only: it is not an order, creates no commitment, and this console records no decision about it."
      />

      <Card flush>
        <div className="card-head">
          <div className="toolbar" style={{ flex: 1 }}>
            <SearchInput
              value={query}
              onChange={setQuery}
              placeholder="Search need, buyer, business, destination…"
            />
            <Select
              value={status}
              onChange={setStatus}
              options={STATUS_OPTIONS}
              label="Filter by state"
              style={{ width: 168 }}
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

        <Async state={state} label="Loading requirements…">
          {() => (
            <Table
              rows={rows}
              rowKey={(row) => row.id}
              columns={[
                {
                  key: 'product',
                  header: 'Requirement',
                  render: (row) => (
                    <div>
                      <div className="primary truncate" style={{ maxWidth: 300 }}>
                        {row.product}
                      </div>
                      {row.original ? (
                        <div className="sub truncate" style={{ maxWidth: 300 }}>
                          {row.original}
                        </div>
                      ) : null}
                    </div>
                  ),
                },
                {
                  key: 'buyer',
                  header: 'Buyer',
                  render: (row) => (
                    <div>
                      <div className="primary">{row.business_name || row.buyer_name || '—'}</div>
                      {row.business_name && row.buyer_name ? (
                        <div className="sub">{row.buyer_name}</div>
                      ) : null}
                    </div>
                  ),
                },
                {
                  key: 'quantity',
                  header: 'Quantity',
                  render: (row) => <span className="nowrap">{row.quantity}</span>,
                },
                {
                  key: 'budget',
                  header: 'Budget / unit',
                  render: (row) =>
                    row.budget ? (
                      <span className="nowrap">{rupees(row.budget)}</span>
                    ) : (
                      <span className="muted">Discuss</span>
                    ),
                },
                {
                  key: 'lead',
                  header: 'Within',
                  render: (row) => <span className="nowrap">{row.lead_days} days</span>,
                },
                {
                  key: 'location',
                  header: 'Destination',
                  render: (row) => <span className="muted">{row.location || '—'}</span>,
                },
                {
                  key: 'sample',
                  header: 'Sample',
                  render: (row) =>
                    row.sample_required ? (
                      <Pill status="requested">Requested</Pill>
                    ) : (
                      <span className="muted">—</span>
                    ),
                },
                {
                  key: 'status',
                  header: 'State',
                  render: (row) => <Pill status={row.status} />,
                },
                {
                  key: 'created',
                  header: 'Posted',
                  render: (row) => <span className="muted nowrap">{dateTime(row.created_at)}</span>,
                },
              ]}
              empty={
                <Empty
                  icon="search"
                  title="No requirements match"
                  text="Requirements appear once a buyer confirms one in the mobile app."
                />
              }
            />
          )}
        </Async>
      </Card>
    </>
  )
}
