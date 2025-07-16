-- Migration: Create supporting tables
-- Created: 2025-07-16
-- Description: Set up notifications, audit_logs, settings, and other supporting tables

-- =============================================================================
-- NOTIFICATIONS TABLE - System notifications and alerts
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Recipient information
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  role_id UUID REFERENCES public.roles(id) ON DELETE CASCADE,
  
  -- Notification content
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  notification_type TEXT CHECK (notification_type IN (
    'info', 'success', 'warning', 'error', 'order', 'inventory', 'system', 'promotional'
  )) NOT NULL,
  
  -- Notification channel and delivery
  channel TEXT CHECK (channel IN ('in_app', 'email', 'sms', 'push')) DEFAULT 'in_app',
  priority TEXT CHECK (priority IN ('low', 'normal', 'high', 'urgent')) DEFAULT 'normal',
  
  -- Status tracking
  is_read BOOLEAN DEFAULT FALSE,
  is_sent BOOLEAN DEFAULT FALSE,
  
  -- Rich content support
  data JSONB DEFAULT '{}'::jsonb, -- Additional structured data
  action_url TEXT, -- URL for notification click action
  icon TEXT, -- Icon class or image URL
  
  -- Related entity references
  entity_type TEXT, -- 'order', 'product', 'inventory', etc.
  entity_id UUID, -- ID of the related entity
  
  -- Scheduling and expiry
  send_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  
  -- Delivery tracking
  read_at TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,
  delivery_attempts INTEGER DEFAULT 0,
  last_delivery_attempt TIMESTAMPTZ,
  delivery_error TEXT,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for notifications
