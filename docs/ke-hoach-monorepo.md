# Audit và kế hoạch chuyển sang monorepo

Ngày: 2026-10-16. **Bản 2** (cùng ngày): thêm hướng dài hạn "backend thay được" (Supabase, NestJS hoặc nhiều backend), xem mục 12 đến 19. Những chỗ bản 1 nói khác đã được sửa tại chỗ; thay đổi chính ghi ở mục 12.1. Yêu cầu ban đầu của grace: audit toàn bộ dự án, đề xuất kế hoạch refactor sang monorepo (mỗi sản phẩm Web, CMS, Mobile là một app, phần dùng chung ở `packages/`), lấy Feature-First làm cấu trúc chính, chỉ dùng Ports & Adapters ở chỗ nghiệp vụ phức tạp hoặc phụ thuộc dịch vụ ngoài. **Tài liệu này không đổi code.** Mọi số liệu đo trên `main` commit `0cde6de` bằng quét tĩnh (grep, đếm dòng); chưa chạy thử bước nào của kế hoạch.

Đọc kèm: [danh-gia-kien-truc.md](danh-gia-kien-truc.md) (kết luận Nuxt + Supabase là đủ), [ke-hoach-sua-kien-truc.md](ke-hoach-sua-kien-truc.md), PR #53 (NestJS và app, đang hoãn).

## 1. Trả lời ngắn

- **Nên làm, nhưng làm theo nấc và dừng được ở bất kỳ nấc nào.** Phần đáng giá nhất (gom code theo feature, tách phần TypeScript thuần ra `packages/core` để app sau này dùng lại) rẻ và có ích ngay. Phần đắt nhất (tách admin thành app CMS riêng) có lợi ít hơn mình tưởng, nên để làm khi có lý do cụ thể.
- **Không cần Hexagonal cho phần lớn module.** Nghiệp vụ thật (hóa đơn, trừ kho FEFO, ca thu ngân, lưu trú, bệnh án) nằm trong RPC Postgres. Phía TypeScript chỉ gọi RPC và hiển thị, nên bọc thêm port/adapter ở POS, kho, y tế chỉ là thêm file mà không thêm an toàn. Repository hiện tại đã nhận `client` làm tham số, đó chính là "cổng" đủ dùng.
- **Ports & Adapters chỉ ở 4 chỗ dính dịch vụ ngoài:** vận chuyển (GHN), thanh toán (SePay/VietQR, khi làm), lưu file (ảnh, đính kèm y tế, vì app mobile upload khác web), gửi thông báo (khi có kênh).
- **Bản 2: nghiệp vụ hiện nằm trong Postgres, không phải TypeScript.** 262 hàm SQL, 50 trigger, 214 policy RLS. Vì vậy "đổi backend" thật ra là đổi nơi chạy nghiệp vụ, và phần giữ được lâu dài là **hợp đồng** (tên use case, dữ liệu vào/ra, lỗi, quyền) chứ không phải mã. Kế hoạch này đặt hợp đồng và quy tắc thuần vào `packages/core` (không phụ thuộc Supabase), còn mọi thứ chạm `supabase-js` vào một chỗ duy nhất (`packages/supabase`).
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
| Giữ | Mẫu repository nhận `client` | `src/repositories/**` | Chuyển vào `packages/supabase/<feature>/repo.ts` (bản 2), đổi kiểu trả về sang kiểu miền của `core` |
| Giữ | `parseRpc`, `unwrap`, `pageRange`, mã lỗi Postgres | `src/repositories/shared.ts` | `packages/supabase/src/shared/` (hàm), mã lỗi nghiệp vụ trong `core/shared/errors.ts` |
| Giữ | Quyền giao diện thuần | `src/lib/access.ts` | `packages/core/src/auth/access.ts` |
| Giữ | Bộ nhập/xuất Excel/CSV/PDF | `src/lib/data-io`, `components/common/data-io` | Chỉ CMS dùng, vào feature `data-io` của CMS |
| **Tách** | Quy tắc và hằng số đang nằm trong repository | `repositories/inventory/index.ts` (`isExpired`, `businessDate`, `STOCK_STATUSES`, `DOC_TYPES`), `repositories/users.ts` (`USER_SORT`)... | `core/<feature>/model.ts` (kiểu, hằng số) và `rules.ts` (hàm thuần); `repo.ts` chỉ còn gọi Supabase |
| Tách | Store `auth` | `src/stores/modules/auth.ts` (294 dòng) + `auth-parts/` | Phần phiên đăng nhập và hồ sơ: dùng chung (layer). `adminGrants`: CMS |
| Tách | i18n | `src/i18n/locales/*.json` | Khóa chung (`common`, `validation`, `locale`) trong layer; khóa admin vào CMS; khóa shop vào Web |
| Tách | `lib/constants.ts`, `lib/utils.ts` | `src/lib/` | Theo feature; `cn()` vào UI; hàm format tiền, ngày vào `core/shared/format.ts` |
| Tách | `composables/shop` | `src/composables/shop/` | Phần admin (`useShopSettingsForm`, `useShippingTest`, `useOrderSheet`, `useOrdersPage`) sang CMS |
| **Chuyển** | Kiểu dữ liệu | `src/types/*.ts` | `core/<feature>/model.ts`; `database.types.ts` vào `packages/supabase/src/db/` |
| Chuyển | Schema zod | `src/validations/*.ts` | `core/<feature>/contract.ts` |
| Chuyển | Queries | `src/queries/*.ts` | Khóa cache và hàm lấy dữ liệu vào `core/<feature>/keys.ts` (khóa, không Vue) và `packages/supabase/<feature>/repo.ts` (hàm lấy dữ liệu); `useQuery` bọc mỏng nằm trong feature của từng app |
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
   ├─ core/                     # TS thuần: KHÔNG Vue/Nuxt/Pinia/DOM và KHÔNG supabase-js
   │  └─ src/                    # phụ thuộc duy nhất: zod, date-fns
   │     ├─ shared/             # format tiền/ngày, Page<T>, lỗi nghiệp vụ (AppError), kiểu Result
   │     ├─ auth/               # access.ts, kiểu role, Session (kiểu của mình, không phải của Supabase)
   │     ├─ ports/              # interface cho dịch vụ ngoài (mục 5) và cho feature đã chuyển backend (mục 15)
   │     └─ <feature>/          # pos, inventory, products, medical, boarding, spa, shop, ...
   │        ├─ model.ts         # kiểu miền, hằng số, trạng thái
   │        ├─ rules.ts         # hàm thuần (isExpired, phí ship, giá hiển thị...)
   │        ├─ contract.ts      # zod: dữ liệu vào/ra từng use case, mã lỗi nghiệp vụ (mục 14)
   │        ├─ keys.ts          # khóa cache + luật làm mới, không phụ thuộc framework
   │        └─ index.ts         # API công khai của feature
   ├─ supabase/                 # NƠI DUY NHẤT import @supabase/supabase-js (mục 13)
   │  └─ src/
   │     ├─ db/                 # database.types.ts (sinh), type Db
   │     ├─ shared/             # unwrap, parseRpc, pageRange, dịch lỗi Postgres → AppError
   │     ├─ auth/               # đọc claim user_role/branch_ids, đăng nhập/đăng xuất
   │     └─ <feature>/repo.ts   # hàm gọi RPC/bảng, trả kiểu của core (mapper), không trả Row
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

