import { useCallback, useState } from 'react'
import { Icon } from './Icons.jsx'
import { ToastContext } from '../lib/toast.js'

const ICONS = { success: 'check', error: 'alert', info: 'sparkle' }

export function ToastProvider({ children }) {
  const [items, setItems] = useState([])

  const notify = useCallback((message, tone = 'info') => {
    const id = Date.now() + Math.random().toString(36).slice(2)
    setItems((list) => [...list, { id, message: String(message), tone }])
    window.setTimeout(() => {
      setItems((list) => list.filter((item) => item.id !== id))
    }, 4600)
  }, [])

  return (
    <ToastContext.Provider value={notify}>
      {children}
      <div className="toasts" role="status" aria-live="polite">
        {items.map((item) => (
          <div key={item.id} className={'toast ' + item.tone}>
            <Icon name={ICONS[item.tone] || 'sparkle'} size={16} />
            <span>{item.message}</span>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  )
}
