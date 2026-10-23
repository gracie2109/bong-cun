# Audit kiến trúc Multi-Dashboard (Pawtiny)

Ngày: 2026-10-23 · Repo `gracie2109/bong-cun`, nhánh `main`, commit `edd81d0` (đã `git fetch`, trùng `origin/main`).
Phạm vi: chỉ đọc code, schema, RPC, policy, composable, component, route, test. Không sửa code, không migration, không đổi cấu hình.
Báo cáo trước (nghiên cứu widget + ThingsBoard): `pet-care-plan/nghien-cuu-dashboard-widget.md`. Báo cáo này đi sâu hơn về phạm vi chi nhánh, quyền và data contract, và thay thế phần đề xuất dashboard của báo cáo trước.

Nhãn:

- **[F]** đã xác minh trong code (có đường dẫn) · **[I]** suy luận từ bằng chứng · **[U]** chưa đủ bằng chứng.
- Mức ưu tiên: **P0** sai dữ liệu / sai quyền / rủi ro bảo mật · **P1** nền tảng bắt buộc cho Multi-Dashboard · **P2** UX, hiệu năng, bảo trì · **Later**.

Đường dẫn viết tắt: `S` = `supabase/schema.sql` (bản dump sinh tự động của DB, nguồn đúng nhất cho định nghĩa hàm hiện tại); `web` = `apps/web/src`.

---

## 1. Executive summary

1. **[F]** Cả 8 RPC đầu mối đều có thật, đều `SECURITY DEFINER` + `search_path ''`, và đều tự kiểm tra quyền theo chi nhánh ở server. Tên đúng là `report_overview`, `report_revenue_series`, `report_top_items`, `stock_alert_counts`, `shop_order_badge`, `spa_day_board`, `boarding_board`, `medical_queue`. Có thêm `list_shop_orders` trả sẵn `counts` theo trạng thái, và `medical_reminders`.
2. **[F]** Mô hình phạm vi: **không có tenant**, **không có bảng store/shop**. Chỉ có `branches` (chi nhánh). Quyền theo `(user, branch, role)` trong `staff_branches`. Tài khoản loại `admin`/`superAdmin` vượt qua mọi kiểm tra chi nhánh.
3. **[F]** Đã có một "bộ chọn chi nhánh toàn cục" thực tế: `useCurrentBranch()` (localStorage `admin.branchId`) dùng ở 17 màn hình nghiệp vụ qua `BranchPicker`. Báo cáo doanh thu dùng một cơ chế khác (URL query + danh sách chi nhánh lọc theo quyền + "Tất cả chi nhánh"). Hai cơ chế này cần được gộp thành một **scope** dùng chung, không viết cái thứ ba.
4. **[F]** Chỉ nhóm RPC `report_*` hỗ trợ "tất cả chi nhánh được phép" (`p_branch = null` → `report_branch_ids` mở rộng thành danh sách cụ thể). Các RPC vận hành (tồn kho, spa, khách sạn, khám) chỉ nhận **một** chi nhánh.
5. Phát hiện quan trọng nhất:
   - **P0 [F]** Cache TanStack Query không bị xóa khi đăng xuất, query key không chứa user. Trên máy dùng chung, người đăng nhập sau có thể thấy số liệu của người trước trong tối đa ~5 phút (mục 7, R1).
   - **P0 [F]** Doanh thu đơn online được ghi vào **ngày đóng gói** (ngày tạo hóa đơn), nhưng chỉ được tính khi đã giao xong. Số của ngày cũ thay đổi về sau; dashboard "hôm nay" không thấy tiền COD thu hôm nay (R2). Cần PO chốt định nghĩa.
   - **P0 (phòng ngừa) [F]** `has_permission(..., p_branch = null)` nghĩa là "ở bất kỳ chi nhánh nào". Nếu RPC "tất cả chi nhánh" mới dùng `null` theo kiểu này sẽ lộ dữ liệu (R3).
   - **P1 [F]** Frontend dùng quyền **hợp nhất mọi chi nhánh** (`auth.can`) để quyết định hiện widget của **chi nhánh đang chọn** (R4).
6. **Quyết định [R]**: dashboard định nghĩa bằng code, tổ chức **theo mục đích nghiệp vụ**, quyền tính ở **cấp widget theo chi nhánh**. Bắt đầu với **2 dashboard**: "Hôm nay" (vận hành, mặc định cho mọi nhân viên) và "Kinh doanh" (doanh thu + bán hàng, cần `reports`). Spa và Thú y **không** thành dashboard riêng vì đã có màn hình nghiệp vụ chuyên dụng (`spa_day_board`, `medical_queue`). Phase 1 tái dùng RPC sẵn có, **không** thêm bảng, migration, cache layer hay RPC tổng hợp. Sửa P0 trước khi làm UI.

---

## 2. Kiến trúc Dashboard hiện tại và điểm tái sử dụng

### 2.1 Hiện trạng

| Thành phần | Bằng chứng | Ghi chú |
| --- | --- | --- |
| Route | `web/pages/admin/index.vue` (name `dashboard`) → `features/admin/dashboard/DashboardView.vue` **[F]** | Không có trong `ADMIN_ROUTE_PERMISSIONS` nên mọi staff vào được (`packages/core/src/auth/access.ts`) |
| Thẻ doanh thu | `TodaySalesCard.vue` + `useTodaySales.ts` → `useReportOverview` **[F]** | Ẩn khi lỗi (`!query.isError`) |
| Thẻ khách sạn | `BoardingTodayCard.vue` → `useBoardingBoard(branch, todayKey())` **[F]** | Không có nhánh lỗi |
| Thẻ khám | `MedicalTodayCard.vue` → `useMedicalQueue` + `useMedicalReminders(scope overdue)` **[F]** | Không có nhánh lỗi |
| Lối tắt | `ADMIN_NAV_SECTIONS` lọc bằng `canOpenAdminRoute` **[F]** | Trùng sidebar |
| Chart | `features/admin/reports/shared/StackedBarChart.vue` (SVG tự vẽ), không có thư viện chart **[F]** | |
| Cache | `web/lib/query-client.ts`: `staleTime 30s`, `refetchOnWindowFocus false`, `retry 1`; `gcTime` để mặc định của TanStack (5 phút) **[F]** | |
| Realtime | Không có `.channel(` nào trong `web` và `packages/supabase` **[F]** | Chỉ polling |

### 2.2 Tái sử dụng

| Tài nguyên | Phân loại | Bằng chứng / việc cần làm |
| --- | --- | --- |
| Hook dữ liệu: `useReportOverview`, `useRevenueSeries`, `useTopItems` | Dùng ngay (overview đã export); series/top cần export | `features/admin/reports/queries/reports.ts`, `reports/index.ts` **[F]** |
| `useBoardingBoard`, `useMedicalQueue`, `useMedicalReminders` | Dùng ngay | đã export ở `boarding/index.ts`, `medical/index.ts` **[F]** |
| `useDayBoard` (spa), `useStockAlertCounts`, `useShopOrderBadge`, `useShopOrderList` | Cần export | `schedule/index.ts`, `inventory/index.ts` chưa export; `shop-orders` **chưa có** `index.ts` (rule `feature-via-index` trong `apps/web/.dependency-cruiser.cjs`) **[F]** |
| `useCurrentBranch` + `BranchPicker` | Tái dùng làm nền cho scope toàn cục, cần mở rộng | `web/composables/useCurrentBranch.ts`, `features/admin/pos/components/BranchPicker.vue` **[F]** |
| `useReportBranches` + `ReportBranchPicker` (có "Tất cả chi nhánh") | Gộp vào scope chung | `features/admin/reports/shared/*` **[F]** |
| `KpiCard`, `StackedBarChart`, `chartScale`, `format`, `dateRange` | Chuyển ra `components/common` để hai feature dùng chung | đang private trong `reports/shared` **[F]** |
| `Skeleton`, `TableStateRows` | Dùng ngay | `web/components/ui/skeleton`, `web/components/common/TableStateRows.vue` **[F]** |
| `Notification.vue` (chuông header) | Viết lại | số thông báo hard-code `ref<number>(4)` dòng 55 **[F]** |

