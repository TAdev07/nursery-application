import { UserRole, UserType } from '@/types/auth'

// App configuration
export const APP_CONFIG = {
  name: 'Nursery Management System',
  description: 'Modern nursery management for B2B and B2C customers',
  version: '1.0.0',
  author: 'Nursery Team',
  keywords: ['nursery', 'plants', 'b2b', 'e-commerce', 'garden'],
  url: process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000',
} as const

// API routes
export const API_ROUTES = {
  auth: '/api/auth',
  users: '/api/users',
  products: '/api/products',
  categories: '/api/categories',
  orders: '/api/orders',
  inventory: '/api/inventory',
  upload: '/api/upload',
} as const

// App routes
export const ROUTES = {
  home: '/',

  // Auth routes
  login: '/auth/login',
  register: '/auth/register',
  forgotPassword: '/auth/forgot-password',
  resetPassword: '/auth/reset-password',

  // Dashboard routes
  dashboard: '/dashboard',

  // Product routes
  products: '/products',
  productDetail: (slug: string) => `/products/${slug}`,
  categories: '/categories',

  // Order routes
  cart: '/cart',
  checkout: '/checkout',
  orders: '/orders',
  orderDetail: (id: string) => `/orders/${id}`,

  // Account routes
  profile: '/account/profile',
  company: '/account/company',
  settings: '/account/settings',

  // Admin routes
  admin: '/admin',
  adminUsers: '/admin/users',
  adminProducts: '/admin/products',
  adminOrders: '/admin/orders',
  adminInventory: '/admin/inventory',
  adminSettings: '/admin/settings',
} as const

// User role permissions
export const ROLE_PERMISSIONS = {
  [UserRole.SUPER_ADMIN]: {
    canManageUsers: true,
    canManageProducts: true,
    canManageOrders: true,
    canManageInventory: true,
    canManageSettings: true,
    canViewReports: true,
    canManageFinances: true,
  },
  [UserRole.NURSERY_MANAGER]: {
    canManageUsers: false,
    canManageProducts: true,
    canManageOrders: true,
    canManageInventory: true,
    canManageSettings: false,
    canViewReports: true,
    canManageFinances: false,
  },
  [UserRole.SALES_STAFF]: {
    canManageUsers: false,
    canManageProducts: false,
    canManageOrders: true,
    canManageInventory: false,
    canManageSettings: false,
    canViewReports: true,
    canManageFinances: false,
  },
  [UserRole.NURSERY_WORKER]: {
    canManageUsers: false,
    canManageProducts: false,
    canManageOrders: false,
    canManageInventory: true,
    canManageSettings: false,
    canViewReports: false,
    canManageFinances: false,
  },
  [UserRole.WHOLESALE_CUSTOMER]: {
    canManageUsers: false,
    canManageProducts: false,
    canManageOrders: false,
    canManageInventory: false,
    canManageSettings: false,
    canViewReports: false,
    canManageFinances: false,
  },
  [UserRole.RETAIL_CUSTOMER]: {
    canManageUsers: false,
    canManageProducts: false,
    canManageOrders: false,
    canManageInventory: false,
    canManageSettings: false,
    canViewReports: false,
    canManageFinances: false,
  },
  [UserRole.CONTENT_EDITOR]: {
    canManageUsers: false,
    canManageProducts: true,
    canManageOrders: false,
    canManageInventory: false,
    canManageSettings: false,
    canViewReports: false,
    canManageFinances: false,
  },
} as const

// Default values
export const DEFAULT_VALUES = {
  pagination: {
    page: 1,
    limit: 10,
    maxLimit: 100,
  },
  userType: UserType.B2C,
  userRole: UserRole.RETAIL_CUSTOMER,
  currency: 'VND',
  locale: 'vi-VN',
} as const

// Validation constants
export const VALIDATION = {
  password: {
    minLength: 8,
    maxLength: 128,
  },
  email: {
    maxLength: 320,
  },
  name: {
    minLength: 2,
    maxLength: 100,
  },
  phone: {
    pattern: /^(\+84|84|0)[3|5|7|8|9][0-9]{8}$/,
  },
  slug: {
    pattern: /^[a-z0-9]+(?:-[a-z0-9]+)*$/,
  },
  sku: {
    pattern: /^[A-Z0-9]{3,20}$/,
  },
} as const

// File upload limits
export const UPLOAD_LIMITS = {
  image: {
    maxSize: 5 * 1024 * 1024, // 5MB
    allowedTypes: ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'],
  },
  document: {
    maxSize: 10 * 1024 * 1024, // 10MB
    allowedTypes: ['application/pdf', 'application/msword', 'text/plain'],
  },
} as const

// Plant-specific constants
export const PLANT_CONSTANTS = {
  hardinessZones: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
  sunRequirements: ['full_sun', 'partial_sun', 'partial_shade', 'full_shade'],
  waterNeeds: ['low', 'medium', 'high'],
  growthRates: ['slow', 'medium', 'fast'],
  plantTypes: ['tree', 'shrub', 'perennial', 'annual', 'houseplant'],
  containerTypes: [
    'plastic_pot',
    'terracotta_pot',
    'fabric_bag',
    'biodegradable_pot',
  ],
  sizeCategories: [
    'seedling',
    '4_inch',
    '6_inch',
    '1_gallon',
    '2_gallon',
    '5_gallon',
    '10_gallon',
    '15_gallon',
  ],
} as const
