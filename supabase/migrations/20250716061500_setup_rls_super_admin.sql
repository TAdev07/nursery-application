-- Migration: Setup Row Level Security (RLS) - Super Admin Policies
-- Created: 2025-07-16
-- Description: Thiết lập RLS policies cho Super Admin role với full access

-- =============================================================================
-- ENABLE RLS ON ALL TABLES
-- =============================================================================

-- Core tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Product catalog tables
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;

-- Inventory tables
ALTER TABLE public.warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_alerts ENABLE ROW LEVEL SECURITY;

-- Order system tables
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipping_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Supporting tables
ALTER TABLE public.price_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_price_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nurseries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.seasonal_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- HELPER FUNCTIONS FOR ROLE CHECKING
-- =============================================================================

-- Function to check if current user has a specific role
CREATE OR REPLACE FUNCTION public.has_role(role_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.user_roles ur
    JOIN public.roles r ON ur.role_id = r.id
    WHERE ur.user_id = auth.uid()
    AND r.name = role_name
    AND ur.is_active = TRUE
    AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if current user is Super Admin
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN public.has_role('super_admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get current user's company_id (for B2B users)
CREATE OR REPLACE FUNCTION public.get_user_company_id()
RETURNS UUID AS $$
BEGIN
  RETURN (
    SELECT cp.id
    FROM public.company_profiles cp
    WHERE cp.user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user is staff member
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN public.has_role('nursery_manager') 
    OR public.has_role('sales_staff') 
    OR public.has_role('nursery_worker')
    OR public.has_role('content_editor');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- INSERT SUPER ADMIN ROLE
-- =============================================================================

-- Add super_admin role if not exists
INSERT INTO public.roles (name, description, permissions, is_system_role) VALUES
('super_admin', 'Super Administrator với full access', 
 '["*:*"]'::jsonb, 
 true)
ON CONFLICT (name) DO NOTHING;

-- Add other system roles
INSERT INTO public.roles (name, description, permissions, is_system_role) VALUES
('nursery_manager', 'Nursery Manager - quản lý nhà vườn', 
 '["products:manage", "inventory:manage", "orders:manage", "staff:manage", "reports:view"]'::jsonb, 
 true),
('sales_staff', 'Sales Staff - nhân viên bán hàng', 
 '["products:view", "customers:manage", "orders:manage", "reports:view"]'::jsonb, 
 true),
('nursery_worker', 'Nursery Worker - công nhân nhà vườn', 
 '["products:view", "inventory:view", "inventory:update", "orders:view"]'::jsonb, 
 true),
('wholesale_customer', 'Wholesale Customer - khách hàng sỉ', 
 '["products:view", "orders:create", "orders:view", "profile:manage"]'::jsonb, 
 true),
('retail_customer', 'Retail Customer - khách hàng lẻ', 
 '["products:view", "orders:create", "orders:view", "profile:manage"]'::jsonb, 
 true),
('content_editor', 'Content Editor - chỉnh sửa nội dung', 
 '["products:edit", "categories:manage", "content:manage"]'::jsonb, 
 true)
ON CONFLICT (name) DO NOTHING;

-- =============================================================================
-- SUPER ADMIN RLS POLICIES - FULL ACCESS
-- =============================================================================

-- Super Admin có full access đến tất cả tables

-- PROFILES TABLE
CREATE POLICY "super_admin_profiles_all" ON public.profiles
  FOR ALL USING (public.is_super_admin());

-- COMPANY_PROFILES TABLE  
CREATE POLICY "super_admin_company_profiles_all" ON public.company_profiles
  FOR ALL USING (public.is_super_admin());

-- ROLES TABLE
CREATE POLICY "super_admin_roles_all" ON public.roles
  FOR ALL USING (public.is_super_admin());

-- USER_ROLES TABLE
CREATE POLICY "super_admin_user_roles_all" ON public.user_roles
  FOR ALL USING (public.is_super_admin());

-- CATEGORIES TABLE
CREATE POLICY "super_admin_categories_all" ON public.categories
  FOR ALL USING (public.is_super_admin());

-- PRODUCTS TABLE
CREATE POLICY "super_admin_products_all" ON public.products
  FOR ALL USING (public.is_super_admin());

-- PRODUCT_VARIANTS TABLE
CREATE POLICY "super_admin_product_variants_all" ON public.product_variants
  FOR ALL USING (public.is_super_admin());

-- PRODUCT_IMAGES TABLE
CREATE POLICY "super_admin_product_images_all" ON public.product_images
  FOR ALL USING (public.is_super_admin());

-- PRODUCT_CATEGORIES TABLE
CREATE POLICY "super_admin_product_categories_all" ON public.product_categories
  FOR ALL USING (public.is_super_admin());

-- WAREHOUSES TABLE
CREATE POLICY "super_admin_warehouses_all" ON public.warehouses
  FOR ALL USING (public.is_super_admin());

-- INVENTORY_ITEMS TABLE
CREATE POLICY "super_admin_inventory_items_all" ON public.inventory_items
  FOR ALL USING (public.is_super_admin());

-- INVENTORY_MOVEMENTS TABLE
CREATE POLICY "super_admin_inventory_movements_all" ON public.inventory_movements
  FOR ALL USING (public.is_super_admin());

-- INVENTORY_ADJUSTMENTS TABLE
CREATE POLICY "super_admin_inventory_adjustments_all" ON public.inventory_adjustments
  FOR ALL USING (public.is_super_admin());

-- STOCK_ALERTS TABLE
CREATE POLICY "super_admin_stock_alerts_all" ON public.stock_alerts
  FOR ALL USING (public.is_super_admin());

-- ORDERS TABLE
CREATE POLICY "super_admin_orders_all" ON public.orders
  FOR ALL USING (public.is_super_admin());

-- ORDER_ITEMS TABLE
CREATE POLICY "super_admin_order_items_all" ON public.order_items
  FOR ALL USING (public.is_super_admin());

-- ORDER_STATUS_HISTORY TABLE
CREATE POLICY "super_admin_order_status_history_all" ON public.order_status_history
  FOR ALL USING (public.is_super_admin());

-- SHIPPING_DETAILS TABLE
CREATE POLICY "super_admin_shipping_details_all" ON public.shipping_details
  FOR ALL USING (public.is_super_admin());

-- PAYMENTS TABLE
CREATE POLICY "super_admin_payments_all" ON public.payments
  FOR ALL USING (public.is_super_admin());

-- PRICE_LISTS TABLE
CREATE POLICY "super_admin_price_lists_all" ON public.price_lists
  FOR ALL USING (public.is_super_admin());

-- CUSTOMER_PRICE_ASSIGNMENTS TABLE
CREATE POLICY "super_admin_customer_price_assignments_all" ON public.customer_price_assignments
  FOR ALL USING (public.is_super_admin());

-- DISCOUNTS TABLE
CREATE POLICY "super_admin_discounts_all" ON public.discounts
  FOR ALL USING (public.is_super_admin());

-- CUSTOMER_DISCOUNTS TABLE
CREATE POLICY "super_admin_customer_discounts_all" ON public.customer_discounts
  FOR ALL USING (public.is_super_admin());

-- LOCATIONS TABLE
CREATE POLICY "super_admin_locations_all" ON public.locations
  FOR ALL USING (public.is_super_admin());

-- NURSERIES TABLE
CREATE POLICY "super_admin_nurseries_all" ON public.nurseries
  FOR ALL USING (public.is_super_admin());

-- DELIVERY_ZONES TABLE
CREATE POLICY "super_admin_delivery_zones_all" ON public.delivery_zones
  FOR ALL USING (public.is_super_admin());

-- SEASONAL_AVAILABILITY TABLE
CREATE POLICY "super_admin_seasonal_availability_all" ON public.seasonal_availability
  FOR ALL USING (public.is_super_admin());

-- PROMOTIONS TABLE
CREATE POLICY "super_admin_promotions_all" ON public.promotions
  FOR ALL USING (public.is_super_admin());

-- CUSTOMER_GROUPS TABLE
CREATE POLICY "super_admin_customer_groups_all" ON public.customer_groups
  FOR ALL USING (public.is_super_admin());

-- CUSTOMER_GROUP_MEMBERS TABLE
CREATE POLICY "super_admin_customer_group_members_all" ON public.customer_group_members
  FOR ALL USING (public.is_super_admin());

-- NOTIFICATION_PREFERENCES TABLE
CREATE POLICY "super_admin_notification_preferences_all" ON public.notification_preferences
  FOR ALL USING (public.is_super_admin());

-- NOTIFICATIONS TABLE
CREATE POLICY "super_admin_notifications_all" ON public.notifications
  FOR ALL USING (public.is_super_admin());

-- AUDIT_LOGS TABLE
CREATE POLICY "super_admin_audit_logs_all" ON public.audit_logs
  FOR ALL USING (public.is_super_admin());

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON FUNCTION public.has_role(TEXT) IS 'Check if current authenticated user has specific role';
COMMENT ON FUNCTION public.is_super_admin() IS 'Check if current user is Super Admin';
COMMENT ON FUNCTION public.get_user_company_id() IS 'Get company ID for current B2B user';
COMMENT ON FUNCTION public.is_staff() IS 'Check if current user is any type of staff member';

-- =============================================================================
-- GRANT EXECUTE PERMISSIONS ON FUNCTIONS
-- =============================================================================
GRANT EXECUTE ON FUNCTION public.has_role(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_company_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_staff() TO authenticated;