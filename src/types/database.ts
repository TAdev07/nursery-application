// Database types will be generated from Supabase
// This is a placeholder until Supabase schema is ready

export interface Database {
  public: {
    Tables: {
      // Tables will be defined here after Supabase setup
      [key: string]: {
        Row: Record<string, unknown>
        Insert: Record<string, unknown>
        Update: Record<string, unknown>
      }
    }
    Views: {
      [key: string]: {
        Row: Record<string, unknown>
      }
    }
    Functions: {
      [key: string]: {
        Args: Record<string, unknown>
        Returns: unknown
      }
    }
    Enums: {
      [key: string]: string
    }
  }
}
