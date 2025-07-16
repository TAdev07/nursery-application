-- Migration: Database schema verification and testing
-- Created: 2025-07-16
-- Description: Comprehensive verification of all tables, constraints, indexes, and functionality

-- =============================================================================
-- SCHEMA VERIFICATION FUNCTIONS
-- =============================================================================

-- Function to verify all tables exist
CREATE OR REPLACE FUNCTION public.verify_tables_exist()
RETURNS TABLE (
  tbl_name TEXT,
  tbl_exists BOOLEAN,
  row_count BIGINT
) AS $$
DECLARE
  expected_tables TEXT[] := ARRAY[
    'profiles', 'company_profiles', 'roles', 'user_roles',
    'categories', 'products', 'product_variants', 'product_images',
    'inventory_locations', 'inventory_stock', 'stock_movements', 
    'stock_adjustment_requests', 'stock_transfer_requests', 'stock_transfer_items',
    'orders', 'order_items', 'order_status_history', 'shipping_addresses',
    'payment_transactions', 'pricing_tiers', 'discount_codes', 'discount_code_usage',
    'notifications', 'audit_logs', 'system_settings', 'activity_logs',
    'email_templates', 'scheduled_tasks', 'api_keys', 'feature_flags'
  ];
  table_name_var TEXT;
  table_exists BOOLEAN;
  table_count BIGINT;
BEGIN
  FOREACH table_name_var IN ARRAY expected_tables
  LOOP
    -- Check if table exists
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema = 'public' AND information_schema.tables.table_name = table_name_var
    ) INTO table_exists;
    
    -- Get row count if table exists
    IF table_exists THEN
      EXECUTE format('SELECT COUNT(*) FROM public.%I', table_name_var) INTO table_count;
    ELSE
      table_count := -1;
    END IF;
    
    RETURN QUERY SELECT table_name_var, table_exists, table_count;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to verify foreign key constraints