---

## 3. Mô hình tenant / store / branch và quyền truy cập

### 3.1 Schema

| Khái niệm | Có không | Bằng chứng |
| --- | --- | --- |
| Tenant | **Không**. Một DB cho một doanh nghiệp | không có bảng/cột `tenant` trong `S` **[F]** |
| Store / Shop | **Không** có bảng riêng. "Shop" là kênh bán online (`shop_orders`, `shop_settings`) | `S` **[F]** |
| Branch | `branches(id, code, name, address, phone, is_active)` | `S` dòng ~14336 **[F]** |
| Gán nhân viên | `staff_branches(user_id, branch_id, role, does_services)` | `S` dòng ~15413 **[F]** |
| Chi nhánh bán online | `shop_settings.online_branch_id` (chỉ **một**) | `shop_order_badge`, `list_shop_orders` **[F]** |
| Dữ liệu dùng chung chuỗi | khách hàng, thú cưng, catalog (không có `branch_id`) | quyết định thiết kế trong memory dự án; `medical_reminders` không lọc chi nhánh cho vaccine **[F]** |
| Dữ liệu theo chi nhánh | `invoices`, `sales_returns`, `stock_lots`, `appointments`, `boarding_stays`, `medical_visits`, `cash_shifts`, `shop_orders` (cột `branch_id`) | `S` **[F]** |

**Kết luận [F]**: trong repo này "store" = "branch". Không có cấp nào ở trên.

### 3.2 Quyền

| Lớp | Cơ chế | Bằng chứng |
| --- | --- | --- |
| Loại tài khoản | JWT claim `user_role`; `is_admin()` = admin/superAdmin, `is_super_admin()` | `S` `is_admin` (~5437), `is_super_admin` **[F]** |
| Quyền theo chi nhánh | `has_permission(perm, method, branch)`: superAdmin luôn đúng; còn lại cần dòng `staff_branches` + `role_permissions`. **`p_branch is null` nghĩa là "bất kỳ chi nhánh nào"** | `S:4256-4268` **[F]** |
| Hàm bọc theo module | `can_report`, `can_inventory`, `can_schedule`, `can_boarding`, `can_medical`, `can_shop_orders`, `can_pos` = `is_admin() OR has_permission(...)` | ví dụ `can_inventory` `S:1863` **[F]** |
| Danh sách chi nhánh | Bảng `branches` có policy `public read` cho `anon`, `authenticated` | `S:18832` **[F]**. Danh sách chi nhánh không nhạy cảm **[I]** |
| Quyền của tôi | `my_permissions(p_branch)` trả từng dòng `(branch_id, role, permission, methods)` | `S:7555` **[F]** |
| Frontend | `listMyPermissions` **gộp** mọi chi nhánh thành `Record<perm, methods[]>`; `auth.can(perm)` dựa trên bản gộp; admin không có vai trò chi nhánh → `"all"` | `packages/supabase/src/users/permissions.ts:74`, `web/stores/modules/auth-parts/adminGrants.ts` **[F]** |

### 3.3 Trả lời 9 câu hỏi về phạm vi

| # | Câu hỏi | Trả lời |
| --- | --- | --- |
| 1 | Quan hệ tenant/store/branch | Chỉ có branch (3.1) **[F]** |
| 2 | Nguồn danh sách | `listBranches()` đọc `branches` với `is_active = true`, sắp theo `code` (`packages/supabase/src/users/branches.ts:16`) **[F]** |
| 3 | Chi nhánh hiện tại | `useCurrentBranch()`: localStorage `admin.branchId`, mặc định chi nhánh đầu tiên (`web/composables/useCurrentBranch.ts`) **[F]** |
| 4 | Quyền từng chi nhánh | Server: `has_permission` theo `branch_id` **[F]**. Frontend: chỉ có bản gộp **[F]** |
| 5 | Màn hình dùng phạm vi | 17 màn hình gọi `BranchPicker` + `useCurrentBranch`: tồn kho, phiếu kho, khách sạn (4), spa (3), khám (5), POS, hóa đơn, ca **[F]**. Báo cáo dùng `useReportFilters` (URL) **[F]** |
| 6 | Tái dùng selector | Có. `useCurrentBranch` đã là state toàn cục, giữ khi chuyển trang **[F]**. Thiếu: lọc theo quyền, lựa chọn "Tất cả" |
| 7 | Chỉ có quyền 1 chi nhánh | `BranchPicker` ẩn select khi chỉ có 1 lựa chọn **[F]**. **Nhưng** danh sách lấy từ *mọi chi nhánh active*, không lọc theo quyền **[F]** → nhân viên 1 chi nhánh vẫn thấy chi nhánh khác khi có ≥2 chi nhánh |
| 8 | Không có quyền chi nhánh nào | `adminGrants = {}` → không mở được trang có quyền; dashboard vẫn mở được (không gắn quyền) **[F]**. Báo cáo có trạng thái `reports.noBranch` **[F]**. Dashboard chưa có trạng thái tương tự **[F]** |
| 9 | Giữ phạm vi khi điều hướng | Có, vì 17 màn hình cùng đọc `admin.branchId` **[F]**. Báo cáo đọc `?branch=`, nếu thiếu thì lấy chi nhánh hiện tại (`useReportFilters.ts`) **[F]**. Bộ lọc khác (vd. "sắp hết hạn") **không** truyền qua URL được: màn hình tồn kho, đơn online không đọc `route.query` **[F]** |

---

## 4. Danh sách dashboard tối thiểu

### 4.1 Đánh giá 5 ứng viên

| Ứng viên | Mục tiêu riêng có rõ không | Trùng với | Kết luận |
| --- | --- | --- | --- |
| A. Tổng quan kinh doanh | Có (chủ xem sức khỏe kinh doanh) | C gần như toàn bộ: doanh thu, xu hướng, số đơn, top sản phẩm | **Gộp A + C** |
| B. Vận hành cửa hàng | Có (việc phải làm hôm nay) | Phần "việc cần xử lý" của A | **Giữ**, làm mặc định |
| C. Bán hàng & doanh thu | Có nhưng trùng A | A | **Gộp vào A** thành "Kinh doanh" |
| D. Spa & chăm sóc | Trùng màn hình `spaBoard` đã có (`spa_day_board`, tự làm mới 30s) | Bảng spa | **Không làm** dashboard; đặt widget "Spa hôm nay" trong B, bấm vào mở bảng spa |
| E. Thú y & khám bệnh | Trùng `medicalQueue`, `medicalReminders`, `medicalWard` | Hàng đợi khám | **Không làm**; widget "Khám hôm nay" trong B |

**[I]** D và E chỉ đáng thành dashboard khi có nhân viên chỉ làm spa/khám và muốn một màn tổng hợp nhiều hơn bảng nghiệp vụ. Hiện chưa có bằng chứng về nhu cầu này. Với kiến trúc đề xuất, thêm sau chỉ tốn một khai báo + widget mới.

