# Audit và kế hoạch chuyển sang monorepo

Ngày: 2026-10-16. Yêu cầu của grace: audit toàn bộ dự án, đề xuất kế hoạch refactor sang monorepo (mỗi sản phẩm Web, CMS, Mobile là một app, phần dùng chung ở `packages/`), lấy Feature-First làm cấu trúc chính, chỉ dùng Ports & Adapters ở chỗ nghiệp vụ phức tạp hoặc phụ thuộc dịch vụ ngoài. **Tài liệu này không đổi code.** Mọi số liệu đo trên `main` commit `0cde6de` bằng quét tĩnh (grep, đếm dòng); chưa chạy thử bước nào của kế hoạch.

Đọc kèm: [danh-gia-kien-truc.md](danh-gia-kien-truc.md) (kết luận Nuxt + Supabase là đủ), [ke-hoach-sua-kien-truc.md](ke-hoach-sua-kien-truc.md), PR #53 (NestJS và app, đang hoãn).

## 1. Trả lời ngắn

- **Nên làm, nhưng làm theo nấc và dừng được ở bất kỳ nấc nào.** Phần đáng giá nhất (gom code theo feature, tách phần TypeScript thuần ra `packages/core` để app sau này dùng lại) rẻ và có ích ngay. Phần đắt nhất (tách admin thành app CMS riêng) có lợi ít hơn mình tưởng, nên để làm khi có lý do cụ thể.
- **Không cần Hexagonal cho phần lớn module.** Nghiệp vụ thật (hóa đơn, trừ kho FEFO, ca thu ngân, lưu trú, bệnh án) nằm trong RPC Postgres. Phía TypeScript chỉ gọi RPC và hiển thị, nên bọc thêm port/adapter ở POS, kho, y tế chỉ là thêm file mà không thêm an toàn. Repository hiện tại đã nhận `client` làm tham số, đó chính là "cổng" đủ dùng.
- **Ports & Adapters chỉ ở 4 chỗ dính dịch vụ ngoài:** vận chuyển (GHN), thanh toán (SePay/VietQR, khi làm), lưu file (ảnh, đính kèm y tế, vì app mobile upload khác web), gửi thông báo (khi có kênh).
- **Database và `supabase/` giữ nguyên ở gốc repo.** Workflow tự chạy migration, backup, CI SQL không phải đổi.
- **Công cụ: npm workspaces, chưa cần Turborepo, chưa đổi sang pnpm.**
- App mobile là giai đoạn sau. Quy tắc quan trọng nhất cho nó phải áp dụng từ bây giờ: `packages/core` không được import Vue, Nuxt, Pinia hay DOM, để sau này React Native hay Capacitor đều dùng lại được.

## 2. Hiện trạng đo được

### 2.1 Kích thước

| Thư mục | File `.ts/.vue` | Dòng | Ghi chú |
| --- | --- | --- | --- |
| `src/views/admin` | 476 | 28.199 | 13 module: medical 4.157, pets 4.474, pos 3.084, boarding 3.079, products 2.836, settings 2.499, inventory 2.186, reports 1.822, schedule 1.606, users 1.249, shop-orders 916, dashboard 233 |
| `src/views/client` + `home` + `auth` | 99 | 4.493 | Shop công khai, tài khoản khách, đăng nhập |
| `src/components/ui` | 257 | 5.761 | shadcn-vue trên reka-ui |
| `src/components/common` | 53 | 3.825 | PagedTableCard, AppDialog, SearchView, data-io... |
| `src/components/shop` + `layout/client` | 28 | 1.061 | Khung và thẻ của shop |
| `src/repositories` | 98 | 7.535 | Gọi Supabase, TS thuần |
| `src/queries` | 55 | 3.344 | TanStack Query (Vue) |
| `src/types` | 26 | 4.697 | Trong đó `database.types.ts` 3.182 dòng (sinh tự động) |
| `src/composables`, `utils`, `lib`, `stores`, `validations` | 100 | 4.956 | |
| `server/api/ghn` | 7 | 158 | Proxy GHN giữ token |
| `supabase/` | 122 migration, 6 file test, 1 edge function | | Nghiệp vụ chính |
| `src/i18n/locales/*.json` | 2 | 3.396 mỗi file | Một file chung cho admin và shop |

**Admin chiếm khoảng 85% code giao diện.** Phần khách hàng nhỏ (khoảng 5.500 dòng kể cả component shop).

### 2.2 Cách code đang chia lớp

