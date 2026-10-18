# Kế hoạch LocationModule: địa giới hành chính, địa chỉ và mapping GHN

Ngày lập: 2026-10-18.

> **Đã thay một phần (2026-10-18):** grace chọn làm Location Service thành một dự án NestJS riêng. Mục 3, 4, 5, 6, 7 và 9 bên dưới được thay bằng [`docs/location-service/kien-truc.md`](./location-service/kien-truc.md) và contract [`openapi.yaml`](./location-service/openapi.yaml). Mục 1 (audit) và mục 2 (nguồn dữ liệu, GHN) vẫn dùng. Không code theo các bước L1–L10 nữa.

Ký hiệu trong tài liệu:

- **[XM]** đã xác minh từ nguồn (có link ở mục 2.4).
- **[GĐ]** giả định thiết kế, chọn phương án an toàn nhất.
- **[CXM]** chưa xác minh được, phải kiểm lại trước khi làm bước phụ thuộc vào nó.

---

## 1. Audit codebase (Giai đoạn 0)

### 1.1 Kiến trúc hiện tại [XM, đọc trực tiếp repo ở commit `09a29ae`]

- Monorepo npm workspaces: `apps/web` (Nuxt 4, Vue 3, Tailwind, shadcn-vue trên reka-ui, TanStack Query), `packages/core` (type, zod contract, hàm thuần), `packages/supabase` (gọi RPC, mapper), `apps/mobile` (vỏ Capacitor). Ranh giới kiểm bằng dependency-cruiser (`npm run deps:check`).
- Backend là **Supabase Postgres**: logic nghiệp vụ nằm trong RPC `security definer`, lỗi trả về bằng `raise ... using hint = '<code>'`, phía client đổi thành `AppError` qua `toAppError`. Không có ORM.
- Nuxt server (`apps/web/server`) chỉ làm proxy cho thứ cần bí mật: `server/utils/ghn.ts` gọi `https://online-gateway.ghn.vn/shiip/public-api` bằng `runtimeConfig.ghn.token`/`shopId`; có middleware rate limit và CORS cho app mobile.
- Phân quyền: `has_permission(module, method, branch)` theo (nhân viên, cơ sở). Route server kiểm quyền bằng cách gọi RPC với token của người gọi (`server/utils/staffAuth.ts`), không dùng service key.
- Migration: `supabase/migrations/`, forward-only, idempotent, chạy tự động khi merge vào `main` (workflow "Supabase migrate"). Mới nhất đã chạy: `20261026010000_security_hardening.sql`. `supabase/schema.sql` sinh tự động, CI báo lỗi nếu cũ.
- Test: pgTAP ở `supabase/tests/*.test.sql`, contract test DB ở `apps/web/tests/db` (`npm run test:db`), unit test Vitest ở `apps/web/tests/unit`. Không có `@vue/test-utils`; logic UI được test qua hàm thuần và composable tách khỏi component. Không có script lint riêng; CI chạy typecheck, deps:check, test, build và DB test.
- Tìm kiếm không dấu dùng `public.immutable_unaccent()` + chỉ mục `gin_trgm_ops` (ví dụ `customers_search_idx`).

### 1.2 Nơi đang lưu địa chỉ

| Nơi | Cách lưu hiện tại | Ghi chú |
| --- | --- | --- |
| `customer_addresses` (sổ địa chỉ của khách mua online) | `street` + `province_name`, `district_name`, `ward_name` (NOT NULL) + `ghn_province_id`, `ghn_district_id`, `ghn_ward_code` (NOT NULL) | Mô hình 3 cấp của GHN. Lưu qua RPC `save_my_address`, lỗi `address_location` khi thiếu cấp nào. |
| `shop_orders` | Snapshot `ship_street`, `ship_ward_name`, `ship_district_name`, `ship_province_name`, `ghn_district_id`, `ghn_ward_code` | CHECK `shop_orders_check`: giao hàng thì bắt buộc có `ghn_district_id` và `ghn_ward_code`. Snapshot chép trong `create_shop_order`. |
| `shop_settings` (kho gửi hàng) | `ghn_from_province_id`, `ghn_from_district_id`, `ghn_from_ward_code`, `from_address_text`, `pickup_address` | Một dòng duy nhất. |
| `branches` (cơ sở: shop, spa, phòng khám) | `address text` tự do | Không có đơn vị hành chính. |
| `suppliers` | `address text` tự do | Ngoài phạm vi. |
| `users.address` (jsonb, cũ) | `{ address, ward{WardCode,WardName}, district{...}, province{...} }` theo GHN | Ghi từ form tạo khách cũ (`CustomerCreateSheet` → `ProvinceAddress.vue`). `customers` (CRM tại quầy) không có cột địa chỉ. |

### 1.3 Component và service địa chỉ ở frontend

- `components/common/GhnLocationPicker.vue` (56 dòng) + `features/shared/shop/composables/useGhnLocationPicker.ts` + `features/shared/shop/queries/ghnLocations.ts`: chọn tỉnh → huyện → xã theo GHN, reset cấp dưới khi đổi cấp trên, cache `staleTime: Infinity`. Dùng ở `components/shop/AddressFormDialog.vue` (sổ địa chỉ khách) và `features/admin/shop-orders/settings/components/ShippingCard.vue` (kho gửi).
- `components/common/ProvinceAddress.vue` (216 dòng, cũ, gắn vee-validate, chữ tiếng Anh): chỉ còn dùng ở `features/admin/users/components/InfomationForm.vue`.
- `services/location.service.ts`: gọi `/api/ghn/provinces|districts|wards`, nuốt lỗi bằng `console.log` (lỗi API không hiện lên UI).
- Type: `packages/core/src/users/location.ts` (`GHNProvince`, `IAddress`, `initAddress`), `packages/core/src/shop/address.ts` + `shop.ts` (`GhnLocation`, `Address`, `AddressInput`).
- Tính phí: `features/shop/checkout/composables/useShippingQuote.ts` gửi mã GHN của địa chỉ lên `/api/ghn/shipping-fee`; GHN không trả lời thì dùng phí cố định `flat_shipping_fee`.

