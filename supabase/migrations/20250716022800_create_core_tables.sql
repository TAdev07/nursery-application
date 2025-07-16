-- Migration: Create core tables for user management and authentication
-- Created: 2025-07-16
-- Description: Set up profiles, company_profiles, roles, and user_roles tables

-- =============================================================================
-- PROFILES TABLE - Extends Supabase auth.users
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  first_name TEXT,
  last_name TEXT,
  phone TEXT,
  avatar_url TEXT,
  user_type TEXT DEFAULT 'B2C' CHECK (user_type IN ('B2C', 'B2B', 'ADMIN', 'STAFF')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'pending')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for profiles
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- AUTO-CREATE PROFILE TRIGGER
-- =============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, user_type)
  VALUES (NEW.id, NEW.email, 'B2C');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- COMPANY PROFILES TABLE - B2B business information
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.company_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE UNIQUE,
  company_name TEXT NOT NULL,
  business_registration TEXT,
  tax_number TEXT,
  website TEXT,
  business_address TEXT,
  business_phone TEXT,
  business_email TEXT,
  
  -- Financial information
  credit_limit DECIMAL(12,2) DEFAULT 0,
  current_balance DECIMAL(12,2) DEFAULT 0,
  payment_terms INTEGER DEFAULT 30, -- days
  discount_tier TEXT DEFAULT 'standard' CHECK (discount_tier IN ('standard', 'bronze', 'silver', 'gold', 'platinum')),
  
  -- Status and approval
  approval_status TEXT DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected', 'suspended')),
  approved_by UUID REFERENCES public.profiles(id),
  approved_at TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for company_profiles
CREATE TRIGGER update_company_profiles_updated_at
  BEFORE UPDATE ON public.company_profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- ROLES TABLE - System roles and permissions
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.roles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  permissions JSONB DEFAULT '[]'::jsonb,
  is_system_role BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for roles
CREATE TRIGGER update_roles_updated_at
  BEFORE UPDATE ON public.roles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- USER ROLES TABLE - Many-to-many relationship between users and roles
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.user_roles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  role_id UUID REFERENCES public.roles(id) ON DELETE CASCADE,
  granted_by UUID REFERENCES public.profiles(id),
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT TRUE,
  
  -- Ensure unique user-role combinations
  UNIQUE(user_id, role_id)
);

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- Profiles indexes
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_user_type ON public.profiles(user_type);
CREATE INDEX IF NOT EXISTS idx_profiles_status ON public.profiles(status);

-- Company profiles indexes
CREATE INDEX IF NOT EXISTS idx_company_profiles_user_id ON public.company_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_company_profiles_approval_status ON public.company_profiles(approval_status);
CREATE INDEX IF NOT EXISTS idx_company_profiles_company_name ON public.company_profiles(company_name);

-- Roles indexes
CREATE INDEX IF NOT EXISTS idx_roles_name ON public.roles(name);
CREATE INDEX IF NOT EXISTS idx_roles_active ON public.roles(is_active) WHERE is_active = TRUE;

-- User roles indexes
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON public.user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_active ON public.user_roles(is_active) WHERE is_active = TRUE;

-- =============================================================================
-- INSERT DEFAULT ROLES
-- =============================================================================
INSERT INTO public.roles (name, description, permissions, is_system_role) VALUES
('admin', 'System Administrator', 
 '["users:manage", "products:manage", "inventory:manage", "orders:manage", "settings:manage", "reports:view"]'::jsonb, 
 true),
('staff', 'Staff Member', 
 '["products:view", "inventory:manage", "orders:view", "orders:update"]'::jsonb, 
 true),
('b2b_customer', 'B2B Customer', 
 '["products:view", "orders:create", "orders:view", "profile:manage"]'::jsonb, 
 true),
('b2c_customer', 'B2C Customer', 
 '["products:view", "orders:create", "orders:view", "profile:manage"]'::jsonb, 
 true);

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON TABLE public.profiles IS 'User profiles extending Supabase auth.users with additional information';
COMMENT ON TABLE public.company_profiles IS 'B2B company information and financial details';
COMMENT ON TABLE public.roles IS 'System roles with permissions for RBAC';
COMMENT ON TABLE public.user_roles IS 'Many-to-many relationship between users and roles';

COMMENT ON COLUMN public.profiles.user_type IS 'User classification: B2C, B2B, ADMIN, STAFF';
COMMENT ON COLUMN public.company_profiles.discount_tier IS 'Company discount tier based on volume/relationship';
COMMENT ON COLUMN public.roles.permissions IS 'JSON array of permission strings for this role';
COMMENT ON COLUMN public.user_roles.expires_at IS 'Optional expiration date for temporary role assignments';