```
pages/ (vỏ mỏng) → views/<admin|client>/<module>/ (component + composable của màn)
                  → queries/<module>.ts (TanStack Query, khóa cache ở queries/keys.ts)
                  → repositories/<module>/ (TS thuần, nhận SupabaseClient)
                  → RPC Postgres + RLS
```

Đây là chia theo **lớp** (horizontal): muốn sửa một module, ví dụ lưu trú, phải mở `views/admin/boarding`, `queries/boarding/`, `repositories/boarding/`, `types/boarding/`, `types/boardingWeb.ts`, `queries/boardingWeb.ts`, `queries/accountBoarding.ts`. Riêng `views/admin/<module>` thì đã gần feature-first.

### 2.3 Ranh giới hiện tại, đo bằng import

| Kiểm tra | Kết quả | Đánh giá |
| --- | --- | --- |
| `repositories/` import Vue, Nuxt, Pinia, `#imports`, store, query | **0 file** | Rất tốt. Đây là nền để tách `packages/core`. |
| `repositories/` dùng `window`, `document`, `localStorage` | 0 | Tốt. Riêng `repositories/storage.ts` nhận `File` của trình duyệt (xem mục 5). |
| Chỗ duy nhất gọi `useSupabaseClient` | `src/lib/supabase.ts` | Tốt: đổi cách tạo client chỉ sửa một chỗ. |
| `repositories/` import kiểu từ `views/admin/...` | 4 dòng: `productImport.ts`, `dataImports.ts` (kiểu dòng nhập Excel) | **Ngược chiều**, phải sửa trước. |
| `queries/` import từ `views/` | 3 dòng (cùng các kiểu nhập Excel) | Ngược chiều. |
| `views/admin` import `views/client` | 2 file dùng `OrderStatusBadge.vue` (`shop-orders/orders/components/OrderRow.vue`, `OrderSheet.vue`) | Sẽ gãy khi tách app. Chuyển badge vào UI dùng chung. |
| `types/index.ts` import `lib/constants`; `types/vue-router.d.ts` import `lib/access` | 2 | Nhỏ, sửa khi chuyển. |
| View/component import thẳng `repositories` (không qua `queries`) | 66 import có giá trị (233 file nếu tính `import type`) | Chủ yếu để lấy **hằng số và quy tắc** (`isExpired`, `businessDate`, `DOC_STATUSES`, `USER_SORT`) và hàm xuất Excel. Quy tắc nghiệp vụ đang nằm lẫn trong lớp truy cập dữ liệu. |

### 2.4 Phần dùng chung giữa shop và admin hôm nay

- `queries/` dùng cả hai phía: chỉ `branches`, `productCategories`, `products`. Còn lại tách sạch: phía khách dùng `account*`, `shop*`, `spaCatalog`, `spaWeb`, `boardingWeb`, `ghnLocations`; admin dùng phần còn lại.
- Component: phía khách dùng 11 component `ui/` (chủ yếu `button`, `label`, `input`, `sheet`, `dialog`) và 7 component `common/` (`AppDialog`, `TablePager`, `LoadingIndicator`, `InputPassword`, `VerifyEmailCode`, `GhnLocationPicker`, `ScrollSentinel`).
- Store: `auth` dùng cả hai, nhưng trộn phần đăng nhập chung với quyền admin (`loadAdminGrants`). `cart` chỉ shop.
- `composables/shop/` trộn: `useShopSettingsForm`, `useShippingTest`, `useOrderSheet`, `useOrdersPage` là của admin (màn "Bán online").
- i18n: một file 3.396 dòng, khóa gốc `adminNav`, `pos`, `inventory`, `medical`, `rbac`... (admin) nằm chung với `shop`, `client`, `seo` (shop).
- GHN: `server/api/ghn/*` dùng ở cả checkout của khách và màn cài đặt/thử phí ở admin.

### 2.5 Code chết hoặc nợ nhỏ thấy khi audit

- `src/components/Vouchers/CardVoucher.vue`: không file nào import.
- `src/data/`, một phần `src/assets/flags`: rỗng hoặc chưa kiểm.
- `src/lib/utils.ts` (174 dòng) có nhiều hàm `any` cũ (`getUniquePermissions`, `matchingTwoObject`, `reduceData`) cần kiểm còn dùng không. `src/lib/constants.ts` (170 dòng) là kho hằng số chung của nhiều module.
- `vue-multiselect`, `lodash-es`, `vue-zoomable` mỗi gói chỉ dùng ở 1 file.
- Tên package vẫn là `beer-sys`.

## 3. Giữ, tách, chuyển, viết lại

