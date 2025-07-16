-- Migration: Fix inventory constraints - Remove subquery from CHECK constraint
-- Created: 2025-07-16
-- Description: Fix the subquery error in inventory_stock table constraint

-- =============================================================================
-- FIX INVENTORY STOCK TABLE CONSTRAINT
-- =============================================================================

-- Remove the problematic CHECK constraint (if it exists)
ALTER TABLE public.inventory_stock 
DROP CONSTRAINT IF EXISTS inventory_stock_quantity_available_check;

-- Add basic non-negative constraint for quantity_available
-- (The business logic will be handled by triggers)
ALTER TABLE public.inventory_stock 
ADD CONSTRAINT inventory_stock_quantity_available_basic_check 
CHECK (quantity_available >= -999999); -- Allow negative but within reasonable bounds

-- =============================================================================
-- ADD VALIDATION TRIGGER FOR NEGATIVE STOCK
-- =============================================================================

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

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS validate_negative_stock_trigger ON public.inventory_stock;

-- Create trigger to validate negative stock
CREATE TRIGGER validate_negative_stock_trigger
  BEFORE INSERT OR UPDATE ON public.inventory_stock
  FOR EACH ROW EXECUTE FUNCTION public.validate_negative_stock();

-- =============================================================================
-- COMMENTS
-- =============================================================================
COMMENT ON FUNCTION public.validate_negative_stock() IS 'Validates negative stock based on location settings';
COMMENT ON TRIGGER validate_negative_stock_trigger ON public.inventory_stock IS 'Validates negative stock is allowed at location before insert/update';