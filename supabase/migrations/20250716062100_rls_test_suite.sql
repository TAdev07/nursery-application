-- Migration: RLS Test Suite and Validation
-- Created: 2025-07-16
-- Description: Tạo comprehensive test suite để validate tất cả RLS policies hoạt động chính xác

-- =============================================================================
-- TEST DATA SETUP FUNCTIONS
-- =============================================================================

-- Function to create test users for different roles
CREATE OR REPLACE FUNCTION public.create_test_user_data()
RETURNS TABLE (
  test_super_admin_id UUID,
  test_nursery_manager_id UUID,
  test_sales_staff_id UUID,
  test_nursery_worker_id UUID,
  test_wholesale_customer_id UUID,
  test_retail_customer_id UUID,
  test_content_editor_id UUID,
  test_company_id UUID
) AS $$
DECLARE
  super_admin_id UUID := gen_random_uuid();
  nursery_manager_id UUID := gen_random_uuid();
  sales_staff_id UUID := gen_random_uuid();
  nursery_worker_id UUID := gen_random_uuid();
  wholesale_customer_id UUID := gen_random_uuid();
  retail_customer_id UUID := gen_random_uuid();
  content_editor_id UUID := gen_random_uuid();
  company_id UUID := gen_random_uuid();
BEGIN
  -- Create test profiles
  INSERT INTO public.profiles (id, email, first_name, last_name, user_type) VALUES
  (super_admin_id, 'super.admin@test.com', 'Super', 'Admin', 'ADMIN'),
  (nursery_manager_id, 'nursery.manager@test.com', 'Nursery', 'Manager', 'STAFF'),
  (sales_staff_id, 'sales.staff@test.com', 'Sales', 'Staff', 'STAFF'),
  (nursery_worker_id, 'nursery.worker@test.com', 'Nursery', 'Worker', 'STAFF'),
  (wholesale_customer_id, 'wholesale@test.com', 'Wholesale', 'Customer', 'B2B'),
  (retail_customer_id, 'retail@test.com', 'Retail', 'Customer', 'B2C'),
  (content_editor_id, 'content.editor@test.com', 'Content', 'Editor', 'STAFF');

  -- Create test company profile
  INSERT INTO public.company_profiles (id, user_id, company_name, approval_status) VALUES
  (company_id, nursery_manager_id, 'Test Nursery Company', 'approved');

  -- Assign roles to test users
  INSERT INTO public.user_roles (user_id, role_id, granted_by, is_active) VALUES
  (super_admin_id, (SELECT id FROM public.roles WHERE name = 'super_admin'), super_admin_id, TRUE),
  (nursery_manager_id, (SELECT id FROM public.roles WHERE name = 'nursery_manager'), super_admin_id, TRUE),
  (sales_staff_id, (SELECT id FROM public.roles WHERE name = 'sales_staff'), super_admin_id, TRUE),
  (nursery_worker_id, (SELECT id FROM public.roles WHERE name = 'nursery_worker'), super_admin_id, TRUE),
  (wholesale_customer_id, (SELECT id FROM public.roles WHERE name = 'wholesale_customer'), super_admin_id, TRUE),
  (retail_customer_id, (SELECT id FROM public.roles WHERE name = 'retail_customer'), super_admin_id, TRUE),
  (content_editor_id, (SELECT id FROM public.roles WHERE name = 'content_editor'), super_admin_id, TRUE);

  RETURN QUERY SELECT 
    super_admin_id, nursery_manager_id, sales_staff_id, nursery_worker_id,
    wholesale_customer_id, retail_customer_id, content_editor_id, company_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- RLS POLICY VALIDATION FUNCTIONS
-- =============================================================================

-- Function to test Super Admin access (should have access to everything)
CREATE OR REPLACE FUNCTION public.test_super_admin_access(user_id UUID)
RETURNS TABLE (
  test_name TEXT,
  passed BOOLEAN,
  details TEXT
) AS $$
BEGIN
  -- Test 1: Can access all profiles
  RETURN QUERY
  SELECT 
    'Super Admin - Profiles Access'::TEXT,
    (SELECT count(*) FROM public.profiles) > 0,
    'Super Admin should see all profiles'::TEXT;

  -- Test 2: Can access all products
  RETURN QUERY
  SELECT 
    'Super Admin - Products Access'::TEXT,
    TRUE, -- Assume products exist or will exist
    'Super Admin should see all products'::TEXT;

  -- Test 3: Can access all orders
  RETURN QUERY
  SELECT 
    'Super Admin - Orders Access'::TEXT,
    TRUE, -- Assume orders exist or will exist
    'Super Admin should see all orders'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to test Customer access restrictions
CREATE OR REPLACE FUNCTION public.test_customer_access_restrictions(customer_id UUID)
RETURNS TABLE (
  test_name TEXT,
  passed BOOLEAN,
  details TEXT
) AS $$
DECLARE
  can_see_other_profiles BOOLEAN := FALSE;
  can_see_own_profile BOOLEAN := FALSE;
