import { useMemo, useState } from 'react'
import { api } from '../lib/api.js'
import { useAsync } from '../lib/useAsync.js'
import { navigate } from '../lib/router.jsx'
import { dateTime, label, toneFor } from '../lib/format.js'
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

const ACTION_TONE = {
  verification_verified: 'success',
  verification_rejected: 'danger',
  verification_needs_correction: 'warning',
  verification_submitted: 'info',
  account_enabled: 'success',
  account_disabled: 'danger',
  product_flag: 'warning',
  product_flagged: 'warning',
  product_blocked: 'danger',
  product_clear: 'success',
}

const FILTERS = [
  { value: 'all', label: 'All events' },
  { value: 'verification', label: 'Verification' },
  { value: 'account', label: 'Account access' },
  { value: 'product', label: 'Moderation' },
]

export function Activity({ reloadKey }) {
  const [query, setQuery] = useState('')
  const [entity, setEntity] = useState('all')
  const state = useAsync(() => api('/admin/activity?limit=200'), [reloadKey])

  const rows = useMemo(() => {
    const needle = query.trim().toLowerCase()
    return (state.data || []).filter((event) => {
      if (entity !== 'all' && event.entity_type !== entity) return false
      if (!needle) return true
      return [event.actor, event.action, event.summary, event.note, event.entity_id]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(needle))
    })
  }, [state.data, query, entity])

  return (
    <>
      <PageHead
        title="Audit trail"
        desc="Administrator decisions and verification submissions on the shared database, newest first. This is a record of what happened, not a security log."
      />

      <Card flush>
        <div className="card-head">
          <div className="toolbar" style={{ flex: 1 }}>
            <SearchInput value={query} onChange={setQuery} placeholder="Search actor, action, note…" />
            <Select value={entity} onChange={setEntity} options={FILTERS} label="Filter by area" style={{ width: 176 }} />
          </div>
          <div className="card-actions">
            <span className="muted" style={{ fontSize: 12 }}>
              {rows.length} events
            </span>
            <Button variant="ghost" size="sm" onClick={state.reload}>
              <Icon name="refresh" size={14} /> Refresh
            </Button>
          </div>
        </div>

        <Async state={state} label="Loading the audit trail…">
          {() => (
            <Table
              rows={rows}
              rowKey={(event, index) => event.entity_id + '-' + event.at + '-' + index}
              columns={[
                {
                  key: 'when',
                  header: 'When',
                  render: (event) => <span className="muted nowrap">{dateTime(event.at)}</span>,
                },
                {
                  key: 'actor',
                  header: 'Actor',
                  render: (event) => <span className="primary">{label(event.actor)}</span>,
                },
                {
                  key: 'action',
                  header: 'Action',
                  render: (event) => (
                    <Pill
                      tone={ACTION_TONE[event.action] || toneFor(event.action.replace(/^[a-z]+_/, ''))}
                      dot={false}
                    >
                      {label(event.action)}
                    </Pill>
                  ),
                },
                {
                  key: 'summary',
                  header: 'Summary',
                  render: (event) => (
                    <div style={{ maxWidth: 420 }}>
                      <div>{event.summary || '—'}</div>
                      {event.note ? <div className="sub">{event.note}</div> : null}
                    </div>
                  ),
                },
                {
                  key: 'entity',
                  header: 'Record',
                  render: (event) => (
                    <span className="mono muted">{String(event.entity_id).slice(0, 10)}</span>
                  ),
                },
                {
                  key: 'open',
                  header: '',
                  align: 'right',
                  render: (event) =>
                    event.entity_type === 'verification' ? (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={(clickEvent) => {
                          clickEvent.stopPropagation()
                          navigate('/verification/' + event.entity_id)
                        }}
                      >
                        Open
                      </Button>
                    ) : event.entity_type === 'account' ? (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={(clickEvent) => {
                          clickEvent.stopPropagation()
                          navigate('/accounts/' + event.entity_id)
                        }}
                      >
                        Open
                      </Button>
                    ) : event.entity_type === 'product' ? (
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={(clickEvent) => {
                          clickEvent.stopPropagation()
                          navigate('/products/' + event.entity_id)
                        }}
                      >
                        Open
                      </Button>
                    ) : null,
                },
              ]}
              empty={
                <Empty
                  icon="activity"
                  title="No events recorded"
                  text="Decision, moderation and access events will appear here as reviewers work through the queue."
                />
              }
            />
          )}
        </Async>
      </Card>
    </>
  )
}
