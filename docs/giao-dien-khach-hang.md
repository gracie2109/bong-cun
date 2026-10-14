# Giao diện khách hàng (frontend người dùng cuối)

Kế hoạch hoàn thiện phần web khách hàng tự dùng: shop công khai, khu vực tài khoản, thú cưng của tôi và đặt lịch spa online. Viết ngày 2026-10-14, sau khi checkout shop (PR #71-#79) đã merge.

Nguồn: [checkout-shop.md](checkout-shop.md), [lich-hen-spa.md](lich-hen-spa.md), [module-san-pham.md](module-san-pham.md), [view-structure.md](view-structure.md), kế hoạch BA/kiến trúc v0.3 (M12 Cổng khách hàng) và code hiện có trong `src/views/client`, `src/views/home`, `src/composables/shop`.

> **Cách hiểu yêu cầu.** "Phần f0 người dùng cuối" được hiểu là **FE (frontend) phía khách hàng**: mọi màn hình khách nhìn thấy, không phải admin. Nếu ý chị là "F0 = giai đoạn đầu tiên" thì các bước 1-8 dưới đây chính là giai đoạn đầu của phía khách; phần "Để sau" ở mục 2 là giai đoạn sau.

## 1. Trước và sau

**Trước (hiện trạng trên `main`):**

| Khu vực | Đang có | Thiếu / lỗi |
| --- | --- | --- |
| Trang chủ | Banner, dịch vụ, danh mục thật (fallback ảnh mẫu), dải "Sản phẩm được yêu thích" lấy nhóm sản phẩm thật, quick view thêm giỏ | Dải sản phẩm thứ hai vẫn là dữ liệu mẫu `rawProducts`; `RegisterForm.vue` 765 dòng ghi vào bảng `bookings` cũ (yêu cầu tư vấn), lệch với module lịch hẹn mới |
| Sản phẩm | Chỉ quick view trong dialog (`ShopGroupCard`) | `/products` đang render lại trang chủ; không có trang chi tiết, không lọc danh mục/thương hiệu, không tìm kiếm, không phân trang |
| Giỏ, checkout, đơn | Giỏ thống nhất, địa chỉ, phí GHN, COD và nhận tại cửa hàng, trang đơn `/orders/[code]`, tab "Đơn của tôi" | Không có |
| Tài khoản | `/profile` với 3 tab (thông tin, địa chỉ, đơn) | Tab thông tin in thẳng `{{ currentUser }}` ra màn hình, nút "Update profile" không làm gì, lưới 9 mạng xã hội chỉ Google chạy; tab bằng `ref`, không có URL riêng |
| Thú cưng | Không có phía khách | RLS `pets`, `customers` chỉ cho nhân viên |
| Lịch spa | Lễ tân đặt tại quầy (`save_appointment`, `source` đã có giá trị `web` để dành) | Khách không tự đặt, không xem lịch của mình |
| Trang tĩnh | `/contact` cứng địa chỉ mẫu | `/about-us`, `/coupons` render trang chủ; header còn chữ "Login" cứng, menu tiếng Anh cứng |

**Sau:** khách vào web xem và lọc sản phẩm, mở trang chi tiết, mua hàng (đã có), đăng nhập rồi vào **Tài khoản** để sửa thông tin, quản lý địa chỉ, xem đơn, khai báo **thú cưng** của mình, **đặt lịch spa** theo khung giờ còn trống và xem/hủy lịch đã đặt. Lễ tân thấy lịch đặt từ web trên bảng lịch với nhãn "Web", chưa xếp người làm, rồi xếp như lịch đặt qua điện thoại.

## 2. Phạm vi

| Mức | Nội dung |
| --- | --- |
| **Làm (bước 1-8)** | Dọn layout/header/footer và trang chủ; trang danh sách sản phẩm; trang chi tiết sản phẩm; khu vực tài khoản có URL riêng; sửa hồ sơ; thú cưng của tôi; bảng giá dịch vụ spa; đặt lịch spa online; lịch hẹn của tôi (xem, hủy); trang giới thiệu và liên hệ thật; nút "Liên kết tài khoản web" trong admin |
| **Để sau** | Sổ tiêm, lịch sử khám (cần module Y tế, Phase 2); đặt lưu trú online (sau module khách sạn thú cưng); điểm tích lũy, hạng thành viên, voucher (trang `/coupons` bỏ khỏi menu tới lúc đó); đăng nhập OTP qua SĐT (tốn phí SMS); thông báo đẩy, Zalo/SMS nhắc lịch; đặt cọc; ảnh thú cưng (đang mở trong memory, làm chung khi có upload ảnh cho khách); app mobile (Phase 3, đã hoãn) |
| **Không làm** | Đổi kiến trúc (vẫn Nuxt + Supabase RPC, không NestJS); đổi theme cam của shop công khai; sửa migration cũ |

Ưu tiên đơn giản, chi phí thấp: không thêm dịch vụ trả phí nào, không edge function; mọi logic mới là RPC Postgres như các module trước.

## 3. Quy tắc nghiệp vụ

### 3.1 Danh mục và tìm kiếm sản phẩm

- Shop chỉ hiện nhóm sản phẩm có ít nhất một biến thể đang bán. Giá hiển thị là **giá của cơ sở bán online** (`shop_settings.online_branch_id`, giá chung nếu cơ sở không ghi đè), dạng "Từ 120.000đ" khi các biến thể khác giá.
- Lọc theo danh mục **gồm cả danh mục con** (chọn "Thức ăn cho chó" thì ra cả "Hạt" và "Pate" bên dưới).
- Tìm kiếm theo tên (bỏ dấu), SKU, mã vạch như `list_product_groups`; ô tìm debounce 500ms (quy ước).
- Sắp xếp: mới nhất (mặc định), giá tăng, giá giảm, tên A-Z.
- Phân trang: `page` + `page_size` như mọi getList, trên shop hiển thị kiểu nút "Xem thêm" (dùng lại logic `useInfiniteOptions`), 24 nhóm mỗi lần.
- Nhóm hết hàng ở cơ sở online vẫn hiện nhưng mờ và có nhãn "Hết hàng"; sắp xuống cuối khi sắp xếp mặc định.
- Bộ lọc nằm trên URL query (`?q=&category=&brand=&sort=`) để chia sẻ link và nút quay lại giữ trạng thái.

### 3.2 Trang chi tiết sản phẩm

- URL `/products/[id]` theo id nhóm (slug để sau, không cần migration).
- Dùng lại `ShopGroupGallery`, `VariantOptions`, `useVariantChoice`, `useAddToCart` của quick view. Quick view vẫn giữ, thêm link "Xem chi tiết".
- Có mô tả, thương hiệu, danh mục (breadcrumb), đơn vị quy đổi, tồn còn bán, và 8 sản phẩm cùng danh mục.
- Nhóm không còn biến thể bán được: trang báo "Sản phẩm đã ngừng bán", không lỗi 404.

### 3.3 Tài khoản và hồ sơ khách

- Một tài khoản web nối với **tối đa một** hồ sơ khách `customers` qua `customers.user_id` (đã có). Checkout đã tạo hồ sơ khi đặt đơn đầu tiên.
- Khi khách mở "Thú cưng" hoặc "Đặt lịch" mà chưa có hồ sơ, web gọi `ensure_my_customer(full_name, phone)`:
  - đã có hồ sơ nối với tài khoản: trả về hồ sơ đó;
  - SĐT chưa ai dùng: tạo hồ sơ mới nối với tài khoản;
  - SĐT **đã thuộc hồ sơ khác** (khách từng đến quầy): **không tự nối** (ai cũng có thể gõ SĐT người khác), báo `phone_in_use` và hướng dẫn "Cửa hàng đã có hồ sơ với số này. Nhờ nhân viên liên kết khi bạn đến, hoặc gọi hotline". Nhân viên nối trong admin bằng nút **Liên kết tài khoản web** (mục 6.2). Cùng nguyên tắc với checkout: tài khoản không bao giờ tự nối vào hồ sơ của người khác.
- Sửa hồ sơ: họ tên, SĐT, ngày sinh (tùy chọn). Email là email đăng nhập, chỉ đọc. Đổi SĐT chạy cùng quy tắc trùng số như trên. Tên và SĐT trên hồ sơ khách cập nhật theo.
- Lưới 9 mạng xã hội bỏ, chỉ giữ "Liên kết Google" (thứ duy nhất đang chạy).

### 3.4 Thú cưng của tôi

- Khách thấy các thú cưng có `pet_owners.customer_id = hồ sơ của mình` và `to_date is null`, kể cả thú do lễ tân tạo.
- Khách thêm thú: tên, loài (bắt buộc), giống, giới tính, triệt sản, ngày sinh, dị ứng, ghi chú tính cách, cân nặng hiện tại (ghi vào `pet_weight_logs`). Khách thành chủ chính (`role = 'primary'`).
- Khách sửa được các trường trên cho thú **mình là chủ chính**; đồng sở hữu chỉ xem. Không sửa `microchip`, `status` (nhân viên làm).
- "Xóa" phía khách = ẩn khỏi danh sách của mình (đóng liên kết `pet_owners.to_date = hôm nay`), không xóa dữ liệu vì lịch sử dịch vụ đi theo thú. Thú đang có lịch hẹn chưa xong thì không ẩn được.

### 3.5 Đặt lịch spa online

- Chỉ khách **đã đăng nhập**, có hồ sơ khách và ít nhất một thú cưng. Khách vãng lai thấy bảng giá và nút "Đăng nhập để đặt lịch".
- Luồng 4 bước: **chọn cơ sở** (tự chọn khi chỉ có một) → **chọn thú và dịch vụ/combo** cho từng thú → **chọn ngày và giờ** → **xác nhận** (ghi chú, xem tạm tính).
- Dịch vụ/combo lọc theo loài của thú (`service_species`, `combo_species`) như `save_appointment`. Giá tạm tính lấy từ cân nặng gần nhất của thú; dịch vụ theo cân nặng mà thú chưa có cân nặng thì hiện "Báo giá khi nhận thú".
- Nhiều thú hoặc nhiều dịch vụ trong một lịch: các phiếu xếp **liền nhau** từ giờ bắt đầu khách chọn (phiếu sau bắt đầu khi phiếu trước xong). Đủ cho shop nhỏ, tránh bài toán xếp song song.
- **Khung giờ trống**: bước 15 phút, trong giờ mở cửa (`spa_hours`), cách hiện tại ít nhất **2 giờ**, tối đa **30 ngày** tới. Một khung còn chỗ khi số phiếu chưa hủy đang chồng lên khung đó **nhỏ hơn số bàn spa đang hoạt động** của cơ sở (không có bàn nào thì sức chứa = 1). Khách không chọn nhân viên, không chọn bàn.
- Lịch web lưu `source = 'web'`, `status = 'booked'`, phiếu không có `staff_id` và `resource_id`. Lễ tân xếp người/bàn trên bảng lịch như hiện nay. Ràng buộc chống trùng giờ của nhân viên/bàn vẫn do database giữ khi lễ tân xếp.
- Giới hạn chống spam: tối đa **3 lịch web chưa diễn ra** mỗi khách.
- Khách **hủy** được lịch của mình khi còn `booked` và còn hơn **2 giờ** trước giờ hẹn. Sát giờ hơn thì hiện "Gọi cửa hàng để hủy". Khách **không sửa** lịch: hủy rồi đặt lại (giống quy tắc của `save_appointment`).
- Các ngưỡng 2 giờ, 30 ngày, 3 lịch là hằng số đặt tên trong một hàm SQL `spa_web_rules()`; chưa làm màn hình cài đặt.
- Bảng `bookings` (form tư vấn cũ) giữ nguyên trong DB, không xóa; trang chủ không ghi vào nữa. Màn admin đọc `bookings` (nếu còn) không đổi.

### 3.6 Lịch hẹn của tôi

- Hai danh sách: **Sắp tới** (booked, checked_in, in_progress) và **Đã qua** (done, paid, cancelled, no_show), phân trang 10.
- Mỗi lịch: mã, cơ sở, giờ, từng thú với dịch vụ, trạng thái, tạm tính; nút hủy theo 3.5.
- Khách không thấy nhân viên nào làm, chỉ thấy trạng thái.

## 4. Quyền và bảo mật

- Mọi RPC mới cho khách là `security definer`, lọc theo `auth.uid()` qua `my_customer_id()`, `revoke ... from public, anon` rồi `grant ... to authenticated` (riêng `shop_product_groups`, `spa_public_catalog`, `spa_web_slots` cho cả `anon` vì là dữ liệu công khai).
- Không mở RLS đọc thẳng `pets`, `customers`, `appointments` cho khách; chỉ đi qua RPC trả đúng cột cần.
- `spa_web_slots` chỉ trả **có chỗ / hết chỗ** theo khung giờ, không lộ ai đặt.
- Route khu tài khoản và đặt lịch có `requiresAuth: true` (middleware hiện có). RLS/RPC vẫn là chỗ chặn thật.
- `link_customer_account` chỉ cho nhân viên có quyền sửa khách hàng (`has_permission('customers', 'UPDATE', null)` hoặc `is_admin()`, theo cách module khách hàng đang kiểm tra).

## 5. Database

Tất cả là migration mới, forward-only, chạy lại được (`create or replace`, `if not exists`), không sửa file cũ. Workflow "Supabase migrate" tự chạy khi merge vào `main`.

### 5.1 Bảng và cột

Không có bảng mới. Một cột mới:

| Bảng | Cột | Ghi chú |
| --- | --- | --- |
| `customers` | `birth_date date` | Tùy chọn, khách tự điền trong hồ sơ |

### 5.2 RPC

| RPC | Ai gọi | Việc |
| --- | --- | --- |
| `shop_product_groups(p_search, p_category, p_brand, p_sort, p_limit, p_offset)` | anon, authenticated | Như `list_product_groups` nhưng chỉ nhóm có biến thể đang bán, danh mục gồm cả con, trả `price_min`, `price_max` theo cơ sở online và `in_stock`; `p_sort in ('newest','price_asc','price_desc','name')`. Trả `{ total, rows }` |
| `shop_related_groups(p_group, p_limit)` | anon, authenticated | Nhóm cùng danh mục, trừ chính nó |
| `my_profile()` | authenticated | `{ email, full_name, phone, birth_date, customer_id }` từ `users` + `customers` |
| `ensure_my_customer(p_full_name, p_phone)` | authenticated | Mục 3.3. Lỗi `hint = 'phone_in_use'` |
| `save_my_profile(p jsonb)` | authenticated | Sửa tên, SĐT, ngày sinh trên `users` và hồ sơ khách. Lỗi `phone_in_use` |
| `my_pets()` | authenticated | Danh sách thú của tôi: id, tên, loài, giống, giới tính, triệt sản, ngày sinh, cân nặng gần nhất, vai trò của tôi |
| `save_my_pet(p jsonb, p_id uuid default null)` | authenticated | Thêm/sửa theo 3.4; tạo `pet_owners` primary khi thêm; ghi `pet_weight_logs` khi cân nặng đổi |
| `hide_my_pet(p_id uuid)` | authenticated | Đóng liên kết; lỗi `hint = 'has_open_appointment'` |
| `link_customer_account(p_customer uuid, p_user uuid)` | nhân viên | Nối tài khoản web chưa có hồ sơ vào hồ sơ khách chưa có tài khoản |
| `spa_web_rules()` | nội bộ | Hằng số: `min_lead` 2 giờ, `max_days` 30, `max_open` 3, `cancel_before` 2 giờ |
| `spa_public_catalog(p_branch uuid)` | anon, authenticated | Dịch vụ và combo đang bán: tên, mô tả, thời lượng, loài áp dụng, giá chung hoặc bảng giá theo khung cân nặng của cơ sở |
| `spa_web_slots(p_branch, p_date, p_minutes)` | anon, authenticated | Danh sách giờ bắt đầu (15 phút một) còn chỗ cho một khối dài `p_minutes`, theo 3.5 |
| `book_my_appointment(p jsonb)` | authenticated | `p: { branch_id, start_at, note?, items: [{ pet_id, type, id }] }`. Kiểm tra thú thuộc tôi, luật 3.5, xếp phiếu liền nhau, tính giá như `save_appointment`, ghi `source = 'web'`. Trả `{ id, code }`. Lỗi `hint`: `slot_full`, `too_soon`, `too_far`, `too_many`, `closed`, `outside_hours`, `no_pet` |
| `my_appointments(p_scope text, p_limit, p_offset)` | authenticated | `p_scope in ('upcoming','past')`, trả `{ total, rows }` |
| `cancel_my_appointment(p_id uuid, p_reason text default null)` | authenticated | Hủy theo 3.5; lỗi `hint = 'too_late'` |

Ghi chú cho `book_my_appointment`: `save_appointment` kiểm tra quyền lễ tân ngay đầu hàm nên khách không gọi được. Không sửa hàm đó; tách phần tính tên/thời lượng/giá một phiếu thành hàm nội bộ mới `spa_ticket_quote(p_branch, p_pet, p_type, p_id)` và dùng nó trong `book_my_appointment`. (Có thể cho `save_appointment` dùng lại hàm này sau, làm riêng, không nằm trong kế hoạch này.)

### 5.3 Chia file migration

| File | Bước | Nội dung |
| --- | --- | --- |
| `20261017010000_shop_catalog.sql` | 2 | `shop_product_groups`, `shop_related_groups` |
| `20261017020000_my_profile.sql` | 4 | Cột `customers.birth_date`, `my_profile`, `ensure_my_customer`, `save_my_profile` |
| `20261017030000_my_pets.sql` | 5 | `my_pets`, `save_my_pet`, `hide_my_pet` |
| `20261017030100_link_customer_account.sql` | 5 | `link_customer_account` |
| `20261017040000_spa_public_catalog.sql` | 6 | `spa_public_catalog` |
| `20261017050000_spa_web_slots.sql` | 7 | `spa_web_rules`, `spa_ticket_quote`, `spa_web_slots` |
| `20261017050100_book_my_appointment.sql` | 7 | `book_my_appointment` |
| `20261017060000_my_appointments.sql` | 8 | `my_appointments`, `cancel_my_appointment` |

Mỗi file dưới khoảng 300 dòng. Sau mỗi migration cập nhật `src/types/database.types.ts` (thêm chữ ký RPC mới bằng tay nếu không chạy được `supabase gen types`).

## 6. Màn hình

### 6.1 Phía khách

| Route | Màn | Ghi chú |
| --- | --- | --- |
| `/` | Trang chủ | Bỏ dải sản phẩm mẫu thứ hai; dải 1 dùng `shop_product_groups` sắp "mới nhất"; thay `RegisterForm` bằng khối CTA "Đặt lịch spa" dẫn tới `/spa/book` |
| `/products` | Danh sách sản phẩm | Cột lọc (danh mục dạng cây, thương hiệu), ô tìm, sắp xếp, lưới thẻ, "Xem thêm". Trên mobile bộ lọc mở bằng Sheet |
| `/products/[id]` | Chi tiết sản phẩm | Breadcrumb, gallery, chọn biến thể/đơn vị, số lượng, thêm giỏ, mô tả, sản phẩm liên quan |
| `/spa` | Dịch vụ spa | Bảng giá theo loài và khung cân nặng, nút "Đặt lịch" |
| `/spa/book` | Đặt lịch (cần đăng nhập) | Wizard 4 bước theo 3.5; xong chuyển `/account/appointments` với toast mã lịch |
| `/account` | Tổng quan tài khoản | Lời chào, 3 đơn gần nhất, lịch sắp tới gần nhất, số thú cưng |
| `/account/profile` | Hồ sơ | Form theo 3.3, liên kết Google |
| `/account/addresses` | Địa chỉ | Chuyển nguyên tab địa chỉ hiện có |
| `/account/orders` | Đơn hàng | Chuyển nguyên tab đơn hiện có; chi tiết vẫn là `/orders/[code]` |
| `/account/pets` | Thú cưng | Thẻ từng thú, dialog thêm/sửa (`AppDialog`-style của shop), ẩn |
| `/account/appointments` | Lịch hẹn | Tab Sắp tới / Đã qua, hủy |
| `/profile` | | Chuyển hướng sang `/account/profile` để link cũ không gãy |
| `/about-us` | Giới thiệu | Nội dung tĩnh trong file i18n, ảnh có sẵn trong `assets/register` |
| `/contact` | Liên hệ | Địa chỉ, SĐT, giờ mở cửa lấy từ `branches` và `spa_week_hours`/`shop_public_settings`; bản đồ giữ iframe |
| `/coupons` | | Bỏ khỏi menu và xóa trang (route bắt-tất-cả sẽ ra 404) |

Header: menu dịch qua i18n (Trang chủ, Sản phẩm, Dịch vụ spa, Giới thiệu, Liên hệ); nút "Đăng nhập" dịch; khi đã đăng nhập, avatar mở menu: Tài khoản, Đơn hàng, Thú cưng, Lịch hẹn, Đăng xuất (thêm "Trang quản trị" nếu là nhân viên). Footer có link các trang trên.

Mọi trang shop đặt `useHead` tiêu đề riêng; trạng thái đang tải dùng skeleton, rỗng có hình `empty-box.png`, lỗi có nút thử lại.

### 6.2 Admin (chạm nhẹ)

- Bảng lịch spa và danh sách lịch hẹn: nhãn **Web** cho `source = 'web'`; phiếu chưa xếp người đã có cột riêng (`board/layout.ts`), chỉ cần kiểm tra lịch web hiện đúng ở đó.
- Chi tiết khách hàng: nút **Liên kết tài khoản web** mở ô tìm tài khoản (dùng `search_customers` vốn đã trả cả tài khoản chưa có hồ sơ), gọi `link_customer_account`.
- Huy hiệu số lịch web mới chưa xếp người trên menu "Lịch spa": **để sau**, không làm ở bước này.

## 7. Cấu trúc file frontend

Theo [view-structure.md](view-structure.md) và quy tắc tách file: page dưới `src/pages` chỉ 10-15 dòng; view là vỏ mỏng ghép component; state ở composable `useXxx`; hàm thuần ở `src/utils`; type ở `src/types`; gọi Supabase ở `src/repositories`, hook vue-query ở `src/queries`. Mỗi file `.vue`/`.ts` dưới khoảng 300 dòng.

```
src/pages/
  products/index.vue, products/[id].vue
  spa/index.vue, spa/book.vue
  account.vue                      # layout con có <NuxtPage />, requiresAuth
  account/index.vue, profile.vue, addresses.vue, orders.vue, pets.vue, appointments.vue
  profile.vue                      # navigateTo('/account/profile')
src/views/client/
  layout/          AccountMenu.vue, ClientFooter.vue, ClientNavLinks.vue
  catalog/         Index.vue, components/{CatalogFilters,CategoryTree,BrandFilter,CatalogSort,CatalogGrid,CatalogCard}.vue
  product/         Index.vue, components/{ProductBreadcrumb,ProductBuyBox,ProductDescription,RelatedProducts}.vue
  account/         AccountShell.vue, components/AccountNav.vue, overview/Index.vue
  account/profile/ Index.vue, components/{ProfileForm,GoogleLink}.vue
  account/pets/    Index.vue, components/{PetCard,PetFormDialog,PetFormFields}.vue
  account/appointments/ Index.vue, components/{AppointmentCard,CancelAppointmentDialog}.vue
  spa/catalog/     Index.vue, components/{ServicePriceTable,ComboList}.vue
  spa/booking/     Index.vue, components/{BookingSteps,StepBranch,StepPets,StepServices,StepSlot,StepConfirm,SlotGrid}.vue
  about/           Index.vue
  contact/         Index.vue (thay ContactView.vue), components/BranchContactCard.vue
src/composables/
  shop/            useCatalogFilters.ts (đồng bộ URL query), useCatalog.ts, useProductPage.ts
  account/         useProfileForm.ts, useEnsureCustomer.ts, usePetForm.ts, useMyPets.ts, useMyAppointments.ts
  spa/             useBookingWizard.ts (bước, lựa chọn), useBookingSlots.ts, useBookingQuote.ts
src/repositories/
  shop/catalog.ts
  account/{profile,pets,appointments,index}.ts
  spaWeb/{catalog,booking,index}.ts
src/queries/       shopCatalog.ts, account.ts, spaWeb.ts (+ khóa mới trong keys.ts)
src/types/         catalog.ts, account.ts, spaWeb.ts
src/utils/
  shop/catalog.ts  (nhãn giá "Từ ...", query <-> filter)
  account/pet.ts   (tuổi từ ngày sinh, nhãn giới tính)
  spa/booking.ts   (xếp phiếu liền nhau, tổng thời lượng, tạm tính, ngày được chọn)
src/validations/   account.ts (hồ sơ, thú cưng)
```

`RegisterForm.vue` (765 dòng) và `views/home/constants.ts` phần `rawProducts` bị xóa ở bước 1, `CardProduct.vue` xóa nếu không còn nơi dùng. `lib/navigations.ts` thay `clientNav` bằng danh sách mới có khóa i18n và thêm `ACCOUNT_NAV`.

i18n: thêm khóa vào cả `vi.json` và `en.json` dưới `shop.catalog.*`, `shop.product.*`, `account.*`, `spaWeb.*`, `nav.*`. Không để chuỗi cứng trong template.

## 8. Thứ tự làm (cho thread code)

Mỗi bước là một PR nhỏ, squash merge, commit tiếng Anh. Bước có SQL ghi rõ tên migration trong mô tả PR.

| Bước | Nội dung | SQL |
| --- | --- | --- |
| **1. Khung và dọn dẹp** | Header/menu i18n, menu tài khoản ở avatar, footer mới; trang chủ bỏ dữ liệu mẫu và `RegisterForm`, thêm CTA đặt lịch; `/about-us` và `/contact` thật; bỏ `/coupons`; `useHead` cho các trang shop | Không |
| **2. Danh sách sản phẩm** | `/products` với lọc, tìm, sắp xếp, "Xem thêm", lọc trên URL; trang chủ dùng RPC mới | `20261017010000_shop_catalog.sql` |
| **3. Chi tiết sản phẩm** | `/products/[id]`, link từ thẻ và quick view, sản phẩm liên quan | Không (dùng RPC bước 2) |
| **4. Khu tài khoản và hồ sơ** | `/account/*` với nav, chuyển tab địa chỉ/đơn sang route, form hồ sơ, `/profile` chuyển hướng, trang tổng quan | `20261017020000_my_profile.sql` |
| **5. Thú cưng của tôi** | `/account/pets`, `ensure_my_customer` khi chưa có hồ sơ; admin: nút liên kết tài khoản web | `20261017030000_my_pets.sql`, `20261017030100_link_customer_account.sql` |
| **6. Bảng giá spa** | `/spa` bảng giá theo loài/khung cân nặng | `20261017040000_spa_public_catalog.sql` |
| **7. Đặt lịch spa online** | `/spa/book` wizard; admin: nhãn Web | `20261017050000_spa_web_slots.sql`, `20261017050100_book_my_appointment.sql` |
| **8. Lịch hẹn của tôi** | `/account/appointments`, hủy; ô "lịch sắp tới" trên trang tổng quan | `20261017060000_my_appointments.sql` |

Bước 2-3 độc lập với 4-8, có thể làm trước. Bước 7 cần 5 và 6. Mỗi bước: `npx vue-tsc --noEmit -p .nuxt/tsconfig.app.json` (so với lỗi có sẵn) và `npm run build`; SQL thử trên Postgres local như các module trước nếu được.

## 9. Kịch bản kiểm tra

1. Khách chưa đăng nhập: trang chủ không còn thẻ mẫu; `/products` lọc "Thức ăn" ra cả danh mục con; tìm không dấu "pate ga" ra "Pate gà"; sắp giá tăng đúng; "Xem thêm" nối trang; reload giữ bộ lọc.
2. Chi tiết sản phẩm: chọn biến thể hết hàng bị mờ; đổi đơn vị đổi giá; thêm giỏ cập nhật số trên icon; nhóm ngừng bán hiện thông báo.
3. Đăng nhập lần đầu (chưa có hồ sơ), vào Thú cưng: hỏi tên + SĐT; SĐT mới tạo hồ sơ; SĐT đã có ở quầy báo `phone_in_use`; nhân viên bấm "Liên kết tài khoản web" xong thì khách thấy các thú lễ tân đã tạo.
4. Thêm thú có cân nặng 6kg; sửa; ẩn. Thú đồng sở hữu không sửa được. Thú có lịch chưa xong không ẩn được.
5. `/spa`: bảng giá đúng theo loài và khung cân nặng của cơ sở.
6. Đặt lịch: hôm nay sau 2 giờ mới có giờ; ngày nghỉ không có giờ; 2 thú, mỗi thú 1 dịch vụ 60 phút thì giờ cuối cùng phải đủ 120 phút trước giờ đóng cửa; cơ sở có 2 bàn, đặt 2 lịch cùng giờ được, lịch thứ 3 báo `slot_full`; lịch thứ 4 chưa diễn ra báo `too_many`.
7. Lễ tân thấy lịch web trên bảng ở cột chưa xếp, nhãn Web; xếp người được; xếp trùng giờ người đó bị chặn.
8. Lịch hẹn của tôi: hủy được khi còn hơn 2 giờ; sát giờ báo gọi cửa hàng; lịch đã hủy sang tab Đã qua.
9. Khách A không đọc được thú, lịch, hồ sơ của khách B qua RPC (thử đổi id).
10. Mobile 375px: header, bộ lọc dạng Sheet, wizard đặt lịch không tràn ngang.

## 10. Mặc định đã chọn

| Câu hỏi | Mặc định | Lý do |
| --- | --- | --- |
| "f0" là gì | FE phía khách hàng | Ngữ cảnh "người dùng cuối" |
| Khách có chọn nhân viên/bàn không | Không | Đơn giản, lễ tân xếp; tránh lộ lịch nhân viên |
| Nhiều dịch vụ xếp thế nào | Liền nhau | Không phải giải bài xếp song song |
| Sức chứa khung giờ | Số bàn spa đang hoạt động | Dữ liệu đã có, không cần cài đặt mới |
| SĐT trùng hồ sơ quầy | Không tự nối, nhân viên nối | Chống chiếm hồ sơ người khác, không tốn SMS OTP |
| Đặt lịch cần đăng nhập | Có | Có hồ sơ và thú để tính giá, chống spam |
| URL sản phẩm | Theo id | Không cần migration slug |
| `/coupons` | Xóa tới khi có voucher | Không để trang giả |
| Form tư vấn cũ (`bookings`) | Ngừng dùng trên web, giữ bảng | Không xóa dữ liệu |

## 11. Rủi ro

| Rủi ro | Xử lý |
| --- | --- |
| Hai khách cùng đặt khung cuối cùng một lúc | `book_my_appointment` khóa theo cơ sở + ngày (`pg_advisory_xact_lock`) rồi đếm lại sức chứa trước khi ghi |
| Khung giờ đếm theo bàn nhưng lễ tân xếp theo nhân viên | Chấp nhận cho shop một cơ sở; lễ tân vẫn đổi giờ/hủy được. Xem lại khi có ca làm việc nhân viên |
| Lịch web không ai xếp | Bảng lịch đã hiện cột chưa xếp; huy hiệu đếm để sau |
| Người lạ dùng SĐT khách quen | Không tự nối hồ sơ (3.3) |
| `database.types.ts` lệch với DB | Mỗi bước SQL cập nhật type cùng PR |
| File lớn khó đọc | Cấu trúc mục 7, mỗi file dưới khoảng 300 dòng |

## 12. Kết quả

Cập nhật sau mỗi bước (PR, migration đã chạy, việc còn lại).
