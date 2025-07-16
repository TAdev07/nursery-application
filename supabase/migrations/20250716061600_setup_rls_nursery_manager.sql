-- Migration: Setup Row Level Security (RLS) - Nursery Manager Policies
-- Created: 2025-07-16
-- Description: Thiết lập RLS policies cho Nursery Manager role - quản lý data trong company

-- =============================================================================
-- HELPER FUNCTIONS FOR NURSERY MANAGER
-- =============================================================================

-- Function to check if current user is Nursery Manager
CREATE OR REPLACE FUNCTION public.is_nursery_manager()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN public.has_role('nursery_manager');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a company_id belongs to current user's company
CREATE OR REPLACE FUNCTION public.owns_company(company_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.company_profiles cp
    WHERE cp.id = company_id
    AND cp.user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a user belongs to current user's company
CREATE OR REPLACE FUNCTION public.user_in_same_company(user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  current_company_id UUID;
  target_company_id UUID;
BEGIN
  -- Get current user's company
  SELECT public.get_user_company_id() INTO current_company_id;
  
  -- Get target user's company
  SELECT cp.id INTO target_company_id
  FROM public.company_profiles cp
  WHERE cp.user_id = user_id;
  
  -- Check if they're in the same company
  RETURN current_company_id IS NOT NULL 
    AND target_company_id IS NOT NULL 
    AND current_company_id = target_company_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a nursery belongs to current user's company
CREATE OR REPLACE FUNCTION public.owns_nursery(nursery_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.nurseries n
    JOIN public.company_profiles cp ON n.company_id = cp.id
    WHERE n.id = nursery_id
    AND cp.user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a warehouse belongs to current user's company
CREATE OR REPLACE FUNCTION public.owns_warehouse(warehouse_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.warehouses w
    JOIN public.company_profiles cp ON w.company_id = cp.id
    WHERE w.id = warehouse_id
    AND cp.user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- NURSERY MANAGER RLS POLICIES
-- =============================================================================

-- PROFILES TABLE - Can view/manage staff in same company
CREATE POLICY "nursery_manager_profiles_select" ON public.profiles
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND (
      id = auth.uid() -- Own profile
      OR public.user_in_same_company(id) -- Same company users
    )
  );

CREATE POLICY "nursery_manager_profiles_update" ON public.profiles
  FOR UPDATE USING (
    public.is_nursery_manager() 
    AND (
      id = auth.uid() -- Own profile
      OR public.user_in_same_company(id) -- Same company users
    )
  );

-- COMPANY_PROFILES TABLE - Can manage own company
CREATE POLICY "nursery_manager_company_profiles_select" ON public.company_profiles
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND user_id = auth.uid()
  );

CREATE POLICY "nursery_manager_company_profiles_update" ON public.company_profiles
  FOR UPDATE USING (
    public.is_nursery_manager() 
    AND user_id = auth.uid()
  );

-- USER_ROLES TABLE - Can view roles in same company
CREATE POLICY "nursery_manager_user_roles_select" ON public.user_roles
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND public.user_in_same_company(user_id)
  );

CREATE POLICY "nursery_manager_user_roles_insert" ON public.user_roles
  FOR INSERT WITH CHECK (
    public.is_nursery_manager() 
    AND public.user_in_same_company(user_id)
    AND granted_by = auth.uid()
  );

CREATE POLICY "nursery_manager_user_roles_update" ON public.user_roles
  FOR UPDATE USING (
    public.is_nursery_manager() 
    AND public.user_in_same_company(user_id)
  );

-- CATEGORIES TABLE - Can manage categories
CREATE POLICY "nursery_manager_categories_all" ON public.categories
  FOR ALL USING (public.is_nursery_manager());

-- PRODUCTS TABLE - Can manage all products in system
CREATE POLICY "nursery_manager_products_all" ON public.products
  FOR ALL USING (public.is_nursery_manager());

-- PRODUCT_VARIANTS TABLE - Can manage all product variants
CREATE POLICY "nursery_manager_product_variants_all" ON public.product_variants
  FOR ALL USING (public.is_nursery_manager());

-- PRODUCT_IMAGES TABLE - Can manage all product images
CREATE POLICY "nursery_manager_product_images_all" ON public.product_images
  FOR ALL USING (public.is_nursery_manager());

-- PRODUCT_CATEGORIES TABLE - Can manage all product categorizations
CREATE POLICY "nursery_manager_product_categories_all" ON public.product_categories
  FOR ALL USING (public.is_nursery_manager());

-- WAREHOUSES TABLE - Can manage warehouses in own company
CREATE POLICY "nursery_manager_warehouses_select" ON public.warehouses
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND public.owns_company(company_id)
  );