| Hành động | Cái gì | Đường dẫn hiện tại | Đi đâu |
| --- | --- | --- | --- |
| **Giữ nguyên** | Toàn bộ database: migration, test pgTAP, `schema.sql`, edge function, template email | `supabase/` | Giữ ở gốc repo, mọi app dùng chung một project Supabase |
| Giữ | Nghiệp vụ trong RPC + RLS | `supabase/migrations` | Không đưa nghiệp vụ lên TypeScript |
| Giữ | Mẫu repository nhận `client` | `src/repositories/**` | Chuyển nguyên vào `packages/core` |
| Giữ | `parseRpc`, `unwrap`, `pageRange`, mã lỗi Postgres | `src/repositories/shared.ts` | `packages/core/src/shared/` |
| Giữ | Quyền giao diện thuần | `src/lib/access.ts` | `packages/core/src/auth/access.ts` |
| Giữ | Bộ nhập/xuất Excel/CSV/PDF | `src/lib/data-io`, `components/common/data-io` | Chỉ CMS dùng, vào feature `data-io` của CMS |
| **Tách** | Quy tắc và hằng số đang nằm trong repository | `repositories/inventory/index.ts` (`isExpired`, `businessDate`, `STOCK_STATUSES`, `DOC_TYPES`), `repositories/users.ts` (`USER_SORT`)... | `core/<feature>/model.ts` (kiểu, hằng số) và `rules.ts` (hàm thuần); `repo.ts` chỉ còn gọi Supabase |
| Tách | Store `auth` | `src/stores/modules/auth.ts` (294 dòng) + `auth-parts/` | Phần phiên đăng nhập và hồ sơ: dùng chung (layer). `adminGrants`: CMS |
| Tách | i18n | `src/i18n/locales/*.json` | Khóa chung (`common`, `validation`, `locale`) trong layer; khóa admin vào CMS; khóa shop vào Web |
| Tách | `lib/constants.ts`, `lib/utils.ts` | `src/lib/` | Theo feature; `cn()` vào UI; hàm format tiền, ngày vào `core/shared/format.ts` |
| Tách | `composables/shop` | `src/composables/shop/` | Phần admin (`useShopSettingsForm`, `useShippingTest`, `useOrderSheet`, `useOrdersPage`) sang CMS |
| **Chuyển** | Kiểu dữ liệu | `src/types/*.ts` | `core/<feature>/model.ts`; `database.types.ts` vào `core/src/db/` |
| Chuyển | Schema zod | `src/validations/*.ts` | `core/<feature>/schemas.ts` |
| Chuyển | Queries | `src/queries/*.ts` | Khóa cache và hàm lấy dữ liệu vào `core/<feature>/queries.ts` (không Vue); `useQuery` bọc mỏng nằm trong feature của từng app |
| Chuyển | Màn admin | `src/views/admin/<module>/` | `apps/cms/app/features/<module>/` |
| Chuyển | Màn khách | `src/views/client/**`, `views/home`, `components/shop`, `layout/client` | `apps/web/app/features/<module>/` |
| Chuyển | UI dùng chung | `components/ui`, phần chung của `components/common`, `assets/*.css`, phần chung `tailwind.config.js` | `packages/nuxt-base` (Nuxt layer) |
| Chuyển | `OrderStatusBadge.vue` | `views/client/orders/components/` | `packages/nuxt-base` (hai app cùng dùng) |
| Chuyển | Proxy GHN | `server/api/ghn`, `server/utils` | `packages/nuxt-base/server` trước; edge function khi làm mobile (mục 5.1) |
| Chuyển | Kiểu dòng nhập Excel | `views/admin/products/import/importTypes.ts`, `exportSheets.ts`, `views/admin/pets/import/petsImportRow.ts`, `views/admin/inventory/suppliers/import/suppliersImportRow.ts` | `core/<feature>/import.ts` (sửa 7 import ngược chiều) |
| **Viết lại** | `src/services/location.service.ts`, `shipment.service.ts` | `src/services/` | Thành adapter GHN theo port vận chuyển (mục 5.1); bỏ `any` |
| Viết lại (nhỏ) | Ô chọn dùng `vue-multiselect` | `views/admin/users/components/CustomerGroupsStep.vue` | Dùng combobox reka-ui đã có, gỡ gói |
| **Xóa** | Code chết | `components/Vouchers`, `src/data`, hàm `any` không dùng trong `lib/utils.ts` | Xác nhận bằng `knip` trước khi xóa |

