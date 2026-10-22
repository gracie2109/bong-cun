# Kế hoạch nối Pawtiny với Location Service (P1–P5)

Ngày lập: 2026-10-22. grace duyệt hướng làm ngày 2026-10-22 ("ừ, làm đi em"). Tài liệu này là kế hoạch chi tiết để code các bước **P1–P5** trong repo `bong-cun`. Thiết kế gốc: [`docs/location-service/kien-truc.md`](./location-service/kien-truc.md) (mục 7, 8), contract [`openapi.yaml`](./location-service/openapi.yaml), audit và nghiên cứu nguồn ở mục 1–2 của [`ke-hoach-dia-gioi-hanh-chinh.md`](./ke-hoach-dia-gioi-hanh-chinh.md).

Ký hiệu: **[XM]** đã xác minh (đọc code hoặc chạy thật), **[GĐ]** giả định thiết kế, **[CXM]** chưa xác minh, phải kiểm trước bước phụ thuộc.

---

## 0. Tóm tắt và quyết định

1. Pawtiny giữ **bản cache chỉ đọc** của danh mục trong Supabase của mình: bảng `location_catalogs`, `location_units`, `location_provider_codes`. Pawtiny **không** đọc database (Neon) của Location Service, và lúc chạy (form địa chỉ, checkout, tính phí) **không gọi** API của dịch vụ. Dịch vụ ngừng thì Pawtiny vẫn chạy bình thường.
2. Dữ liệu vào cache **chỉ bằng migration**: workflow "Location sync" của `bong-cun` lấy snapshot từ API, so với trạng thái đã đồng bộ lần trước (lưu trong repo), sinh một file migration dữ liệu và mở PR. Merge PR thì workflow "Supabase migrate" có sẵn chạy nó. Không thêm secret database nào.
3. Cache chỉ giữ **cấp tỉnh và cấp xã đang hiệu lực** (34 + 3.321 dòng). Đơn vị đã có trong cache mà sau này hết hiệu lực thì chuyển `status = 'retired'`, không bao giờ xóa. Cấp huyện và danh mục cũ 63 tỉnh không vào cache (địa chỉ cũ của Pawtiny theo mã GHN 3 cấp, không theo mã Nhà nước, nên bảng kế thừa không nối được với chúng).
4. Địa chỉ mới lưu `location_model = 'vn_2025'` + `code` của dịch vụ (`vn_...`) + mã Nhà nước + tên chụp lại. Địa chỉ cũ giữ `location_model = 'ghn_legacy'` và cách tính phí cũ; **không có migration nào đổi địa chỉ cũ**.
5. Mã GHN 2 cấp chỉ được dùng khi tính phí nếu **cùng môi trường GHN** với gateway Pawtiny đang gọi (production). Hiện mapping lấy từ gateway TEST, nên cho đến khi grace chạy lại trên production, địa chỉ mới dùng **phí cố định** (đã là cách xử lý khi GHN không trả lời). Không bao giờ chặn khách đặt hàng vì thiếu mã.
6. Mỗi bước một PR, squash merge. Code theo quy tắc tách file của grace (UI, composable, helper, type riêng; mỗi file dưới khoảng 300 dòng) và bố cục monorepo (`packages/core`, `packages/supabase`, `apps/web/src/features/*`).

---

## 1. Hiện trạng (đã đọc ngày 2026-10-22)

### 1.1 Location Service [XM]

- Live ở `https://location-service-alpha.vercel.app`, danh mục đã nạp: hiện hành 34 tỉnh, 3.321 xã (hiệu lực 2025-07-01); danh mục cũ 63 tỉnh, 696 huyện, 10.030 xã; 10.481 dòng kế thừa.
- `GET /api/v1/catalog/snapshot` (API key, scope `catalog:snapshot`; thêm `?providers=ghn` cần thêm scope `provider-codes:read`) trả **NDJSON**: một dòng `{"type":"catalog",...}`, rồi mỗi đơn vị một dòng `{"type":"location", code, level, unit_type, official_code, name, full_name, name_en, full_name_en, parent_code, status, effective_from, effective_to, centroid}` (**gồm cả đơn vị đã hết hiệu lực**, khoảng 14.000 dòng), rồi các dòng `succession`, rồi `{"type":"provider_code", code, provider, provider_model, provider_code, provider_parent_code, provider_name, match_method, verified_at}` (`src/providers/snapshot.controller.ts`).
- `provider_model` hiện chỉ có `ghn_v2` (mô hình 2 cấp mới của GHN). `provider_code` của tỉnh là `_id` của GHN, của xã là mã xã GHN; `provider_parent_code` của xã là mã tỉnh GHN; `provider_name` là tên GHN nguyên văn.
- Mapping GHN được ghi từ **gateway TEST** (`dev-online-gateway.ghn.vn`): 34/34 tỉnh, khoảng 3.314/3.321 xã đã xác nhận; 7 xã chưa nối (Ia HDreh, Lục Sỹ Thành, Tà Si Láng, Xá Nhè, Ba Tơ, Tân Thanh...). Token production của grace đang bị 401; grace sẽ báo khi chạy lại trên production.
- **Snapshot không cho biết mapping lấy từ môi trường GHN nào** (bảng `location.provider_codes` không có cột môi trường). Đây là lỗ hổng phải vá trước P2 (mục 3).
- API key: tạo bằng CLI `node dist/cli/api-keys.js create --name ... --scopes ...`, key in ra màn hình **một lần**. Chưa có workflow tạo key, chưa có key nào cho Pawtiny.
- Môi trường cloud của Claude **không gọi được** `*.vercel.app` (proxy 403) và không gọi được GHN; GitHub Actions thì gọi được. Vì thế mọi bước chạm API thật đều chạy trong Actions.

