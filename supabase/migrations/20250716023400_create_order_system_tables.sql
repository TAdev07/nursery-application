-- Migration: Create order system tables
-- Created: 2025-07-16
-- Description: Set up orders, order_items, pricing_tiers, and related order management tables

-- =============================================================================
-- PRICING TIERS TABLE - B2B pricing structure
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.pricing_tiers (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  description TEXT,
  
  -- Tier qualification criteria
  min_order_value DECIMAL(10,2) DEFAULT 0,
  min_annual_volume DECIMAL(12,2) DEFAULT 0,
  min_order_quantity INTEGER DEFAULT 0,
  
  -- Discount structure
  discount_percentage DECIMAL(5,2) DEFAULT 0 CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
  flat_discount_amount DECIMAL(10,2) DEFAULT 0,
  
  -- Tier benefits
  free_shipping_threshold DECIMAL(10,2),
  payment_terms_days INTEGER DEFAULT 0, -- Net payment terms in days
  credit_limit DECIMAL(12,2) DEFAULT 0,
  
  -- Status and ordering
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INTEGER DEFAULT 0,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for pricing_tiers
CREATE TRIGGER update_pricing_tiers_updated_at
  BEFORE UPDATE ON public.pricing_tiers
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- ORDERS TABLE - Order header information
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_number TEXT UNIQUE NOT NULL,
  
  -- Customer information
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  company_id UUID REFERENCES public.company_profiles(id) ON DELETE SET NULL,
  
  -- Order status and type
  status TEXT DEFAULT 'draft' CHECK (status IN (
    'draft', 'pending', 'confirmed', 'processing', 'shipped', 
    'delivered', 'completed', 'cancelled', 'refunded', 'on_hold'
  )),
  order_type TEXT DEFAULT 'standard' CHECK (order_type IN (
    'standard', 'wholesale', 'preorder', 'special_order', 'quote_request'
  )),
  
  -- Pricing breakdown
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0,
  discount_amount DECIMAL(10,2) DEFAULT 0,
  tax_amount DECIMAL(10,2) DEFAULT 0,
  shipping_amount DECIMAL(10,2) DEFAULT 0,
  total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
  
  -- Pricing tier and discounts
  pricing_tier_id UUID REFERENCES public.pricing_tiers(id),
  discount_code TEXT,
  discount_description TEXT,
  
  -- B2B specific fields
  purchase_order_number TEXT,
  payment_terms INTEGER DEFAULT 0, -- Net payment terms in days
  credit_used DECIMAL(10,2) DEFAULT 0,
  
  -- Shipping information
  shipping_method TEXT,
  shipping_address JSONB, -- Flexible address structure
  billing_address JSONB,
  
  -- Special instructions and notes
  customer_notes TEXT,
  internal_notes TEXT,
  special_instructions TEXT,
  
  -- Delivery scheduling
  requested_delivery_date DATE,
  promised_delivery_date DATE,
  actual_delivery_date DATE,
  delivery_window TEXT, -- e.g., "morning", "afternoon", "anytime"
  
  -- Payment information
  payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN (
    'pending', 'authorized', 'captured', 'paid', 'refunded', 'failed'
  )),
  payment_method TEXT,
  payment_reference TEXT,
  
  -- Source tracking
  order_source TEXT DEFAULT 'website' CHECK (order_source IN (
    'website', 'phone', 'email', 'in_person', 'marketplace', 'wholesale_portal'
  )),
  sales_representative_id UUID REFERENCES public.profiles(id),
  
  -- Fulfillment tracking
  fulfillment_status TEXT DEFAULT 'pending' CHECK (fulfillment_status IN (
    'pending', 'processing', 'partially_shipped', 'shipped', 'delivered', 'completed'
  )),
  
  -- Timestamps
  order_date TIMESTAMPTZ DEFAULT NOW(),
  confirmed_at TIMESTAMPTZ,
  shipped_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for orders
CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Function to generate order numbers
CREATE OR REPLACE FUNCTION public.generate_order_number()
RETURNS TEXT AS $$
DECLARE
  year_prefix TEXT;
  sequence_num INTEGER;
BEGIN
  year_prefix := to_char(NOW(), 'YY');
  
  -- Get next sequence number for this year
  SELECT COALESCE(MAX(CAST(SUBSTRING(order_number FROM 3) AS INTEGER)), 0) + 1
  INTO sequence_num
  FROM public.orders
  WHERE order_number LIKE year_prefix || '%';
  
  RETURN year_prefix || LPAD(sequence_num::TEXT, 6, '0');
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate order number
CREATE OR REPLACE FUNCTION public.set_order_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.order_number IS NULL OR NEW.order_number = '' THEN
    NEW.order_number := public.generate_order_number();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_order_number_trigger
  BEFORE INSERT ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.set_order_number();

-- =============================================================================
-- ORDER ITEMS TABLE - Individual products within orders
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
  product_variant_id UUID REFERENCES public.product_variants(id) ON DELETE RESTRICT NOT NULL,
  
  -- Quantities
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  quantity_shipped INTEGER DEFAULT 0 CHECK (quantity_shipped >= 0),
  quantity_delivered INTEGER DEFAULT 0 CHECK (quantity_delivered >= 0),
  quantity_cancelled INTEGER DEFAULT 0 CHECK (quantity_cancelled >= 0),
  
  -- Pricing (captured at time of order to preserve historical prices)
  unit_price DECIMAL(10,2) NOT NULL,
  unit_cost DECIMAL(10,2), -- For margin analysis
  discount_amount DECIMAL(10,2) DEFAULT 0,
  total_price DECIMAL(10,2) NOT NULL,
  
  -- Product information (captured for historical accuracy)
  product_name TEXT NOT NULL,
  product_sku TEXT NOT NULL,
  variant_name TEXT,
  variant_sku TEXT,
  
  -- Item-specific notes and customizations
  line_notes TEXT,
  special_instructions TEXT,
  
  -- Fulfillment tracking
  fulfillment_status TEXT DEFAULT 'pending' CHECK (fulfillment_status IN (
    'pending', 'allocated', 'picked', 'packed', 'shipped', 'delivered', 'cancelled'
  )),
  
  -- Allocation tracking
  allocated_at TIMESTAMPTZ,
  allocated_from_location_id UUID REFERENCES public.inventory_locations(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for order_items
CREATE TRIGGER update_order_items_updated_at
  BEFORE UPDATE ON public.order_items
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- ORDER STATUS HISTORY TABLE - Track all status changes
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.order_status_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
  
  from_status TEXT,
  to_status TEXT NOT NULL,
  
  -- Change details
  reason TEXT,
  notes TEXT,
  
  -- User tracking
  changed_by UUID REFERENCES public.profiles(id),
  system_generated BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function to track order status changes
CREATE OR REPLACE FUNCTION public.track_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Only track if status actually changed
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.order_status_history (order_id, from_status, to_status, system_generated)
    VALUES (NEW.id, OLD.status, NEW.status, TRUE);
    
    -- Update timestamp fields based on status
    CASE NEW.status
      WHEN 'confirmed' THEN
        NEW.confirmed_at = COALESCE(NEW.confirmed_at, NOW());
      WHEN 'shipped' THEN
        NEW.shipped_at = COALESCE(NEW.shipped_at, NOW());
      WHEN 'delivered' THEN
        NEW.delivered_at = COALESCE(NEW.delivered_at, NOW());
      WHEN 'cancelled' THEN
        NEW.cancelled_at = COALESCE(NEW.cancelled_at, NOW());
      ELSE
        -- No special handling for other statuses
    END CASE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER track_order_status_change_trigger
  AFTER UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.track_order_status_change();

-- =============================================================================
-- SHIPPING ADDRESSES TABLE - Reusable shipping addresses
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.shipping_addresses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  
  -- Address information
  label TEXT, -- e.g., "Home", "Office", "Farm"
  recipient_name TEXT NOT NULL,
  company_name TEXT,
  address_line_1 TEXT NOT NULL,
  address_line_2 TEXT,
  city TEXT NOT NULL,
  state_province TEXT NOT NULL,
  postal_code TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'VN',
  
  -- Contact information
  phone TEXT,
  email TEXT,
  
  -- Address metadata
  is_default BOOLEAN DEFAULT FALSE,
  is_business BOOLEAN DEFAULT FALSE,
  delivery_instructions TEXT,
  
  -- Validation
  is_validated BOOLEAN DEFAULT FALSE,
  validation_service TEXT,
  validation_date TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for shipping_addresses
CREATE TRIGGER update_shipping_addresses_updated_at
  BEFORE UPDATE ON public.shipping_addresses
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Ensure only one default address per user
CREATE UNIQUE INDEX idx_shipping_addresses_default
ON public.shipping_addresses(user_id)
WHERE is_default = TRUE;

-- =============================================================================
-- PAYMENT TRANSACTIONS TABLE - Payment processing records
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.payment_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
  
  -- Transaction details
  transaction_type TEXT CHECK (transaction_type IN (
    'authorization', 'capture', 'sale', 'refund', 'void'
  )) NOT NULL,
  transaction_status TEXT CHECK (transaction_status IN (
    'pending', 'processing', 'completed', 'failed', 'cancelled'
  )) DEFAULT 'pending',
  
  -- Amounts
  amount DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'VND',
  
  -- Payment method details
  payment_method TEXT NOT NULL, -- 'credit_card', 'bank_transfer', 'cash', 'check', etc.
  payment_provider TEXT, -- 'vnpay', 'momo', 'stripe', etc.
  
  -- External references
  provider_transaction_id TEXT,
  provider_reference TEXT,
  authorization_code TEXT,
  
  -- Transaction metadata
  processor_response JSONB,
  failure_reason TEXT,
  gateway_fee DECIMAL(8,2),
  
  -- Timestamps
  processed_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- DISCOUNT CODES TABLE - Promotional discount codes
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.discount_codes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  
  -- Discount configuration
  discount_type TEXT CHECK (discount_type IN ('percentage', 'fixed_amount', 'free_shipping')) NOT NULL,
  discount_value DECIMAL(10,2) NOT NULL,
  
  -- Usage limits
  usage_limit INTEGER, -- NULL = unlimited
  usage_count INTEGER DEFAULT 0,
  usage_limit_per_customer INTEGER,
  
  -- Eligibility criteria
  minimum_order_amount DECIMAL(10,2),
  maximum_discount_amount DECIMAL(10,2),
  eligible_user_types TEXT[] DEFAULT '{"B2C", "B2B"}',
  eligible_product_categories UUID[], -- References categories.id
  
  -- Validity period
  valid_from TIMESTAMPTZ DEFAULT NOW(),
  valid_until TIMESTAMPTZ,
  
  -- Status
  is_active BOOLEAN DEFAULT TRUE,
  
  -- Creator tracking
  created_by UUID REFERENCES public.profiles(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for discount_codes
CREATE TRIGGER update_discount_codes_updated_at
  BEFORE UPDATE ON public.discount_codes
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- DISCOUNT CODE USAGE TABLE - Track discount code usage
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.discount_code_usage (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  discount_code_id UUID REFERENCES public.discount_codes(id) ON DELETE CASCADE NOT NULL,
  order_id UUID REFERENCES public.orders(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  
  discount_amount DECIMAL(10,2) NOT NULL,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure discount code can only be used once per order
  UNIQUE(discount_code_id, order_id)
);

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- Pricing tiers indexes
CREATE INDEX IF NOT EXISTS idx_pricing_tiers_active ON public.pricing_tiers(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_pricing_tiers_sort_order ON public.pricing_tiers(sort_order);

-- Orders indexes
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_company_id ON public.orders(company_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_order_type ON public.orders(order_type);
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON public.orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_fulfillment_status ON public.orders(fulfillment_status);
CREATE INDEX IF NOT EXISTS idx_orders_order_date ON public.orders(order_date);
CREATE INDEX IF NOT EXISTS idx_orders_total_amount ON public.orders(total_amount);
CREATE INDEX IF NOT EXISTS idx_orders_sales_rep ON public.orders(sales_representative_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON public.orders(order_number);

-- Order items indexes
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_variant ON public.order_items(product_variant_id);
CREATE INDEX IF NOT EXISTS idx_order_items_fulfillment_status ON public.order_items(fulfillment_status);
CREATE INDEX IF NOT EXISTS idx_order_items_allocated_location ON public.order_items(allocated_from_location_id);

-- Order status history indexes
CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON public.order_status_history(order_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_date ON public.order_status_history(created_at);

-- Shipping addresses indexes
CREATE INDEX IF NOT EXISTS idx_shipping_addresses_user_id ON public.shipping_addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_shipping_addresses_default ON public.shipping_addresses(user_id, is_default);

-- Payment transactions indexes
CREATE INDEX IF NOT EXISTS idx_payment_transactions_order_id ON public.payment_transactions(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_type ON public.payment_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_status ON public.payment_transactions(transaction_status);
CREATE INDEX IF NOT EXISTS idx_payment_transactions_provider_id ON public.payment_transactions(provider_transaction_id);

-- Discount codes indexes
CREATE INDEX IF NOT EXISTS idx_discount_codes_code ON public.discount_codes(code);
CREATE INDEX IF NOT EXISTS idx_discount_codes_active ON public.discount_codes(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_discount_codes_valid_period ON public.discount_codes(valid_from, valid_until);

-- Discount code usage indexes
CREATE INDEX IF NOT EXISTS idx_discount_usage_code ON public.discount_code_usage(discount_code_id);
CREATE INDEX IF NOT EXISTS idx_discount_usage_order ON public.discount_code_usage(order_id);
CREATE INDEX IF NOT EXISTS idx_discount_usage_user ON public.discount_code_usage(user_id);

-- =============================================================================
-- SAMPLE DATA
-- =============================================================================

-- Insert default pricing tiers
INSERT INTO public.pricing_tiers (name, description, discount_percentage, payment_terms_days, sort_order) VALUES
('Retail', 'Standard retail pricing', 0, 0, 1),
('Bronze', 'Small business discount', 5, 15, 2),
('Silver', 'Volume discount tier', 10, 30, 3),
('Gold', 'Preferred partner pricing', 15, 45, 4),
('Platinum', 'Wholesale/Distributor pricing', 20, 60, 5);

-- Insert some sample discount codes
INSERT INTO public.discount_codes (code, name, description, discount_type, discount_value, valid_until) VALUES
('WELCOME10', 'Welcome Discount', 'New customer 10% discount', 'percentage', 10, NOW() + INTERVAL '1 year'),
('SPRING2025', 'Spring Sale', 'Spring season 15% off', 'percentage', 15, '2025-06-01'::timestamptz),
('FREESHIP', 'Free Shipping', 'Free shipping on any order', 'free_shipping', 0, NOW() + INTERVAL '6 months');

-- =============================================================================
-- VIEWS FOR REPORTING
-- =============================================================================

-- View for order summaries with customer information
CREATE OR REPLACE VIEW public.order_summary AS
SELECT 
  o.*,
  p.first_name || ' ' || p.last_name as customer_name,
  p.email as customer_email,
  cp.company_name,
  pt.name as pricing_tier_name,
  COUNT(oi.id) as item_count,
  STRING_AGG(DISTINCT oi.product_name, ', ') as product_names
FROM public.orders o
LEFT JOIN public.profiles p ON o.user_id = p.id
LEFT JOIN public.company_profiles cp ON o.company_id = cp.id
LEFT JOIN public.pricing_tiers pt ON o.pricing_tier_id = pt.id
LEFT JOIN public.order_items oi ON o.id = oi.order_id
GROUP BY o.id, p.first_name, p.last_name, p.email, cp.company_name, pt.name;

-- View for sales analytics
CREATE OR REPLACE VIEW public.sales_analytics AS
SELECT 
  DATE_TRUNC('day', o.order_date) as order_date,
  COUNT(o.id) as order_count,
  SUM(o.total_amount) as total_revenue,
  AVG(o.total_amount) as average_order_value,
  COUNT(DISTINCT o.user_id) as unique_customers,
  COUNT(CASE WHEN o.order_type = 'wholesale' THEN 1 END) as wholesale_orders,
  COUNT(CASE WHEN o.order_type = 'standard' THEN 1 END) as retail_orders
FROM public.orders o
WHERE o.status NOT IN ('cancelled', 'draft')
GROUP BY DATE_TRUNC('day', o.order_date);

-- =============================================================================
-- FUNCTIONS FOR ORDER MANAGEMENT
-- =============================================================================

-- Function to calculate order totals
CREATE OR REPLACE FUNCTION public.calculate_order_totals(order_uuid UUID)
RETURNS VOID AS $$
DECLARE
  order_record RECORD;
  calculated_subtotal DECIMAL(10,2);
  calculated_total DECIMAL(10,2);
BEGIN
  -- Get order details
  SELECT * INTO order_record FROM public.orders WHERE id = order_uuid;
  
  -- Calculate subtotal from order items
  SELECT COALESCE(SUM(total_price), 0) INTO calculated_subtotal
  FROM public.order_items
  WHERE order_id = order_uuid;
  
  -- Calculate total (subtotal + tax + shipping - discount)
  calculated_total := calculated_subtotal + order_record.tax_amount + 
                     order_record.shipping_amount - order_record.discount_amount;
  
  -- Update order totals
  UPDATE public.orders
  SET subtotal = calculated_subtotal,
      total_amount = calculated_total,
      updated_at = NOW()
  WHERE id = order_uuid;
END;
$$ LANGUAGE plpgsql;

-- Trigger to recalculate order totals when items change
CREATE OR REPLACE FUNCTION public.recalculate_order_totals()
RETURNS TRIGGER AS $$
BEGIN
  -- Recalculate for the affected order
  PERFORM public.calculate_order_totals(COALESCE(NEW.order_id, OLD.order_id));
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER recalculate_order_totals_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.order_items
  FOR EACH ROW EXECUTE FUNCTION public.recalculate_order_totals();

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON TABLE public.pricing_tiers IS 'B2B pricing tiers with different discount levels and payment terms';
COMMENT ON TABLE public.orders IS 'Order header information with comprehensive B2B and B2C support';
COMMENT ON TABLE public.order_items IS 'Individual line items within orders with fulfillment tracking';
COMMENT ON TABLE public.order_status_history IS 'Audit trail of all order status changes';
COMMENT ON TABLE public.shipping_addresses IS 'Reusable shipping addresses for customers';
COMMENT ON TABLE public.payment_transactions IS 'Payment processing records and transaction history';
COMMENT ON TABLE public.discount_codes IS 'Promotional discount codes with usage limits and criteria';

COMMENT ON COLUMN public.orders.order_number IS 'System-generated unique order number (format: YYNNNNNN)';
COMMENT ON COLUMN public.orders.payment_terms IS 'Net payment terms in days (0 = immediate payment)';
COMMENT ON COLUMN public.order_items.unit_price IS 'Historical price at time of order to preserve pricing';
COMMENT ON COLUMN public.discount_codes.usage_limit IS 'NULL means unlimited usage';