Không có module nào cần viết lại từ đầu. Code mới nhất (POS, kho, lưu trú, y tế) đã chia file nhỏ và tách repository.

## 4. Cấu trúc đề xuất

```
bong-cun/
├─ package.json                 # workspace gốc: "workspaces": ["apps/*", "packages/*"]
├─ supabase/                    # GIỮ NGUYÊN (migrations, tests, functions, schema.sql)
├─ docs/
├─ .github/workflows/           # ci.yml chạy theo workspace; supabase-*.yml không đổi
├─ apps/
│  ├─ web/                      # Nuxt: shop công khai (SSR) + tài khoản khách
│  │  ├─ nuxt.config.ts         # extends: ["../../packages/nuxt-base"]
│  │  └─ app/
│  │     ├─ pages/              # vỏ mỏng, chỉ ghép component của feature
│  │     ├─ layouts/
│  │     ├─ middleware/
│  │     └─ features/
│  │        ├─ catalog/         # danh sách, chi tiết sản phẩm
│  │        ├─ cart/  checkout/  orders/
│  │        ├─ spa-booking/  boarding/
│  │        └─ account/         # hồ sơ, thú cưng của tôi, sổ sức khỏe
│  ├─ cms/                      # Nuxt SPA (ssr: false): admin
│  │  └─ app/
│  │     ├─ pages/  layouts/  middleware/
│  │     └─ features/
│  │        ├─ pos/  inventory/  products/  pets/  spa/  boarding/  medical/
│  │        ├─ shop-orders/  reports/  users/  settings/  dashboard/
│  │        └─ data-io/
│  └─ mobile/                   # GIAI ĐOẠN SAU (mục 7, quyết định Q3)
└─ packages/
   ├─ core/                     # TS thuần: KHÔNG Vue/Nuxt/Pinia/DOM
   │  └─ src/
   │     ├─ db/                 # database.types.ts (sinh), type Db = SupabaseClient<Database>
   │     ├─ shared/             # unwrap, parseRpc, pageRange, format tiền/ngày, mã lỗi
   │     ├─ auth/               # access.ts, kiểu role
   │     ├─ ports/              # interface cho dịch vụ ngoài (mục 5)
   │     └─ <feature>/          # pos, inventory, products, medical, boarding, spa, shop, ...
   │        ├─ model.ts         # kiểu, hằng số, trạng thái
   │        ├─ rules.ts         # hàm thuần (isExpired, tính giá theo cân nặng...)
   │        ├─ schemas.ts       # zod (form + parse kết quả RPC jsonb)
   │        ├─ repo.ts          # gọi Supabase (có thể là thư mục nếu > 300 dòng)
   │        ├─ queries.ts       # khóa cache + queryFn, không phụ thuộc framework
   │        └─ index.ts         # API công khai của feature
   ├─ nuxt-base/                # Nuxt layer dùng chung cho web và cms
   │  ├─ nuxt.config.ts         # modules supabase, i18n, pinia, vueuse; css; tailwind
   │  ├─ components/ui/         # shadcn-vue
   │  ├─ components/common/     # AppDialog, PagedTableCard, SearchView, TablePager...
   │  ├─ composables/           # useAuthSession, usePagedList, useListFilters...
   │  ├─ plugins/vue-query.ts
   │  ├─ server/api/ghn/        # proxy GHN (tới khi chuyển sang edge function)
   │  └─ i18n/                  # khóa chung
   └─ config/                   # tsconfig gốc, tailwind preset, token màu (JSON)
```

**Vì sao chỉ 3 package.** Có thể tách `core` thành `types`, `domain`, `api`, `validation` riêng, nhưng mỗi package thêm một `package.json`, một lần build và một chỗ phải giữ phiên bản. Với một người làm, một package `core` chia thư mục theo feature và xuất theo đường con (`@bongcun/core/pos`) cho cùng ranh giới mà rẻ hơn nhiều. Tách thêm khi một phần thật sự cần phát hành riêng.

**Feature trong app** có dạng:

```
features/boarding/
├─ components/       # .vue nhỏ, chỉ hiển thị
├─ composables/      # useStayDetail, useKennelBoard... (state, gọi query)
├─ queries.ts        # useQuery/useMutation bọc core/boarding/queries.ts
├─ utils.ts          # hàm thuần chỉ màn này dùng
├─ types.ts          # kiểu chỉ của giao diện (props, form)
└─ index.ts          # những gì page và feature khác được dùng
```

Quy tắc chia file của dự án (dưới khoảng 300 dòng, page là vỏ, logic trong `useXxx`) giữ nguyên trong mọi feature.