### 1.2 Pawtiny (`bong-cun`, commit `f21eed3`) [XM]

| Nơi | Hiện tại |
| --- | --- |
| `customer_addresses` | `street`, `province_name`, `district_name`, `ward_name`, `ghn_province_id`, `ghn_district_id`, `ghn_ward_code` đều NOT NULL (GHN 3 cấp). Ghi qua `save_my_address(p jsonb)`, đọc qua `my_addresses()` + `address_json(a)`. |
| `shop_orders` | Snapshot `ship_street`, `ship_ward_name`, `ship_district_name`, `ship_province_name`, `ghn_district_id`, `ghn_ward_code`. CHECK `shop_orders_check`: `(delivery_method = 'delivery') = (ghn_district_id is not null and ghn_ward_code is not null)`. Ghi trong `create_shop_order`. `shipping_fee_quote` do client gửi, server kẹp 0–500.000. |
| `shop_settings` | Kho gửi `ghn_from_province_id`, `ghn_from_district_id`, `ghn_from_ward_code`, `from_address_text`. Ghi qua `save_shop_settings(p jsonb)`. |
| `branches` | `address text` tự do. Không có màn sửa cơ sở trong admin, nên **ngoài phạm vi** P1–P5. |
| Frontend | `components/common/GhnLocationPicker.vue` + `features/shared/shop/composables/useGhnLocationPicker.ts` + `queries/ghnLocations.ts`, dùng ở `components/shop/AddressFormDialog.vue` và `features/admin/shop-orders/settings/components/ShippingCard.vue`. `ProvinceAddress.vue` chỉ còn ở `features/admin/users/components/InfomationForm.vue` (cột `users.address` jsonb cũ, ngoài phạm vi). |
| Tính phí | `apps/web/server/api/ghn/shipping-fee.post.ts` + `leadtime.post.ts`, body dựng ở `server/utils/ghnQuote.ts` từ `fromDistrictId/fromWardCode/toDistrictId/toWardCode`, gọi `https://online-gateway.ghn.vn` (production) trong `server/utils/ghn.ts`. Client: `features/shop/checkout/composables/useShippingQuote.ts`, admin "Tính lại phí GHN": `features/admin/shop-orders/composables/useOrderFeeQuote.ts`. Pawtiny **không** tạo vận đơn qua API (`ship_shop_order` nhận mã vận đơn nhập tay). |
| Migration | Mới nhất trên `main`: `20261030010000_cancelled_bookings_scope.sql`. Số mới phải lớn hơn số này (không phải `20261025*` như ghi chú cũ). `supabase/schema.sql` chỉ dump schema `public`. |
| Tìm không dấu | `public.immutable_unaccent()` + chỉ mục `gin_trgm_ops`. |

---

## 2. Nguyên tắc

- Cache là **bản sao chỉ đọc**: client không có quyền ghi; RPC đọc là `security definer`, `stable`, `search_path = ''`. Chỉ migration (vai trò `postgres`) ghi vào ba bảng cache.
- Không đoán mã: mã GHN chỉ lấy từ mapping đã xác nhận ở Location Service. Không bao giờ ghép theo tên trong Pawtiny.
- Snapshot đơn hàng giữ nguyên tinh thần hiện tại: đơn đã tạo không đọc lại danh mục để hiển thị.
- Migration forward-only, idempotent, số tăng dần; trước mỗi PR kiểm lại số mới nhất trên `main`.
- Tương thích ngược cho app mobile bản cũ: `save_my_address` vẫn nhận payload GHN 3 cấp như cũ.

---

## 3. Việc cần làm trước ở Location Service (S8, repo `location-service`)

Hai PR nhỏ, thêm vào (không phá contract v1).

### S8a. Ghi môi trường GHN của mapping

- Migration mới: `alter table location.provider_codes add column provider_environment text not null default 'test' check (provider_environment in ('production','test'))` (giá trị mặc định `test` vì mọi dòng hiện có lấy từ gateway test). Tương tự cho `provider_code_proposals` nếu bảng đó giữ đề xuất qua nhiều lần sync.
- `ghn sync` / `confirm*` ghi `provider_environment` theo input `environment` của workflow `ghn-sync.yml` (đã có).
- Thêm `provider_environment` vào `ProviderCodeView` (cả `/provider-codes` lẫn dòng `provider_code` của snapshot) và `openapi.yaml`. Đây là trường mới, client cũ bỏ qua được.
- Khi chạy lại trên production: các dòng production thay dòng test (deactivate dòng test cùng `code`), để mỗi đơn vị chỉ có một mapping sống.
- Test: snapshot trả `provider_environment`; sync production thay dòng test.

### S8b. Cấp API key cho Pawtiny mà không lộ key