CREATE POLICY "nursery_manager_warehouses_insert" ON public.warehouses
  FOR INSERT WITH CHECK (
    public.is_nursery_manager() 
    AND public.owns_company(company_id)
  );

CREATE POLICY "nursery_manager_warehouses_update" ON public.warehouses
  FOR UPDATE USING (
    public.is_nursery_manager() 
    AND public.owns_company(company_id)
  );

CREATE POLICY "nursery_manager_warehouses_delete" ON public.warehouses
  FOR DELETE USING (
    public.is_nursery_manager() 
    AND public.owns_company(company_id)
  );

-- INVENTORY_ITEMS TABLE - Can manage inventory in own warehouses
CREATE POLICY "nursery_manager_inventory_items_select" ON public.inventory_items
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND public.owns_warehouse(warehouse_id)
  );

CREATE POLICY "nursery_manager_inventory_items_insert" ON public.inventory_items
  FOR INSERT WITH CHECK (
    public.is_nursery_manager() 
    AND public.owns_warehouse(warehouse_id)
  );

CREATE POLICY "nursery_manager_inventory_items_update" ON public.inventory_items
  FOR UPDATE USING (
    public.is_nursery_manager() 
    AND public.owns_warehouse(warehouse_id)
  );

CREATE POLICY "nursery_manager_inventory_items_delete" ON public.inventory_items
  FOR DELETE USING (
    public.is_nursery_manager() 
    AND public.owns_warehouse(warehouse_id)
  );

-- INVENTORY_MOVEMENTS TABLE - Can view/manage movements in own warehouses
CREATE POLICY "nursery_manager_inventory_movements_select" ON public.inventory_movements
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND (
      public.owns_warehouse(from_warehouse_id) 
      OR public.owns_warehouse(to_warehouse_id)
    )
  );

CREATE POLICY "nursery_manager_inventory_movements_insert" ON public.inventory_movements
  FOR INSERT WITH CHECK (
    public.is_nursery_manager() 
    AND (
      public.owns_warehouse(from_warehouse_id) 
      OR public.owns_warehouse(to_warehouse_id)
    )
  );

-- INVENTORY_ADJUSTMENTS TABLE - Can manage adjustments in own warehouses
CREATE POLICY "nursery_manager_inventory_adjustments_select" ON public.inventory_adjustments
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND public.owns_warehouse(warehouse_id)
  );

CREATE POLICY "nursery_manager_inventory_adjustments_insert" ON public.inventory_adjustments
  FOR INSERT WITH CHECK (
    public.is_nursery_manager() 
    AND public.owns_warehouse(warehouse_id)
    AND adjusted_by = auth.uid()
  );

-- STOCK_ALERTS TABLE - Can view alerts for own warehouses
CREATE POLICY "nursery_manager_stock_alerts_select" ON public.stock_alerts
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND public.owns_warehouse(warehouse_id)
  );

-- ORDERS TABLE - Can view/manage all orders (for business oversight)
CREATE POLICY "nursery_manager_orders_all" ON public.orders
  FOR ALL USING (public.is_nursery_manager());

-- ORDER_ITEMS TABLE - Can view/manage all order items
CREATE POLICY "nursery_manager_order_items_all" ON public.order_items
  FOR ALL USING (public.is_nursery_manager());

-- ORDER_STATUS_HISTORY TABLE - Can view/manage order status history
CREATE POLICY "nursery_manager_order_status_history_select" ON public.order_status_history
  FOR SELECT USING (public.is_nursery_manager());

CREATE POLICY "nursery_manager_order_status_history_insert" ON public.order_status_history
  FOR INSERT WITH CHECK (
    public.is_nursery_manager() 
    AND changed_by = auth.uid()
  );

-- SHIPPING_DETAILS TABLE - Can manage shipping for all orders
CREATE POLICY "nursery_manager_shipping_details_all" ON public.shipping_details
  FOR ALL USING (public.is_nursery_manager());

-- PAYMENTS TABLE - Can view all payments (for financial oversight)
CREATE POLICY "nursery_manager_payments_select" ON public.payments
  FOR SELECT USING (public.is_nursery_manager());

-- PRICE_LISTS TABLE - Can manage price lists
CREATE POLICY "nursery_manager_price_lists_all" ON public.price_lists
  FOR ALL USING (public.is_nursery_manager());

-- CUSTOMER_PRICE_ASSIGNMENTS TABLE - Can manage customer pricing
CREATE POLICY "nursery_manager_customer_price_assignments_all" ON public.customer_price_assignments
  FOR ALL USING (public.is_nursery_manager());