**Vì sao 4 package (bản 2: thêm `supabase`).** Có thể tách `core` thành `types`, `domain`, `api`, `validation` riêng, nhưng mỗi package thêm một `package.json`, một lần build và một chỗ phải giữ phiên bản. Với một người làm, một package `core` chia thư mục theo feature và xuất theo đường con (`@bongcun/core/pos`) cho cùng ranh giới mà rẻ hơn nhiều. **Ngoại lệ có lợi ích thật là `supabase`**: nếu để repository trong `core`, thì `core` mang theo `supabase-js` trong `package.json`, và NestJS (hoặc bất kỳ backend nào) dùng lại `core` sẽ kéo cả thư viện đó; ranh giới chỉ còn dựa vào kỷ luật. Tách thành package riêng khiến luật "core không biết Supabase" được **`package.json` ép** (không khai báo thì không import được) thay vì chỉ ghi trên giấy. Các phần còn lại (types, validation, queries) vẫn là thư mục trong `core`, không thành package.

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
// apps/web, apps/cms: adapter gọi /api/ghn/* (code của src/services/*.ts hiện nay), đặt trong app hoặc nuxt-base
// apps/mobile (sau): adapter gọi edge function `ghn` của Supabase
```

Khi có app mobile, proxy GHN nên chuyển từ `server/api/ghn` (Nitro trên Vercel) sang một edge function Supabase, để web, CMS và mobile cùng gọi một chỗ và token chỉ nằm ở Supabase secrets. Trước đó giữ trong layer `nuxt-base` cho rẻ.

## 6. Quy tắc dependency

```
apps/web ─┐                  apps/mobile ─┐
apps/cms ─┼─► packages/nuxt-base ─┐      (không dùng nuxt-base)
          └───────────────────────┼─► packages/supabase ─► packages/core ─► (zod, date-fns)
                       apps/mobile ┘          │ (supabase-js)                   ▲
                                              └─────────────────────────────────┘
                              (tương lai) apps/api (NestJS) ─► packages/core  (không cần packages/supabase)