Key không được in ra log Actions. Đề xuất [GĐ]: workflow chạy tay "Issue API key" (input `client`, `scopes`) chạy CLI `create` với cờ mới `--quiet-json`, rồi ghi thẳng key vào secret `LOCATION_SERVICE_KEY` của repo `bong-cun` bằng `gh secret set --repo gracie2109/bong-cun`, dùng một fine-grained PAT (`BONGCUN_SECRETS_TOKEN`, chỉ repo `bong-cun`, quyền **Secrets: read and write**) do grace tạo một lần. Bước có `::add-mask::` cho key. Key không bao giờ xuất hiện ở đâu khác.

Phương án dự phòng nếu grace không muốn tạo PAT: workflow mã hóa key bằng `gpg --symmetric` với `BACKUP_PASSPHRASE` và để thành artifact 1 ngày; grace tải về giải mã trên máy tính rồi dán vào secret. Cách này khó làm trên iPad nên chỉ là dự phòng.

Scope cho Pawtiny: `catalog:snapshot,provider-codes:read`, rate limit mặc định 120/phút (một lần sync gọi 1 request).

---

## 4. P1: bảng cache và RPC đọc

**Migration:** `supabase/migrations/20261101010000_location_cache.sql` (kiểm lại số trên `main`). **Không có dữ liệu thật** trong migration này; bảng rỗng cho đến khi P2 chạy.

### 4.1 Bảng

```sql
create table if not exists public.location_catalogs (
  id            text primary key,          -- id phiên bản danh mục của dịch vụ (dòng "catalog" của snapshot)
  source        text not null,
  source_ref    text,
  effective_on  date not null,
  extracted_at  timestamptz,
  checksum      text,                      -- checksum dịch vụ báo, để soát
  is_current    boolean not null default false,
  record_counts jsonb not null default '{}', -- số dòng cache sau lần sync này: {provinces, communes, retired, ghn}
  synced_at     timestamptz not null default now()
);
create unique index if not exists location_catalogs_current on public.location_catalogs (is_current) where is_current;

create table if not exists public.location_units (
  code          text primary key check (code ~ '^vn_[0-9a-z]{20}$'),  -- `code` của Location Service, chuỗi mờ
  level         text not null check (level in ('province','commune')),
  unit_type     text not null,             -- giữ nguyên enum của dịch vụ (ward, commune, special_zone, province, municipality...)
  official_code text,                      -- mã Nhà nước, chuỗi (giữ số 0 đầu)
  name          text not null,             -- "Bến Thành"
  full_name     text not null,             -- "Phường Bến Thành"
  parent_code   text references public.location_units(code),          -- null ở tỉnh
  status        text not null check (status in ('active','retired')),
  effective_from date not null,
  effective_to  date,
  catalog_id    text not null references public.location_catalogs(id), -- lần sync ghi dòng này lần cuối
  search_key    text generated always as (lower(public.immutable_unaccent(full_name || ' ' || name))) stored,
  updated_at    timestamptz not null default now(),
  check ((level = 'province') = (parent_code is null))
);
create index if not exists location_units_parent_active on public.location_units (parent_code) where status = 'active';
create index if not exists location_units_search on public.location_units using gin (search_key extensions.gin_trgm_ops);

create table if not exists public.location_provider_codes (
  code                 text not null references public.location_units(code),
  provider             text not null check (provider in ('ghn')),
  provider_model       text not null check (provider_model in ('ghn_v2')),
  provider_environment text not null check (provider_environment in ('production','test')),
  provider_code        text not null,
  provider_parent_code text,
  provider_name        text not null,      -- tên GHN nguyên văn (có thể cần khi tính phí, mục 8)
  match_method         text not null,
  verified_at          timestamptz,
  active               boolean not null default true,
  catalog_id           text not null references public.location_catalogs(id),
  primary key (provider, provider_model, code)
);
```

- Ba bảng: `enable row level security`, **không** có policy, `revoke all ... from anon, authenticated` (giống `shop_settings`).
- Kiểm `immutable_unaccent` bỏ được `đ` → `d`; nếu không thì thêm `replace(..., 'đ', 'd')` trong biểu thức sinh cột [CXM, kiểm bằng pgTAP].
- Không có bảng kế thừa ở P1 (xem mục 0.3). Nếu sau này cần gợi ý "xã cũ này nay là xã nào" thì thêm `location_successions` bằng migration mới.

### 4.2 RPC đọc (grant `anon`, `authenticated`)

| RPC | Trả về |
| --- | --- |
| `location_provinces()` | `[{ code, official_code, name, full_name, unit_type }]`, chỉ `active`, sắp theo `full_name` (collation mặc định; tiếng Việt đủ dùng [GĐ]) |
| `location_communes(p_province text, p_search text default null, p_page int default 1, p_page_size int default 500)` | `{ items: [{ code, official_code, name, full_name, unit_type }], total }`, chỉ `active` và đúng tỉnh; `p_search` so `search_key` bằng `like '%' || chuẩn hóa(p_search) || '%'`. Tỉnh lớn nhất khoảng 170 xã nên trang mặc định lấy hết. |
| `location_unit(p_code text)` | `{ code, level, official_code, name, full_name, unit_type, status, province: { code, full_name } \| null }`, kể cả `retired` (để hiển thị địa chỉ đã lưu) |
| `location_search(p_search text, p_page int default 1, p_page_size int default 20)` | `{ items: [{ code, full_name, unit_type, province: { code, full_name } }], total }`, chỉ xã `active`, xếp khớp đầu chuỗi trước |
| `location_catalog()` | `{ id, source, effective_on, synced_at, record_counts }` của dòng `is_current`, hoặc `null` khi chưa sync |