## 5. Ports & Adapters: chỉ ở đâu, và vì sao không ở chỗ khác

| Feature | Dùng port? | Lý do |
| --- | --- | --- |
| POS, kho, sản phẩm, spa, lưu trú, y tế, báo cáo, quyền | **Không** | Nghiệp vụ ở RPC, có test pgTAP. TS chỉ map dữ liệu. Repository đã nhận `client` qua tham số, test được bằng client giả nếu cần. Thêm interface + adapter ở đây là gấp đôi file mà không đổi được gì. |
| **Vận chuyển (GHN)** | **Có** | Dịch vụ ngoài, có token bí mật, có phương án dự phòng (phí cố định), sau này có thể thêm hãng khác. |
| **Thanh toán (SePay/VietQR)** | **Có, khi làm** | Bước 9 đến 11 của checkout chưa làm. Webhook và đối soát cần chỗ thay được nhà cung cấp. |
| **Lưu file** (ảnh sản phẩm, đính kèm y tế) | **Có, ở giai đoạn mobile** | Web upload `File`, React Native upload URI. `repositories/storage.ts` hiện nhận `File`. |
| **Thông báo** (nhắc lịch tiêm, lô sắp hết hạn) | **Có, khi có kênh** | Zalo/SMS/email/push đều là dịch vụ ngoài. |
| Xuất/nhập Excel, in hóa đơn | Không | Chỉ CMS dùng, chỉ một cách làm. Để trong feature `data-io` của CMS. |

### 5.1 Ví dụ cụ thể: vận chuyển

```ts
// packages/core/src/ports/shipping.ts
export type ShippingQuoteRequest = { fromDistrictId: number; fromWardCode: string;
  toDistrictId: number; toWardCode: string; weightG: number };
export type ShippingQuote = { fee: number; leadTimeDays?: number };
export interface ShippingProvider {
  quote(req: ShippingQuoteRequest): Promise<ShippingQuote>; // ném ShippingQuoteError
  provinces(): Promise<Province[]>;
  districts(provinceId: number): Promise<District[]>;
  wards(districtId: number): Promise<Ward[]>;
}

// packages/core/src/shop/rules.ts: chọn phí GHN hoặc phí cố định khi lỗi (đang nằm ở composable)
// apps/web, apps/cms: adapter gọi /api/ghn/* (code của src/services/*.ts hiện nay)
// apps/mobile (sau): adapter gọi edge function `ghn` của Supabase
```

Khi có app mobile, proxy GHN nên chuyển từ `server/api/ghn` (Nitro trên Vercel) sang một edge function Supabase, để web, CMS và mobile cùng gọi một chỗ và token chỉ nằm ở Supabase secrets. Trước đó giữ trong layer `nuxt-base` cho rẻ.

## 6. Quy tắc dependency

```
apps/web ─┐                  apps/mobile ─┐
apps/cms ─┼─► packages/nuxt-base ─► packages/core ─► (supabase-js, zod, date-fns)
          └──────────────────────────►┘           ▲
                                      apps/mobile ┘ (không dùng nuxt-base)
```

1. `apps/*` được import `packages/*`. **Không** chiều ngược lại, và **app không import app**.
2. `packages/core` chỉ phụ thuộc `@supabase/supabase-js` (kiểu và client), `zod`, `date-fns`. Cấm `vue`, `nuxt`, `#imports`, `pinia`, `@tanstack/vue-query`, `window`, `document`, `process.env`.
3. Trong `core`, feature A dùng feature B chỉ qua `core/B/index.ts`, không vào file bên trong. Cạnh được phép khai báo rõ, ví dụ `pos → products, inventory, shared`; `medical → pos, products, inventory`; `boarding → pos`. Không vòng.
4. Trong app, `features/A` dùng `features/B` chỉ qua `index.ts`. `pages/` được import `features/*`, không ngược lại.
5. Import sâu vào package bị cấm: dùng `@bongcun/core/pos`, không `@bongcun/core/src/pos/repo`. `package.json` của `core` khai `exports` theo đường con để chặn từ gốc.
6. Biến môi trường chỉ đọc ở app (`runtimeConfig`), truyền vào core qua tham số.

**Kiểm tự động:** thêm `dependency-cruiser` vào CI với các luật trên (một file cấu hình, không cần dựng ESLint). Đây là thứ giữ ranh giới không bị mòn sau vài tuần; không có nó thì quy tắc chỉ nằm trên giấy.

## 7. Chiến lược chia sẻ code

