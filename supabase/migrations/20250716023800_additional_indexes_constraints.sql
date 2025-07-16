-- Migration: Additional indexes and constraints for performance optimization
-- Created: 2025-07-16
-- Description: Set up additional composite indexes, unique constraints, and performance optimizations

-- =============================================================================
-- ROW LEVEL SECURITY POLICIES
-- =============================================================================

-- Enable RLS on all user-facing tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipping_addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- PROFILES TABLE POLICIES
-- =============================================================================

-- Users can view and update their own profile
CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Staff and admins can view all profiles
CREATE POLICY "Staff can view all profiles" ON public.profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.user_roles ur ON p.id = ur.user_id
      JOIN public.roles r ON ur.role_id = r.id
      WHERE p.id = auth.uid() 
        AND r.name IN ('admin', 'staff')
        AND ur.is_active = TRUE
    )
  );

-- Admins can update any profile
CREATE POLICY "Admins can update any profile" ON public.profiles
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.user_roles ur ON p.id = ur.user_id
      JOIN public.roles r ON ur.role_id = r.id
      WHERE p.id = auth.uid() 
        AND r.name = 'admin'
        AND ur.is_active = TRUE
    )
  );

-- =============================================================================
-- PRODUCT AND CATALOG POLICIES
-- =============================================================================

-- Anyone can view active products and categories
CREATE POLICY "Anyone can view active categories" ON public.categories
  FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Anyone can view active products" ON public.products
  FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Anyone can view active product variants" ON public.product_variants
  FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Anyone can view product images" ON public.product_images
  FOR SELECT USING (TRUE);

-- Staff and admins can manage products
CREATE POLICY "Staff can manage products" ON public.products
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.user_roles ur ON p.id = ur.user_id
      JOIN public.roles r ON ur.role_id = r.id
      WHERE p.id = auth.uid() 
        AND r.name IN ('admin', 'staff')
        AND ur.is_active = TRUE
    )
  );

CREATE POLICY "Staff can manage categories" ON public.categories
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.user_roles ur ON p.id = ur.user_id
      JOIN public.roles r ON ur.role_id = r.id
      WHERE p.id = auth.uid() 
        AND r.name IN ('admin', 'staff')
        AND ur.is_active = TRUE
    )
  );

-- =============================================================================
-- INVENTORY POLICIES
-- =============================================================================

-- Only staff and admins can view inventory
CREATE POLICY "Staff can view inventory" ON public.inventory_stock
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.user_roles ur ON p.id = ur.user_id
      JOIN public.roles r ON ur.role_id = r.id
      WHERE p.id = auth.uid() 
        AND r.name IN ('admin', 'staff')
        AND ur.is_active = TRUE
    )
  );

-- Staff and admins can manage inventory
CREATE POLICY "Staff can manage inventory" ON public.inventory_stock
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.user_roles ur ON p.id = ur.user_id
      JOIN public.roles r ON ur.role_id = r.id
      WHERE p.id = auth.uid() 
        AND r.name IN ('admin', 'staff')
        AND ur.is_active = TRUE
    )
  );

-- Stock movements policy
CREATE POLICY "Staff can view stock movements" ON public.stock_movements
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.user_roles ur ON p.id = ur.user_id
      JOIN public.roles r ON ur.role_id = r.id
      WHERE p.id = auth.uid() 
        AND r.name IN ('admin', 'staff')
        AND ur.is_active = TRUE
    )
  );

-- =============================================================================
-- ORDER POLICIES
-- =============================================================================

-- Users can view their own orders
CREATE POLICY "Users can view own orders" ON public.orders
  FOR SELECT USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.company_profiles cp
      WHERE cp.id = company_id AND cp.user_id = auth.uid()
    )
  );

-- Users can create orders
CREATE POLICY "Users can create orders" ON public.orders
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Staff can view all orders
CREATE POLICY "Staff can view all orders" ON public.orders
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.user_roles ur ON p.id = ur.user_id
      JOIN public.roles r ON ur.role_id = r.id
      WHERE p.id = auth.uid() 
        AND r.name IN ('admin', 'staff')
        AND ur.is_active = TRUE
    )
  );

-- Users can view their own order items
CREATE POLICY "Users can view own order items" ON public.order_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.orders o
      WHERE o.id = order_id AND o.user_id = auth.uid()
    )
  );

-- =============================================================================
-- SHIPPING ADDRESSES POLICIES
-- =============================================================================

-- Users can manage their own shipping addresses
CREATE POLICY "Users can manage own addresses" ON public.shipping_addresses
  FOR ALL USING (auth.uid() = user_id);

