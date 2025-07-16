# Tài Liệu Database Schema - Hệ Thống Quản Lý Vườn Ươm

## Tổng Quan

Database schema này hỗ trợ hệ thống quản lý vườn ươm toàn diện với các tính năng chính sau:

- **Quản Lý Người Dùng**: Hồ sơ khách hàng B2C và B2B với kiểm soát truy cập theo vai trò
- **Danh Mục Sản Phẩm**: Danh mục phân cấp với thuộc tính đặc thù của cây trồng
- **Quản Lý Kho**: Theo dõi kho đa vị trí với cập nhật thời gian thực
- **Hệ Thống Đơn Hàng**: Chu trình đơn hàng hoàn chỉnh với hỗ trợ giá B2B
- **Thông Báo**: Hệ thống thông báo đa kênh
- **Kiểm Toán & Phân Tích**: Theo dõi kiểm toán và hoạt động hoàn chỉnh

## Database Structure

### Core Tables (31 total)

#### Authentication & User Management

- `profiles` - User profiles extending Supabase auth
- `company_profiles` - B2B company information
- `roles` - System roles and permissions
- `user_roles` - User-role assignments

#### Product Catalog

- `categories` - Hierarchical product categories
- `products` - Main products with plant-specific attributes
- `product_variants` - Size and container variations
- `product_images` - Product image gallery

#### Inventory Management

- `inventory_locations` - Storage locations (greenhouses, outdoor areas)
- `inventory_stock` - Real-time stock levels per location
- `stock_movements` - Complete inventory audit trail
- `stock_adjustment_requests` - Workflow for inventory adjustments
- `stock_transfer_requests` - Inter-location transfers
- `stock_transfer_items` - Transfer line items

#### Order System

- `orders` - Order headers with B2B/B2C support
- `order_items` - Order line items with fulfillment tracking
- `order_status_history` - Order status change audit trail
- `shipping_addresses` - Customer shipping addresses
- `payment_transactions` - Payment processing records
- `pricing_tiers` - B2B pricing levels
- `discount_codes` - Promotional codes
- `discount_code_usage` - Discount usage tracking

#### Supporting Systems

- `notifications` - Multi-channel notifications
- `audit_logs` - System-wide audit trail
- `system_settings` - Application configuration
- `activity_logs` - User activity tracking
- `email_templates` - Dynamic email templates
- `scheduled_tasks` - Background job management
- `api_keys` - API access management
- `feature_flags` - Feature toggle system

## Key Features

### 1. Plant-Specific Attributes

Products include comprehensive plant data:

- Botanical names and common names
- Growing requirements (sun, water, soil)
- Physical characteristics (mature size, growth rate)
- Care instructions and difficulty level
- Seasonal information (bloom time, colors)
- USDA hardiness zones

### 2. Hierarchical Categories

Categories support unlimited nesting with:

- Materialized path for efficient queries
- Automatic depth calculation
- SEO-friendly slugs

### 3. Multi-Location Inventory

- Real-time stock tracking across multiple locations
- Automatic allocation and reorder alerts
- Complete movement audit trail
- Support for negative stock (configurable)

### 4. B2B Features

- Company profiles with credit limits
- Tiered pricing structure
- Extended payment terms
- Wholesale pricing
- Purchase order tracking

### 5. Automated Business Logic

Triggers handle:

- Inventory updates on stock movements
- Order status progression
- Low stock alerts
- Audit logging
- Notification delivery

### 6. Performance Optimization

- Comprehensive indexing strategy
- Materialized views for reporting
- Full-text search capabilities
- JSONB support for flexible attributes

## Security

### Row Level Security (RLS)

All tables implement RLS policies:

- Users can only access their own data
- Staff/admin roles have elevated permissions
- B2B customers access company-scoped data

### Data Validation

- Check constraints for data integrity
- Foreign key constraints with appropriate cascading
- Business rule validation via triggers

## Sample Data

The schema includes sample data for:

- Default categories (trees, shrubs, perennials, etc.)
- Inventory locations (greenhouses, outdoor areas)
- Pricing tiers (retail to wholesale)
- System settings
- Email templates
- Feature flags

## Migration Files

1. `20250716022800_create_core_tables.sql` - User management tables
2. `20250716023000_create_product_catalog_tables.sql` - Product and category tables
3. `20250716023150_fix_inventory_constraints.sql` - Fix inventory constraints (QUAN TRỌNG)
4. `20250716023200_create_inventory_management_tables.sql` - Inventory tracking
5. `20250716023400_create_order_system_tables.sql` - Order and payment tables
6. `20250716023600_create_supporting_tables.sql` - Notifications and system tables
7. `20250716023800_additional_indexes_constraints.sql` - Performance optimization
8. `20250716024000_business_logic_triggers.sql` - Automated business logic
9. `20250716024200_verify_schema.sql` - Schema verification and testing

## Usage Instructions

### Local Development

```bash
# If you have Supabase CLI installed:
supabase start
supabase db reset

# Manual execution (in order):
# Execute each migration file in your PostgreSQL database
```

### Hướng Dẫn Migration Thủ Công trên Supabase Dashboard

#### Bước 1: Tạo Project Supabase

