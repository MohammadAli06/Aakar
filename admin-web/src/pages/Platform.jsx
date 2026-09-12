import { api } from '../lib/api.js'
import { useAsync } from '../lib/useAsync.js'
import { Async, Banner, Card, KV, PageHead, Pill } from '../components/Ui.jsx'
import { Icon } from '../components/Icons.jsx'

export function Platform({ reloadKey }) {
  const state = useAsync(() => api('/admin/platform'), [reloadKey])

  return (
    <>
      <PageHead
        title="Platform"
        desc="Read-only facts about the backend this console is connected to. Configuration itself lives in the backend environment, not in this browser."
      />

      <Async state={state} label="Reading platform information…">
        {(platform) => (
          <div className="grid grid-2">
            <Card title="Connection" sub="Values reported by the running backend">
              <KV
                items={[
                  ['Service', platform.app_name],
                  ['Environment', <Pill key="env" tone={platform.environment === 'production' ? 'danger' : 'info'} dot={false}>{platform.environment}</Pill>],
                  ['Database', platform.database === 'postgresql' ? 'PostgreSQL' : 'SQLite (local demo)'],
                  ['Schema', platform.migrations],
                  [
                    'Demo workspace',
                    platform.demo_workspace_enabled ? (
                      <Pill key="w" tone="warning">
                        Enabled
                      </Pill>
                    ) : (
                      <Pill key="w" tone="neutral" dot={false}>
                        Disabled
                      </Pill>
                    ),
                  ],
                  [
                    'Assistant credentials',
                    platform.assistant_configured ? (
                      <Pill key="a" tone="success">
                        Configured
                      </Pill>
                    ) : (
                      <Pill key="a" tone="neutral" dot={false}>
                        Not configured
                      </Pill>
                    ),
                  ],
                ]}
              />
            </Card>

            <Card title="Configured elsewhere" sub="Backend environment variables">
              <div className="stack" style={{ gap: 12 }}>
                <Banner icon="settings">
                  These settings are read from the backend environment when it starts. Changing them here would
                  require a server restart, so this console deliberately exposes them as read-only.
                </Banner>
                <KV
                  items={[
                    ['Admin access', 'ADMIN_ACCESS_TOKEN'],
                    ['Database', 'DATABASE_URL'],
                    ['Firebase', 'FIREBASE_CREDENTIALS_PATH, FIREBASE_PROJECT_ID'],
                    ['Assistant', 'LLM_API_KEY, LLM_API_BASE, LLM_MODEL'],
                    ['Demo workspace', 'ENABLE_DEMO_WORKSPACE, WORKSPACE_DEMO_TOKEN'],
                  ]}
                />
                <div className="muted" style={{ fontSize: 12.5 }}>
                  <Icon name="lock" size={13} /> Secret values are never returned by this endpoint.
                </div>
              </div>
            </Card>
          </div>
        )}
      </Async>
    </>
  )
}
