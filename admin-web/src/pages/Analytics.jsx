import { api } from '../lib/api.js'
import { useAsync } from '../lib/useAsync.js'
import { percent } from '../lib/format.js'
import { Async, Banner, Bar, Card, Donut, Legend, PageHead, StatCard } from '../components/Ui.jsx'
import { Icon } from '../components/Icons.jsx'

const VERIFICATION_ORDER = [
  ['pending', 'Pending', 'warning'],
  ['verified', 'Verified', 'success'],
  ['needs_correction', 'Needs correction', 'info'],
  ['rejected', 'Rejected', 'danger'],
  ['not_started', 'Not started', 'neutral'],
]

const PRODUCT_ORDER = [
  ['published', 'Published', 'success'],
  ['verified', 'Verified', 'info'],
  ['ai_generated', 'AI generated', 'warning'],
  ['draft', 'Draft', 'neutral'],
]

export function Analytics({ reloadKey }) {
  const state = useAsync(() => api('/admin/overview'), [reloadKey])

  return (
    <>
      <PageHead
        title="Analytics"
        desc="A current snapshot of the shared database. No time-series history is stored, so these are counts, not trends."
      />

      <Async state={state} label="Calculating…">
        {(overview) => {
          const { accounts, verifications, products } = overview
          const tracked =
            verifications.pending +
            verifications.verified +
            verifications.needs_correction +
            verifications.rejected +
            verifications.not_started

          return (
            <div className="stack">
              <div className="grid grid-4">
                <StatCard
                  icon="shield"
                  label="Verification completion"
                  value={percent(verifications.verified, tracked) + '%'}
                  foot={`${verifications.verified} of ${tracked} accounts`}
                />
                <StatCard
                  icon="users"
                  tone="blue"
                  label="Artisan share"
                  value={percent(accounts.artisan, accounts.total) + '%'}
                  foot={`${accounts.artisan} of ${accounts.total} accounts`}
                />
                <StatCard
                  icon="package"
                  tone="blue"
                  label="Published products"
                  value={percent(products.by_status.published, products.total) + '%'}
                  foot={`${products.by_status.published} of ${products.total} products`}
                />
                <StatCard
                  icon="flag"
                  tone="red"
                  label="Flagged listings"
                  value={products.flagged}
                  foot={products.flagged ? 'requires artisan attention' : 'nothing outstanding'}
                />
              </div>

              <div className="grid grid-2">
                <Card title="Verification funnel" sub={`${tracked} registrations tracked`}>
                  <div className="bars">
                    {VERIFICATION_ORDER.map(([key, text, tone]) => (
                      <Bar key={key} label={text} value={verifications[key] || 0} total={tracked} tone={tone} />
                    ))}
                  </div>
                </Card>

                <Card title="Product lifecycle" sub={`${products.total} catalogue records`}>
                  <div className="bars">
                    {PRODUCT_ORDER.map(([key, text, tone]) => (
                      <Bar
                        key={key}
                        label={text}
                        value={products.by_status[key] || 0}
                        total={products.total}
                        tone={tone}
                      />
                    ))}
                  </div>
                </Card>
              </div>

              <div className="grid grid-2">
                <Card title="Accounts" sub="Registered identities, by role and state">
                  <div className="donut-wrap">
                    <Donut
                      center={String(accounts.total)}
                      segments={[
                        { label: 'Artisan', value: accounts.artisan, color: '#2f7550' },
                        { label: 'Buyer', value: accounts.buyer, color: '#35637f' },
                      ]}
                    />
                    <Legend
                      segments={[
                        { label: 'Artisan', value: accounts.artisan, color: '#2f7550' },
                        { label: 'Buyer', value: accounts.buyer, color: '#35637f' },
                        { label: 'Disabled', value: accounts.disabled, color: '#9d4230' },
                      ]}
                    />
                  </div>
                </Card>

                <Card title="Reading this page" sub="What the numbers do and do not cover">
                  <div className="stack" style={{ gap: 12 }}>
                    <Banner icon="chart">
                      Counts are read live from the shared PostgreSQL/SQLite database used by the mobile app
                      and this console.
                    </Banner>
                    <Banner tone="warning" icon="alert">
                      Commerce figures — orders, settlement and fulfillment — are not part of this console.
                      They live in the shared demo workspace and are simulated status records, so they are
                      deliberately excluded from these totals.
                    </Banner>
                    <div className="muted" style={{ fontSize: 12.5 }}>
                      <Icon name="clock" size={13} /> Snapshot generated {overview.generated_at?.slice(0, 19).replace('T', ' ')} UTC
                    </div>
                  </div>
                </Card>
              </div>
            </div>
          )
        }}
      </Async>
    </>
  )
}