1. Truy cập [supabase.com](https://supabase.com) và đăng nhập
2. Nhấn **"New Project"**
3. Điền thông tin:
   - **Project Name**: `nursery-management`
   - **Database Password**: Tạo mật khẩu mạnh (lưu lại cẩn thận)
   - **Region**: `Southeast Asia (Singapore)` (gần Việt Nam nhất)
4. Nhấn **"Create new project"** và đợi khởi tạo (2-3 phút)

#### Bước 2: Cấu Hình Môi Trường

1. Vào **Settings** > **API** trong dashboard
2. Copy các thông tin sau vào file `.env.local`:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project-ref.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
```

#### Bước 3: Thực Thi Migration Files (QUAN TRỌNG: Theo đúng thứ tự)

**Bước 3.1**: Vào **SQL Editor** trong Supabase Dashboard

**Bước 3.2**: Chạy từng migration file theo thứ tự:

1️⃣ **File đầu tiên**: `20250716022800_create_core_tables.sql`

- Copy toàn bộ nội dung file
- Paste vào SQL Editor
- Nhấn **"Run"**
- Đợi hoàn thành (khoảng 30 giây)

2️⃣ **File thứ hai**: `20250716023000_create_product_catalog_tables.sql`

- Làm tương tự như bước 1
- Đảm bảo không có lỗi trước khi tiếp tục

3️⃣ **File thứ ba**: `20250716023150_fix_inventory_constraints.sql`

- Chạy file fix constraints trước

4️⃣ **File thứ tư**: `20250716023200_create_inventory_management_tables.sql`

- Chạy file inventory management

5️⃣ **File thứ năm**: `20250716023400_create_order_system_tables.sql`

- Chạy file hệ thống đơn hàng

6️⃣ **File thứ sáu**: `20250716023600_create_supporting_tables.sql`

- Chạy file hỗ trợ

7️⃣ **File thứ bảy**: `20250716023800_additional_indexes_constraints.sql`

- Chạy file indexes và constraints

8️⃣ **File thứ tám**: `20250716024000_business_logic_triggers.sql`

- Chạy file business triggers

9️⃣ **File cuối cùng**: `20250716024200_verify_schema.sql`

- Chạy file verification

#### Bước 4: Kiểm Tra Schema

Sau khi chạy xong tất cả migrations, chạy lệnh verification:

```sql
SELECT public.generate_verification_report();
```

Kết quả sẽ hiển thị báo cáo chi tiết về:

- ✅ Tất cả bảng đã được tạo (31 bảng)
- ✅ Foreign key constraints hoạt động
- ✅ Indexes được tạo thành công
- ✅ Triggers hoạt động bình thường
- ✅ Sample data được insert

#### Bước 5: Cấu Hình Authentication (Tùy chọn)

1. Vào **Authentication** > **Settings**
2. Cấu hình:
   - **Site URL**: `http://localhost:3000` (development)
   - **Redirect URLs**: `http://localhost:3000/auth/callback`
3. Enable providers cần thiết (Email, Google, etc.)

#### Bước 6: Cấu Hình Storage (Tùy chọn)

1. Vào **Storage**
2. Tạo buckets:
   - `product-images` (public)
   - `avatars` (public)

#### Bước 7: Enable Real-time (Đã được cấu hình sẵn)

Các bảng sau đã được enable real-time:

- `inventory_stock` - Theo dõi stock real-time
- `orders` - Cập nhật đơn hàng real-time
- `notifications` - Thông báo real-time

#### Bước 8: Test Kết Nối

Chạy test functions để đảm bảo mọi thứ hoạt động:

```sql
-- Test CRUD operations
SELECT * FROM public.test_basic_crud();

-- Test business triggers
SELECT * FROM public.test_business_triggers();

-- Test performance
SELECT * FROM public.test_query_performance();
```

### Lưu Ý Quan Trọng

- ⚠️ **PHẢI chạy migrations theo đúng thứ tự**
- ⚠️ **Không bỏ qua bất kỳ file nào**
- ⚠️ **Kiểm tra lỗi sau mỗi file trước khi tiếp tục**
- ⚠️ **Backup database trước khi chạy migrations**

### Các Function Chính

- `public.generate_verification_report()` - Kiểm tra schema toàn diện
- `public.test_basic_crud()` - Test các thao tác cơ bản
- `public.test_business_triggers()` - Test logic nghiệp vụ
- `public.refresh_materialized_views()` - Cập nhật views báo cáo

## Giám Sát & Monitoring

### Performance Views

- `public.mv_product_catalog` - Danh mục sản phẩm tối ưu
- `public.mv_inventory_summary` - Dữ liệu dashboard kho
- `public.current_stock_summary` - Trạng thái stock real-time
- `public.order_summary` - Phân tích đơn hàng

### Maintenance Functions

- `public.cleanup_old_records()` - Dọn dẹp dữ liệu audit cũ
- `public.get_unused_indexes()` - Tìm indexes không sử dụng
- `public.analyze_table_performance()` - Phân tích hiệu suất

## Thực Hành Tốt Nhất

1. **Bảo Trì Định Kỳ**
   - Refresh materialized views trong giờ ít traffic
   - Giám sát sử dụng index và xóa index không dùng
   - Archive logs audit cũ

2. **Hiệu Suất**
   - Sử dụng materialized views cho queries báo cáo
   - Tận dụng full-text search indexes
   - Giám sát queries chậm

3. **Bảo Mật**
   - Xem xét RLS policies định kỳ
   - Audit quyền người dùng
   - Giám sát hoạt động đáng ngờ

4. **Tính Toàn Vẹn Dữ Liệu**
   - Validate business rules qua triggers
   - Sử dụng constraints phù hợp
   - Implement error handling đúng cách

## Hỗ Trợ

Để có câu hỏi về database schema:

1. Xem lại migration files để hiểu cấu trúc bảng chi tiết
2. Kiểm tra verification functions để có ví dụ
3. Tham khảo documentation và comments inline
4. Xem audit logs để troubleshoot