```

1. `apps/*` được import `packages/*`. **Không** chiều ngược lại, và **app không import app**.
2. `packages/core` chỉ phụ thuộc `zod`, `date-fns`. Cấm `@supabase/supabase-js`, `vue`, `nuxt`, `#imports`, `pinia`, `@tanstack/*`, `window`, `document`, `process.env`. `packages/supabase` phụ thuộc `core` và `@supabase/supabase-js`; `core` không bao giờ import ngược lại. Chỉ `packages/supabase` được import `@supabase/supabase-js` và `database.types.ts`; app lấy client từ nó hoặc từ `@nuxtjs/supabase` rồi truyền vào.
3. Trong `core`, feature A dùng feature B chỉ qua `core/B/index.ts`, không vào file bên trong. Cạnh được phép khai báo rõ, ví dụ `pos → products, inventory, shared`; `medical → pos, products, inventory`; `boarding → pos`. Không vòng.
4. Trong app, `features/A` dùng `features/B` chỉ qua `index.ts`. `pages/` được import `features/*`, không ngược lại.
5. Import sâu vào package bị cấm: dùng `@bongcun/core/pos`, không `@bongcun/core/src/pos/repo`. `package.json` của `core` khai `exports` theo đường con để chặn từ gốc.
6. Biến môi trường chỉ đọc ở app (`runtimeConfig`), truyền vào core qua tham số.

**Kiểm tự động:** thêm `dependency-cruiser` vào CI với các luật trên (một file cấu hình, không cần dựng ESLint). Đây là thứ giữ ranh giới không bị mòn sau vài tuần; không có nó thì quy tắc chỉ nằm trên giấy.

## 7. Chiến lược chia sẻ code

| Loại | Cách chia | Ghi chú |
| --- | --- | --- |
| Kiểu DB | `packages/supabase/src/db/database.types.ts`, sinh bằng `supabase gen types typescript --local`. Kiểu `Row` không ra khỏi package này; `core` có kiểu miền riêng | Thêm bước CI kiểm file này khớp migration, giống `schema.sql` |
| Supabase client | `packages/supabase` khai `type Db = SupabaseClient<Database>`. Mỗi app tự tạo client: web/CMS qua `@nuxtjs/supabase` (cookie), mobile qua `createClient` với AsyncStorage | Đúng như `src/lib/supabase.ts` hiện tại, chỉ là bên nhận |
| Kiểu kết quả RPC `jsonb` | Schema zod trong `core/<feature>/contract.ts`, kiểu suy từ `z.infer`; `packages/supabase` parse bằng `parseRpc` | Một nguồn cho cả kiểu và kiểm tra lúc chạy (đã bắt đầu ở `parseRpc`) |
| Validation form | Schema zod trong `core/<feature>/contract.ts`, thông báo lỗi là khóa i18n; app gắn vào vee-validate (Vue) hay react-hook-form (RN) | |
| Truy vấn | `core/<feature>/keys.ts` giữ khóa cache và luật làm mới (`invalidatePos`...); `queryFn` là hàm của `packages/supabase`; Vue bọc bằng `useQuery(...)`, React bằng `useQuery(...)` của `@tanstack/react-query` | Không viết hai lần |
| Quy tắc nghiệp vụ dạng hàm thuần | `core/<feature>/rules.ts` (test bằng Vitest, backend nào cũng chạy) | Ví dụ giá theo cân nặng, hạn dùng, trạng thái đơn |
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

- PR đầu: tạo `packages/core` (`shared/`, `auth/`) và `packages/supabase` (`db/`, `shared/`, `auth/`); đặt alias để `apps/web` import `@bongcun/core/...` và `@bongcun/supabase/...`. Đổi lệnh sinh kiểu DB sang đường mới.
- Mỗi PR sau một feature, theo thứ tự ít phụ thuộc trước: `branches`/`users`/`permissions` → `products` → `inventory` → `pos` → `spa` → `boarding` → `medical` → `shop` → `reports`.
- Trong mỗi PR: kiểu miền, hằng số, hàm thuần và schema zod vào `core/<f>/` (`model.ts`, `rules.ts`, `contract.ts`); `repositories/<f>` vào `packages/supabase/<f>/repo.ts` và đổi giá trị trả về từ kiểu `Row` sang kiểu của `core` (mapper); khóa cache từ `queries/<f>` sang `core/<f>/keys.ts`. Sửa import bằng codemod (`jscodeshift` hoặc script `sed` có kiểm), không sửa tay từng file.
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
| Q7 | Đặt tên package | `@bongcun/core`, `@bongcun/supabase`, `@bongcun/nuxt-base`, `@bongcun/config` | Dùng tên này, không phát hành lên npm. |

## 11. Việc tiếp theo (bản 1; bản 2 xem mục 22)

Nếu grace đồng ý với khuyến nghị Q1 (a), làm giai đoạn 0 trước, rồi giai đoạn 1 vào lúc không có thread nào đang code, sau đó 2 và 3 theo từng feature. Mỗi PR theo quy tắc đang có: typecheck, build, CI xanh, squash merge, không đổi migration.

---

# Phần bổ sung (bản 2): kiến trúc cho backend thay được

Yêu cầu thêm của grace (2026-10-16): hệ thống có thể tiếp tục dùng Supabase, chuyển sang NestJS hoặc kết hợp nhiều backend trong tương lai; domain, quy tắc và use case độc lập framework/backend; chỉ dùng Ports & Adapters ở chỗ có lý do; không tạo hàng loạt package hay interface; lộ trình PR nhỏ giữ nguyên hành vi production. Số liệu mục 13 và 14 đo trên `main` commit `9ee0417` bằng quét tĩnh (`supabase/schema.sql` và `src/`), không chạy trên database thật.

## 12. Nguyên tắc và thay đổi so với bản 1

### 12.1 Bản 1 sửa gì

| Chỗ | Bản 1 | Bản 2 | Lý do |
| --- | --- | --- | --- |
| Vị trí repository | `packages/core/<f>/repo.ts` | `packages/supabase/<f>/repo.ts` | `core` phải không biết Supabase thì NestJS mới dùng lại được mà không kéo `supabase-js` |
| Số package | 3 (`core`, `nuxt-base`, `config`) | 4 (thêm `supabase`) | Một package có lợi ích thật: ranh giới do `package.json` ép |
| Schema zod | `schemas.ts` | `contract.ts` (vào/ra từng use case + mã lỗi) | Đây là thứ phải giữ khi đổi nơi chạy nghiệp vụ |
| Khóa cache | `queries.ts` (khóa + `queryFn`) | `keys.ts` (chỉ khóa và luật làm mới) | `queryFn` gọi backend nên thuộc adapter |
| Kiểu trả về của repo | tùy | kiểu miền của `core`, không trả `Row` | Đổi backend không làm vỡ giao diện |
| Ports | 4 chỗ dịch vụ ngoài | giữ 4 chỗ + cách mở thêm khi một feature chuyển backend (mục 15) | Không tạo interface trước khi có cài đặt thứ hai |

### 12.2 Năm nguyên tắc

1. **Ranh giới bền vững là hợp đồng use case**, không phải thư viện. Một use case là một việc nghiệp vụ có tên (ví dụ `createInvoice`) với dữ liệu vào, dữ liệu ra, lỗi có mã, quyền cần có và cam kết giao dịch. Hôm nay nó được thực thi bằng một RPC Postgres; mai có thể là một endpoint NestJS với cùng hợp đồng.
2. **Nghiệp vụ nằm ở nơi nó đang đúng và có test.** Không viết lại SQL sang TypeScript chỉ để kiến trúc "sạch". Tiền, kho và quyền giữ ở Postgres cho tới khi có lý do cụ thể để chuyển (mục 16).
3. **Quy tắc rule of two:** chỉ tạo port/interface khi sắp có cài đặt thứ hai hoặc khi đó là dịch vụ ngoài. Một interface chỉ có một cài đặt và không có lý do thay thế là chi phí thuần.
4. **Quy tắc chạy được trên mọi backend nằm trong `core`:** hàm thuần, hằng số, zod. Test bằng Vitest, không cần database.
5. **Mọi bước giữ nguyên hành vi, không đổi database, có đường lui bằng `git revert` hoặc đổi cờ cấu hình.**

## 13. Audit: phần nào đang dính trực tiếp Supabase

| Nhóm | Số đo | Nằm ở đâu | Đánh giá |
| --- | --- | --- | --- |
| Gọi hàm Postgres | 184 lời gọi `.rpc()`, 176 RPC khác nhau, 67 file | `src/repositories/**` | Đây là "API" thật của hệ thống. Tên RPC + tham số `p_*` + khóa JSON trả về |
| Đọc bảng trực tiếp | 65 lời gọi `.from(bảng)`, 27 bảng, 28 file (nhiều nhất: `pet_services` 6, `users` 4, `species` 4, `pet_service_combos` 4, `permissions` 4) | `src/repositories/**` | Dính cả RLS và cú pháp PostgREST. Khó thay nhất vì mỗi truy vấn phải thành một endpoint |
| Cú pháp PostgREST | `.eq` 60, `.order` 33, `.range` 9, `.or("a.ilike.%x%,...")` 9, `.in` 6 | `src/repositories/**`, `shared.ts` (`searchOr`, `pageRange`) | Tập trung ở repository, view không biết |
| Đăng nhập, phiên | 17 chỗ `.auth.` | `src/stores/modules/auth.ts` (9), `auth-parts/recovery.ts` (5), `verification.ts` (3) | Supabase Auth: OTP email, đặt lại mật khẩu, đọc claim. Store `auth` đang vừa giữ phiên vừa gọi SDK |
| Claim JWT | `user_role` (TS đọc), `branch_ids` (SQL đọc) | Custom Access Token Hook; `auth.uid()` 72 chỗ, `auth.jwt()` 4 chỗ trong SQL | Danh tính truyền vào Postgres qua JWT. Backend mới phải truyền được danh tính này |
| Storage | 2 bucket: `images` (public), `medical` (private, signed URL) | `repositories/storage.ts`, `medical/attachments.ts` | Cần port vì web upload `File`, mobile upload URI |
| Edge function | 1: `admin-create-user` | `supabase/functions`; gọi ở `repositories/users.ts:162` | Cần service role. Ứng viên chuyển sang NestJS đầu tiên nếu có |
| Realtime | không dùng (polling `usePolling`) | | Không có gì phải thay |
| Lỗi | mã Postgres 23505/23503/42501 dịch ở `queries/notify.ts`; lỗi nghiệp vụ có `hint` (385 chỗ `raise exception ... hint`, 145 mã khác nhau) với danh sách theo module (`POS_ERROR_HINTS`...) | `queries/notify.ts`, `repositories/*/errors.ts` | Đã có sẵn một **hợp đồng lỗi phi chính thức** là `hint`. Chỉ có 1 chỗ ngoài repository biết mã Postgres |
| Kiểu `Row` | dùng ở 20 file repository, **0 file ngoài repository** | | Rất tốt: giao diện chưa biết hình dạng bảng |
| Client Supabase | duy nhất `src/lib/supabase.ts` | | Tốt |
| `supabase-js` trong view/component | 0 | | Tốt |

**Kết luận audit:** sự phụ thuộc vào Supabase **tập trung** (repository, store `auth`, `lib/supabase.ts`) chứ không rải khắp giao diện. Có hai loại phụ thuộc với chi phí gỡ rất khác nhau:

- **Phụ thuộc SDK** (cú pháp `.rpc`, `.from`, `.auth`): rẻ gỡ, chỉ sửa lớp repository.
- **Phụ thuộc ngữ nghĩa** (RLS dựa vào `auth.uid()`, `has_permission` đọc claim, trigger trừ kho, giao dịch trong RPC): đắt gỡ, vì chúng là nghiệp vụ chứ không phải thư viện.

Một số rò rỉ nhỏ cần vá khi tách `core`/`supabase`: `queries/notify.ts` đọc mã Postgres (chuyển vào adapter, trả lỗi nghiệp vụ), `types/index.ts` import `lib/constants`, khoảng 13 file repository trả kết quả RPC bằng ép kiểu `as unknown as` hoặc `return unwrap(...)` không qua mapper (chỉ 3 luồng tiền có `parseRpc`).

## 14. Phân biệt: nghiệp vụ trong PostgreSQL và nghiệp vụ trong TypeScript

### 14.1 Số liệu

| | PostgreSQL | TypeScript |
| --- | --- | --- |
| Khối lượng | 262 hàm `public.*` (lớn nhất: `create_invoice` 350 dòng, `import_one_group` 294, `boarding_apply_stay` 273, `save_product_group` 264, `place_shop_order` 255, `save_appointment` 230), 50 trigger, 214 policy RLS, 76 bảng, 101 chỗ `FOR UPDATE`, 7 chỗ `pg_advisory` | Khoảng 730 dòng `src/utils/**` (giỏ hàng, phí ship, chọn dịch vụ spa, format), `src/lib/access.ts` (94), `repositories/medical/rules.ts` (33), `server/utils/ghnQuote.ts` (quy tắc báo giá GHN) |
| Vai trò | **Nguồn sự thật** cho tiền, kho, quyền, chống trùng giờ, chọn chuồng, khóa bệnh án | **Xem trước và trải nghiệm**: tính tạm, ràng buộc nhập liệu, chặn sớm, gọi dịch vụ ngoài (GHN) |
| Giao dịch | Mỗi RPC là một giao dịch: hóa đơn + thanh toán + trừ kho, hủy + trả kho, check-out lưu trú... | Không có |
| Quyền | RLS + hàm `can_*`, `has_permission(perm, method, branch)` | `access.ts` chỉ chặn giao diện (ghi rõ "UX gating only") |
| Test | 6 file pgTAP (61 ca: RLS, quyền, POS, lưu trú, y tế, hủy đơn tự động) | Không có test TS nào |

### 14.2 Theo từng feature

| Feature | Quy tắc quyết định nằm ở | TS giữ gì | Tính di động |
| --- | --- | --- | --- |
| POS và hóa đơn | SQL: `create_invoice` (giá tính phía server), trigger trừ kho FEFO trên `invoice_lines`, ca thu ngân, trả hàng | Giỏ POS, hiển thị | Thấp: giao dịch + trigger + khóa dòng |
| Kho theo lô | SQL: `move_stock`, `take_stock_fefo`, `next_doc_code`, phiếu nhập/xuất/kiểm | Hằng số trạng thái, `isExpired`, `businessDate` (nằm lẫn trong repository) | Thấp. Phần hằng số và `isExpired` đưa được vào `core` |
| Checkout shop | SQL: `place_shop_order` (kiểm tồn, giá, cân nặng, chính sách ship), xác nhận đơn, hủy tự động | Giỏ hàng (localStorage), báo giá GHN, `resolveShippingFee`, giới hạn | Trung bình. **Có trùng lặp**: `MAX_DELIVERY_G` 30.000 g định nghĩa ở `utils/shop/shipping.ts` và `server/utils/ghnQuote.ts`; trần phí 500.000 ở `shipping.ts` (`MAX_QUOTE_FEE`) và trong `place_shop_order` |
| Spa | SQL: `save_appointment` (chặn trùng giờ, bàn spa) | Chọn dịch vụ, tuỳ chọn, nhãn giờ (`utils/spa`) | Thấp phần đặt lịch, cao phần giao diện |
| Lưu trú | SQL: `boarding_apply_stay` (tự xếp chuồng, tính đêm) | Kiểu, hiển thị lịch | Thấp |
| Y tế | SQL: ký khóa bệnh án, kê đơn trừ kho theo lô, sổ tiêm | `getMedicalRules` chỉ đọc cấu hình | Thấp |
| Báo cáo | SQL: 11 hàm `report_*` | Biểu đồ, xuất file | Trung bình: có thể thay bằng view hoặc job, chỉ cần giữ hợp đồng |
| Quyền | SQL: `has_permission`, RLS, `my_permissions` | `ADMIN_ROUTE_PERMISSIONS` (bản sao dùng để ẩn menu) | Thấp. Bản sao ở TS có thể lệch SQL (xem 17.5) |
| Nhập/xuất dữ liệu | TS: đọc Excel/CSV, kiểm cột; SQL: `import_*` ghi từng dòng | Toàn bộ bộ `lib/data-io` | Cao: bộ này không cần Supabase, chuyển sang NestJS được nếu muốn xử lý file lớn |
| Vận chuyển GHN | TS (Nitro `server/api/ghn`): token, chọn dịch vụ theo cân nặng | Toàn bộ | Cao: không dính Supabase, là dịch vụ ngoài thuần |
| Tạo tài khoản | Edge function `admin-create-user` | gọi qua `functions.invoke` | Cao: cần service role, dễ chuyển sang NestJS |

### 14.3 Hệ quả cho thiết kế

- **Domain model "độc lập backend" trong dự án này chủ yếu là kiểu dữ liệu, hằng số, hàm thuần và hợp đồng**, không phải entity có hành vi, vì hành vi nằm ở SQL. Không nên viết class `Invoice` với phương thức TS song song với `create_invoice`: đó là hai nơi cùng giữ một quy tắc, rất dễ lệch.
- Quy tắc trùng ở cả hai phía (phí ship, trần phí, cân nặng tối đa) phải có **một nguồn ghi và một test đối chiếu** (mục 17.5).
- Use case = tên hàm repository hiện có, thêm kiểu vào/ra rõ ràng. Không cần tầng "service" mới.

## 15. Kiến trúc đích và chỗ nào dùng Ports & Adapters

```
Giao diện (Vue / React Native)
   │  gọi composable useXxx (state, không biết backend)
   ▼
Hàm use case  ◄── kiểu vào/ra, mã lỗi, quyền lấy từ  packages/core/<feature>/contract.ts
   │
   ├─ [mặc định]      packages/supabase/<feature>/repo.ts  ─► RPC / bảng Supabase
   ├─ [khi cần]       adapter HTTP (gọi NestJS cùng hợp đồng)  ─► apps/api ─► RPC hoặc logic TS
   └─ [dịch vụ ngoài] adapter của port (GHN, SePay, Storage, Thông báo)
```

### 15.1 Bốn mức xử lý, theo lý do

| Mức | Dùng khi | Feature hiện tại | Cách làm |
| --- | --- | --- | --- |
| **A. Quy tắc thuần** | Muốn test nghiệp vụ không cần DB; chạy ở mọi backend | phí ship, giỏ hàng, giá hiển thị, chọn dịch vụ spa, `isExpired`, hạn dùng, quyền giao diện | `core/<f>/rules.ts` + Vitest. **Không cần port** |
| **B. Hợp đồng + adapter cụ thể** | Nghiệp vụ nằm ở SQL, chưa có lý do thay | POS, kho, sản phẩm, spa, lưu trú, y tế, báo cáo, quyền, nhập/xuất | `contract.ts` (zod vào/ra, mã lỗi) + `packages/supabase/<f>/repo.ts` trả kiểu của `core`. **Chưa có interface** |
| **C. Port + nhiều adapter** | Dịch vụ ngoài, hoặc cần thay hạ tầng | Vận chuyển (GHN), thanh toán (SePay, khi làm), lưu file, thông báo (khi có kênh) | `core/ports/*.ts` + adapter. Test nghiệp vụ bằng adapter giả |
| **D. Port tạm cho feature chuyển backend** | Khi một feature thật sự sắp có cài đặt NestJS | chưa có | Tạo interface từ chính các hàm của `repo.ts` (đã có kiểu), thêm adapter HTTP, đổi chỗ gọi qua một registry. Làm **tại thời điểm chuyển**, trong một PR |

Vì sao hoãn mức D: các hàm repository đã có dạng `(client, input) => Promise<kết quả>`; nếu chúng dùng kiểu của `core` (mức B), thì rút ra interface sau này là việc cơ học, vài file mỗi feature. Làm sớm chỉ thêm file mà chưa có người dùng.

### 15.2 Những thứ cố ý không làm

- Không tạo interface `IXxxRepository` cho từng feature.
- Không dùng DI container, CQRS, event bus, class entity có hành vi, hay mapping nhiều tầng. Chỉ có một mapper ở biên repository (dòng DB → kiểu miền).
- Không tách thêm package `types`, `validation`, `api`, `domain` riêng. Chúng là thư mục trong `core`.
- Không dựng sẵn `apps/api` khi chưa có use case nào cần nó.
- Không đưa `supabase-js` vào `core`, và không để `core` đọc biến môi trường.

### 15.3 Xác thực và danh tính

Giữ **Supabase Auth trong mọi kịch bản** (khuyến nghị, quyết định Q8): người dùng, OTP email, JWT có claim `user_role` và `branch_ids`, gói Free dùng được. NestJS xác minh JWT bằng khóa công khai của Supabase và, khi cần gọi database **thay mặt người dùng**, truyền lại JWT đó (kết nối với vai trò `authenticated`) để RLS và `auth.uid()` vẫn đúng. Chỉ dùng service role cho việc hệ thống (webhook, cron), không dùng thay cho người dùng. `core/auth` khai kiểu `Session`/`Role` của riêng mình để giao diện không phụ thuộc kiểu `Session` của Supabase.

## 16. Bốn kịch bản backend: dùng lại gì, viết lại gì

| Kịch bản | Mô tả | Khi nào hợp lý |
| --- | --- | --- |
| **S0. Chỉ Supabase** (hiện tại) | RPC + RLS, Nuxt server chỉ có proxy GHN | Hiện tại và vài chục khách đầu. Rẻ nhất |
| **S1. Supabase + NestJS bên cạnh** | NestJS chỉ làm việc mà Postgres làm kém: webhook SePay/GHN, job nền, thông báo, xử lý file, báo cáo nặng. Ghi dữ liệu qua RPC mới (ví dụ `record_payment`) | Khi làm thanh toán thật, thông báo, mobile cần API chung. **Khuyến nghị làm trước nếu cần backend** |
| **S2. NestJS làm cổng (strangler) cho từng feature** | Giao diện gọi HTTP `/v1/...`. NestJS thực thi bằng cách (a) chuyển tiếp tới đúng RPC cũ, hoặc (b) tự cài lại logic bằng TS | (a) khi muốn một API chung cho web/mobile/bên thứ ba; (b) chỉ khi có lý do cứng cho feature đó |
| **S3. Chuyển toàn bộ nghiệp vụ sang NestJS** | Database chỉ còn bảng và ràng buộc | Chỉ khi có lý do cứng (giới hạn nền tảng, tuân thủ, đội ngũ). Không khuyến nghị bây giờ |

### 16.1 Bảng tái sử dụng

| Thành phần | S1 | S2(a) | S2(b) / S3 |
| --- | --- | --- | --- |
| Giao diện (`apps/web`, `apps/cms`, `nuxt-base`) | giữ | giữ | giữ |
| `packages/core`: kiểu, hằng số, hàm thuần, hợp đồng zod, khóa cache, port | giữ nguyên | giữ nguyên | giữ nguyên (NestJS import cùng gói) |
| Test Vitest của `rules.ts` | giữ | giữ | giữ |
| `packages/supabase` (repo) | giữ cho các feature chưa chuyển | thay bằng adapter HTTP ở feature đã chuyển | thay hoàn toàn ở feature đã chuyển |
| Lược đồ DB: bảng, ràng buộc, index, migration | giữ | giữ | giữ (vẫn là nguồn lược đồ) |
| 262 hàm SQL + 50 trigger | giữ | giữ (NestJS gọi lại) | **viết lại bằng TS** cho feature đã chuyển, rồi gỡ khi hết dùng |
| 214 policy RLS | giữ | giữ (NestJS kết nối vai trò `authenticated`) | giữ làm lớp chặn cuối; thêm kiểm quyền ở tầng NestJS |
| `has_permission`, `role_permissions`, `staff_branches` | giữ | giữ | giữ làm dữ liệu; thêm `PermissionService` TS đọc cùng bảng |
| Giao dịch nguyên tử (hóa đơn + trừ kho + thanh toán) | trong RPC | trong RPC | **tạo lại thủ công**: một giao dịch DB, cùng thứ tự khóa, `SELECT ... FOR UPDATE`; số chứng từ vẫn từ bảng/sequence của DB |
| Trigger trừ kho FEFO trên `invoice_lines`, trả kho khi hủy | giữ | giữ | **viết lại** thành bước trong use case, hoặc giữ trigger nếu vẫn ghi vào cùng bảng |
| pgTAP (61 ca) | giữ | giữ | dùng làm **đặc tả hành vi**: dịch thành test tích hợp NestJS chạy trên DB thật |
| `pg_cron` hủy đơn quá hạn | giữ | giữ | giữ hoặc chuyển thành scheduler của NestJS |
| Edge function `admin-create-user` | giữ | giữ | ứng viên chuyển sang NestJS |
| Proxy GHN trong Nitro | giữ hoặc chuyển | chuyển thành adapter của port vận chuyển, chạy ở NestJS | như S2 |
| Supabase Auth, JWT, claim | giữ | giữ | giữ (khuyến nghị) |

### 16.2 Phần bắt buộc viết lại khi chuyển nơi thực thi nghiệp vụ (S2(b)/S3)

1. Mọi RPC của feature chuyển (ví dụ POS: `create_invoice` 350 dòng, `cancel_invoice`, `create_sales_return`, ca thu ngân) thành use case TS **cùng hợp đồng, cùng thứ tự khóa**.
2. Trigger và hàm phụ trợ (trừ kho FEFO, sinh số chứng từ, chống âm kho) thành mã TS trong cùng một giao dịch hoặc giữ ở DB.
3. 65 lời gọi `.from(bảng)` đọc trực tiếp: mỗi truy vấn danh sách, tìm kiếm, phân trang (`or(...ilike...)`, `range`) cần một endpoint, vì NestJS không có PostgREST.
4. Phân quyền theo chi nhánh: cài `PermissionService` và guard, kiểm parity với `has_permission` bằng cùng bộ ca pgTAP.
5. Bộ test: dịch pgTAP thành test tích hợp; chạy cả hai phía song song cho tới khi chuyển xong.
6. Ước lượng chi phí nằm ở phân tích PR #53 (`docs/kien-truc-web-app-nestjs.md` trên nhánh của PR đó: ước tính 3 đến 7 tháng nếu chuyển toàn bộ sang NestJS; chưa kiểm lại số này ở bản 2); đây là lý do kịch bản S3 không được khuyến nghị khi chưa có khách.

## 17. Hợp đồng API (API contracts)

### 17.1 Một hợp đồng gồm gì

Mỗi use case ghi trong `core/<feature>/contract.ts`:

| Mục | Ví dụ với `createInvoice` |
| --- | --- |
| Tên | `createInvoice` (tên miền, không phải `create_invoice`) |
| Vào | zod `createInvoiceInput` (camelCase, chưa có tiền tố `p_`) |
| Ra | zod `createInvoiceResult` |
| Lỗi | mã nghiệp vụ: `no_open_shift`, `out_of_stock`, `discount_limit`... (chính là `hint` hiện có) |
| Quyền | `pos` + `CREATE` + phạm vi chi nhánh |
| Cam kết | một giao dịch; không có trạng thái nửa chừng |
| Idempotency | khóa `clientRef` nếu có (checkout shop đã có `client_ref`) |

Adapter Supabase chịu trách nhiệm dịch tên (`p_branch` ↔ `branchId`, `snake_case` ↔ `camelCase`) và đóng gói lỗi; giao diện không biết hai thứ này.

### 17.2 Mô hình lỗi

```ts
// packages/core/src/shared/errors.ts
export type AppErrorCode = "forbidden" | "not_found" | "conflict" | "in_use" | "validation" | "unavailable"
  | PosErrorHint | InventoryErrorHint | MedicalErrorHint | /* mỗi module khai mã của mình */ never;
