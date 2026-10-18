# Chống clone và mạo danh

Không thể chặn hoàn toàn việc sao chép giao diện một website công khai: ai cũng tải được HTML, CSS, JS. Mục tiêu ở đây là:

1. Giá trị thật (giá, tồn kho, đơn hàng, hồ sơ thú cưng, quyền) nằm ở server, có RLS và kiểm quyền, bản sao không lấy được.
2. Không cho trang khác nhúng (iframe) hay chạy nguyên bản site của mình trên domain của họ.
3. Bản giả dễ bị phát hiện: công cụ tìm kiếm luôn trỏ về domain thật, có quy trình theo dõi và báo cáo.

Ngày rà soát: 2026-10-18.

## 1. Các lớp phòng thủ đã làm

### 1.1. Header bảo mật

| Header | Giá trị | Đặt ở đâu |
| --- | --- | --- |
| `Content-Security-Policy` | xem bên dưới | `apps/web/server/middleware/security-headers.ts` (cần URL Supabase lúc chạy) |
| `X-Frame-Options` | `SAMEORIGIN` | `routeRules["/**"].headers` trong `nuxt.config.ts` |
| `X-Content-Type-Options` | `nosniff` | như trên |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | như trên |
| `Permissions-Policy` | tắt camera, micro, vị trí, thanh toán, USB | như trên |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` | như trên |

Giá trị nằm ở `apps/web/config/securityHeaders.ts` (hàm thuần, có test `tests/unit/securityHeaders.test.ts`). Header tĩnh đi qua `routeRules` nên CDN của Vercel gửi cả cho file tĩnh.

CSP:

```
default-src 'self';
script-src 'self' 'unsafe-inline';
style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
font-src 'self' data: https://fonts.gstatic.com;
img-src 'self' data: blob: https:;
connect-src 'self' https://<project>.supabase.co wss://<project>.supabase.co;
frame-src https://www.google.com;
frame-ancestors 'self';
worker-src 'self' blob:; manifest-src 'self';
object-src 'none'; base-uri 'self'; form-action 'self'
```

- `frame-ancestors 'self'` + `X-Frame-Options` chặn trang khác nhúng site trong iframe (chống clickjacking và "bọc" site thật).
- `'unsafe-inline'` cho script còn giữ vì Nuxt chèn script khởi động inline. Muốn bỏ phải dùng nonce (module `nuxt-security`), để sau.
- `img-src https:` mở cho mọi host https vì ảnh sản phẩm có thể là URL dán vào (Unsplash, pethaven, Google avatar...).
- `frame-src https://www.google.com` cho bản đồ ở trang Liên hệ.
- Không có `'unsafe-eval'`. CSP không bật khi `nuxt dev` (Vite HMR cần eval).
- App Capacitor là bản build tĩnh, không qua server nên không nhận các header này; app gọi `/api/ghn/*` vẫn chạy như cũ (CORS ở `server/middleware/ghn-cors.ts`).

Đã kiểm trên bản `nuxt build` chạy bằng Chromium: trang chủ, sản phẩm, chi tiết sản phẩm, liên hệ (bản đồ Google), spa, đặt lịch, lưu trú, giỏ, checkout, đăng nhập, đăng ký, giới thiệu, admin: không có vi phạm CSP nào; nhúng site trong iframe từ origin khác bị chặn.

### 1.2. Chặn chạy trên domain lạ

- `apps/web/src/plugins/domain-guard.client.ts` chạy đầu tiên trên trình duyệt. Nếu `location.hostname` không nằm trong danh sách cho phép thì `location.replace` sang cùng trang trên domain thật (giữ path, query, hash). Không chạy trong app Capacitor.
- Danh sách cho phép: `runtimeConfig.public.allowedHosts` (mặc định `bong-cun.vercel.app, bong-cun-*-ptthaothaos-projects.vercel.app, localhost, 127.0.0.1`: production, preview của team Vercel này và máy dev), domain thật: `runtimeConfig.public.siteUrl` (mặc định `https://bong-cun.vercel.app`). Đổi bằng biến môi trường `NUXT_PUBLIC_ALLOWED_HOSTS`, `NUXT_PUBLIC_SITE_URL`. Dấu `*` chỉ khớp trong một nhãn domain (không vượt dấu chấm).
- Lớp này chặn kiểu clone "proxy/mirror" (chạy nguyên site của mình qua domain khác). Kẻ tải mã về và xoá plugin thì vẫn dựng được giao diện, nhưng không có dữ liệu thật ngoài phần công khai (xem mục 2).

### 1.3. Canonical

`useCanonicalLink()` (gọi trong `app.vue`) thêm `<link rel="canonical">` và `og:url` cho mọi trang, luôn là `siteUrl + path` (bỏ query). Bản sao copy nguyên HTML vẫn chỉ Google về domain thật.

Code: `apps/web/src/features/shared/security/` (helpers thuần có test `tests/unit/hostAllowlist.test.ts`).

### 1.4. Giới hạn tần suất (rate limit)

