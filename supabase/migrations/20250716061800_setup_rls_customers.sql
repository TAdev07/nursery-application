-- Migration: Setup Row Level Security (RLS) - Customer Policies (Wholesale/Retail)
-- Created: 2025-07-16
-- Description: Thiết lập RLS policies cho Wholesale và Retail customers với permissions khác nhau

-- =============================================================================
-- HELPER FUNCTIONS FOR CUSTOMERS
-- =============================================================================

-- Function to check if current user is Wholesale Customer
CREATE OR REPLACE FUNCTION public.is_wholesale_customer()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN public.has_role('wholesale_customer');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user is Retail Customer
CREATE OR REPLACE FUNCTION public.is_retail_customer()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN public.has_role('retail_customer');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user is any type of customer
CREATE OR REPLACE FUNCTION public.is_customer()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN public.is_wholesale_customer() OR public.is_retail_customer();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if an order belongs to current customer
CREATE OR REPLACE FUNCTION public.is_my_order(order_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.orders o
    WHERE o.id = order_id
    AND o.customer_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if a notification is for current user
CREATE OR REPLACE FUNCTION public.is_my_notification(notification_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.notifications n
    WHERE n.id = notification_id
    AND n.user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- CUSTOMER RLS POLICIES - SHARED BETWEEN WHOLESALE AND RETAIL
-- =============================================================================

-- PROFILES TABLE - Can view and update own profile only
CREATE POLICY "customers_profiles_select" ON public.profiles
  FOR SELECT USING (
    public.is_customer() 
    AND id = auth.uid()
  );

CREATE POLICY "customers_profiles_update" ON public.profiles
  FOR UPDATE USING (
    public.is_customer() 
    AND id = auth.uid()
  );

-- COMPANY_PROFILES TABLE - Can view and update own company profile (for B2B customers)
CREATE POLICY "customers_company_profiles_select" ON public.company_profiles
  FOR SELECT USING (
    public.is_customer() 
    AND user_id = auth.uid()
  );

CREATE POLICY "customers_company_profiles_update" ON public.company_profiles
  FOR UPDATE USING (
    public.is_customer() 
    AND user_id = auth.uid()
  );

-- CATEGORIES TABLE - Can view all categories (read-only)
CREATE POLICY "customers_categories_select" ON public.categories
  FOR SELECT USING (public.is_customer());

-- PRODUCTS TABLE - Can view available products (read-only)
CREATE POLICY "customers_products_select" ON public.products
  FOR SELECT USING (
    public.is_customer() 
    AND status = 'active'
    AND is_published = TRUE
  );

-- PRODUCT_VARIANTS TABLE - Can view available product variants (read-only)
CREATE POLICY "customers_product_variants_select" ON public.product_variants
  FOR SELECT USING (
    public.is_customer() 
    AND is_active = TRUE
  );

-- PRODUCT_IMAGES TABLE - Can view product images (read-only)
CREATE POLICY "customers_product_images_select" ON public.product_images
  FOR SELECT USING (public.is_customer());

-- PRODUCT_CATEGORIES TABLE - Can view product categorizations (read-only)
CREATE POLICY "customers_product_categories_select" ON public.product_categories
  FOR SELECT USING (public.is_customer());

-- INVENTORY_ITEMS TABLE - Can view available stock (read-only)
CREATE POLICY "customers_inventory_items_select" ON public.inventory_items
  FOR SELECT USING (
    public.is_customer() 
    AND available_quantity > 0
  );

-- ORDERS TABLE - Can view and manage own orders only
CREATE POLICY "customers_orders_select" ON public.orders
  FOR SELECT USING (
    public.is_customer() 
    AND customer_id = auth.uid()
  );

CREATE POLICY "customers_orders_insert" ON public.orders
  FOR INSERT WITH CHECK (
    public.is_customer() 
    AND customer_id = auth.uid()
  );

CREATE POLICY "customers_orders_update" ON public.orders
  FOR UPDATE USING (
    public.is_customer() 
    AND customer_id = auth.uid()
    AND status IN ('draft', 'pending') -- Can only update orders that aren't confirmed
  );

-- ORDER_ITEMS TABLE - Can manage items for own orders
CREATE POLICY "customers_order_items_select" ON public.order_items
  FOR SELECT USING (
    public.is_customer() 
    AND public.is_my_order(order_id)
  );

CREATE POLICY "customers_order_items_insert" ON public.order_items
  FOR INSERT WITH CHECK (
    public.is_customer() 
    AND public.is_my_order(order_id)
  );

CREATE POLICY "customers_order_items_update" ON public.order_items
  FOR UPDATE USING (
    public.is_customer() 
    AND public.is_my_order(order_id)
  );

CREATE POLICY "customers_order_items_delete" ON public.order_items
  FOR DELETE USING (
    public.is_customer() 
    AND public.is_my_order(order_id)
  );

-- ORDER_STATUS_HISTORY TABLE - Can view history for own orders (read-only)
CREATE POLICY "customers_order_status_history_select" ON public.order_status_history
  FOR SELECT USING (
    public.is_customer() 
    AND public.is_my_order(order_id)
  );

-- SHIPPING_DETAILS TABLE - Can view shipping info for own orders
CREATE POLICY "customers_shipping_details_select" ON public.shipping_details
  FOR SELECT USING (
    public.is_customer() 
    AND public.is_my_order(order_id)
  );

CREATE POLICY "customers_shipping_details_update" ON public.shipping_details
  FOR UPDATE USING (
    public.is_customer() 
    AND public.is_my_order(order_id)
  );

-- PAYMENTS TABLE - Can view payments for own orders (read-only)
CREATE POLICY "customers_payments_select" ON public.payments
  FOR SELECT USING (
    public.is_customer() 
    AND public.is_my_order(order_id)
  );

-- =============================================================================
-- WHOLESALE CUSTOMER SPECIFIC POLICIES
-- =============================================================================

-- PRICE_LISTS TABLE - Wholesale customers can view wholesale price lists
CREATE POLICY "wholesale_customers_price_lists_select" ON public.price_lists
  FOR SELECT USING (
    public.is_wholesale_customer() 
    AND customer_type = 'wholesale'
  );

-- CUSTOMER_PRICE_ASSIGNMENTS TABLE - Can view own price assignments
CREATE POLICY "wholesale_customers_price_assignments_select" ON public.customer_price_assignments
  FOR SELECT USING (
    public.is_wholesale_customer() 
    AND customer_id = auth.uid()
  );

-- DISCOUNTS TABLE - Can view wholesale discounts
CREATE POLICY "wholesale_customers_discounts_select" ON public.discounts
  FOR SELECT USING (
    public.is_wholesale_customer() 
    AND customer_type = 'wholesale'
    AND is_active = TRUE
    AND (start_date IS NULL OR start_date <= NOW())
    AND (end_date IS NULL OR end_date >= NOW())
  );

-- CUSTOMER_DISCOUNTS TABLE - Can view own discount assignments
CREATE POLICY "wholesale_customers_customer_discounts_select" ON public.customer_discounts
  FOR SELECT USING (
    public.is_wholesale_customer() 
    AND customer_id = auth.uid()
    AND is_active = TRUE
    AND (expires_at IS NULL OR expires_at >= NOW())
  );

-- =============================================================================
-- RETAIL CUSTOMER SPECIFIC POLICIES
-- =============================================================================

-- PRICE_LISTS TABLE - Retail customers can view retail price lists
CREATE POLICY "retail_customers_price_lists_select" ON public.price_lists
  FOR SELECT USING (
    public.is_retail_customer() 
    AND customer_type = 'retail'
  );

-- DISCOUNTS TABLE - Can view retail discounts
CREATE POLICY "retail_customers_discounts_select" ON public.discounts
  FOR SELECT USING (
    public.is_retail_customer() 
    AND customer_type = 'retail'
    AND is_active = TRUE
    AND (start_date IS NULL OR start_date <= NOW())
    AND (end_date IS NULL OR end_date >= NOW())
  );

-- CUSTOMER_DISCOUNTS TABLE - Can view own discount assignments
CREATE POLICY "retail_customers_customer_discounts_select" ON public.customer_discounts
  FOR SELECT USING (
    public.is_retail_customer() 
    AND customer_id = auth.uid()
    AND is_active = TRUE
    AND (expires_at IS NULL OR expires_at >= NOW())
  );

-- =============================================================================
-- SHARED CUSTOMER POLICIES (CONTINUED)
-- =============================================================================

-- LOCATIONS TABLE - Can view delivery locations (read-only)
CREATE POLICY "customers_locations_select" ON public.locations
  FOR SELECT USING (public.is_customer());

-- DELIVERY_ZONES TABLE - Can view delivery zones for order planning (read-only)
CREATE POLICY "customers_delivery_zones_select" ON public.delivery_zones
  FOR SELECT USING (
    public.is_customer() 
    AND is_active = TRUE
  );

-- SEASONAL_AVAILABILITY TABLE - Can view seasonal availability (read-only)
CREATE POLICY "customers_seasonal_availability_select" ON public.seasonal_availability
  FOR SELECT USING (
    public.is_customer() 
    AND is_active = TRUE
  );

-- PROMOTIONS TABLE - Can view active promotions
CREATE POLICY "customers_promotions_select" ON public.promotions
  FOR SELECT USING (
    public.is_customer() 
    AND is_active = TRUE
    AND (start_date IS NULL OR start_date <= NOW())
    AND (end_date IS NULL OR end_date >= NOW())
  );

-- CUSTOMER_GROUPS TABLE - Can view groups they belong to (read-only)
CREATE POLICY "customers_customer_groups_select" ON public.customer_groups
  FOR SELECT USING (
    public.is_customer() 
    AND EXISTS (
      SELECT 1 FROM public.customer_group_members cgm 
      WHERE cgm.group_id = id 
      AND cgm.customer_id = auth.uid()
      AND cgm.is_active = TRUE
    )
  );

-- CUSTOMER_GROUP_MEMBERS TABLE - Can view own group memberships (read-only)
CREATE POLICY "customers_customer_group_members_select" ON public.customer_group_members
  FOR SELECT USING (
    public.is_customer() 
    AND customer_id = auth.uid()
  );

-- NOTIFICATION_PREFERENCES TABLE - Can manage own notification preferences
CREATE POLICY "customers_notification_preferences_select" ON public.notification_preferences
  FOR SELECT USING (
    public.is_customer() 
    AND user_id = auth.uid()
  );

CREATE POLICY "customers_notification_preferences_insert" ON public.notification_preferences
  FOR INSERT WITH CHECK (
    public.is_customer() 
    AND user_id = auth.uid()
  );

CREATE POLICY "customers_notification_preferences_update" ON public.notification_preferences
  FOR UPDATE USING (
    public.is_customer() 
    AND user_id = auth.uid()
  );

-- NOTIFICATIONS TABLE - Can view own notifications
CREATE POLICY "customers_notifications_select" ON public.notifications
  FOR SELECT USING (
    public.is_customer() 
    AND user_id = auth.uid()
  );

-- =============================================================================
-- GRANT EXECUTE PERMISSIONS ON NEW FUNCTIONS
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.is_wholesale_customer() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_retail_customer() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_customer() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_my_order(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_my_notification(UUID) TO authenticated;

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON FUNCTION public.is_wholesale_customer() IS 'Check if current user is Wholesale Customer';
COMMENT ON FUNCTION public.is_retail_customer() IS 'Check if current user is Retail Customer';
COMMENT ON FUNCTION public.is_customer() IS 'Check if current user is any type of customer';
COMMENT ON FUNCTION public.is_my_order(UUID) IS 'Check if order belongs to current customer';
COMMENT ON FUNCTION public.is_my_notification(UUID) IS 'Check if notification is for current customer';