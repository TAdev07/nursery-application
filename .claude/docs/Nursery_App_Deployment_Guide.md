# Hướng dẫn triển khai ứng dụng vườn ươm - Next.js 15 + Supabase

## 📋 Tổng quan dự án

### Mục tiêu
Xây dựng hệ thống web toàn diện cho vườn ươm hiện đại phục vụ cả B2C và B2B với các tính năng:
- **Catalog sản phẩm**: Quản lý cây cảnh với đặc tính riêng
- **Quản lý inventory**: Real-time tracking, seasonal management
- **B2B Features**: Wholesale pricing, bulk orders, credit management
- **Authentication**: Multi-role system với Supabase Auth

### Tech Stack (2025 Latest)
- **Framework**: Next.js 15 (App Router + Server Components)
- **React**: React 19 (with Compiler)
- **Database**: Supabase (PostgreSQL + Real-time + Auth)
- **Styling**: Tailwind CSS 4.0 Beta
- **State**: Zustand + TanStack Query v5
- **Deployment**: Vercel

### Ưu điểm stack này
✅ **Nhanh**: React 19 Compiler + Next.js 15 Turbopack
✅ **Rẻ**: Supabase free tier generous, Vercel free hosting
✅ **Scalable**: Auto-scaling serverless architecture
✅ **DX tốt**: TypeScript end-to-end, zero config setup

---

## 🗂️ Tài liệu chia theo module

### 📚 Danh sách tài liệu:

1. **[Project Setup & Environment]** (30 phút setup)
2. **[Database Schema & Supabase]** (2-3 giờ implement)
3. **[Authentication System]** (1-2 ngày)
4. **[Product Catalog]** (3-4 ngày)
5. **[Inventory Management]** (2-3 ngày)
6. **[Order System & B2B]** (4-5 ngày)
7. **[Frontend Components]** (5-7 ngày)
8. **[API Routes & Actions]** (2-3 ngày)
9. **[Testing & Deployment]** (1-2 ngày)
10. **[Performance & SEO]** (1-2 ngày)

### 🎯 Timeline tổng thể
- **Phase 1** (Tháng 1-4): Core features (MVP)
- **Phase 2** (Tháng 5-8): B2B enhancements
- **Phase 3** (Tháng 9-12): Advanced features & optimization

---

## 🚀 Quick Start (30 phút)

### Bước 1: Tạo project
```bash
# Create Next.js 15 project
npx create-next-app@latest nursery-app --typescript --tailwind --app

# Install core dependencies
cd nursery-app
npm install @supabase/supabase-js @supabase/auth-helpers-nextjs
npm install zustand @tanstack/react-query react-hook-form zod
npm install @radix-ui/react-* lucide-react date-fns
```

### Bước 2: Setup Supabase
1. Tạo project tại supabase.com
2. Copy URL + API keys vào `.env.local`
3. Enable Authentication providers
4. Setup RLS policies

### Bước 3: Project structure
```
nursery-app/
├── app/                    # Next.js App Router
├── components/             # React components
├── lib/                    # Utils, Supabase client
├── hooks/                  # Custom hooks
├── types/                  # TypeScript types
└── supabase/              # DB migrations, functions
```

---

## 📊 Database Design Highlights

### Core Tables
- **profiles**: User management với B2B/B2C roles
- **company_profiles**: B2B company information
- **products**: Plant catalog với plant-specific attributes
- **product_variants**: Sizes, containers, pricing tiers
- **inventory_stock**: Real-time stock tracking
- **orders**: Order management với B2B features

### Key Features
- **Plant Attributes**: Hardiness zones, care requirements, seasonal data
- **Inventory Tracking**: Multi-location, real-time updates
- **B2B Pricing**: Tiered pricing, credit limits, wholesale rates
- **Real-time**: WebSocket updates cho stock changes

---

## 🔐 Authentication Strategy

### User Types
- **B2C**: Individual customers
- **B2B**: Business customers (wholesale)
- **ADMIN**: System administrators
- **STAFF**: Nursery employees

### Features
- **Supabase Auth**: Email/password + OAuth (Google, Facebook)
- **Multi-tenancy**: Company profiles cho B2B
- **Role-based permissions**: Granular access control
- **Profile management**: Avatar upload, preferences

