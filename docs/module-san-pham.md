# Module sản phẩm: phần còn lại

Kế hoạch ngày 13/10/2026 cho phần còn lại của module sản phẩm (M6 trong kế hoạch BA/kiến trúc v0.3): danh mục và thương hiệu, ảnh dùng chung với shop, giá theo cơ sở, quy đổi đơn vị, nhập/xuất Excel. Đi sau biến thể sản phẩm (PR #46, [bien-the-san-pham.md](bien-the-san-pham.md)), kho theo lô (PR #44), POS (PR #43, #54), lịch spa (PR #55, #56) và báo cáo (PR #60 đến #63), đều đã merge.

**Tiến độ:** kế hoạch tự duyệt; các câu hỏi mở đã chọn mặc định ở mục 10. Bước 1 (danh mục và thương hiệu) đã merge (#65); bước 2 (thư viện ảnh) đã merge (#67); bước 3 (giá theo cơ sở) đã merge (#68); bước 4 (đơn vị quy đổi) đã code; bước 5 chưa làm. Khác plan ở bước 2: policy kho ảnh `catalog/` cho phép CREATE hoặc UPDATE sản phẩm; client tự tính các file ảnh bị gỡ để xoá (thay cho `removed_paths`); mỗi ảnh có thêm `storage_path`. Khác plan ở bước 3: tab Giá theo cơ sở chỉ cho sửa ô của cơ sở mà nhân viên có quyền Sửa sản phẩm (admin sửa mọi cơ sở), biến thể mới phải lưu trước rồi mới đặt giá riêng; `create_invoice` được sao chép nguyên văn và chỉ đổi dòng tính giá sản phẩm. Khác plan ở bước 4: 9 file migration `20261015040000` đến `040800` (tách `save_product_units` ra hàm nội bộ gọi từ `save_product_group`; `create_invoice`, `create_sales_return`, `save_stock_document` mỗi hàm một file); dòng phiếu nhập nhận `unit_id`, `qty`, `unit_cost` theo đơn vị đã chọn và lưu quy ra đơn vị gốc; `report_sales_lines` và `report_top_items` dùng số lượng đơn vị gốc; chưa làm phần Should: lọc danh mục ở tồn kho và quét mã vạch của đơn vị ở phiếu nhập.

Dự án là pet project cá nhân, nên ưu tiên đơn giản và rẻ: thêm bảng nhỏ, logic giá và tồn nằm trong Postgres RPC, không thêm dịch vụ ngoài, chỉ thêm một thư viện đọc/ghi Excel nhỏ và tải lười (lazy).

## 1. Trước và sau

**Trước:** sản phẩm chỉ có nhóm + biến thể (SKU, mã vạch, một đơn vị, một giá, một ảnh nhóm và một ảnh biến thể). Không phân loại được theo danh mục hay thương hiệu, nên POS, kho, báo cáo và shop không lọc được. Ảnh nằm trong thư mục riêng của người tải lên, người khác không xoá được. Mỗi biến thể chỉ bán một đơn vị (không bán lẻ viên từ hộp). Giá giống nhau ở mọi cơ sở. Muốn nhập 200 mặt hàng phải gõ tay từng cái.

**Sau:**

1. Menu "Sản phẩm" có thêm hai trang **Danh mục** (cây 2 cấp) và **Thương hiệu**. Form sản phẩm chọn danh mục và thương hiệu; danh sách sản phẩm, POS, màn tồn kho và tab báo cáo "Sản phẩm & dịch vụ" lọc được theo hai trường này.
2. Mỗi sản phẩm có **bộ ảnh** (tối đa 8 ảnh, kéo để sắp xếp, ảnh đầu là ảnh bìa). Biến thể chọn ảnh từ bộ ảnh của nhóm. Shop đọc đúng bộ ảnh này. Ảnh nằm ở thư mục chung `catalog/`, ai có quyền sửa sản phẩm cũng thay/xoá được. Ảnh được nén sang WebP trước khi tải lên.
3. Mỗi biến thể có thể đặt **giá riêng cho từng cơ sở**. Không đặt thì dùng giá chung. POS, hóa đơn và lịch sử giá dùng đúng giá của cơ sở đang bán. Shop online dùng giá chung.
4. Mỗi biến thể có **đơn vị quy đổi**: đơn vị gốc (viên) + các đơn vị lớn (vỉ = 10 viên, hộp = 100 viên), mỗi đơn vị có mã vạch và giá riêng (tuỳ chọn). Tồn kho luôn tính theo đơn vị gốc. POS quét mã vạch hộp thì ra dòng "1 hộp"; phiếu nhập nhập theo thùng.
5. Trang **Nhập/xuất Excel**: tải file mẫu, tải lên `.xlsx`, xem trước từng dòng (hợp lệ / lỗi / sẽ tạo / sẽ cập nhật), xác nhận thì ghi. Xuất toàn bộ danh mục ra cùng mẫu đó để sửa hàng loạt rồi nhập lại.

## 2. Phạm vi

| Mức | Nội dung |
| --- | --- |
| **Must** | Danh mục 2 cấp + thương hiệu, gắn vào nhóm sản phẩm, lọc ở danh sách sản phẩm và POS; bộ ảnh nhóm dùng chung admin/shop, thư mục ảnh chung; giá theo cơ sở cho biến thể, POS và `create_invoice` dùng giá đó; đơn vị quy đổi (bán ở POS, nhập kho, trả hàng, trừ tồn đúng); nhập Excel tạo/cập nhật theo SKU có xem trước; xuất Excel cùng mẫu |
| **Should** | Lọc theo danh mục ở màn tồn kho và tab báo cáo; nén ảnh WebP trước khi tải; danh mục có ảnh để shop hiện ở trang chủ (thay ảnh mẫu `Categories.vue`); lịch sử các lần nhập (ai, lúc nào, bao nhiêu dòng) |
| **Could** | Dọn ảnh mồ côi trong storage; nhập Excel kèm tồn đầu kỳ (tạo phiếu nhập nháp); giá riêng theo cơ sở cho đơn vị lớn; trang danh sách sản phẩm của shop lọc theo danh mục |
| **Won't (lần này)** | Bảng giá theo nhóm khách / khuyến mãi; giá theo thời gian (lịch đổi giá); quy đổi giữa biến thể khác nhau; chuyển kho giữa cơ sở; nhập `.xls`/`.csv`; giỏ hàng và thanh toán shop (để luồng "shop checkout" riêng) |

## 3. Quy tắc nghiệp vụ

### 3.1 Danh mục và thương hiệu

- Danh mục và thương hiệu **dùng chung mọi cơ sở** (cùng nhóm "danh mục sản phẩm" trong quy tắc dữ liệu 2.5 của kế hoạch BA).
- Danh mục tối đa **2 cấp** (ví dụ "Thức ăn" › "Hạt cho chó"). Một nhóm sản phẩm thuộc **một** danh mục (cấp nào cũng được) và **một** thương hiệu, cả hai có thể để trống.
- Lọc theo danh mục cha thì gồm cả danh mục con.
- Tên danh mục không trùng trong cùng cha (bỏ dấu, không phân biệt hoa thường); tên thương hiệu không trùng toàn hệ thống. `slug` sinh tự động từ tên (bỏ dấu, gạch nối), dùng cho URL shop sau này.
- Xoá: chỉ khi không còn sản phẩm và (với danh mục) không còn danh mục con. Còn dùng thì chỉ được **ngừng dùng** (`is_active = false`): không chọn được cho sản phẩm mới, sản phẩm cũ giữ nguyên, shop ẩn danh mục đó.
- Sắp xếp danh mục bằng `sort_order` (nút lên/xuống), không kéo thả cây.

### 3.2 Ảnh

- Bộ ảnh thuộc **nhóm sản phẩm**, tối đa 8 ảnh. Ảnh đầu tiên (`sort_order` nhỏ nhất) là ảnh bìa và được ghi lại vào `product_groups.image_url` để mọi chỗ đang đọc cột này (POS, shop, danh sách) chạy như cũ.
- Biến thể **chọn** một ảnh trong bộ ảnh của nhóm (lưu `products.image_url` như hiện tại). Không chọn thì dùng ảnh bìa.
- Tải lên vào `images/catalog/<group_id>/<uuid>.webp`. Thư mục `catalog/` có policy riêng: ai có `products: UPDATE` (hoặc admin) được thêm và xoá. Ảnh cũ ở `<uid>/products/` giữ nguyên, không di chuyển (URL vẫn chạy).
- Client nén ảnh trước khi tải: cạnh dài tối đa 1600px, WebP chất lượng 0.85, bằng `canvas` (không thêm thư viện). GIF giữ nguyên. Giới hạn 5MB của bucket giữ nguyên.
- Xoá ảnh khỏi bộ ảnh: RPC xoá dòng, client xoá file storage sau khi RPC thành công. Nếu xoá file thất bại thì chỉ để lại file mồ côi (vô hại), không báo lỗi cho người dùng.
- Danh mục và thương hiệu mỗi cái có 1 ảnh (`image_url`), tải vào `catalog/categories/`, `catalog/brands/`.

### 3.3 Giá theo cơ sở

- `products.price` là **giá chung**. Bảng mới `product_branch_prices (product_id, branch_id, price)` là giá riêng; không có dòng = dùng giá chung. Cùng mẫu với `pet_service_prices.branch_id` của dịch vụ spa.
- Hàm duy nhất tính giá: `public.product_unit_price(p_product uuid, p_branch uuid, p_unit uuid default null)` (mục 3.4). Mọi chỗ cần giá (POS, `create_invoice`, danh sách) gọi hàm này, không tự tính.
- Shop online (chưa có cơ sở) gọi với `p_branch = null`, tức giá chung.
- Sửa giá riêng cần `products: UPDATE` **ở đúng cơ sở đó** (`has_permission('products', 'UPDATE', branch)`) hoặc admin. Sửa giá chung giữ như cũ.
- Hóa đơn đã chụp giá lúc bán (`invoice_lines.unit_price`) nên đổi giá không ảnh hưởng hóa đơn cũ.
- MVP có 1 cơ sở: UI giá riêng nằm trong form sản phẩm, ẩn khi hệ thống chỉ có 1 cơ sở hoạt động (giống bộ chọn cơ sở ở header).

### 3.4 Đơn vị quy đổi

- Mỗi biến thể có **đơn vị gốc** = `products.unit` (đơn vị nhỏ nhất, tồn kho tính theo đơn vị này) và 0..n **đơn vị quy đổi** trong bảng `product_units`: tên, hệ số (`factor` > 1, số nguyên hoặc thập phân 2 chữ số), mã vạch riêng, giá riêng tuỳ chọn, cờ "bán" và "nhập".
- Giá một đơn vị quy đổi: có giá riêng thì dùng (giá chung, mọi cơ sở); không có thì = giá gốc tại cơ sở × hệ số. Giá riêng theo cơ sở cho đơn vị lớn là Could.
- Mã vạch là duy nhất trên **cả** `products.barcode` và `product_units.barcode`. Kiểm tra trong RPC lưu (bảng khác nhau nên không dùng được một unique index), cộng unique index trên từng bảng.
- **Bán (POS):** dòng hóa đơn lưu đơn vị và số lượng theo đơn vị bán ("2 hộp"), cộng `unit_factor`. Trừ kho theo `qty × unit_factor` (đơn vị gốc). Bán được số lẻ đơn vị gốc nếu đơn vị gốc cho phép (giữ như hiện tại: `qty numeric(10,2)`).
- **Trả hàng:** trả theo đơn vị đã bán trên dòng (trả 1 trong 2 hộp), hoàn kho `qty × unit_factor`. Không trả đổi đơn vị (không trả 5 viên từ dòng "1 hộp") trong lần này.
- **Nhập kho:** dòng phiếu nhập chọn đơn vị (mặc định đơn vị có cờ "nhập", không có thì đơn vị gốc), nhập số lượng và giá vốn theo đơn vị đó. Khi lưu phiếu, quy về đơn vị gốc: `qty = số lượng × hệ số`, `unit_cost = giá vốn / hệ số` (làm tròn 2 số lẻ, tổng tiền dòng tính từ số nhập gốc để không lệch). Xuất huỷ và kiểm kê luôn theo đơn vị gốc.
- **Báo cáo:** số lượng bán/trả quy về đơn vị gốc (`base_qty`) và hiện kèm đơn vị gốc, để "2 hộp" và "5 viên" cộng được với nhau.
- Đơn vị đã dùng trên hóa đơn hoặc phiếu kho thì không xoá, không đổi hệ số; chỉ ngừng dùng. Hóa đơn cũ có `unit_factor = 1`.

### 3.5 Nhập/xuất Excel

- Chỉ `.xlsx`, một sheet "San pham" (bắt buộc) và một sheet "Don vi" (tuỳ chọn). Mẫu có dòng tiêu đề tiếng Việt, cố định thứ tự cột.
- **Khoá nhận dạng là SKU** của biến thể. SKU có rồi → cập nhật; chưa có → tạo. Dòng không có SKU → lỗi (bắt buộc SKU khi nhập file).
- Các dòng cùng "Tên nhóm" gom thành một nhóm; cột "Thuộc tính 1/Giá trị 1 … Thuộc tính 3/Giá trị 3" tạo biến thể (file chỉ hỗ trợ tối đa 3 thuộc tính, form vẫn không giới hạn).
- Danh mục ghi dạng "Cha > Con", thương hiệu ghi tên. Chưa có thì **tạo mới** (có cờ trong bước xem trước để người dùng thấy).
- Ảnh: cột "Ảnh" nhận URL `https://`, nhiều URL ngăn bằng dấu `|`. Không tải file ảnh qua Excel; URL ngoài được lưu nguyên.
- Không có cột tồn kho: tồn chỉ thay đổi qua phiếu kho (quy tắc đã chốt). Nhập tồn đầu kỳ bằng file là Could (tạo phiếu nhập nháp).
- Quy trình: đọc file ở trình duyệt → kiểm tra cơ bản ở client → gửi lô tối đa 200 dòng cho RPC chạy **thử** (`p_dry_run = true`, không ghi gì, trả kết quả từng dòng) → màn xem trước → bấm "Nhập" thì gửi lại cùng dữ liệu với `p_dry_run = false`, mỗi lô một giao dịch. Lỗi ở dòng nào thì cả lô đó không ghi; UI báo lô nào hỏng để sửa file rồi nhập lại (chạy lại an toàn vì theo SKU).
- Tối đa 2.000 dòng mỗi file.
- Xuất: gọi RPC đọc theo trang (500 dòng/lần), ghi ra đúng mẫu nhập. Xuất rồi nhập lại không đổi gì là một kịch bản test.

## 4. Quyền

Không thêm mã quyền mới; dùng `products` sẵn có (`can_products`).

| Việc | Cần |
| --- | --- |
| Xem danh mục, thương hiệu, ảnh, đơn vị | Công khai (shop đọc), như các bảng catalog hiện tại |
| Thêm/sửa danh mục, thương hiệu | `products: CREATE` / `UPDATE` |
| Xoá danh mục, thương hiệu | `products: DELETE` |
| Bộ ảnh, đơn vị quy đổi, giá chung | `products: UPDATE` (nằm trong `save_product_group`) |
| Giá riêng theo cơ sở | `products: UPDATE` tại cơ sở đó, hoặc admin |
| Nhập Excel | `products: CREATE` và `UPDATE` (kiểm tra trong RPC) |
| Xuất Excel | `products: VIEW` |

`ADMIN_ROUTE_PERMISSIONS` thêm `productCategories`, `productBrands`, `productImport` → `products`.

## 5. Database

Quy ước như các module trước: migration forward-only, chạy lại được (`if not exists`, `create or replace`, `drop policy if exists`), không sửa file cũ; hàm `security definer`, `set search_path = ''`, `revoke ... from public, anon`, `grant ... to authenticated` (hàm đọc catalog cấp cả `anon`); mỗi file dưới khoảng 300 dòng. Workflow "Supabase migrate" tự chạy khi merge vào main.

Khi `create or replace` một hàm đã có (`create_invoice`, `create_sales_return`, `save_stock_document`, `save_product_group`, `product_group_json`, các hàm báo cáo), **chép bản mới nhất** rồi sửa, không chép bản cũ:

| Hàm | Bản mới nhất |
| --- | --- |
| `create_invoice`, `cancel_invoice` | `20261013050100_pos_invoice_appointments.sql` |
| `create_sales_return` | `20261009120000_pos_p1_fixes.sql` |
| `save_stock_document`, `post_stock_document`, `stock_summary`, `stock_rows` | `20261007130000_inventory_lots.sql` (kiểm tra lại bằng `grep` trước khi sửa) |
| `save_product_group`, `product_group_json`, `list_product_groups` | `20261007140000_product_variants.sql` |
| `report_sales_lines`, `report_top_items` | `20261014010100_reports_sales_lines.sql`, `20261014010300_reports_rankings.sql` |

### 5.1 Bảng mới và cột mới

```sql
-- Bước 1
create table if not exists public.product_categories (
  id         uuid primary key default gen_random_uuid(),
  parent_id  uuid references public.product_categories(id) on delete restrict,
  name       text not null check (length(btrim(name)) > 0),
  slug       text not null,
  image_url  text,
  sort_order int not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
-- tên duy nhất trong cùng cha; slug duy nhất toàn bảng
create unique index if not exists product_categories_name_key
  on public.product_categories (coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(public.immutable_unaccent(btrim(name))));
create unique index if not exists product_categories_slug_key on public.product_categories (slug);
-- trigger: cha phải là danh mục gốc (tối đa 2 cấp), không tự trỏ chính mình

create table if not exists public.product_brands (
  id, name, slug, image_url, is_active, created_at, updated_at   -- cùng kiểu như trên
);

alter table public.product_groups
  add column if not exists category_id uuid references public.product_categories(id) on delete restrict,
  add column if not exists brand_id    uuid references public.product_brands(id) on delete restrict;
create index if not exists product_groups_category_idx on public.product_groups (category_id) where category_id is not null;
create index if not exists product_groups_brand_idx    on public.product_groups (brand_id) where brand_id is not null;

-- Bước 2
create table if not exists public.product_images (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.product_groups(id) on delete cascade,
  url          text not null,
  storage_path text,            -- null với URL ngoài (nhập từ Excel)
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);
create index if not exists product_images_group_idx on public.product_images (group_id, sort_order);
-- dữ liệu cũ: mỗi product_groups.image_url khác rỗng → 1 dòng product_images (bỏ qua nếu đã có)

-- Bước 3
create table if not exists public.product_branch_prices (
  product_id uuid not null references public.products(id) on delete cascade,
  branch_id  uuid not null references public.branches(id) on delete cascade,
  price      numeric(14,2) not null check (price >= 0),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (product_id, branch_id)
);

-- Bước 4
create table if not exists public.product_units (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  name       text not null check (length(btrim(name)) > 0),
  factor     numeric(12,2) not null check (factor > 1),
  barcode    text,
  price      numeric(14,2) check (price >= 0),   -- null = giá gốc × hệ số
  for_sale     boolean not null default true,
  for_purchase boolean not null default false,
  is_active  boolean not null default true,
  sort_order int not null default 0,
  unique (product_id, name)
);
create unique index if not exists product_units_barcode_key on public.product_units (barcode) where barcode is not null;

alter table public.invoice_lines
  add column if not exists unit_id     uuid references public.product_units(id) on delete restrict,
  add column if not exists unit_factor numeric(12,2) not null default 1 check (unit_factor > 0);
alter table public.invoice_lines
  add column if not exists base_qty numeric(14,2) generated always as (qty * unit_factor) stored;

alter table public.stock_document_lines
  add column if not exists unit_id     uuid references public.product_units(id) on delete restrict,
  add column if not exists unit_name   text,
  add column if not exists unit_factor numeric(12,2) not null default 1 check (unit_factor > 0),
  add column if not exists entered_qty  numeric(12,2),   -- số người dùng nhập theo đơn vị đã chọn
  add column if not exists entered_cost numeric(14,2);

-- Bước 5 (Should)
create table if not exists public.product_imports (
  id uuid primary key default gen_random_uuid(),
  file_name text, row_count int, created_count int, updated_count int,
  created_by uuid references auth.users(id) on delete set null, created_at timestamptz not null default now()
);
```

RLS: các bảng catalog mới đọc công khai (`"public read"` cho `anon, authenticated`), không cấp `insert/update/delete`; ghi chỉ qua RPC. `product_branch_prices` cũng đọc công khai (giá không bí mật). `product_imports` chỉ người có `products: VIEW` đọc.

Storage (bước 2): policy mới trên `storage.objects` cho `bucket_id = 'images' and (storage.foldername(name))[1] = 'catalog'`: `insert`/`delete`/`select` khi `public.can_products('UPDATE')`. Policy cũ theo thư mục `<uid>` giữ nguyên.

### 5.2 RPC

| Bước | Hàm | Ghi chú |
| --- | --- | --- |
| 1 | `save_product_category(p jsonb) returns uuid` | `{ id?, parent_id?, name, image_url?, sort_order?, is_active? }`; sinh slug, chặn cấp 3, chặn tự trỏ |
| 1 | `delete_product_category(p_id uuid)` | Lỗi `23503` hint `in_use` / `has_children` nếu còn dùng |
| 1 | `list_product_categories(p_search, p_include_inactive, p_limit, p_offset) returns jsonb` | `{ total, rows: [{ id, parent_id, parent_name, name, slug, image_url, sort_order, is_active, product_count }] }`, sắp theo cha rồi `sort_order`; dùng cho bảng và InfiniteSelect |
| 1 | `save_product_brand`, `delete_product_brand`, `list_product_brands` | Cùng mẫu |
| 1 | `list_product_groups(p_search, p_include_archived, p_category, p_brand, p_limit, p_offset)` | `drop function if exists list_product_groups(text, boolean, int, int)` rồi tạo bản có tham số mới (mặc định null). `p_category` gồm cả con |
| 1 | `save_product_group`, `product_group_json` | Thêm `category_id`, `brand_id` (và `category_name`, `brand_name` trong JSON) |
| 2 | `save_product_group` | Thêm `images: [{ id?, url, storage_path? }]` theo thứ tự; xoá ảnh không còn trong danh sách; ghi ảnh đầu vào `product_groups.image_url`; biến thể chỉ được trỏ tới URL nằm trong bộ ảnh. Trả về thêm `removed_paths` để client xoá file |
| 2 | `product_group_json` | Thêm `images: [{ id, url }]` |
| 3 | `product_unit_price(p_product, p_branch, p_unit default null) returns numeric` | `stable`, cấp `anon`. Thứ tự: giá riêng của đơn vị → (giá cơ sở hoặc giá chung) × hệ số |
| 3 | `set_product_branch_prices(p_product uuid, p_prices jsonb)` | `[{ branch_id, price \| null }]`; null = xoá giá riêng; kiểm quyền từng cơ sở |
| 3 | `branch_prices(p_branch uuid, p_products uuid[]) returns table(product_id uuid, price numeric)` | Cho POS phủ giá lên danh sách, cùng mẫu `sellable_stock` |
| 3 | `create_invoice` | Dòng product lấy `v_price := product_unit_price(v_item, v_branch, null)` thay cho `v_product.price` |
| 4 | `save_product_group` | Mỗi biến thể thêm `units: [{ id?, name, factor, barcode, price, for_sale, for_purchase, is_active }]`; kiểm tra trùng mã vạch chéo hai bảng; đơn vị đã dùng thì không đổi hệ số, không xoá (chỉ tắt) |
| 4 | `find_by_barcode(p_code text, p_branch uuid) returns jsonb` | `{ product_id, unit_id \| null, name, unit, factor, price }` cho POS quét mã |
| 4 | `create_invoice` | Dòng product nhận thêm `unit_id`; kiểm tra đơn vị thuộc sản phẩm, đang bán; tên đơn vị vào `unit`, hệ số vào `unit_factor`, giá theo `product_unit_price(..., unit_id)` |
| 4 | `invoice_line_take_stock` | `take_stock_fefo(..., new.base_qty, ...)` thay vì `new.qty` |
| 4 | `create_sales_return` | Hoàn kho `v_qty * v_inv_line.unit_factor`; số còn trả được vẫn tính theo đơn vị bán |
| 4 | `save_stock_document` | Dòng nhận `unit_id`, `entered_qty`, `entered_cost`; quy ra `qty`, `unit_cost` theo đơn vị gốc; `post_stock_document` không đổi |
| 4 | `report_sales_lines`, `report_top_items` | Dùng `base_qty`, cột `unit` = đơn vị gốc hiện tại |
| 4 | `stock_summary` | Thêm `p_category` (Should) |
| 5 | `import_products(p_rows jsonb, p_dry_run boolean) returns jsonb` | Mục 5.3 |
| 5 | `export_products(p_limit int, p_offset int) returns jsonb` | Mỗi biến thể một dòng, cùng cột với mẫu; kèm danh sách đơn vị |

Sau mỗi file có đổi chữ ký hàm: `notify pgrst, 'reload schema';`. Sau mỗi bước có bảng hoặc hàm mới, cập nhật `src/types/database.types.ts` bằng tay theo cách các PR trước đã làm (repo chưa có script sinh type).

### 5.3 `import_products`

Đầu vào mỗi dòng (client đã đổi tên cột tiếng Việt sang khoá):

```jsonc
{ "row": 12, "group": "Hạt Royal Canin Mini Adult", "category": "Thức ăn > Hạt cho chó", "brand": "Royal Canin",
  "description": "", "images": ["https://..."],
  "attrs": [{ "name": "Khối lượng", "value": "2kg" }],
  "sku": "RC-MINI-2", "barcode": "893...", "unit": "túi", "price": 420000,
  "track_stock": true, "is_active": true,
  "units": [{ "name": "thùng", "factor": 6, "barcode": null, "price": null, "for_purchase": true }] }
```

Kết quả:

```jsonc
{ "ok": true, "created_groups": 3, "updated_groups": 1, "created_variants": 9, "updated_variants": 2,
  "new_categories": ["Thức ăn > Hạt cho chó"], "new_brands": ["Royal Canin"],
  "rows": [{ "row": 12, "action": "create" | "update" | "skip", "errors": ["Mã vạch trùng với SKU RC-MAXI-4"] }] }
```

- Gom dòng theo tên nhóm, dựng đúng JSON mà `save_product_group` nhận, rồi gọi các hàm con dùng chung với `save_product_group` (tách phần thân thành helper nội bộ `apply_product_group(p jsonb)` để hai đường dùng chung một logic).
- Nhóm có trong file nhưng thiếu biến thể đang có trong DB: **giữ nguyên** biến thể đó (nhập không bao giờ xoá). Đây là khác biệt duy nhất so với lưu từ form.
- `p_dry_run = true`: chạy toàn bộ trong `begin ... exception` và luôn `raise` ở cuối để huỷ, bắt lại và trả kết quả. Đơn giản hơn viết hai đường kiểm tra.
- Lỗi theo dòng dùng tiếng Việt ngắn; mã lỗi tổng `22023` hint `import_invalid` khi `p_dry_run = false` mà còn dòng lỗi.

### 5.4 Chia file migration

| File | Nội dung |
| --- | --- |
| `20261015010000_product_categories_brands.sql` | Bảng, index, trigger 2 cấp, RLS, save/delete/list danh mục và thương hiệu |
| `20261015010100_product_groups_category_brand.sql` | Cột nhóm, `save_product_group`, `product_group_json`, `list_product_groups` mới |
| `20261015020000_product_images.sql` | Bảng ảnh, chuyển ảnh cũ, policy storage `catalog/`, `save_product_group` + `product_group_json` có ảnh |
| `20261015030000_product_branch_prices.sql` | Bảng giá cơ sở, `product_unit_price` (chưa có đơn vị: tham số `p_unit` bỏ qua), `set_product_branch_prices`, `branch_prices` |
| `20261015030100_invoice_branch_price.sql` | `create_invoice` dùng `product_unit_price` |
| `20261015040000_product_units.sql` | Bảng đơn vị, cột `invoice_lines`, `stock_document_lines`, `product_unit_price` đủ, `find_by_barcode`, `save_product_group` có đơn vị |
| `20261015040100_units_sell_return.sql` | `create_invoice`, `invoice_line_take_stock`, `create_sales_return` |
| `20261015040200_units_stock_reports.sql` | `save_stock_document`, `report_sales_lines`, `report_top_items`, `stock_summary` có `p_category` |
| `20261015050000_product_import.sql` | `apply_product_group` (tách từ `save_product_group`), `import_products`, `export_products`, `product_imports` |

Nếu một file vượt 300 dòng (thường do `create_invoice` dài), tách hàm đó ra file riêng cùng bước, số phút tăng dần.

## 6. Màn hình

Chung cho mọi màn: bảng dùng `PagedTableCard` (lấp đầy chiều cao, cuộn trong bảng, header xám đậm, phân trang ở footer, nhớ page size), danh sách có tìm kiếm + `page` + `page_size` qua RPC, ô tìm debounce 500ms (`usePagedSearch`), dialog dùng `AppDialog` (X góc phải, Esc đóng, Enter lưu), select có tìm kiếm dùng `InfiniteSelect` + `useInfiniteOptions`, toast ở giữa trên, theme admin teal.

### 6.1 Menu

Mục "Sản phẩm" trong `src/lib/navigations.ts` thành nhóm có 4 trang con: Sản phẩm (`adminProducts`, giữ route cũ), Danh mục (`productCategories`, `/admin/products/categories`), Thương hiệu (`productBrands`, `/admin/products/brands`), Nhập/xuất Excel (`productImport`, `/admin/products/import`). Thanh tab nhỏ `ProductsNav.vue` ở đầu mỗi trang giống `ReportsNav.vue`.

### 6.2 Danh mục (bước 1)

- Bảng: Tên (con thụt lề, có "›" và tên cha), Ảnh, Số sản phẩm, Thứ tự (nút lên/xuống), Trạng thái, thao tác (Sửa, Ngừng dùng/Dùng lại, Xoá khi `product_count = 0` và không có con).
- Tìm theo tên; công tắc "Hiện cả đã ngừng".
- Dialog thêm/sửa: Tên, Danh mục cha (`InfiniteSelect`, chỉ danh mục gốc, có "Không có"), Ảnh (1 ảnh, `UploadFields` thư mục `catalog/categories`).

### 6.3 Thương hiệu (bước 1)

Như danh mục nhưng phẳng: Tên, Logo, Số sản phẩm, Trạng thái.

### 6.4 Sản phẩm (bước 1 đến 4)

- **Danh sách** (bước 1): thanh lọc thêm Danh mục và Thương hiệu (`InfiniteSelect`), giữ trên URL query; cột mới "Danh mục" (dạng "Cha › Con") và "Thương hiệu".
- **Form** `ProductGroupSheet` hiện đã 147 dòng, thêm nữa sẽ quá dài, nên chuyển sang **tab** trong sheet:
  1. *Thông tin*: tên, mô tả, danh mục, thương hiệu (bước 1).
  2. *Ảnh*: lưới ảnh, tải nhiều ảnh, kéo để sắp xếp (HTML5 drag, không thư viện), xoá, nhãn "Ảnh bìa" ở ảnh đầu (bước 2).
  3. *Biến thể*: thuộc tính + bảng biến thể như hiện tại; cột ảnh biến thể mở popover chọn từ bộ ảnh (bước 2).
  4. *Đơn vị*: chọn biến thể (hoặc "áp cho mọi biến thể" khi tạo mới), bảng đơn vị: Tên, Hệ số "= N <đơn vị gốc>", Mã vạch, Giá (để trống = tự tính, hiện giá tự tính làm placeholder), Bán, Nhập, Đang dùng (bước 4).
  5. *Giá theo cơ sở*: ẩn khi chỉ có 1 cơ sở hoạt động. Lưới biến thể × cơ sở, ô trống = giá chung (placeholder), có "Xoá giá riêng" (bước 3). Lưu bằng `set_product_branch_prices` riêng, không đi qua `save_product_group`, vì quyền theo cơ sở.
- Lỗi lưu hiện ở đúng tab (chấm đỏ trên tên tab có lỗi).

### 6.5 POS (bước 1, 3, 4)

- Thanh danh mục dạng chip trên lưới sản phẩm ("Tất cả", các danh mục gốc có sản phẩm); chọn chip thì lọc (bước 1).
- Giá trên thẻ và trong giỏ là giá tại cơ sở đang mở ca (`branch_prices`), có dấu nhỏ khi khác giá chung (bước 3).
- Quét mã vạch gọi `find_by_barcode`: ra đúng đơn vị. Bấm thẻ sản phẩm có đơn vị quy đổi thì popup chọn đơn vị (gộp vào popup chọn biến thể nếu có cả hai). Dòng giỏ có ô chọn đơn vị để đổi nhanh; giá đổi theo. Kiểm tồn theo đơn vị gốc: "Còn 35 viên (3 hộp)" (bước 4).
- `create_invoice` vẫn tự tính giá; client chỉ hiển thị.

### 6.6 Kho (bước 4)

- Phiếu nhập: cột "Đơn vị" (select các đơn vị có cờ nhập + đơn vị gốc), số lượng và giá vốn theo đơn vị đó, hiện dòng phụ "= 60 viên, 1.500đ/viên".
- Màn tồn kho: lọc theo danh mục (Should); tồn hiện theo đơn vị gốc, tooltip quy đổi sang đơn vị lớn nhất.

### 6.7 Nhập/xuất Excel (bước 5)

- Ba khối theo thứ tự: (1) "Tải file mẫu" và "Xuất toàn bộ sản phẩm"; (2) ô kéo-thả file `.xlsx`; (3) bảng xem trước.
- Bảng xem trước dùng `PagedTableCard`, phân trang ở client: Dòng, Nhóm, SKU, Biến thể, Giá, Hành động (Tạo/Cập nhật/Bỏ qua), Lỗi. Bộ lọc nhanh "Chỉ dòng lỗi". Tổng ở đầu: "120 dòng: 100 tạo, 15 cập nhật, 5 lỗi; sẽ tạo 2 danh mục, 1 thương hiệu".
- Nút "Nhập" chỉ bật khi không còn dòng lỗi. Thanh tiến độ theo lô. Xong thì toast và link về danh sách sản phẩm.
- Khối (Should) "Lịch sử nhập" 10 lần gần nhất.

### 6.8 Shop (bước 2)

- `ShopGroupCard` quick view: ảnh lớn + dải ảnh nhỏ từ `group.images`; chọn biến thể có ảnh thì nhảy tới ảnh đó.
- `Categories.vue` trang chủ đọc danh mục gốc đang dùng có ảnh từ `list_product_categories` (Should); khi chưa có danh mục nào thì giữ ảnh mẫu như hiện tại.
- Shop vẫn bán theo đơn vị gốc, giá chung. Giỏ hàng/checkout không đổi (luồng riêng).

## 7. Cấu trúc file frontend

Theo quy tắc tách file: trang là vỏ mỏng, logic trong composable `useXxx`, hàm thuần trong `*.ts`, type riêng, mỗi file dưới khoảng 300 dòng. Số dòng dưới đây là ước lượng trần.

```
src/repositories/
  products.ts                 (289 dòng, đã sát giới hạn) → tách:
  products/types.ts           Product, ProductGroup, ProductUnit, ProductImage, BranchPrice
  products/mappers.ts         toProduct, toProductGroup (từ JSON RPC)
  products/groups.ts          list/get/save/setActive nhóm
  products/sellable.ts        listSellableProducts, searchSellableProducts, findByBarcode, branchPrices
  products/index.ts           re-export để import cũ "@/repositories/products" không đổi
  productCategories.ts        ~120  list/save/delete danh mục + thương hiệu dùng chung helper
  productImport.ts            ~100  importProducts, exportProducts (gọi RPC)
src/queries/
  products.ts                 thêm key cho filter mới
  productCategories.ts        ~90   useProductCategories, useProductBrands, mutations
  productImport.ts            ~60
src/views/admin/products/
  ProductsNav.vue             ~40
  Index.vue                   giữ < 120, thêm ProductsFilterBar
  ProductsFilterBar.vue       ~80   tìm, danh mục, thương hiệu, lưu trữ
  useProductsFilters.ts       ~60   filter + URL query
  ProductGroupSheet.vue       viết lại thành vỏ tab ~120
  useProductGroupForm.ts      ~150  state form, fill, submit, lỗi theo tab
  tabs/GeneralTab.vue         ~90
  tabs/ImagesTab.vue          ~120
  tabs/VariantsTab.vue        ~60   bọc ProductAttributesEditor + ProductVariantsTable
  tabs/UnitsTab.vue           ~140
  tabs/BranchPricesTab.vue    ~130
  images/useImageGallery.ts   ~120  thêm/xoá/sắp xếp, tải lên
  images/compressImage.ts     ~60   canvas → WebP
  images/VariantImagePicker.vue ~60
  units/productUnitForm.ts    ~80   kiểu dòng, kiểm tra, giá tự tính
  prices/useBranchPrices.ts   ~90
  categories/Index.vue        ~110
  categories/CategoryRow.vue  ~70
  categories/CategoryDialog.vue ~110
  categories/useCategoryForm.ts ~70
  brands/Index.vue, BrandRow.vue, BrandDialog.vue (~100 mỗi file)
  import/Index.vue            ~90   vỏ trang
  import/ImportDropzone.vue   ~70
  import/ImportPreviewTable.vue ~120
  import/ImportSummary.vue    ~60
  import/useProductImport.ts  ~150  đọc file, chia lô, dry run, nhập thật, tiến độ
  import/importTemplate.ts    ~100  định nghĩa cột, đổi tên cột ↔ khoá, file mẫu
  import/parseRows.ts         ~150  dòng Excel → JSON dòng, kiểm tra client
  import/exportProducts.ts    ~80
src/views/admin/pos/
  CategoryChips.vue           ~60
  UnitPicker.vue              ~80
  catalog.ts, useCatalogItems.ts  thêm lọc danh mục, đơn vị, giá cơ sở (tách useBranchPrices nếu quá 150 dòng)
src/views/admin/inventory/documents/
  documentLines.ts            thêm đơn vị, quy đổi
  DocumentUnitSelect.vue      ~50
src/pages/admin/products/
  index.vue (dời từ products.vue, giữ name adminProducts), categories.vue, brands.vue, import.vue
```

Thư viện Excel: `read-excel-file` và `write-excel-file` (nhỏ, chỉ `.xlsx`, không có lỗ hổng như bản `xlsx` trên npm). Chỉ import động trong trang Nhập/xuất (`await import(...)`) để không làm nặng bundle chính. Đây là phụ thuộc mới duy nhất.

i18n: thêm khoá `productCategories.*`, `productBrands.*`, `productImport.*`, `products.tabs.*`, `products.units.*`, `products.branchPrices.*` vào cả `vi` và `en`.

## 8. Thứ tự làm (cho thread code)

Mỗi bước là một PR riêng, squash merge vào main sau khi typecheck + build sạch và kịch bản ở mục 9 chạy được trên Postgres local. Bước sau giả định bước trước đã merge và migration đã chạy.

| Bước | PR | Migration | Phần chính |
| --- | --- | --- | --- |
| 1 | Danh mục và thương hiệu | `20261015010000`, `20261015010100` | Hai trang mới, `ProductsNav`, tách `repositories/products.ts`, form sản phẩm thành tab (Thông tin + Biến thể), lọc danh sách, chip danh mục ở POS |
| 2 | Bộ ảnh dùng chung | `20261015020000` | Tab Ảnh, nén WebP, chọn ảnh biến thể, quick view shop có dải ảnh, (Should) danh mục trang chủ |
| 3 | Giá theo cơ sở | `20261015030000`, `20261015030100` | Tab Giá theo cơ sở, POS phủ giá cơ sở, `create_invoice` dùng `product_unit_price` |
| 4 | Đơn vị quy đổi | `20261015040000` đến `040200` | Tab Đơn vị, POS chọn đơn vị + quét mã, phiếu nhập theo đơn vị, trả hàng, báo cáo `base_qty`, (Should) lọc danh mục ở tồn kho |
| 5 | Nhập/xuất Excel | `20261015050000` | Trang nhập/xuất, thư viện Excel, (Should) lịch sử nhập |

Bước 3 trước bước 4 vì bước 4 sửa lại `create_invoice` và `product_unit_price` trên nền của bước 3. Bước 5 sau cùng vì file mẫu cần đủ danh mục, ảnh và đơn vị.

## 9. Kịch bản kiểm tra

Chạy trên Postgres local với dữ liệu mẫu (như các module trước), cộng typecheck và build.

1. Tạo "Thức ăn" › "Hạt cho chó"; tạo cấp 3 dưới "Hạt cho chó" → lỗi. Đổi cha của "Thức ăn" thành chính nó → lỗi.
2. Gắn nhóm vào "Hạt cho chó"; lọc danh sách theo "Thức ăn" → thấy nhóm. Xoá "Hạt cho chó" → lỗi `in_use`; ngừng dùng được, nhóm vẫn giữ danh mục.
3. Tải 3 ảnh, kéo ảnh 3 lên đầu, lưu → `product_groups.image_url` = ảnh 3. Xoá ảnh đang được biến thể dùng → biến thể về ảnh bìa. Nhân viên B (có `products: UPDATE`) xoá ảnh do nhân viên A tải → được.
4. Giá chung 100.000, giá riêng cơ sở CS01 90.000: hóa đơn ở CS01 lấy 90.000, `product_unit_price(..., null)` (shop) trả 100.000. Người chỉ có quyền ở CS02 đặt giá CS01 → `42501`.
5. Viên giá 2.000, hộp = 10 viên không đặt giá → hộp 20.000 (ở CS01 với giá riêng viên 1.800 → 18.000). Đặt giá hộp 19.000 → 19.000 ở mọi cơ sở.
6. Bán 2 hộp → `qty 2`, `unit 'hộp'`, `unit_factor 10`, `base_qty 20`, tồn giảm 20 viên theo FEFO, `cost_amount` đúng 20 viên. Hủy hóa đơn → tồn về đủ.
7. Trả 1 trong 2 hộp → tồn +10 viên, tiền hoàn = nửa dòng. Trả tiếp 2 hộp → lỗi "chỉ còn 1".
8. Phiếu nhập 2 thùng (1 thùng = 24 lon), giá vốn 480.000/thùng → lô +48 lon, `unit_cost` 20.000.
9. Mã vạch hộp trùng mã vạch một biến thể khác → lỗi khi lưu. Quét mã vạch hộp ở POS → dòng "1 hộp".
10. Đổi hệ số đơn vị đã có trên hóa đơn → lỗi; tắt được.
11. Báo cáo Sản phẩm: bán 2 hộp + 5 viên → `qty_sold` 25 viên.
12. Nhập Excel 50 dòng (3 dòng lỗi: SKU trống, giá âm, mã vạch trùng) → xem trước đúng 3 lỗi, không ghi gì vào DB. Sửa file, nhập lại → tạo đủ; nhập lại lần nữa → toàn bộ "cập nhật", không đổi dữ liệu. Xuất ra rồi nhập lại → không đổi.
13. Nhập file có nhóm thiếu một biến thể đang có → biến thể đó vẫn còn.
14. Người chỉ có `products: VIEW` gọi `import_products` → `42501`; xuất được.
15. Hóa đơn cũ trước bước 4 vẫn mở được, `unit_factor = 1`, `base_qty = qty`; báo cáo cũ không đổi số.

## 10. Mặc định đã chọn cho câu hỏi mở

| Câu hỏi | Mặc định | Lý do |
| --- | --- | --- |
| Danh mục mấy cấp? | 2 cấp | Đủ cho cửa hàng thú cưng (Thức ăn › Hạt cho chó); cây sâu hơn làm UI và lọc phức tạp |
| Một sản phẩm nhiều danh mục? | Một | Đơn giản cho lọc, báo cáo, Excel |
| Danh mục gắn vào nhóm hay biến thể? | Nhóm | Biến thể cùng nhóm luôn cùng loại hàng |
| Ảnh ở đâu? | Bộ ảnh theo nhóm, biến thể chọn từ bộ ảnh | Một chỗ quản lý, shop đổi ảnh theo biến thể được |
| Giá shop online theo cơ sở nào? | Giá chung | Chưa có khái niệm cơ sở trên shop |
| Giá riêng theo cơ sở cho đơn vị lớn? | Không (Could) | Một cơ sở, ít giá trị |
| Tồn kho theo đơn vị nào? | Đơn vị gốc (nhỏ nhất) | Đúng kế hoạch BA (edge case số 2) |
| Trả hàng đổi đơn vị? | Không | Hiếm, dễ sai tiền hoàn |
| Khoá khi nhập Excel? | SKU, bắt buộc | Mã vạch có thể trống, tên có thể trùng |
| Nhập Excel có xoá? | Không bao giờ | Tránh mất dữ liệu do file thiếu dòng |
| Nhập tồn qua Excel? | Không (Could: phiếu nhập nháp) | Tồn chỉ đổi qua phiếu kho |
| Định dạng file | Chỉ `.xlsx` | Một đường đọc, một thư viện |
| Quyền | Dùng lại `products` | Không cần màn phân quyền mới |

## 11. Rủi ro

| Rủi ro | Cách giảm |
| --- | --- |
| Sửa `create_invoice` / `create_sales_return` làm hỏng POS | Chép bản mới nhất (bảng ở mục 5), chỉ đổi các dòng nêu ở mục 5.2, chạy lại kịch bản POS trong [pos-luong-va-kich-ban-test.md](pos-luong-va-kich-ban-test.md) |
| `base_qty` (cột generated) làm bảng `invoice_lines` bị ghi lại | Bảng còn nhỏ; chạy trong migration bình thường, không cần chia giai đoạn |
| Làm tròn `unit_cost` khi chia hệ số | Tổng tiền dòng tính từ số người dùng nhập; lệch tối đa vài đồng trên giá vốn bình quân |
| `drop function list_product_groups` cũ làm client cũ gọi lỗi trong lúc deploy | Tham số mới đều có mặc định, client cũ gọi bằng tên tham số vẫn chạy với bản mới |
| File Excel lớn làm treo trình duyệt | Giới hạn 2.000 dòng, đọc bằng thư viện nhẹ, gửi lô 200 dòng |
| Ảnh mồ côi trong storage | Vô hại; dọn dẹp là Could |
