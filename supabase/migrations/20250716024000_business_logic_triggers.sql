-- Migration: Business logic triggers and automation
-- Created: 2025-07-16
-- Description: Set up automated business logic triggers for inventory, orders, notifications, and audit logging

-- =============================================================================
-- INVENTORY AUTOMATION TRIGGERS
-- =============================================================================

-- Function to auto-allocate inventory when order items are created
CREATE OR REPLACE FUNCTION public.auto_allocate_inventory()
RETURNS TRIGGER AS $$
DECLARE
  available_stock INTEGER;
  allocation_location UUID;
  allocated_quantity INTEGER;
BEGIN
  -- Only allocate for new order items in confirmed orders
  IF TG_OP = 'INSERT' THEN
    -- Check if the order is confirmed
    IF EXISTS (SELECT 1 FROM public.orders WHERE id = NEW.order_id AND status = 'confirmed') THEN
      -- Find available stock and best location to allocate from
      SELECT 
        ist.location_id,
        LEAST(NEW.quantity, ist.quantity_sellable) as alloc_qty
      INTO allocation_location, allocated_quantity
      FROM public.inventory_stock ist
      JOIN public.inventory_locations il ON ist.location_id = il.id
      WHERE ist.product_variant_id = NEW.product_variant_id
        AND ist.quantity_sellable >= 1
        AND il.is_sellable = TRUE
      ORDER BY il.priority_order, ist.quantity_sellable DESC
      LIMIT 1;
      
      -- If we found available stock, allocate it
      IF allocation_location IS NOT NULL AND allocated_quantity > 0 THEN
        -- Update the order item with allocation info
        UPDATE public.order_items
        SET allocated_from_location_id = allocation_location,
            allocated_at = NOW(),
            fulfillment_status = CASE 
              WHEN allocated_quantity >= NEW.quantity THEN 'allocated'
              ELSE 'partially_allocated'
            END
        WHERE id = NEW.id;
        
        -- Create stock movement for allocation
        INSERT INTO public.stock_movements (
          product_variant_id, location_id, movement_type, quantity_change,
          quantity_before, quantity_after, reference_type, reference_id,
          user_id, notes, system_generated
        )
        VALUES (
          NEW.product_variant_id, allocation_location, 'allocation', -allocated_quantity,
          (SELECT quantity_available FROM public.inventory_stock WHERE product_variant_id = NEW.product_variant_id AND location_id = allocation_location),
          (SELECT quantity_available FROM public.inventory_stock WHERE product_variant_id = NEW.product_variant_id AND location_id = allocation_location) - allocated_quantity,
          'order_item', NEW.id, NULL, 
          'Auto-allocated for order item', TRUE
        );
        
        -- Send low stock notification if needed
        PERFORM public.check_and_send_low_stock_alert(NEW.product_variant_id, allocation_location);
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto inventory allocation
CREATE TRIGGER auto_allocate_inventory_trigger
  AFTER INSERT ON public.order_items
  FOR EACH ROW EXECUTE FUNCTION public.auto_allocate_inventory();

-- Function to check and send low stock alerts
CREATE OR REPLACE FUNCTION public.check_and_send_low_stock_alert(
  variant_id UUID,
  location_id UUID
)
RETURNS VOID AS $$
DECLARE
  stock_record RECORD;
  product_info RECORD;
