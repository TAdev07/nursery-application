-- Migration: Setup Row Level Security (RLS) - Nursery Worker Policies
-- Created: 2025-07-16
-- Description: Thiết lập RLS policies cho Workers xử lý inventory và production tasks

-- =============================================================================
-- HELPER FUNCTIONS FOR WORKERS
-- =============================================================================

-- Function to check if current user is Nursery Worker
CREATE OR REPLACE FUNCTION public.is_nursery_worker()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN public.has_role('nursery_worker');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a warehouse is accessible to current worker
CREATE OR REPLACE FUNCTION public.worker_can_access_warehouse(warehouse_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Workers can access warehouses in their company
  RETURN EXISTS (
    SELECT 1 
    FROM public.warehouses w
    JOIN public.company_profiles cp ON w.company_id = cp.id
    WHERE w.id = warehouse_id
    AND public.user_in_same_company(cp.user_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if an adjustment was made by current user
CREATE OR REPLACE FUNCTION public.is_my_adjustment(adjustment_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.inventory_adjustments ia
    WHERE ia.id = adjustment_id
    AND ia.adjusted_by = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- NURSERY WORKER RLS POLICIES
-- =============================================================================

-- PROFILES TABLE - Can view and update own profile only
CREATE POLICY "nursery_worker_profiles_select" ON public.profiles
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND id = auth.uid()
  );

CREATE POLICY "nursery_worker_profiles_update" ON public.profiles
  FOR UPDATE USING (
    public.is_nursery_worker() 
    AND id = auth.uid()
  );

-- CATEGORIES TABLE - Can view categories (read-only)
CREATE POLICY "nursery_worker_categories_select" ON public.categories
  FOR SELECT USING (public.is_nursery_worker());

-- PRODUCTS TABLE - Can view products (read-only)
CREATE POLICY "nursery_worker_products_select" ON public.products
  FOR SELECT USING (public.is_nursery_worker());

-- PRODUCT_VARIANTS TABLE - Can view product variants (read-only)
CREATE POLICY "nursery_worker_product_variants_select" ON public.product_variants
  FOR SELECT USING (public.is_nursery_worker());

-- PRODUCT_IMAGES TABLE - Can view product images (read-only)
CREATE POLICY "nursery_worker_product_images_select" ON public.product_images
  FOR SELECT USING (public.is_nursery_worker());

-- PRODUCT_CATEGORIES TABLE - Can view product categorizations (read-only)
CREATE POLICY "nursery_worker_product_categories_select" ON public.product_categories
  FOR SELECT USING (public.is_nursery_worker());

-- WAREHOUSES TABLE - Can view warehouses in accessible locations
CREATE POLICY "nursery_worker_warehouses_select" ON public.warehouses
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND public.worker_can_access_warehouse(id)
  );

-- INVENTORY_ITEMS TABLE - Can view and update inventory in accessible warehouses
CREATE POLICY "nursery_worker_inventory_items_select" ON public.inventory_items
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND public.worker_can_access_warehouse(warehouse_id)
  );

CREATE POLICY "nursery_worker_inventory_items_update" ON public.inventory_items
  FOR UPDATE USING (
    public.is_nursery_worker() 
    AND public.worker_can_access_warehouse(warehouse_id)
  );

-- INVENTORY_MOVEMENTS TABLE - Can view movements in accessible warehouses and create new ones
CREATE POLICY "nursery_worker_inventory_movements_select" ON public.inventory_movements
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND (
      public.worker_can_access_warehouse(from_warehouse_id) 
      OR public.worker_can_access_warehouse(to_warehouse_id)
    )
  );

CREATE POLICY "nursery_worker_inventory_movements_insert" ON public.inventory_movements
  FOR INSERT WITH CHECK (
    public.is_nursery_worker() 
    AND (
      public.worker_can_access_warehouse(from_warehouse_id) 
      OR public.worker_can_access_warehouse(to_warehouse_id)
    )
    AND moved_by = auth.uid()
  );

-- INVENTORY_ADJUSTMENTS TABLE - Can view and create adjustments in accessible warehouses
CREATE POLICY "nursery_worker_inventory_adjustments_select" ON public.inventory_adjustments
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND (
      public.worker_can_access_warehouse(warehouse_id)
      OR adjusted_by = auth.uid() -- Can always see own adjustments
    )
  );

CREATE POLICY "nursery_worker_inventory_adjustments_insert" ON public.inventory_adjustments
  FOR INSERT WITH CHECK (
    public.is_nursery_worker() 
    AND public.worker_can_access_warehouse(warehouse_id)
    AND adjusted_by = auth.uid()
  );

-- STOCK_ALERTS TABLE - Can view alerts for accessible warehouses
CREATE POLICY "nursery_worker_stock_alerts_select" ON public.stock_alerts
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND public.worker_can_access_warehouse(warehouse_id)
  );

-- ORDERS TABLE - Can view orders for fulfillment purposes (read-only)
CREATE POLICY "nursery_worker_orders_select" ON public.orders
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND status IN ('confirmed', 'processing', 'ready_for_pickup', 'out_for_delivery')
  );

