import React from 'react'
import './App.css'

function App() {
  return (
    <div style={{
      fontFamily: 'system-ui, sans-serif',
      minHeight: '100vh',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      background: '#f8f7f2',
      color: '#233c32',
      padding: '24px',
      textAlign: 'center'
    }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '32px', margin: '0 0 8px 0', fontFamily: 'Georgia, serif' }}>
          ✦ Aakar Admin Dashboard
        </h1>
        <p style={{ color: '#7c8275', margin: 0, fontSize: '15px' }}>
          Real craft. Responsible connections.
        </p>
      </header>

      <div style={{
        background: '#ffffff',
        border: '1px solid #e3e6dc',
        borderRadius: '16px',
        padding: '32px',
        maxWidth: '480px',
        width: '100%',
        boxShadow: '0 4px 12px rgba(0,0,0,0.03)'
      }}>
        <span style={{
          display: 'inline-block',
          fontSize: '12px',
          fontWeight: 600,
          padding: '4px 12px',
          borderRadius: '12px',
          background: '#e8f0e5',
          color: '#356147',
          marginBottom: '16px'
        }}>
          ADMIN PORTAL · UNDER SETUP
        </span>
        <h2 style={{ fontSize: '20px', margin: '0 0 12px 0' }}>Verification & Moderation Workspace</h2>
        <p style={{ color: '#59624f', fontSize: '14px', lineHeight: 1.6, margin: '0 0 20px 0' }}>
          This React portal will connect to the FastAPI backend at <code>/api/v1/workspace</code> for artisan verification, product moderation, and order issue reviews.
        </p>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '13px', textAlign: 'left', background: '#f6f6ef', padding: '14px', borderRadius: '8px' }}>
          <div><strong>Backend API:</strong> <code>http://localhost:8000/api/v1</code></div>
          <div><strong>Role:</strong> Administrator</div>
          <div><strong>Status:</strong> Ready for development</div>
        </div>
      </div>
    </div>
  )
}

export default App