Lỗi (`hint` → `AppError`): `location_not_found`, `location_search_too_short` (dưới 2 ký tự sau chuẩn hóa), `invalid_input` (page_size quá 500, p_province không phải tỉnh). Thêm vào bảng mã lỗi trong `packages/core` và `apps/web/tests/unit/errorHintModules.ts`.

Mã GHN **không** có trong các RPC này; chỉ có RPC riêng ở P5.

### 4.3 Code TypeScript

```
packages/core/src/locations/
  types.ts        # LocationUnit, LocationRef, LocationValue, LocationCatalog
  contracts.ts    # zod cho kết quả RPC + mapper snake_case → camelCase
  format.ts       # formatLocationLine(street, ward, province) cho địa chỉ 2 cấp
  index.ts
packages/supabase/src/locations/
  locations.ts    # getProvinces, getCommunes, getLocation, searchLocations, getCatalog
  index.ts
```

`packages/core/src/index.ts` và `packages/supabase/src/index.ts` export thêm `locations`; thêm subpath `@bongcun/core/locations` nếu các module khác đang dùng subpath (theo cách `@bongcun/core/shop`).

### 4.4 Test P1

- pgTAP `supabase/tests/location_cache.test.sql`: bảng và chỉ mục tồn tại; `anon`/`authenticated` không `select` thẳng được; `location_provinces` chỉ trả `active`; `location_communes` đúng tỉnh, tìm không dấu ("ben thanh", "BẾN THÀNH", "phuong ben thanh" đều ra "Phường Bến Thành"), phân trang, `invalid_input`; `location_unit` trả được dòng `retired`; mã lạ → `location_not_found`; chuỗi tìm 1 ký tự → `location_search_too_short`; `location_catalog()` null khi rỗng. Dữ liệu là bộ nhỏ tự tạo trong file test, ghi rõ "chỉ dùng cho test".
- Contract test `apps/web/tests/db/locations.contract.test.ts`: kết quả RPC qua zod.
- Unit: `format.ts`.

---

## 5. P2: đồng bộ từ Location Service

Cần: S8a, S8b đã merge; secret `LOCATION_SERVICE_KEY` có trong `bong-cun`; biến (Variable, không phải secret) `LOCATION_SERVICE_URL = https://location-service-alpha.vercel.app`.

### 5.1 Trạng thái đã đồng bộ nằm trong repo

```
supabase/data/locations/
  README.md            # nguồn, cách chạy, không sửa tay
  state.json           # { catalog: {...}, units: { [code]: {...} }, ghn: { [code]: {...} } } sắp theo code
```

`state.json` là bản chuẩn hóa của những gì **migration đã ghi** (sau lọc), khoảng 1 MB [GĐ]. Nhờ nó script tính được diff mà không cần đọc database Supabase, và PR cho thấy rõ thay đổi.

### 5.2 Script

Node 22, không thêm dependency, theo kiểu `apps/web/scripts/*.mjs` sẵn có. Hàm thuần tách riêng để test:

```
apps/web/scripts/location-sync/
  run.mjs           # CLI: tải snapshot → parse → diff với state.json → ghi migration + state.json + report.md
  fetchSnapshot.mjs # GET {URL}/api/v1/catalog/snapshot?providers=ghn, header Authorization: Bearer; timeout 60 s; 1 lần thử lại khi 5xx/mạng
  parseNdjson.mjs   # tách theo "type", kiểm từng dòng (code dạng vn_..., level, status...)
  selectRows.mjs    # lọc: level province/commune; đơn vị mới chỉ nhận khi active; đơn vị đã có trong state thì cập nhật dù retired
  diffState.mjs     # thêm / đổi / ngừng / giữ nguyên cho units và ghn
  checks.mjs        # các chốt an toàn ở 5.3
  writeMigration.mjs# sinh SQL
  writeReport.mjs   # report.md cho thân PR
  migrationName.mjs # số migration: lớn hơn cả giờ UTC hiện tại lẫn số mới nhất trong supabase/migrations
```

Cờ: `--dry-run` (chỉ in báo cáo), `--from-file <ndjson>` (dùng file snapshot có sẵn, để test và để chạy lại khi API ngừng).

### 5.3 Chốt an toàn (dừng, không sinh file, workflow đỏ)

- Dòng `catalog` thiếu, hoặc `effective_on` cũ hơn phiên bản trong `state.json` (không cho lùi phiên bản).
- Số tỉnh `active` khác 34 hoặc số xã `active` lệch quá 2% so với lần trước (lần đầu: so với 3.321), trừ khi workflow chạy với input `allow_count_change = true`.
- Có xã `active` mà `parent_code` không phải tỉnh `active` trong cùng snapshot.
- Có quá 50 đơn vị chuyển `retired` trong một lần, trừ khi có `allow_count_change`.
- Mapping GHN trỏ tới `code` không có trong cache.
- Không có gì đổi: thoát xanh, không mở PR.

### 5.4 Migration sinh ra

