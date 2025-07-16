'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase'

export default function TestSupabasePage() {
  const [connectionStatus, setConnectionStatus] = useState<'testing' | 'success' | 'error'>('testing')
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    testConnection()
  }, [])

  const testConnection = async () => {
    try {
      const supabase = createClient()
      
      // Test basic connection
      const { data, error } = await supabase.auth.getSession()
      
      if (error) {
        throw error
      }

      // Test a simple query (this will work even without tables)
      const { data: healthCheck, error: healthError } = await supabase
        .from('profiles') // This table doesn't exist yet, but that's OK for testing connection
        .select('*')
        .limit(1)

      // If we get a "relation does not exist" error, that's actually good - it means we connected!
      if (healthError && healthError.message.includes('relation') && healthError.message.includes('does not exist')) {
        setConnectionStatus('success')
        setError('Connection successful! Database schema not yet created (expected).')
      } else if (healthError) {
        throw healthError
      } else {
        setConnectionStatus('success')
        setError(null)
      }
    } catch (err) {
      setConnectionStatus('error')
      setError(err instanceof Error ? err.message : 'Unknown error occurred')
    }
  }

  return (
    <div className="container mx-auto p-8">
      <h1 className="text-3xl font-bold mb-6">Supabase Connection Test</h1>
      
      <div className="bg-white p-6 rounded-lg shadow-md">
        <h2 className="text-xl font-semibold mb-4">Connection Status</h2>
        
        <div className="flex items-center mb-4">
          <div className={`w-4 h-4 rounded-full mr-3 ${
            connectionStatus === 'testing' ? 'bg-yellow-500' :
            connectionStatus === 'success' ? 'bg-green-500' : 'bg-red-500'
          }`}></div>
          <span className="font-medium">
            {connectionStatus === 'testing' && 'Testing connection...'}
            {connectionStatus === 'success' && 'Connected successfully'}
            {connectionStatus === 'error' && 'Connection failed'}
          </span>
        </div>

        {error && (
          <div className={`p-4 rounded-md ${
            connectionStatus === 'success' ? 'bg-green-50 text-green-800' : 'bg-red-50 text-red-800'
          }`}>
            <p className="text-sm">{error}</p>
          </div>
        )}

        <button
          onClick={testConnection}
          className="mt-4 px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
        >
          Test Again
        </button>
      </div>

      <div className="mt-8 bg-gray-50 p-6 rounded-lg">
        <h3 className="text-lg font-semibold mb-3">Environment Variables</h3>
        <div className="space-y-2 text-sm">
          <div>
            <span className="font-medium">NEXT_PUBLIC_SUPABASE_URL:</span>{' '}
            <span className={process.env.NEXT_PUBLIC_SUPABASE_URL ? 'text-green-600' : 'text-red-600'}>
              {process.env.NEXT_PUBLIC_SUPABASE_URL ? '✓ Set' : '✗ Missing'}
            </span>
          </div>
          <div>
            <span className="font-medium">NEXT_PUBLIC_SUPABASE_ANON_KEY:</span>{' '}
            <span className={process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ? 'text-green-600' : 'text-red-600'}>
              {process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ? '✓ Set' : '✗ Missing'}
            </span>
          </div>
        </div>
      </div>
    </div>
  )
}