BEGIN
  -- Get current stock information
  SELECT ist.*, il.name as location_name
  INTO stock_record
  FROM public.inventory_stock ist
  JOIN public.inventory_locations il ON ist.location_id = il.id
  WHERE ist.product_variant_id = variant_id
    AND ist.location_id = location_id;
    
  -- Get product information
  SELECT p.name, pv.variant_name, pv.sku
  INTO product_info
  FROM public.product_variants pv
  JOIN public.products p ON pv.product_id = p.id
  WHERE pv.id = variant_id;
  
  -- Check if we need to send low stock alert
  IF stock_record.quantity_available <= stock_record.reorder_point 
     AND stock_record.reorder_point > 0 
     AND NOT stock_record.low_stock_alert_sent THEN
    
    -- Create notification for inventory managers
    INSERT INTO public.notifications (
      role_id, title, message, notification_type, priority,
      entity_type, entity_id, data
    )
    SELECT 
      r.id,
      'Low Stock Alert: ' || product_info.name,
      format('Product %s (%s) at %s is running low. Current stock: %s, Reorder point: %s',
        product_info.name, product_info.sku, stock_record.location_name,
        stock_record.quantity_available, stock_record.reorder_point),
      'inventory',
      'high',
      'inventory_stock',
      stock_record.id,
      jsonb_build_object(
        'product_name', product_info.name,
        'sku', product_info.sku,
        'variant_name', product_info.variant_name,
        'location_name', stock_record.location_name,
        'current_stock', stock_record.quantity_available,
        'reorder_point', stock_record.reorder_point
      )
    FROM public.roles r
    WHERE r.name IN ('admin', 'staff')
      AND r.is_active = TRUE;
    
    -- Mark alert as sent
    UPDATE public.inventory_stock
    SET low_stock_alert_sent = TRUE
    WHERE id = stock_record.id;
  END IF;
  
  -- Check for out of stock
  IF stock_record.quantity_available = 0 AND NOT stock_record.out_of_stock_alert_sent THEN
    INSERT INTO public.notifications (
      role_id, title, message, notification_type, priority,
      entity_type, entity_id, data
    )
    SELECT 
      r.id,
      'Out of Stock: ' || product_info.name,
      format('Product %s (%s) at %s is out of stock!',
        product_info.name, product_info.sku, stock_record.location_name),
      'inventory',
      'urgent',
      'inventory_stock',
      stock_record.id,
      jsonb_build_object(
        'product_name', product_info.name,
        'sku', product_info.sku,
        'variant_name', product_info.variant_name,
        'location_name', stock_record.location_name,
        'current_stock', 0
      )
    FROM public.roles r
    WHERE r.name IN ('admin', 'staff')
      AND r.is_active = TRUE;
    
    UPDATE public.inventory_stock
    SET out_of_stock_alert_sent = TRUE
    WHERE id = stock_record.id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- ORDER AUTOMATION TRIGGERS
-- =============================================================================

-- Function to automatically update order status based on item fulfillment
CREATE OR REPLACE FUNCTION public.update_order_fulfillment_status()
RETURNS TRIGGER AS $$
DECLARE
  order_record RECORD;
  total_items INTEGER;
  allocated_items INTEGER;
  shipped_items INTEGER;
  delivered_items INTEGER;
