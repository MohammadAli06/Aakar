import { useMemo, useState } from 'react'
import { api } from '../lib/api.js'
import { useAsync } from '../lib/useAsync.js'
import { navigate } from '../lib/router.jsx'
import { date, label, rupees } from '../lib/format.js'
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
  { value: 'all', label: 'Any product state' },
  { value: 'draft', label: 'Draft' },
  { value: 'ai_generated', label: 'AI generated' },
  { value: 'verified', label: 'Verified' },
  { value: 'published', label: 'Published' },
]

const MODERATION_OPTIONS = [
  { value: 'all', label: 'Any moderation' },
  { value: 'flagged', label: 'Flagged' },
  { value: 'blocked', label: 'Blocked' },
  { value: 'clear', label: 'Clear' },
]

export function Products({ reloadKey }) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState('all')
  const [moderation, setModeration] = useState('all')
  const state = useAsync(() => api('/admin/products'), [reloadKey])

  const rows = useMemo(() => {
    const needle = query.trim().toLowerCase()
    return (state.data || []).filter((row) => {
      if (status !== 'all' && row.status !== status) return false
      if (moderation !== 'all' && row.moderation !== moderation) return false
      if (!needle) return true
      return [row.title, row.artisan_name, row.category, row.listing_status]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(needle))
    })
  }, [state.data, query, status, moderation])

  return (
    <>
      <PageHead
        title="Products"
        desc="Catalogue records with their internal state, listing verification and any moderation decision already recorded."
      />

      <Card flush>
        <div className="card-head">
          <div className="toolbar" style={{ flex: 1 }}>
            <SearchInput value={query} onChange={setQuery} placeholder="Search title, artisan, category…" />
            <Select value={status} onChange={setStatus} options={STATUS_OPTIONS} label="Filter by state" style={{ width: 178 }} />
            <Select
              value={moderation}
              onChange={setModeration}
              options={MODERATION_OPTIONS}
              label="Filter by moderation"
              style={{ width: 176 }}
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

        <Async state={state} label="Loading products…">
          {() => (
            <Table
              rows={rows}
              rowKey={(row) => row.id}
              onRowClick={(row) => navigate('/products/' + row.id)}
              columns={[
                {
                  key: 'title',
                  header: 'Product',
                  render: (row) => (
                    <div>
                      <div className="primary truncate" style={{ maxWidth: 300 }}>
                        {row.title}
                      </div>
                      <div className="sub">{label(row.category)}</div>
                    </div>
                  ),
                },
                {
                  key: 'artisan',
                  header: 'Artisan',
                  render: (row) => <span className="muted">{row.artisan_name || '—'}</span>,
                },
                {
                  key: 'status',
                  header: 'State',
                  render: (row) => <Pill status={row.status} />,
                },
                {
                  key: 'listing',
                  header: 'Listing',
                  render: (row) =>
                    row.has_listing ? (
                      <Pill status={row.listing_status} />
                    ) : (
                      <span className="muted">No listing</span>
                    ),
                },
                {
                  key: 'price',
                  header: 'Final price',
                  render: (row) => (
                    <span className="nowrap">
                      {row.final_price ? rupees(row.final_price) : <span className="muted">Not set</span>}
                    </span>
                  ),
                },
                {
                  key: 'moderation',
                  header: 'Moderation',
                  render: (row) =>
                    row.moderation === 'clear' ? (
                      <span className="muted">Clear</span>
                    ) : (
                      <Pill status={row.moderation} />
                    ),
                },
                {
                  key: 'created',
                  header: 'Created',
                  render: (row) => <span className="muted nowrap">{date(row.created_at)}</span>,
                },
              ]}
              empty={
                <Empty
                  icon="package"
                  title="No products match"
                  text="Products appear once an artisan saves one from the mobile app. Drafts are included."
                />
              }
            />
          )}
        </Async>
      </Card>
    </>
  )
}
