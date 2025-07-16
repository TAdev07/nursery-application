-- Migration: Create product catalog tables
-- Created: 2025-07-16
-- Description: Set up categories, products, product_variants, and product_images tables

-- =============================================================================
-- CATEGORIES TABLE - Hierarchical product categories
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.categories (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  parent_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  image_url TEXT,
  icon TEXT, -- For UI display (e.g., icon class names)
  
  -- Hierarchy and ordering
  depth INTEGER DEFAULT 0, -- Calculated depth in hierarchy
  path TEXT, -- Materialized path for efficient queries (e.g., "trees/fruit-trees/citrus")
  sort_order INTEGER DEFAULT 0,
  
  -- Status and metadata
  is_active BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  meta_title TEXT, -- SEO
  meta_description TEXT, -- SEO
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for categories
CREATE TRIGGER update_categories_updated_at
  BEFORE UPDATE ON public.categories
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Function to update category path and depth
CREATE OR REPLACE FUNCTION public.update_category_path()
RETURNS TRIGGER AS $$
DECLARE
  parent_path TEXT;
  parent_depth INTEGER;
BEGIN
  IF NEW.parent_id IS NULL THEN
    NEW.path = NEW.slug;
    NEW.depth = 0;
  ELSE
    SELECT path, depth INTO parent_path, parent_depth
    FROM public.categories
    WHERE id = NEW.parent_id;
    
    NEW.path = parent_path || '/' || NEW.slug;
    NEW.depth = parent_depth + 1;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_category_path_trigger
  BEFORE INSERT OR UPDATE ON public.categories
  FOR EACH ROW EXECUTE FUNCTION public.update_category_path();

-- =============================================================================
-- PRODUCTS TABLE - Main product information with plant-specific attributes
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  sku TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  short_description TEXT,
  category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,

  -- Plant-specific attributes
  botanical_name TEXT,
  common_names TEXT[], -- Alternative names
  plant_type TEXT CHECK (plant_type IN ('tree', 'shrub', 'perennial', 'annual', 'houseplant', 'herb', 'vegetable', 'fruit', 'succulent', 'fern', 'grass')),
  
  -- Physical characteristics
  mature_height_min INTEGER, -- cm
  mature_height_max INTEGER, -- cm
  mature_width_min INTEGER, -- cm
  mature_width_max INTEGER, -- cm
  growth_rate TEXT CHECK (growth_rate IN ('very_slow', 'slow', 'medium', 'fast', 'very_fast')),
  
  -- Growing requirements
  sun_requirements TEXT[] CHECK (sun_requirements <@ ARRAY['full_sun', 'partial_sun', 'partial_shade', 'full_shade']),
  water_needs TEXT CHECK (water_needs IN ('very_low', 'low', 'medium', 'high', 'very_high')),
  hardiness_zones INTEGER[],
  soil_preferences TEXT[] CHECK (soil_preferences <@ ARRAY['clay', 'loam', 'sand', 'well_draining', 'moist', 'dry', 'acidic', 'neutral', 'alkaline']),
  
  -- Care information
  care_difficulty TEXT CHECK (care_difficulty IN ('very_easy', 'easy', 'medium', 'hard', 'very_hard')),
  care_instructions TEXT,
  special_features TEXT[], -- ['drought_tolerant', 'deer_resistant', 'attracts_butterflies', etc.]
  
  -- Seasonal information
  bloom_time TEXT[], -- Months or seasons when it blooms
  bloom_color TEXT[],
  foliage_color TEXT[],
  fall_color TEXT[],
  
  -- Additional attributes (flexible JSONB for future expansion)
  attributes JSONB DEFAULT '{}'::jsonb,

  -- Pricing
  base_price DECIMAL(10,2) NOT NULL,
  wholesale_price DECIMAL(10,2),
  cost_price DECIMAL(10,2), -- For margin calculations
  
  -- Inventory settings
  track_inventory BOOLEAN DEFAULT TRUE,
  low_stock_threshold INTEGER DEFAULT 5,
  
  -- Status and visibility
  is_active BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  is_digital BOOLEAN DEFAULT FALSE, -- For gift cards, consultations, etc.
  
  -- SEO
  meta_title TEXT,
  meta_description TEXT,
  
  -- Dates
  available_from DATE,
  available_until DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for products
CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- PRODUCT VARIANTS TABLE - Size and container variations
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.product_variants (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  variant_name TEXT NOT NULL, -- e.g., "6-inch pot", "2-gallon container"
  sku TEXT UNIQUE NOT NULL,
  
  -- Variant specifications
  size_category TEXT, -- e.g., "small", "medium", "large", "extra_large"
  container_type TEXT, -- e.g., "pot", "container", "bare_root", "balled_and_burlapped"
  container_size TEXT, -- e.g., "4-inch", "1-gallon", "15-gallon"
  container_material TEXT, -- e.g., "plastic", "terracotta", "biodegradable"
  
  -- Physical dimensions
  height_cm INTEGER,
  width_cm INTEGER,
  weight_kg DECIMAL(8,2),
  
  -- Pricing adjustments (relative to base product price)
  price_adjustment DECIMAL(8,2) DEFAULT 0, -- Can be positive or negative
  price_multiplier DECIMAL(5,4) DEFAULT 1.0, -- Alternative to fixed adjustment
  wholesale_price_adjustment DECIMAL(8,2) DEFAULT 0,
  
  -- Inventory
  track_inventory BOOLEAN DEFAULT TRUE,
  low_stock_threshold INTEGER DEFAULT 5,
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  is_default BOOLEAN DEFAULT FALSE, -- One variant per product should be default
  
  -- Additional variant-specific attributes
  attributes JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for product_variants
CREATE TRIGGER update_product_variants_updated_at
  BEFORE UPDATE ON public.product_variants
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Ensure only one default variant per product
CREATE UNIQUE INDEX idx_product_variants_default 
ON public.product_variants(product_id) 
WHERE is_default = TRUE;

-- =============================================================================
-- PRODUCT IMAGES TABLE - Product gallery
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.product_images (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES public.product_variants(id) ON DELETE CASCADE, -- Optional: variant-specific images
  
  image_url TEXT NOT NULL,
  alt_text TEXT,
  title TEXT,
  description TEXT,
  
  -- Image metadata
  image_type TEXT CHECK (image_type IN ('main', 'gallery', 'care_guide', 'mature_plant', 'detail', 'lifestyle')),
  sort_order INTEGER DEFAULT 0,
  is_primary BOOLEAN DEFAULT FALSE, -- One primary image per product
  
  -- Image properties
  width_px INTEGER,
  height_px INTEGER,
  file_size_bytes INTEGER,
  file_format TEXT, -- jpg, png, webp, etc.
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for product_images
CREATE TRIGGER update_product_images_updated_at
  BEFORE UPDATE ON public.product_images
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Ensure only one primary image per product
CREATE UNIQUE INDEX idx_product_images_primary 
ON public.product_images(product_id) 
WHERE is_primary = TRUE AND variant_id IS NULL;

-- Ensure only one primary image per variant
CREATE UNIQUE INDEX idx_product_images_variant_primary 
ON public.product_images(variant_id) 
WHERE is_primary = TRUE AND variant_id IS NOT NULL;

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- Categories indexes
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON public.categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_slug ON public.categories(slug);
CREATE INDEX IF NOT EXISTS idx_categories_active ON public.categories(is_active) WHERE is_active = TRUE;
-- CREATE INDEX IF NOT EXISTS idx_categories_path ON public.categories USING gin(string_to_array(path, '/'));
-- Note: Commented out due to function not being IMMUTABLE - use regular btree index instead
CREATE INDEX IF NOT EXISTS idx_categories_path ON public.categories(path);
CREATE INDEX IF NOT EXISTS idx_categories_depth ON public.categories(depth);

-- Products indexes
CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products(category_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_products_sku ON public.products(sku);
CREATE INDEX IF NOT EXISTS idx_products_slug ON public.products(slug);
CREATE INDEX IF NOT EXISTS idx_products_active ON public.products(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_products_featured ON public.products(is_featured) WHERE is_featured = TRUE;
CREATE INDEX IF NOT EXISTS idx_products_plant_type ON public.products(plant_type) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_products_price ON public.products(base_price) WHERE is_active = TRUE;

-- Full-text search index for products
CREATE INDEX IF NOT EXISTS idx_products_search ON public.products 
USING gin(to_tsvector('english', name || ' ' || COALESCE(description, '') || ' ' || COALESCE(botanical_name, '')));

-- GIN indexes for array columns
CREATE INDEX IF NOT EXISTS idx_products_sun_requirements ON public.products USING gin(sun_requirements);
CREATE INDEX IF NOT EXISTS idx_products_hardiness_zones ON public.products USING gin(hardiness_zones);
CREATE INDEX IF NOT EXISTS idx_products_special_features ON public.products USING gin(special_features);

-- Product variants indexes
CREATE INDEX IF NOT EXISTS idx_product_variants_product_id ON public.product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_sku ON public.product_variants(sku);
CREATE INDEX IF NOT EXISTS idx_product_variants_active ON public.product_variants(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_product_variants_container_type ON public.product_variants(container_type);

-- Product images indexes
CREATE INDEX IF NOT EXISTS idx_product_images_product_id ON public.product_images(product_id);
CREATE INDEX IF NOT EXISTS idx_product_images_variant_id ON public.product_images(variant_id);
CREATE INDEX IF NOT EXISTS idx_product_images_type ON public.product_images(image_type);
CREATE INDEX IF NOT EXISTS idx_product_images_sort_order ON public.product_images(product_id, sort_order);

-- =============================================================================
-- SAMPLE DATA
-- =============================================================================

-- Insert default categories
INSERT INTO public.categories (name, slug, description, sort_order) VALUES
('Trees', 'trees', 'All types of trees for landscaping and gardening', 1),
('Shrubs & Bushes', 'shrubs', 'Ornamental and functional shrubs', 2),
('Perennials', 'perennials', 'Plants that return year after year', 3),
('Annuals', 'annuals', 'Plants that complete their lifecycle in one year', 4),
('Houseplants', 'houseplants', 'Indoor plants for home and office', 5),
('Herbs', 'herbs', 'Culinary and medicinal herbs', 6),
('Vegetables', 'vegetables', 'Edible plants for the garden', 7),
('Succulents', 'succulents', 'Drought-resistant plants', 8);

-- Insert subcategories for trees
INSERT INTO public.categories (name, slug, description, parent_id, sort_order) VALUES
('Shade Trees', 'shade-trees', 'Large trees for shade and privacy', 
 (SELECT id FROM public.categories WHERE slug = 'trees'), 1),
('Ornamental Trees', 'ornamental-trees', 'Decorative flowering trees', 
 (SELECT id FROM public.categories WHERE slug = 'trees'), 2),
('Fruit Trees', 'fruit-trees', 'Edible fruit producing trees', 
 (SELECT id FROM public.categories WHERE slug = 'trees'), 3);

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON TABLE public.categories IS 'Hierarchical product categories with materialized path for efficient queries';
COMMENT ON TABLE public.products IS 'Main products table with comprehensive plant-specific attributes';
COMMENT ON TABLE public.product_variants IS 'Product variations for different sizes, containers, and specifications';
COMMENT ON TABLE public.product_images IS 'Product image gallery with support for variant-specific images';

COMMENT ON COLUMN public.categories.path IS 'Materialized path for efficient hierarchical queries (e.g., trees/fruit-trees/citrus)';
COMMENT ON COLUMN public.products.attributes IS 'Flexible JSONB field for additional plant attributes';
COMMENT ON COLUMN public.products.hardiness_zones IS 'Array of USDA hardiness zones where plant can survive';
COMMENT ON COLUMN public.product_variants.price_adjustment IS 'Fixed amount to add/subtract from base price';
COMMENT ON COLUMN public.product_variants.price_multiplier IS 'Multiplier for base price (alternative to fixed adjustment)';