### 4.2 Hai dashboard đề xuất

| Dashboard | Key | Mục đích | Ai thấy | Phạm vi hỗ trợ | Widget |
| --- | --- | --- | --- | --- | --- |
| **Hôm nay** | `today` | Việc phải xử lý và tình hình trong ngày tại một chi nhánh | Mọi staff có ít nhất 1 widget nhìn được | **Một chi nhánh** (vận hành gắn với chi nhánh) | Việc cần xử lý, Doanh thu hôm nay (nếu có `reports`), Spa hôm nay, Khách sạn hôm nay, Khám hôm nay |
| **Kinh doanh** | `business` | Doanh thu, xu hướng, đơn, mặt hàng bán chạy | Có `reports: VIEW` ở ít nhất 1 chi nhánh | **Một chi nhánh hoặc Tất cả chi nhánh được phép** | KPI doanh thu (kỳ chọn, so kỳ trước), Xu hướng 7/30 ngày, Cơ cấu theo mảng, Top 5 sản phẩm, Đơn online theo trạng thái |

### 4.3 Trục tổ chức

| Phương án | Ưu | Nhược |
| --- | --- | --- |
| Theo vai trò (Dashboard thu ngân, groomer, bác sĩ...) | Quen thuộc | Vai trò ở repo là dữ liệu cấu hình (`roles`, tạo thêm được như `vet`, `inventory`), gắn dashboard vào tên vai trò = gắn quyền vào tên dashboard; người nhiều vai trò thấy dashboard trùng nội dung **[I]** |
| Theo nghiệp vụ / mục đích | Ít dashboard, không trùng, quyền tách khỏi tên | Người dùng có thể thấy dashboard thiếu vài widget |

**Chọn [R]**: theo **mục đích**, quyền quyết định ở **widget**. Dashboard chỉ hiện trong danh sách khi người dùng xem được ít nhất một widget của nó ở phạm vi hiện tại (hoặc khi có quyền bắt buộc, như `reports` cho "Kinh doanh").

Phân biệt khái niệm (áp vào đề xuất):

| Khái niệm | Phase 1 |
| --- | --- |
| Dashboard hệ thống định nghĩa sẵn | Có: mảng `DASHBOARDS` trong code |
| Dashboard hiển thị theo quyền | Có: lọc theo widget nhìn được |
| Dashboard mặc định của người dùng | Có ở mức nhẹ: nhớ lựa chọn cuối trên thiết bị (localStorage), mặc định `today` |
| Dashboard cá nhân hóa (ẩn/sắp xếp widget) | Later |
| Dashboard Builder | Later |

---

## 5. Mapping Dashboard × Widget × Data Source

Chuỗi: Dashboard → Widget → Component (đề xuất) → Hook → RPC → Bảng/trường → Quy tắc → Quyền.

| Dashboard | Widget | Component | Hook (có sẵn) | RPC | Bảng nguồn | Quyền server |
| --- | --- | --- | --- | --- | --- | --- |
| today, business | W1 Doanh thu (hôm nay / kỳ) | `SalesKpiWidget` | `useReportOverview` | `report_overview` → `report_overview_core` → `report_sales_lines` | `invoices`, `payments`, `sales_returns`, `invoice_lines`, `appointment_items`, `medical_visit_items`, `stock_movements` | `report_branch_ids` → `can_report('VIEW')` |
| business | W2 Xu hướng 7/30 ngày | `RevenueTrendWidget` | `useRevenueSeries` | `report_revenue_series` | như W1 | như W1 |
| today, business | W3 Việc cần xử lý | `ActionItemsWidget` | `useShopOrderBadge`, `useStockAlertCounts`, `useMedicalReminders`, `useBoardingBoard` | `shop_order_badge`, `stock_alert_counts`, `medical_reminders`, `boarding_board` | `shop_orders`, `stock_lots`+`products`+`stock_thresholds`, `vaccinations`, `boarding_stays` | `can_shop_orders`, `can_inventory`, `can_medical`, `can_boarding` (từng dòng) |
| business | W3b Đơn online theo trạng thái | `OnlineOrdersWidget` | `useShopOrderList` (page size 1, đọc `counts`) | `list_shop_orders` | `shop_orders` | `can_shop_orders` |
| today | W4 Cảnh báo tồn kho (nằm trong W3 hoặc tách) | trong `ActionItemsWidget` | `useStockAlertCounts` | `stock_alert_counts` → `stock_rows` | `stock_lots`, `products`, `stock_thresholds` | `can_inventory('VIEW', branch)` |
| today | W5 Spa hôm nay | `SpaTodayWidget` | `useDayBoard` | `spa_day_board` | `appointments`, `appointment_items`, `staff_branches`, `spa_resources` | `can_schedule('VIEW', branch)` |
| today | W6 Khách sạn hôm nay | `BoardingTodayWidget` | `useBoardingBoard` | `boarding_board` | `kennels`, `boarding_stays`, `boarding_stay_pets` | `can_boarding('VIEW', branch)` |
| today | W7 Khám hôm nay | `MedicalTodayWidget` | `useMedicalQueue`, `useMedicalReminders` | `medical_queue`, `medical_reminders` | `medical_visits`, `vaccinations` | `can_medical('VIEW', branch)` |
| business | W8 Top 5 sản phẩm | `TopItemsWidget` | `useTopItems` | `report_top_items(kind='product')` | như W1 + `sales_return_lines` | như W1 |

---

## 6. Data Contract cho từng widget

Quy ước trạng thái chung cho mọi widget **[R]**:

| Trạng thái | Điều kiện | Hiển thị |
| --- | --- | --- |
| `hidden` | Không có quyền module **tại chi nhánh đang chọn** (không gọi RPC) | Không render widget |
| `needsBranch` | Phạm vi = Tất cả nhưng RPC chỉ nhận một chi nhánh | "Chọn một chi nhánh để xem" |
| `loading` | Lần tải đầu (chưa có data cho key hiện tại) | Skeleton đúng kích thước |
| `forbidden` | RPC trả 42501 | "Bạn không có quyền xem mục này ở chi nhánh X" |
| `error` | Lỗi khác | Thông báo + nút Thử lại; widget khác không bị ảnh hưởng |
| `empty` | Có data nhưng không có gì để xem (vd. 0 lịch spa) | Câu hướng dẫn + link |
| `ready` | | Số liệu |

`0` là giá trị thật và hiện là "0"; `null` chỉ xuất hiện ở các trường được ghi rõ bên dưới và hiện là "—". **[F]** Mapper hiện tại biến mọi giá trị thiếu thành `0` (`num()` trong `packages/supabase/src/reports/parse.ts`), nên ở báo cáo hiện tại "không có dữ liệu" và "0" trông giống nhau.

### W1 Doanh thu (hôm nay hoặc kỳ chọn)

