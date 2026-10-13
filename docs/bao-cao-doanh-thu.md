# Báo cáo doanh thu

Kế hoạch module báo cáo (M11 trong kế hoạch BA/kiến trúc v0.3, mục 2.3 và thứ tự Phase 1 bước 5). Module đứng sau POS (PR #43, #54), kho theo lô (PR #44) và lịch hẹn spa (PR #55, #56, #58), đều đã merge.

**Tiến độ:** đã lên plan, chưa code. Plan này đủ chi tiết để một thread khác code theo, không cần hỏi lại. Các câu hỏi mở đã được chọn mặc định ở mục 11.

Dự án là pet project cá nhân, chưa có doanh thu, nên ưu tiên đơn giản, rẻ, dễ hiểu: tính trực tiếp từ bảng gốc bằng Postgres RPC, không bảng tổng hợp, không thư viện biểu đồ mới, xuất CSV ở trình duyệt.

## 1. Trước và sau

**Trước:** số liệu bán hàng chỉ xem được theo từng ca (`cash_shift_summary`) hoặc lật từng hóa đơn trong danh sách Hóa đơn. Không có cách xem doanh thu một ngày, một tháng, tách shop và spa, theo phương thức thanh toán, theo nhân viên, hay biết sản phẩm/dịch vụ nào bán chạy và lãi bao nhiêu. Hoàn trả và hủy hóa đơn nằm rải rác trong từng hóa đơn.

**Sau:** menu mới "Báo cáo" có 5 tab dùng chung một bộ lọc (cơ sở + khoảng ngày):

1. **Tổng quan**: thẻ KPI (doanh thu thuần, số hóa đơn, giá trị trung bình, hoàn trả, so với kỳ trước), biểu đồ cột doanh thu theo ngày tách Shop / Spa, cơ cấu theo mảng và theo phương thức thanh toán, bảng theo ngày/tuần/tháng.
2. **Sản phẩm & dịch vụ**: xếp hạng theo doanh thu, số lượng hoặc lãi gộp; tìm kiếm, phân trang.
3. **Nhân viên**: doanh thu theo thu ngân, và theo nhân viên spa (người làm phiếu).
4. **Hoàn trả & hủy**: mọi phiếu trả hàng và hóa đơn bị hủy trong kỳ, có lý do và người làm.
5. **Đối chiếu ca**: các ca thu ngân trong kỳ, tiền mặt dự kiến so với tiền đếm, chênh lệch.

Mỗi tab có nút "Xuất CSV" (quyền `reports: EXPORT`). Màn Dashboard có thêm ô "Hôm nay" cho người có quyền xem báo cáo (Should).

## 2. Phạm vi

| Mức | Nội dung |
| --- | --- |
| **Must** | Quyền `reports` theo cơ sở; bộ lọc cơ sở + khoảng ngày dùng chung, giữ trên URL; Tổng quan (KPI, biểu đồ ngày, Shop/Spa, phương thức thanh toán, bảng theo ngày); Top sản phẩm & dịch vụ; Doanh thu theo thu ngân và nhân viên spa; Hoàn trả & hủy; Đối chiếu ca; xuất CSV |
| **Should** | So sánh kỳ trước (% tăng giảm); gom theo tuần/tháng; lãi gộp hàng hóa (theo giá vốn lô); ô "Hôm nay" trên Dashboard; "Tất cả cơ sở" khi người dùng có quyền ở nhiều cơ sở |
| **Could** | Doanh thu theo giờ trong ngày (giờ cao điểm); khách hàng mua nhiều nhất; tỉ lệ no-show/hủy lịch spa; in báo cáo |
| **Won't (lần này)** | Bảng tổng hợp / materialized view; báo cáo tồn kho (đã có ở màn Tồn kho); hoa hồng nhân viên; công nợ; lưu trú (chưa có module); xuất Excel .xlsx; gửi báo cáo tự động qua email/Zalo |

## 3. Định nghĩa số liệu

Đây là phần quan trọng nhất: mọi màn và mọi RPC dùng đúng các định nghĩa này.

### 3.1 Ngày nghiệp vụ

- Một hóa đơn thuộc ngày `(invoices.created_at at time zone 'Asia/Ho_Chi_Minh')::date`, cùng múi giờ với `public.business_date()`.
- Phiếu trả hàng thuộc ngày của `sales_returns.created_at`; hóa đơn hủy thuộc ngày của `cancelled_at`; ca thuộc ngày của `opened_at`. Tất cả theo giờ Việt Nam.
- RPC nhận `p_from date`, `p_to date` (cả hai đầu đều tính). Khoảng tối đa 366 ngày, quá thì báo lỗi `22023` hint `range_too_long`.
- Để dùng được index `invoices (branch_id, created_at desc)`, điều kiện viết theo `created_at >= (p_from::timestamp at time zone 'Asia/Ho_Chi_Minh') and created_at < ((p_to + 1)::timestamp at time zone 'Asia/Ho_Chi_Minh')`, không bọc `created_at` trong hàm.

### 3.2 Doanh thu

| Chỉ số | Công thức | Ghi chú |
| --- | --- | --- |
| **Tiền hàng** (gross) | `sum(invoices.subtotal)` của hóa đơn `paid` | Bằng tổng `invoice_lines.amount` |
| **Giảm giá** | `sum(invoices.discount_amount)` của hóa đơn `paid` | Giảm giá chỉ có ở cấp hóa đơn |
| **Doanh thu bán** (net sales) | `sum(invoices.total)` của hóa đơn `paid` = Tiền hàng − Giảm giá | |
| **Hoàn trả** | `sum(sales_returns.refund_amount)` có ngày trong kỳ | Trừ vào kỳ của ngày trả, không sửa kỳ của hóa đơn gốc |
| **Doanh thu thuần** | Doanh thu bán − Hoàn trả | Con số chính ở thẻ KPI |
| **Số hóa đơn** | `count(*)` hóa đơn `paid` | |
| **Giá trị TB / hóa đơn** | Doanh thu bán / Số hóa đơn | 0 khi không có hóa đơn |
| **Hóa đơn hủy** | Số lượng và `sum(total)` của hóa đơn `cancelled` có `cancelled_at` trong kỳ | Không tính vào doanh thu; chỉ để kiểm soát |

Hóa đơn đã hủy không bao giờ tính vào doanh thu, kể cả ở ngày bán. Hủy chỉ làm được khi ca còn mở, nên gần như luôn cùng ngày.

### 3.3 Doanh thu từng dòng (để tách mảng, xếp hạng, theo nhân viên)

Giảm giá cấp hóa đơn được chia đều theo tỉ lệ tiền dòng:

```
line_net = invoice_lines.amount * invoices.total / nullif(invoices.subtotal, 0)   -- 0 khi subtotal = 0
```

Giữ nguyên số thập phân trong SQL, chỉ `round(..., 0)` ở tổng cuối mỗi nhóm. Tổng các nhóm có thể lệch tổng hóa đơn tối đa vài đồng do làm tròn; thẻ KPI luôn lấy từ `invoices` (mục 3.2) nên không lệch. Cách chia này giống cách `create_sales_return` tính tiền hoàn từng dòng.

### 3.4 Mảng (segment)

| Mảng | Điều kiện |
| --- | --- |
| **Shop** | `invoice_lines.item_type = 'product'` |
| **Spa** | `item_type in ('service', 'combo')` |
| ↳ Spa theo lịch hẹn | dòng spa có `appointment_items.invoice_line_id = invoice_lines.id` |
| ↳ Spa bán lẻ tại quầy | dòng spa không gắn phiếu lịch hẹn |

Hoàn trả chỉ có ở hàng hóa (`create_sales_return` chỉ nhận dòng product), nên hoàn trả trừ toàn bộ vào Shop. Khi có module Lưu trú sẽ thêm mảng thứ ba; RPC trả mảng dạng khóa (`shop`, `spa`) để thêm được mà không đổi cấu trúc.

### 3.5 Phương thức thanh toán

| Chỉ số | Công thức |
| --- | --- |
| Tiền mặt thu | `sum(payments.amount where method = 'cash')` − `sum(invoices.change_amount)` (hóa đơn `paid`) |
| Chuyển khoản | `sum(payments.amount where method = 'transfer')` |
| Thẻ | `sum(payments.amount where method = 'card')` |
| Hoàn tiền mặt / chuyển khoản | `sum(sales_returns.refund_amount)` theo `refund_method` |

Tiền mặt trừ tiền thối để Tiền mặt + Chuyển khoản + Thẻ = Doanh thu bán. Thanh toán thuộc ngày của hóa đơn (thanh toán tạo cùng lúc với hóa đơn).

### 3.6 Giá vốn và lãi gộp (chỉ hàng hóa)

- Giá vốn bán = `sum(invoice_lines.cost_amount)` của dòng product trên hóa đơn `paid` (trigger `take_stock` đã ghi giá vốn theo lô FEFO). Dòng bán trước khi sản phẩm theo dõi tồn có `cost_amount` null: coi là 0 và đếm số dòng thiếu giá vốn để hiện cảnh báo nhỏ "N dòng chưa có giá vốn".
- Giá vốn hoàn = `sum(stock_movements.qty * stock_movements.unit_cost)` với `reason = 'return'` và `return_id` thuộc phiếu trả trong kỳ (qty dương vì hàng về kho).
- Lãi gộp hàng hóa = (Doanh thu bán dòng product − Hoàn trả) − (Giá vốn bán − Giá vốn hoàn).
- Dịch vụ spa không có giá vốn (chưa trừ kho vật tư), nên cột lãi gộp của dịch vụ để trống, không ghi 100%.
- Gắn nhãn "ước tính" trên UI.

### 3.7 Nhân viên

- **Thu ngân**: `invoices.created_by`, tên in là `invoices.cashier_name`. Doanh thu bán, số hóa đơn, giá trị TB, số hóa đơn bị hủy. Hoàn trả gán cho `sales_returns.created_by` (người làm phiếu trả).
- **Nhân viên spa**: `appointment_items.staff_id` của các dòng spa đã thanh toán (nối qua `invoice_line_id`); tên lấy từ `public.staff_display_name(staff_id)`. Chỉ số: số phiếu, số thú khác nhau, `line_net`. Dòng spa bán lẻ không có phiếu lịch hẹn, hoặc phiếu chưa gán nhân viên, gộp vào một dòng "Chưa gán nhân viên".

## 4. Quyền

Thêm mã quyền mới `reports` (module "Báo cáo"), methods `VIEW`, `EXPORT`, `ALL`.

| Method | Cho phép |
| --- | --- |
| `VIEW` | Mở menu Báo cáo, xem mọi tab ở cơ sở được cấp |
| `EXPORT` | Nút Xuất CSV |

- Hàm `public.can_report(p_method text, p_branch uuid)`: `is_admin() or has_permission('reports', p_method, p_branch)`, cùng mẫu với `can_pos`, `can_schedule`.
- Cấp sẵn: `admin` → `ALL`. Không cấp cho `cashier`, `inventory` (chủ quán tự cấp ở màn Phân quyền nếu muốn).
- Không thêm RLS mới: báo cáo chỉ đọc qua RPC `security definer`, mỗi RPC kiểm tra `can_report('VIEW', branch)` cho từng cơ sở được hỏi và báo lỗi `42501` nếu thiếu.
- **Nhiều cơ sở**: `p_branch = null` nghĩa là "mọi cơ sở người gọi có `reports: VIEW`". Helper nội bộ `public.report_branch_ids(p_branch uuid) returns uuid[]`: nếu `p_branch` có giá trị thì kiểm tra quyền ở đó (thiếu quyền → `42501`), nếu null thì trả mảng các cơ sở có quyền (rỗng → `42501`). Mọi RPC lọc `branch_id = any(v_branches)`.
- Frontend: `ADMIN_ROUTE_PERMISSIONS` thêm 5 route → `reports`; nút Xuất ẩn khi `!auth.can('reports', 'EXPORT')`.

## 5. Database: RPC và index

Tất cả hàm: `language plpgsql` (hoặc `sql`), `stable`, `security definer`, `set search_path = ''`, `revoke ... from public, anon`, `grant ... to authenticated` (helper nội bộ thì revoke hết). Migration forward-only, chạy lại được, không sửa file cũ. Workflow "Supabase migrate" tự chạy khi merge vào main.

### 5.1 Index thêm

```sql
create index if not exists sales_returns_branch_created_idx on public.sales_returns (branch_id, created_at);
create index if not exists invoices_branch_cancelled_idx on public.invoices (branch_id, cancelled_at) where cancelled_at is not null;
create index if not exists appointment_items_invoice_line_idx on public.appointment_items (invoice_line_id) where invoice_line_id is not null;
create index if not exists stock_movements_return_reason_idx on public.stock_movements (return_id) where reason = 'return';
```

`invoices (branch_id, created_at desc)`, `invoice_lines` theo product/service/combo, `payments (invoice_id)`, `cash_shifts (branch_id, opened_at desc)` đã có.

Khối lượng dự kiến nhỏ (một cơ sở, vài trăm hóa đơn/ngày), tính trực tiếp đủ nhanh. Xem lại bằng `EXPLAIN ANALYZE` khi vượt khoảng 100.000 hóa đơn; lúc đó mới cân nhắc bảng tổng hợp theo ngày.

### 5.2 Helper nội bộ (không cấp cho client)

| Hàm | Trả về | Mục đích |
| --- | --- | --- |
| `report_branch_ids(p_branch uuid)` | `uuid[]` | Mục 4 |
| `report_range(p_from date, p_to date)` | `tstzrange` | Kiểm tra `p_from <= p_to`, ≤ 366 ngày, đổi sang khoảng giờ VN `[from 00:00, to+1 00:00)` |
| `report_sales_lines(p_branches uuid[], p_from timestamptz, p_to timestamptz)` | `table` | Một dòng cho mỗi `invoice_lines` của hóa đơn `paid` trong khoảng: `invoice_id, branch_id, biz_date, cashier_id, cashier_name, line_id, item_type, product_id, service_id, combo_id, name, sku, qty, amount, line_net, cost_amount, segment ('shop'/'spa'), appointment_item_id, staff_id, pet_id` |

`report_sales_lines` là nguồn duy nhất cho tách mảng, top mặt hàng và nhân viên spa, để mọi tab tính `line_net` giống nhau. Tham số timestamptz (đã đổi bằng `report_range`) để điều kiện dùng được index.

### 5.3 RPC cho màn hình

**`report_overview(p_branch uuid, p_from date, p_to date) returns jsonb`**

```jsonc
{
  "gross": 0, "discount": 0, "net_sales": 0, "refunds": 0, "net_revenue": 0,
  "invoice_count": 0, "avg_ticket": 0,
  "cancelled_count": 0, "cancelled_amount": 0, "return_count": 0,
  "segments": { "shop": 0, "spa": 0, "spa_appointment": 0, "spa_walk_in": 0 },
  "payments": { "cash": 0, "transfer": 0, "card": 0, "refund_cash": 0, "refund_transfer": 0 },
  "gross_profit": 0, "missing_cost_lines": 0,
  "previous": { "net_revenue": 0, "invoice_count": 0, "avg_ticket": 0 }   // kỳ liền trước cùng số ngày
}
```

`segments.shop` là doanh thu dòng product trước hoàn trả; thẻ Shop trên UI hiện `shop − refunds`. Kỳ trước: `[p_from − n, p_from − 1]` với `n = p_to − p_from + 1`; dùng chung helper, không gọi đệ quy RPC.

**`report_revenue_series(p_branch uuid, p_from date, p_to date, p_bucket text default 'day') returns table`**

`p_bucket`: `day` | `week` (thứ hai đầu tuần, `date_trunc('week', ...)`) | `month`. Trả mọi bucket trong khoảng, kể cả bucket trống (dùng `generate_series`), sắp tăng dần:

`bucket date, invoice_count int, gross numeric, discount numeric, net_sales numeric, refunds numeric, net_revenue numeric, shop numeric, spa numeric, cash numeric, transfer numeric, card numeric`

Tối đa 366 dòng, không phân trang ở DB (biểu đồ cần đủ chuỗi); bảng dưới biểu đồ phân trang ở client bằng `PagedTableCard`. Đây là ngoại lệ có chủ đích của quy ước "mọi getList có page + page_size", vì đây là chuỗi thời gian có giới hạn, không phải danh sách.

**`report_top_items(p_branch, p_from, p_to, p_kind text default 'all', p_search text default null, p_sort text default 'revenue', p_limit int default 20, p_offset int default 0) returns table`**

- `p_kind`: `all` | `product` | `service` (gồm cả combo).
- Gom theo `(item_type, coalesce(product_id, service_id, combo_id))`. Tên lấy theo tên hiện tại trong danh mục, fallback tên trên dòng.
- `p_search`: `ilike` theo tên và SKU, `=` theo barcode (giống `stock_summary`).
- `p_sort`: `revenue` | `qty` | `profit` (giảm dần, rồi tên).
- Cột: `item_type text, item_id uuid, name text, sku text, unit text, qty_sold numeric, qty_returned numeric, invoice_count bigint, net_revenue numeric, refunds numeric, cost numeric, gross_profit numeric, share numeric (% trên tổng doanh thu bán trong kỳ), total_count bigint`.
- `qty_returned`, `refunds`: từ `sales_return_lines` có phiếu trả trong kỳ, theo `product_id`.
- `cost`, `gross_profit` null với dịch vụ/combo.

**`report_staff_revenue(p_branch, p_from, p_to, p_role text default 'cashier', p_search text default null, p_limit int default 20, p_offset int default 0) returns table`**

- `p_role = 'cashier'`: `staff_id, name, invoice_count, net_sales, refunds, cancelled_count, avg_ticket, total_count`.
- `p_role = 'spa'`: `staff_id (null = chưa gán), name, ticket_count, pet_count, net_sales, total_count` (cột không dùng trả null). Sắp theo `net_sales` giảm dần.
- `p_search`: theo tên.

**`report_adjustments(p_branch, p_from, p_to, p_kind text default 'all', p_search text default null, p_limit int default 20, p_offset int default 0) returns table`**

Hợp `union all` của phiếu trả (`kind = 'return'`) và hóa đơn hủy (`kind = 'cancel'`), sắp mới nhất trước:

`kind text, id uuid, code text (mã phiếu TH hoặc mã hóa đơn), invoice_id uuid, invoice_code text, at timestamptz, amount numeric, method text (refund_method; null với hủy), reason text, by_name text, item_summary text ("Hạt Royal Canin x2, ..." tối đa 3 tên), total_count bigint`

`p_search`: theo mã phiếu, mã hóa đơn, lý do. Tên người hủy: `staff_display_name(cancelled_by)`.

**`report_shifts(p_branch, p_from, p_to, p_status text default 'all', p_search text default null, p_limit int default 20, p_offset int default 0) returns table`**

`id, code, branch_code, status, opened_by_name, opened_at, closed_by_name, closed_at, opening_cash, invoice_count, sales_total, cash_in, transfer_in, card_in, refund_cash, expected_cash, counted_cash, difference (counted − expected; null khi ca đang mở), total_count`

- Ca đã đóng: `expected_cash`, `counted_cash` lấy từ `cash_shifts` (đã chốt lúc đóng). Ca đang mở: `expected_cash` tính trực tiếp theo đúng công thức của `cash_shift_summary`, `counted_cash` null.
- Không gọi `cash_shift_summary` (hàm đó kiểm tra quyền `pos`, người chỉ có `reports` sẽ bị chặn). Không sửa `cash_shift_summary`.
- `p_status`: `all` | `open` | `closed` | `mismatch` (ca đóng có `difference <> 0`).
- `p_search`: theo mã ca, tên thu ngân.

Mọi RPC danh sách: `total_count` = `count(*) over ()` trước `limit/offset`, giống `stock_summary`; `p_limit` kẹp trong `[1, 5000]` (5000 cho xuất CSV).

### 5.4 Chia file migration (mỗi file dưới ~300 dòng)

| File | Nội dung |
| --- | --- |
| `20261014010000_reports_access.sql` | Quyền `reports`, cấp cho `admin`, `can_report`, `report_branch_ids`, `report_range`, index mục 5.1 |
| `20261014010100_reports_sales_lines.sql` | `report_sales_lines` |
| `20261014010200_reports_overview.sql` | `report_overview`, `report_revenue_series` |
| `20261014010300_reports_rankings.sql` | `report_top_items`, `report_staff_revenue` |
| `20261014010400_reports_audit.sql` | `report_adjustments`, `report_shifts` |

Sau migration chạy `supabase gen types` (hoặc sửa tay `src/types/database.types.ts` như các module trước) để `client.rpc(...)` có kiểu.

## 6. Màn hình

Menu sidebar: section mới **"Báo cáo"** (`adminNav.reports`) đặt ngay sau "Bán hàng", 5 mục: Tổng quan, Sản phẩm & dịch vụ, Nhân viên, Hoàn trả & hủy, Đối chiếu ca. Trong trang có thêm `ReportsNav` dạng tab như `PosNav`.

| Route name | Path | Trang |
| --- | --- | --- |
| `reportsOverview` | `/admin/reports` | Tổng quan |
| `reportsItems` | `/admin/reports/items` | Sản phẩm & dịch vụ |
| `reportsStaff` | `/admin/reports/staff` | Nhân viên |
| `reportsAdjustments` | `/admin/reports/adjustments` | Hoàn trả & hủy |
| `reportsShifts` | `/admin/reports/shifts` | Đối chiếu ca |

### 6.1 Bộ lọc chung (`ReportFilterBar`)

- **Cơ sở**: `ReportBranchPicker`. Danh sách lấy từ `useBranches()` lọc theo cơ sở có `reports: VIEW` (`my_permissions`). Có mục "Tất cả cơ sở" (giá trị `all` → `p_branch = null`) chỉ khi có quyền ở từ 2 cơ sở trở lên. Một cơ sở thì hiện nhãn tĩnh như `BranchPicker`.
- **Khoảng ngày**: chip nhanh Hôm nay · Hôm qua · 7 ngày · Tháng này · Tháng trước · Tùy chọn (mở `RangeDateShadcn`). Mặc định **Tháng này**.
- Trạng thái lọc nằm trên URL query (`?branch=...&from=2026-10-01&to=2026-10-13&preset=thisMonth`) để chuyển tab giữ nguyên lọc, F5 không mất, gửi link được. `ReportsNav` truyền nguyên `route.query` khi chuyển tab.
- Ngày tính theo giờ Việt Nam ở client bằng `date-fns` (đã có), gửi lên dạng `yyyy-MM-dd`.

### 6.2 Tổng quan

```
[ReportsNav]                                   [Cơ sở ▾] [Hôm nay|7 ngày|Tháng này|...] [Xuất CSV]
┌ Doanh thu thuần ┐┌ Số hóa đơn ┐┌ TB / hóa đơn ┐┌ Hoàn trả ┐┌ Lãi gộp hàng (ước tính) ┐
│ 12.500.000 ₫    ││ 184        ││ 67.900 ₫      ││ 350.000 ₫││ 2.100.000 ₫             │
│ ▲ 8% so kỳ trước││ ▼ 3%       ││ ▲ 11%         ││ 3 phiếu  ││ 2 dòng chưa có giá vốn  │
└─────────────────┘└────────────┘└───────────────┘└──────────┘└─────────────────────────┘
┌ Doanh thu theo ngày (cột chồng Shop / Spa) ───────────────┐┌ Cơ cấu ─────────────────┐
│  ▇ ▅ ▇ ▆ ▃ ▇ ...                         [Ngày|Tuần|Tháng]││ Shop   7.800.000  62%    │
│                                                            ││ Spa    4.700.000  38%    │
│                                                            ││  · theo lịch hẹn  4.1tr  │
│                                                            ││  · bán lẻ          0.6tr │
│                                                            ││ Tiền mặt / CK / Thẻ ...  │
└────────────────────────────────────────────────────────────┘└──────────────────────────┘
┌ Bảng theo ngày: Ngày | HĐ | Tiền hàng | Giảm giá | Hoàn trả | Thuần | Shop | Spa | TM | CK | Thẻ ┐
│ ... (PagedTableCard, phân trang ở client, dòng tổng in đậm cuối bảng)                         │
└───────────────────────────────────────────────────────────────────────────────────────────────┘
```

- Hai query: `report_overview` (thẻ + cơ cấu) và `report_revenue_series` (biểu đồ + bảng).
- Mũi tên so kỳ trước: xanh khi tăng, đỏ khi giảm (riêng Hoàn trả thì ngược lại), "—" khi kỳ trước bằng 0.
- Biểu đồ: component SVG tự viết `StackedBarChart.vue` (cột chồng, trục Y rút gọn "1,2tr", tooltip khi hover, cuộn ngang nếu quá 31 cột). **Không thêm thư viện biểu đồ**. Màu: Shop = teal primary `#0F766E`, Spa = `#F59E0B`.
- Bấm một cột ngày → chuyển sang tab Hóa đơn của POS lọc đúng ngày đó (Could; cần `useInvoicesFilters` nhận `from/to` qua query).

### 6.3 Sản phẩm & dịch vụ

- Thanh lọc riêng: tab Tất cả / Hàng hóa / Dịch vụ; ô tìm (debounce 500ms); sắp theo Doanh thu / Số lượng / Lãi gộp.
- Bảng: # hạng | Tên (+ SKU) | Loại | SL bán | SL trả | Doanh thu thuần | Tỉ trọng (thanh ngang nhỏ) | Giá vốn | Lãi gộp | Biên %.
- `PagedTableCard`, phân trang ở footer, page size nhớ theo bảng như các bảng khác.

### 6.4 Nhân viên

- Hai tab: **Thu ngân** | **Nhân viên spa**. Ô tìm theo tên.
- Thu ngân: Tên | Số HĐ | Doanh thu bán | Hoàn trả | HĐ hủy | TB/HĐ.
- Spa: Tên | Số phiếu | Số thú | Doanh thu dịch vụ | Tỉ trọng.

### 6.5 Hoàn trả & hủy

- Lọc: Tất cả / Trả hàng / Hủy hóa đơn; tìm theo mã, lý do.
- Bảng: Loại (badge) | Mã | Hóa đơn gốc | Thời gian | Hàng | Số tiền | Hình thức hoàn | Lý do | Người làm.
- Bấm mã hóa đơn mở `InvoiceSheet` có sẵn của POS (tái sử dụng, không viết lại).

### 6.6 Đối chiếu ca

- Lọc: Tất cả / Đang mở / Đã đóng / Lệch tiền; tìm theo mã ca, thu ngân.
- Bảng: Mã ca | Thu ngân | Mở lúc | Đóng lúc | Số HĐ | Doanh thu | Tiền mặt dự kiến | Tiền đếm | Chênh lệch (đỏ khi thiếu, cam khi thừa).

### 6.7 Xuất CSV

- `useReportExport`: gọi lại đúng RPC của tab với `p_limit = 5000, p_offset = 0`, đổi sang CSV bằng `src/lib/csv.ts`, tải về `bao-cao-<tab>-<from>-<to>.csv`.
- UTF-8 có BOM để Excel đọc đúng tiếng Việt; số xuất dạng số thô (không ký hiệu ₫); tiêu đề cột tiếng Việt lấy từ i18n.
- Khi `total_count > 5000` hiện toast "Chỉ xuất 5.000 dòng đầu, hãy thu hẹp khoảng ngày".

### 6.8 Dashboard (Should)

`DashboardView` thêm `TodaySalesCard` phía trên lối tắt khi `auth.can('reports', 'VIEW')`: doanh thu thuần hôm nay, số hóa đơn, Shop/Spa, gọi `report_overview` với cơ sở hiện tại (`useCurrentBranch`) và hôm nay. Bấm vào mở Tổng quan.

## 7. Cấu trúc file frontend

Theo quy tắc chia file của dự án: page mỏng, logic trong composable, hàm thuần trong helper, type riêng, mỗi file dưới ~300 dòng.

```
src/pages/admin/reports/
  index.vue  items.vue  staff.vue  adjustments.vue  shifts.vue      # 12 dòng mỗi file, definePageMeta + <View />

src/repositories/reports/
  index.ts          # re-export
  types.ts          # ReportFilter, ReportOverview, SeriesPoint, TopItem, StaffRevenue, Adjustment, ShiftRecon, Bucket, ItemKind...
  parse.ts          # toOverview, toSeriesPoint, toTopItem... (snake_case → camelCase, num())
  overview.ts       # getOverview, getRevenueSeries
  rankings.ts       # listTopItems, listStaffRevenue  → Page<T>
  audit.ts          # listAdjustments, listShifts     → Page<T>

src/queries/reports.ts          # useReportOverview, useRevenueSeries, useTopItems, useStaffRevenue, useAdjustments, useShiftRecon
src/queries/keys.ts             # + reportKeys (all, overview(filter), series(filter, bucket), list(tab, page, filter))
src/queries/pos.ts              # invalidatePos thêm reportKeys.all (bán / hủy / trả làm số liệu đổi)

src/lib/csv.ts                  # toCsv(rows, columns), downloadCsv(name, text). Thuần, không Vue.
src/lib/access.ts               # + 5 route → "reports"
src/lib/navigations.ts          # + section "adminNav.reports"
src/i18n/locales/vi.json, en.json   # + "reports.*", "adminNav.reports*"

src/views/admin/reports/
  ReportsNav.vue                # tab, giữ route.query
  shared/
    ReportFilterBar.vue         # branch + preset chips + range + slot cho lọc riêng + nút xuất
    ReportBranchPicker.vue
    DatePresetChips.vue
    KpiCard.vue                 # label, value, delta, hint
    StackedBarChart.vue         # SVG thuần, props: points, series, formatY
    ExportButton.vue
    useReportFilters.ts         # đọc/ghi URL query → ReportFilter (branchId|null, from, to); trả cả previous range
    useReportBranches.ts        # cơ sở có reports: VIEW, cờ showAll
    useReportExport.ts          # fetch 5000 + csv + toast
    dateRange.ts                # PRESETS, presetRange(preset, today), previousRange, toIsoDate, rangeDays
    format.ts                   # money (tái dùng pos/format), compactMoney ("1,2tr"), percent, delta
    chartScale.ts               # niceMax, ticks, bar geometry (thuần, dễ test)
  overview/
    Index.vue                   # shell: filter bar + 3 khối
    OverviewKpis.vue
    RevenueChartCard.vue        # chọn bucket + StackedBarChart
    MixCard.vue                 # cơ cấu mảng + phương thức thanh toán
    SeriesTable.vue
    useOverview.ts              # 2 query + bucket + phân trang client cho bảng
  items/
    Index.vue  ItemsFilterBar.vue  ItemRow.vue  useItemsFilters.ts
  staff/
    Index.vue  StaffTabs.vue  CashierRow.vue  SpaStaffRow.vue  useStaffFilters.ts
  adjustments/
    Index.vue  AdjustmentRow.vue  useAdjustmentFilters.ts
  shifts/
    Index.vue  ShiftReconRow.vue  useShiftReconFilters.ts
```

Tái sử dụng có sẵn: `PagedTableCard`, `TableStateRows`, `usePagedSearch` (debounce 500ms, reset trang khi lọc đổi), `usePagedList`, `RangeDateShadcn`, `InvoiceSheet`, `pos/format.ts` (`money`, `dateTime`), `Header`, `ContentWrap fill`.

## 8. Thứ tự làm (cho thread code)

Mỗi bước một PR nhỏ, tự squash merge theo quy ước của dự án, báo migration nào đã chạy tự động.

| Bước | Nội dung | Migration |
| --- | --- | --- |
| 1 | Quyền + helper + index + `report_sales_lines` + `report_overview` + `report_revenue_series`; repository, query, bộ lọc chung, menu, tab Tổng quan (KPI, biểu đồ, cơ cấu, bảng); xuất CSV cho Tổng quan | `..010000`, `..010100`, `..010200` |
| 2 | `report_top_items`, `report_staff_revenue`; tab Sản phẩm & dịch vụ, tab Nhân viên | `..010300` |
| 3 | `report_adjustments`, `report_shifts`; tab Hoàn trả & hủy, tab Đối chiếu ca | `..010400` |
| 4 | Ô "Hôm nay" trên Dashboard; invalidate `reportKeys` khi bán/hủy/trả; cập nhật mục "Tiến độ" của tài liệu này | không |

## 9. Kịch bản kiểm tra

Dữ liệu mẫu: một ngày có 3 hóa đơn ở CS01.

| # | Dữ liệu | Kỳ vọng |
| --- | --- | --- |
| T1 | HĐ1: 2 hàng 100.000 + 1 dịch vụ 200.000, giảm 40.000, khách đưa tiền mặt 400.000 (thối 40.000) | Tiền hàng 400.000, giảm 40.000, doanh thu bán 360.000; Shop 180.000, Spa 180.000 (chia giảm giá theo tỉ lệ); tiền mặt 360.000 |
| T2 | HĐ2: phiếu spa từ lịch hẹn 300.000, chuyển khoản | Spa theo lịch hẹn 300.000; nhân viên spa của phiếu có 300.000, 1 phiếu |
| T3 | HĐ3 bán rồi hủy trong ca | Không vào doanh thu; tab Hoàn trả & hủy có 1 dòng "Hủy" |
| T4 | Hôm sau trả 1 hàng của HĐ1 | Hoàn trả 90.000 vào hôm sau, không đổi số liệu hôm trước; SL trả = 1 ở top mặt hàng; giá vốn hoàn trừ ra khỏi lãi gộp |
| T5 | Hóa đơn lúc 23:30 giờ VN | Thuộc đúng ngày đó, không nhảy sang ngày sau (UTC) |
| T6 | Người có `reports: VIEW` ở CS01 hỏi CS02 | Lỗi `42501`, UI hiện "Không có quyền" |
| T7 | Người không có `reports` | Không thấy menu; gọi thẳng RPC bị `42501` |
| T8 | Khoảng 400 ngày | Lỗi `range_too_long`, UI chặn ngay ở bộ lọc |
| T9 | Ca đóng có tiền đếm thiếu 20.000 | Đối chiếu ca hiện −20.000 màu đỏ, lọc "Lệch tiền" ra ca này |
| T10 | Tổng các ngày trong bảng | Bằng thẻ KPI của cả kỳ |

## 10. Rủi ro

| Rủi ro | Cách xử lý |
| --- | --- |
| Lệch vài đồng giữa tổng theo mảng và tổng hóa đơn | Thẻ KPI lấy từ `invoices`; ghi chú nhỏ dưới cơ cấu "đã chia giảm giá theo tỉ lệ" |
| Giá vốn thiếu với hàng bán trước khi theo dõi tồn | Đếm `missing_cost_lines`, nhãn "ước tính" |
| RPC chậm khi dữ liệu lớn | Index mục 5.1, giới hạn 366 ngày; xem lại ở mốc 100.000 hóa đơn |
| Định nghĩa lệch giữa các tab | Một helper `report_sales_lines` cho mọi số liệu theo dòng |

## 11. Mặc định đã chọn cho câu hỏi mở

| Câu hỏi | Chọn | Lý do |
| --- | --- | --- |
| Hoàn trả trừ vào kỳ nào? | Kỳ của ngày trả | Số đã chốt của ngày cũ không đổi, khớp tiền thực tế trong ca |
| Hóa đơn hủy? | Không tính doanh thu; liệt kê riêng | Hủy chỉ khi ca còn mở |
| Doanh thu dòng khi có giảm giá cấp hóa đơn? | Chia theo tỉ lệ tiền dòng | Giống cách tính tiền hoàn |
| Tiền mặt thu? | Tiền khách đưa − tiền thối | Ba phương thức cộng lại bằng doanh thu bán |
| Doanh thu nhân viên spa? | Theo `staff_id` của phiếu, giá trị sau chia giảm giá | Nhân viên làm phiếu mới là người tạo doanh thu dịch vụ |
| Quyền | Mã mới `reports` (VIEW, EXPORT), chỉ cấp sẵn cho admin | Báo cáo doanh thu là thông tin quản lý; tách khỏi `pos: VIEW` của thu ngân |
| Mặc định khoảng ngày | Tháng này | Câu hỏi hay gặp nhất của chủ quán |
| Biểu đồ | SVG tự viết, không thêm thư viện | Chỉ cần cột chồng; giữ bundle nhỏ, ít phụ thuộc |
| Xuất file | CSV ở trình duyệt, tối đa 5.000 dòng | Không cần thư viện xlsx, Excel mở được |
| Bảng tổng hợp / materialized view | Không | Dữ liệu nhỏ; tính trực tiếp luôn đúng, không phải làm mới |
| "Tất cả cơ sở" | Có, khi có quyền từ 2 cơ sở | Thiết kế sẵn đa cơ sở, chưa tốn công khi chỉ có 1 |
| Tuần bắt đầu | Thứ hai (ISO) | Thói quen ở Việt Nam |
