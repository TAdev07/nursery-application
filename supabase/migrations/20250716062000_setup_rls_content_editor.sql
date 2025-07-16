-- Migration: Setup Row Level Security (RLS) - Content Editor Policies
-- Created: 2025-07-16
-- Description: Thiết lập RLS policies cho Content Editors quản lý product information và content

-- =============================================================================
-- HELPER FUNCTIONS FOR CONTENT EDITORS
-- =============================================================================

-- Function to check if current user is Content Editor
CREATE OR REPLACE FUNCTION public.is_content_editor()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN public.has_role('content_editor');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if content editor can manage all content (company-wide)
-- Content editors usually work company-wide, not restricted to specific areas
CREATE OR REPLACE FUNCTION public.content_editor_can_manage()
RETURNS BOOLEAN AS $$
BEGIN
  -- Content editors typically have company-wide content management permissions
  -- but this can be restricted if needed for multi-tenant scenarios
  RETURN public.is_content_editor();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- CONTENT EDITOR RLS POLICIES
-- =============================================================================

-- PROFILES TABLE - Can view and update own profile only
CREATE POLICY "content_editor_profiles_select" ON public.profiles
  FOR SELECT USING (
    public.is_content_editor() 
    AND id = auth.uid()
  );

CREATE POLICY "content_editor_profiles_update" ON public.profiles
  FOR UPDATE USING (
    public.is_content_editor() 
    AND id = auth.uid()
  );

-- CATEGORIES TABLE - Full management of categories
CREATE POLICY "content_editor_categories_select" ON public.categories
  FOR SELECT USING (public.is_content_editor());

CREATE POLICY "content_editor_categories_insert" ON public.categories
  FOR INSERT WITH CHECK (
    public.is_content_editor() 
    AND created_by = auth.uid()
  );

CREATE POLICY "content_editor_categories_update" ON public.categories
  FOR UPDATE USING (public.is_content_editor());

CREATE POLICY "content_editor_categories_delete" ON public.categories
  FOR DELETE USING (public.is_content_editor());

-- PRODUCTS TABLE - Full management of products
CREATE POLICY "content_editor_products_select" ON public.products
  FOR SELECT USING (public.is_content_editor());

CREATE POLICY "content_editor_products_insert" ON public.products
  FOR INSERT WITH CHECK (
    public.is_content_editor() 
    AND created_by = auth.uid()
  );

CREATE POLICY "content_editor_products_update" ON public.products
  FOR UPDATE USING (public.is_content_editor());

CREATE POLICY "content_editor_products_delete" ON public.products
  FOR DELETE USING (public.is_content_editor());

-- PRODUCT_VARIANTS TABLE - Full management of product variants
CREATE POLICY "content_editor_product_variants_select" ON public.product_variants
  FOR SELECT USING (public.is_content_editor());

CREATE POLICY "content_editor_product_variants_insert" ON public.product_variants
  FOR INSERT WITH CHECK (
    public.is_content_editor() 
    AND created_by = auth.uid()
  );

CREATE POLICY "content_editor_product_variants_update" ON public.product_variants
  FOR UPDATE USING (public.is_content_editor());

CREATE POLICY "content_editor_product_variants_delete" ON public.product_variants
  FOR DELETE USING (public.is_content_editor());

-- PRODUCT_IMAGES TABLE - Full management of product images
CREATE POLICY "content_editor_product_images_select" ON public.product_images
  FOR SELECT USING (public.is_content_editor());

CREATE POLICY "content_editor_product_images_insert" ON public.product_images
  FOR INSERT WITH CHECK (
    public.is_content_editor() 
    AND uploaded_by = auth.uid()
  );

CREATE POLICY "content_editor_product_images_update" ON public.product_images
  FOR UPDATE USING (public.is_content_editor());

CREATE POLICY "content_editor_product_images_delete" ON public.product_images
  FOR DELETE USING (public.is_content_editor());

-- PRODUCT_CATEGORIES TABLE - Full management of product categorizations
CREATE POLICY "content_editor_product_categories_select" ON public.product_categories
  FOR SELECT USING (public.is_content_editor());

CREATE POLICY "content_editor_product_categories_insert" ON public.product_categories
  FOR INSERT WITH CHECK (public.is_content_editor());

CREATE POLICY "content_editor_product_categories_update" ON public.product_categories
  FOR UPDATE USING (public.is_content_editor());

CREATE POLICY "content_editor_product_categories_delete" ON public.product_categories
  FOR DELETE USING (public.is_content_editor());

-- WAREHOUSES TABLE - Can view warehouse information (read-only for context)
CREATE POLICY "content_editor_warehouses_select" ON public.warehouses
  FOR SELECT USING (public.is_content_editor());

-- INVENTORY_ITEMS TABLE - Can view inventory for content purposes (read-only)
CREATE POLICY "content_editor_inventory_items_select" ON public.inventory_items
  FOR SELECT USING (public.is_content_editor());

-- PRICE_LISTS TABLE - Can view price lists for content purposes (read-only)
CREATE POLICY "content_editor_price_lists_select" ON public.price_lists
  FOR SELECT USING (public.is_content_editor());