### Implementation
- AuthContext provider với custom hooks
- Middleware cho route protection
- RLS policies cho data security

---

## 🌱 Product Catalog Features

### Product Management
- **Plant-specific data**: Botanical names, care instructions, hardiness zones
- **Seasonal availability**: Planting seasons, bloom times
- **Multi-variant support**: Different sizes, container types
- **Image galleries**: Multiple photos, care guides
- **SEO optimization**: Meta tags, structured data

### Search & Filtering
- **Full-text search**: Name, botanical name, description
- **Advanced filters**: Plant type, sun/water requirements, price range
- **Category hierarchy**: Nested categories với breadcrumbs
- **Sort options**: Price, name, popularity, newest

### B2B Enhancements
- **Wholesale pricing**: Tiered pricing based on customer level
- **Bulk order tools**: CSV upload, quantity discounts
- **Custom pricing**: Special rates cho contract customers

---

## 📦 Inventory System

### Real-time Tracking
- **Multi-location**: Greenhouse, outdoor, storage areas
- **Live updates**: WebSocket notifications cho stock changes
- **Reservation system**: Hold inventory during checkout
- **Audit trail**: Complete movement history

### Business Logic
- **Seasonal management**: Availability based on planting seasons
- **Auto-reorder**: Low stock alerts và suggested quantities
- **Quality tracking**: Damage tracking, condition notes
- **Batch management**: Plant batches, expiry dates

---

## 🛒 Order Management

### B2C Features
- **Shopping cart**: Persistent cart, guest checkout
- **Order tracking**: Status updates, shipping notifications
- **Payment integration**: Stripe, PayPal support
- **Shipping calculation**: Weight-based, location-based rates

### B2B Enhancements
- **Approval workflows**: Manager approval cho large orders
- **Credit terms**: Net 30/60/90 payment terms
- **Purchase orders**: PO number tracking
- **Bulk discounts**: Volume-based pricing

---

## 🎨 Frontend Architecture

### Component Strategy
- **shadcn/ui**: Pre-built components với Radix + Tailwind
- **Server Components**: Static content, SEO optimization
- **Client Components**: Interactive features, real-time updates
- **Progressive enhancement**: Works without JavaScript

### State Management
- **Server state**: TanStack Query cho API calls
- **Client state**: Zustand cho UI state
- **Form state**: React Hook Form + Zod validation
- **Real-time**: Supabase subscriptions

### Performance
- **Image optimization**: Next.js Image với WebP/AVIF
- **Code splitting**: Route-based lazy loading
- **Caching**: Aggressive caching với revalidation
- **Core Web Vitals**: Target >90 performance scores

---

## 🔄 Development Workflow

### Git Strategy
- **Main**: Production-ready code
- **Develop**: Integration branch
- **Feature branches**: feature/task-name
- **Conventional commits**: feat, fix, docs, style

### Testing Strategy
- **Unit tests**: Vitest + Testing Library
- **Integration tests**: API route testing
- **E2E tests**: Playwright cho critical flows
- **Visual testing**: Storybook cho components

### Deployment
- **Vercel**: Auto-deploy từ Git
- **Preview deployments**: Mỗi PR có preview URL
- **Environment management**: Dev, staging, production
- **Monitoring**: Error tracking, performance monitoring

---

## 📈 Scaling Considerations

### Performance Optimization
- **Database indexing**: Query optimization
- **CDN**: Static asset delivery
- **Caching layers**: Redis cho frequent queries
- **Image optimization**: Multiple formats, sizes

### Business Growth
- **Multi-tenant**: Support multiple nurseries
- **API ecosystem**: Public API cho integrations
- **Mobile app**: React Native với shared logic
- **Analytics**: Business intelligence, reporting

---

## 🎯 Success Metrics

### Technical KPIs
- Page load time < 2s
- API response time < 200ms
- System uptime 99.9%
- Core Web Vitals > 90

### Business KPIs
- Conversion rate: B2C >2%, B2B >15%
- Customer retention >60%
- Average order value increase 20%
- Mobile traffic >40%

---

## 📋 Next Steps

1. **Đọc từng tài liệu module** theo thứ tự
2. **Setup development environment** (30 phút)
3. **Implement Phase 1 MVP** (4 tháng)
4. **Iterate based on feedback**

**Ready to build the future of nursery management! 🌱**