-- ORDER_ITEMS TABLE - Can view order items for fulfillment (read-only)
CREATE POLICY "nursery_worker_order_items_select" ON public.order_items
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND EXISTS (
      SELECT 1 FROM public.orders o 
      WHERE o.id = order_id 
      AND o.status IN ('confirmed', 'processing', 'ready_for_pickup', 'out_for_delivery')
    )
  );

-- ORDER_STATUS_HISTORY TABLE - Can view status history (read-only)
CREATE POLICY "nursery_worker_order_status_history_select" ON public.order_status_history
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND EXISTS (
      SELECT 1 FROM public.orders o 
      WHERE o.id = order_id 
      AND o.status IN ('confirmed', 'processing', 'ready_for_pickup', 'out_for_delivery')
    )
  );

-- SHIPPING_DETAILS TABLE - Can view shipping details for fulfillment (read-only)
CREATE POLICY "nursery_worker_shipping_details_select" ON public.shipping_details
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND EXISTS (
      SELECT 1 FROM public.orders o 
      WHERE o.id = order_id 
      AND o.status IN ('confirmed', 'processing', 'ready_for_pickup', 'out_for_delivery')
    )
  );

-- LOCATIONS TABLE - Can view locations (read-only)
CREATE POLICY "nursery_worker_locations_select" ON public.locations
  FOR SELECT USING (public.is_nursery_worker());

-- NURSERIES TABLE - Can view nursery information in accessible areas
CREATE POLICY "nursery_worker_nurseries_select" ON public.nurseries
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND EXISTS (
      SELECT 1 
      FROM public.company_profiles cp
      WHERE cp.id = company_id
      AND public.user_in_same_company(cp.user_id)
    )
  );

-- SEASONAL_AVAILABILITY TABLE - Can view seasonal availability (read-only)
CREATE POLICY "nursery_worker_seasonal_availability_select" ON public.seasonal_availability
  FOR SELECT USING (public.is_nursery_worker());

CREATE POLICY "nursery_worker_seasonal_availability_update" ON public.seasonal_availability
  FOR UPDATE USING (
    public.is_nursery_worker() 
    AND updated_by = auth.uid()
  );

-- NOTIFICATION_PREFERENCES TABLE - Can manage own notification preferences
CREATE POLICY "nursery_worker_notification_preferences_select" ON public.notification_preferences
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND user_id = auth.uid()
  );

CREATE POLICY "nursery_worker_notification_preferences_insert" ON public.notification_preferences
  FOR INSERT WITH CHECK (
    public.is_nursery_worker() 
    AND user_id = auth.uid()
  );

CREATE POLICY "nursery_worker_notification_preferences_update" ON public.notification_preferences
  FOR UPDATE USING (
    public.is_nursery_worker() 
    AND user_id = auth.uid()
  );

-- NOTIFICATIONS TABLE - Can view own notifications
CREATE POLICY "nursery_worker_notifications_select" ON public.notifications
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND user_id = auth.uid()
  );

-- AUDIT_LOGS TABLE - Can view logs of own actions
CREATE POLICY "nursery_worker_audit_logs_select" ON public.audit_logs
  FOR SELECT USING (
    public.is_nursery_worker() 
    AND user_id = auth.uid()
  );

-- =============================================================================
-- PRODUCTION/CULTIVATION SPECIFIC POLICIES
-- =============================================================================

-- Workers might need additional tables for production tracking
-- These policies can be extended when production tables are added

-- Example: PRODUCTION_BATCHES TABLE (if exists)
-- CREATE POLICY "nursery_worker_production_batches_select" ON public.production_batches
--   FOR SELECT USING (
--     public.is_nursery_worker() 
--     AND nursery_id IN (
--       SELECT n.id FROM public.nurseries n
--       JOIN public.company_profiles cp ON n.company_id = cp.id
--       WHERE public.user_in_same_company(cp.user_id)
--     )
--   );

-- CREATE POLICY "nursery_worker_production_batches_update" ON public.production_batches
--   FOR UPDATE USING (
--     public.is_nursery_worker() 
--     AND nursery_id IN (
--       SELECT n.id FROM public.nurseries n
--       JOIN public.company_profiles cp ON n.company_id = cp.id
--       WHERE public.user_in_same_company(cp.user_id)
--     )
--   );

-- =============================================================================
-- GRANT EXECUTE PERMISSIONS ON NEW FUNCTIONS
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.is_nursery_worker() TO authenticated;
GRANT EXECUTE ON FUNCTION public.worker_can_access_warehouse(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_my_adjustment(UUID) TO authenticated;

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON FUNCTION public.is_nursery_worker() IS 'Check if current user is Nursery Worker';
COMMENT ON FUNCTION public.worker_can_access_warehouse(UUID) IS 'Check if worker can access warehouse in their company';
COMMENT ON FUNCTION public.is_my_adjustment(UUID) IS 'Check if inventory adjustment was made by current user';