- `apps/web/server/middleware/rate-limit.ts`: giới hạn theo IP cho route `/api/*` (proxy GHN). Báo giá ship/thời gian giao: 30 lần/phút; tra tỉnh/huyện/xã: 120 lần/phút. Quá hạn trả 429 kèm `Retry-After`.
- Bộ đếm nằm trong bộ nhớ của từng instance Vercel, nên đây là lớp làm chậm scraper và vòng lặp lỗi, không phải hạn mức tuyệt đối. Muốn chặt hơn: Cloudflare rate limiting (mục 4) hoặc Upstash Redis.
- Tìm kiếm và đặt đơn không đi qua Nitro: trình duyệt gọi thẳng Supabase. Giới hạn cho đặt đơn phải nằm trong database (mục 3, điểm M2).

### 1.5. Response công khai

Các RPC công khai cho khách chưa đăng nhập chỉ trả dữ liệu catalog: `shop_product_groups`, `shop_related_groups`, `shop_cart_lines`, `shop_public_settings`, `spa_public_catalog`, `spa_web_slots`, `boarding_public_catalog`. Không có cột giá vốn, nhà cung cấp hay tồn kho theo lô. Bảng sản phẩm đọc công khai không có cột giá vốn. Phần còn hở nhỏ xem điểm L3.

## 2. Vì sao bản clone không lấy được dữ liệu thật

Anon key của Supabase là công khai (nằm trong JS), nên một bản clone có thể gọi thẳng Supabase của mình từ domain khác (REST của Supabase cho mọi origin). Vì vậy bảo vệ thật là RLS và kiểm quyền trong hàm, không phải CORS:

- Mọi bảng `public` đều bật RLS.
- Khách chưa đăng nhập chỉ đọc catalog (sản phẩm, dịch vụ, chi nhánh, banner) và gọi các RPC công khai ở mục 1.5.
- Khách đã đăng nhập chỉ thấy đơn, lịch hẹn, thú cưng của chính mình.
- Mọi việc của nhân viên đi qua hàm `security definer` có kiểm `can_*`/`has_permission` theo chi nhánh.

## 3. Báo cáo rà soát Supabase

Nguồn: Supabase security advisor (`get_advisors`) và truy vấn chỉ đọc trên project `bongcun-manager` ngày 2026-10-18 (policy, quyền EXECUTE, nội dung hàm, bucket). Không sửa gì trên production.

### Điểm hở

| Mã | Mức | Vấn đề | Hướng xử lý |
| --- | --- | --- | --- |
| M1 | Trung bình | Bảng `bookings` (form "Đặt lịch" cũ, không còn màn nào dùng, 0 dòng) có policy `public create` cho `anon`: ai cũng chèn dòng không giới hạn, kể cả từ bản clone. | Migration bỏ policy này. Nhân viên vẫn tạo được qua policy `permission insert`. |
| M2 | Trung bình | Đặt đơn online (`place_shop_order`) không giới hạn số đơn. Đơn `pending`/`confirmed` giữ chỗ tồn kho online (`shop_available_qty`), nên một tài khoản có thể tạo hàng loạt đơn để "khoá" hàng tới khi job tự hủy chạy (48 giờ). | Migration thêm trigger: mỗi tài khoản tối đa 5 đơn đang chờ xác nhận và 10 đơn trong 1 giờ; lỗi trả hint `too_many_orders`, màn checkout hiện câu dễ hiểu. |
| M3 | Trung bình | Bucket công khai `images`: mọi tài khoản đã đăng nhập (kể cả khách tự đăng ký) upload được ảnh 5 MB vào thư mục của mình, có link công khai. Có thể bị dùng làm chỗ chứa ảnh miễn phí cho trang giả. Hiện chưa có file nào của khách. | Migration chỉ cho nhân viên (`is_staff()`) upload vào thư mục riêng. Chỉ màn admin dùng tính năng này. |
| L1 | Thấp | Supabase Auth chưa bật "Leaked password protection" (chặn mật khẩu đã lộ, theo HaveIBeenPwned). | grace bật trong Dashboard (mục 4). Có thể cần gói Pro. |
| L2 | Thấp | `is_display_name_available` cho `anon`: dò được một tên hiển thị đã có người dùng chưa. | Giữ, màn đăng ký cần. |
| L3 | Thấp | `products`, `product_groups`, `product_units` và bảng giá đọc công khai cả dòng đang ẩn và nhóm `clinic_only`: lộ tên, giá của hàng đang ẩn hay thuốc chỉ bán tại phòng khám. Không lộ giá vốn. | Chưa sửa: trang shop đang đọc thẳng các bảng này, muốn siết phải chuyển sang RPC. Ghi lại để làm khi cần. |
| I1 | Rất thấp | Hàm trigger `pets_deceased_after/before` còn quyền EXECUTE cho `anon`/`authenticated` (gọi trực tiếp sẽ lỗi vì không phải trigger). View `pet_overview` còn GRANT cho `anon` (view là `security_invoker`, RLS vẫn chặn). | Migration thu hồi cho gọn. |

### Đã kiểm, không có vấn đề

