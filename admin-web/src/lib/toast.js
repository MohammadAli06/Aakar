import { createContext, useContext } from 'react'

export const ToastContext = createContext(() => {})

/** `notify(message, 'success' | 'error' | 'info')` */
export function useToast() {
  return useContext(ToastContext)
}
