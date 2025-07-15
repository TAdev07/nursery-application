// User roles enum
export enum UserRole {
  SUPER_ADMIN = 'super_admin',
  NURSERY_MANAGER = 'nursery_manager',
  SALES_STAFF = 'sales_staff',
  NURSERY_WORKER = 'nursery_worker',
  WHOLESALE_CUSTOMER = 'wholesale_customer',
  RETAIL_CUSTOMER = 'retail_customer',
  CONTENT_EDITOR = 'content_editor',
}

// User types
export enum UserType {
  B2C = 'B2C',
  B2B = 'B2B',
  ADMIN = 'ADMIN',
  STAFF = 'STAFF',
}

// Auth-related types
export interface UserProfile {
  id: string
  email: string
  firstName?: string
  lastName?: string
  phone?: string
  avatarUrl?: string
  userType: UserType
  role: UserRole
  status: 'active' | 'inactive' | 'pending'
  createdAt: string
  updatedAt: string
}

export interface CompanyProfile {
  id: string
  userId: string
  companyName: string
  businessRegistration?: string
  taxNumber?: string
  creditLimit: number
  paymentTerms: number
  discountTier: string
  approvalStatus: 'pending' | 'approved' | 'rejected'
  createdAt: string
}

export interface AuthState {
  user: UserProfile | null
  company?: CompanyProfile | null
  isLoading: boolean
  isAuthenticated: boolean
}

export interface LoginCredentials {
  email: string
  password: string
}

export interface RegisterData {
  email: string
  password: string
  firstName: string
  lastName: string
  userType: UserType
  companyName?: string
}
