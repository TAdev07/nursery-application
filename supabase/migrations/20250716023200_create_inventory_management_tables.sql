-- Migration: Create inventory management tables
-- Created: 2025-07-16
-- Description: Set up inventory_locations, inventory_stock, and stock_movements tables

-- =============================================================================
-- INVENTORY LOCATIONS TABLE - Warehouse and storage location management
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.inventory_locations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code TEXT UNIQUE NOT NULL, -- e.g., "GH01", "OUT-A", "STOR-01"
  name TEXT NOT NULL,
  description TEXT,
  
  -- Location classification
  location_type TEXT CHECK (location_type IN ('greenhouse', 'outdoor', 'storage', 'display', 'quarantine', 'nursery_area')) NOT NULL,
  climate_controlled BOOLEAN DEFAULT FALSE,
  
  -- Physical characteristics
  capacity_max INTEGER, -- Maximum plants this location can hold
  area_sqm DECIMAL(10,2), -- Area in square meters
  
  -- Address and contact info
  address TEXT,
  contact_person TEXT,
  phone TEXT,
  
  -- Environmental conditions
  temperature_min INTEGER, -- Celsius
  temperature_max INTEGER, -- Celsius
  humidity_min INTEGER, -- Percentage
  humidity_max INTEGER, -- Percentage
  
  -- Location hierarchy (for nested locations like sections within greenhouses)
  parent_location_id UUID REFERENCES public.inventory_locations(id) ON DELETE SET NULL,
  
  -- Status and settings
  is_active BOOLEAN DEFAULT TRUE,
  is_sellable BOOLEAN DEFAULT TRUE, -- Can inventory from this location be sold?
  allow_negative_stock BOOLEAN DEFAULT FALSE,
  priority_order INTEGER DEFAULT 0, -- For allocation priority
  
  -- Additional attributes (flexible for future expansion)
  attributes JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for inventory_locations
CREATE TRIGGER update_inventory_locations_updated_at
  BEFORE UPDATE ON public.inventory_locations
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- INVENTORY STOCK TABLE - Real-time stock tracking per location and variant
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.inventory_stock (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_variant_id UUID REFERENCES public.product_variants(id) ON DELETE CASCADE NOT NULL,
  location_id UUID REFERENCES public.inventory_locations(id) ON DELETE CASCADE NOT NULL,
  
  -- Stock quantities
  quantity_available INTEGER DEFAULT 0,
  quantity_reserved INTEGER DEFAULT 0 CHECK (quantity_reserved >= 0),
  quantity_committed INTEGER DEFAULT 0 CHECK (quantity_committed >= 0), -- Allocated to orders
  quantity_damaged INTEGER DEFAULT 0 CHECK (quantity_damaged >= 0),
  quantity_on_hold INTEGER DEFAULT 0 CHECK (quantity_on_hold >= 0), -- Quality issues, etc.
  
  -- Calculated field for total on-hand
  quantity_on_hand INTEGER GENERATED ALWAYS AS (
    quantity_available + quantity_reserved + quantity_committed + quantity_damaged + quantity_on_hold
  ) STORED,
  
  -- Calculated field for sellable quantity
  quantity_sellable INTEGER GENERATED ALWAYS AS (
    quantity_available - quantity_reserved
  ) STORED,
  
  -- Reorder management
  reorder_point INTEGER DEFAULT 0,
  reorder_quantity INTEGER DEFAULT 0,
  max_stock_level INTEGER,
  
  -- Cost tracking (for FIFO/LIFO inventory valuation)
  average_cost DECIMAL(10,4) DEFAULT 0,
  last_cost DECIMAL(10,4) DEFAULT 0,
  
  -- Tracking information
  last_counted_at TIMESTAMPTZ,
  last_counted_by UUID REFERENCES public.profiles(id),
  last_movement_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Alerts and notifications
  low_stock_alert_sent BOOLEAN DEFAULT FALSE,
  out_of_stock_alert_sent BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure unique combination of product variant and location
  UNIQUE(product_variant_id, location_id)
);