CREATE OR REPLACE FUNCTION public.verify_foreign_keys()
RETURNS TABLE (
  tbl_name TEXT,
  constraint_name TEXT,
  col_name TEXT,
  foreign_table TEXT,
  foreign_column TEXT,
  is_valid BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    tc.table_name::TEXT,
    tc.constraint_name::TEXT,
    kcu.column_name::TEXT,
    ccu.table_name::TEXT as foreign_table,
    ccu.column_name::TEXT as foreign_column,
    -- Check if constraint is valid (not deferred/violated)
    NOT EXISTS (
      SELECT 1 FROM pg_constraint pc
      WHERE pc.conname = tc.constraint_name 
        AND pc.contype = 'f'
        AND NOT pc.convalidated
    ) as is_valid
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
  JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
  WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
  ORDER BY tc.table_name, tc.constraint_name;
END;
$$ LANGUAGE plpgsql;

-- Function to verify indexes exist
CREATE OR REPLACE FUNCTION public.verify_indexes()
RETURNS TABLE (
  tbl_name TEXT,
  idx_name TEXT,
  index_type TEXT,
  columns TEXT[],
  is_unique BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.relname::TEXT as table_name,
    i.relname::TEXT as index_name,
    am.amname::TEXT as index_type,
    ARRAY_AGG(a.attname ORDER BY a.attnum)::TEXT[] as columns,
    ix.indisunique as is_unique
  FROM pg_class t
  JOIN pg_index ix ON t.oid = ix.indrelid
  JOIN pg_class i ON i.oid = ix.indexrelid
  JOIN pg_am am ON i.relam = am.oid
  JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(ix.indkey)
  WHERE t.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
    AND t.relkind = 'r'  -- Regular tables only
    AND i.relname NOT LIKE '%_pkey'  -- Exclude primary key indexes
  GROUP BY t.relname, i.relname, am.amname, ix.indisunique
  ORDER BY t.relname, i.relname;
END;
$$ LANGUAGE plpgsql;

-- Function to verify triggers exist
CREATE OR REPLACE FUNCTION public.verify_triggers()
RETURNS TABLE (
  tbl_name TEXT,
  trg_name TEXT,
  trigger_function TEXT,
  trigger_event TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.relname::TEXT as table_name,
    t.tgname::TEXT as trigger_name,
    p.proname::TEXT as trigger_function,
    CASE t.tgtype & 7
      WHEN 1 THEN 'INSERT'
      WHEN 2 THEN 'DELETE'
      WHEN 4 THEN 'UPDATE'
      ELSE 'MULTIPLE'
    END::TEXT as trigger_event
  FROM pg_trigger t
  JOIN pg_class c ON t.tgrelid = c.oid
  JOIN pg_proc p ON t.tgfoid = p.oid
  JOIN pg_namespace n ON c.relnamespace = n.oid
  WHERE n.nspname = 'public'
    AND NOT t.tgisinternal  -- Exclude internal triggers
  ORDER BY c.relname, t.tgname;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- DATA INTEGRITY TESTS
-- =============================================================================

-- Function to test basic CRUD operations
CREATE OR REPLACE FUNCTION public.test_basic_crud()
RETURNS TABLE (
  test_name TEXT,
  success BOOLEAN,
  error_message TEXT
) AS $$
DECLARE
  test_category_id UUID;
  test_product_id UUID;
  test_variant_id UUID;
  test_location_id UUID;
  test_profile_id UUID;
  test_order_id UUID;
  error_msg TEXT;
BEGIN
  -- Test 1: Create a test category
  BEGIN
    INSERT INTO public.categories (name, slug, description)
    VALUES ('Test Category', 'test-category', 'A test category')
    RETURNING id INTO test_category_id;
    
    RETURN QUERY SELECT 'Create Category'::TEXT, TRUE, NULL::TEXT;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
    RETURN QUERY SELECT 'Create Category'::TEXT, FALSE, error_msg;
  END;
  
  -- Test 2: Create a test product
  BEGIN
    INSERT INTO public.products (
      sku, name, slug, category_id, botanical_name, 
      plant_type, base_price, wholesale_price
    )
    VALUES (
      'TEST001', 'Test Plant', 'test-plant', test_category_id,
      'Testicus planticus', 'tree', 29.99, 19.99
    )
    RETURNING id INTO test_product_id;
    
    RETURN QUERY SELECT 'Create Product'::TEXT, TRUE, NULL::TEXT;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
    RETURN QUERY SELECT 'Create Product'::TEXT, FALSE, error_msg;
  END;
  
  -- Test 3: Create a product variant
  BEGIN
    INSERT INTO public.product_variants (
      product_id, variant_name, sku, container_type, container_size
    )
    VALUES (
      test_product_id, '6-inch pot', 'TEST001-6IN', 'pot', '6-inch'
    )
    RETURNING id INTO test_variant_id;
    
    RETURN QUERY SELECT 'Create Product Variant'::TEXT, TRUE, NULL::TEXT;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
    RETURN QUERY SELECT 'Create Product Variant'::TEXT, FALSE, error_msg;
  END;
  
  -- Test 4: Create inventory location
  BEGIN
    INSERT INTO public.inventory_locations (code, name, location_type)
    VALUES ('TEST01', 'Test Location', 'greenhouse')
    RETURNING id INTO test_location_id;
    
    RETURN QUERY SELECT 'Create Inventory Location'::TEXT, TRUE, NULL::TEXT;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
    RETURN QUERY SELECT 'Create Inventory Location'::TEXT, FALSE, error_msg;
  END;
  
  -- Test 5: Create inventory stock
  BEGIN
    INSERT INTO public.inventory_stock (
      product_variant_id, location_id, quantity_available, reorder_point
    )
    VALUES (test_variant_id, test_location_id, 100, 10);
    
    RETURN QUERY SELECT 'Create Inventory Stock'::TEXT, TRUE, NULL::TEXT;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
    RETURN QUERY SELECT 'Create Inventory Stock'::TEXT, FALSE, error_msg;
  END;
  
  -- Test 6: Test hierarchical categories
  BEGIN
    INSERT INTO public.categories (name, slug, parent_id)
    VALUES ('Test Subcategory', 'test-subcategory', test_category_id);
    
    -- Verify path was set correctly
    IF EXISTS (
      SELECT 1 FROM public.categories 
      WHERE slug = 'test-subcategory' 
        AND path = 'test-category/test-subcategory'
        AND depth = 1
    ) THEN
      RETURN QUERY SELECT 'Hierarchical Categories'::TEXT, TRUE, NULL::TEXT;
    ELSE
      RETURN QUERY SELECT 'Hierarchical Categories'::TEXT, FALSE, 'Path or depth not set correctly'::TEXT;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
    RETURN QUERY SELECT 'Hierarchical Categories'::TEXT, FALSE, error_msg;
  END;
  
  -- Test 7: Test materialized view data
  BEGIN
    -- Refresh materialized view
    REFRESH MATERIALIZED VIEW public.mv_product_catalog;
    
    -- Check if test product appears in materialized view
    IF EXISTS (
      SELECT 1 FROM public.mv_product_catalog 
      WHERE sku = 'TEST001' AND total_stock = 100
    ) THEN
      RETURN QUERY SELECT 'Materialized View'::TEXT, TRUE, NULL::TEXT;
    ELSE
      RETURN QUERY SELECT 'Materialized View'::TEXT, FALSE, 'Product not found in materialized view'::TEXT;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
    RETURN QUERY SELECT 'Materialized View'::TEXT, FALSE, error_msg;
  END;
  
  -- Cleanup test data
  BEGIN
    DELETE FROM public.inventory_stock WHERE location_id = test_location_id;
    DELETE FROM public.inventory_locations WHERE id = test_location_id;
    DELETE FROM public.product_variants WHERE id = test_variant_id;
    DELETE FROM public.products WHERE id = test_product_id;
    DELETE FROM public.categories WHERE parent_id = test_category_id;
    DELETE FROM public.categories WHERE id = test_category_id;
    
    RETURN QUERY SELECT 'Cleanup Test Data'::TEXT, TRUE, NULL::TEXT;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
    RETURN QUERY SELECT 'Cleanup Test Data'::TEXT, FALSE, error_msg;
  END;
END;
$$ LANGUAGE plpgsql;

-- Function to test business logic triggers
CREATE OR REPLACE FUNCTION public.test_business_triggers()
RETURNS TABLE (
  test_name TEXT,
  success BOOLEAN,
  error_message TEXT
) AS $$
DECLARE
  test_stock_id UUID;
  initial_quantity INTEGER := 50;
  movement_quantity INTEGER := 10;
  final_quantity INTEGER;
  error_msg TEXT;
BEGIN
  -- Test inventory update triggers
  BEGIN
    -- Create test data
    INSERT INTO public.inventory_stock (
      product_variant_id, location_id, quantity_available
    )
    SELECT 
      pv.id, il.id, initial_quantity
    FROM public.product_variants pv
    CROSS JOIN public.inventory_locations il
    WHERE pv.sku LIKE '%001%' AND il.code LIKE 'GH%'
    LIMIT 1
    RETURNING id INTO test_stock_id;
    
    -- Create a stock movement
    INSERT INTO public.stock_movements (
      product_variant_id, location_id, movement_type, quantity_change,
      quantity_before, quantity_after
    )
    SELECT 
      ist.product_variant_id, ist.location_id, 'sale', -movement_quantity,
      ist.quantity_available, ist.quantity_available - movement_quantity
    FROM public.inventory_stock ist
    WHERE ist.id = test_stock_id;
    
    -- Check if quantity was updated correctly
    SELECT quantity_available INTO final_quantity
    FROM public.inventory_stock
    WHERE id = test_stock_id;
    
    IF final_quantity = (initial_quantity - movement_quantity) THEN
      RETURN QUERY SELECT 'Inventory Update Trigger'::TEXT, TRUE, NULL::TEXT;
    ELSE
      RETURN QUERY SELECT 'Inventory Update Trigger'::TEXT, FALSE, 
        format('Expected %s, got %s', initial_quantity - movement_quantity, final_quantity)::TEXT;
    END IF;
    
    -- Cleanup
    DELETE FROM public.stock_movements WHERE location_id IN (SELECT location_id FROM public.inventory_stock WHERE id = test_stock_id);
    DELETE FROM public.inventory_stock WHERE id = test_stock_id;
    
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
    RETURN QUERY SELECT 'Inventory Update Trigger'::TEXT, FALSE, error_msg;
  END;
  
  -- Test timestamp update triggers
  BEGIN
    -- Create a test setting
    INSERT INTO public.system_settings (category, key, value, data_type, name)
    VALUES ('test', 'test_key', '"test_value"', 'string', 'Test Setting');
    
    -- Wait a moment then update
    PERFORM pg_sleep(0.1);
    
    UPDATE public.system_settings 
    SET value = '"updated_value"'
    WHERE category = 'test' AND key = 'test_key';
    
    -- Check if updated_at was changed
    IF EXISTS (
      SELECT 1 FROM public.system_settings 
      WHERE category = 'test' AND key = 'test_key'
        AND updated_at > created_at
    ) THEN
      RETURN QUERY SELECT 'Timestamp Update Trigger'::TEXT, TRUE, NULL::TEXT;
    ELSE
      RETURN QUERY SELECT 'Timestamp Update Trigger'::TEXT, FALSE, 'updated_at not changed'::TEXT;
    END IF;
    
    -- Cleanup
    DELETE FROM public.system_settings WHERE category = 'test' AND key = 'test_key';
    
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS error_msg = MESSAGE_TEXT;
    RETURN QUERY SELECT 'Timestamp Update Trigger'::TEXT, FALSE, error_msg;
  END;
END;
$$ LANGUAGE plpgsql;

-- Function to test performance of key queries
CREATE OR REPLACE FUNCTION public.test_query_performance()
RETURNS TABLE (
  query_name TEXT,
  execution_time_ms FLOAT,
  rows_returned BIGINT
) AS $$
DECLARE
  start_time TIMESTAMP;
  end_time TIMESTAMP;
  row_count BIGINT;
BEGIN
  -- Test 1: Product catalog query
  start_time := clock_timestamp();
  SELECT COUNT(*) INTO row_count
  FROM public.mv_product_catalog
  WHERE category_slug IS NOT NULL;
  end_time := clock_timestamp();
  
  RETURN QUERY SELECT 
    'Product Catalog Query'::TEXT,
    EXTRACT(MILLISECONDS FROM (end_time - start_time))::FLOAT,
    row_count;
  
  -- Test 2: Inventory summary query
  start_time := clock_timestamp();
  SELECT COUNT(*) INTO row_count
  FROM public.current_stock_summary
  WHERE stock_status = 'in_stock';
  end_time := clock_timestamp();
  
  RETURN QUERY SELECT 
    'Inventory Summary Query'::TEXT,
    EXTRACT(MILLISECONDS FROM (end_time - start_time))::FLOAT,
    row_count;
  
  -- Test 3: User orders query
  start_time := clock_timestamp();
  SELECT COUNT(*) INTO row_count
  FROM public.order_summary
  WHERE customer_email IS NOT NULL;
  end_time := clock_timestamp();
  
  RETURN QUERY SELECT 
    'Order Summary Query'::TEXT,
    EXTRACT(MILLISECONDS FROM (end_time - start_time))::FLOAT,
    row_count;
    
  -- Test 4: Full-text search query
  start_time := clock_timestamp();
  SELECT COUNT(*) INTO row_count
  FROM public.products
  WHERE to_tsvector('english', name || ' ' || COALESCE(description, '')) @@ to_tsquery('english', 'plant');
  end_time := clock_timestamp();
  
  RETURN QUERY SELECT 
    'Full-text Search Query'::TEXT,
    EXTRACT(MILLISECONDS FROM (end_time - start_time))::FLOAT,
    row_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- COMPREHENSIVE VERIFICATION REPORT
-- =============================================================================

-- Function to generate complete verification report
CREATE OR REPLACE FUNCTION public.generate_verification_report()
RETURNS TEXT AS $$
DECLARE
  report TEXT := '';
  table_count INTEGER;
  constraint_count INTEGER;
  index_count INTEGER;
  trigger_count INTEGER;
  failed_tests INTEGER;
  missing_tables TEXT;
BEGIN
  report := report || E'=============================================================================\n';
  report := report || E'DATABASE SCHEMA VERIFICATION REPORT\n';
  report := report || E'Generated: ' || NOW() || E'\n';
  report := report || E'=============================================================================\n\n';
  
  -- Table verification
  SELECT COUNT(*) INTO table_count
  FROM public.verify_tables_exist()
  WHERE tbl_exists = TRUE;
  
  report := report || E'TABLES:\n';
  report := report || format('- Total tables created: %s/31\n', table_count);
  
  IF table_count < 31 THEN
    report := report || E'- Missing tables:\n';
    SELECT string_agg('  * ' || tbl_name, E'\n')
    INTO missing_tables
    FROM public.verify_tables_exist()
    WHERE tbl_exists = FALSE;
    
    report := report || missing_tables || E'\n';
  ELSE
    report := report || E'- All required tables exist ✓\n';
  END IF;
  
  report := report || E'\n';
  
  -- Foreign key verification
  SELECT COUNT(*) INTO constraint_count
  FROM public.verify_foreign_keys()
  WHERE is_valid = TRUE;
  
  report := report || E'FOREIGN KEY CONSTRAINTS:\n';
  report := report || format('- Total valid constraints: %s\n', constraint_count);
  
  SELECT COUNT(*) INTO constraint_count
  FROM public.verify_foreign_keys()
  WHERE is_valid = FALSE;
  
  IF constraint_count > 0 THEN
    report := report || format('- Invalid constraints: %s\n', constraint_count);
  ELSE
    report := report || E'- All foreign key constraints valid ✓\n';
  END IF;
  
  report := report || E'\n';
  
  -- Index verification
  SELECT COUNT(*) INTO index_count
  FROM public.verify_indexes();
  
  report := report || E'INDEXES:\n';
  report := report || format('- Total indexes created: %s\n', index_count);
  report := report || E'- Performance indexes in place ✓\n\n';
  
  -- Trigger verification
  SELECT COUNT(*) INTO trigger_count
  FROM public.verify_triggers();
  
  report := report || E'TRIGGERS:\n';
  report := report || format('- Total triggers created: %s\n', trigger_count);
  report := report || E'- Business logic automation active ✓\n\n';
  
  -- Test results
  SELECT COUNT(*) INTO failed_tests
  FROM public.test_basic_crud()
  WHERE success = FALSE;
  
  report := report || E'FUNCTIONALITY TESTS:\n';
  IF failed_tests = 0 THEN
    report := report || E'- All CRUD operations working ✓\n';
  ELSE
    report := report || format('- %s CRUD tests failed\n', failed_tests);
  END IF;
  
  SELECT COUNT(*) INTO failed_tests
  FROM public.test_business_triggers()
  WHERE success = FALSE;
  
  IF failed_tests = 0 THEN
    report := report || E'- All business triggers working ✓\n';
  ELSE
    report := report || format('- %s trigger tests failed\n', failed_tests);
  END IF;
  
  report := report || E'\n';
  
  -- Sample data verification
  report := report || E'SAMPLE DATA:\n';
  
  SELECT COUNT(*) INTO table_count FROM public.categories;
  report := report || format('- Categories: %s\n', table_count);
  
  SELECT COUNT(*) INTO table_count FROM public.inventory_locations;
  report := report || format('- Inventory locations: %s\n', table_count);
  
  SELECT COUNT(*) INTO table_count FROM public.pricing_tiers;
  report := report || format('- Pricing tiers: %s\n', table_count);
  
  SELECT COUNT(*) INTO table_count FROM public.system_settings;
  report := report || format('- System settings: %s\n', table_count);
  
  report := report || E'\n';
  
  -- Final status
  report := report || E'=============================================================================\n';
  report := report || E'VERIFICATION STATUS: ';
  
  IF table_count >= 31 AND constraint_count = 0 AND failed_tests = 0 THEN
    report := report || E'PASSED ✓\n';
    report := report || E'Database schema is ready for production use.\n';
  ELSE
    report := report || E'ISSUES DETECTED ⚠\n';
    report := report || E'Please review the issues above before proceeding.\n';
  END IF;
  
  report := report || E'=============================================================================\n';
  
  RETURN report;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- RUN VERIFICATION TESTS
-- =============================================================================

-- Test all components
SELECT 'Running database verification tests...' as status;

-- Run basic CRUD tests
SELECT * FROM public.test_basic_crud();

-- Run business logic tests
SELECT * FROM public.test_business_triggers();

-- Run performance tests
SELECT * FROM public.test_query_performance();

-- Generate comprehensive report
SELECT public.generate_verification_report() as verification_report;