-- =============================================================================
-- NOTIFICATIONS POLICIES
-- =============================================================================

-- Users can view their own notifications
CREATE POLICY "Users can view own notifications" ON public.notifications
  FOR SELECT USING (
    auth.uid() = user_id OR
    EXISTS (
      SELECT 1 FROM public.user_roles ur
      WHERE ur.user_id = auth.uid() AND ur.role_id = role_id AND ur.is_active = TRUE
    )
  );

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- ACTIVITY LOGS POLICIES
-- =============================================================================

-- Staff can view activity logs
CREATE POLICY "Staff can view activity logs" ON public.activity_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      JOIN public.user_roles ur ON p.id = ur.user_id
      JOIN public.roles r ON ur.role_id = r.id
      WHERE p.id = auth.uid() 
        AND r.name IN ('admin', 'staff')
        AND ur.is_active = TRUE
    )
  );

-- Users can view their own activity logs
CREATE POLICY "Users can view own activity" ON public.activity_logs
  FOR SELECT USING (auth.uid() = user_id);

-- =============================================================================
-- ADDITIONAL COMPOSITE INDEXES FOR PERFORMANCE
-- =============================================================================

-- Profiles composite indexes
CREATE INDEX IF NOT EXISTS idx_profiles_type_status ON public.profiles(user_type, status);
CREATE INDEX IF NOT EXISTS idx_profiles_created_date ON public.profiles(created_at);

-- Company profiles composite indexes
CREATE INDEX IF NOT EXISTS idx_company_profiles_approval_tier ON public.company_profiles(approval_status, discount_tier);