| Mục | Nội dung |
| --- | --- |
| 1. Định nghĩa | Doanh thu thuần của các hóa đơn đã thanh toán trong kỳ, trừ tiền hoàn của phiếu trả hàng trong kỳ **[F]** |
| 2. Công thức | `net_revenue = Σ invoices.total (status='paid', created_at ∈ kỳ) − Σ sales_returns.refund_amount (created_at ∈ kỳ)`; `invoice_count = count(paid)`; `avg_ticket = net_sales / invoice_count` (0 nếu không có HĐ); mảng `shop/spa/boarding/medical` = Σ `line_net` theo `segment` của `report_sales_lines`, với `line_net = amount × total / subtotal` (chia giảm giá HĐ theo tỉ lệ) **[F]** `S:9292-9388`, `S:9495-9535` |
| 3. Trạng thái | Gồm `paid`. Loại `unpaid` (HĐ online chưa giao) và `cancelled`. Hủy đếm riêng theo `cancelled_at` (`cancelled_count`, `cancelled_amount`) **[F]** |
| 4. Thời điểm ghi nhận | `invoices.created_at`. Với POS = lúc bán. Với online = **lúc đóng gói** (`pack_shop_order` → `issue_shop_order_invoice` tạo HĐ `unpaid`), và chỉ được đếm khi `deliver_shop_order`/`pay_pickup_shop_order` đổi sang `paid` mà **không** đổi `created_at` **[F]** (xem R2) |
| 5. Múi giờ | `report_range`: `[from 00:00, to+1 00:00)` giờ `Asia/Ho_Chi_Minh`, tối đa 366 ngày **[F]** `S:9390`. Client lấy "hôm nay" bằng `todayInVietnam()` **[F]** |
| 6. Đơn vị/kiểu | VND, số nguyên (đã `round`), không null (RPC `coalesce` về 0) **[F]** |
| 7. Phạm vi | Một chi nhánh, hoặc `null` = mọi chi nhánh người gọi được `can_report` (danh sách cụ thể, không dùng `has_permission(null)`) **[F]** `S:9223`. Cộng nhiều chi nhánh: các trường tổng cộng được; `avg_ticket` được tính lại trên tổng, đúng **[F]** |
| 8. Rỗng | `invoice_count = 0` → `empty` ("Chưa có hóa đơn hôm nay"), vẫn hiện 0đ |
| 9. 0/null/... | Không có null. Phân biệt bằng trạng thái query |
| 10. Cache | Key `['reports','overview',{branchId,from,to}]` **[F]**; stale 30s; bị invalidate khi bán/hủy/trả ở POS (`invalidatePos` trong `features/admin/pos/queries/pos.ts`) **[F]**; **không** bị invalidate khi đơn online đổi trạng thái (`useOrderStep` chỉ invalidate `shopKeys`) **[F]**. Đề xuất làm mới 5 phút khi đang mở |
| 11. Đổi dashboard/chi nhánh | Key đổi theo chi nhánh; dùng `placeholderData: keepPreviousData` (có sẵn) sẽ hiện số chi nhánh **cũ** trong lúc tải chi nhánh mới **[F]** → widget phải làm mờ + ghi rõ "đang tải chi nhánh X" khi `isPlaceholderData` (R8) |
| 12. Đích | `reportsOverview` với `?branch=<id|all>&preset=today` (route đã đọc các query này) **[F]** |

### W2 Xu hướng doanh thu 7/30 ngày

| Mục | Nội dung |
| --- | --- |
| 1–3 | Như W1 nhưng theo từng ngày; mỗi ngày đều có dòng (sinh bằng `generate_series`) **[F]** `S:9412-9485` |
| Khác W1 | Làm tròn **từng ngày** rồi cộng → tổng chuỗi có thể lệch vài đồng so với `report_overview` **[F]**; cột phương thức thanh toán **không có `cod`** (overview có) **[F]** |
| 5 | Khoảng `[today−6, today]` hoặc `[today−29, today]` giờ VN |
| 7 | Như W1 |
| 8 | Toàn bộ ngày = 0 → `empty` |
| 10 | Key `['reports','series',filter,'day']`; không poll |
| 12 | `reportsOverview?preset=last7` (preset có sẵn) hoặc `custom` cho 30 ngày |

### W3 Việc cần xử lý

Mỗi dòng là một nguồn độc lập, có quyền riêng, lỗi riêng.

| Dòng | RPC | Định nghĩa đang có trong code | Quyền | Đích |
| --- | --- | --- | --- | --- |
| Đơn online chờ xác nhận | `shop_order_badge(null)` | `count(shop_orders where status='pending' and branch_id = online_branch_id)`; trả **0** nếu không có quyền (không báo lỗi) **[F]** `S:12700` | `can_shop_orders('VIEW', online_branch)` | `shopOrders` |
| Tồn dưới mức tối thiểu | `stock_alert_counts` | sản phẩm `track_stock` có `min_qty` và `sellable < min_qty` **[F]** | `can_inventory` | `inventoryStock` |
| Hết hàng | như trên | `sellable = 0`, **gồm cả sản phẩm active chưa từng nhập kho** (`stock_rows` left join lô) **[F]** `S:13641` → R6 | | |
| Lô sắp hết hạn | như trên | sản phẩm có lô `expiry_date ∈ [today, today + N)`, N mặc định 60 **[F]** | | |
| Lô đã hết hạn còn tồn | như trên | lô `expiry_date < today` và `qty_on_hand > 0` **[F]** | | |
| Vaccine quá hạn | `medical_reminders(scope='overdue', page_size=1).total` | mũi gần nhất của mỗi (thú, loại vaccine) có `next_due_on < today`, thú `active`, có chủ chính; **không lọc chi nhánh** **[F]** `S:6791+` → R7 | `can_medical` tại chi nhánh truyền vào | `medicalReminders` |
| Khách sạn quá giờ trả | `boarding_board.counts.overdue` | số **chuồng** ở trạng thái `overdue` **[F]** `S:1222` | `can_boarding` | `boardingBoard` |

- Thời điểm: hiện tại; "today" = `business_date()` ở server **[F]**.
- Phạm vi: **một chi nhánh** (trừ đơn online luôn là chi nhánh bán online). Ở phạm vi "Tất cả": `needsBranch`.
- Cache: badge 60s (có sẵn), tồn kho stale 30s, khám 30s, khách sạn 60s **[F]**.
- Rỗng: mọi dòng = 0 → "Không có việc gì cần xử lý".

### W4 Cảnh báo tồn kho

Xem các dòng tồn kho trong W3. Có thể tách thành widget riêng ở dashboard "Hôm nay" nếu PO muốn thấy 4 con số cạnh nhau. Tham số N ngày lấy từ cùng mặc định với màn tồn kho để số khớp nhau **[R]**.

### W5 Lịch spa hôm nay

| Mục | Nội dung |
| --- | --- |
| Định nghĩa | Các dịch vụ (`appointment_items`) có lịch trong ngày tại chi nhánh **[F]** |
| Công thức (client từ dữ liệu RPC) | Đếm item theo `status`: `waiting`, `in_progress`, `done`, `cancelled` **[F]** (constraint `appointment_items_status_check`); 3 item kế tiếp có `start_at ≥ now` và chưa `done/cancelled` |
| Lưu ý | Đây là **đếm** từ dữ liệu đã trả về, không phải công thức nghiệp vụ mới **[I]**; nên đặt trong hàm thuần có test |
| Thời gian | `[date 00:00, date+1 00:00)` giờ VN trong RPC **[F]** |
| Null | `staff_id`, `resource_id` có thể null (chưa phân công) **[F]** |
| Phạm vi | Một chi nhánh, `can_schedule` |
| Cache | Key của `useDayBoard`, tự làm mới 30s (`features/admin/schedule/queries/spa.ts:186-192`) **[F]**, dùng chung với bảng spa |
| Rỗng | `is_closed = true` → "Hôm nay nghỉ"; 0 item → "Chưa có lịch" |
| Đích | `spaBoard` |