Ví dụ `supabase/migrations/20261101020000_location_sync_<catalog-id>.sql`, một giao dịch (`db push` chạy mỗi file trong transaction):

1. `insert into location_catalogs ... on conflict (id) do update set record_counts = excluded.record_counts, synced_at = now()`; đặt `is_current` cho đúng một dòng.
2. Upsert `location_units` theo thứ tự tỉnh rồi xã (vì FK `parent_code`), dạng `insert ... values (...), (...) on conflict (code) do update set ... where (location_units.*) is distinct from (...)`. Chia lô 500 dòng mỗi câu lệnh để file dễ đọc và không quá dài.
3. Đơn vị có trong state nhưng snapshot báo `retired` hoặc biến mất: `update ... set status = 'retired', effective_to = ...`. Không `delete`.
4. Upsert `location_provider_codes` theo khóa chính; mapping biến mất thì `active = false`.
5. Cuối file: khối `do $$ ... $$` kiểm lại số dòng `active` (34 tỉnh, số xã như báo cáo), sai thì `raise exception` để cả migration rollback.

Lần chạy đầu file khoảng 1 MB [GĐ]; lần sau chỉ chứa diff. Chạy lại cùng file trên database đã có dữ liệu không đổi gì (idempotent).

### 5.5 Workflow `.github/workflows/location-sync.yml`

- `workflow_dispatch` (input `dry_run`, `allow_count_change`) và `schedule` mỗi thứ Hai 04:00 giờ VN (`0 21 * * 0` UTC) [GĐ, danh mục ít đổi; bỏ lịch nếu grace muốn chỉ chạy tay].
- Bước: checkout → setup-node 22 → `node apps/web/scripts/location-sync/run.mjs` → nếu có file mới: chạy `npm run db:start && npm run db:test` ngay trong job (vì PR do `GITHUB_TOKEN` mở **không kích hoạt** CI của PR) → tạo nhánh `location-sync/<catalog-id>-<yyyymmdd>`, commit (tác giả grace theo quy ước repo), mở PR bằng `gh pr create` với `report.md` làm thân.
- `permissions: contents: write, pull-requests: write`. Không có secret database. Key chỉ đọc qua `secrets.LOCATION_SERVICE_KEY`, không in ra.
- Merge PR sync là việc của người (grace hoặc thread đang làm), theo quy ước squash. Sau merge "Supabase migrate" tự chạy.

### 5.6 Test P2

- Unit (Vitest, `apps/web/tests/unit/locationSync*.test.ts`) với snapshot mẫu nhỏ tự tạo (`apps/web/tests/fixtures/location-snapshot.ndjson`, ghi rõ dữ liệu giả): parse, lọc (bỏ huyện, bỏ đơn vị cũ chưa từng cache), diff (thêm/đổi/ngừng), mọi chốt ở 5.3, tên migration luôn lớn hơn số mới nhất, SQL sinh ra ổn định (cùng đầu vào → cùng file, test snapshot), chạy hai lần liên tiếp → lần hai không sinh gì.
- pgTAP: chạy file migration sinh từ fixture trên database test, kiểm số dòng, chạy lại không đổi, đơn vị retired vẫn đọc được qua `location_unit`.
- Thật: chạy workflow `dry_run` trên Actions, đọc báo cáo (kỳ vọng 34 tỉnh, 3.321 xã, khoảng 3.348 mapping `test`), rồi chạy thật, review PR, merge.

---

## 6. P3: nâng cấp bảng địa chỉ và RPC ghi

**Migration:** `2026110103xxxx_addresses_location_cache.sql` (sau migration dữ liệu P2 nếu P2 merge trước; FK không cần dữ liệu nên thứ tự P2/P3 không bắt buộc). Hàm sửa phải chép từ định nghĩa hiện tại trong `supabase/schema.sql`, chỉ sửa phần địa chỉ.

### 6.1 Cột

| Bảng | Thêm | Nới |
| --- | --- | --- |
| `customer_addresses` | `location_model text not null default 'ghn_legacy' check (location_model in ('ghn_legacy','vn_2025'))`, `province_location_code text references location_units(code)`, `ward_location_code text references location_units(code)`, `province_official_code text`, `ward_official_code text` | `district_name`, `ghn_province_id`, `ghn_district_id`, `ghn_ward_code` thành nullable. CHECK mới: `ghn_legacy` → đủ 4 cột GHN như cũ; `vn_2025` → có `ward_location_code` và `province_location_code`. Các CHECK `*_district_name_check`, `*_ghn_ward_code_check` hiện có vẫn đúng với giá trị null (CHECK null là qua). |
| `shop_orders` | `ship_location_model text`, `ship_ward_location_code text`, `ship_province_location_code text`, `ship_ward_official_code text`, `ship_province_official_code text` (không FK: đây là snapshot) | Thay `shop_orders_check` bằng CHECK mới: `(delivery_method = 'delivery') = ((ghn_district_id is not null and ghn_ward_code is not null) or ship_ward_location_code is not null)`. Thêm `not valid`, `validate`, rồi `drop constraint if exists shop_orders_check` trong cùng migration. |
| `shop_settings` | `from_ward_location_code text references location_units(code)`, `from_street text` | giữ cột GHN cũ |