-- Products composite indexes
CREATE INDEX IF NOT EXISTS idx_products_category_active ON public.products(category_id, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_products_type_active ON public.products(plant_type, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_products_featured_active ON public.products(is_featured, is_active) WHERE is_featured = TRUE AND is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_products_price_range ON public.products(base_price, is_active) WHERE is_active = TRUE;

-- Product variants composite indexes
CREATE INDEX IF NOT EXISTS idx_product_variants_product_active ON public.product_variants(product_id, is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_product_variants_container_active ON public.product_variants(container_type, is_active) WHERE is_active = TRUE;

-- Inventory composite indexes
CREATE INDEX IF NOT EXISTS idx_inventory_stock_variant_location ON public.inventory_stock(product_variant_id, location_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_low_stock_alert ON public.inventory_stock(product_variant_id, location_id, quantity_available) 
  WHERE quantity_available <= reorder_point AND reorder_point > 0;
CREATE INDEX IF NOT EXISTS idx_inventory_stock_negative ON public.inventory_stock(location_id, quantity_available) 
  WHERE quantity_available < 0;

-- Stock movements composite indexes
CREATE INDEX IF NOT EXISTS idx_stock_movements_variant_date ON public.stock_movements(product_variant_id, created_at);
CREATE INDEX IF NOT EXISTS idx_stock_movements_location_date ON public.stock_movements(location_id, created_at);
CREATE INDEX IF NOT EXISTS idx_stock_movements_type_date ON public.stock_movements(movement_type, created_at);

-- Orders composite indexes
CREATE INDEX IF NOT EXISTS idx_orders_user_status ON public.orders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_orders_user_date ON public.orders(user_id, order_date);
CREATE INDEX IF NOT EXISTS idx_orders_status_date ON public.orders(status, order_date);
CREATE INDEX IF NOT EXISTS idx_orders_company_status ON public.orders(company_id, status) WHERE company_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_sales_rep_date ON public.orders(sales_representative_id, order_date) WHERE sales_representative_id IS NOT NULL;

-- Order items composite indexes
CREATE INDEX IF NOT EXISTS idx_order_items_order_variant ON public.order_items(order_id, product_variant_id);
CREATE INDEX IF NOT EXISTS idx_order_items_variant_date ON public.order_items(product_variant_id, created_at);

-- Notifications composite indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read, created_at) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_type_priority ON public.notifications(notification_type, priority, created_at);

-- Activity logs composite indexes
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_type_date ON public.activity_logs(user_id, activity_type, created_at);
CREATE INDEX IF NOT EXISTS idx_activity_logs_entity_date ON public.activity_logs(entity_type, entity_id, created_at);

-- =============================================================================
-- JSONB INDEXES FOR ADVANCED QUERIES
-- =============================================================================

-- Products JSONB attributes index
CREATE INDEX IF NOT EXISTS idx_products_attributes_gin ON public.products USING gin(attributes);

-- Orders shipping and billing address indexes
CREATE INDEX IF NOT EXISTS idx_orders_shipping_address_gin ON public.orders USING gin(shipping_address);
CREATE INDEX IF NOT EXISTS idx_orders_billing_address_gin ON public.orders USING gin(billing_address);

-- Notifications data index
CREATE INDEX IF NOT EXISTS idx_notifications_data_gin ON public.notifications USING gin(data);

-- System settings value index
CREATE INDEX IF NOT EXISTS idx_system_settings_value_gin ON public.system_settings USING gin(value);

-- =============================================================================
-- TEXT SEARCH INDEXES
-- =============================================================================

-- Products full-text search (updated for better performance)
DROP INDEX IF EXISTS idx_products_search;
CREATE INDEX idx_products_search_tsvector ON public.products 
USING gin(to_tsvector('english', 
  COALESCE(name, '') || ' ' || 
  COALESCE(description, '') || ' ' || 
  COALESCE(botanical_name, '')
)) WHERE is_active = TRUE;

-- Categories full-text search
CREATE INDEX IF NOT EXISTS idx_categories_search_tsvector ON public.categories 
USING gin(to_tsvector('english', 
  COALESCE(name, '') || ' ' || 
  COALESCE(description, '')
)) WHERE is_active = TRUE;

-- User profiles search
CREATE INDEX IF NOT EXISTS idx_profiles_search_tsvector ON public.profiles 
USING gin(to_tsvector('english', 
  COALESCE(first_name, '') || ' ' || 
  COALESCE(last_name, '') || ' ' ||
  COALESCE(email, '')
));

-- Company profiles search
CREATE INDEX IF NOT EXISTS idx_company_profiles_search_tsvector ON public.company_profiles 
USING gin(to_tsvector('english', 
  COALESCE(company_name, '') || ' ' || 
  COALESCE(business_registration, '')
));

-- =============================================================================
-- PARTIAL INDEXES FOR SPECIFIC QUERIES
-- =============================================================================

-- Active records only indexes
CREATE INDEX IF NOT EXISTS idx_products_active_only ON public.products(created_at) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_categories_active_only ON public.categories(sort_order) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_product_variants_active_only ON public.product_variants(product_id) WHERE is_active = TRUE;

-- B2B specific indexes
CREATE INDEX IF NOT EXISTS idx_profiles_b2b_only ON public.profiles(created_at) WHERE user_type = 'B2B';
CREATE INDEX IF NOT EXISTS idx_orders_wholesale_only ON public.orders(order_date) WHERE order_type = 'wholesale';

-- Inventory alerts indexes
CREATE INDEX IF NOT EXISTS idx_inventory_out_of_stock ON public.inventory_stock(location_id) WHERE quantity_available = 0;
CREATE INDEX IF NOT EXISTS idx_inventory_overstocked ON public.inventory_stock(location_id) WHERE max_stock_level IS NOT NULL AND quantity_available > max_stock_level;

-- Order status specific indexes
CREATE INDEX IF NOT EXISTS idx_orders_pending_only ON public.orders(order_date) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_orders_processing_only ON public.orders(order_date) WHERE status = 'processing';
CREATE INDEX IF NOT EXISTS idx_orders_shipped_only ON public.orders(shipped_at) WHERE status = 'shipped';

-- =============================================================================
-- UNIQUE CONSTRAINTS
-- =============================================================================

-- Additional unique constraints for data integrity
ALTER TABLE public.profiles ADD CONSTRAINT unique_profiles_email UNIQUE (email);
ALTER TABLE public.company_profiles ADD CONSTRAINT unique_company_user UNIQUE (user_id);
ALTER TABLE public.categories ADD CONSTRAINT unique_category_slug UNIQUE (slug);
ALTER TABLE public.products ADD CONSTRAINT unique_product_sku UNIQUE (sku);
ALTER TABLE public.products ADD CONSTRAINT unique_product_slug UNIQUE (slug);
ALTER TABLE public.product_variants ADD CONSTRAINT unique_variant_sku UNIQUE (sku);
ALTER TABLE public.inventory_locations ADD CONSTRAINT unique_location_code UNIQUE (code);
ALTER TABLE public.orders ADD CONSTRAINT unique_order_number UNIQUE (order_number);

-- =============================================================================
-- CHECK CONSTRAINTS FOR DATA VALIDATION
-- =============================================================================

-- Email format validation
ALTER TABLE public.profiles ADD CONSTRAINT check_email_format 
  CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- Phone number format validation (Vietnamese format)
ALTER TABLE public.profiles ADD CONSTRAINT check_phone_format 
  CHECK (phone IS NULL OR phone ~* '^\+?84[0-9]{8,9}$|^0[0-9]{9,10}$');

-- Price validation
ALTER TABLE public.products ADD CONSTRAINT check_positive_prices 
  CHECK (base_price >= 0 AND (wholesale_price IS NULL OR wholesale_price >= 0));

-- Quantity validation
ALTER TABLE public.product_variants ADD CONSTRAINT check_positive_threshold 
  CHECK (low_stock_threshold >= 0);

-- Order amount validation
ALTER TABLE public.orders ADD CONSTRAINT check_positive_amounts 
  CHECK (subtotal >= 0 AND tax_amount >= 0 AND shipping_amount >= 0 AND total_amount >= 0);

-- Percentage validation for discounts
ALTER TABLE public.pricing_tiers ADD CONSTRAINT check_discount_percentage_range 
  CHECK (discount_percentage >= 0 AND discount_percentage <= 100);

-- =============================================================================
-- FOREIGN KEY CONSTRAINTS WITH APPROPRIATE ACTIONS
-- =============================================================================

-- Update foreign key constraints to handle cascading properly
ALTER TABLE public.product_variants 
  DROP CONSTRAINT IF EXISTS product_variants_product_id_fkey,
  ADD CONSTRAINT product_variants_product_id_fkey 
    FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE public.product_images 
  DROP CONSTRAINT IF EXISTS product_images_product_id_fkey,
  ADD CONSTRAINT product_images_product_id_fkey 
    FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE;

ALTER TABLE public.inventory_stock 
  DROP CONSTRAINT IF EXISTS inventory_stock_product_variant_id_fkey,
  ADD CONSTRAINT inventory_stock_product_variant_id_fkey 
    FOREIGN KEY (product_variant_id) REFERENCES public.product_variants(id) ON DELETE CASCADE;

ALTER TABLE public.order_items 
  DROP CONSTRAINT IF EXISTS order_items_product_variant_id_fkey,
  ADD CONSTRAINT order_items_product_variant_id_fkey 
    FOREIGN KEY (product_variant_id) REFERENCES public.product_variants(id) ON DELETE RESTRICT;

-- =============================================================================
-- PERFORMANCE OPTIMIZATION FUNCTIONS
-- =============================================================================

-- Function to analyze table statistics
CREATE OR REPLACE FUNCTION public.analyze_table_performance(input_table_name TEXT)
RETURNS TABLE (
  table_name TEXT,
  row_count BIGINT,
  table_size TEXT,
  index_size TEXT,
  total_size TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    input_table_name,
    (SELECT reltuples::BIGINT FROM pg_class WHERE relname = input_table_name),
    pg_size_pretty(pg_relation_size(input_table_name::regclass)),
    pg_size_pretty(pg_indexes_size(input_table_name::regclass)),
    pg_size_pretty(pg_total_relation_size(input_table_name::regclass));
END;
$$ LANGUAGE plpgsql;

-- Function to get slow queries (requires pg_stat_statements extension)
CREATE OR REPLACE FUNCTION public.get_slow_queries(limit_count INTEGER DEFAULT 10)
RETURNS TABLE (
  query TEXT,
  calls BIGINT,
  total_time DOUBLE PRECISION,
  mean_time DOUBLE PRECISION
) AS $$
BEGIN
  -- This function requires pg_stat_statements extension
  -- It will fail gracefully if the extension is not available
  BEGIN
    RETURN QUERY
    SELECT 
      pss.query,
      pss.calls,
      pss.total_exec_time,
      pss.mean_exec_time
    FROM pg_stat_statements pss
    ORDER BY pss.total_exec_time DESC
    LIMIT limit_count;
  EXCEPTION WHEN OTHERS THEN
    -- Return empty result if pg_stat_statements is not available
    RETURN;
  END;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- MATERIALIZED VIEWS FOR REPORTING
-- =============================================================================

-- Materialized view for product catalog with stock information
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_product_catalog AS
SELECT 
  p.id,
  p.sku,
  p.name,
  p.slug,
  p.description,
  p.botanical_name,
  p.plant_type,
  p.base_price,
  p.wholesale_price,
  p.is_active,
  p.is_featured,
  c.name as category_name,
  c.slug as category_slug,
  COALESCE(SUM(ist.quantity_available), 0) as total_stock,
  COALESCE(SUM(ist.quantity_sellable), 0) as total_sellable,
  COUNT(DISTINCT pv.id) as variant_count,
  (ARRAY_AGG(pv.id) FILTER (WHERE pv.id IS NOT NULL))[1] as default_variant_id,
  ARRAY_AGG(DISTINCT pi.image_url) FILTER (WHERE pi.image_url IS NOT NULL) as image_urls
FROM public.products p
LEFT JOIN public.categories c ON p.category_id = c.id
LEFT JOIN public.product_variants pv ON p.id = pv.product_id AND pv.is_active = TRUE
LEFT JOIN public.inventory_stock ist ON pv.id = ist.product_variant_id
LEFT JOIN public.product_images pi ON p.id = pi.product_id AND pi.is_primary = TRUE
WHERE p.is_active = TRUE
GROUP BY p.id, c.name, c.slug;

-- Create unique index for materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_product_catalog_id ON public.mv_product_catalog(id);
CREATE INDEX IF NOT EXISTS idx_mv_product_catalog_category ON public.mv_product_catalog(category_slug);
CREATE INDEX IF NOT EXISTS idx_mv_product_catalog_stock ON public.mv_product_catalog(total_sellable);

-- Materialized view for inventory summary
CREATE MATERIALIZED VIEW IF NOT EXISTS public.mv_inventory_summary AS
SELECT 
  il.id as location_id,
  il.code as location_code,
  il.name as location_name,
  COUNT(DISTINCT ist.product_variant_id) as unique_products,
  SUM(ist.quantity_available) as total_quantity,
  SUM(ist.quantity_sellable) as total_sellable,
  COUNT(*) FILTER (WHERE ist.quantity_available <= ist.reorder_point AND ist.reorder_point > 0) as low_stock_items,
  COUNT(*) FILTER (WHERE ist.quantity_available = 0) as out_of_stock_items,
  AVG(ist.average_cost) as avg_inventory_cost,
  SUM(ist.quantity_available * ist.average_cost) as total_inventory_value
FROM public.inventory_locations il
LEFT JOIN public.inventory_stock ist ON il.id = ist.location_id
WHERE il.is_active = TRUE
GROUP BY il.id, il.code, il.name;

-- Create unique index for inventory summary materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_inventory_summary_location_id ON public.mv_inventory_summary(location_id);

-- Function to refresh materialized views
CREATE OR REPLACE FUNCTION public.refresh_materialized_views()
RETURNS VOID AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_product_catalog;
  REFRESH MATERIALIZED VIEW CONCURRENTLY public.mv_inventory_summary;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON INDEX idx_products_search_tsvector IS 'Full-text search index for products including name, description, botanical name, and common names';
COMMENT ON INDEX idx_inventory_stock_low_stock_alert IS 'Optimized index for finding products below reorder point';
COMMENT ON MATERIALIZED VIEW public.mv_product_catalog IS 'Pre-computed product catalog with stock and image information for fast queries';
COMMENT ON MATERIALIZED VIEW public.mv_inventory_summary IS 'Inventory summary by location with key metrics for dashboard views';

-- =============================================================================
-- PERFORMANCE MONITORING SETUP
-- =============================================================================

-- Create a function to monitor index usage
CREATE OR REPLACE FUNCTION public.get_unused_indexes()
RETURNS TABLE (
  schemaname TEXT,
  tablename TEXT,
  indexname TEXT,
  index_size TEXT,
  index_scans BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    psi.schemaname::TEXT,
    psi.relname::TEXT,
    psi.indexrelname::TEXT,
    pg_size_pretty(pg_relation_size(psi.indexrelid))::TEXT,
    psi.idx_scan
  FROM pg_stat_user_indexes psi
  JOIN pg_index pi ON psi.indexrelid = pi.indexrelid
  WHERE psi.idx_scan < 10  -- Indexes used less than 10 times
    AND NOT pi.indisunique  -- Exclude unique indexes
    AND psi.schemaname = 'public'
  ORDER BY pg_relation_size(psi.indexrelid) DESC;
END;
$$ LANGUAGE plpgsql;

-- Create notification for when materialized views need refresh
CREATE OR REPLACE FUNCTION public.schedule_mv_refresh()
RETURNS VOID AS $$
BEGIN
  -- This would typically be called by a scheduled task
  -- to refresh materialized views during low-traffic periods
  PERFORM public.refresh_materialized_views();
  
  -- Log the refresh
  INSERT INTO public.system_settings (category, key, value, data_type, name, description)
  VALUES ('system', 'last_mv_refresh', to_jsonb(CURRENT_TIMESTAMP), 'string', 'Last MV Refresh', 'Timestamp of last materialized view refresh')
  ON CONFLICT (category, key) 
  DO UPDATE SET value = to_jsonb(CURRENT_TIMESTAMP), updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;