### W6 Hoạt động khách sạn

| Mục | Nội dung |
| --- | --- |
| Định nghĩa | Tình trạng chuồng trong ngày **[F]** |
| Công thức | `counts` do RPC tính trên **chuồng**: `arriving` (chuồng có thú sắp đến), `departing`, `occupied` (= occupied + departing + overdue), `overdue`, `free`, `inpatient` **[F]** `S:1215-1232` |
| Đơn vị | **Chuồng**, không phải số thú hay số lượt lưu trú. Nhãn phải ghi đúng (R9) |
| Phạm vi | Một chi nhánh, `can_boarding` |
| Cache | Làm mới 60s + khi focus (`features/admin/boarding/queries/stays.ts:104-112`) **[F]** |
| Đích | `boardingBoard` |

### W7 Hàng đợi khám

| Mục | Nội dung |
| --- | --- |
| Định nghĩa | Lượt khám của ngày tại chi nhánh **[F]** |
| Công thức | `counts` = `scheduled`, `waiting`, `in_progress`, `done` (đã khám, chưa thu tiền; `paid` là bước sau) **[F]** `S:6758-6766`, constraint `medical_visits_status_check` |
| Quy tắc | Khi xem **hôm nay**, lượt `waiting/in_progress` của những ngày trước (chưa xong) cũng được đưa vào **[F]** `S:6736-6738` |
| Vaccine quá hạn | Như W3 (toàn chuỗi) |
| Phạm vi | Một chi nhánh, `can_medical` |
| Cache | Làm mới 30s (`medicalVisits.ts:30-37`) **[F]** |
| Đích | `medicalQueue` |

### W8 Top sản phẩm

| Mục | Nội dung |
| --- | --- |
| Định nghĩa | Sản phẩm (hàng hóa) có doanh thu thuần cao nhất kỳ **[F]** |
| Công thức | Theo `report_top_items`: gom `report_sales_lines` theo `(item_type, id)`; `net_revenue` = Σ `line_net`; trả hàng trừ riêng theo ngày trả; `share` = phần trăm trên **tổng mọi dòng** (cả dịch vụ, lưu trú) **[F]** `S:9731+` |
| Bắt buộc | Gọi với `p_kind='product'`. Với `'all'`, các dòng lưu trú có `product_id/service_id/combo_id` đều null nên bị gom thành **một** dòng chung **[F]** |
| Phân trang | `p_limit = 5` |
| Đích | `reportsItems` với cùng kỳ |

---

## 7. Sai lệch và rủi ro có bằng chứng

| ID | Mức | Phát hiện | Bằng chứng | Tác động | Cách xác minh |
| --- | --- | --- | --- | --- | --- |
| R1 | **P0** | Cache dữ liệu không gắn người dùng và không bị xóa khi đăng xuất | `signoutHdl` (`web/stores/modules/auth.ts:220-231`) chỉ `signOut`, `applySession(null)`, `removeStorage([])` (xóa localStorage), rồi `router.push("/")` (điều hướng client, không reload); không có `queryClient.clear()` ở đâu trong `web`; query key như `reportKeys.overview(filter)`, `medicalKeys.queue(branch, date)` không có user id **[F]**. TanStack mặc định giữ cache không dùng 5 phút và hiện ngay dữ liệu cũ khi mount lại rồi mới tải lại **[F, hành vi mặc định của thư viện]** | Máy quầy dùng chung: người B đăng nhập sau người A trong vòng 5 phút, mở dashboard, thấy số của A cho tới khi query chạy lại; nếu lần chạy lại lỗi 42501, TanStack vẫn giữ `data` cũ, và thẻ khách sạn/khám hiện tại vẫn render `counts` cũ **[I]** | Test e2e: đăng nhập admin, mở dashboard, đăng xuất, đăng nhập tài khoản thiếu quyền `medical`, mở dashboard trong 5 phút |
| R2 | **P0** (cần PO) | Doanh thu online ghi theo ngày đóng gói, chỉ đếm sau khi giao | `issue_shop_order_invoice` tạo HĐ `channel='online'`, `status='unpaid'` lúc `pack_shop_order`; `deliver_shop_order` đổi `status='paid'` + ghi payment `cod`, không đổi `created_at`; mọi RPC báo cáo lọc `status='paid'` + `created_at` **[F]** `S` các hàm tương ứng | (a) số của ngày đã qua tăng lên về sau khi đơn được giao; (b) dashboard hôm nay không thấy tiền COD thu hôm nay; (c) đối soát tiền mặt theo ngày lệch với doanh thu **[I]** | pgTAP: đóng gói ngày D, giao ngày D+1, gọi `report_overview(D)` trước/sau khi giao |
| R2b | P1 | "Hủy" trộn hai loại | `return_shop_order` hủy HĐ online **chưa từng thu tiền** → được đếm vào `cancelled_count/amount` cùng với HĐ POS đã thu rồi hủy **[F]** | Chỉ số hủy phóng đại khi có đơn bị hoàn **[I]** | pgTAP cùng kịch bản |
| R3 | **P0** (phòng ngừa) | `has_permission(..., null)` = "ở bất kỳ chi nhánh nào" | `S:4265` `(p_branch is null or sb.branch_id = p_branch)` **[F]**. RPC `report_*` an toàn vì mở rộng thành danh sách cụ thể (`report_branch_ids`) **[F]**. Các RPC vận hành gọi với `null` thì qua được kiểm tra nhưng lọc `branch_id = null` nên trả rỗng **[F]** (vd. `stock_alert_counts` → `stock_rows`) | Nếu RPC "tất cả chi nhánh" mới viết `if can_xxx('VIEW', p_branch)` rồi `where p_branch is null or branch_id = p_branch`, nhân viên có quyền ở **một** chi nhánh sẽ thấy **mọi** chi nhánh **[I]** | Quy tắc review + pgTAP cho mọi RPC nhận `p_branch null` |
| R4 | P1 | Widget dùng quyền gộp mọi chi nhánh cho chi nhánh đang chọn | `BoardingTodayCard`, `MedicalTodayCard` dùng `auth.can("boarding"/"medical")` (gộp, `adminGrants.ts:50`) rồi gọi RPC với `useCurrentBranch().branchId` **[F]** | Server từ chối (42501) → thẻ kẹt "Đang tải" vì không có nhánh lỗi **[F]**; kết hợp R1 có thể hiện dữ liệu cũ **[I]**. Hiện chỉ xảy ra khi có ≥2 chi nhánh | Tạo nhân viên có `medical` ở chi nhánh A, chọn chi nhánh B |
| R5 | P1 | Danh sách chi nhánh của selector không lọc theo quyền | `useCurrentBranch` dùng `listBranches()` (mọi chi nhánh active) **[F]** | Nhân viên chọn được chi nhánh mình không làm, mọi màn hình báo lỗi quyền. Không lộ dữ liệu vì server chặn **[I]** | Như R4 |
| R6 | P1 (cần PO) | "Hết hàng" gồm sản phẩm chưa từng nhập kho | `stock_rows`: `from products p left join lots ... where p.track_stock and (p.is_active or ...)`; `stock_alert_counts.out = count(sellable = 0)` **[F]** | Catalog mới nhập nhiều sản phẩm (memory: có file mẫu Paddy) làm số "hết hàng" rất lớn, mất giá trị cảnh báo **[I]** | Đếm sản phẩm `track_stock` không có lô nào |
| R7 | P1 | Vaccine quá hạn là số **toàn chuỗi**, không theo chi nhánh | `medical_reminders`: nhánh vaccine không có điều kiện `branch_id`, chỉ nhánh `recheck` có **[F]** | Mỗi chi nhánh thấy cùng một số; cộng các chi nhánh ở phạm vi "Tất cả" sẽ nhân đôi **[I]** | So sánh `total` của hai chi nhánh |
| R8 | P1 | Đổi chi nhánh có thể hiện số của chi nhánh cũ | `useReportOverview`, `useRevenueSeries` dùng `placeholderData: keepPreviousData` **[F]** | Trong lúc tải, KPI là của chi nhánh trước nhưng tiêu đề đã đổi **[I]** | Đổi chi nhánh với mạng chậm |
| R9 | P2 | Đơn vị của số khách sạn là "chuồng" | `boarding_board.counts` đếm trên phần tử `kennels` **[F]** | Hiểu nhầm là số thú/lượt **[I]** | Đặt 2 thú cùng chuồng |
| R10 | P1 | Logic nghiệp vụ ở frontend | `TodaySalesCard.vue`: "Shop" = `segments.shop − refunds` **[F]**; `refunds` là mọi phiếu trả (gồm hàng bán trong khám) | Con số "Shop" không có trong báo cáo, không đối chiếu được **[I]** | So sánh với tab Tổng quan |
| R11 | P2 | Thẻ doanh thu thiếu khách sạn và khám | RPC trả đủ 4 mảng, thẻ chỉ hiện 2 **[F]** | Chủ không thấy đủ | |
| R12 | P2 | "Hôm nay" bị đóng băng sau nửa đêm | `useBoardingBoard(branch, todayKey())` truyền chuỗi cố định lúc mount; `useTodaySales` gọi `todayInVietnam()` trong `computed` không có dependency thời gian **[F]** | Máy quầy để mở qua đêm vẫn xem ngày hôm qua **[I]** | Mở dashboard 23:59, chờ qua 00:00 |
| R13 | P2 | Đổi trạng thái đơn online không làm mới báo cáo và tồn kho | `useOrderStep.onSuccess` chỉ invalidate `shopKeys` **[F]**; đóng gói trừ kho, giao làm HĐ thành `paid` | Số trên dashboard trễ tới khi stale (30s) và mount lại | |
| R14 | P2 | Hai hàm "hôm nay" | `todayInVietnam` (reports) và `todayKey` (schedule), cùng múi giờ VN **[F]** | Không sai, nhưng dễ lệch khi sửa một chỗ | |
| R15 | P1 | Chưa có test nào cho RPC báo cáo | không có `report_` trong `supabase/tests/*.sql` và `apps/web/tests/db/*.ts` **[F]** | Không có lưới an toàn khi sửa R2 hay thêm phạm vi | |
| R16 | P2 | Chuông thông báo hiện số giả | `components/common/Notification.vue:55` **[F]** | Gây hiểu nhầm | |
| R17 | — (đã đúng) | Không có N+1 | Mỗi widget là một RPC tập hợp; `report_overview` gọi phần lõi 2 lần (kỳ này + kỳ trước) **[F]** | | |

