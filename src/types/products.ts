// Plant-specific types
export enum PlantType {
  TREE = 'tree',
  SHRUB = 'shrub',
  PERENNIAL = 'perennial',
  ANNUAL = 'annual',
  HOUSEPLANT = 'houseplant',
}

export enum GrowthRate {
  SLOW = 'slow',
  MEDIUM = 'medium',
  FAST = 'fast',
}

export enum WaterNeeds {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
}

export enum SunRequirements {
  FULL_SUN = 'full_sun',
  PARTIAL_SUN = 'partial_sun',
  PARTIAL_SHADE = 'partial_shade',
  FULL_SHADE = 'full_shade',
}

// Product-related interfaces
export interface Category {
  id: string
  name: string
  slug: string
  description?: string
  parentId?: string
  imageUrl?: string
  isActive: boolean
  sortOrder: number
  createdAt: string
}

export interface Product {
  id: string
  sku: string
  name: string
  slug: string
  description?: string
  categoryId: string

  // Plant-specific attributes
  botanicalName?: string
  plantType: PlantType
  matureHeightMax?: number // cm
  growthRate: GrowthRate
  sunRequirements: SunRequirements[]
  waterNeeds: WaterNeeds
  hardinessZones: number[]
  careInstructions?: string

  // Pricing
  basePrice: number
  wholesalePrice?: number

  // Status
  isActive: boolean
  isFeatured: boolean
  createdAt: string
}

export interface ProductVariant {
  id: string
  productId: string
  variantName: string
  sku: string
  sizeCategory?: string
  containerType?: string
  containerSize?: string
  priceAdjustment: number
  isActive: boolean
}

export interface ProductImage {
  id: string
  productId: string
  imageUrl: string
  altText?: string
  displayOrder: number
  isPrimary: boolean
  createdAt: string
}

// Catalog view types
export interface ProductWithDetails extends Product {
  category: Category
  variants: ProductVariant[]
  images: ProductImage[]
  totalStock: number
  inStock: boolean
}
