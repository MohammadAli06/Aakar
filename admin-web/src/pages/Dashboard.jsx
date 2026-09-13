import { api } from '../lib/api.js'
import { useAsync } from '../lib/useAsync.js'
import { loadQueue } from '../lib/verification.js'
import { navigate } from '../lib/router.jsx'
import { dateTime, label, relative, toneFor } from '../lib/format.js'
import {
  Async,
  Bar,
  Button,
  Card,
  Donut,
  Empty,
  Legend,
  PageHead,
  Pill,
  StatCard,
} from '../components/Ui.jsx'
import { Icon } from '../components/Icons.jsx'

const ROLE_COLORS = { artisan: '#2f7550', buyer: '#35637f' }

export function Dashboard({ reloadKey }) {
  const state = useAsync(async () => {
    const [overview, activity, queue] = await Promise.all([
      api('/admin/overview'),
      api('/admin/activity?limit=6'),
      loadQueue(),
    ])
    return { overview, activity, queue }
  }, [reloadKey])

  return (
    <>
      <PageHead
        title="Dashboard"
        desc="Live counts from the shared backend. Verification, moderation and manual review are the responsibilities this console actually carries."
      />

      <Async state={state} label="Reading the workspace…">
        {({ overview, activity, queue }) => {
          const accounts = overview.accounts
          const verifications = overview.verifications
          const products = overview.products
          const requirements = overview.requirements || { total: 0, open: 0 }
          const verificationTotal =
            verifications.pending +
            verifications.verified +
            verifications.needs_correction +
            verifications.rejected +
            verifications.not_started
          const pendingRows = queue.filter((row) => row.status === 'pending')

          return (
            <div className="stack">
              <div className="grid grid-4">
                <StatCard
                  icon="users"
                  label="Accounts"
                  value={accounts.total}
                  foot={`${accounts.artisan} artisan · ${accounts.buyer} buyer`}
                />
                <StatCard
                  icon="shield"
                  tone="amber"
                  label="Awaiting verification"
                  value={verifications.pending}
                  foot={`${accounts.verified} artisan verified`}
                />
                <StatCard
                  icon="package"
                  tone="blue"
                  label="Products"
                  value={products.total}
                  foot={`${products.by_status.published} published`}
                />
                <StatCard
                  icon="flag"
                  tone="red"
                  label="Flagged listings"
                  value={products.flagged}
                  foot="moderation decisions recorded"
                />
              </div>

              <div className="grid grid-2-1">
                <Card
                  title="Verification pipeline"
                  sub={`${verificationTotal} registration${verificationTotal === 1 ? '' : 's'} tracked`}
                  actions={
                    <Button variant="ghost" size="sm" onClick={() => navigate('/verification')}>
                      Open queue <Icon name="chevron" size={13} />
                    </Button>
                  }
                >
                  <div className="bars">
                    <Bar label="Pending" value={verifications.pending} total={verificationTotal} tone="warning" />
                    <Bar label="Verified" value={verifications.verified} total={verificationTotal} tone="success" />
                    <Bar
                      label="Needs correction"
                      value={verifications.needs_correction}
                      total={verificationTotal}
                      tone="info"
                    />
                    <Bar label="Rejected" value={verifications.rejected} total={verificationTotal} tone="danger" />
                    <Bar
                      label="Not started"
                      value={verifications.not_started}
                      total={verificationTotal}
                      tone="neutral"
                    />
                  </div>
                </Card>

                <Card title="Accounts by role" sub="Registered artisan and buyer identities">
                  <div className="donut-wrap">
                    <Donut
                      center={String(accounts.total)}
                      segments={[
                        { label: 'Artisan', value: accounts.artisan, color: ROLE_COLORS.artisan },
                        { label: 'Buyer', value: accounts.buyer, color: ROLE_COLORS.buyer },
                      ]}
                    />
                    <Legend
                      segments={[
                        { label: 'Artisan', value: accounts.artisan, color: ROLE_COLORS.artisan },
                        { label: 'Buyer', value: accounts.buyer, color: ROLE_COLORS.buyer },
                      ]}
                    />
                  </div>
                </Card>
              </div>

              <div className="grid grid-2">
                <Card
                  title="Needs attention"
                  sub="Submissions waiting on a reviewer"
                  actions={
                    pendingRows.length ? (
                      <span className="pill warning">
                        <span className="dot" />
                        {pendingRows.length} pending
                      </span>
                    ) : null
                  }
                  flush
                >
                  {pendingRows.length ? (
                    <div className="table-wrap">
                      <table className="data">
                        <tbody>
                          {pendingRows.slice(0, 5).map((row) => (
                            <tr
                              key={row.record_id || row.user_id}
                              className="clickable"
                              onClick={() => navigate('/verification/' + row.record_id)}
                            >
                              <td style={{ width: '46%' }}>
                                <div className="primary">{row.name || 'Unnamed account'}</div>
                                <div className="sub">
                                  {row.business_name || label(row.role)}
                                  {row.location ? ' · ' + row.location : ''}
                                </div>
                              </td>
                              <td>
                                <Pill status={row.role} tone="role">
                                  {label(row.role)}
                                </Pill>
                              </td>
                              <td className="muted nowrap">{relative(row.submitted_at)}</td>
                              <td className="cell-actions">
                                <span className="muted">
                                  <Icon name="chevron" size={14} />
                                </span>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  ) : (
                    <Empty
                      icon="check"
                      title="Queue is clear"
                      text="No verification submission is waiting for a decision right now."
                    />
                  )}
                </Card>

                <Card
                  title="Recent activity"
                  sub="Administrator decisions and submissions"
                  actions={
                    <Button variant="ghost" size="sm" onClick={() => navigate('/activity')}>
                      Full trail <Icon name="chevron" size={13} />
                    </Button>
                  }
                >
                  {activity.length ? (
                    <div className="timeline">
                      {activity.map((event, index) => (
                        <div className="event" key={event.at + index}>
                          <span
                            className="event-dot"
                            style={{
                              background:
                                toneFor(event.action.replace('verification_', '')) === 'danger'
                                  ? 'var(--red)'
                                  : undefined,
                            }}
                          />
                          <div className="event-body">
                            <div className="event-title">{event.summary || label(event.action)}</div>
                            <div className="event-meta">
                              {label(event.actor)} · {dateTime(event.at)}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <Empty
                      icon="activity"
                      title="No recorded activity"
                      text="Reviewer decisions and verification submissions will appear here."
                    />
                  )}
                </Card>

                <Card
                  title="Buyer demand"
                  sub="Requirements posted from the marketplace"
                  actions={
                    <Button variant="ghost" size="sm" onClick={() => navigate('/requirements')}>
                      Open list <Icon name="chevron" size={13} />
                    </Button>
                  }
                >
                  <div className="stack" style={{ gap: 12 }}>
                    <StatCard
                      icon="search"
                      tone="blue"
                      label="Open requirements"
                      value={requirements.open}
                      foot={`${requirements.total} posted in total`}
                    />
                    <div className="muted" style={{ fontSize: 12 }}>
                      A requirement records what a buyer needs. It is not an order, it creates no
                      commitment, and it is not an action the console has to take.
                    </div>
                  </div>
                </Card>
              </div>

              <div className="banner">
                <span className="banner-icon">
                  <Icon name="sparkle" size={16} />
                </span>
                <div>
                  <strong>What this console does not do.</strong> It does not move money, book carriers, hold
                  escrow or publish products. Payments and logistics are status records in the demo
                  workspace, and moderation decisions never republish a listing on their own — the artisan
                  reviews and publishes.
                </div>
              </div>
            </div>
          )
        }}
      </Async>
    </>
  )
}