### 1.4 Vấn đề phát hiện

1. **Danh mục địa giới của cả hệ thống đang là danh mục của GHN**, gọi trực tiếp mỗi lần mở form. Không có bảng đơn vị hành chính nội bộ, không có mã chính thức, không có phiên bản. Trái nguyên tắc "Petshop sở hữu dữ liệu địa lý".
2. **Vẫn bắt chọn quận/huyện** dù từ 01/07/2025 mô hình là 2 cấp (mục 2.1). Các cột `*_district_*` đều NOT NULL.
3. Hai component chọn địa chỉ trùng chức năng (`GhnLocationPicker`, `ProvinceAddress`) và `users.address` jsonb là cấu trúc thứ ba.
4. Lỗi GHN ở `location.service.ts` bị nuốt; form không có trạng thái lỗi.
5. `branches.address` là chữ tự do: không tổng hợp được theo địa bàn, không làm điểm gửi hàng cho nhiều cơ sở.
6. Báo cáo theo địa bàn hiện không làm được vì tên tỉnh/xã là chuỗi.

### 1.5 Phương án tích hợp (tóm tắt)

- Thêm **danh mục đơn vị hành chính nội bộ** trong Postgres, nạp từ danh mục chính thức của Nhà nước, có phiên bản và hiệu lực.
- **Nâng cấp** `customer_addresses`, `shop_orders`, `shop_settings`, `branches` bằng cột mới trỏ vào danh mục (nullable, không xóa cột cũ). Không tạo bảng `addresses` song song.
- Bảng **mapping nhà vận chuyển** tách riêng; adapter GHN ở Nuxt server dùng mapping đó để tính phí. Mã GHN không bao giờ là khóa chính.
- Một component chọn địa chỉ 2 cấp dùng chung, đọc danh mục qua RPC Supabase (chạy được cả web SSR lẫn app mobile SPA), thay `GhnLocationPicker` ở hai nơi đang dùng.

---

## 2. Nghiên cứu dữ liệu địa giới và GHN (Giai đoạn 1)

### 2.1 Mô hình đơn vị hành chính đang có hiệu lực

- [XM] Nghị quyết 202/2025/QH15 (Quốc hội thông qua 12/06/2025, hiệu lực ngay): cả nước còn **34 đơn vị hành chính cấp tỉnh** (28 tỉnh, 6 thành phố). Chính quyền các tỉnh mới hoạt động từ **01/07/2025**.
- [XM] Từ 01/07/2025 chính quyền địa phương **2 cấp**: tỉnh/thành phố → xã/phường/đặc khu. Cấp huyện không còn.
- [XM] Quyết định 19/2025/QĐ-TTg (ký 30/06/2025, hiệu lực 01/07/2025) ban hành Bảng danh mục và mã số đơn vị hành chính: Phụ lục I gồm 34 đơn vị cấp tỉnh (mã 2 chữ số), Phụ lục II gồm **3.321 đơn vị cấp xã** (mã 5 chữ số).
- [XM] Mã số là định danh duy nhất, cố định trong suốt thời gian đơn vị tồn tại; mã đã cấp không cấp lại cho đơn vị khác cùng cấp. Khi nhập xã, đơn vị mới nhận mã của xã đặt trụ sở UBND, mã còn lại bị loại (nguyên tắc từ QĐ 124/2004/QĐ-TTg, được nhắc lại trong các bài hướng dẫn).
- [XM] Cục Thống kê đã ra Công văn 915/CTK-CSCL (16/06/2025) và 1027/CTK-CSCL (25/06/2025) thông báo tên và mã xã mới; bản 1027 có phụ lục các xã đổi tên/mã so với bản 915. Nghĩa là danh sách dự thảo từng khác bản chính thức: **chỉ dùng phụ lục của QĐ 19/2025 hoặc danh mục trên cổng của Cục Thống kê**.

### 2.2 Thay đổi có thể ảnh hưởng dữ liệu

- [XM] Danh mục **vẫn đang thay đổi sau 2025**: Nghị quyết 112/2025/UBTVQH15 (24/12/2025) đặt tiêu chuẩn đơn vị cấp xã áp dụng từ 01/01/2026; các tỉnh đang lập đề án chuyển xã thành phường hoặc nhập xã nhỏ (ví dụ HĐND Khánh Hòa ngày 12/06/2026 tán thành đề án thành lập 4 phường trên nguyên trạng 4 xã; đây mới là bước HĐND, chưa phải nghị quyết UBTVQH).
- [CXM] Khi một xã chuyển thành phường "trên nguyên trạng", mã 5 chữ số có giữ nguyên không. Thiết kế phải chịu được cả hai trường hợp (mục 3.2).
- [CXM] Danh sách đầy đủ các thay đổi đã có hiệu lực từ 07/2025 đến nay (10/2026). Không tra được cổng Cục Thống kê từ môi trường làm việc; bước L1 phải lấy bản danh mục mới nhất và ghi rõ ngày trích xuất.
- [XM] Dữ liệu cũ (63 tỉnh, cấp huyện, khoảng 10.000 xã) vẫn xuất hiện trong địa chỉ đã lưu: toàn bộ `customer_addresses` và `shop_orders` hiện có đều theo mô hình 3 cấp của GHN.

### 2.3 GHN