-- DISCOUNTS TABLE - Can manage discount information
CREATE POLICY "content_editor_discounts_select" ON public.discounts
  FOR SELECT USING (public.is_content_editor());

CREATE POLICY "content_editor_discounts_insert" ON public.discounts
  FOR INSERT WITH CHECK (
    public.is_content_editor() 
    AND created_by = auth.uid()
  );

CREATE POLICY "content_editor_discounts_update" ON public.discounts
  FOR UPDATE USING (public.is_content_editor());

CREATE POLICY "content_editor_discounts_delete" ON public.discounts
  FOR DELETE USING (public.is_content_editor());

-- LOCATIONS TABLE - Can view locations (read-only for content purposes)
CREATE POLICY "content_editor_locations_select" ON public.locations
  FOR SELECT USING (public.is_content_editor());

-- NURSERIES TABLE - Can view nursery information (read-only for content)
CREATE POLICY "content_editor_nurseries_select" ON public.nurseries
  FOR SELECT USING (public.is_content_editor());

-- SEASONAL_AVAILABILITY TABLE - Full management of seasonal information
CREATE POLICY "content_editor_seasonal_availability_select" ON public.seasonal_availability
  FOR SELECT USING (public.is_content_editor());

CREATE POLICY "content_editor_seasonal_availability_insert" ON public.seasonal_availability
  FOR INSERT WITH CHECK (
    public.is_content_editor() 
    AND created_by = auth.uid()
  );

CREATE POLICY "content_editor_seasonal_availability_update" ON public.seasonal_availability
  FOR UPDATE USING (
    public.is_content_editor() 
    AND updated_by = auth.uid()
  );

CREATE POLICY "content_editor_seasonal_availability_delete" ON public.seasonal_availability
  FOR DELETE USING (public.is_content_editor());

-- PROMOTIONS TABLE - Full management of promotions
CREATE POLICY "content_editor_promotions_select" ON public.promotions
  FOR SELECT USING (public.is_content_editor());

CREATE POLICY "content_editor_promotions_insert" ON public.promotions
  FOR INSERT WITH CHECK (
    public.is_content_editor() 
    AND created_by = auth.uid()
  );

CREATE POLICY "content_editor_promotions_update" ON public.promotions
  FOR UPDATE USING (public.is_content_editor());

CREATE POLICY "content_editor_promotions_delete" ON public.promotions
  FOR DELETE USING (public.is_content_editor());

-- CUSTOMER_GROUPS TABLE - Can view customer groups for targeting content (read-only)
CREATE POLICY "content_editor_customer_groups_select" ON public.customer_groups
  FOR SELECT USING (public.is_content_editor());

-- NOTIFICATION_PREFERENCES TABLE - Can manage own notification preferences
CREATE POLICY "content_editor_notification_preferences_select" ON public.notification_preferences
  FOR SELECT USING (
    public.is_content_editor() 
    AND user_id = auth.uid()
  );

CREATE POLICY "content_editor_notification_preferences_insert" ON public.notification_preferences
  FOR INSERT WITH CHECK (
    public.is_content_editor() 
    AND user_id = auth.uid()
  );

CREATE POLICY "content_editor_notification_preferences_update" ON public.notification_preferences
  FOR UPDATE USING (
    public.is_content_editor() 
    AND user_id = auth.uid()
  );

-- NOTIFICATIONS TABLE - Can view own notifications and send content-related notifications
CREATE POLICY "content_editor_notifications_select" ON public.notifications
  FOR SELECT USING (
    public.is_content_editor() 
    AND (
      user_id = auth.uid() -- Own notifications
      OR created_by = auth.uid() -- Notifications they created
    )
  );

CREATE POLICY "content_editor_notifications_insert" ON public.notifications
  FOR INSERT WITH CHECK (
    public.is_content_editor() 
    AND created_by = auth.uid()
    AND notification_type IN ('product_update', 'promotion', 'content_update') -- Content-related notifications only
  );

-- AUDIT_LOGS TABLE - Can view logs of own content-related actions
CREATE POLICY "content_editor_audit_logs_select" ON public.audit_logs
  FOR SELECT USING (
    public.is_content_editor() 
    AND user_id = auth.uid()
  );

-- =============================================================================
-- CONTENT MANAGEMENT SPECIFIC POLICIES
-- =============================================================================

-- Content editors should NOT have access to:
-- - Orders and order-related tables (business sensitive)
-- - Customer personal information (privacy)
-- - Financial information (payments, pricing assignments)
-- - Inventory management (operational)
-- - Company profiles of others (privacy)
-- - User roles (security)

-- They CAN access:
-- - Product catalog and content
-- - Categories and product organization
-- - Marketing content (promotions, seasonal info)
-- - Content-related notifications
-- - Their own profile and preferences

-- Note: These restrictions ensure content editors can do their job effectively
-- while maintaining proper data separation and security

-- =============================================================================
-- GRANT EXECUTE PERMISSIONS ON NEW FUNCTIONS
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.is_content_editor() TO authenticated;
GRANT EXECUTE ON FUNCTION public.content_editor_can_manage() TO authenticated;

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON FUNCTION public.is_content_editor() IS 'Check if current user is Content Editor';
COMMENT ON FUNCTION public.content_editor_can_manage() IS 'Check if content editor can manage content (company-wide access)';