-- Auto-update updated_at trigger for inventory_stock
CREATE TRIGGER update_inventory_stock_updated_at
  BEFORE UPDATE ON public.inventory_stock
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- STOCK MOVEMENTS TABLE - Complete audit trail of all inventory changes
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.stock_movements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_variant_id UUID REFERENCES public.product_variants(id) ON DELETE CASCADE NOT NULL,
  location_id UUID REFERENCES public.inventory_locations(id) ON DELETE CASCADE NOT NULL,
  
  -- Movement details
  movement_type TEXT CHECK (movement_type IN (
    'receiving', 'sale', 'return', 'transfer_in', 'transfer_out', 
    'adjustment', 'damage', 'theft', 'count', 'allocation', 'deallocation',
    'promotion', 'waste', 'growth_update', 'quality_change'
  )) NOT NULL,
  
  -- Quantities (can be positive or negative)
  quantity_change INTEGER NOT NULL,
  quantity_before INTEGER NOT NULL,
  quantity_after INTEGER NOT NULL,
  
  -- Cost information
  unit_cost DECIMAL(10,4),
  total_cost DECIMAL(12,4),
  
  -- References and relationships
  reference_type TEXT, -- 'order', 'transfer', 'receiving', 'adjustment', etc.
  reference_id UUID, -- ID of the related record (order_id, transfer_id, etc.)
  reference_number TEXT, -- Human-readable reference (order number, PO number, etc.)
  
  -- Transfer-specific fields
  from_location_id UUID REFERENCES public.inventory_locations(id),
  to_location_id UUID REFERENCES public.inventory_locations(id),
  
  -- Documentation
  reason TEXT,
  notes TEXT,
  
  -- User and system tracking
  user_id UUID REFERENCES public.profiles(id),
  system_generated BOOLEAN DEFAULT FALSE,
  
  -- Approval workflow (for significant adjustments)
  requires_approval BOOLEAN DEFAULT FALSE,
  approved_by UUID REFERENCES public.profiles(id),
  approved_at TIMESTAMPTZ,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- STOCK ADJUSTMENT REQUESTS TABLE - For tracking adjustment requests that need approval
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.stock_adjustment_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  product_variant_id UUID REFERENCES public.product_variants(id) ON DELETE CASCADE NOT NULL,
  location_id UUID REFERENCES public.inventory_locations(id) ON DELETE CASCADE NOT NULL,
  
  -- Adjustment details
  current_quantity INTEGER NOT NULL,
  requested_quantity INTEGER NOT NULL,
  quantity_difference INTEGER GENERATED ALWAYS AS (requested_quantity - current_quantity) STORED,
  
  reason TEXT NOT NULL,
  supporting_documentation TEXT[], -- URLs to photos, documents, etc.
  
  -- Workflow status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed', 'cancelled')),
  
  -- User tracking
  requested_by UUID REFERENCES public.profiles(id) NOT NULL,
  reviewed_by UUID REFERENCES public.profiles(id),
  approved_by UUID REFERENCES public.profiles(id),
  
  -- Timestamps
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  
  -- Comments and notes
  reviewer_notes TEXT,
  completion_notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for stock_adjustment_requests
