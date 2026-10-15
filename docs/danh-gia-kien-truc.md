# Đánh giá kiến trúc bong-cun (10/2026)

Thời điểm: 2026-10-15, sau khi các module chính đã xong (shop online, spa, POS, kho theo lô, khách sạn thú cưng, y tế). Đây là đánh giá tổng thể, chưa phải kế hoạch refactor. Không đổi code trong PR này.

## Cập nhật sau khi sửa (2026-10-15, PR #126 đến #130)

Các mục 4.1, 4.2, 4.8 và 5 đã được xử lý theo [ke-hoach-sua-kien-truc.md](ke-hoach-sua-kien-truc.md):

- 4 lỗi typecheck đã sửa, gỡ `uuid`, `@types/uuid`, `@vuepic/vue-datepicker` (PR #127).
- CI chạy ở mọi PR: typecheck, build, toàn bộ migration trên DB rỗng, 28 test pgTAP, kiểm `supabase/schema.sql` (PR #128).
- `supabase/schema.sql` là bản chụp để tra hàm hiện hành (PR #128).
- Backup mã hóa hằng tuần, lần chạy đầu thành công (PR #129, [sao-luu-du-lieu.md](sao-luu-du-lieu.md)).
- Không còn file nào trong `src/` trên 300 dòng (PR #130).
- Mục 4.3: rà lại cho thấy các chỗ gác bằng `is_staff()` là chủ ý (xem bên dưới); test quyền đã có cho POS.

Còn để sau: 4.4 (kiểu `jsonb`), 4.6 (`pg_cron`), 4.7 (bảng tổng hợp báo cáo), (test SQL cho lưu trú và y tế đã có ở PR #132, `radix-vue` đã chuyển sang `reka-ui` ở PR sau đó).

## 1. Trả lời ngắn

- **Kiến trúc hiện tại (Nuxt 4 + Supabase, nghiệp vụ nằm trong RPC Postgres, RLS là lớp chặn thật) đủ cho giai đoạn pet project, và còn đủ cho 1 đến vài chi nhánh nhỏ khi có khách thật.** Không cần đổi nền tảng.
- **Điểm yếu lớn nhất không nằm ở công nghệ mà ở lưới an toàn:** không có test nào (cả TypeScript lẫn SQL), không có CI build/typecheck, và migration chạy thẳng vào database production ngay khi merge mà không qua bản thử. Với khoảng 24.600 dòng SQL nghiệp vụ, đây là rủi ro số 1.
- Rủi ro số 2 là **khó biết phiên bản hiện tại của một hàm SQL** (ví dụ `create_invoice` được định nghĩa lại 7 lần qua các migration) và **kiểm tra quyền phân tán** trong 215 hàm `security definer`.
- NestJS và app mobile: **đang hoãn** theo quyết định ngày 2026-10-13 (dự án chưa có doanh thu). Phân tích ở PR #53 vẫn còn đúng làm hướng sau này; tài liệu này không đề xuất chuyển.

## 2. Hiện trạng (số liệu đo trên `main`, commit f4859a4)

| Phần | Hiện trạng |
| --- | --- |
| Frontend | Nuxt 4, `srcDir: src/`. Trang công khai SSR, `/admin/**`, giỏ hàng, checkout, tài khoản là SPA (`routeRules` trong `nuxt.config.ts`). ~1.260 file `.vue/.ts`. |
| Tầng dữ liệu FE | `src/repositories/` (TS thuần, nhận Supabase client, 81 file) → `src/queries/` (TanStack Query, 47 file, khóa cache ở `queries/keys.ts`) → `src/views/` (575 file) → `src/pages/` (vỏ mỏng). Pinia chỉ còn 4 store (`auth`, `cart`, `app`). |
| Backend | Không có server riêng. Nghiệp vụ trong Postgres: 121 migration, ~24.600 dòng SQL, 263 hàm `public.*` (215 hàm `security definer`, 148 hàm trả `jsonb`), 77 bảng, 128 index. |
| Phân quyền | Role tài khoản trong JWT (`user_role` qua Custom Access Token Hook: `is_admin()`, `is_super_admin()`) + quyền theo (nhân viên, chi nhánh) qua `staff_branches` + `role_permissions` + `has_permission(perm, method, branch)`. Mỗi module có hàm gác riêng: `can_pos`, `can_inventory`, `can_boarding`, `can_medical`... Middleware `auth.global.ts` chỉ chặn giao diện. |
| Server code ngoài DB | `server/api/ghn/*` (proxy GHN trên Vercel/Nitro), 1 edge function `supabase/functions/admin-create-user`. |
| Storage | Bucket `images` (public), bucket `medical` (private, có policy theo quyền). |
| Triển khai | Vercel (`vercel.json`). Workflow `supabase-migrate.yml` chạy `supabase db push --include-all` vào production khi merge vào `main` có file migration mới. |
| Kiểm thử, CI | Không có file test, không có ESLint, không có workflow typecheck/build. Typecheck và build chỉ chạy tay trong từng thread. |
| Kiểu dữ liệu | `src/types/database.types.ts` (3.182 dòng) sinh từ Supabase; mọi RPC FE gọi (176 hàm) đều có trong file này. Nhưng 148 RPC trả `jsonb` nên kiểu kết quả phải viết tay (ví dụ `src/types/boarding.ts`, 321 dòng). |

## 3. Điểm mạnh nên giữ

1. **Nghiệp vụ nguyên tử nằm trong Postgres.** Hóa đơn, trừ kho FEFO, ca thu ngân, đổi trả, check-in/out lưu trú, ký bệnh án đều là một RPC một giao dịch. Không có chuyện FE ghi nửa chừng. Đây đúng là chỗ mà PR #53 cũng khuyên giữ lại dù sau này có NestJS.
2. **RLS bật trên mọi bảng**, `set search_path = ''` trên toàn bộ 339 lần tạo hàm, `revoke ... from public, anon` có mặt nhất quán. Policy dùng `(select auth.uid())` để planner cache. Nền bảo mật tốt hơn nhiều dự án cùng cỡ.
3. **Đa chi nhánh đã được thiết kế từ đầu:** 32 cột `branch_id`, hàm gác nhận `p_branch` (ví dụ `can_pos('VIEW', branch_id)` trong policy hóa đơn), `medical_settings` theo chi nhánh. Thêm chi nhánh thứ hai là việc cấu hình, không phải viết lại.
4. **Tầng FE tách lớp rõ:** repositories không phụ thuộc Vue, queries gom cache và invalidation (ví dụ `invalidatePos` trong `src/queries/pos.ts` làm mới cả kho, spa, lưu trú, báo cáo). Quy tắc chia file nhỏ đã được áp dụng: chỉ còn 6 file trên 300 dòng.
5. **Chi phí gần như bằng 0:** Vercel + Supabase, không có server phải trông.

## 4. Điểm yếu và nợ kỹ thuật (xếp theo mức ưu tiên)

### 4.1 Không có lưới an toàn trước production (cao)

- `.github/workflows/` chỉ có `supabase-migrate.yml` và `supabase-mark-applied.yml`. Không có bước typecheck, build hay test trên PR.
- Migration chạy thẳng vào DB thật khi merge (`supabase db push --include-all`). Các thread trước có test trên Postgres cục bộ, nhưng việc đó tùy từng thread, không bắt buộc. Một lần đã có file lỗi lọt lên (`20261017030000` thiếu `$$;`, sửa ở PR #100).
- `nuxt typecheck` trên `main` hiện **không sạch**: 4 lỗi có từ trước (chạy ngày 2026-10-15): `src/components/common/RangeDateShadcn/Index.vue` import `radix-vue/dist/date` không còn tồn tại (2 lỗi), `src/components/common/Zooming.vue` thiếu kiểu cho `vue-zoomable`, `src/components/ui/toast/use-toast.ts:82` lỗi TS2589. Vì không có CI nên không ai thấy.
- Không có test nào: không có `*.spec.ts`, không có pgTAP. 7 lần định nghĩa lại `create_invoice` không có gì đảm bảo bản sau không phá bản trước.

**Hướng sửa (rẻ, nên làm trước):** một workflow `ci.yml` chạy trên PR: `npm ci`, `nuxt typecheck`, `nuxt build`, và dựng Postgres rỗng (`supabase start` hoặc container `postgres`) rồi chạy toàn bộ migration từ đầu. Chỉ riêng bước "chạy lại toàn bộ migration trên DB rỗng" đã bắt được lỗi cú pháp và lỗi thứ tự. Sau đó thêm dần vài test SQL cho các luồng tiền và kho (mục 5).

### 4.2 Khó biết hàm SQL nào là bản hiện hành (cao)

- 49 hàm được định nghĩa lại nhiều lần: `create_invoice` 7 lần, `cancel_invoice` 5, `save_product_group` 5, `product_group_json` 5, `report_sales_lines` 4...
- Muốn đọc bản đang chạy phải lục migration mới nhất có tên hàm đó. Thread sau rất dễ sửa nhầm từ bản cũ, làm mất một bản vá (ví dụ quy tắc giá phía server của `create_invoice`).

**Hướng sửa:** thêm file chỉ để đọc `supabase/schema.sql` do CI sinh (`supabase db dump --schema-only` sau khi chạy migration trên DB rỗng) và commit kèm PR. Không đổi cách viết migration, chỉ có một bản chụp để tra cứu và so diff.

### 4.3 Kiểm tra quyền phân tán trong hàm `security definer` (trung bình, cần kiểm)

- 215 hàm `security definer` bỏ qua RLS, nên mỗi hàm tự kiểm quyền. Quét tĩnh: 65 hàm không gọi trực tiếp `can_*`, `has_permission`, `is_admin` hay `auth.uid()`.
- Phần lớn là hàm nội bộ đã `revoke ... from authenticated` (ví dụ `take_stock_fefo`, `next_doc_code`, `stock_rows`, `import_pets_row`) hoặc hàm công khai cố ý (`shop_public_settings`, `spa_public_catalog`). Một số hàm được cấp cho `authenticated` nhưng kiểm quyền qua hàm phụ: `save_boarding_stay` qua `boarding_apply_stay`, `report_overview` qua `report_branch_ids`, `confirm_shop_order` qua `shop_order_for_update`. Tôi không tìm thấy lỗ hổng cụ thể, nhưng **không có cách nào xác nhận ngoài đọc tay từng hàm**.
- Hai hệ quyền chồng nhau: `is_admin()` đọc role trong JWT và bỏ qua chi nhánh; `has_permission` đọc theo chi nhánh. `is_staff()` (`20261007100000_permission_policies.sql`) trả true cho `admin`, `superAdmin`, `cashier` hoặc bất kỳ ai có role ở một chi nhánh. Rà lại 16 chỗ dùng: tất cả là đọc danh mục dùng chung (loại chuồng, giá chuồng, chẩn đoán, loại vaccine), cờ sức khỏe ở quầy (`pet_health_flags`, chỉ trả cờ, không trả bệnh án) và tìm khách ở quầy (`search_customers`). Đây là chủ ý "mọi nhân viên đều đọc", không phải lỗ hổng. Đổi role hay chi nhánh chỉ có hiệu lực khi JWT được làm mới (`branch_ids` nằm trong token).

**Hướng sửa:** (1) test SQL theo role: "thu ngân không có quyền X gọi hàm Y thì bị 42501", vài chục ca cho các hàm ghi tiền và kho; (2) quy ước mỗi hàm `security definer` được cấp cho `authenticated` phải có dòng kiểm quyền ngay đầu thân hàm, kể cả khi hàm phụ đã kiểm; (3) chạy Supabase Security Advisor định kỳ (không chạy được trong phiên này vì kết nối Supabase bị chặn).

### 4.4 RPC trả `jsonb` nên mất kiểu dữ liệu (trung bình)

- 148 hàm trả `jsonb`; `database.types.ts` chỉ biết là `Json`. Kiểu thật được viết tay ở `src/types/*.ts` và ép kiểu trong repository. Đổi tên một khóa trong SQL thì TypeScript không báo.

**Hướng sửa:** với hàm mới, ưu tiên `returns table (...)` hoặc `returns setof <view>` khi kết quả là danh sách phẳng. Với hàm cũ, thêm parse bằng zod ở repository cho vài luồng quan trọng (hóa đơn, lưu trú, bệnh án) để lỗi lệch khóa hiện ngay thay vì ra `undefined` trên màn hình.

### 4.5 Thư viện UI trùng lặp (thấp)

- `radix-vue` (tên cũ) dùng ở 155 file, `reka-ui` (tên mới của cùng thư viện) ở 10 file. Hai bản cùng nằm trong bundle.
- `@vuepic/vue-datepicker` không còn component nào import nhưng CSS của nó vẫn nạp toàn cục trong `nuxt.config.ts`; `uuid` không còn được import (code dùng `crypto.randomUUID()`); `vue-multiselect`, `lodash-es`, `vue-zoomable` mỗi cái chỉ dùng ở 1 file. Tên package vẫn là `beer-sys`.

**Đã sửa (2026-10-15):** đổi toàn bộ import sang `reka-ui`, gỡ `radix-vue`. `Checkbox` và `Switch` giữ API `checked`/`update:checked` cũ nên không phải sửa ~35 chỗ dùng. Typecheck 0 lỗi, build chạy; chưa bấm thử trên trình duyệt.

### 4.6 Việc chạy nền chưa có chỗ (thấp bây giờ, cao khi có khách)

- Không có `pg_cron` hay job định kỳ. Nhắc lịch tiêm, cảnh báo lô sắp hết hạn, nhả đơn online quá hạn, đối soát thanh toán đều đang phải bấm tay hoặc chưa có.
- Khi cần, đường rẻ nhất là `pg_cron` gọi RPC có sẵn ngay trong Supabase, chưa cần server riêng. Đây cũng là điểm PR #53 đưa sang NestJS; với quy mô hiện tại `pg_cron` + edge function là đủ.

### 4.7 Hiệu năng (thấp)

- 128 index, tìm kiếm qua RPC chung, phân trang ở DB (`pageRange` trong `src/repositories/shared.ts`). 10 chỗ dùng `count: "exact"`, ổn với dữ liệu vài chục nghìn dòng.
- Báo cáo tính trực tiếp trên bảng giao dịch (`report_overview` chạy `report_overview_core` hai lần cho kỳ này và kỳ trước). Chỉ cần bảng tổng hợp theo ngày khi hóa đơn lên hàng trăm nghìn.
- Màn admin cập nhật bằng polling (`usePolling`), chưa dùng Realtime. Đủ cho vài máy cùng chi nhánh.

### 4.8 Backup và môi trường (cần grace xác nhận)

- Chỉ có một môi trường Supabase (`bongcun-manager`), dùng cho cả thử và thật. Tôi không kiểm được gói Supabase đang dùng; nếu là gói Free thì không có point-in-time recovery và project bị tạm dừng khi không hoạt động một thời gian. Trước khi có dữ liệu khách thật nên có ít nhất một bản dump định kỳ (có thể là một workflow GitHub chạy `supabase db dump` hằng tuần vào artifact riêng tư).

## 5. File lớn hơn 300 dòng (chỉ liệt kê, không sửa ở đây)

| File | Dòng | Gợi ý tách khi có thread refactor |
| --- | --- | --- |
| `src/repositories/pos.ts` | 544 | tách `pos/invoices.ts`, `pos/shifts.ts`, `pos/returns.ts`, `pos/errors.ts` |
| `src/repositories/inventory.ts` | 524 | tách theo lô, phiếu kho, nhà cung cấp, ngưỡng tồn |
| `src/stores/modules/auth.ts` | 409 | tách phần quyền admin (`loadAdminGrants`) và phần hồ sơ ra composable/helper |
| `src/repositories/medical/visits.ts` | 384 | tách đọc (danh sách, chi tiết) và ghi (chỉ định, ký, hủy) |
| `src/types/boarding.ts` | 321 | tách theo đặt chỗ, chăm sóc, thanh toán |
| `src/queries/boarding.ts` | 312 | tách giống repository `boarding/` |

Migration lớn (ví dụ `20261007130000_inventory_lots.sql` 1.122 dòng) không tính vì migration không được sửa lại.

## 6. Còn đủ cho đa chi nhánh không

Đủ ở mức dữ liệu và quyền. Những việc còn phải làm khi mở chi nhánh thứ hai:

- Rà các policy và hàm còn dùng `is_admin()` (46 chỗ) và `is_staff()` (16 chỗ): admin thấy mọi chi nhánh là cố ý, nhưng nếu muốn "quản lý chi nhánh" chỉ thấy chi nhánh của mình thì phải đổi sang `has_permission(..., branch)`.
- Báo cáo đã nhận danh sách chi nhánh (`report_branch_ids`), không cần đổi.
- Kho, ca, hóa đơn, chuồng, lịch spa đã theo chi nhánh.

## 7. NestJS và app mobile

Đang hoãn (quyết định 2026-10-13). Phân tích ở PR #53 vẫn đúng làm hướng sau này: nếu làm thì NestJS đứng cạnh Supabase cho webhook, cron, thông báo, không thay RPC. Các mục 4.1 đến 4.4 ở trên đều có ích cho cả hướng đó, nên không bị bỏ phí.

## 8. Lộ trình đề xuất

Theo thứ tự, mỗi bước một PR nhỏ, không đổi tính năng:

1. **CI trên PR:** sửa 4 lỗi typecheck hiện có, rồi chạy typecheck, build, và toàn bộ migration trên Postgres rỗng ở mỗi PR (mục 4.1).
2. **Bản chụp schema** `supabase/schema.sql` do CI sinh để tra hàm hiện hành (mục 4.2).
3. **Test SQL cho luồng tiền và kho:** tạo/hủy hóa đơn, trả hàng, trừ kho FEFO, check-out lưu trú, kèm ca kiểm quyền theo role (mục 4.3).
4. **Backup định kỳ** và xác nhận gói Supabase (mục 4.8).
5. Khi đụng tới: tách 6 file lớn (mục 5), chuyển `radix-vue` sang `reka-ui`, gỡ gói không dùng, zod parse cho RPC `jsonb` quan trọng.
6. Khi có khách thật: `pg_cron` cho nhắc lịch và cảnh báo lô, sau đó mới tính tới bước tiếp theo của PR #53.

## 9. Giới hạn của đánh giá này

- Số liệu lấy bằng quét tĩnh repo (grep và một script đọc thân hàm SQL), không chạy trên database thật vì kết nối Supabase bị chặn trong phiên này. Quét tĩnh có thể bỏ sót policy tạo bằng `execute format(...)`.
- Không bấm thử giao diện, không chạy build. Chỉ chạy `nuxt typecheck` một lần trên `main` (4 lỗi có từ trước, mục 4.1).
