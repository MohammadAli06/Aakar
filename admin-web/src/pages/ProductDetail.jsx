import { useState } from 'react'
import { api } from '../lib/api.js'
import { useAsync } from '../lib/useAsync.js'
import { useToast } from '../lib/toast.js'
import { navigate } from '../lib/router.jsx'
import { dateTime, label, rupees } from '../lib/format.js'
import {
  Async,
  Banner,
  Button,
  Card,
  Empty,
  Field,
  KV,
  PageHead,
  Pill,
  Select,
  SectionLabel,
} from '../components/Ui.jsx'

const MODERATION = [
  { value: 'clear', label: 'Clear — no concern recorded' },
  { value: 'flagged', label: 'Flag — needs the artisan’s attention' },
  { value: 'blocked', label: 'Block — must not be published' },
]

export function ProductDetail({ productId, reloadKey }) {
  const state = useAsync(() => api('/admin/products/' + productId), [reloadKey])
  const notify = useToast()
  const [status, setStatus] = useState(null)
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)

  async function save() {
    if (!note.trim()) {
      notify('Add a short reason before recording the decision.', 'error')
      return
    }
    setBusy(true)
    try {
      await api(`/admin/products/${productId}/moderation`, {
        method: 'PUT',
        body: { status: status || 'clear', note: note.trim() },
      })
      notify('Moderation decision recorded.', 'success')
      setNote('')
      state.reload()
    } catch (error) {
      notify(error.message, 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <PageHead
        title="Product review"
        desc="Listing content, labour-aware pricing and the moderation record for one product."
        actions={
          <Button variant="ghost" size="sm" onClick={() => navigate('/products')}>
            Back to products
          </Button>
        }
      />

      <Async state={state} label="Loading product…">
        {(product) => {
          const pricing = product.pricing
          const floor = pricing ? pricing.material_cost + pricing.labour_cost + pricing.overhead : 0
          const attributes = Object.entries(product.listing?.attributes || {})
          const currentModeration = status ?? product.moderation

          return (
            <div className="stack">
              <div className="row-wrap">
                <h2 style={{ fontSize: 18 }}>{product.listing?.title_en || 'Untitled product'}</h2>
                <Pill status={product.status} />
                {product.moderation !== 'clear' ? <Pill status={product.moderation} /> : null}
              </div>

              <div className="grid grid-1-2">
                <div className="stack">
                  <Card title="Product record">
                    <KV
                      items={[
                        ['Category', label(product.category)],
                        ['Internal state', <Pill key="s" status={product.status} />],
                        ['Created', dateTime(product.created_at)],
                        ['Artisan', product.artisan_name || '—'],
                        [
                          'Artisan verified',
                          product.artisan_verified ? (
                            <Pill key="v" tone="success">
                              Verified
                            </Pill>
                          ) : (
                            <Pill key="v" tone="neutral">
                              Not verified
                            </Pill>
                          ),
                        ],
                        ['Location', product.location],
                        [
                          'Listing approved',
                          product.listing ? (
                            <Pill key="l" status={product.listing.verification_status} />
                          ) : (
                            '—'
                          ),
                        ],
                      ]}
                    />
                    <div className="mt-16">
                      <Banner icon="package">
                        Publication is the artisan’s action. A moderation decision here never publishes,
                        unpublishes or re-approves a listing by itself.
                      </Banner>
                    </div>
                  </Card>

                  <Card title="Moderation">
                    <Field label="Decision">
                      <Select value={currentModeration} onChange={setStatus} options={MODERATION} />
                    </Field>
                    <div style={{ marginTop: 14 }}>
                      <Field
                        label="Reason"
                        hint="Required. Stored with the decision and shown in the audit trail."
                      >
                        <textarea
                          className="textarea"
                          value={note}
                          maxLength={2000}
                          placeholder="Photo appears to be a machine-made replica rather than the artisan’s own work."
                          onChange={(event) => setNote(event.target.value)}
                        />
                      </Field>
                    </div>
                    {product.moderation_note ? (
                      <div className="mt-16">
                        <SectionLabel>Current moderation note</SectionLabel>
                        <p className="muted" style={{ fontSize: 12.5, margin: 0 }}>
                          {product.moderation_note}
                        </p>
                      </div>
                    ) : null}
                    <div className="row" style={{ marginTop: 16 }}>
                      <Button onClick={save} disabled={busy}>
                        {busy ? 'Saving…' : 'Record decision'}
                      </Button>
                      {status && status !== product.moderation ? (
                        <span className="muted" style={{ fontSize: 12 }}>
                          Changing from {label(product.moderation)} to {label(status)}
                        </span>
                      ) : null}
                    </div>
                  </Card>
                </div>

                <div className="stack">
                  <Card
                    title="Generated listing"
                    sub={
                      product.listing
                        ? 'AI output, pending or completed artisan review'
                        : 'The artisan has not generated a listing yet'
                    }
                  >
                    {product.listing ? (
                      <div className="stack" style={{ gap: 14 }}>
                        <div>
                          <SectionLabel>Title · English</SectionLabel>
                          <div>{product.listing.title_en}</div>
                        </div>
                        <div>
                          <SectionLabel>Title · Hindi</SectionLabel>
                          <div>{product.listing.title_hi}</div>
                        </div>
                        <div>
                          <SectionLabel>Description · English</SectionLabel>
                          <p style={{ margin: 0, fontSize: 13, lineHeight: 1.6 }}>{product.listing.desc_en}</p>
                        </div>
                        <div>
                          <SectionLabel>Description · Hindi</SectionLabel>
                          <p style={{ margin: 0, fontSize: 13, lineHeight: 1.6 }}>{product.listing.desc_hi}</p>
                        </div>
                        {product.listing.tags?.length ? (
                          <div>
                            <SectionLabel>Tags</SectionLabel>
                            <div className="row-wrap">
                              {product.listing.tags.map((tag) => (
                                <span className="chip" key={tag}>
                                  {tag}
                                </span>
                              ))}
                            </div>
                          </div>
                        ) : null}
                      </div>
                    ) : (
                      <Empty
                        icon="file"
                        title="No listing content"
                        text="Capture, transcription and listing generation happen in the mobile product studio."
                      />
                    )}
                  </Card>

                  <Card title="Pricing" sub="Material + labour + overhead form the cost floor">
                    {pricing ? (
                      <div className="stack" style={{ gap: 14 }}>
                        <KV
                          items={[
                            ['Material cost', rupees(pricing.material_cost)],
                            ['Labour cost', rupees(pricing.labour_cost)],
                            ['Overhead', rupees(pricing.overhead)],
                            [
                              'Cost floor',
                              <strong key="floor">{rupees(floor)}</strong>,
                            ],
                            [
                              'Recommended range',
                              `${rupees(pricing.recommended_min)} – ${rupees(pricing.recommended_max)}`,
                            ],
                            [
                              'Artisan final price',
                              pricing.final_price ? (
                                <strong key="final">{rupees(pricing.final_price)}</strong>
                              ) : (
                                'Not set'
                              ),
                            ],
                          ]}
                        />
                        {pricing.final_price && pricing.final_price < floor ? (
                          <Banner tone="danger" icon="alert">
                            The final price is below the recorded cost floor. The artisan sets the final price;
                            this console only surfaces the discrepancy.
                          </Banner>
                        ) : null}
                        <div>
                          <SectionLabel>Explanation</SectionLabel>
                          <p className="muted" style={{ fontSize: 12.5, margin: 0, lineHeight: 1.6 }}>
                            {pricing.explanation_en}
                          </p>
                        </div>
                      </div>
                    ) : (
                      <Empty
                        icon="chart"
                        title="No price recommendation"
                        text="Pricing is calculated in the mobile studio from the artisan’s own cost inputs."
                      />
                    )}
                  </Card>

                  {attributes.length ? (
                    <Card title="Extracted attributes" sub="Values and reviewer confidence">
                      <div className="table-wrap">
                        <table className="data">
                          <thead>
                            <tr>
                              <th>Attribute</th>
                              <th>Value</th>
                            </tr>
                          </thead>
                          <tbody>
                            {attributes.map(([key, value]) => (
                              <tr key={key}>
                                <td className="muted">{label(key)}</td>
                                <td>{typeof value === 'object' ? value?.value ?? '—' : String(value)}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </Card>
                  ) : null}
                </div>
              </div>
            </div>
          )
        }}
      </Async>

      {state.error ? (
        <Card className="mt-16">
          <Empty
            icon="search"
            title="Product not found"
            text="The record may have been removed, or this backend uses a different database."
            action={
              <Button variant="ghost" size="sm" onClick={() => navigate('/products')}>
                Back to products
              </Button>
            }
          />
        </Card>
      ) : null}
    </>
  )
}