CREATE TRIGGER update_stock_adjustment_requests_updated_at
  BEFORE UPDATE ON public.stock_adjustment_requests
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- STOCK TRANSFER REQUESTS TABLE - For moving inventory between locations
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.stock_transfer_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  transfer_number TEXT UNIQUE NOT NULL,
  
  from_location_id UUID REFERENCES public.inventory_locations(id) NOT NULL,
  to_location_id UUID REFERENCES public.inventory_locations(id) NOT NULL,
  
  -- Transfer details
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'in_transit', 'completed', 'cancelled')),
  transfer_type TEXT DEFAULT 'standard' CHECK (transfer_type IN ('standard', 'emergency', 'return', 'display')),
  
  -- Scheduling
  requested_date DATE,
  scheduled_date DATE,
  completed_date DATE,
  
  -- Documentation
  reason TEXT,
  notes TEXT,
  
  -- User tracking
  requested_by UUID REFERENCES public.profiles(id) NOT NULL,
  approved_by UUID REFERENCES public.profiles(id),
  completed_by UUID REFERENCES public.profiles(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for stock_transfer_requests
CREATE TRIGGER update_stock_transfer_requests_updated_at
  BEFORE UPDATE ON public.stock_transfer_requests
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- STOCK TRANSFER ITEMS TABLE - Individual items in a transfer request
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.stock_transfer_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  transfer_request_id UUID REFERENCES public.stock_transfer_requests(id) ON DELETE CASCADE NOT NULL,
  product_variant_id UUID REFERENCES public.product_variants(id) ON DELETE CASCADE NOT NULL,
  
  quantity_requested INTEGER NOT NULL CHECK (quantity_requested > 0),
  quantity_available INTEGER, -- Available at source location when transfer was created
  quantity_transferred INTEGER DEFAULT 0 CHECK (quantity_transferred >= 0),
  
  -- Item-specific notes
  notes TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- FUNCTIONS FOR INVENTORY MANAGEMENT
-- =============================================================================

-- Function to update stock levels when movements are recorded
CREATE OR REPLACE FUNCTION public.update_stock_from_movement()
RETURNS TRIGGER AS $$
DECLARE
  current_stock RECORD;
BEGIN
  -- Get current stock record
  SELECT * INTO current_stock
  FROM public.inventory_stock
  WHERE product_variant_id = NEW.product_variant_id
    AND location_id = NEW.location_id;
  
  -- If no stock record exists, create one
  IF NOT FOUND THEN
    INSERT INTO public.inventory_stock (product_variant_id, location_id, quantity_available)
    VALUES (NEW.product_variant_id, NEW.location_id, GREATEST(0, NEW.quantity_change));
  ELSE
    -- Update existing stock based on movement type
    CASE NEW.movement_type
      WHEN 'receiving' THEN
        UPDATE public.inventory_stock
        SET quantity_available = quantity_available + NEW.quantity_change,
            last_movement_at = NOW(),
            average_cost = CASE 
              WHEN NEW.unit_cost IS NOT NULL AND quantity_available + NEW.quantity_change > 0 THEN
                ((average_cost * quantity_available) + (NEW.unit_cost * NEW.quantity_change)) / 
                (quantity_available + NEW.quantity_change)
              ELSE average_cost
            END,
            last_cost = COALESCE(NEW.unit_cost, last_cost)
        WHERE product_variant_id = NEW.product_variant_id
          AND location_id = NEW.location_id;
          
      WHEN 'sale', 'transfer_out', 'damage', 'theft', 'waste' THEN
        UPDATE public.inventory_stock
        SET quantity_available = quantity_available - ABS(NEW.quantity_change),
            last_movement_at = NOW()
        WHERE product_variant_id = NEW.product_variant_id
          AND location_id = NEW.location_id;
          
      WHEN 'return', 'transfer_in' THEN
        UPDATE public.inventory_stock
        SET quantity_available = quantity_available + ABS(NEW.quantity_change),
            last_movement_at = NOW()
        WHERE product_variant_id = NEW.product_variant_id
          AND location_id = NEW.location_id;
          
      WHEN 'adjustment', 'count' THEN
        UPDATE public.inventory_stock
        SET quantity_available = NEW.quantity_after,
            last_movement_at = NOW(),
            last_counted_at = CASE WHEN NEW.movement_type = 'count' THEN NOW() ELSE last_counted_at END,
            last_counted_by = CASE WHEN NEW.movement_type = 'count' THEN NEW.user_id ELSE last_counted_by END
        WHERE product_variant_id = NEW.product_variant_id
          AND location_id = NEW.location_id;
          
      WHEN 'allocation' THEN
        UPDATE public.inventory_stock
        SET quantity_available = quantity_available - ABS(NEW.quantity_change),
            quantity_committed = quantity_committed + ABS(NEW.quantity_change),
            last_movement_at = NOW()
        WHERE product_variant_id = NEW.product_variant_id
          AND location_id = NEW.location_id;
          
      WHEN 'deallocation' THEN
        UPDATE public.inventory_stock
        SET quantity_available = quantity_available + ABS(NEW.quantity_change),
            quantity_committed = quantity_committed - ABS(NEW.quantity_change),
            last_movement_at = NOW()
        WHERE product_variant_id = NEW.product_variant_id
          AND location_id = NEW.location_id;
    END CASE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update stock when movements are recorded
CREATE TRIGGER update_stock_from_movement_trigger
  AFTER INSERT ON public.stock_movements
  FOR EACH ROW EXECUTE FUNCTION public.update_stock_from_movement();

-- Function to check and reset low stock alerts
CREATE OR REPLACE FUNCTION public.check_stock_alerts()
RETURNS TRIGGER AS $$
BEGIN
  -- Reset alerts if stock is above reorder point
  IF NEW.quantity_available > NEW.reorder_point THEN
    NEW.low_stock_alert_sent = FALSE;
    NEW.out_of_stock_alert_sent = FALSE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to check stock alerts on inventory updates
CREATE TRIGGER check_stock_alerts_trigger
  BEFORE UPDATE ON public.inventory_stock
  FOR EACH ROW EXECUTE FUNCTION public.check_stock_alerts();

-- Function to validate negative stock constraint
CREATE OR REPLACE FUNCTION public.validate_negative_stock()
RETURNS TRIGGER AS $$
DECLARE
  location_settings RECORD;
BEGIN
  -- Get location settings
  SELECT allow_negative_stock INTO location_settings
  FROM public.inventory_locations
  WHERE id = NEW.location_id;
  
  -- Check if negative stock is allowed for this location
  IF NEW.quantity_available < 0 AND NOT COALESCE(location_settings.allow_negative_stock, FALSE) THEN
    RAISE EXCEPTION 'Số lượng không thể âm tại vị trí này. Số lượng hiện tại: %, Vị trí: %', 
      NEW.quantity_available, NEW.location_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to validate negative stock
CREATE TRIGGER validate_negative_stock_trigger
  BEFORE INSERT OR UPDATE ON public.inventory_stock
  FOR EACH ROW EXECUTE FUNCTION public.validate_negative_stock();

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- Inventory locations indexes
CREATE INDEX IF NOT EXISTS idx_inventory_locations_code ON public.inventory_locations(code);
CREATE INDEX IF NOT EXISTS idx_inventory_locations_type ON public.inventory_locations(location_type);
CREATE INDEX IF NOT EXISTS idx_inventory_locations_active ON public.inventory_locations(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_inventory_locations_sellable ON public.inventory_locations(is_sellable) WHERE is_sellable = TRUE;
CREATE INDEX IF NOT EXISTS idx_inventory_locations_parent ON public.inventory_locations(parent_location_id);

-- Inventory stock indexes
CREATE INDEX IF NOT EXISTS idx_inventory_stock_variant ON public.inventory_stock(product_variant_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_location ON public.inventory_stock(location_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_available ON public.inventory_stock(quantity_available);
CREATE INDEX IF NOT EXISTS idx_inventory_stock_sellable ON public.inventory_stock(quantity_sellable) WHERE quantity_sellable > 0;
CREATE INDEX IF NOT EXISTS idx_inventory_stock_low_stock ON public.inventory_stock(product_variant_id, location_id) 
  WHERE quantity_available <= reorder_point AND reorder_point > 0;
CREATE INDEX IF NOT EXISTS idx_inventory_stock_out_of_stock ON public.inventory_stock(product_variant_id, location_id) 
  WHERE quantity_available = 0;

-- Stock movements indexes
CREATE INDEX IF NOT EXISTS idx_stock_movements_variant ON public.stock_movements(product_variant_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_location ON public.stock_movements(location_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_type ON public.stock_movements(movement_type);
CREATE INDEX IF NOT EXISTS idx_stock_movements_reference ON public.stock_movements(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_date ON public.stock_movements(created_at);
CREATE INDEX IF NOT EXISTS idx_stock_movements_user ON public.stock_movements(user_id);

-- Stock adjustment requests indexes
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_status ON public.stock_adjustment_requests(status);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_requested_by ON public.stock_adjustment_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_date ON public.stock_adjustment_requests(requested_at);

-- Stock transfer requests indexes
CREATE INDEX IF NOT EXISTS idx_stock_transfers_number ON public.stock_transfer_requests(transfer_number);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_status ON public.stock_transfer_requests(status);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_from_location ON public.stock_transfer_requests(from_location_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_to_location ON public.stock_transfer_requests(to_location_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_requested_by ON public.stock_transfer_requests(requested_by);

-- =============================================================================
-- SAMPLE DATA
-- =============================================================================

-- Insert default inventory locations
INSERT INTO public.inventory_locations (code, name, description, location_type, climate_controlled, is_active, priority_order) VALUES
('GH01', 'Greenhouse #1', 'Main greenhouse for tropical plants', 'greenhouse', TRUE, TRUE, 1),
('GH02', 'Greenhouse #2', 'Secondary greenhouse for seedlings', 'greenhouse', TRUE, TRUE, 2),
('OUT-A', 'Outdoor Area A', 'Main outdoor display area', 'outdoor', FALSE, TRUE, 3),
('OUT-B', 'Outdoor Area B', 'Secondary outdoor area for hardy plants', 'outdoor', FALSE, TRUE, 4),
('STOR01', 'Storage Warehouse', 'Main storage for supplies and dormant plants', 'storage', FALSE, TRUE, 5),
('DISP01', 'Front Display', 'Customer-facing display area', 'display', FALSE, TRUE, 6),
('QUAR01', 'Quarantine Area', 'Isolated area for new arrivals', 'quarantine', TRUE, TRUE, 7);

-- =============================================================================
-- VIEWS FOR REPORTING AND ANALYTICS
-- =============================================================================

-- View for current stock levels across all locations
CREATE OR REPLACE VIEW public.current_stock_summary AS
SELECT 
  pv.id as variant_id,
  pv.sku,
  p.name as product_name,
  pv.variant_name,
  il.code as location_code,
  il.name as location_name,
  ist.quantity_available,
  ist.quantity_reserved,
  ist.quantity_committed,
  ist.quantity_sellable,
  ist.reorder_point,
  CASE 
    WHEN ist.quantity_available <= ist.reorder_point AND ist.reorder_point > 0 THEN 'low_stock'
    WHEN ist.quantity_available = 0 THEN 'out_of_stock'
    ELSE 'in_stock'
  END as stock_status,
  ist.last_movement_at,
  ist.average_cost
FROM public.inventory_stock ist
JOIN public.product_variants pv ON ist.product_variant_id = pv.id
JOIN public.products p ON pv.product_id = p.id
JOIN public.inventory_locations il ON ist.location_id = il.id
WHERE il.is_active = TRUE;

-- View for stock movements with product details
CREATE OR REPLACE VIEW public.stock_movement_details AS
SELECT 
  sm.*,
  pv.sku,
  p.name as product_name,
  pv.variant_name,
  il.code as location_code,
  il.name as location_name,
  prof.first_name || ' ' || prof.last_name as user_name
FROM public.stock_movements sm
JOIN public.product_variants pv ON sm.product_variant_id = pv.id
JOIN public.products p ON pv.product_id = p.id
JOIN public.inventory_locations il ON sm.location_id = il.id
LEFT JOIN public.profiles prof ON sm.user_id = prof.id;

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON TABLE public.inventory_locations IS 'Physical locations where inventory is stored (greenhouses, outdoor areas, storage)';
COMMENT ON TABLE public.inventory_stock IS 'Real-time inventory quantities by product variant and location';
COMMENT ON TABLE public.stock_movements IS 'Complete audit trail of all inventory changes with full traceability';
COMMENT ON TABLE public.stock_adjustment_requests IS 'Workflow system for inventory adjustments requiring approval';
COMMENT ON TABLE public.stock_transfer_requests IS 'System for moving inventory between locations with approval workflow';

COMMENT ON COLUMN public.inventory_stock.quantity_sellable IS 'Calculated field: available quantity minus reserved quantity';
COMMENT ON COLUMN public.inventory_stock.average_cost IS 'Weighted average cost for inventory valuation';
COMMENT ON COLUMN public.stock_movements.system_generated IS 'TRUE if movement was created automatically by the system';