CREATE TRIGGER update_notifications_updated_at
  BEFORE UPDATE ON public.notifications
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Function to mark notification as read
CREATE OR REPLACE FUNCTION public.mark_notification_read(notification_uuid UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.notifications
  SET is_read = TRUE,
      read_at = NOW(),
      updated_at = NOW()
  WHERE id = notification_uuid AND is_read = FALSE;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- AUDIT LOGS TABLE - Complete system audit trail
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Event details
  event_type TEXT NOT NULL, -- 'create', 'update', 'delete', 'login', 'logout', etc.
  table_name TEXT, -- Table affected (for database operations)
  record_id UUID, -- ID of the affected record
  
  -- Change tracking
  old_values JSONB, -- Previous values (for updates/deletes)
  new_values JSONB, -- New values (for creates/updates)
  changed_fields TEXT[], -- List of fields that changed
  
  -- User and session tracking
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  session_id TEXT,
  ip_address INET,
  user_agent TEXT,
  
  -- Request context
  request_method TEXT, -- HTTP method for API requests
  request_path TEXT, -- API endpoint or page path
  request_body JSONB, -- Request payload (sensitive data removed)
  
  -- System context
  application_name TEXT DEFAULT 'nursery-app',
  environment TEXT DEFAULT 'production',
  
  -- Additional metadata
  description TEXT, -- Human-readable description of the event
  severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
  tags TEXT[], -- Searchable tags for categorization
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function to create audit log entries
CREATE OR REPLACE FUNCTION public.create_audit_log(
  p_event_type TEXT,
  p_table_name TEXT DEFAULT NULL,
  p_record_id UUID DEFAULT NULL,
  p_old_values JSONB DEFAULT NULL,
  p_new_values JSONB DEFAULT NULL,
  p_user_id UUID DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  log_id UUID;
  changed_fields_array TEXT[];
BEGIN
  -- Calculate changed fields if both old and new values provided
  IF p_old_values IS NOT NULL AND p_new_values IS NOT NULL THEN
    SELECT ARRAY_AGG(key)
    INTO changed_fields_array
    FROM (
      SELECT key
      FROM jsonb_each(p_new_values)
      WHERE (p_old_values ->> key) IS DISTINCT FROM (p_new_values ->> key)
    ) AS changes;
  END IF;
  
  INSERT INTO public.audit_logs (
    event_type, table_name, record_id, old_values, new_values, 
    changed_fields, user_id, description
  )
  VALUES (
    p_event_type, p_table_name, p_record_id, p_old_values, p_new_values,
    changed_fields_array, p_user_id, p_description
  )
  RETURNING id INTO log_id;
  
  RETURN log_id;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- SYSTEM SETTINGS TABLE - Application configuration
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.system_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Setting identification
  category TEXT NOT NULL, -- 'general', 'email', 'payment', 'inventory', etc.
  key TEXT NOT NULL,
  
  -- Setting value and metadata
  value JSONB NOT NULL,
  default_value JSONB,
  data_type TEXT CHECK (data_type IN ('string', 'number', 'boolean', 'json', 'array')) NOT NULL,
  
  -- Setting description and validation
  name TEXT NOT NULL,
  description TEXT,
  validation_rules JSONB, -- JSON schema for validation
  is_public BOOLEAN DEFAULT FALSE, -- Can be accessed by public API
  is_sensitive BOOLEAN DEFAULT FALSE, -- Contains sensitive data
  
  -- Version and change tracking
  version INTEGER DEFAULT 1,
  last_changed_by UUID REFERENCES public.profiles(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure unique category-key combinations
  UNIQUE(category, key)
);

-- Auto-update updated_at trigger for system_settings
CREATE TRIGGER update_system_settings_updated_at
  BEFORE UPDATE ON public.system_settings
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Function to get setting value with type casting
CREATE OR REPLACE FUNCTION public.get_setting(
  p_category TEXT,
  p_key TEXT,
  p_default JSONB DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
  setting_value JSONB;
BEGIN
  SELECT value INTO setting_value
  FROM public.system_settings
  WHERE category = p_category AND key = p_key;
  
  RETURN COALESCE(setting_value, p_default);
END;
$$ LANGUAGE plpgsql;

-- Function to update setting value
CREATE OR REPLACE FUNCTION public.update_setting(
  p_category TEXT,
  p_key TEXT,
  p_value JSONB,
  p_user_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  UPDATE public.system_settings
  SET value = p_value,
      version = version + 1,
      last_changed_by = p_user_id,
      updated_at = NOW()
  WHERE category = p_category AND key = p_key;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Không tìm thấy cài đặt: %.%', p_category, p_key;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- ACTIVITY LOGS TABLE - User activity tracking
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Activity details
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  activity_type TEXT NOT NULL, -- 'login', 'logout', 'view_product', 'place_order', etc.
  activity_name TEXT NOT NULL, -- Human-readable activity name
  
  -- Context and metadata
  entity_type TEXT, -- Type of entity involved (product, order, etc.)
  entity_id UUID, -- ID of the entity
  metadata JSONB DEFAULT '{}'::jsonb, -- Additional activity data
  
  -- Session and request tracking
  session_id TEXT,
  ip_address INET,
  user_agent TEXT,
  referer TEXT,
  
  -- Performance metrics
  duration_ms INTEGER, -- How long the activity took
  response_status INTEGER, -- HTTP status code
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================================================
-- EMAIL TEMPLATES TABLE - Dynamic email template management
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.email_templates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Template identification
  template_key TEXT UNIQUE NOT NULL, -- 'welcome_email', 'order_confirmation', etc.
  name TEXT NOT NULL,
  description TEXT,
  
  -- Template content
  subject TEXT NOT NULL,
  html_content TEXT NOT NULL,
  text_content TEXT,
  
  -- Template variables and metadata
  variables JSONB DEFAULT '[]'::jsonb, -- List of available template variables
  template_type TEXT CHECK (template_type IN ('transactional', 'promotional', 'system')) DEFAULT 'transactional',
  
  -- Localization
  language TEXT DEFAULT 'vi',
  
  -- Status and versioning
  is_active BOOLEAN DEFAULT TRUE,
  version INTEGER DEFAULT 1,
  
  -- Change tracking
  created_by UUID REFERENCES public.profiles(id),
  last_modified_by UUID REFERENCES public.profiles(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for email_templates
CREATE TRIGGER update_email_templates_updated_at
  BEFORE UPDATE ON public.email_templates
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================================================
-- SCHEDULED TASKS TABLE - Background job management
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.scheduled_tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Task identification
  task_name TEXT NOT NULL,
  task_type TEXT NOT NULL, -- 'email_send', 'inventory_sync', 'report_generation', etc.
  
  -- Scheduling
  schedule_expression TEXT, -- Cron expression for recurring tasks
  next_run_at TIMESTAMPTZ,
  last_run_at TIMESTAMPTZ,
  
  -- Task configuration
  parameters JSONB DEFAULT '{}'::jsonb,
  timeout_seconds INTEGER DEFAULT 300,
  max_retries INTEGER DEFAULT 3,
  retry_count INTEGER DEFAULT 0,
  
  -- Status tracking
  status TEXT CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled')) DEFAULT 'pending',
  
  -- Execution tracking
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  error_message TEXT,
  execution_log TEXT,
  
  -- Metadata
  created_by UUID REFERENCES public.profiles(id),
  is_active BOOLEAN DEFAULT TRUE,
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Function for scheduled_tasks updated_at trigger
CREATE OR REPLACE FUNCTION public.update_scheduled_tasks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Auto-update updated_at trigger for scheduled_tasks
CREATE TRIGGER update_scheduled_tasks_updated_at
  BEFORE UPDATE ON public.scheduled_tasks
  FOR EACH ROW EXECUTE FUNCTION public.update_scheduled_tasks_updated_at();

-- =============================================================================
-- API KEYS TABLE - API access management
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.api_keys (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Key identification
  key_name TEXT NOT NULL,
  key_hash TEXT UNIQUE NOT NULL, -- Hashed version of the actual key
  key_prefix TEXT NOT NULL, -- First few characters for identification
  
  -- Key ownership and permissions
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  permissions JSONB DEFAULT '[]'::jsonb, -- Array of permitted actions
  
  -- Access control
  is_active BOOLEAN DEFAULT TRUE,
  rate_limit_per_hour INTEGER DEFAULT 1000,
  allowed_origins TEXT[], -- CORS origins
  
  -- Usage tracking
  last_used_at TIMESTAMPTZ,
  usage_count INTEGER DEFAULT 0,
  
  -- Expiry and security
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  revoked_at TIMESTAMPTZ,
  revoked_by UUID REFERENCES public.profiles(id)
);

-- =============================================================================
-- FEATURE FLAGS TABLE - Feature toggle management
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.feature_flags (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Flag identification
  flag_key TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  
  -- Flag configuration
  is_enabled BOOLEAN DEFAULT FALSE,
  flag_type TEXT CHECK (flag_type IN ('boolean', 'string', 'number', 'json')) DEFAULT 'boolean',
  flag_value JSONB DEFAULT 'false'::jsonb,
  
  -- Targeting rules
  targeting_rules JSONB DEFAULT '[]'::jsonb, -- Rules for selective enablement
  percentage_rollout INTEGER DEFAULT 0 CHECK (percentage_rollout >= 0 AND percentage_rollout <= 100),
  
  -- Metadata
  environment TEXT DEFAULT 'production',
  created_by UUID REFERENCES public.profiles(id),
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at trigger for feature_flags
CREATE TRIGGER update_feature_flags_updated_at
  BEFORE UPDATE ON public.feature_flags
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Function to check if a feature is enabled for a user
CREATE OR REPLACE FUNCTION public.is_feature_enabled(
  p_flag_key TEXT,
  p_user_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  flag_record RECORD;
  user_hash INTEGER;
BEGIN
  SELECT * INTO flag_record
  FROM public.feature_flags
  WHERE flag_key = p_flag_key;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- If flag is disabled, return false
  IF NOT flag_record.is_enabled THEN
    RETURN FALSE;
  END IF;
  
  -- Check percentage rollout
  IF flag_record.percentage_rollout < 100 AND p_user_id IS NOT NULL THEN
    user_hash := ABS(HASHTEXT(p_user_id::TEXT)) % 100;
    IF user_hash >= flag_record.percentage_rollout THEN
      RETURN FALSE;
    END IF;
  END IF;
  
  -- TODO: Implement targeting rules evaluation
  
  RETURN flag_record.is_enabled;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- INDEXES FOR PERFORMANCE
-- =============================================================================

-- Notifications indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_role_id ON public.notifications(role_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications(notification_type);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_unsent ON public.notifications(channel, is_sent) WHERE is_sent = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_send_at ON public.notifications(send_at);
CREATE INDEX IF NOT EXISTS idx_notifications_entity ON public.notifications(entity_type, entity_id);

-- Audit logs indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_event_type ON public.audit_logs(event_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_table_record ON public.audit_logs(table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_severity ON public.audit_logs(severity);

-- System settings indexes
CREATE INDEX IF NOT EXISTS idx_system_settings_category ON public.system_settings(category);
CREATE INDEX IF NOT EXISTS idx_system_settings_public ON public.system_settings(is_public) WHERE is_public = TRUE;

-- Activity logs indexes
CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON public.activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_activity_type ON public.activity_logs(activity_type);
CREATE INDEX IF NOT EXISTS idx_activity_logs_entity ON public.activity_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON public.activity_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_activity_logs_session ON public.activity_logs(session_id);

-- Email templates indexes
CREATE INDEX IF NOT EXISTS idx_email_templates_key ON public.email_templates(template_key);
CREATE INDEX IF NOT EXISTS idx_email_templates_active ON public.email_templates(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_email_templates_type ON public.email_templates(template_type);

-- Scheduled tasks indexes
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_status ON public.scheduled_tasks(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_next_run ON public.scheduled_tasks(next_run_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_type ON public.scheduled_tasks(task_type);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_active ON public.scheduled_tasks(is_active) WHERE is_active = TRUE;

-- API keys indexes
CREATE INDEX IF NOT EXISTS idx_api_keys_user_id ON public.api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_active ON public.api_keys(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_api_keys_hash ON public.api_keys(key_hash);

-- Feature flags indexes
CREATE INDEX IF NOT EXISTS idx_feature_flags_key ON public.feature_flags(flag_key);
CREATE INDEX IF NOT EXISTS idx_feature_flags_enabled ON public.feature_flags(is_enabled) WHERE is_enabled = TRUE;
CREATE INDEX IF NOT EXISTS idx_feature_flags_environment ON public.feature_flags(environment);

-- =============================================================================
-- SAMPLE DATA
-- =============================================================================

-- Insert default system settings (Vietnamese)
INSERT INTO public.system_settings (category, key, value, data_type, name, description, is_public) VALUES
('general', 'site_name', '"Hệ Thống Quản Lý Vườn Ươm"', 'string', 'Tên Website', 'Tên hiển thị của ứng dụng', true),
('general', 'site_description', '"Giải pháp quản lý vườn ươm toàn diện"', 'string', 'Mô Tả Website', 'Mô tả về ứng dụng', true),
('general', 'timezone', '"Asia/Ho_Chi_Minh"', 'string', 'Múi Giờ Mặc Định', 'Múi giờ mặc định của hệ thống', false),
('general', 'currency', '"VND"', 'string', 'Tiền Tệ Mặc Định', 'Đơn vị tiền tệ mặc định cho giá cả', true),
('general', 'language', '"vi"', 'string', 'Ngôn Ngữ Mặc Định', 'Ngôn ngữ mặc định của ứng dụng', true),

('inventory', 'low_stock_threshold', '10', 'number', 'Ngưỡng Tồn Kho Thấp', 'Ngưỡng mặc định cho cảnh báo tồn kho thấp', false),
('inventory', 'auto_allocation', 'true', 'boolean', 'Phân Bổ Tự Động', 'Tự động phân bổ kho cho đơn hàng', false),
('inventory', 'negative_stock_allowed', 'false', 'boolean', 'Cho Phép Tồn Kho Âm', 'Cho phép tồn kho âm', false),

('orders', 'auto_confirm_orders', 'false', 'boolean', 'Tự Động Xác Nhận Đơn Hàng', 'Tự động xác nhận đơn hàng khi thanh toán', false),
('orders', 'order_number_prefix', '"ORD"', 'string', 'Tiền Tố Số Đơn Hàng', 'Tiền tố cho số đơn hàng', false),
('orders', 'default_payment_terms', '0', 'number', 'Điều Khoản Thanh Toán Mặc Định', 'Điều khoản thanh toán mặc định theo ngày', false),

('email', 'smtp_enabled', 'false', 'boolean', 'Kích Hoạt SMTP', 'Kích hoạt gửi email qua SMTP', false),
('email', 'from_name', '"Quản Lý Vườn Ươm"', 'string', 'Tên Người Gửi Email', 'Tên người gửi mặc định cho email', false),
('email', 'from_email', '"noreply@nursery.com"', 'string', 'Địa Chỉ Email Người Gửi', 'Địa chỉ email người gửi mặc định', false);

-- Insert default email templates (Vietnamese)
INSERT INTO public.email_templates (template_key, name, subject, html_content, text_content, variables) VALUES
('welcome_email', 'Email Chào Mừng', 'Chào mừng bạn đến với {{site_name}}!', 
 '<h1>Chào mừng {{user_name}}!</h1><p>Cảm ơn bạn đã tham gia {{site_name}}. Chúng tôi rất vui được hỗ trợ bạn với tất cả nhu cầu về cây trồng.</p>',
 'Chào mừng {{user_name}}! Cảm ơn bạn đã tham gia {{site_name}}. Chúng tôi rất vui được hỗ trợ bạn với tất cả nhu cầu về cây trồng.',
 '["user_name", "site_name"]'::jsonb),

('order_confirmation', 'Xác Nhận Đơn Hàng', 'Xác nhận đơn hàng - {{order_number}}',
 '<h1>Đơn Hàng Đã Được Xác Nhận</h1><p>Đơn hàng {{order_number}} của bạn đã được xác nhận. Tổng cộng: {{total_amount}} {{currency}}</p>',
 'Đơn hàng đã được xác nhận. Đơn hàng {{order_number}} của bạn đã được xác nhận. Tổng cộng: {{total_amount}} {{currency}}',
 '["order_number", "total_amount", "currency", "customer_name"]'::jsonb),

('low_stock_alert', 'Cảnh Báo Hết Hàng', 'Cảnh báo tồn kho thấp - {{product_name}}',
 '<h1>Cảnh Báo Tồn Kho Thấp</h1><p>{{product_name}} ({{sku}}) sắp hết hàng. Tồn kho hiện tại: {{current_stock}}</p>',
 'Cảnh báo tồn kho thấp: {{product_name}} ({{sku}}) sắp hết hàng. Tồn kho hiện tại: {{current_stock}}',
 '["product_name", "sku", "current_stock", "location_name"]'::jsonb);

-- Insert default feature flags (Vietnamese)
INSERT INTO public.feature_flags (flag_key, name, description, is_enabled) VALUES
('b2b_pricing', 'Giá B2B', 'Kích hoạt tính năng giá sỉ B2B', true),
('inventory_management', 'Quản Lý Kho', 'Kích hoạt theo dõi và quản lý kho', true),
('email_notifications', 'Thông Báo Email', 'Gửi thông báo email cho người dùng', false),
('advanced_reporting', 'Báo Cáo Nâng Cao', 'Kích hoạt phân tích và báo cáo nâng cao', false),
('mobile_app', 'Hỗ Trợ Ứng Dụng Di Động', 'Kích hoạt các tính năng đặc biệt cho ứng dụng di động', false);

-- =============================================================================
-- VIEWS FOR SYSTEM MONITORING
-- =============================================================================

-- View for unread notifications by user
CREATE OR REPLACE VIEW public.user_notifications AS
SELECT 
  n.*,
  p.email as user_email,
  p.first_name || ' ' || p.last_name as user_name
FROM public.notifications n
JOIN public.profiles p ON n.user_id = p.id
WHERE n.is_read = FALSE
ORDER BY n.created_at DESC;

-- View for system activity summary
CREATE OR REPLACE VIEW public.system_activity_summary AS
SELECT 
  DATE_TRUNC('hour', created_at) as activity_hour,
  activity_type,
  COUNT(*) as activity_count,
  COUNT(DISTINCT user_id) as unique_users
FROM public.activity_logs
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', created_at), activity_type
ORDER BY activity_hour DESC;

-- =============================================================================
-- COMMENTS FOR DOCUMENTATION
-- =============================================================================
COMMENT ON TABLE public.notifications IS 'System notifications with multi-channel delivery support';
COMMENT ON TABLE public.audit_logs IS 'Complete audit trail for all system changes and user actions';
COMMENT ON TABLE public.system_settings IS 'Configurable application settings with type validation';
COMMENT ON TABLE public.activity_logs IS 'User activity tracking for analytics and monitoring';
COMMENT ON TABLE public.email_templates IS 'Dynamic email templates with variable substitution';
COMMENT ON TABLE public.scheduled_tasks IS 'Background job scheduling and execution tracking';
COMMENT ON TABLE public.api_keys IS 'API access key management with rate limiting';
COMMENT ON TABLE public.feature_flags IS 'Feature toggle system for gradual rollouts';

COMMENT ON COLUMN public.notifications.data IS 'Additional structured data for rich notifications';
COMMENT ON COLUMN public.audit_logs.changed_fields IS 'Array of field names that were modified';
COMMENT ON COLUMN public.system_settings.validation_rules IS 'JSON schema for validating setting values';
COMMENT ON COLUMN public.feature_flags.targeting_rules IS 'Rules for selective feature enablement';