export class AppError extends Error { constructor(readonly code: AppErrorCode, readonly detail?: string) { super(code) } }
```

`packages/supabase/src/shared/errors.ts` dịch: 42501 → `forbidden`, 23505 → `conflict`, 23503 → `in_use`, `hint` → mã module. Chuyển logic từ `queries/notify.ts` sang đây (một PR nhỏ, phần giao diện chỉ còn dịch `AppError.code` ra chữ). Adapter HTTP sau này dịch mã HTTP/JSON sang cùng `AppError`.

### 17.3 Vận chuyển (transport) theo giai đoạn

| Giai đoạn | Giao diện gọi | Ghi chú |
| --- | --- | --- |
| Hiện tại | `supabase.rpc("create_invoice", { p_... })` | Không đổi |
| S1 | như trên; thêm HTTP chỉ cho việc mới (webhook, thông báo) | Webhook là endpoint công khai có chữ ký, không phải API cho giao diện |
| S2 | `POST /v1/pos/invoices` | JSON giống hợp đồng, xác thực bằng JWT Supabase |

OpenAPI: **chưa sinh**. Khi có HTTP thật thì sinh từ zod (ví dụ `zod-to-openapi` hoặc `nestjs-zod`) để mobile native hoặc bên thứ ba đọc.

### 17.4 Tương thích ngược và phiên bản

- Chỉ **thêm** trường mới (tùy chọn); không đổi tên hay xóa trường trong hợp đồng đang dùng.
- Đổi tên/đổi chữ ký RPC theo expand/contract: tạo hàm mới, chuyển client, giữ hàm cũ tới khi không còn bản app nào gọi, rồi mới gỡ. Với mobile, bản app đã cài không ép cập nhật được nên hàm cũ giữ lâu hơn.
- API HTTP gắn tiền tố `/v1`; hợp đồng đổi phá vỡ thì thành `/v2` song song.
- Không migration nào bị sửa; việc thêm hàm mới đi theo quy trình migration hiện có (forward-only, tự chạy khi merge).

### 17.5 Kiểm thử hợp đồng

| Kiểm tra | Cách làm | Bắt được |
| --- | --- | --- |
| Hình dạng kết quả RPC | Test chạy trên DB cục bộ của CI (đã có bước `supabase db start`): gọi RPC với dữ liệu mẫu, `parse` bằng zod của `core` | Đổi khóa trong SQL mà quên sửa TS |
| Hằng số/quy tắc trùng TS↔SQL | Test đọc hằng số trong `core` và so với kết quả RPC (ví dụ trần phí 500.000, cân nặng tối đa) | Hai nơi lệch nhau |
| Bản sao quyền | Test so `ADMIN_ROUTE_PERMISSIONS` với mã quyền trong bảng `permissions` | Menu hiện mà RPC từ chối, hoặc ngược lại |
| Cùng một bộ test chạy với hai adapter | Khi có adapter HTTP, chạy lại đúng bộ test hợp đồng với cả hai | NestJS không khớp hành vi cũ |

## 18. Ranh giới module và quy tắc dependency (bổ sung cho mục 6)

| Quy tắc | Nội dung | Kiểm tra |
| --- | --- | --- |
| R1 | `core` không import `supabase-js`, framework, `process.env`, DOM | `package.json` của `core` không khai; dependency-cruiser |
| R2 | `supabase` chỉ import `core` và `supabase-js` | dependency-cruiser |
| R3 | App và `nuxt-base` không import `supabase-js` trực tiếp, trừ chỗ tạo client | dependency-cruiser |
| R4 | `supabase` trả kiểu của `core`, không trả `Row` | typecheck (kiểu `Row` không export ra ngoài package) |
| R5 | `core/<A>` dùng `core/<B>` qua `index.ts`, chỉ theo cạnh khai báo, không vòng | dependency-cruiser |
| R6 | `ports/` chỉ chứa interface và kiểu; không import adapter | dependency-cruiser |
| R7 | Adapter dịch vụ ngoài nằm ở app hoặc package adapter, không trong `core` | review + dependency-cruiser |
| R8 | Mọi lỗi ra khỏi `supabase` là `AppError` | test đơn vị của hàm dịch lỗi |

Ranh giới theo module (cạnh cho phép trong `core`): `pos → products, inventory, shared`; `medical → pos, products, inventory, boarding(kennels)`; `boarding → pos`; `shop → products, inventory, shared`; `reports → shared` (chỉ đọc); `spa → pos, products`. `inventory` và `products` không phụ thuộc feature nào khác. Nếu một cạnh mới cần thiết, thêm vào luật và ghi lý do.

## 19. Lộ trình bản 2: PR nhỏ, giữ hành vi, có đường lui

Lộ trình ở mục 8 vẫn đúng (giai đoạn 0 đến 6). Bản 2 thêm **các bước chuẩn bị backend thay được** chèn vào đúng chỗ và một **nhánh B tùy chọn** chỉ làm khi có nhu cầu. Mọi bước dưới đây: không sửa `supabase/migrations`, không chạy migration, không đổi hành vi production.

### 19.1 Bước chuẩn bị (chèn vào giai đoạn 0 và 2)

| PR | Nội dung | Rủi ro | Đường lui |
| --- | --- | --- | --- |
| 0a | Dọn ranh giới (mục 8, giai đoạn 0) | thấp | `git revert` |
| 0b | Thêm `AppError` và hàm dịch lỗi vào `repositories/shared.ts`; `queries/notify.ts` chỉ còn đọc `AppError.code` | thấp | `git revert` |
| 0c | Vitest + test hàm thuần đầu tiên: `utils/shop/shipping.ts`, `utils/shop/cart.ts`, `isExpired`; thêm vào CI | thấp | `git revert` |
| 0d | Gom trùng lặp TS: một nơi định nghĩa `MAX_DELIVERY_G`, trần phí | thấp | `git revert` |
| 2.x (mỗi feature) | `contract.ts` (zod vào/ra, mã lỗi), mapper trả kiểu miền, chuyển repo sang `packages/supabase`; test hình dạng RPC trên DB CI | trung bình (đổi import hàng loạt) | `git revert` PR đó; các feature khác độc lập |
| 2.y | Tách `stores/auth`: phiên và hồ sơ (dùng chung) khỏi `adminGrants`; `core/auth` có kiểu `Session`/`Role` riêng | trung bình | `git revert` |

### 19.2 Nhánh B (tùy chọn, độc lập với việc tách app)

| Bước | Điều kiện bắt đầu | Nội dung | Giao dịch / quyền / tương thích | Đường lui |
| --- | --- | --- | --- | --- |
| B0 | Có yêu cầu thật cần backend (thanh toán, thông báo, mobile) | Quyết định hosting và chi phí (Q9) | | Không làm gì |
| B1 | Sau B0 | `apps/api` (NestJS) chỉ có `/health` và guard xác minh JWT Supabase; chưa chạm DB | Không ảnh hưởng production | Xóa thư mục |
| B2 | Sau B1, khi làm thanh toán | Port `PaymentGateway` trong `core/ports`, adapter SePay, endpoint webhook ở `apps/api`; ghi qua **một RPC mới** `record_payment` (migration riêng, forward-only, idempotent theo mã giao dịch) | Giao dịch nằm trong RPC; webhook dùng service role, có chữ ký và lưu `webhook_events`; không đổi RPC cũ | Tắt webhook trong cấu hình SePay; RPC mới không ảnh hưởng luồng cũ |
| B3 | Khi có kênh thông báo | Port `Notifier`, adapter Zalo/SMS/email, job đọc DB qua RPC | Dùng service role, chỉ đọc danh sách cần nhắc | Tắt job |
| B4 | Chỉ khi cần API chung cho mobile/bên thứ ba | Cổng HTTP cho **một** feature, kiểu S2(a): endpoint gọi lại đúng RPC cũ với JWT của người dùng; thêm adapter HTTP trong `packages/` hoặc app; cờ `NUXT_PUBLIC_BACKEND_<FEATURE>=supabase\|api` | Giao dịch giữ nguyên (vẫn một RPC); RLS vẫn áp dụng vì dùng JWT người dùng; HTTP có `/v1` | Đổi cờ về `supabase` |
| B5 | Chỉ khi có lý do cứng | Cài lại một feature bằng TS (S2(b)), **chạy song song** (shadow): gọi cả hai trên staging, so kết quả; có cờ cắt chuyển | Một giao dịch DB, cùng thứ tự khóa, số chứng từ lấy từ DB; `PermissionService` đọc cùng bảng, pass bộ ca pgTAP dịch sang test tích hợp; hàm SQL cũ giữ ít nhất một chu kỳ phát hành sau cắt chuyển (expand/contract) | Đổi cờ; SQL cũ vẫn còn |

### 19.3 Bảo đảm xuyên suốt

- **Giao dịch:** một thao tác nghiệp vụ là một giao dịch database. Không tách một thao tác ra nhiều lời gọi HTTP. Nếu cài lại bằng TS, dùng một kết nối/giao dịch, giữ nguyên thứ tự khóa của hàm SQL gốc, không sinh số chứng từ trong bộ nhớ ứng dụng.
- **Phân quyền:** ba lớp giữ nguyên: RLS làm lớp chặn cuối (NestJS không kết nối bằng vai trò bỏ qua RLS khi làm thay người dùng), `has_permission` là nguồn sự thật, giao diện chỉ ẩn nút. Bảng `role_permissions`, `staff_branches` vẫn là một nguồn dữ liệu quyền duy nhất.
- **Tương thích ngược:** mục 17.4. Cờ theo từng feature cho phép web chuyển trước, mobile chuyển sau.
- **Đường lui:** mọi bước đổi code dùng `git revert`; mọi bước đổi nơi thực thi dùng cờ cấu hình; không bước nào xóa hàm SQL cũ cho tới khi hết bản client nào gọi.

### 19.4 Khi nào nên làm gì (tóm tắt)

| Tình huống | Làm |
| --- | --- |
| Không có nhu cầu mới, chưa có khách thật | Giai đoạn 0 đến 3 (kể cả 0b, 0c, 0d và 2.x). Dừng. |
| Làm thanh toán SePay thật | Thêm B0 đến B2 |
| Có kênh thông báo | B3 |
| Làm app mobile | Giai đoạn 6; B4 chỉ khi mobile cần API chung (còn không thì gọi thẳng Supabase như web) |
| Gặp giới hạn Supabase hoặc yêu cầu pháp lý | Cân nhắc B5 từng feature; chưa có dấu hiệu nào hôm nay |

## 20. Rủi ro bổ sung

| Rủi ro | Mức | Cách giảm |
| --- | --- | --- |
| Tạo port/interface quá sớm, thêm file mà không có người dùng | Trung bình | Quy tắc rule of two (12.2) và danh sách "không làm" (15.2) |
| Hợp đồng zod lệch với RPC thật vì không ai chạy | Cao nếu bỏ qua | Test hình dạng RPC trong CI (17.5) |
| Quy tắc trùng TS↔SQL lệch dần (phí ship, quyền) | Trung bình | Một nơi định nghĩa + test đối chiếu |
| Cài lại nghiệp vụ bằng TS làm mất khóa/giao dịch (bán âm kho, trùng số chứng từ) | Cao | Chỉ làm B5 khi cần, shadow mode, cùng thứ tự khóa, test cạnh tranh |
| NestJS dùng service role thay người dùng, vô tình bỏ qua RLS | Cao | Quy tắc 15.3: JWT người dùng cho việc của người dùng; service role chỉ cho webhook và cron |
| Chi phí vận hành NestJS (hosting, giám sát) với dự án chưa có doanh thu | Trung bình | Chỉ B1 khi có nhu cầu thật; S1 trước S2/S3 |
| Chia `packages/supabase` làm tăng số bước import khi sửa một feature | Thấp | Mỗi feature vẫn có thư mục tương ứng ở hai nơi, đặt tên giống nhau |

## 21. Quyết định cần grace chọn (bổ sung Q1 đến Q7)

Q7 đổi thành: đặt tên `@bongcun/core`, `@bongcun/supabase`, `@bongcun/nuxt-base`, `@bongcun/config`; không phát hành lên npm.

| # | Câu hỏi | Lựa chọn | Khuyến nghị |
| --- | --- | --- | --- |
| Q8 | Xác thực dài hạn | (a) giữ Supabase Auth ở mọi kịch bản; (b) tự làm auth trong NestJS | **(a)**. Auth tự làm tốn nhiều công và rủi ro bảo mật, trong khi Supabase Auth đang chạy tốt |
| Q9 | Nếu cần NestJS, chạy ở đâu | (a) dịch vụ container giá thấp (Fly.io, Render, Railway); (b) VPS; (c) Vercel serverless | Chọn ở B0, không phải bây giờ. Nghiêng (a); (c) không hợp với webhook cần chạy nền ổn định |
| Q10 | Nguồn sự thật cho tiền và kho | (a) SQL; (b) TS | **(a)** cho tới khi có lý do cứng. TS chỉ xem trước và chặn sớm |
| Q11 | Tách `packages/supabase` ngay ở giai đoạn 2 hay để sau | (a) ngay; (b) sau | **(a)**. Chi phí là thao tác di chuyển có sẵn trong giai đoạn 2; để sau thì phải di chuyển lần hai |
| Q12 | Ports trong đợt này | (a) chỉ dịch vụ ngoài (GHN, thanh toán, lưu file, thông báo); (b) cho mọi feature | **(a)** |
| Q13 | Sinh OpenAPI | (a) chưa; (b) ngay | **(a)**, khi có HTTP thật |
| Q14 | Thêm Vitest và `dependency-cruiser` vào CI | (a) có; (b) không | **(a)**. Hiện TS chưa có test nào; đây là lưới an toàn rẻ nhất cho việc tách code |

## 22. Việc tiếp theo (thay mục 11)

Nếu grace đồng ý Q1 (a), Q8 (a), Q11 (a), Q12 (a), Q14 (a): bắt đầu bằng PR 0a đến 0d (dọn ranh giới, `AppError`, Vitest, gom hằng số trùng), rồi giai đoạn 1 vào lúc không có thread nào đang code, rồi giai đoạn 2 theo từng feature (mỗi PR một feature: hợp đồng, mapper, chuyển repo). Nhánh B chỉ mở khi có yêu cầu thật (thanh toán, thông báo, mobile). Mỗi PR: typecheck, build, CI xanh, squash merge, không đổi migration, không chạy SQL.

## 23. Quyết định đã chốt (grace, 2026-10-16)

| # | Chọn | Hệ quả cho kế hoạch |
| --- | --- | --- |
| Q1 | (a) Làm giai đoạn 0 đến 3 rồi dừng | Không tách CMS (giai đoạn 5) và không làm mobile (giai đoạn 6) trong đợt này. Giai đoạn 4 (layer `nuxt-base`) cũng hoãn: UI dùng chung vẫn nằm trong `apps/web` |
| Q2 | (a) Khi tách CMS thì dùng tên miền con `admin.<domain>` | Chỉ áp dụng khi mở lại giai đoạn 5 |
| Q3 | (b) Mobile là Capacitor bọc Vue | Mobile dùng lại component Vue và `nuxt-base`; app mobile là một app Vue/Nuxt build tĩnh (SPA) bọc bằng Capacitor, không viết lại giao diện. `packages/core` vẫn không phụ thuộc framework (nên giữ), nhưng lợi ích "dùng chung với React Native" không còn là lý do chính. Giai đoạn 6 rẻ hơn kế hoạch cũ: cần plugin Capacitor (camera, thông báo đẩy, lưu file) và adapter lưu file thay vì viết lại UI |
| Q4 | (a) npm workspaces | Giữ `package-lock.json`, chưa dùng Turborepo |
| Q5 | (a) dependency-cruiser | Đưa vào CI ở giai đoạn 0 |
| Q6 | (a) Proxy GHN giữ ở Nuxt server | Không đổi tới khi làm mobile hoặc NestJS |
| Q7 | Theo gợi ý | `@bongcun/core`, `@bongcun/supabase`, `@bongcun/nuxt-base`, `@bongcun/config`; không phát hành lên npm. Vì hoãn giai đoạn 4 nên `nuxt-base` và `config` chưa tạo ngay |
| Q8 | (a) Giữ Supabase Auth ở mọi kịch bản | NestJS (nếu có) chỉ xác minh JWT Supabase |

Q9 đến Q14: grace chọn "theo khuyến nghị" (2026-10-16).

| # | Chọn | Hệ quả |
| --- | --- | --- |
| Q9 | Chưa chọn hosting NestJS, quyết ở bước B0 khi có nhu cầu thật | Không làm gì bây giờ |
| Q10 | SQL là nguồn sự thật cho tiền và kho | TS chỉ xem trước và chặn sớm; quy tắc trùng TS/SQL có test đối chiếu |
| Q11 | Tách `packages/supabase` ngay ở giai đoạn 2 | `core` không có `supabase-js` |
| Q12 | Ports chỉ cho dịch vụ ngoài (GHN, thanh toán, lưu file, thông báo) | Feature khác chỉ thêm interface khi sắp có backend thứ hai |
| Q13 | Chưa sinh OpenAPI | Làm khi có HTTP thật |
| Q14 | Thêm Vitest và dependency-cruiser vào CI | PR 0b, 0c, 0d dùng chúng |

Trạng thái: mọi quyết định cho giai đoạn 0 đến 3 đã chốt. Việc code do thread riêng "Monorepo giai đoạn 0 đến 3" (Sonnet) thực hiện theo kế hoạch này.

## 24. Tiến độ thực hiện (cập nhật 2026-10-16)

Làm theo Q1 (a): giai đoạn 0 đến 3. Mỗi dòng là một PR đã squash merge, CI xanh, không đụng migration.

| Giai đoạn | PR | Nội dung |
| --- | --- | --- |
| 0a | #140 | Sửa import sai chiều, xóa `src/data` và `components/Vouchers`, thêm dependency-cruiser vào CI |
| 0b | #141 | `AppError` và dịch mã lỗi Postgres; `notifyFailure` chỉ đọc mã lỗi |
| 0d | #142 | `MAX_DELIVERY_G`, `MAX_QUOTE_FEE` chỉ còn một chỗ định nghĩa |
| 0c | #143 | Vitest và test đầu tiên, chạy trong CI |
| 1 | #144 | App vào `apps/web`, npm workspaces; `supabase/` ở gốc |
| 2 | #145 đến #151 | `packages/core` (kiểu miền, quy tắc thuần, mã lỗi) và `packages/supabase` (toàn bộ repository, kiểu DB, `unwrap`/`parseRpc`/dịch lỗi). Không còn `apps/web/src/repositories` |

Khác với kế hoạch gốc, có chủ ý:

- Chuyển repository bằng script (`git mv` và viết lại import) theo cụm feature thay vì mapper từng feature. Repository vẫn trả kiểu như trước; mapper sang kiểu miền và `contract.ts` (zod vào/ra) làm dần khi có lý do.
- `packages/supabase` có lib DOM vì `storage.ts` và đính kèm y tế còn nhận `File`; sẽ thành port lưu file khi làm mobile. `core` không có DOM.
- Barrel `export *` theo feature (`@bongcun/core/shop`, `@bongcun/supabase/pos`...) thay vì khai `exports` từng đường con.
- Luật dependency-cruiser: `core` không import framework hay `supabase-js`; `supabase` chỉ import `core`; trong `apps/web` chỉ store `auth` còn import `supabase-js` (sẽ tách ở giai đoạn 3).
- Hợp đồng zod, mapper, test hình dạng RPC trên DB CI và test đối chiếu quyền (mục 17.5) chưa làm; cần DB trong test.
- Nitro inline `@bongcun/core` để bundle server (proxy GHN) không import TypeScript ngoài.
