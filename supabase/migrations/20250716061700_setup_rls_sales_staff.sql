-- Migration: Setup Row Level Security (RLS) - Sales Staff Policies
-- Created: 2025-07-16
-- Description: Thiết lập RLS policies cho Sales Staff role - xử lý orders và customer management

-- =============================================================================
-- HELPER FUNCTIONS FOR SALES STAFF
-- =============================================================================

-- Function to check if current user is Sales Staff
CREATE OR REPLACE FUNCTION public.is_sales_staff()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN public.has_role('sales_staff');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if an order is assigned to current sales staff
CREATE OR REPLACE FUNCTION public.is_assigned_to_me(order_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.orders o
    WHERE o.id = order_id
    AND o.assigned_staff_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if an order belongs to current user's company customers
CREATE OR REPLACE FUNCTION public.order_in_company(order_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  current_company_id UUID;
BEGIN
  -- Get current user's company
  SELECT public.get_user_company_id() INTO current_company_id;
  
  -- Check if order customer is in same company or order is assigned to current user
  RETURN EXISTS (
    SELECT 1 
    FROM public.orders o
    LEFT JOIN public.company_profiles cp ON o.customer_id = cp.user_id
    WHERE o.id = order_id
    AND (
      cp.id = current_company_id -- Customer from same company
      OR o.assigned_staff_id = auth.uid() -- Assigned to current user
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- SALES STAFF RLS POLICIES
-- =============================================================================

-- PROFILES TABLE - Can view customer profiles and own profile
CREATE POLICY "sales_staff_profiles_select" ON public.profiles
  FOR SELECT USING (
    public.is_sales_staff() 
    AND (
      id = auth.uid() -- Own profile
      OR user_type IN ('B2C', 'B2B') -- Customer profiles
    )
  );

CREATE POLICY "sales_staff_profiles_update" ON public.profiles
  FOR UPDATE USING (
    public.is_sales_staff() 
    AND id = auth.uid() -- Only own profile
  );

-- COMPANY_PROFILES TABLE - Can view all company profiles (for customer management)
CREATE POLICY "sales_staff_company_profiles_select" ON public.company_profiles
  FOR SELECT USING (public.is_sales_staff());

CREATE POLICY "sales_staff_company_profiles_update" ON public.company_profiles
  FOR UPDATE USING (
    public.is_sales_staff() 
    AND user_id = auth.uid() -- Only if they own the company profile
  );

-- ROLES TABLE - Can view roles (read-only)
CREATE POLICY "sales_staff_roles_select" ON public.roles
  FOR SELECT USING (public.is_sales_staff());

-- CATEGORIES TABLE - Can view categories (read-only)
CREATE POLICY "sales_staff_categories_select" ON public.categories
  FOR SELECT USING (public.is_sales_staff());

-- PRODUCTS TABLE - Can view all products (read-only)
CREATE POLICY "sales_staff_products_select" ON public.products
  FOR SELECT USING (public.is_sales_staff());

-- PRODUCT_VARIANTS TABLE - Can view all product variants (read-only)
CREATE POLICY "sales_staff_product_variants_select" ON public.product_variants
  FOR SELECT USING (public.is_sales_staff());

-- PRODUCT_IMAGES TABLE - Can view all product images (read-only)
CREATE POLICY "sales_staff_product_images_select" ON public.product_images
  FOR SELECT USING (public.is_sales_staff());

-- PRODUCT_CATEGORIES TABLE - Can view all product categorizations (read-only)
CREATE POLICY "sales_staff_product_categories_select" ON public.product_categories
  FOR SELECT USING (public.is_sales_staff());

-- WAREHOUSES TABLE - Can view warehouse information (read-only)
CREATE POLICY "sales_staff_warehouses_select" ON public.warehouses
  FOR SELECT USING (public.is_sales_staff());

-- INVENTORY_ITEMS TABLE - Can view inventory (read-only)
CREATE POLICY "sales_staff_inventory_items_select" ON public.inventory_items
  FOR SELECT USING (public.is_sales_staff());

-- STOCK_ALERTS TABLE - Can view stock alerts (read-only)
CREATE POLICY "sales_staff_stock_alerts_select" ON public.stock_alerts
  FOR SELECT USING (public.is_sales_staff());

-- ORDERS TABLE - Can view assigned orders and create new orders
CREATE POLICY "sales_staff_orders_select" ON public.orders
  FOR SELECT USING (
    public.is_sales_staff() 
    AND (
      assigned_staff_id = auth.uid() -- Assigned orders
      OR public.order_in_company(id) -- Orders from company customers
    )
  );

CREATE POLICY "sales_staff_orders_insert" ON public.orders
  FOR INSERT WITH CHECK (
    public.is_sales_staff() 
    AND (
      assigned_staff_id = auth.uid() -- Assign to self
      OR assigned_staff_id IS NULL -- Or no assignment yet
    )
  );

CREATE POLICY "sales_staff_orders_update" ON public.orders
  FOR UPDATE USING (
    public.is_sales_staff() 
    AND (
      assigned_staff_id = auth.uid() -- Assigned orders
      OR public.order_in_company(id) -- Orders from company customers
    )
  );

-- ORDER_ITEMS TABLE - Can view/manage items for accessible orders
CREATE POLICY "sales_staff_order_items_select" ON public.order_items
  FOR SELECT USING (
    public.is_sales_staff() 
    AND public.order_in_company(order_id)
  );

CREATE POLICY "sales_staff_order_items_insert" ON public.order_items
  FOR INSERT WITH CHECK (
    public.is_sales_staff() 
    AND public.order_in_company(order_id)
  );

CREATE POLICY "sales_staff_order_items_update" ON public.order_items
  FOR UPDATE USING (
    public.is_sales_staff() 
    AND public.order_in_company(order_id)
  );

CREATE POLICY "sales_staff_order_items_delete" ON public.order_items
  FOR DELETE USING (
    public.is_sales_staff() 
    AND public.order_in_company(order_id)
  );

-- ORDER_STATUS_HISTORY TABLE - Can view history and add updates
CREATE POLICY "sales_staff_order_status_history_select" ON public.order_status_history
  FOR SELECT USING (
    public.is_sales_staff() 
    AND public.order_in_company(order_id)
  );

CREATE POLICY "sales_staff_order_status_history_insert" ON public.order_status_history
  FOR INSERT WITH CHECK (
    public.is_sales_staff() 
    AND public.order_in_company(order_id)
    AND changed_by = auth.uid()
  );

-- SHIPPING_DETAILS TABLE - Can manage shipping for accessible orders
CREATE POLICY "sales_staff_shipping_details_select" ON public.shipping_details
  FOR SELECT USING (
    public.is_sales_staff() 
    AND public.order_in_company(order_id)
  );

CREATE POLICY "sales_staff_shipping_details_insert" ON public.shipping_details
  FOR INSERT WITH CHECK (
    public.is_sales_staff() 
    AND public.order_in_company(order_id)
  );

CREATE POLICY "sales_staff_shipping_details_update" ON public.shipping_details
  FOR UPDATE USING (
    public.is_sales_staff() 
    AND public.order_in_company(order_id)
  );

-- PAYMENTS TABLE - Can view payments for accessible orders (read-only)
CREATE POLICY "sales_staff_payments_select" ON public.payments
  FOR SELECT USING (
    public.is_sales_staff() 
    AND public.order_in_company(order_id)
  );

-- PRICE_LISTS TABLE - Can view price lists (read-only)
CREATE POLICY "sales_staff_price_lists_select" ON public.price_lists
  FOR SELECT USING (public.is_sales_staff());

-- CUSTOMER_PRICE_ASSIGNMENTS TABLE - Can view customer pricing (read-only)
CREATE POLICY "sales_staff_customer_price_assignments_select" ON public.customer_price_assignments
  FOR SELECT USING (public.is_sales_staff());

-- DISCOUNTS TABLE - Can view discounts (read-only)
CREATE POLICY "sales_staff_discounts_select" ON public.discounts
  FOR SELECT USING (public.is_sales_staff());

-- CUSTOMER_DISCOUNTS TABLE - Can view and assign customer discounts
CREATE POLICY "sales_staff_customer_discounts_select" ON public.customer_discounts
  FOR SELECT USING (public.is_sales_staff());

CREATE POLICY "sales_staff_customer_discounts_insert" ON public.customer_discounts
  FOR INSERT WITH CHECK (
    public.is_sales_staff() 
    AND assigned_by = auth.uid()
  );

-- LOCATIONS TABLE - Can view locations (read-only)
CREATE POLICY "sales_staff_locations_select" ON public.locations
  FOR SELECT USING (public.is_sales_staff());

-- NURSERIES TABLE - Can view nursery information (read-only)
CREATE POLICY "sales_staff_nurseries_select" ON public.nurseries
  FOR SELECT USING (public.is_sales_staff());

-- DELIVERY_ZONES TABLE - Can view delivery zones (read-only)
CREATE POLICY "sales_staff_delivery_zones_select" ON public.delivery_zones
  FOR SELECT USING (public.is_sales_staff());

-- SEASONAL_AVAILABILITY TABLE - Can view seasonal availability (read-only)
CREATE POLICY "sales_staff_seasonal_availability_select" ON public.seasonal_availability
  FOR SELECT USING (public.is_sales_staff());

-- PROMOTIONS TABLE - Can view promotions (read-only)
CREATE POLICY "sales_staff_promotions_select" ON public.promotions
  FOR SELECT USING (public.is_sales_staff());

-- CUSTOMER_GROUPS TABLE - Can view customer groups (read-only)
CREATE POLICY "sales_staff_customer_groups_select" ON public.customer_groups
  FOR SELECT USING (public.is_sales_staff());

-- CUSTOMER_GROUP_MEMBERS TABLE - Can view and manage customer group memberships
CREATE POLICY "sales_staff_customer_group_members_select" ON public.customer_group_members
  FOR SELECT USING (public.is_sales_staff());

CREATE POLICY "sales_staff_customer_group_members_insert" ON public.customer_group_members
  FOR INSERT WITH CHECK (
    public.is_sales_staff() 
    AND added_by = auth.uid()
  );

CREATE POLICY "sales_staff_customer_group_members_update" ON public.customer_group_members
  FOR UPDATE USING (public.is_sales_staff());

-- NOTIFICATION_PREFERENCES TABLE - Can view own preferences
CREATE POLICY "sales_staff_notification_preferences_select" ON public.notification_preferences
  FOR SELECT USING (
    public.is_sales_staff() 
    AND user_id = auth.uid()
  );

CREATE POLICY "sales_staff_notification_preferences_update" ON public.notification_preferences
  FOR UPDATE USING (
    public.is_sales_staff() 
    AND user_id = auth.uid()
  );

-- NOTIFICATIONS TABLE - Can view own notifications and send to customers
CREATE POLICY "sales_staff_notifications_select" ON public.notifications
  FOR SELECT USING (
    public.is_sales_staff() 
    AND (
      user_id = auth.uid() -- Own notifications
      OR created_by = auth.uid() -- Notifications they created
    )
  );

CREATE POLICY "sales_staff_notifications_insert" ON public.notifications
  FOR INSERT WITH CHECK (
    public.is_sales_staff() 
    AND created_by = auth.uid()
  );

-- AUDIT_LOGS TABLE - Can view logs related to their actions
CREATE POLICY "sales_staff_audit_logs_select" ON public.audit_logs
  FOR SELECT USING (
    public.is_sales_staff() 
    AND user_id = auth.uid()
  );

-- =============================================================================
-- GRANT EXECUTE PERMISSIONS ON NEW FUNCTIONS
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.is_sales_staff() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_assigned_to_me(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.order_in_company(UUID) TO authenticated;

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON FUNCTION public.is_sales_staff() IS 'Check if current user is Sales Staff';
COMMENT ON FUNCTION public.is_assigned_to_me(UUID) IS 'Check if order is assigned to current sales staff';
COMMENT ON FUNCTION public.order_in_company(UUID) IS 'Check if order belongs to current user company customers';