- [XM, từ code repo và tài liệu cũ] API danh mục cũ: `GET /master-data/province`, `GET /master-data/district` (header `province_id`), `GET /master-data/ward?district_id=` dưới `https://online-gateway.ghn.vn/shiip/public-api`, xác thực bằng header `Token`. Các route này **không cần `ShopId`** (repo đã gọi với `withShop: false`). Tính phí và thời gian giao (`/v2/shipping-order/fee`, `/leadtime`) cần `Token` + `ShopId` và dùng `to_district_id` (int) + `to_ward_code` (text).
- [XM, qua kết quả tìm kiếm trang GHN Developer] Cổng tài liệu GHN có thêm **"Get Province (New)"** và **"Get Ward (New)"** trong mục Master Data, và tài liệu Tạo đơn có ghi chú "trường hợp dùng đơn vị hành chính mới 2 cấp thì tham khảo tài liệu riêng".
- [CXM] **Không đọc được nội dung** ba trang `developer.ghn.vn/vi/docs/master-data/get-province-new`, `get-ward-new`, `get-ward`: tên miền `developer.ghn.vn` và `api.ghn.vn` không phân giải được từ môi trường làm việc (proxy chặn), Firecrawl hết hạn mức. Vì vậy chưa xác minh: đường dẫn, tham số, các trường trả về (có mã chính thức của Nhà nước không, có trạng thái, tên thay thế, quan hệ với mã cũ không), phân trang, giới hạn tần suất, và việc API tính phí/tạo đơn có nhận mã 2 cấp mới hay vẫn cần `to_district_id`.
- [GĐ] Vì thế adapter GHN được thiết kế cho cả hai khả năng: (a) GHN mới trả mã 2 cấp riêng và nhận chúng khi tính phí; (b) GHN vẫn chỉ tính phí theo cặp `district_id` + `ward_code` cũ. Bảng mapping lưu được cả hai (mục 3.4). Bước L6 bắt đầu bằng việc đọc ba trang tài liệu trên và gọi thử (chỉ GET danh mục) qua proxy đã triển khai.
- [XM] Điều khoản: chưa thấy điều khoản cấm lưu danh mục GHN; tuy vậy [GĐ] chỉ lưu những cột cần cho mapping, không phát hành lại danh mục GHN cho bên thứ ba.

### 2.4 Nguồn dữ liệu được chọn

| Mục đích | Nguồn chính | Trạng thái |
| --- | --- | --- |
| Danh mục hiện hành (34 tỉnh, xã/phường/đặc khu) | Cổng Danh mục hành chính của Cục Thống kê `danhmuchanhchinh.gso.gov.vn` (xuất Excel), đối chiếu Phụ lục I, II của QĐ 19/2025/QĐ-TTg | Nguồn đã xác minh là chính thức; **file chưa tải được** từ môi trường làm việc |
| Danh mục cũ (63 tỉnh, 3 cấp) | Cùng cổng Cục Thống kê, chọn ngày trước 01/07/2025 | [CXM] cổng có cho chọn ngày; làm sau, không bắt buộc cho MVP |
| Bảng cũ → mới | 34 nghị quyết của UBTVQH về sắp xếp đơn vị cấp xã từng tỉnh (2025) | Chỉ nạp khi có file đối chiếu được với nghị quyết; mặc định **không** nạp |
| Mapping GHN | API danh mục GHN, đọc qua proxy server | [CXM] mục 2.3 |

Các bộ dữ liệu cộng đồng (gói npm, repo GitHub, file Excel trên blog) **chỉ dùng để đối chiếu** khi kiểm tra, không nạp làm dữ liệu production.

Nguồn đã đọc:

- Nghị quyết 202/2025/QH15: [vanban.chinhphu.vn](https://vanban.chinhphu.vn/?pageid=27160&docid=213930), [toàn văn trên xaydungchinhsach.chinhphu.vn](https://xaydungchinhsach.chinhphu.vn/toan-van-nghi-quyet-so-202-2025-qh15-ve-sap-xep-don-vi-hanh-chinh-cap-tinh-119250612174148722.htm)
- QĐ 19/2025/QĐ-TTg: [thuvienphapluat.vn](https://thuvienphapluat.vn/van-ban/Bo-may-hanh-chinh/Quyet-dinh-19-2025-QD-TTg-Bang-danh-muc-va-ma-so-cac-don-vi-hanh-chinh-Viet-Nam-663707.aspx), [luatvietnam.vn](https://luatvietnam.vn/hanh-chinh/quyet-dinh-19-2025-qd-ttg-cua-thu-tuong-chinh-phu-ban-hanh-bang-danh-muc-va-ma-so-cac-don-vi-hanh-chinh-viet-nam-404751-d1.html), [laichau.gov.vn (34 tỉnh, 3.321 xã)](https://laichau.gov.vn/tin-tuc-su-kien/chuyen-de/tinh-gon-to-chuc-bo-may-cua-he-thong-chinh-tri/bang-danh-muc-va-ma-so-cua-34-tinh-thanh-moi-3321-don-vi-hanh-chinh-cap-xa-moi.html)
- Công văn 1027/CTK-CSCL: [thuvienphapluat.vn](https://thuvienphapluat.vn/cong-van/Bo-may-hanh-chinh/Cong-van-1027-CTK-CSCL-2025-thong-bao-ma-so-va-ten-don-vi-hanh-chinh-cap-xa-moi-665444.aspx); 915/CTK-CSCL: [thuvienphapluat.vn](https://thuvienphapluat.vn/cong-van/Bo-may-hanh-chinh/Cong-van-915-CTK-CSCL-2025-thong-bao-ten-don-vi-hanh-chinh-cap-xa-moi-684702.aspx)
- Tiêu chuẩn đơn vị cấp xã 2026 (NQ 112/2025/UBTVQH15): [thuvienphapluat.vn](https://thuvienphapluat.vn/chinh-sach-phap-luat-moi/vn/ho-tro-phap-luat/tu-van-phap-luat/114308/tieu-chuan-don-vi-hanh-chinh-cap-xa-moi-nhat-2026-xa-phuong-va-dac-khu)
- GHN: [GHN Developer](https://developer.ghn.vn/en) (chỉ thấy mục lục qua tìm kiếm), [API Tạo đơn hàng](https://api.ghn.vn/home/docs/detail?id=122), [API Tính phí](https://api.ghn.vn/home/docs/detail?id=95), [API Get Ward cũ](https://api.ghn.vn/home/docs/detail?id=61)

---

## 3. Thiết kế dữ liệu (Giai đoạn 2–3)

Tên bảng tiếng Anh, theo quy ước repo. Mọi bảng mới bật RLS; client **không có quyền ghi** trực tiếp, chỉ đọc qua RPC.

### 3.1 `admin_unit_catalogs`: phiên bản danh mục

```sql
create table public.admin_unit_catalogs (
  id            text primary key,          -- ví dụ 'gso-2025-07-01', 'gso-2026-03-15'
  source        text not null,             -- 'gso' | 'decision-19-2025' | 'legacy-gso'
  source_ref    text not null,             -- số văn bản / URL cổng / ngày trích xuất
  effective_on  date not null,             -- ngày danh mục có hiệu lực
  extracted_on  date not null,             -- ngày tải file từ nguồn
  file_sha256   text not null,             -- băm file gốc để biết đã nạp đúng file nào
  is_current    boolean not null default false,
  stats         jsonb not null default '{}', -- {provinces, wards, added, updated, unchanged, retired}
  imported_at   timestamptz not null default now()
);
create unique index on public.admin_unit_catalogs (is_current) where is_current;
```

### 3.2 `admin_units`: đơn vị hành chính (cả hiện hành lẫn lịch sử)

```sql
create table public.admin_units (
  id             uuid primary key default gen_random_uuid(),  -- ID nội bộ ổn định
  official_code  text not null,             -- mã Nhà nước: 2 số (tỉnh), 3 số (huyện cũ), 5 số (xã)
  level          text not null check (level in ('province','district','ward')),
  unit_type      text not null,             -- 'tinh','thanh_pho','phuong','xa','dac_khu','quan','huyen','thi_xa','thi_tran',...
  name           text not null,             -- tên chính thức đầy đủ: 'Phường Bến Thành'
  short_name     text not null,             -- 'Bến Thành' (bỏ tiền tố loại đơn vị) để hiển thị gọn
  search_name    text generated always as (lower(public.immutable_unaccent(name))) stored,
  parent_id      uuid references public.admin_units(id),
  valid_from     date not null,
  valid_to       date,                      -- null = đang hiệu lực
  catalog_id     text not null references public.admin_unit_catalogs(id), -- danh mục nạp ra dòng này
  retired_by     text references public.admin_unit_catalogs(id),          -- danh mục đóng dòng này
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (valid_to is null or valid_to > valid_from),
  check (official_code ~ '^[0-9]{2,5}$')
);
-- Mỗi mã chỉ có một dòng đang hiệu lực ở mỗi cấp; lịch sử cùng mã được giữ bằng valid_from khác nhau.
create unique index admin_units_code_current on public.admin_units (level, official_code) where valid_to is null;
create unique index admin_units_code_from on public.admin_units (level, official_code, valid_from);
create index admin_units_parent_current on public.admin_units (parent_id) where valid_to is null;
create index admin_units_search on public.admin_units using gin (search_name extensions.gin_trgm_ops);
```

Quy tắc:

- **Hiện hành** = `valid_to is null`. Mọi RPC danh sách mặc định lọc điều kiện này, nên dữ liệu lịch sử không lọt vào form.
- Cấp `district` chỉ tồn tại cho dữ liệu lịch sử. Xã hiện hành có `parent_id` là tỉnh. Không có trường "huyện" trong form mới.
- Đổi tên hoặc đổi loại (xã → phường) mà **giữ mã**: đóng dòng cũ (`valid_to = ngày hiệu lực`), thêm dòng mới cùng mã, và ghi một dòng `admin_unit_successions` loại `renamed`. Vì `id` mới khác `id` cũ nên địa chỉ cũ vẫn trỏ đúng tên tại thời điểm lưu; tra cứu "đơn vị này giờ là gì" đi qua bảng kế thừa.
- Đổi mã (nhập, chia): dòng cũ đóng, dòng mới mở; quan hệ cũ → mới chỉ ghi khi có văn bản xác nhận (mục 3.3).
- Không bao giờ `delete` dòng nào. Không có trigger cascade xóa.
- `alias`: [GĐ] không làm bảng tên thay thế riêng ở MVP vì nguồn chính thức không cung cấp. Tìm kiếm không dấu trên `name` và `short_name` là đủ; tên cũ của một đơn vị tìm được qua dòng lịch sử của nó. Khi có nguồn tên thay thế đáng tin (ví dụ "TP.HCM", "Sài Gòn"), thêm bảng `admin_unit_aliases(unit_id, alias, search_alias)` ở bước sau.
- Tọa độ, ranh giới, vùng giao hàng: [GĐ] chưa thêm cột. Khi cần thì thêm `centroid` (PostGIS `geography(point)`, extension có sẵn trên Supabase) hoặc bảng `admin_unit_geometries` riêng, không ảnh hưởng bảng này.

### 3.3 `admin_unit_successions`: đối chiếu cũ → mới

```sql
create table public.admin_unit_successions (
  from_unit_id uuid not null references public.admin_units(id),
  to_unit_id   uuid not null references public.admin_units(id),
  kind         text not null check (kind in ('renamed','merged_into','split_into','part_moved_to')),
  is_whole     boolean not null,       -- true: toàn bộ đơn vị cũ thuộc đơn vị mới; false: chỉ một phần
  basis        text not null,          -- số nghị quyết, ví dụ '1656/NQ-UBTVQH15'
  effective_on date not null,
  catalog_id   text not null references public.admin_unit_catalogs(id),
  primary key (from_unit_id, to_unit_id)
);
```

- Chỉ nạp từ file có nguồn văn bản. Không suy ra từ tên trùng nhau.
- Một xã cũ bị chia cho nhiều xã mới → nhiều dòng `is_whole = false`. Khi đó **không** tự đổi địa chỉ; UI chỉ gợi ý danh sách và để người dùng chọn.

### 3.4 `admin_unit_provider_codes`: mapping nhà vận chuyển

```sql
create table public.admin_unit_provider_codes (
  id              uuid primary key default gen_random_uuid(),
  unit_id         uuid not null references public.admin_units(id),
  provider        text not null check (provider in ('ghn')),
  provider_model  text not null check (provider_model in ('ghn_v2','ghn_legacy')), -- 2 cấp mới hoặc 3 cấp cũ của GHN
  provider_code   text not null,       -- mã GHN của chính đơn vị: ProvinceID / WardCode (luôn lưu dạng text)
  provider_parent text,                -- ghn_legacy: DistrictID mà GHN cần kèm WardCode khi tính phí
  provider_name   text not null,       -- tên GHN tại lúc nối, để soát lệch
  match_method    text not null check (match_method in ('official_code','staff_confirmed')),
  confirmed_by    uuid,                -- null khi match theo mã chính thức
  verified_at     timestamptz not null default now(),
  is_active       boolean not null default true
);
create unique index on public.admin_unit_provider_codes (provider, provider_model, unit_id) where is_active;
create unique index on public.admin_unit_provider_codes (provider, provider_model, provider_code) where is_active;
```

- Mã GHN không bao giờ là khóa chính hay khóa ngoại của danh mục nội bộ.
- `match_method = 'official_code'`: chỉ khi GHN trả kèm mã Nhà nước và mã đó khớp. `staff_confirmed`: nhân viên có quyền đã duyệt trên màn đối chiếu (mục 5.3). Không có cách nào khác để tạo mapping, nên **không bao giờ tự đoán mã GHN từ tên**.
- Thiếu mapping = không có dòng; adapter trả lỗi `location_not_mapped` và checkout dùng phí cố định như hiện tại.

### 3.5 Nâng cấp bảng địa chỉ có sẵn (không xóa cột, không đổi dữ liệu cũ)

| Bảng | Thêm | Nới |
| --- | --- | --- |
| `customer_addresses` | `province_unit_id uuid`, `ward_unit_id uuid` (FK `admin_units`), `location_model text not null default 'ghn_legacy' check in ('ghn_legacy','admin_v2')` | `district_name`, `ghn_province_id`, `ghn_district_id`, `ghn_ward_code` thành nullable (`alter column ... drop not null`). Thêm CHECK: `location_model = 'ghn_legacy'` thì đủ 3 mã GHN như cũ; `'admin_v2'` thì bắt buộc `ward_unit_id`, `province_unit_id`. |
| `shop_orders` | `ship_ward_unit_id uuid`, `ship_province_code text`, `ship_ward_code text` (mã Nhà nước chụp lại lúc đặt), `ship_provider_ref jsonb` (mã GHN đã dùng để tính phí, chụp lại) | Sửa CHECK `shop_orders_check`: giao hàng thì có (`ghn_district_id` và `ghn_ward_code`) **hoặc** `ship_ward_unit_id`. Bằng cách tạo CHECK mới `not valid` rồi `validate`, sau đó drop CHECK cũ trong cùng migration (không đụng dữ liệu). |
| `shop_settings` | `from_ward_unit_id uuid`, `from_street text` | giữ cột GHN cũ |
| `branches` | `street text`, `ward_unit_id uuid` | giữ `address` (chữ tự do) để hiển thị đến khi nhân viên nhập lại |

- Dòng cũ giữ nguyên `location_model = 'ghn_legacy'` và vẫn tính phí GHN bằng mã cũ khi GHN còn nhận. **Không** có migration nào chuyển địa chỉ cũ sang mã mới.
- `users.address` jsonb: không đụng. Form tạo khách ở admin (`ProvinceAddress`) chuyển sang component mới ở bước L8 nếu còn dùng; nếu không ai đọc cột này nữa thì để lại, ghi chú trong docs.
- `customers` (CRM tại quầy) chưa có địa chỉ: ngoài phạm vi, component mới dùng được khi cần.

### 3.6 Snapshot đơn hàng

`create_shop_order` (chép nguyên văn từ `schema.sql` sang migration mới, chỉ sửa phần địa chỉ): với địa chỉ `admin_v2` thì chép tên xã/tỉnh hiện tại, mã Nhà nước, `ship_ward_unit_id`, và mã GHN lấy từ mapping (nếu có) vào `ship_provider_ref` + `ghn_ward_code`/`ghn_district_id` (nếu là `ghn_legacy` mapping). Đơn đã tạo không bao giờ đọc lại danh mục để hiển thị: tên in trên đơn là snapshot.

### 3.7 RLS và quyền

- Ba bảng danh mục, kế thừa, mapping: `enable row level security`, không có policy cho `anon`/`authenticated` (chỉ đọc qua RPC `security definer`), giống cách repo đang làm với `shop_settings`.
- Ghi danh mục: chỉ qua migration (vai trò `postgres` khi workflow chạy). Không có RPC ghi danh mục cho client.
- Ghi mapping: RPC `save_provider_codes(jsonb)` kiểm `has_permission('shop_orders','UPDATE', null)` (cùng quyền đang sửa "Cài đặt bán online"). [GĐ] Không thêm module quyền mới để grace không phải tick thêm.

---

## 4. API (Giai đoạn 4)

Theo quy ước repo, API là **RPC Postgres** gọi qua `packages/supabase`, contract zod ở `packages/core/src/locations`. Chỉ một route Nuxt server mới cho GHN.

### 4.1 RPC đọc (grant `anon`, `authenticated`; `stable`, `security definer`, `search_path = ''`)

| RPC | Mục đích | Trả về |
| --- | --- | --- |
| `location_provinces()` | Tỉnh/thành hiện hành, sắp theo tên | `[{ id, code, name, short_name, unit_type }]` (34 dòng) |
| `location_wards(p_province uuid, p_search text default null, p_page int default 1, p_page_size int default 500)` | Xã/phường/đặc khu hiện hành của một tỉnh, có tìm không dấu | `{ items: [{ id, code, name, short_name, unit_type }], total }`. Tỉnh nhiều nhất khoảng 170 xã nên trang mặc định lấy hết; vẫn có `page`/`page_size` theo quy ước getList. |
| `location_unit(p_id uuid)` | Chi tiết một đơn vị, kể cả lịch sử | `{ id, code, level, name, unit_type, valid_from, valid_to, is_current, parent: {...}, successors: [...] }` |
| `location_search(p_search text, p_level text default 'ward', p_page int, p_page_size int default 20)` | Ô tìm nhanh "gõ tên phường" toàn quốc | `{ items: [{ id, code, name, province: { id, name } }], total }`, chỉ hiện hành |
| `location_catalog()` | Phiên bản danh mục đang dùng | `{ id, source, source_ref, effective_on, extracted_on, stats }` |

Lỗi (hint → `AppError`): `location_not_found` (id/mã không có), `location_search_too_short` (dưới 2 ký tự), `invalid_input` (page_size quá 500). Bổ sung vào bảng mã lỗi `packages/core` và `tests/unit/errorHintModules.ts`.

Ví dụ:

```jsonc
// location_wards('0b1e…', 'ben', 1, 500)
{ "items": [{ "id": "7c2a…", "code": "26734", "name": "Phường Bến Thành", "short_name": "Bến Thành", "unit_type": "phuong" }], "total": 1 }
```

(Mã trong ví dụ chỉ minh họa định dạng, không phải dữ liệu thật.)

### 4.2 RPC ghi có sẵn được nâng cấp

- `save_my_address(p jsonb)`: nhận thêm `ward_unit_id`. Có `ward_unit_id` → kiểm đơn vị đang hiệu lực, cấp `ward`, suy `province_unit_id` từ `parent_id` (client không tự gửi tỉnh để tránh lệch), lưu `location_model = 'admin_v2'`, chép tên. Lỗi mới: `location_inactive` (đơn vị đã hết hiệu lực), `location_parent_mismatch`. Không có `ward_unit_id` → nhánh cũ giữ nguyên (để bản app mobile cũ chưa cập nhật vẫn chạy).
- `save_shop_settings`, RPC sửa cơ sở (`branches`): nhận `from_ward_unit_id`/`ward_unit_id` + `street`, kiểm như trên.
- `address_json` thêm `ward_unit_id`, `province_unit_id`, `location_model`, `is_current` (đơn vị còn hiệu lực không).

### 4.3 Cache

- Client: TanStack Query `staleTime: Infinity`, khóa có `catalogId` (`locationKeys.wards(catalogId, provinceId)`), nên khi nạp danh mục mới thì khóa đổi và dữ liệu tự tải lại. `location_catalog()` có `staleTime` 1 giờ.
- Server: không thêm tầng cache; truy vấn chỉ mục trên vài nghìn dòng là đủ nhanh trên gói FREE.

### 4.4 Route Nuxt server cho GHN (adapter)

- `POST /api/ghn/shipping-fee` và `/leadtime`: nhận **thêm** dạng `{ fromWardUnitId, toWardUnitId, weightG, insuranceValue }`. Server gọi RPC `provider_codes_for(p_units uuid[], p_provider 'ghn')` (grant `anon`, chỉ trả mã GHN của các đơn vị được hỏi) rồi dựng body GHN. Dạng cũ (mã GHN trực tiếp) vẫn nhận cho địa chỉ `ghn_legacy`.
- `GET /api/admin/locations/ghn-diff`: chỉ nhân viên có quyền (kiểm bằng token người gọi như `staffAuth.ts`), gọi **chỉ các endpoint GET danh mục** của GHN, trả danh sách: đã nối, khớp mã chính thức (có thể nối ngay), cần người xác nhận, GHN có mà danh mục mình không có.
- Không có route nào gọi endpoint ghi của GHN (tạo/sửa/hủy đơn).

---

## 5. Frontend (Giai đoạn 5)

### 5.1 Cấu trúc file (mỗi file dưới khoảng 300 dòng)

```
packages/core/src/locations/
  types.ts            # AdminUnit, AdminUnitRef, LocationValue, CatalogInfo
  contracts.ts        # zod cho kết quả RPC + mapper
  normalize.ts        # bỏ dấu, chuẩn hóa khoảng trắng, tách tiền tố "Phường/Xã/Đặc khu"
  format.ts           # formatAdminAddress(street, ward, province)
  index.ts
packages/supabase/src/locations/
  locations.ts        # getProvinces, getWards, getUnit, searchUnits, getCatalog
  index.ts
apps/web/src/features/shared/locations/
  queries/useLocationQueries.ts      # useProvinces, useWards, useCatalog (TanStack)
  composables/useAdminUnitPicker.ts  # trạng thái chọn tỉnh → xã, reset cấp dưới
  helpers/pickerState.ts             # hàm thuần: pickProvince, pickWard, isComplete (test được)
  components/AdminUnitPicker.vue     # 2 combobox: tỉnh/thành, phường/xã
  components/LegacyAddressNotice.vue # nhãn "địa chỉ theo địa giới cũ" + nút cập nhật
  index.ts
```

Bỏ dần: `GhnLocationPicker.vue`, `useGhnLocationPicker.ts`, `ghnLocations.ts`, `location.service.ts` khi không còn nơi dùng (bước L8). `ProvinceAddress.vue` thay ở `InfomationForm.vue` nếu form đó còn dùng.

### 5.2 `AdminUnitPicker`

- `v-model: LocationValue = { provinceId, provinceName, wardId, wardName, wardCode }`.
- Dùng `components/ui/combobox` (shadcn-vue/reka-ui đã có) để gõ tìm, lọc không dấu phía client (danh sách một tỉnh nhỏ). Không thêm thư viện.
- Đổi tỉnh → xóa xã. Danh sách xã chỉ tải khi đã có tỉnh. Trạng thái: đang tải (skeleton trong combobox), lỗi (dòng báo lỗi + nút thử lại), rỗng ("Không có phường/xã khớp").
- Hiển thị tên đầy đủ ("Phường Bến Thành"), kèm loại đơn vị khi trùng tên.
- Không có ô quận/huyện.
- Props `disabled`, `required`; phát `update:modelValue` chỉ với id lấy từ danh sách server, nên không gửi được mã sai.
- Chuỗi giao diện vào `i18n/locales/vi.json` và `en.json`.

### 5.3 Nơi tích hợp

1. `AddressFormDialog.vue` (sổ địa chỉ khách, web + app): thay `GhnLocationPicker` bằng `AdminUnitPicker`; `address.ts` (core) đổi `AddressForm.location` sang `LocationValue`, `formToInput` gửi `wardUnitId`. Địa chỉ cũ mở ra sửa: hiện `LegacyAddressNotice` với tên cũ và yêu cầu chọn lại phường/xã mới, gợi ý từ `successors` nếu có.
2. `ShippingCard.vue` (kho gửi hàng): như trên, lưu `from_ward_unit_id`.
3. Màn cơ sở (branches) trong admin: thêm `street` + `AdminUnitPicker` (địa điểm shop/spa/phòng khám).
4. Checkout `useShippingQuote`: địa chỉ `admin_v2` gửi `toWardUnitId`; lỗi `location_not_mapped` → phí cố định, nhãn "phí ước tính" như hiện tại.
5. Màn đối chiếu GHN (admin, "Bán online > Cài đặt bán online > Đối chiếu mã GHN"): bảng từ `ghn-diff`, nút "Nối" cho từng dòng cần người xác nhận, nút "Nối tất cả dòng khớp mã chính thức". Dùng `PagedTableCard` + `SearchView`.

---

## 6. GHN adapter (Giai đoạn 6)

- Đặt ở `apps/web/server/providers/ghn/`: `client.ts` (gọi HTTP, timeout 8 s, thử lại tối đa 1 lần với GET khi lỗi mạng/5xx, không thử lại POST), `masterData.ts` (đọc danh mục cũ/mới), `quote.ts` (dựng body từ mapping), `errors.ts`. `server/utils/ghn.ts` hiện có được chuyển vào đây, giữ nguyên hành vi.
- Phân loại lỗi trả cho client: `provider_not_configured` (503, thiếu token/shopId), `provider_unavailable` (502, timeout/mạng), `provider_rejected` (422, GHN trả code khác 200), `location_not_mapped` (409, thiếu mapping). Không log token, không log nguyên body GHN; log chỉ gồm route, mã lỗi, thời gian.
- Không đoán mã GHN. Không gọi GHN từ frontend để dựng danh mục (route `/api/ghn/provinces|districts|wards` giữ lại cho đến khi bỏ `GhnLocationPicker`, rồi xóa ở L8).
- Cần credentials: token GHN đã có trên Vercel (`NUXT_GHN_TOKEN`, `NUXT_GHN_SHOP_ID`). Môi trường cloud của Claude không gọi được GHN, nên kiểm thử thật của L6 chỉ làm được qua bản deploy (preview Vercel) hoặc khi grace mở màn đối chiếu.

---

## 7. Import và cập nhật dữ liệu (Giai đoạn 7)

### 7.1 Cách nạp

- File gốc tải từ cổng Cục Thống kê được lưu trong repo: `supabase/data/admin-units/<catalog-id>/source.xlsx` (hoặc `.csv`) + `README.md` ghi nguồn, ngày tải, sha256.
- Script `scripts/admin-units/build-migration.mjs` (Node, chỉ dùng thư viện đã có trong repo: `read-excel-file` đang dùng cho nhập dữ liệu; nếu nguồn là CSV thì không cần thư viện):
  1. Đọc file, kiểm cột bắt buộc, định dạng mã (2/5 chữ số), không trùng mã, mỗi xã có tỉnh cha tồn tại, tên không rỗng.
  2. Kiểm số lượng hợp lý (34 tỉnh; số xã khớp số ghi trên nguồn, ví dụ 3.321 cho bản 01/07/2025) và **dừng** nếu lệch mà không có tham số xác nhận.
  3. So với danh mục trước trong repo: in báo cáo thêm / đổi tên / đổi loại / ngừng hiệu lực / không đổi / lỗi.
  4. Sinh file migration `supabase/migrations/<timestamp>_admin_units_<catalog-id>.sql` gồm `insert ... on conflict do nothing` cho catalog, upsert theo `(level, official_code) where valid_to is null`, đóng dòng hết hiệu lực bằng `valid_to`, cập nhật `stats`, và `raise notice` báo số dòng.
- Migration chạy tự động khi merge (grace không phải chạy SQL). Chạy lại được: catalog trùng id thì bỏ qua, dòng đã có thì không tạo thêm.
- Không có cron, không đồng bộ nền.

### 7.2 Cập nhật khi có thay đổi chính thức

Ghi trong `docs/dia-gioi-hanh-chinh.md` (viết ở L9): tải lại file từ cổng Cục Thống kê → đặt vào thư mục catalog mới → chạy script → đọc báo cáo → nếu có đổi tên/nhập xã thì thêm file kế thừa kèm số nghị quyết → mở PR → merge. Sau đó mở màn đối chiếu GHN để nối các xã mới.

---

## 8. Kiểm thử (Giai đoạn 8)

| Lớp | Nơi | Nội dung |
| --- | --- | --- |
| pgTAP | `supabase/tests/admin_units.test.sql` | Bảng, chỉ mục, RLS (client không đọc/ghi thẳng bảng); `location_provinces` chỉ trả hiện hành; `location_wards` đúng tỉnh, tìm không dấu ("ben thanh" ra "Bến Thành"), phân trang; id không có → `location_not_found`; dòng `valid_to` đã đóng không xuất hiện; nạp cùng catalog 2 lần không thêm dòng; `save_my_address` với xã hết hiệu lực → `location_inactive`, với nhánh cũ vẫn chạy; CHECK mới của `shop_orders` nhận cả đơn cũ lẫn mới; `save_provider_codes` không có quyền → lỗi quyền; `provider_codes_for` với xã chưa nối trả rỗng. |
| DB contract | `apps/web/tests/db/locations.contract.test.ts` | Kết quả RPC qua zod contract. |
| Unit | `apps/web/tests/unit/` | `normalize`, `format`, `pickerState` (đổi tỉnh xóa xã, chưa chọn xã thì chưa hoàn tất, chỉ nhận id có trong danh sách), `quote.ts` dựng body từ mapping v2/legacy, phân loại lỗi GHN, script build-migration với file mẫu nhỏ (báo cáo thêm/đổi/lỗi, chạy hai lần ra cùng kết quả). |
| Tích hợp | CI | `npm run type-check`, `npm run deps:check`, `npm test`, `npm run build`, `npm run db:start && npm run db:test`, `npm run db:schema` không lệch. |

Dữ liệu dùng trong test là bộ nhỏ tự tạo, đặt trong `supabase/tests/` và `apps/web/tests/`, ghi rõ "chỉ dùng cho test". Không có file mẫu nào nằm trong `supabase/migrations/` hay `supabase/seed.sql`.

UI chỉ kiểm được bằng typecheck/build và test hàm thuần (repo không có `@vue/test-utils`; [GĐ] không thêm dependency). grace bấm thử trên trình duyệt ở cuối ngày.

---

## 9. Các bước code (mỗi bước một PR, squash merge)

Số migration phải mới hơn `20261026010000`; dùng dải `20261027*` theo thứ tự bước, kiểm lại số mới nhất trên `main` trước mỗi PR.

| Bước | Nội dung | Migration | Phụ thuộc |
| --- | --- | --- | --- |
| **L1** | Lấy file danh mục chính thức (mục 7.1), lưu vào `supabase/data/admin-units/`, viết `README.md` nguồn. Nếu môi trường không tải được cổng Cục Thống kê: **dừng bước này** và nhờ grace tải file Excel từ `danhmuchanhchinh.gso.gov.vn` rồi gửi vào project. Các bước L2–L4 làm song song bằng dữ liệu test. | không | grace (có thể) |
| **L2** | Schema: `admin_unit_catalogs`, `admin_units`, `admin_unit_successions`, `admin_unit_provider_codes`, RLS, chỉ mục. pgTAP cấu trúc. | `20261027010000_admin_units_schema.sql` | |
| **L3** | RPC đọc (mục 4.1), contract zod `packages/core/src/locations`, `packages/supabase/src/locations`, mã lỗi, pgTAP + contract test. | `20261027020000_location_rpcs.sql` | L2 |
| **L4** | Script build-migration + test script. | không | L2 |
| **L5** | Chạy script với file L1 → migration nạp danh mục hiện hành. Ghi báo cáo số dòng trong PR. | `20261027030000_admin_units_gso_<ngày>.sql` | L1, L3, L4 |
| **L6** | Đọc tài liệu GHN mục 2.3 (ở bản deploy hoặc nhờ grace dán nội dung nếu vẫn bị chặn), cập nhật mục 2.3 của file này, tách `server/providers/ghn`, RPC `provider_codes_for` + `save_provider_codes`, route `ghn-diff`, phí theo `wardUnitId`. | `20261027040000_provider_codes_rpcs.sql` | L3 |
| **L7** | Nâng cấp `customer_addresses`, `shop_orders` (CHECK mới), `shop_settings`, `branches`; `save_my_address`, `create_shop_order`, `save_shop_settings`, RPC cơ sở, `address_json` (chép từ `schema.sql`, chỉ sửa phần cần). | `20261027050000_addresses_admin_units.sql` | L3 |
| **L8** | Frontend: `AdminUnitPicker`, tích hợp 5 nơi ở mục 5.3, màn đối chiếu GHN, bỏ component/route cũ không còn dùng. | không | L5, L6, L7 |
| **L9** | `docs/dia-gioi-hanh-chinh.md`: hướng dẫn cập nhật danh mục, nối GHN, giới hạn còn lại; cập nhật `docs/checkout-shop.md`. | không | L8 |
| L10 (tùy chọn) | Danh mục cũ 63 tỉnh + bảng kế thừa từ nghị quyết, gợi ý cập nhật cho địa chỉ cũ. Chỉ làm khi có file nguồn đối chiếu được. | `2026102706*` | L5 |

Việc grace cần làm sau khi code xong: mở "Đối chiếu mã GHN" và nối các xã (nếu GHN không trả mã chính thức thì phải xác nhận tay, nhiều xã); bấm thử form địa chỉ trên web và app.

---

## 10. Rủi ro và giới hạn còn lại

| Rủi ro | Cách xử lý |
| --- | --- |
| GHN chưa nhận mã 2 cấp khi tính phí, hoặc không trả mã chính thức | Mapping lưu được `ghn_legacy` (district + ward cũ) cho từng xã mới; nối tay qua màn đối chiếu; thiếu mapping thì phí cố định. Không chặn khách đặt hàng. |
| Danh mục đổi trong năm 2026 (xã lên phường, nhập xã) | Phiên bản + hiệu lực; mỗi lần cập nhật là một migration mới; địa chỉ cũ giữ id cũ. |
| Không tải được file nguồn từ môi trường cloud | L1 nhờ grace tải; các bước khác không phụ thuộc. |
| Địa chỉ cũ 3 cấp không chuyển tự động | Chủ ý. Khách/nhân viên chọn lại khi sửa; đơn cũ giữ snapshot. |
| Supabase FREE | Khoảng 3.400 dòng danh mục và vài nghìn dòng mapping, không đáng kể. |
| Tọa độ, vùng giao hàng, báo cáo theo địa bàn | Chưa làm. Schema cho phép thêm sau; báo cáo theo địa bàn làm được khi đơn mới có `ship_ward_unit_id`. |