| Loại | Cách chia | Ghi chú |
| --- | --- | --- |
| Kiểu DB | `packages/core/src/db/database.types.ts`, sinh bằng `supabase gen types typescript --local` | Thêm bước CI kiểm file này khớp migration, giống `schema.sql` |
| Supabase client | `core` chỉ khai `type Db = SupabaseClient<Database>`. Mỗi app tự tạo client: web/CMS qua `@nuxtjs/supabase` (cookie), mobile qua `createClient` với AsyncStorage | Đúng như `src/lib/supabase.ts` hiện tại, chỉ là bên nhận |
| Kiểu kết quả RPC `jsonb` | Schema zod trong `core/<feature>/schemas.ts`, kiểu suy từ `z.infer` | Một nguồn cho cả kiểu và kiểm tra lúc chạy (đã bắt đầu ở `parseRpc`) |
| Validation form | Schema zod trong `core`, thông báo lỗi là khóa i18n; app gắn vào vee-validate (Vue) hay react-hook-form (RN) | |
| Truy vấn | `core/<feature>/queries.ts` trả `{ queryKey, queryFn }` thuần; Vue bọc bằng `useQuery(...)`, React bọc bằng `useQuery(...)` của `@tanstack/react-query` | Khóa cache và luật làm mới (`invalidatePos`...) dùng chung, không viết hai lần |
| Quy tắc nghiệp vụ phía client | `core/<feature>/rules.ts` | Ví dụ giá theo cân nặng, hạn dùng, trạng thái đơn |
| UI | Vue dùng chung qua layer `nuxt-base`. Mobile **không** dùng chung component | Chỉ chia token màu, font, khoảng cách qua `packages/config` (JSON) |
| i18n | Khóa chung trong layer, khóa riêng theo app | Mobile đọc cùng JSON nếu cần |

## 8. Lộ trình

Mỗi giai đoạn là một hoặc vài PR, merge xong app vẫn chạy như cũ. **Sau giai đoạn 3 có thể dừng lâu mà không bị nửa vời.**

### Giai đoạn 0: Dọn ranh giới (1 PR, rủi ro thấp)

- Sửa 7 import ngược chiều (repository/query lấy kiểu từ `views/`): chuyển các kiểu dòng nhập Excel sang cạnh repository.
- Chuyển `OrderStatusBadge.vue` sang `components/common`.
- Chạy `knip` để liệt kê code và gói không dùng; xóa `components/Vouchers`, `src/data` và hàm chết đã xác nhận. Gỡ `vue-multiselect`.
- Thêm `dependency-cruiser` vào CI với luật cho cấu trúc hiện tại (`repositories` không import `views`, `queries`, `vue`).
- Kiểm: typecheck, build, CI xanh. Không đổi hành vi.

### Giai đoạn 1: Dựng workspace, chuyển app vào `apps/web` (1 PR, cần đóng băng ngắn)

- `git mv` toàn bộ app (`src`, `server`, `public`, `nuxt.config.ts`, `tailwind.config.js`, `components.json`...) vào `apps/web/`. `package.json` gốc thành workspace root, đổi tên package khỏi `beer-sys`.
- Lúc này `apps/web` vẫn chứa cả admin. Chưa tách gì.
- `ci.yml`: `npm ci` ở gốc, `npm run type-check -w apps/web`, `npm run build -w apps/web`. Job `db` không đổi.
- `supabase/` không di chuyển, nên `supabase-migrate.yml`, `supabase-backup.yml`, `supabase-mark-applied.yml` không đổi.
- **grace phải làm một việc trên Vercel:** Project Settings > Root Directory đổi thành `apps/web` (`vercel.json` không đặt được mục này). Nếu quên, bản deploy đầu sẽ lỗi build, bản cũ vẫn chạy.
- Rủi ro: mọi nhánh đang mở sẽ xung đột vì đổi đường dẫn. Chỉ làm khi không có thread nào đang code.

### Giai đoạn 2: Tách `packages/core` theo từng feature (khoảng 8 đến 10 PR nhỏ)

- PR đầu: tạo `packages/core` với `db/`, `shared/`, `auth/`; đặt alias để `apps/web` import `@bongcun/core/...`. Đổi lệnh sinh kiểu DB sang đường mới.
- Mỗi PR sau một feature, theo thứ tự ít phụ thuộc trước: `branches`/`users`/`permissions` → `products` → `inventory` → `pos` → `spa` → `boarding` → `medical` → `shop` → `reports`.
- Trong mỗi PR: chuyển `types/<f>`, `validations/<f>`, `repositories/<f>` vào `core/<f>/`, tách hằng số và hàm thuần ra `model.ts`/`rules.ts`, chuyển khóa cache và `queryFn` từ `queries/<f>` sang `core/<f>/queries.ts`. Sửa import bằng codemod (`jscodeshift` hoặc script `sed` có kiểm), không sửa tay từng file.
- Thêm vài test Vitest cho `rules.ts` vừa tách (hàm thuần, test rẻ). Hiện TS chưa có test nào.
- Luật `dependency-cruiser` cho `core` bật ngay từ PR đầu.