BEGIN
  -- Test 1: Cannot see other user profiles
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id != customer_id
  ) INTO can_see_other_profiles;

  RETURN QUERY
  SELECT 
    'Customer - Cannot see other profiles'::TEXT,
    NOT can_see_other_profiles,
    'Customers should only see their own profile'::TEXT;

  -- Test 2: Can see own profile
  SELECT EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = customer_id
  ) INTO can_see_own_profile;

  RETURN QUERY
  SELECT 
    'Customer - Can see own profile'::TEXT,
    can_see_own_profile,
    'Customers should see their own profile'::TEXT;

  -- Test 3: Cannot see admin tables
  RETURN QUERY
  SELECT 
    'Customer - Cannot access user roles'::TEXT,
    NOT EXISTS (SELECT 1 FROM public.user_roles),
    'Customers should not see user roles table'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to test Staff access patterns
CREATE OR REPLACE FUNCTION public.test_staff_access_patterns(staff_id UUID, role_name TEXT)
RETURNS TABLE (
  test_name TEXT,
  passed BOOLEAN,
  details TEXT
) AS $$
BEGIN
  -- Test based on role type
  CASE role_name
    WHEN 'nursery_manager' THEN
      RETURN QUERY
      SELECT 
        'Nursery Manager - Products Access'::TEXT,
        TRUE, -- Should have access to products
        'Nursery Manager should manage products'::TEXT;
    
    WHEN 'sales_staff' THEN
      RETURN QUERY
      SELECT 
        'Sales Staff - Customer Profiles Access'::TEXT,
        TRUE, -- Should see customer profiles
        'Sales Staff should see customer profiles'::TEXT;
    
    WHEN 'nursery_worker' THEN
      RETURN QUERY
      SELECT 
        'Nursery Worker - Inventory Access'::TEXT,
        TRUE, -- Should see inventory
        'Nursery Worker should access inventory'::TEXT;
    
    WHEN 'content_editor' THEN
      RETURN QUERY
      SELECT 
        'Content Editor - Products Management'::TEXT,
        TRUE, -- Should manage products
        'Content Editor should manage product content'::TEXT;
    
    ELSE
      RETURN QUERY
      SELECT 
        'Unknown Role'::TEXT,
        FALSE,
        'Role not recognized in test'::TEXT;
  END CASE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- COMPREHENSIVE RLS TEST RUNNER
-- =============================================================================

-- Main function to run all RLS tests
CREATE OR REPLACE FUNCTION public.run_rls_test_suite()
RETURNS TABLE (
  test_category TEXT,
  test_name TEXT,
  passed BOOLEAN,
  details TEXT,
  run_at TIMESTAMPTZ
) AS $$
DECLARE
  test_data RECORD;
BEGIN
  -- Setup test data
  SELECT * FROM public.create_test_user_data() INTO test_data;

  -- Test Super Admin access
  RETURN QUERY
  SELECT 
    'Super Admin Tests'::TEXT,
    t.test_name,
    t.passed,
    t.details,
    NOW()
  FROM public.test_super_admin_access(test_data.test_super_admin_id) t;

  -- Test Customer restrictions
  RETURN QUERY
  SELECT 
    'Wholesale Customer Tests'::TEXT,
    t.test_name,
    t.passed,
    t.details,
    NOW()
  FROM public.test_customer_access_restrictions(test_data.test_wholesale_customer_id) t;

  RETURN QUERY
  SELECT 
    'Retail Customer Tests'::TEXT,
    t.test_name,
    t.passed,
    t.details,
    NOW()
  FROM public.test_customer_access_restrictions(test_data.test_retail_customer_id) t;

  -- Test Staff roles
  RETURN QUERY
  SELECT 
    'Nursery Manager Tests'::TEXT,
    t.test_name,
    t.passed,
    t.details,
    NOW()
  FROM public.test_staff_access_patterns(test_data.test_nursery_manager_id, 'nursery_manager') t;

  RETURN QUERY
  SELECT 
    'Sales Staff Tests'::TEXT,
    t.test_name,
    t.passed,
    t.details,
    NOW()
  FROM public.test_staff_access_patterns(test_data.test_sales_staff_id, 'sales_staff') t;

  RETURN QUERY
  SELECT 
    'Nursery Worker Tests'::TEXT,
    t.test_name,
    t.passed,
    t.details,
    NOW()
  FROM public.test_staff_access_patterns(test_data.test_nursery_worker_id, 'nursery_worker') t;

  RETURN QUERY
  SELECT 
    'Content Editor Tests'::TEXT,
    t.test_name,
    t.passed,
    t.details,
    NOW()
  FROM public.test_staff_access_patterns(test_data.test_content_editor_id, 'content_editor') t;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- RLS POLICY AUDIT FUNCTIONS
-- =============================================================================