Dữ liệu cũ không đổi. Không thêm cột GHN 2 cấp vào địa chỉ: mã GHN luôn tra từ cache lúc tính phí (P5), nên mapping sửa ở dịch vụ thì địa chỉ cũ tự đúng theo.

### 6.2 RPC

- `save_my_address(p)`: có `ward_location_code` → kiểm đơn vị tồn tại, `level = 'commune'`, `status = 'active'`; tỉnh suy từ `parent_code` (client không gửi tỉnh); chép `full_name` của xã và tỉnh vào `ward_name`/`province_name`, mã Nhà nước, `location_model = 'vn_2025'`; xóa (`null`) các cột GHN và `district_name`. Lỗi mới: `location_not_found`, `location_inactive`. Không có `ward_location_code` → nhánh cũ nguyên văn (app mobile bản cũ).
- `address_json(a)`: thêm `location_model`, `province_location_code`, `ward_location_code`, `province_official_code`, `ward_official_code`. Giữ các khóa cũ (có thể null).
- `create_shop_order`: với địa chỉ `vn_2025` chép các cột `ship_*_location_code`, `ship_*_official_code`, `ship_location_model`; `ghn_district_id`/`ghn_ward_code` để null. Địa chỉ `ghn_legacy` như cũ (`ship_location_model = 'ghn_legacy'`). `shipping_fee_quote` giữ nguyên cách kẹp hiện tại.
- JSON đơn hàng (hàm ở `schema.sql` dòng có `'ship_street', o.ship_street`, cả bản khách lẫn admin): thêm `ship_location_model` và hai mã `location_code`.
- `save_shop_settings(p)` và JSON cài đặt (public + admin): nhận/trả `from_ward_location_code`, `from_street`; kiểm như `save_my_address`.

### 6.3 TypeScript

- `packages/core/src/shop/shop.ts`, `address.ts`: `Address` thêm `locationModel`, `wardLocationCode`, `provinceLocationCode`; trường GHN thành `number | null`. `AddressForm.location` đổi thành `LocationValue` (`{ provinceCode, provinceName, wardCode, wardName }`); `formToInput` gửi `ward_location_code`. `formatAddress` bỏ quận/huyện khi null.
- `packages/supabase/src/shop/addresses.ts`, `orders.ts`, `ordersAdmin.ts`: mapper + zod theo cột mới.
- Hiển thị đơn (`OrderInfo.vue`, `OrderDetailInfo.vue`) dùng `formatAddress`, không tự ghép quận.

### 6.4 Test P3

pgTAP `supabase/tests/addresses_location_cache.test.sql`: lưu `vn_2025` đúng, suy tỉnh từ xã; xã retired → `location_inactive`; mã lạ → `location_not_found`; gửi mã tỉnh làm xã → lỗi; payload GHN cũ vẫn lưu được và vẫn là `ghn_legacy`; giới hạn 10 địa chỉ và địa chỉ mặc định không đổi; `create_shop_order` với cả hai loại địa chỉ (CHECK mới nhận cả hai, đơn pickup không có mã nào); đơn cũ trong database test vẫn hợp lệ sau `validate`. Unit: `address.ts` (form ↔ input cho cả hai mô hình). Contract test DB cho `my_addresses`.

---

## 7. P4: component chọn địa chỉ 2 cấp và tích hợp

### 7.1 File

```
apps/web/src/features/shared/locations/
  queries/locationKeys.ts             # khóa có catalogId: ['locations', catalogId, 'communes', provinceCode]
  queries/useLocationQueries.ts       # useLocationCatalog (staleTime 1 giờ), useProvinces, useCommunes (staleTime Infinity)
  composables/useLocationPicker.ts    # trạng thái tỉnh → xã, reset xã khi đổi tỉnh
  helpers/pickerState.ts              # hàm thuần: pickProvince, pickWard, isComplete, filterOptions (không dấu, phía client)
  components/LocationPicker.vue       # 2 combobox (components/ui/combobox có sẵn), không có ô quận/huyện
  components/LegacyAddressNotice.vue  # "Địa chỉ theo địa giới cũ, vui lòng chọn lại phường/xã" + tên cũ
  types.ts
  index.ts
```

- `v-model: LocationValue | null`; chỉ phát giá trị lấy từ danh sách server. Props `disabled`, `required`. Trạng thái tải (skeleton), lỗi (dòng báo + nút thử lại), rỗng ("Không có phường/xã khớp"). Hiện `unit_type` khi hai xã trùng tên trong một tỉnh.
- Chữ giao diện vào `i18n/locales/vi.json`, `en.json`.
- Chạy được cả SSR web lẫn SPA mobile (chỉ gọi RPC Supabase, không gọi Nuxt server). Thêm `features/shared/locations` vào `index.ts` barrel và luật dependency-cruiser như các feature khác.

### 7.2 Nơi đổi