### Giai đoạn 3: Feature-first bên trong `apps/web` (khoảng 10 PR, một module mỗi PR)

- Gom `views/admin/<m>`, phần Vue còn lại của `queries/<m>`, `composables/<m>`, `utils/<m>` vào `app/features/<m>/`. `pages/` giữ nguyên đường dẫn URL.
- Tách `stores/modules/auth.ts`: phiên đăng nhập và hồ sơ (dùng chung) khỏi `adminGrants` (admin).
- Tách i18n theo khóa gốc thành nhiều file (chung, shop, admin), vẫn nạp chung.
- **Điểm dừng hợp lý.** Tới đây đã có: monorepo, core dùng lại được cho mobile, code theo feature, ranh giới có kiểm tự động. Chỉ còn một app deploy như cũ.

### Giai đoạn 4: Layer `packages/nuxt-base` (2 đến 3 PR)

- Chuyển `components/ui`, phần chung của `components/common`, CSS, tailwind preset, plugin vue-query, `useAuthSession`, i18n chung, `server/api/ghn` vào layer. `apps/web` khai `extends`.
- Vẫn một app; bước này chỉ chuẩn bị cho giai đoạn 5.

### Giai đoạn 5: Tách `apps/cms` (3 đến 5 PR, chỉ làm khi có lý do, xem Q1)

- Tạo `apps/cms` (Nuxt, `ssr: false` toàn bộ), chuyển `features/` admin, `pages/admin/**` (bỏ tiền tố `/admin` hoặc giữ, xem Q2), middleware quyền, `lib/navigations.ts`.
- `apps/web` bỏ admin và các gói chỉ admin dùng (`read-excel-file`, `write-excel-file`; kiểm lại bằng `knip`).
- Link chéo (ví dụ "xem trên shop" từ admin) dùng `NUXT_PUBLIC_WEB_URL`.
- **grace phải làm:** tạo project Vercel thứ hai (root `apps/cms`), thêm biến môi trường Supabase và GHN, gắn tên miền (ví dụ `admin.<domain>`), thêm URL của CMS vào Supabase Auth > URL Configuration > Redirect URLs (cho email đặt lại mật khẩu, mã xác minh).
- Cả hai project Vercel nên có "Ignored Build Step" chỉ build khi thư mục của mình hoặc `packages/` đổi.

### Giai đoạn 6: App mobile (sau, khi có yêu cầu thật)

- Tạo `apps/mobile`, dùng `@bongcun/core` cho kiểu, schema, repository, khóa cache.
- Thêm adapter: lưu file (upload URI), phiên đăng nhập (AsyncStorage), vận chuyển (gọi edge function). Chuyển proxy GHN sang edge function lúc này.
- Phạm vi gợi ý cho bản đầu: đúng các màn khách đang có trên web (sản phẩm, giỏ, đơn, đặt lịch spa, thú cưng và sổ sức khỏe của tôi). Không làm admin trên mobile.
- Chi phí đã ước ở PR #53: tài khoản Apple 99 USD/năm, Google 25 USD một lần.

### Tóm tắt

| Giai đoạn | Lợi ích | Chi phí | Khuyến nghị |
| --- | --- | --- | --- |
| 0 Dọn ranh giới | Sửa import sai chiều, bỏ code chết, có luật tự động | Thấp | Làm |
| 1 Workspace | Có chỗ cho `packages/` | Thấp, nhưng đụng mọi nhánh đang mở | Làm |
| 2 `packages/core` | Mobile dùng lại được, quy tắc tách khỏi truy cập dữ liệu, có test TS đầu tiên | Trung bình | Làm |
| 3 Feature-first | Sửa một module chỉ mở một thư mục | Trung bình | Làm |
| 4 Layer | Chuẩn bị tách app | Thấp | Làm cùng lúc với 5 |
| 5 Tách CMS | Deploy độc lập, bundle shop nhẹ hơn | Hai project Vercel, hai phiên đăng nhập, cấu hình Auth | Hoãn tới khi có lý do |
| 6 Mobile | App khách | Cao | Hoãn, như quyết định 2026-10-13 |