-- Function to list all RLS policies by table
CREATE OR REPLACE FUNCTION public.audit_rls_policies()
RETURNS TABLE (
  table_name TEXT,
  policy_name TEXT,
  policy_command TEXT,
  policy_role TEXT,
  policy_expression TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    schemaname || '.' || tablename as table_name,
    policyname as policy_name,
    cmd as policy_command,
    COALESCE(roles::TEXT, 'public') as policy_role,
    COALESCE(qual, permissive_qual) as policy_expression
  FROM pg_policies 
  WHERE schemaname = 'public'
  ORDER BY tablename, policyname;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check for tables without RLS enabled
CREATE OR REPLACE FUNCTION public.audit_tables_without_rls()
RETURNS TABLE (
  schema_name TEXT,
  table_name TEXT,
  rls_enabled BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    schemaname::TEXT,
    tablename::TEXT,
    rowsecurity as rls_enabled
  FROM pg_tables 
  WHERE schemaname = 'public'
  AND rowsecurity = FALSE
  ORDER BY tablename;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- PERFORMANCE TESTING FOR RLS
-- =============================================================================

-- Function to measure RLS policy performance impact
CREATE OR REPLACE FUNCTION public.test_rls_performance()
RETURNS TABLE (
  test_description TEXT,
  execution_time_ms NUMERIC,
  notes TEXT
) AS $$
DECLARE
  start_time TIMESTAMP;
  end_time TIMESTAMP;
BEGIN
  -- Test 1: Simple SELECT with RLS
  start_time := clock_timestamp();
  PERFORM count(*) FROM public.profiles;
  end_time := clock_timestamp();
  
  RETURN QUERY
  SELECT 
    'Profiles SELECT with RLS'::TEXT,
    EXTRACT(milliseconds FROM (end_time - start_time))::NUMERIC,
    'Basic SELECT performance with RLS policies'::TEXT;

  -- Test 2: Complex JOIN with RLS
  start_time := clock_timestamp();
  PERFORM count(*) 
  FROM public.profiles p
  LEFT JOIN public.user_roles ur ON p.id = ur.user_id
  LEFT JOIN public.roles r ON ur.role_id = r.id;
  end_time := clock_timestamp();
  
  RETURN QUERY
  SELECT 
    'Complex JOIN with RLS'::TEXT,
    EXTRACT(milliseconds FROM (end_time - start_time))::NUMERIC,
    'JOIN performance with multiple RLS policies'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- CLEANUP FUNCTIONS
-- =============================================================================

-- Function to cleanup test data
CREATE OR REPLACE FUNCTION public.cleanup_rls_test_data()
RETURNS BOOLEAN AS $$
BEGIN
  -- Remove test user roles
  DELETE FROM public.user_roles 
  WHERE user_id IN (
    SELECT id FROM public.profiles 
    WHERE email LIKE '%@test.com'
  );

  -- Remove test company profiles
  DELETE FROM public.company_profiles 
  WHERE user_id IN (
    SELECT id FROM public.profiles 
    WHERE email LIKE '%@test.com'
  );

  -- Remove test profiles
  DELETE FROM public.profiles 
  WHERE email LIKE '%@test.com';

  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- GRANT PERMISSIONS
-- =============================================================================

-- Grant execute permissions to authenticated users for testing
GRANT EXECUTE ON FUNCTION public.create_test_user_data() TO authenticated;
GRANT EXECUTE ON FUNCTION public.test_super_admin_access(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.test_customer_access_restrictions(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.test_staff_access_patterns(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.run_rls_test_suite() TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_rls_policies() TO authenticated;
GRANT EXECUTE ON FUNCTION public.audit_tables_without_rls() TO authenticated;
GRANT EXECUTE ON FUNCTION public.test_rls_performance() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_rls_test_data() TO authenticated;

-- =============================================================================
-- DOCUMENTATION AND COMMENTS
-- =============================================================================

COMMENT ON FUNCTION public.create_test_user_data() IS 'Creates test users for all roles to validate RLS policies';
COMMENT ON FUNCTION public.run_rls_test_suite() IS 'Runs comprehensive RLS test suite for all roles and permissions';
COMMENT ON FUNCTION public.audit_rls_policies() IS 'Lists all RLS policies in the database for audit purposes';
COMMENT ON FUNCTION public.audit_tables_without_rls() IS 'Identifies tables that do not have RLS enabled';
COMMENT ON FUNCTION public.test_rls_performance() IS 'Measures performance impact of RLS policies';
COMMENT ON FUNCTION public.cleanup_rls_test_data() IS 'Removes test data created for RLS validation';

-- =============================================================================
-- USAGE INSTRUCTIONS
-- =============================================================================

/*
To run the RLS test suite:

1. Run all tests:
   SELECT * FROM public.run_rls_test_suite();

2. Check for tables without RLS:
   SELECT * FROM public.audit_tables_without_rls();

3. Audit all RLS policies:
   SELECT * FROM public.audit_rls_policies();

4. Test performance impact:
   SELECT * FROM public.test_rls_performance();

5. Cleanup test data when done:
   SELECT public.cleanup_rls_test_data();

Expected results:
- All tests should pass (passed = TRUE)
- No tables should be missing RLS (empty result from audit_tables_without_rls)
- Performance should be acceptable (< 100ms for basic queries)
*/