Không tìm thấy:

- **[F]** Hai RPC khác nhau tính cùng chỉ số doanh thu theo cách khác nhau. Overview, series, top, staff đều đi qua `report_sales_lines` + cùng điều kiện `paid`/`created_at`. Khác biệt duy nhất là làm tròn (W2) và thiếu cột `cod` (W2).
- **[F]** Tổng hợp nhiều chi nhánh sai ở `report_*`: điều kiện `branch_id = any(v_branches)`, cộng tổng rồi mới chia cho `avg_ticket`.

---

## 8. Global store selector và điều hướng

### Đề xuất S1: một `useAdminScope()` thay cho hai cơ chế (P1)

| Mục | Nội dung |
| --- | --- |
| Vấn đề | Hai cơ chế chọn chi nhánh (localStorage cho 17 màn, URL cho báo cáo); danh sách không lọc quyền (R5); không có "Tất cả" ngoài báo cáo |
| Bằng chứng | `useCurrentBranch.ts`, `useReportFilters.ts`, `useReportBranches.ts` **[F]** |
| Chọn | Mở rộng `useCurrentBranch` thành `useAdminScope()`: `scope = { kind: 'branch', id } \| { kind: 'all' }`; vẫn lưu ở `admin.branchId` (thêm giá trị `all`); `options` = chi nhánh có ít nhất một dòng `my_permissions` (admin: mọi chi nhánh active); `allowAll` chỉ khi ≥2 lựa chọn **và** trang hiện tại hỗ trợ. Giữ tên `useCurrentBranch()` làm lớp tương thích trả `branchId` (luôn là một chi nhánh) để 17 màn hình không phải sửa |
| Không chọn | (a) Store Pinia mới: trùng chức năng; (b) đưa chi nhánh vào URL ở mọi trang: phải sửa 17 màn, mất "nhớ chi nhánh làm việc" giữa các phiên; (c) giữ hai cơ chế: tiếp tục lệch nhau |
| Ảnh hưởng | `web/composables/useCurrentBranch.ts`, `BranchPicker`, `ReportBranchPicker`, `useReportFilters` |
| Rủi ro | Màn hình chỉ hỗ trợ một chi nhánh nhận `all` → phải luôn đọc qua lớp tương thích (khi scope là `all`, `branchId` = chi nhánh cuối cùng đã chọn) |
| Điều kiện | Làm sau R1 (dọn cache), trước khi có chi nhánh thứ hai |

Hành vi:

| Tình huống | Hành vi |
| --- | --- |
| Có 1 lựa chọn | Hiện nhãn chi nhánh, không có select (như `BranchPicker` hiện nay) |
| 0 lựa chọn | Dashboard hiện "Tài khoản chưa được gán chi nhánh nào, liên hệ quản trị"; không gọi RPC chi nhánh |
| Scope `all` ở dashboard "Kinh doanh" | Widget báo cáo gọi `p_branch = null` (server tự giới hạn); widget đơn online dùng chi nhánh bán online |
| Scope `all` ở dashboard "Hôm nay" | Không cho chọn `all` (dashboard khai báo `scopes: ['branch']`); nếu đang `all` thì dùng chi nhánh cuối cùng |
| Đổi chi nhánh | Widget hiện skeleton, không hiện số cũ (tắt `keepPreviousData` ở widget dashboard hoặc làm mờ khi `isPlaceholderData`) |
| Bấm widget | Màn đích đọc cùng `admin.branchId` nên tự giữ chi nhánh; với báo cáo truyền thêm `?branch=` |

### Đề xuất S2: chọn dashboard (P1)

- **[R]** State riêng: `?view=today|business` trên route `dashboard` (chia sẻ được link, Back hoạt động), mặc định lấy từ localStorage `admin.dashboard`, cuối cùng là `today`. Không gộp vào state chi nhánh.
- **[R]** Không nên đưa chi nhánh vào URL của dashboard ở Phase 1 (giữ đúng cơ chế 17 màn đang dùng); ngoại lệ là link sang báo cáo.
- **[R]** Bộ lọc chi tiết (vd. tồn kho "sắp hết hạn") qua URL là P2: cần các màn đích đọc `route.query` (hiện chỉ `products` và `reports` làm việc này **[F]**).

---

## 9. So sánh phương án dữ liệu và widget