BEGIN
  -- Get order fulfillment statistics
  SELECT 
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE fulfillment_status IN ('allocated', 'picked', 'packed')) as allocated,
    COUNT(*) FILTER (WHERE fulfillment_status = 'shipped') as shipped,
    COUNT(*) FILTER (WHERE fulfillment_status = 'delivered') as delivered
  INTO total_items, allocated_items, shipped_items, delivered_items
  FROM public.order_items
  WHERE order_id = COALESCE(NEW.order_id, OLD.order_id);
  
  -- Update order fulfillment status based on item statuses
  UPDATE public.orders
  SET fulfillment_status = CASE
    WHEN delivered_items = total_items THEN 'delivered'
    WHEN shipped_items > 0 AND shipped_items = total_items THEN 'shipped'
    WHEN shipped_items > 0 THEN 'partially_shipped'
    WHEN allocated_items > 0 THEN 'processing'
    ELSE 'pending'
  END,
  updated_at = NOW()
  WHERE id = COALESCE(NEW.order_id, OLD.order_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger for order fulfillment status updates
CREATE TRIGGER update_order_fulfillment_status_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.order_items
  FOR EACH ROW EXECUTE FUNCTION public.update_order_fulfillment_status();

-- Function to send order notifications
CREATE OR REPLACE FUNCTION public.send_order_notifications()
RETURNS TRIGGER AS $$
DECLARE
  customer_info RECORD;
  order_info RECORD;
BEGIN
  -- Only process status changes
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    -- Get customer and order information
    SELECT 
      p.first_name || ' ' || p.last_name as customer_name,
      p.email,
      p.id as user_id
    INTO customer_info
    FROM public.profiles p
    WHERE p.id = NEW.user_id;
    
    -- Get order details
    SELECT 
      NEW.order_number,
      NEW.total_amount,
      (SELECT value::text FROM public.system_settings WHERE category = 'general' AND key = 'currency') as currency
    INTO order_info;
    
    -- Send appropriate notification based on status
    CASE NEW.status
      WHEN 'confirmed' THEN
        INSERT INTO public.notifications (
          user_id, title, message, notification_type, priority,
          entity_type, entity_id, data, action_url
        )
        VALUES (
          customer_info.user_id,
          'Order Confirmed - ' || order_info.order_number,
          'Your order has been confirmed and is being processed.',
          'order',
          'normal',
          'order',
          NEW.id,
          jsonb_build_object(
            'order_number', order_info.order_number,
            'total_amount', NEW.total_amount,
            'currency', order_info.currency,
            'customer_name', customer_info.customer_name
          ),
          '/orders/' || NEW.id
        );
        
      WHEN 'shipped' THEN
        INSERT INTO public.notifications (
          user_id, title, message, notification_type, priority,
          entity_type, entity_id, data, action_url
        )
        VALUES (
          customer_info.user_id,
          'Order Shipped - ' || order_info.order_number,
          'Your order has been shipped and is on its way!',
          'order',
          'normal',
          'order',
          NEW.id,
          jsonb_build_object(
            'order_number', order_info.order_number,
            'tracking_info', 'Available soon'
          ),
          '/orders/' || NEW.id
        );
        
      WHEN 'delivered' THEN
        INSERT INTO public.notifications (
          user_id, title, message, notification_type, priority,
          entity_type, entity_id, data, action_url
        )
        VALUES (
          customer_info.user_id,
          'Order Delivered - ' || order_info.order_number,
          'Your order has been delivered successfully!',
          'order',
          'success',
          'order',
          NEW.id,
          jsonb_build_object(
            'order_number', order_info.order_number
          ),
          '/orders/' || NEW.id
        );
        
      WHEN 'cancelled' THEN
        INSERT INTO public.notifications (
          user_id, title, message, notification_type, priority,
          entity_type, entity_id, data, action_url
        )
        VALUES (
          customer_info.user_id,
          'Order Cancelled - ' || order_info.order_number,
          'Your order has been cancelled. If you have any questions, please contact us.',
          'order',
          'warning',
          'order',
          NEW.id,
          jsonb_build_object(
            'order_number', order_info.order_number
          ),
          '/orders/' || NEW.id
        );
    END CASE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for order notifications
CREATE TRIGGER send_order_notifications_trigger
  AFTER UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.send_order_notifications();

-- =============================================================================
-- AUTOMATIC TIMESTAMP UPDATES
-- =============================================================================

-- Function to automatically update the 'updated_at' timestamp
-- (We already have this but let's ensure it's consistently applied)
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers to all relevant tables that don't already have them
DO $$
DECLARE
  table_name TEXT;
  tables_to_update TEXT[] := ARRAY[
    'user_roles',
    'pricing_tiers', 
    'payment_transactions',
    'discount_codes',
    'discount_code_usage'
  ];
BEGIN
  FOREACH table_name IN ARRAY tables_to_update
  LOOP
    -- Check if trigger already exists
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger 
      WHERE tgname = 'update_' || table_name || '_updated_at'
    ) THEN
      EXECUTE format('
        CREATE TRIGGER update_%I_updated_at
          BEFORE UPDATE ON public.%I
          FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
      ', table_name, table_name);
    END IF;
  END LOOP;
END $$;

-- =============================================================================
-- AUDIT LOGGING TRIGGERS
-- =============================================================================

-- Function to create audit logs for important table changes
CREATE OR REPLACE FUNCTION public.create_audit_log_trigger()
RETURNS TRIGGER AS $$
DECLARE
  old_data JSONB;
  new_data JSONB;
  excluded_columns TEXT[] := ARRAY['updated_at', 'last_movement_at'];
BEGIN
  -- Prepare old and new data, excluding certain columns
  IF TG_OP = 'DELETE' THEN
    old_data := to_jsonb(OLD);
    new_data := NULL;
  ELSIF TG_OP = 'INSERT' THEN
    old_data := NULL;
    new_data := to_jsonb(NEW);
  ELSE -- UPDATE
    old_data := to_jsonb(OLD);
    new_data := to_jsonb(NEW);
  END IF;
  
  -- Remove excluded columns
  IF old_data IS NOT NULL THEN
    SELECT jsonb_object_agg(key, value)
    INTO old_data
    FROM jsonb_each(old_data)
    WHERE key != ALL(excluded_columns);
  END IF;
  
  IF new_data IS NOT NULL THEN
    SELECT jsonb_object_agg(key, value)
    INTO new_data
    FROM jsonb_each(new_data)
    WHERE key != ALL(excluded_columns);
  END IF;
  
  -- Only create audit log if there are actual changes (for updates)
  IF TG_OP = 'UPDATE' AND old_data = new_data THEN
    RETURN NEW;
  END IF;
  
  -- Create audit log entry
  INSERT INTO public.audit_logs (
    event_type,
    table_name,
    record_id,
    old_values,
    new_values,
    user_id,
    description
  )
  VALUES (
    LOWER(TG_OP),
    TG_TABLE_NAME,
    CASE 
      WHEN TG_OP = 'DELETE' THEN (old_data->>'id')::UUID
      ELSE (new_data->>'id')::UUID
    END,
    old_data,
    new_data,
    auth.uid(),
    format('%s operation on %s', TG_OP, TG_TABLE_NAME)
  );
  
  RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

-- Apply audit triggers to important tables
DO $$
DECLARE
  table_name TEXT;
  audit_tables TEXT[] := ARRAY[
    'profiles',
    'company_profiles',
    'roles',
    'user_roles',
    'products',
    'product_variants',
    'inventory_stock',
    'orders',
    'order_items',
    'payment_transactions',
    'system_settings'
  ];
BEGIN
  FOREACH table_name IN ARRAY audit_tables
  LOOP
    -- Drop existing audit trigger if it exists
    EXECUTE format('DROP TRIGGER IF EXISTS audit_%I_trigger ON public.%I', table_name, table_name);
    
    -- Create new audit trigger
    EXECUTE format('
      CREATE TRIGGER audit_%I_trigger
        AFTER INSERT OR UPDATE OR DELETE ON public.%I
        FOR EACH ROW EXECUTE FUNCTION public.create_audit_log_trigger();
    ', table_name, table_name);
  END LOOP;
END $$;

-- =============================================================================
-- USER ACTIVITY TRACKING TRIGGERS
-- =============================================================================

-- Function to track user login activity
CREATE OR REPLACE FUNCTION public.track_user_login()
RETURNS TRIGGER AS $$
BEGIN
  -- Track login activity when last_sign_in_at is updated
  IF OLD.last_sign_in_at IS DISTINCT FROM NEW.last_sign_in_at 
     AND NEW.last_sign_in_at IS NOT NULL THEN
    
    INSERT INTO public.activity_logs (
      user_id, activity_type, activity_name, 
      metadata, ip_address
    )
    SELECT 
      p.id,
      'login',
      'User Login',
      jsonb_build_object(
        'email', NEW.email,
        'login_time', NEW.last_sign_in_at
      ),
      NULL -- IP would need to be passed from application
    FROM public.profiles p
    WHERE p.id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: This would typically be applied to auth.users table, but we'll track it at profile level
CREATE TRIGGER track_user_activity_trigger
  AFTER UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.track_user_login();

-- =============================================================================
-- BUSINESS RULE VALIDATION TRIGGERS
-- =============================================================================

-- Function to validate order business rules
CREATE OR REPLACE FUNCTION public.validate_order_business_rules()
RETURNS TRIGGER AS $$
DECLARE
  customer_profile RECORD;
  company_profile RECORD;
BEGIN
  -- Get customer information
  SELECT * INTO customer_profile
  FROM public.profiles
  WHERE id = NEW.user_id;
  
  -- Get company information if B2B order
  IF NEW.company_id IS NOT NULL THEN
    SELECT * INTO company_profile
    FROM public.company_profiles
    WHERE id = NEW.company_id;
    
    -- Validate B2B business rules
    IF company_profile.approval_status != 'approved' THEN
      RAISE EXCEPTION 'Không thể tạo đơn hàng: Công ty chưa được phê duyệt cho mua sắm B2B';
    END IF;
    
    -- Check credit limit for B2B customers
    IF NEW.total_amount > company_profile.credit_limit THEN
      RAISE EXCEPTION 'Tổng đơn hàng vượt quá hạn mức tín dụng được phê duyệt: %', company_profile.credit_limit;
    END IF;
  END IF;
  
  -- Validate order totals
  IF NEW.total_amount < 0 THEN
    RAISE EXCEPTION 'Tổng đơn hàng không thể âm';
  END IF;
  
  -- Validate discount amount doesn't exceed subtotal
  IF NEW.discount_amount > NEW.subtotal THEN
    RAISE EXCEPTION 'Số tiền giảm giá không thể vượt quá tổng phụ';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for order business rule validation
CREATE TRIGGER validate_order_business_rules_trigger
  BEFORE INSERT OR UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.validate_order_business_rules();

-- Function to validate inventory movements
CREATE OR REPLACE FUNCTION public.validate_inventory_movement()
RETURNS TRIGGER AS $$
DECLARE
  current_stock INTEGER;
  allow_negative_stock BOOLEAN;
BEGIN
  -- Get current stock and location settings
  SELECT 
    ist.quantity_available,
    il.allow_negative_stock
  INTO current_stock, allow_negative_stock
  FROM public.inventory_stock ist
  JOIN public.inventory_locations il ON ist.location_id = il.id
  WHERE ist.product_variant_id = NEW.product_variant_id
    AND ist.location_id = NEW.location_id;
  
  -- Validate that stock movements don't create invalid states
  IF NEW.movement_type IN ('sale', 'transfer_out', 'damage', 'theft', 'waste') THEN
    IF NOT COALESCE(allow_negative_stock, FALSE) 
       AND (current_stock + NEW.quantity_change) < 0 THEN
      RAISE EXCEPTION 'Không đủ tồn kho: Không thể giảm số lượng xuống dưới 0 tại vị trí này. Tồn kho hiện tại: %, Thay đổi: %', 
        current_stock, NEW.quantity_change;
    END IF;
  END IF;
  
  -- Validate quantity changes are logical
  IF NEW.movement_type IN ('receiving', 'return', 'transfer_in') AND NEW.quantity_change <= 0 THEN
    RAISE EXCEPTION 'Thao tác nhập kho phải có số lượng dương. Loại thao tác: %, Số lượng: %', 
      NEW.movement_type, NEW.quantity_change;
  END IF;
  
  IF NEW.movement_type IN ('sale', 'transfer_out', 'damage', 'theft', 'waste') AND NEW.quantity_change >= 0 THEN
    RAISE EXCEPTION 'Thao tác xuất kho phải có số lượng âm. Loại thao tác: %, Số lượng: %', 
      NEW.movement_type, NEW.quantity_change;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for inventory movement validation
CREATE TRIGGER validate_inventory_movement_trigger
  BEFORE INSERT ON public.stock_movements
  FOR EACH ROW EXECUTE FUNCTION public.validate_inventory_movement();

-- =============================================================================
-- NOTIFICATION AUTOMATION
-- =============================================================================

-- Function to send welcome notifications to new users
CREATE OR REPLACE FUNCTION public.send_welcome_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Send welcome notification to new users
  INSERT INTO public.notifications (
    user_id, title, message, notification_type, priority,
    data, action_url
  )
  VALUES (
    NEW.id,
    'Welcome to ' || (SELECT value::text FROM public.system_settings WHERE category = 'general' AND key = 'site_name'),
    'Welcome to our nursery! We are excited to help you find the perfect plants for your needs.',
    'info',
    'normal',
    jsonb_build_object(
      'user_name', COALESCE(NEW.first_name || ' ' || NEW.last_name, 'valued customer'),
      'welcome_date', NOW()
    ),
    '/getting-started'
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for welcome notifications
CREATE TRIGGER send_welcome_notification_trigger
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.send_welcome_notification();

-- =============================================================================
-- MATERIALIZED VIEW REFRESH TRIGGERS
-- =============================================================================

-- Function to mark materialized views for refresh
CREATE OR REPLACE FUNCTION public.mark_mv_for_refresh()
RETURNS TRIGGER AS $$
BEGIN
  -- Update a flag indicating that materialized views need refresh
  INSERT INTO public.system_settings (category, key, value, data_type, name, description)
  VALUES ('system', 'mv_needs_refresh', 'true', 'boolean', 'MV Needs Refresh', 'Flag indicating materialized views need refresh')
  ON CONFLICT (category, key) 
  DO UPDATE SET value = 'true', updated_at = NOW();
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Apply refresh triggers to tables that affect materialized views
DO $$
DECLARE
  table_name TEXT;
  mv_trigger_tables TEXT[] := ARRAY[
    'products',
    'product_variants',
    'inventory_stock',
    'categories',
    'product_images'
  ];
BEGIN
  FOREACH table_name IN ARRAY mv_trigger_tables
  LOOP
    EXECUTE format('
      CREATE TRIGGER mark_mv_refresh_%I_trigger
        AFTER INSERT OR UPDATE OR DELETE ON public.%I
        FOR EACH STATEMENT EXECUTE FUNCTION public.mark_mv_for_refresh();
    ', table_name, table_name);
  END LOOP;
END $$;

-- =============================================================================
-- PERFORMANCE MONITORING TRIGGERS
-- =============================================================================

-- Function to log slow operations
CREATE OR REPLACE FUNCTION public.log_slow_operations()
RETURNS TRIGGER AS $$
DECLARE
  operation_time INTERVAL;
BEGIN
  -- This is a simplified version - in practice, you'd measure actual execution time
  operation_time := NOW() - COALESCE(OLD.updated_at, OLD.created_at, NOW());
  
  -- Log operations that take longer than expected
  IF operation_time > INTERVAL '5 seconds' THEN
    INSERT INTO public.audit_logs (
      event_type, table_name, record_id, description, severity
    )
    VALUES (
      'slow_operation',
      TG_TABLE_NAME,
      CASE WHEN TG_OP = 'DELETE' THEN (row_to_json(OLD)->>'id')::UUID ELSE (row_to_json(NEW)->>'id')::UUID END,
      format('Slow %s operation on %s took %s', TG_OP, TG_TABLE_NAME, operation_time),
      'medium'
    );
  END IF;
  
  RETURN CASE TG_OP WHEN 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- CLEANUP AND MAINTENANCE TRIGGERS
-- =============================================================================

-- Function to cleanup old records
CREATE OR REPLACE FUNCTION public.cleanup_old_records()
RETURNS VOID AS $$
BEGIN
  -- Clean up old activity logs (keep only last 90 days)
  DELETE FROM public.activity_logs 
  WHERE created_at < NOW() - INTERVAL '90 days';
  
  -- Clean up old audit logs (keep only last 1 year)
  DELETE FROM public.audit_logs 
  WHERE created_at < NOW() - INTERVAL '1 year';
  
  -- Clean up expired notifications
  DELETE FROM public.notifications 
  WHERE expires_at IS NOT NULL AND expires_at < NOW();
  
  -- Clean up old stock movements (keep only last 2 years)
  DELETE FROM public.stock_movements 
  WHERE created_at < NOW() - INTERVAL '2 years'
    AND movement_type NOT IN ('receiving', 'sale'); -- Keep important movements longer
  
  -- Reset low stock alerts for items that are no longer low
  UPDATE public.inventory_stock
  SET low_stock_alert_sent = FALSE,
      out_of_stock_alert_sent = FALSE
  WHERE quantity_available > reorder_point 
    AND (low_stock_alert_sent = TRUE OR out_of_stock_alert_sent = TRUE);
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON FUNCTION public.auto_allocate_inventory() IS 'Automatically allocates inventory when order items are created for confirmed orders';
COMMENT ON FUNCTION public.check_and_send_low_stock_alert(UUID, UUID) IS 'Checks inventory levels and sends alerts when below reorder point';
COMMENT ON FUNCTION public.update_order_fulfillment_status() IS 'Updates order fulfillment status based on individual item statuses';
COMMENT ON FUNCTION public.send_order_notifications() IS 'Sends notifications to customers when order status changes';
COMMENT ON FUNCTION public.create_audit_log_trigger() IS 'Generic function to create audit logs for table changes';
COMMENT ON FUNCTION public.validate_order_business_rules() IS 'Validates business rules before order creation/updates';
COMMENT ON FUNCTION public.validate_inventory_movement() IS 'Validates inventory movements to prevent invalid stock states';
COMMENT ON FUNCTION public.cleanup_old_records() IS 'Cleanup function for old audit logs, activities, and notifications';

-- Create a summary comment for this migration
COMMENT ON SCHEMA public IS 'Database schema includes automated business logic triggers for inventory management, order processing, notifications, audit logging, and data validation';

-- =============================================================================
-- GRANT PERMISSIONS (if needed)
-- =============================================================================

-- Grant necessary permissions for trigger functions to access auth.uid()
-- Note: These grants may need to be adjusted based on your Supabase setup
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;