## 9. Rủi ro và breaking change

| Rủi ro / thay đổi | Mức | Cách giảm |
| --- | --- | --- |
| Đổi đường dẫn hàng loạt làm xung đột mọi nhánh đang mở | Cao | Mỗi giai đoạn di chuyển chạy khi không có thread nào code; PR chỉ di chuyển, không sửa logic; codemod thay import |
| Vercel build sai thư mục sau giai đoạn 1 | Trung bình | Đổi Root Directory cùng lúc merge; bản deploy cũ vẫn chạy nếu build lỗi |
| Auto-import Nuxt (`#imports`, `useSupabaseClient`) lọt vào `core` | Trung bình | Luật dependency-cruiser; typecheck riêng `core` bằng `tsc` không có kiểu Nuxt |
| Tách CMS: nhân viên phải đăng nhập riêng ở CMS (khác tên miền, khác cookie) | Trung bình (đổi hành vi) | Báo trước; đây là chủ ý, an toàn hơn |
| Tách CMS: email đặt lại mật khẩu trỏ sai app | Trung bình | Thêm Redirect URL trong Supabase Auth trước khi deploy CMS; template email dùng `redirectTo` theo app |
| Tách CMS: link cũ `/admin/...` đã lưu bookmark | Thấp | Web giữ redirect `/admin/**` sang tên miền CMS một thời gian |
| `database.types.ts` lệch migration sau khi đổi chỗ | Thấp | Bước CI so sánh như `schema.sql` |
| Thêm package làm CI chậm hơn | Thấp | Bộ nhớ đệm npm sẵn có; chỉ cân nhắc Turborepo khi CI quá khoảng 10 phút |
| Đổi cấu trúc nhưng chưa ai bấm thử giao diện (mọi UI hiện mới chỉ typecheck/build) | Trung bình | Mỗi giai đoạn di chuyển kèm danh sách màn cần bấm thử; giai đoạn 1 và 5 nên có grace bấm thử trước khi đi tiếp |
| Migration, RLS, RPC | Không đổi | Không giai đoạn nào đụng `supabase/migrations` |

## 10. Quyết định cần grace chọn

| # | Câu hỏi | Lựa chọn | Khuyến nghị |
| --- | --- | --- | --- |
| Q1 | Làm tới giai đoạn nào bây giờ? | (a) 0 đến 3 rồi dừng; (b) tới 5, tách hẳn CMS; (c) chỉ giai đoạn 0 | **(a)**. Được gần hết lợi ích về bảo trì và chuẩn bị cho mobile; tách CMS khi có tên miền riêng hoặc khi bundle shop thật sự chậm. |
| Q2 | Khi tách CMS, chạy ở đâu? | (a) tên miền con `admin.<domain>`; (b) giữ `/admin` cùng tên miền qua rewrite | **(a)**. Rewrite giữa hai project Vercel phức tạp và dễ lỗi cookie. |
| Q3 | App mobile viết bằng gì? | (a) Expo (React Native); (b) Capacitor bọc Vue | **Chưa cần chọn.** Vì `core` không phụ thuộc framework nên cả hai đều dùng lại được. Nghiêng về (a) nếu muốn app cảm giác native và học thêm React Native như PR #53 đề xuất; (b) nếu muốn dùng lại nhiều nhất component Vue. |
| Q4 | Công cụ monorepo | (a) npm workspaces; (b) pnpm + Turborepo | **(a)**. Repo đang dùng npm và `package-lock.json`; đổi trình quản lý gói không đem lại gì ở quy mô này. |
| Q5 | Kiểm ranh giới | (a) dependency-cruiser; (b) ESLint + plugin boundaries; (c) không kiểm | **(a)**. Không cần dựng ESLint (repo chưa có). |
| Q6 | Proxy GHN | (a) giữ ở Nuxt server trong layer; (b) chuyển sang edge function ngay | **(a)** tới giai đoạn 6, rồi (b). |
| Q7 | Đặt tên package | `@bongcun/core`, `@bongcun/nuxt-base`, `@bongcun/config` | Dùng tên này, không phát hành lên npm. |

## 11. Việc tiếp theo

Nếu grace đồng ý với khuyến nghị Q1 (a), làm giai đoạn 0 trước, rồi giai đoạn 1 vào lúc không có thread nào đang code, sau đó 2 và 3 theo từng feature. Mỗi PR theo quy tắc đang có: typecheck, build, CI xanh, squash merge, không đổi migration.
