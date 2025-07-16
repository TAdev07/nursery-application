import { createBrowserClient, createServerClient } from '@supabase/ssr'

import { NextRequest, NextResponse } from 'next/server'
import { Database } from '@/types/database'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables')
}

// Client-side Supabase client
export function createClient() {
  return createBrowserClient<Database>(supabaseUrl, supabaseAnonKey)
}

// Server-side Supabase client for Server Components
export function createServerSupabaseClient() {
  return createServerClient<Database>(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return []
      },
      setAll(_cookiesToSet) {
        // No-op for server components
      },
    },
  })
}

// Server-side Supabase client for API routes
export function createServerSupabaseClientForAPI(request: NextRequest) {
  return createServerClient<Database>(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        const cookies = request.cookies.getAll()
        return cookies.map(cookie => ({
          name: cookie.name,
          value: cookie.value,
        }))
      },
      setAll(_cookiesToSet) {
        // Cookies will be set in the response
      },
    },
  })
}

// Server-side Supabase client for middleware
export function createServerSupabaseClientForMiddleware(
  request: NextRequest,
  response: NextResponse
) {
  return createServerClient<Database>(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        const cookies = request.cookies.getAll()
        return cookies.map(cookie => ({
          name: cookie.name,
          value: cookie.value,
        }))
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value, options }) => {
          response.cookies.set(name, value, options)
        })
      },
    },
  })
}