-- DISCOUNTS TABLE - Can manage discounts
CREATE POLICY "nursery_manager_discounts_all" ON public.discounts
  FOR ALL USING (public.is_nursery_manager());

-- CUSTOMER_DISCOUNTS TABLE - Can manage customer discounts
CREATE POLICY "nursery_manager_customer_discounts_all" ON public.customer_discounts
  FOR ALL USING (public.is_nursery_manager());

-- LOCATIONS TABLE - Can manage locations
CREATE POLICY "nursery_manager_locations_all" ON public.locations
  FOR ALL USING (public.is_nursery_manager());

-- NURSERIES TABLE - Can manage nurseries in own company
CREATE POLICY "nursery_manager_nurseries_select" ON public.nurseries
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND public.owns_company(company_id)
  );

CREATE POLICY "nursery_manager_nurseries_insert" ON public.nurseries
  FOR INSERT WITH CHECK (
    public.is_nursery_manager() 
    AND public.owns_company(company_id)
  );

CREATE POLICY "nursery_manager_nurseries_update" ON public.nurseries
  FOR UPDATE USING (
    public.is_nursery_manager() 
    AND public.owns_company(company_id)
  );

CREATE POLICY "nursery_manager_nurseries_delete" ON public.nurseries
  FOR DELETE USING (
    public.is_nursery_manager() 
    AND public.owns_company(company_id)
  );

-- DELIVERY_ZONES TABLE - Can manage delivery zones
CREATE POLICY "nursery_manager_delivery_zones_all" ON public.delivery_zones
  FOR ALL USING (public.is_nursery_manager());

-- SEASONAL_AVAILABILITY TABLE - Can manage seasonal availability
CREATE POLICY "nursery_manager_seasonal_availability_all" ON public.seasonal_availability
  FOR ALL USING (public.is_nursery_manager());

-- PROMOTIONS TABLE - Can manage promotions
CREATE POLICY "nursery_manager_promotions_all" ON public.promotions
  FOR ALL USING (public.is_nursery_manager());

-- CUSTOMER_GROUPS TABLE - Can manage customer groups
CREATE POLICY "nursery_manager_customer_groups_all" ON public.customer_groups
  FOR ALL USING (public.is_nursery_manager());

-- CUSTOMER_GROUP_MEMBERS TABLE - Can manage customer group memberships
CREATE POLICY "nursery_manager_customer_group_members_all" ON public.customer_group_members
  FOR ALL USING (public.is_nursery_manager());

-- NOTIFICATION_PREFERENCES TABLE - Can view own preferences and manage staff preferences
CREATE POLICY "nursery_manager_notification_preferences_select" ON public.notification_preferences
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND (
      user_id = auth.uid() 
      OR public.user_in_same_company(user_id)
    )
  );

CREATE POLICY "nursery_manager_notification_preferences_update" ON public.notification_preferences
  FOR UPDATE USING (
    public.is_nursery_manager() 
    AND (
      user_id = auth.uid() 
      OR public.user_in_same_company(user_id)
    )
  );

-- NOTIFICATIONS TABLE - Can view notifications for own company
CREATE POLICY "nursery_manager_notifications_select" ON public.notifications
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND (
      user_id = auth.uid() 
      OR public.user_in_same_company(user_id)
    )
  );

CREATE POLICY "nursery_manager_notifications_insert" ON public.notifications
  FOR INSERT WITH CHECK (
    public.is_nursery_manager() 
    AND created_by = auth.uid()
  );

-- AUDIT_LOGS TABLE - Can view audit logs for own company activities
CREATE POLICY "nursery_manager_audit_logs_select" ON public.audit_logs
  FOR SELECT USING (
    public.is_nursery_manager() 
    AND (
      user_id = auth.uid() 
      OR public.user_in_same_company(user_id)
    )
  );

-- =============================================================================
-- GRANT EXECUTE PERMISSIONS ON NEW FUNCTIONS
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.is_nursery_manager() TO authenticated;
GRANT EXECUTE ON FUNCTION public.owns_company(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_in_same_company(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owns_nursery(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.owns_warehouse(UUID) TO authenticated;

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON FUNCTION public.is_nursery_manager() IS 'Check if current user is Nursery Manager';
COMMENT ON FUNCTION public.owns_company(UUID) IS 'Check if company_id belongs to current user';
COMMENT ON FUNCTION public.user_in_same_company(UUID) IS 'Check if user_id is in same company as current user';
COMMENT ON FUNCTION public.owns_nursery(UUID) IS 'Check if nursery belongs to current user company';
COMMENT ON FUNCTION public.owns_warehouse(UUID) IS 'Check if warehouse belongs to current user company';