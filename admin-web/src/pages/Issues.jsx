import { useState } from 'react'
import { api } from '../lib/api.js'
import { useAsync } from '../lib/useAsync.js'
import { useToast } from '../lib/toast.js'
import { label, rupees } from '../lib/format.js'
import {
  Async,
  Banner,
  Button,
  Card,
  Empty,
  Field,
  KV,
  Modal,
  PageHead,
  Pill,
} from '../components/Ui.jsx'

async function loadWorkspace() {
  try {
    return { available: true, snapshot: await api('/workspace') }
  } catch (error) {
    if (error.status === 404 || error.status === 401) {
      return { available: false, status: error.status, snapshot: null }
    }
    throw error
  }
}

export function Issues({ reloadKey }) {
  const state = useAsync(loadWorkspace, [reloadKey])
  const notify = useToast()
  const [target, setTarget] = useState(null)
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)

  async function act(outcome) {
    if (!note.trim()) {
      notify('Add a manual investigation note or agreed outcome first.', 'error')
      return
    }
    setBusy(true)
    try {
      await api('/workspace/actions', {
        method: 'POST',
        body: {
          action: target.action,
          input: { id: target.id, status: outcome, note: note.trim() },
          role: 'admin',
          actor: 'admin',
          version: target.version,
        },
      })
      notify('Review recorded in the shared workspace.', 'success')
      setTarget(null)
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
        title="Order issues"
        desc="Manual review of participant-reported problems, with the order terms and fulfillment context attached."
      />

      <Async state={state} label="Reaching the shared workspace…">
        {({ available, snapshot }) => {
          if (!available) {
            return (
              <Card>
                <Empty
                  icon="alert"
                  title="The shared workspace is not enabled"
                  text="Order issues live in the opt-in shared demo workspace. Start the backend with ENABLE_DEMO_WORKSPACE=true (run_demo.ps1 does this) to review them here. A production order-issue store is not yet part of the backend."
                />
              </Card>
            )
          }

          const issues = snapshot.issues || []
          const orders = snapshot.orders || []
          const ordersById = new Map(orders.map((order) => [order.id, order]))
          const openCount = issues.filter((issue) => issue.status !== 'resolved').length
          const checkpoints = orders.filter(
            (order) => order.checkpoint_required && order.checkpoint === 'submitted',
          )

          return (
            <div className="stack">
              <Banner tone="warning" icon="alert">
                <strong>Shared demo workspace.</strong> Payments here are status records — no money is held
                or transferred, no carrier is booked and no hub is confirmed. Resolutions are manual notes,
                not automated adjudication or refunds.
              </Banner>

              <Card
                title="Issue queue"
                sub={`${issues.length} reported · ${openCount} unresolved`}
                actions={
                  <Pill tone={openCount ? 'warning' : 'success'}>{openCount ? 'Open items' : 'All resolved'}</Pill>
                }
                flush
              >
                {issues.length ? (
                  <div className="table-wrap">
                    <table className="data">
                      <thead>
                        <tr>
                          <th>Issue</th>
                          <th>Order</th>
                          <th>Reported by</th>
                          <th>Status</th>
                          <th>Outcome</th>
                          <th className="cell-actions">Review</th>
                        </tr>
                      </thead>
                      <tbody>
                        {issues.map((issue) => (
                          <tr key={issue.id}>
                            <td style={{ maxWidth: 320 }}>
                              <div className="primary">{label(issue.category)}</div>
                              <div className="sub">{issue.description}</div>
                            </td>
                            <td>
                              <div>{ordersById.get(issue.order_id)?.product_title || issue.order_id}</div>
                              <div className="sub">{issue.order_id}</div>
                            </td>
                            <td className="muted">{label(issue.reporter)}</td>
                            <td>
                              <Pill status={issue.status} />
                            </td>
                            <td className="muted" style={{ maxWidth: 220 }}>
                              {issue.resolution || '—'}
                            </td>
                            <td className="cell-actions">
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => {
                                  setNote('')
                                  setTarget({ action: 'resolve', id: issue.id, version: snapshot.version, issue })
                                }}
                              >
                                Open
                              </Button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <Empty
                    icon="check"
                    title="No issues reported"
                    text="Participant-reported problems from the shared workspace appear here for manual review."
                  />
                )}
              </Card>

              <Card
                title="Production checkpoints"
                sub="Optional progress reviews submitted by an artisan"
                flush
              >
                {checkpoints.length ? (
                  <div className="table-wrap">
                    <table className="data">
                      <thead>
                        <tr>
                          <th>Order</th>
                          <th>Progress</th>
                          <th>Evidence</th>
                          <th className="cell-actions">Review</th>
                        </tr>
                      </thead>
                      <tbody>
                        {checkpoints.map((order) => (
                          <tr key={order.id}>
                            <td>
                              <div className="primary">{order.product_title}</div>
                              <div className="sub">{order.id}</div>
                            </td>
                            <td className="nowrap">
                              {order.checkpoint_quantity} / {order.quantity}
                            </td>
                            <td className="muted">{order.checkpoint_evidence ? 'Photo attached' : 'None'}</td>
                            <td className="cell-actions">
                              <Button
                                variant="ghost"
                                size="sm"
                                onClick={() => {
                                  setNote('')
                                  setTarget({
                                    action: 'checkpoint',
                                    id: order.id,
                                    version: snapshot.version,
                                    order,
                                  })
                                }}
                              >
                                Open
                              </Button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <Empty
                    icon="package"
                    title="No checkpoint is waiting"
                    text="A progress checkpoint is optional per order. Reviews here are separate from payment confirmation and cannot guarantee quality."
                  />
                )}
              </Card>

              <Modal
                open={Boolean(target)}
                wide
                title={target?.action === 'checkpoint' ? 'Production checkpoint review' : 'Order issue review'}
                sub={
                  target?.action === 'checkpoint'
                    ? 'Approve the progress report or ask for changes'
                    : 'Record the manual investigation and agreed outcome'
                }
                onClose={() => setTarget(null)}
                footer={
                  target?.action === 'checkpoint' ? (
                    <>
                      <Button variant="ghost" onClick={() => setTarget(null)}>
                        Cancel
                      </Button>
                      <Button variant="ghost" disabled={busy} onClick={() => act('changes_requested')}>
                        Request changes
                      </Button>
                      <Button disabled={busy} onClick={() => act('approved')}>
                        Approve review
                      </Button>
                    </>
                  ) : (
                    <>
                      <Button variant="ghost" onClick={() => setTarget(null)}>
                        Cancel
                      </Button>
                      <Button variant="ghost" disabled={busy} onClick={() => act('under_review')}>
                        Mark under review
                      </Button>
                      <Button disabled={busy} onClick={() => act('resolved')}>
                        Record resolution
                      </Button>
                    </>
                  )
                }
              >
                {target?.action === 'checkpoint' ? (
                  <KV
                    items={[
                      ['Order', target.order?.product_title],
                      ['Reference', target.id],
                      ['Completed', `${target.order?.checkpoint_quantity} / ${target.order?.quantity}`],
                      ['Specifications', target.order?.specifications],
                    ]}
                  />
                ) : (
                  <div className="stack" style={{ gap: 16 }}>
                    <KV
                      items={[
                        ['Category', label(target?.issue?.category)],
                        ['Reported by', label(target?.issue?.reporter)],
                        ['Status', <Pill key="s" status={target?.issue?.status} />],
                        ['Description', target?.issue?.description],
                        ['Evidence', target?.issue?.evidence || 'None attached'],
                        [
                          'Order total',
                          rupees(ordersById.get(target?.issue?.order_id)?.total),
                        ],
                        [
                          'Production',
                          label(ordersById.get(target?.issue?.order_id)?.production),
                        ],
                        ['Shipment', label(ordersById.get(target?.issue?.order_id)?.shipment)],
                        ['Inspection', label(ordersById.get(target?.issue?.order_id)?.inspection)],
                      ]}
                    />
                    <details>
                      <summary className="muted" style={{ cursor: 'pointer', fontSize: 12.5 }}>
                        Full order and terms record
                      </summary>
                      <pre
                        className="mono"
                        style={{
                          background: '#f7f6f1',
                          padding: 14,
                          borderRadius: 10,
                          maxHeight: 260,
                          overflow: 'auto',
                          whiteSpace: 'pre-wrap',
                        }}
                      >
                        {JSON.stringify(ordersById.get(target?.issue?.order_id) || {}, null, 2)}
                      </pre>
                    </details>
                  </div>
                )}

                <div className="mt-16" />

                <Field
                  label="Reviewer note"
                  hint="Required. Include what was checked and the outcome agreed with the participants."
                >
                  <textarea
                    className="textarea"
                    value={note}
                    maxLength={2000}
                    onChange={(event) => setNote(event.target.value)}
                  />
                </Field>
              </Modal>

              <Card title="Recent orders" sub="Shared context for the queue above" flush>
                {orders.length ? (
                  <div className="table-wrap">
                    <table className="data">
                      <thead>
                        <tr>
                          <th>Order</th>
                          <th>Quantity</th>
                          <th>Total</th>
                          <th>Production</th>
                          <th>Shipment</th>
                          <th>Inspection</th>
                          <th>Status</th>
                        </tr>
                      </thead>
                      <tbody>
                        {orders.slice(0, 8).map((order) => (
                          <tr key={order.id}>
                            <td>
                              <div className="primary">{order.product_title}</div>
                              <div className="sub">{order.id}</div>
                            </td>
                            <td>{order.quantity}</td>
                            <td className="nowrap">{rupees(order.total)}</td>
                            <td>
                              <Pill status={order.production} />
                            </td>
                            <td>
                              <Pill status={order.shipment} />
                            </td>
                            <td>
                              <Pill status={order.inspection} />
                            </td>
                            <td>
                              <Pill status={order.status} />
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <Empty icon="store" title="No orders in the workspace" />
                )}
              </Card>
            </div>
          )
        }}
      </Async>
    </>
  )
}