| Tiêu chí | A. Dùng lại RPC sẵn có | B. Chuẩn hóa/hợp nhất RPC trùng | C. RPC tổng hợp cho từng dashboard | D. Lớp tổng hợp/cache riêng |
| --- | --- | --- | --- | --- |
| Độ phức tạp | Thấp | Trung bình | Trung bình | Cao (job đồng bộ, bảng mới) |
| Số request "Hôm nay" | ~6–8 song song | như A | 1 | 1 |
| Độ trễ | Tốt (RPC nhỏ, có index `invoices_branch_created_idx`, `appointment_items_branch_start_idx`, `stock_lots_fefo_idx` **[F]**) | như A | phụ thuộc phần chậm nhất | tốt nhất |
| Truy vấn trùng | Thấp, cùng key với màn nghiệp vụ nên dùng chung cache | | Không chia sẻ cache với màn nghiệp vụ | |
| Nhất quán số liệu | Cao: cùng RPC với màn nghiệp vụ | Cao | Rủi ro lặp công thức | Rủi ro lệch do đồng bộ trễ |
| Cô lập lỗi widget | Có | Có | Không (một lỗi hỏng cả gói, trừ khi tự bắt lỗi từng phần) | |
| Quyền | Đã có trong từng RPC | | Phải kiểm từng nguồn bên trong (R3) | Phải tái hiện quyền trên bảng tổng hợp |
| Kiểm thử | Test RPC sẵn có | | Test mới | Test mới + đồng bộ |
| Bảo trì | Thấp | | Thêm một nơi phải sửa khi đổi định nghĩa | Cao |
| Bằng chứng cần thiết | Không | **Không thấy RPC trùng logic** (mục 7) | Chưa có số đo chậm | Memory dự án: chỉ xem lại khi báo cáo 30 ngày > ~1s |

**Chọn A [R]**. B không cần vì không có trùng lặp. C chỉ cân nhắc cho W3 khi số nguồn cảnh báo > 5 hoặc đo thấy chậm. D: Later.

Widget:

| Phương án | Kết luận |
| --- | --- |
| Registry động (id chuỗi → component, nạp động, schema cấu hình) | Không. Chưa có cá nhân hóa hay cấu hình DB tham chiếu widget bằng id |
| Mảng định nghĩa dashboard trong code, import component trực tiếp | **Chọn**. Có kiểm tra kiểu, đổi sang map theo `key` khi cần cá nhân hóa |

---

## 10. Kiến trúc mục tiêu

```
pages/admin/index.vue                          (vỏ mỏng, giữ nguyên)
features/admin/dashboard/
  DashboardView.vue                            (header: DashboardSwitcher + ScopePicker; grid widget)
  dashboards.ts                                (DASHBOARDS: định nghĩa bằng code)
  useDashboardSelection.ts                     (?view= + localStorage, lọc dashboard nhìn được)
  kit/  WidgetCard.vue WidgetStateView.vue widgetState.ts types.ts
  widgets/<key>/  <Key>Widget.vue  use<Key>Widget.ts  <key>Stats.ts (hàm thuần nếu có đếm)
composables/useAdminScope.ts                   (mở rộng useCurrentBranch, S1)
stores/modules/auth-parts/branchGrants.ts      (quyền theo từng chi nhánh: canAt(perm, branchId))
components/common/{stats,charts}/              (KpiCard, StackedBarChart... chuyển từ reports)
```

Định nghĩa (TypeScript, không phải JSON):

```ts
type ScopeKind = "branch" | "all";
type WidgetDef = { key: string; component: Component; permission: string; scopes: ScopeKind[]; span?: 1 | 2 };
type DashboardDef = { key: "today" | "business"; titleKey: string; scopes: ScopeKind[]; requires?: string; widgets: WidgetDef[] };
```

Quy tắc:

1. **[R]** Dashboard hiện khi `requires` (nếu có) thỏa **và** có ít nhất một widget nhìn được ở scope hiện tại.
2. **[R]** Widget nhìn được khi `canAt(permission, branchId)` (scope một chi nhánh) hoặc có quyền ở ít nhất một chi nhánh (scope `all`, chỉ với widget khai báo hỗ trợ `all`). `canAt` đọc `my_permissions` theo từng dòng, **không** dùng bản gộp. Admin/superAdmin: luôn đúng (khớp `is_admin()` ở server).
3. **[R]** Frontend chỉ quyết định hiển thị; server vẫn là nơi chặn. Mọi RPC mới nhận "tất cả chi nhánh" phải mở rộng thành danh sách cụ thể như `report_branch_ids`.
4. **[R]** Mỗi widget có composable trả `WidgetState<T>` (mục 6), tải độc lập, lỗi độc lập.
5. **[R]** Widget không tính công thức nghiệp vụ; chỉ đếm/sắp xếp dữ liệu RPC trả về trong hàm thuần có test.

---

## 11. Câu hỏi cần PO quyết định

| # | Câu hỏi | Phương án | Ảnh hưởng |
| --- | --- | --- | --- |
| Q1 | Doanh thu đơn online ghi vào ngày nào? (R2) | (a) ngày tạo HĐ khi đóng gói (hiện tại); (b) ngày thu tiền (giao COD / thanh toán tại quầy); (c) ngày đặt hàng | (b) cần migration thêm `paid_at` và sửa 5 RPC báo cáo; số liệu cũ đổi |
| Q2 | HĐ online bị hoàn (chưa thu tiền) có tính là "hủy" không? (R2b) | (a) có (hiện tại); (b) tách thành "đơn hoàn" | (b) sửa `report_overview_core` |
| Q3 | Có hiện "tiền COD đang chờ thu" (HĐ `unpaid`) không? | có / không | RPC mới hoặc thêm trường |
| Q4 | "Hết hàng" có tính sản phẩm chưa từng nhập kho? (R6) | (a) có (hiện tại); (b) chỉ sản phẩm từng có lô | (b) sửa `stock_alert_counts` |
| Q5 | Ngưỡng "sắp hết hạn" trên dashboard | 30 / 60 (mặc định RPC) ngày | |
| Q6 | Vaccine quá hạn xem theo toàn chuỗi hay theo chi nhánh thú hay đến? (R7) | (a) toàn chuỗi (hiện tại); (b) theo chi nhánh lần tiêm cuối | (b) sửa `medical_reminders` |
| Q7 | Khách sạn đếm theo chuồng hay theo thú? (R9) | chuồng (hiện tại) / thú | |
| Q8 | Ai thấy dashboard "Kinh doanh"? | chỉ người có `reports` (đề xuất) | |
| Q9 | Có cần dashboard Spa / Thú y riêng? | không, dùng màn nghiệp vụ (đề xuất) | |
| Q10 | Khi nào có chi nhánh thứ hai? | | quyết định thời điểm làm S1 đầy đủ và scope `all` |

---

## 12. Kế hoạch theo phase, nghiệm thu và test

### Phase 0: Sửa P0 + lưới test (S–M, trước mọi UI)