- Mọi bảng `public` bật RLS. Ba bảng bật RLS mà không có policy (`doc_sequences`, `ping_config`, `ping_log`) là cố ý: chặn mọi truy cập từ API.
- 172 hàm `security definer` mà `authenticated` gọi được: mọi hàm hoặc kiểm `can_*`/`has_permission` ngay đầu, hoặc gọi hàm dùng chung có kiểm (`shop_order_for_update`, `list_appointments`, `boarding_apply_stay`). Các hàm nội bộ (trừ kho FEFO, mã chứng từ, lõi báo cáo, import, tính giá) đã thu hồi EXECUTE khỏi `anon` và `authenticated`.
- RPC tìm kiếm dùng chung: `search_unlinked_accounts` kiểm `can_link_accounts()`; các RPC `list_*`/`report_*` kiểm quyền theo chi nhánh.
- Khách chỉ xem thú cưng: `pets` chỉ cho thêm/sửa/xoá khi có quyền `pets` hoặc là admin; khách đọc qua `my_pets()`. `customers` tương tự.
- Admin tách quyền rõ: `roles`, `role_permissions`, `staff_branches` chỉ superAdmin sửa; trigger `guard_user_columns` chặn người dùng tự đổi `role`, `email`, `id` của mình.
- Storage: `medical` riêng tư, chỉ người có quyền y tế; `pet-photos` chỉ người có quyền `pets` upload/xoá; ảnh catalog chỉ người có quyền sản phẩm.

### Migration đề xuất

`supabase/migrations/20261026010000_security_hardening.sql` (PR riêng, chờ grace duyệt vì workflow "Supabase migrate" tự chạy khi merge). Forward-only, chạy lại được (`drop policy if exists`, `create or replace`, `drop trigger if exists`). Ảnh hưởng tới dữ liệu đang chạy:

- M1: không mất dữ liệu (bảng trống), form công khai đã không còn.
- M2: chỉ chặn đơn mới vượt ngưỡng, không đụng đơn cũ. Khách đang có 5 đơn chờ sẽ phải đợi shop xác nhận/hủy bớt mới đặt tiếp.
- M3: file cũ giữ nguyên; khách không upload được nữa (hiện không màn khách nào upload).
- I1: không ảnh hưởng.

## 4. Việc grace tự làm thủ công

- [ ] Supabase Dashboard → Authentication → URL Configuration: **Site URL** là domain thật (`https://bong-cun.vercel.app` hoặc domain riêng sau này); **Redirect URLs** chỉ gồm domain thật, `http://localhost:3004/**` khi cần dev, và scheme của app mobile nếu dùng. Xoá mọi URL lạ.
- [ ] Supabase Dashboard → Authentication → Attack Protection (hoặc Policies → Password): bật **Leaked password protection** (điểm L1) nếu gói cho phép.
- [ ] Vercel → Project → Settings → Environment Variables (khi có domain riêng): đặt `NUXT_PUBLIC_SITE_URL=https://<domain thật>` và `NUXT_PUBLIC_ALLOWED_HOSTS=<domain thật>,www.<domain thật>,bong-cun.vercel.app,bong-cun-*-ptthaothaos-projects.vercel.app,localhost,127.0.0.1`. Nếu đổi tên team trên Vercel thì sửa mẫu preview theo.
- [ ] Cloudflare (khi có domain riêng): trỏ DNS qua Cloudflare, bật proxy (đám mây cam); bật **Bot Fight Mode** và WAF managed rules gói Free; thêm rate limiting rule cho `/api/*`; nếu bị spam đăng ký/đặt đơn thì thêm **Turnstile** cho form đăng nhập/đăng ký/checkout (cần sửa code, báo Claude làm).
- [ ] Theo dõi domain giả: đặt lịch xem [crt.sh](https://crt.sh/?q=pawtiny) (và [bongcun](https://crt.sh/?q=bongcun)) với các từ khoá "pawtiny", "bongcun", "bong-cun", "bông cún" (chứng chỉ mới cho domain na ná); tạo Google Alerts cho tên shop, số điện thoại và địa chỉ cửa hàng.
- [ ] Khi phát hiện bản giả: chụp màn hình, lưu URL và thời gian; tra nhà đăng ký domain và nơi host bằng `whois`/ICANN Lookup; gửi báo cáo abuse cho nhà đăng ký và nhà host (kèm bằng chứng và link site thật); báo Google Safe Browsing (safebrowsing.google.com/safebrowsing/report_phish) và gửi yêu cầu gỡ theo DMCA tới Google Search; nếu dùng Vercel/Netlify/Cloudflare thì dùng form abuse của họ.
- [ ] Sau khi merge PR migration: kiểm lại Security Advisor trong Dashboard, cảnh báo về `bookings`/trigger phải hết.

## 5. Giới hạn còn lại

- Giao diện và mã frontend luôn sao chép được; plugin chặn domain chỉ bắt được bản chạy nguyên mã của mình.
- `script-src 'unsafe-inline'` còn đó; bỏ được khi chuyển sang nonce.
- Rate limit ở Nitro chỉ theo từng instance; tìm kiếm catalog (RPC Supabase) không có rate limit riêng ngoài giới hạn chung của Supabase.
- Điểm L2, L3 giữ nguyên có chủ đích (mục 3).