1. `components/shop/AddressFormDialog.vue`: thay `GhnLocationPicker` bằng `LocationPicker`. Sửa địa chỉ `ghn_legacy`: hiện `LegacyAddressNotice`, ô chọn trống, bắt chọn lại trước khi lưu (lưu xong thành `vn_2025`). Thêm mới luôn là `vn_2025`.
2. `features/admin/shop-orders/settings/components/ShippingCard.vue`: kho gửi chọn bằng `LocationPicker` + `from_street`; giữ hiển thị cột GHN cũ (chỉ đọc) đến khi P5 xong.
3. Checkout không đổi giao diện; `useShippingQuote` xử lý ở P5. Trong khoảng giữa P4 và P5, địa chỉ `vn_2025` không có mã GHN nên `places` = null → phí cố định "ước tính" (hành vi có sẵn).
4. Sau P4 không còn nơi nào dùng `GhnLocationPicker`, `useGhnLocationPicker`, `ghnLocations`, `services/location.service.ts` (trừ `ProvinceAddress` ở form user cũ, kiểm lại bằng `rg`): xóa ở P5 cùng route master-data.

### 7.3 Test P4

Unit `pickerState` (đổi tỉnh xóa xã; chưa chọn xã thì chưa đủ; lọc không dấu), `locationKeys` (đổi catalogId thì đổi khóa). Typecheck, build, `generate:mobile`, `deps:check`. Repo không có `@vue/test-utils` nên giao diện grace bấm thử cuối ngày.

---

## 8. P5: tính phí GHN bằng mã lấy từ cache

> **Cập nhật 2026-10-22 (grace gửi ảnh tài liệu GHN "Calculate Fee"):** API phí GHN đang dùng (`/v2/shipping-order/fee`) chỉ nhận `to_district_id` + `to_ward_code` (3 cấp cũ), không có tham số cho địa chỉ 2 cấp mới. Vì vậy P5 rút gọn: địa chỉ `ghn_legacy` vẫn tính phí GHN như cũ, địa chỉ `vn_2025` dùng phí cố định "ước tính" (đường dự phòng có sẵn). Chỉ xóa phần picker GHN cũ không còn dùng (`GhnLocationPicker`, `useGhnLocationPicker`, `ghnLocations`, `ghnLocationKeys`); route master-data và `services/location.service.ts` giữ lại vì `ProvinceAddress` (form người dùng cũ) còn dùng. Phần thiết kế dưới đây để dành khi GHN có API phí cho địa chỉ mới.

### 8.1 Phải xác minh trước khi code [CXM]

- Body của `/v2/shipping-order/fee` và `/leadtime` cho **địa chỉ 2 cấp mới**. Theo tài liệu GHN grace đã dán cho phần danh mục: địa chỉ mới gửi `to_province_name`/`to_ward_name` đúng chuỗi `name` của GHN kèm `is_new_to_address: true`; chưa đọc tài liệu "Tính phí" nên chưa biết có nhận `to_ward_code` mới không, và phía gửi (`from_*`) dùng gì. **Bước đầu của P5: xin grace dán tài liệu "Tính phí" và "Thời gian giao dự kiến" (bản đơn vị hành chính mới)**. Môi trường cloud không mở được developer.ghn.vn.
- Mã GHN ở gateway test có trùng production không. Không giả định; chặn bằng `provider_environment` (8.3).

### 8.2 Thiết kế

- RPC `location_ghn_refs(p_codes text[])` (grant `anon`, `authenticated`; tối đa 2 mã; chỉ trả mapping `active` của các mã được hỏi): `[{ code, provider_environment, province: { provider_code, provider_name }, ward: { provider_code, provider_name } | null }]`.
- `apps/web/server/providers/ghn/` (tách từ `server/utils/ghn.ts`, `ghnQuote.ts`, giữ hành vi cũ):
  - `client.ts`: gọi HTTP như `ghnFetch` hiện tại.
  - `legacyBody.ts`: body 3 cấp hiện có (`feeBody`, `leadtimeBody`).
  - `v2Body.ts`: body 2 cấp theo tài liệu ở 8.1.
  - `resolvePlaces.ts`: nhận `{ from: PlaceRef, to: PlaceRef }`, mỗi `PlaceRef` là `{ kind: 'ghn_legacy', districtId, wardCode }` hoặc `{ kind: 'vn_2025', wardLocationCode }`; tra `location_ghn_refs`; chọn body. Không có mapping, khác môi trường, hoặc trộn hai mô hình mà GHN không nhận → lỗi `location_not_mapped` (409).
  - `errors.ts`: `provider_not_configured` 503, `provider_unavailable` 502, `provider_rejected` 422, `location_not_mapped` 409. Không log token hay body GHN.
- `shipping-fee.post.ts`, `leadtime.post.ts`: zod nhận dạng mới (`PlaceRef`) **và** dạng cũ (4 số GHN) để app mobile bản cũ vẫn chạy.
- Biến môi trường mới `NUXT_GHN_ENVIRONMENT` (mặc định `production`, khớp `online-gateway`). Mã có `provider_environment` khác giá trị này thì coi như chưa nối.
- Client: `useShippingQuote` và `useOrderFeeQuote` dựng `PlaceRef` từ địa chỉ/đơn hàng và kho gửi (`from_ward_location_code` nếu có, không thì cột GHN cũ). Lỗi `location_not_mapped` → phí cố định, nhãn "phí ước tính" như hiện tại. Hàm dựng `PlaceRef` đặt ở `packages/core/src/shop/shippingPlace.ts` (thuần, test được).
- Xóa: `server/api/ghn/provinces|districts|wards.get.ts`, `GhnLocationPicker.vue`, `useGhnLocationPicker.ts`, `ghnLocations.ts`, phần master-data của `location.service.ts` (sau khi `rg` xác nhận không còn nơi dùng). Giữ route tính phí dạng cũ cho địa chỉ `ghn_legacy`.