| Hạng mục | Mức | Nội dung | Nghiệm thu |
| --- | --- | --- | --- |
| R1 | P0 | `queryClient.clear()` khi đăng xuất và khi `applySession` thấy user id khác | Test: đăng xuất → cache rỗng; đăng nhập tài khoản khác không thấy số cũ |
| R15 | P1 | pgTAP `supabase/tests/reports.test.sql`: công thức (paid/unpaid/cancelled/trả hàng), múi giờ (HĐ 23:30 và 00:30 giờ VN), phạm vi (`null` chỉ gộp chi nhánh được phép; chi nhánh trái quyền → 42501; admin thấy tất cả), cộng nhiều chi nhánh | `npm run db:test` xanh trong CI |
| R3 | P0 (phòng ngừa) | Viết quy tắc vào docs/CLAUDE.md: RPC nhận `p_branch null` phải mở rộng danh sách; thêm pgTAP cho `stock_alert_counts(null)`, `spa_day_board(null)`, `boarding_board(null)`, `medical_queue(null)` trả rỗng hoặc lỗi, không trả dữ liệu | Test xanh |
| R2 | P0 | Chờ PO trả lời Q1–Q2; nếu đổi định nghĩa thì migration forward-only (số > `20261101030000`), sửa từ định nghĩa trong `supabase/schema.sql` | Test R15 cập nhật theo định nghĩa mới |

Không làm UI ở phase này.

### Phase 1: Nền tảng Multi-Dashboard (M, không migration)

| Hạng mục | Mức | File chính |
| --- | --- | --- |
| `branchGrants` + `canAt(perm, branchId)` (R4) | P1 | `web/stores/modules/auth-parts/` |
| `useAdminScope` + lọc chi nhánh theo quyền (S1, R5) | P1 | `web/composables/useCurrentBranch.ts`, `BranchPicker` |
| Kit widget + `WidgetState` (mục 6) | P1 | `features/admin/dashboard/kit/*` |
| `dashboards.ts`, `useDashboardSelection` (S2) | P1 | `features/admin/dashboard/*` |
| Export hook còn thiếu, tạo `shop-orders/index.ts` | P1 | 3 file `index.ts` |
| Chuyển `KpiCard`, `StackedBarChart`, `chartScale`, `format` ra `components/common` | P1 | `features/admin/reports/**` |
| Widget W1, W3, W5, W6, W7 cho "Hôm nay"; W1, W2, W3b, W8 cho "Kinh doanh"; bỏ phép tính ở frontend (R10), hiện đủ 4 mảng (R11), nhãn "chuồng" (R9) | P1 | `features/admin/dashboard/widgets/*` |
| Không hiện số cũ khi đổi chi nhánh (R8) | P1 | widget composables |

Nghiệm thu Phase 1:

- Mỗi widget đi qua đủ trạng thái `hidden / needsBranch / loading / forbidden / error / empty / ready` (unit test `widgetState`).
- Nhân viên có quyền module ở chi nhánh A nhưng chọn B: widget `hidden`, không có request 42501.
- Một RPC lỗi (giả lập) không làm widget khác lỗi.
- Số W1 khớp tab Tổng quan báo cáo cùng chi nhánh, cùng ngày.
- Đổi dashboard giữ chi nhánh; đổi chi nhánh giữ dashboard; Back trả về dashboard trước.
- Bấm widget mở đúng màn với đúng chi nhánh.
- `npm run type-check`, `npm run deps:check`, `npm test`, `npm run build` xanh.

### Phase 2: UX và bảo trì (S–M)

R12 (đổi ngày lúc nửa đêm), R13 (invalidate báo cáo/tồn kho sau bước đơn online), R14 (một hàm "hôm nay"), R16 (chuông thông báo dùng nguồn của W3), bộ lọc qua URL cho màn đích (tồn kho, đơn online), lưu dashboard mặc định.

### Later

Dashboard Spa/Thú y riêng (khi có yêu cầu), so sánh chi nhánh (`report_branch_compare`, khi có ≥2 chi nhánh), cá nhân hóa (bảng preferences), RPC tổng hợp cho W3, bảng tổng hợp, Dashboard Builder, Realtime.

### Bộ test đề xuất

| Nhóm | Test | Loại |
| --- | --- | --- |
| Dữ liệu | Công thức W1/W2/W8; HĐ `unpaid`/`cancelled`/trả hàng; HĐ sát nửa đêm giờ VN; khoảng > 366 ngày báo lỗi; kỳ không có HĐ trả 0 | pgTAP |
| Dữ liệu | `stock_alert_counts` với sản phẩm chưa nhập kho, lô hết hạn hôm nay; `boarding_board` đếm theo chuồng; `medical_queue` mang lượt chờ từ hôm trước | pgTAP |
| Đối chiếu | Tổng `report_revenue_series` bằng `report_overview` cùng kỳ (sai số làm tròn ≤ số ngày) | pgTAP hoặc Vitest DB (`apps/web/tests/db`) |
| Chi nhánh | Một chi nhánh; `null` chỉ gộp chi nhánh được phép; chi nhánh trái quyền → 42501; `has_permission(null)` không mở dữ liệu | pgTAP (`tests.login(user)` + `set local role authenticated`) |
| Cache | Đăng xuất xóa cache; đổi chi nhánh không hiện số cũ | Vitest unit cho `useAdminScope` + test thủ công |
| Multi-Dashboard | Danh sách dashboard theo quyền; `?view=` không hợp lệ quay về mặc định; widget dùng chung ở hai dashboard cùng key cache | Vitest unit cho `dashboards.ts`, `useDashboardSelection` |
| Widget | Map trạng thái query → `WidgetState`; hàm đếm spa | Vitest unit |

---

## Quyết định kiến trúc

**Làm ngay**

1. Phase 0: sửa R1 (dọn cache khi đăng xuất), thêm pgTAP cho RPC báo cáo và cho quy tắc `p_branch null`, xin PO trả lời Q1–Q2 về cách ghi nhận doanh thu online.
2. Phase 1: dashboard định nghĩa bằng code, tổ chức theo mục đích, **2 dashboard** ("Hôm nay", "Kinh doanh"), quyền ở cấp widget theo **từng chi nhánh** (`canAt`), một scope chi nhánh dùng chung mở rộng từ `useCurrentBranch`, widget tải độc lập với trạng thái rõ ràng, dữ liệu từ RPC sẵn có.

**Giữ nguyên**

- Toàn bộ RPC `report_*`, `stock_alert_counts`, `shop_order_badge`, `list_shop_orders`, `spa_day_board`, `boarding_board`, `medical_queue`, `medical_reminders` và cách chúng kiểm tra quyền.
- Cơ chế `admin.branchId` mà 17 màn hình đang dùng (mở rộng, không thay).
- TanStack Query, query key theo feature, polling hiện có.
- Biểu đồ SVG tự vẽ.

**Sửa trước khi làm UI**

- R1 (P0), R15 + R3 test (P0/P1), chốt Q1–Q2 cho R2 (P0).

**Hoãn**

- Dashboard Spa/Thú y riêng, dashboard theo vai trò, so sánh chi nhánh, cá nhân hóa, bảng cấu hình dashboard, migration cho dashboard, RPC tổng hợp, cache layer, Realtime, Dashboard Builder, widget registry động.

---

### Giới hạn của audit

- Không chạy được Supabase local hay truy vấn DB thật trong phiên này; mọi kết luận về hành vi RPC dựa trên định nghĩa trong `supabase/schema.sql`, chưa chạy thử. Các kịch bản ở cột "Cách xác minh" là để thread triển khai kiểm chứng.
- Hành vi giữ cache của TanStack (giữ 5 phút, hiện dữ liệu cũ khi mount, giữ `data` khi refetch lỗi) là hành vi mặc định được tài liệu hóa của thư viện, chưa được thử trực tiếp trên app.
- Chưa đọc kỹ `spa_day_board` phần cuối (trường trả về của từng item ngoài các trường đã liệt kê) và các màn đích để xác nhận tham số query nào được hỗ trợ ngoài báo cáo và sản phẩm.
