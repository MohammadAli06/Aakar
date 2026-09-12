import { useEffect, useState } from 'react'

/* A deliberately tiny hash router. The console is a handful of views and does
   not need a routing dependency: deep links, back/forward and refresh all work
   through the URL hash. */

export function currentPath() {
  return window.location.hash.replace(/^#/, '') || '/'
}

export function navigate(to) {
  const next = to.startsWith('#') ? to.slice(1) : to
  if (currentPath() === next) return
  window.location.hash = '#' + next
}

export function useRoute() {
  const [path, setPath] = useState(currentPath)

  useEffect(() => {
    const onChange = () => {
      setPath(currentPath())
      window.scrollTo({ top: 0, behavior: 'auto' })
    }
    window.addEventListener('hashchange', onChange)
    return () => window.removeEventListener('hashchange', onChange)
  }, [])

  const segments = path.split('/').filter(Boolean)
  return { path, section: segments[0] || 'dashboard', id: segments[1] || null }
}