### 8.3 Khi nào phí thật chạy cho địa chỉ mới

Ngay khi đủ ba điều: P5 merge, Location Service có mapping `production` (grace chạy lại GHN sync với token production, rồi `Location sync` mở PR và được merge), và body v2 đã khớp tài liệu. Trước đó địa chỉ mới dùng phí cố định. Địa chỉ cũ tính phí như hôm nay.

### 8.4 Test P5

Unit: `resolvePlaces` (legacy/legacy, v2/v2, thiếu mapping, khác môi trường, dạng cũ của client), `v2Body`, `shippingPlace.ts`, phân loại lỗi. pgTAP `location_ghn_refs` (giới hạn 2 mã, không lộ mapping inactive, mã lạ → mảng rỗng). Thật: grace thử checkout trên Vercel với một địa chỉ mới sau khi có mapping production.

---

## 9. Thứ tự, số migration, việc của grace

| Thứ tự | PR | Repo | Migration | Ai chặn |
| --- | --- | --- | --- | --- |
| 1 | S8a môi trường GHN của mapping | location-service | migration Node của dịch vụ | không |
| 2 | P1 cache + RPC đọc | bong-cun | `20261101010000_location_cache.sql` | không (làm song song với 1) |
| 3 | S8b workflow cấp key | location-service | không | không |
| 4 | P2 script + workflow sync | bong-cun | không (script sinh sau) | không |
| 5 | Lần sync đầu (PR do workflow mở) | bong-cun | `202611010200xx_location_sync_*.sql` (do script đặt) | **grace**: tạo PAT `BONGCUN_SECRETS_TOKEN` trong location-service, chạy "Issue API key", thêm Variable `LOCATION_SERVICE_URL` |
| 6 | P3 cột địa chỉ + RPC | bong-cun | `2026110103xxxx_addresses_location_cache.sql` | không |
| 7 | P4 `LocationPicker` + tích hợp | bong-cun | không | không |
| 8 | P5 tính phí từ cache | bong-cun | `2026110104xxxx_location_ghn_refs.sql` | **grace**: dán tài liệu GHN "Tính phí" (bản mới) |
| 9 | Đồng bộ lại mapping production | cả hai | migration sync mới | **grace**: token GHN production, rồi bảo chạy lại GHN sync (production) và Location sync |

Số migration ở trên là dự kiến; mỗi PR kiểm lại số mới nhất trên `main` và luôn lấy số lớn hơn. Script sync tự lấy số lớn hơn mọi file có sẵn.

Không có SQL nào grace phải dán tay: mọi migration chạy qua "Supabase migrate" khi merge.

Sau khi xong, grace bấm thử: thêm/sửa địa chỉ trên web và app (chọn tỉnh, gõ tìm xã không dấu), sửa một địa chỉ cũ (phải chọn lại), cài kho gửi, đặt một đơn giao hàng với địa chỉ mới (phí ước tính cho đến bước 9), xem đơn ở admin.

---

## 10. Rủi ro

| Rủi ro | Xử lý |
| --- | --- |
| Mapping GHN đang là của gateway test | Cột `provider_environment` + `NUXT_GHN_ENVIRONMENT`; khác môi trường thì phí cố định. Không dùng mã test để tính phí production. |
| Từ P4 đến bước 9, địa chỉ mới chỉ có phí cố định | Chủ ý (đã là đường dự phòng hiện có, không chặn đặt hàng). Nếu grace muốn giữ phí GHN thật cho khách mới thì làm bước 9 trước khi merge P4. |
| Body tính phí 2 cấp của GHN chưa rõ | P5 bắt đầu bằng đọc tài liệu; thiếu tài liệu thì P5 vẫn merge được với v2 trả `location_not_mapped` (phí cố định), chỉ phần legacy chạy. |
| Location Service ngừng hoặc trả dữ liệu sai | Pawtiny không gọi dịch vụ lúc chạy; sync có chốt an toàn ở 5.3 và PR có người đọc trước khi vào production. |
| Danh mục đổi (xã lên phường, nhập xã) | Đơn vị cũ thành `retired`, địa chỉ đã lưu vẫn hiển thị tên chụp lại; `save_my_address` không nhận đơn vị retired nên khách chọn lại khi sửa. Gợi ý đơn vị kế thừa để sau. |
| PR do workflow mở không chạy CI | Workflow tự chạy `db:start` + `db:test` trước khi mở PR; người merge vẫn xem báo cáo. |
| API key lộ | Key chỉ ở secret; S8b ghi thẳng vào secret, có `add-mask`; thu hồi bằng CLI `revoke` và cấp lại. |
| Supabase FREE | Khoảng 3.400 dòng đơn vị + 3.400 dòng mapping, không đáng kể. |

## 11. Ngoài phạm vi

Địa chỉ cơ sở (`branches`, chưa có màn sửa), `users.address` jsonb và `ProvinceAddress.vue`, bảng kế thừa và gợi ý cập nhật địa chỉ cũ, tọa độ, báo cáo theo địa bàn (làm được khi đơn mới có `ship_ward_location_code`), tạo vận đơn GHN qua API, repo gateway vận chuyển riêng.
