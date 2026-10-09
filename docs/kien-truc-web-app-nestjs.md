# Web + app mobile + backend NestJS: có làm được không?

> Phân tích tính khả thi, ngày 2026-10-09. Dựa trên `main` tại commit a82814b và kế hoạch BA/kiến trúc v0.3.

## 1. Trả lời ngắn

**Được.** Repo hiện tại đã có nền phù hợp cho cả ba: dữ liệu và nghiệp vụ quan trọng nằm trong Postgres (RPC + RLS), còn tầng `src/repositories/` là TypeScript thuần nhận một `SupabaseClient`, không phụ thuộc Vue. Nhờ vậy app mobile và backend riêng dùng lại được phần lớn logic mà không phải viết lại.

**Khuyến nghị:** làm theo mô hình **lai (hybrid)**:

- **Supabase vẫn là lõi**: Postgres, Auth, Storage, RLS/RBAC theo chi nhánh, và các RPC giao dịch (hóa đơn, trừ kho FEFO, ca thu ngân...). Web và app gọi thẳng Supabase cho đọc/ghi thông thường như hiện nay.
- **NestJS đứng cạnh, không đứng giữa**: chỉ nhận những việc Postgres và trình duyệt làm không tốt: webhook thanh toán (SePay), tích hợp GHN, gửi thông báo đẩy, cron đối soát, xuất báo cáo/Excel, tác vụ quản trị cần service role.
- **App mobile bằng Expo (React Native)** cho app khách hàng (Phase 3), dùng chung tầng `repositories` + kiểu dữ liệu + schema zod với web qua monorepo.
- **Không** chuyển toàn bộ sang "NestJS làm BE duy nhất" lúc này: chi phí viết lại lớn, mất lớp bảo vệ RLS, mà không mang lại tính năng mới cho phạm vi Shop + Spa.

## 2. Hiện trạng liên quan

| Thành phần | Hiện có | Ý nghĩa khi thêm app/BE |
| --- | --- | --- |
| Frontend | Nuxt 4, public SSR, `/admin/**` SPA, Pinia, TanStack Query, shadcn-vue | Giữ nguyên; thành `apps/web` |
| Dữ liệu | 19 migration (~4.600 dòng SQL), ~39 Postgres function | Đây là "backend" thật hiện nay; mọi client dùng lại được |
| Nghiệp vụ nhiều bước | `create_invoice`, `cancel_invoice`, `take_stock_fefo`, `post_stock_document`, `open/close_cash_shift`, `create_sales_return`, `save_product_group`... | Giá và tồn kho tính trong DB, client không tự quyết số tiền. Nên giữ ở DB |
| Phân quyền | Auth hook đưa `user_role` vào JWT; `has_permission(perm, method, branch)`; RLS trên các bảng theo quyền | Cùng một JWT dùng được cho web, app và NestJS |
| Tầng truy cập dữ liệu | `src/repositories/*.ts` TS thuần (53 truy vấn bảng, 36 lời gọi RPC); `src/queries/*` là hook Vue Query | `repositories` chia sẻ được; `queries` chỉ dành cho Vue |
| Server | `server/api/ghn/*` (Nuxt server routes), 1 edge function `admin-create-user` | Ứng viên đầu tiên chuyển sang NestJS |
| Upload | Supabase Storage bucket `images`, policy theo thư mục `<userId>/...` | App upload thẳng được, không cần qua BE |
| Realtime | Chưa dùng; có `usePolling` | Supabase Realtime dùng được ở cả web và app |
| Deploy | Vercel (Nuxt) | NestJS cần chỗ chạy tiến trình dài (không hợp Vercel serverless) |

## 3. Ba phương án

| | A. Chỉ Supabase (không NestJS) | **B. Lai: Supabase lõi + NestJS cạnh (khuyến nghị)** | C. NestJS là BE duy nhất |
| --- | --- | --- | --- |
| Web/app gọi | Supabase trực tiếp | Supabase trực tiếp; NestJS cho tích hợp, webhook, job | Chỉ NestJS (REST/GraphQL) |
| Nghiệp vụ | RPC Postgres | RPC Postgres; NestJS gọi lại RPC | Viết lại trong service NestJS |
| Phân quyền | RLS + `has_permission` | Như A; NestJS chỉ thêm guard kiểm JWT | Guard NestJS; RLS bị bỏ qua (kết nối bằng quyền cao) |
| Webhook, cron, push | Edge function + pg_cron, khá chật | NestJS làm, có queue, retry, log | NestJS làm |
| Công viết lại | 0 | Thấp: thêm dần | Cao: ~39 function, toàn bộ repositories, RBAC |
| Rủi ro | Edge function khó debug, khó test khi tích hợp nhiều | Hai nơi chứa logic, cần quy tắc rõ (mục 4) | Sai sót phân quyền khi chuyển; chậm tính năng nhiều tháng |
| Hợp khi | Chưa có tích hợp ngoài | Có SePay/GHN/push, đội 1-2 người | Muốn rời Supabase, tự host, đội BE riêng |

**Vì sao chọn B:** phạm vi đã chốt là Shop + Spa, web trước, app khách ở Phase 3. Những thứ sắp làm (SePay, GHN thật, đối soát, nhắc lịch, push) đều là việc của một backend tiến trình dài, đúng chỗ mạnh của NestJS. Còn CRUD, POS, kho đã chạy tốt trên RPC + RLS; đưa chúng qua NestJS chỉ thêm một chặng mạng và một chỗ phải giữ phân quyền đồng bộ.

## 4. Ranh giới logic: giữ ở đâu?

**Giữ trong Postgres (RPC/migration):**

- Mọi thao tác phải nguyên tử: tạo/hủy hóa đơn, trừ/hoàn kho theo lô (FEFO), phiếu kho, ca thu ngân, đổi trả, sinh mã chứng từ (`next_doc_code`).
- Tính giá, giảm giá vượt ngưỡng cần quyền quản lý, tồn kho bán được (`sellable_stock`).
- RLS và `has_permission()`: lớp chặn thật cho mọi client, kể cả NestJS khi gọi bằng JWT người dùng.
- Tìm kiếm dùng chung (`search_customers`...) theo quy ước hiện có.

**Đưa sang NestJS:**

- Tích hợp bên ngoài: SePay (webhook HMAC, hộp thư `webhook_events`, đối soát 15 phút), GHN (phí, thời gian giao, tạo đơn, callback rồi gọi lại API chi tiết đơn) theo tài liệu [thanh-toan-van-chuyen.md](thanh-toan-van-chuyen.md).
- Thông báo: push (Expo), email/Zalo/SMS sau này; đọc từ bảng outbox do RPC ghi.
- Job định kỳ: đối soát, nhắc lịch spa/tiêm, cảnh báo hết hạn lô.
- Báo cáo nặng, xuất Excel/PDF, nhập dữ liệu Excel.
- Tác vụ quản trị cần service role (tạo tài khoản nhân viên, đang là edge function `admin-create-user`).

**Quy tắc vận hành:**

1. NestJS **không tự viết lại** nghiệp vụ đã có trong RPC; nó gọi RPC.
2. Việc do người dùng bấm: NestJS gọi Supabase **bằng JWT của chính người đó** để RLS vẫn áp dụng. Chỉ webhook/cron mới dùng service role, và chỉ gọi những RPC viết riêng cho việc đó.
3. Ghi bất đồng bộ đi qua bảng outbox/inbox trong DB (có khóa chống trùng), NestJS xử lý idempotent.

## 5. Monorepo và chia sẻ code

Đề xuất cấu trúc (pnpm workspaces + Turborepo):

```
apps/
  web/        Nuxt 4 hiện tại (chuyển nguyên thư mục src/, server/)
  mobile/     Expo (React Native), app khách hàng
  api/        NestJS
packages/
  domain/     database.types.ts, schema zod, hằng số (PAYMENT_METHODS, DISCOUNT_LIMIT...), helper thuần
  data/       repositories/*.ts hiện tại (nhận SupabaseClient, trả dữ liệu)
supabase/     migrations, functions, seed (giữ ở gốc)
```

| Dùng chung được | Không dùng chung được |
| --- | --- |
| `database.types.ts` (sinh 1 lần, mọi app import) | Component Vue (`.vue`, shadcn-vue) |
| `repositories/*` (TS thuần) | Hook `src/queries/*` (Vue Query bản Vue); app viết lại bằng TanStack Query bản React, cùng key và cùng repository bên dưới |
| Schema zod, validate form | Pinia store, layout, i18n setup |
| Quy tắc nghiệp vụ trong DB | Giao diện: app khách là màn hình mới, không phải admin thu nhỏ |

Việc cần sửa khi tách: alias `@/types/...` trong repositories đổi thành import package; `vercel.json` đặt root `apps/web`; chuyển `npm` sang `pnpm` (hoặc giữ npm workspaces nếu muốn ít thay đổi).

## 6. Chọn framework app

| | **Expo / React Native (khuyến nghị)** | Capacitor + Vue (Ionic Vue) | Flutter |
| --- | --- | --- | --- |
| Dùng lại code web | TS: types, repositories, zod | Nhiều nhất: Vue, composable, một phần component | Gần như không (Dart) |
| Cảm giác native, hiệu năng | Tốt | Khá (webview) | Rất tốt |
| Push, OTA update, build store | Có sẵn (expo-notifications, EAS Update/Build) | Có, qua plugin | Có |
| Supabase SDK | supabase-js chạy được | supabase-js | supabase_flutter |
| Cái giá | Học React; UI viết mới | UI "web trong app", dễ bị store đánh giá thấp nếu sơ sài | Học Dart, hai hệ code tách biệt |

**Hệ quả khi web là Vue:** chọn gì thì giao diện app vẫn phải làm riêng, vì app khách (đặt lịch, thú cưng, lịch sử, hóa đơn, điểm) khác hẳn màn hình admin. Phần đáng chia sẻ là tầng dữ liệu và kiểu, mà tầng đó là TS thuần nên Expo dùng được. Nếu muốn **tiết kiệm tối đa** và chỉ cần app đơn giản, Capacitor + Vue là phương án dự phòng hợp lý; còn app cho khách dùng lâu dài thì Expo đáng hơn.

App nội bộ cho nhân viên (POS, kho) **không cần** làm native: admin web chạy trên máy tính/iPad là đủ; có thể thêm PWA nếu cần biểu tượng ngoài màn hình chính.

## 7. Auth và RBAC

- **Một hệ đăng nhập**: Supabase Auth cho cả web, app, NestJS.
  - Web: cookie qua `@nuxtjs/supabase` (như hiện tại).
  - App: supabase-js lưu phiên trong SecureStore; khách đăng nhập OTP qua SĐT (cần nhà cung cấp SMS, có phí theo tin) hoặc email OTP để bắt đầu.
  - NestJS: guard kiểm JWT của Supabase (khóa công khai JWKS), lấy `sub`, `user_role` từ claim; không tự cấp token.
- **RBAC giữ trong DB**: `has_permission(perm, method, branch)` là nguồn sự thật. Guard NestJS chỉ chặn sớm cho rõ lỗi; quyết định cuối vẫn ở RLS/RPC.
- **Việc mới phải làm cho app khách**: policy RLS cho vai trò khách hàng (chỉ thấy thú cưng, lịch hẹn, hóa đơn của mình) và các RPC đặt lịch cho khách. Hiện policy chủ yếu viết cho nhân viên (suy luận từ migration, cần rà kỹ khi bắt đầu Phase 3). Liên kết tài khoản đăng nhập với bản ghi `customers` theo SĐT.

## 8. Realtime, upload, thông báo

- **Realtime**: dùng Supabase Realtime (Postgres changes hoặc broadcast) trực tiếp từ web và app, ví dụ lịch spa cập nhật, trạng thái đơn. RLS áp dụng cho Postgres changes. Không cần WebSocket riêng trong NestJS.
- **Upload**: app upload thẳng lên Storage với policy `<userId>/...` như web. NestJS chỉ cần khi phải xử lý ảnh (resize, xóa EXIF) hoặc cấp signed URL cho file riêng tư (hóa đơn PDF).
- **Push**: RPC ghi vào bảng `notifications_outbox`; NestJS đọc, gửi qua Expo Push, đánh dấu đã gửi. Token thiết bị lưu ở bảng `device_tokens` gắn `auth.uid()`.

## 9. Chi phí ước tính (tham khảo, cần kiểm lại giá tại thời điểm mua)

| Hạng mục | Ước tính |
| --- | --- |
| Supabase Pro | ~25 USD/tháng (đủ cho 1-2 chi nhánh) |
| Host NestJS (Railway / Render / Fly.io, 1 instance nhỏ) | ~5-20 USD/tháng |
| Vercel cho web | Gói hiện tại |
| Apple Developer | 99 USD/năm |
| Google Play | 25 USD một lần |
| Expo EAS | Gói miễn phí đủ lúc đầu; trả phí khi build nhiều |
| SMS OTP | Theo tin nhắn, tùy nhà mạng/brandname |

Chi phí lớn nhất là **công sức**: một người duy trì ba ứng dụng. Phương án B giữ phần này thấp vì NestJS nhỏ và app chỉ có màn hình khách.

## 10. Rủi ro và cách giảm

| Rủi ro | Cách giảm |
| --- | --- |
| Logic nằm hai nơi, lệch nhau | Quy tắc mục 4: nghiệp vụ giao dịch chỉ ở RPC; NestJS chỉ điều phối và tích hợp |
| NestJS dùng service role làm lộ dữ liệu | Thao tác người dùng gọi bằng JWT người dùng; service role chỉ cho webhook/cron, bọc trong module riêng |
| Kiểu dữ liệu lệch giữa web/app/api | Sinh `database.types.ts` một lần vào `packages/domain`, CI kiểm sau mỗi migration |
| Tách monorepo làm hỏng deploy web | Làm thành một PR riêng, không đổi hành vi, kiểm build Vercel trước khi merge |
| App store từ chối / chậm duyệt | Bắt đầu bằng bản TestFlight/Internal testing; chuẩn bị chính sách quyền riêng tư |
| Ít người, nhiều mặt trận | Đúng thứ tự lộ trình: web Shop + Spa xong trước, NestJS chỉ khi cần SePay/GHN, app ở Phase 3 |

## 11. Lộ trình chuyển đổi từng bước

Mỗi bước là một PR độc lập, web đang chạy không bị gián đoạn.

| Bước | Khi nào | Nội dung | Không đụng tới |
| --- | --- | --- | --- |
| 0. Giữ nền sạch | Ngay, liên tục | Repositories tiếp tục TS thuần, không import Vue/Nuxt; nghiệp vụ mới vẫn viết bằng RPC | Mọi thứ |
| 1. Tách monorepo | Khi bắt đầu bước 2 | Chuyển code vào `apps/web`, tách `packages/domain` + `packages/data`, đổi cấu hình Vercel | Hành vi, DB |
| 2. Dựng `apps/api` (NestJS) | Khi làm thanh toán SePay / GHN thật | Guard JWT Supabase, module SePay webhook + đối soát, GHN (chuyển dần `server/api/ghn/*`), deploy riêng | Admin, POS, kho |
| 3. Thông báo và job | Sau bước 2 | Outbox, nhắc lịch, cảnh báo lô sắp hết hạn, chuyển `admin-create-user` sang NestJS | Như trên |
| 4. App khách (Expo) | Phase 3 | Đăng nhập OTP, thú cưng, đặt lịch spa, lịch sử, hóa đơn, push; thêm RLS/RPC cho khách | Admin web |

Nếu sau này cần rời Supabase (tự host, yêu cầu pháp lý), NestJS ở bước 2-3 đã có sẵn, và có thể chuyển dần từng module sang phương án C mà không phải làm lại từ đầu.

## 12. Chi tiết: nếu NestJS là BE duy nhất (phương án C)

> Ước tính cho 1 dev full-stack quen NestJS, làm toàn thời gian. Đội 2 người rút được khoảng 40%, không phải một nửa, vì phần chuyển đổi phải làm tuần tự. Số tiền là giá niêm yết tham khảo, cần kiểm lại khi mua.

### 12.1 Khối lượng việc phải làm

Hiện tại "backend" là 19 migration (~4.600 dòng SQL), ~39 Postgres function, RLS trên các bảng, và 53 truy vấn bảng + 36 lời gọi RPC từ `src/repositories/`. Đưa tất cả qua NestJS nghĩa là:

| Hạng mục | Việc | Công (tuần) |
| --- | --- | --- |
| Nền NestJS | Cấu trúc module, config, kết nối DB (Prisma/Drizzle/TypeORM), log, xử lý lỗi, deploy, CI | 1-2 |
| Auth | Vẫn dùng Supabase Auth và kiểm JWT (nhẹ), hoặc tự làm đăng nhập, refresh token, quên mật khẩu, OTP (nặng hơn ~2 tuần) | 1-3 |
| RBAC | Viết lại `has_permission(perm, method, branch)` thành guard + decorator, lọc dữ liệu theo chi nhánh ở mọi truy vấn | 2-3 |
| API | ~60-80 endpoint thay cho truy vấn trực tiếp: DTO, validate, phân trang + tìm kiếm theo quy ước hiện có | 4-6 |
| Nghiệp vụ | Hoặc giữ RPC và gọi từ NestJS (nhanh), hoặc viết lại hóa đơn, FEFO, phiếu kho, ca thu ngân, đổi trả bằng TS trong transaction (chậm, dễ sai) | 0-6 |
| Web | Đổi tầng `repositories` gọi API thay cho Supabase; sửa lỗi phát sinh ở từng màn hình | 2-3 |
| Upload, realtime | Upload qua API hoặc cấp signed URL; WebSocket/SSE nếu cần realtime | 1-2 |
| Kiểm thử, chạy song song | Test phân quyền theo chi nhánh, so số liệu POS/kho giữa bản cũ và mới | 2-3 |
| **Tổng** | | **~13-28 tuần (3-7 tháng)** |

Trong thời gian đó gần như **không ra tính năng mới** (spa, báo cáo, thanh toán), vì mọi màn hình đều phải sửa lại tầng dữ liệu.

So với phương án B: dựng NestJS cạnh Supabase cho SePay/GHN chỉ tốn ~1-2 tuần cho phần nền, phần còn lại là công của chính tính năng thanh toán, vốn phải làm dù chọn gì.

### 12.2 Chi phí hạ tầng hằng tháng

| | B (khuyến nghị) | C, vẫn giữ Supabase làm DB + Auth | C, rời hẳn Supabase |
| --- | --- | --- | --- |
| Postgres | Supabase Pro ~25 USD | Supabase Pro ~25 USD | Postgres managed (Neon, RDS, DigitalOcean...) ~20-60 USD |
| Auth | Supabase (đã gồm) | Supabase (đã gồm) | Tự làm (0 USD, tốn công) hoặc dịch vụ ngoài theo số người dùng |
| Lưu file | Supabase Storage (đã gồm) | Supabase Storage | S3 / Cloudflare R2 ~1-5 USD |
| Host NestJS | 1 instance nhỏ ~5-20 USD | 2 instance để không chết cả hệ thống khi 1 cái lỗi ~20-50 USD | ~20-50 USD |
| Redis (queue, cache) | Có thể chưa cần | ~0-15 USD | ~0-15 USD |
| Giám sát, log, cảnh báo | Gói miễn phí đủ | Nên trả phí ~0-30 USD | ~0-30 USD |
| **Ước tổng** | **~30-45 USD** | **~45-120 USD** | **~45-160 USD** |

Tiền hạ tầng không chênh nhiều. **Chi phí thật của C là công**: 3-7 tháng của 1 dev, cộng việc vận hành server mà Supabase đang làm hộ.

### 12.3 Rủi ro

| Rủi ro | Mức | Giải thích |
| --- | --- | --- |
| Lộ dữ liệu giữa chi nhánh | Cao | NestJS kết nối DB bằng một tài khoản quyền cao, nên RLS không còn chặn. Chỉ cần một endpoint quên lọc `branch_id` là nhân viên chi nhánh này xem được hóa đơn, kho chi nhánh khác. Hiện nay DB chặn việc đó dù code client có sai. |
| Sai số liệu tiền và kho | Cao (nếu viết lại RPC) | Trừ kho FEFO, hoàn kho khi hủy, khóa ca thu ngân đang chạy đúng trong Postgres. Viết lại bằng TS phải xử lý transaction, khóa dòng, chạy đồng thời; sai là lệch tồn kho, lệch tiền ca. |
| Đóng băng tính năng | Cao | 3-7 tháng không làm spa, báo cáo, thanh toán, trong khi phạm vi đã chốt là Shop + Spa chạy sớm. |
| Một điểm chết | Trung bình | NestJS sập thì POS, admin, shop, app đều ngừng. Hiện nay chỉ phụ thuộc Supabase. |
| Gánh vận hành | Trung bình | Tự lo deploy, scale, bảo mật server, cập nhật thư viện, sao lưu (nếu rời Supabase), trực sự cố. Với 1-2 người là gánh nặng lớn. |
| Chạy hai hệ song song | Trung bình | Trong lúc chuyển, một phần màn hình gọi Supabase, một phần gọi NestJS; quy tắc dễ lệch nhau. |
| Chậm hơn một chút | Thấp | Thêm một chặng mạng client → NestJS → DB; không đáng kể nếu host gần DB. |

**Được gì:** một API duy nhất cho web và app, test nghiệp vụ bằng TS dễ hơn SQL, không phụ thuộc Supabase, dễ tuyển dev NestJS hơn dev Postgres.

**Cách làm C ít rủi ro hơn (nếu vẫn muốn):** NestJS làm cổng duy nhất nhưng **giữ nguyên RPC** và gọi DB **bằng JWT của người dùng** (supabase-js với header `Authorization`), để RLS vẫn chặn. Công giảm còn ~8-14 tuần, rủi ro lộ dữ liệu và sai số liệu gần như về mức của B. Đây cũng là đích tự nhiên nếu đi theo B rồi chuyển dần.

**Khi nào C đáng làm:** có đội backend riêng; phải tự host (yêu cầu pháp lý, khách hàng doanh nghiệp); bán hệ thống cho nhiều chủ cửa hàng (SaaS nhiều tenant); hoặc Supabase không còn đáp ứng được về giá hay tính năng.

## 13. Chi tiết: chi phí và rủi ro khi làm app bằng Expo

### 13.1 Chi phí tiền

| Hạng mục | Chi phí | Ghi chú |
| --- | --- | --- |
| Apple Developer Program | 99 USD/năm | Bắt buộc để lên App Store; đăng ký dạng tổ chức cần mã D-U-N-S (miễn phí, chờ vài ngày đến vài tuần) |
| Google Play Console | 25 USD một lần | Tài khoản cá nhân mới phải cho ~12 người test kín 14 ngày trước khi phát hành; tài khoản tổ chức thì không |
| Expo EAS (build + cập nhật OTA) | Free → ~19 USD/tháng (Starter) → ~199 USD/tháng (Production) | Free đủ khi mới làm (giới hạn số lượt build/tháng, xếp hàng chậm); trả phí khi build nhiều hoặc nhiều người dùng nhận OTA. Có thể tự build trên máy để tránh phí |
| Thông báo đẩy (Expo Push) | 0 USD | Miễn phí; vẫn cần cấu hình APNs (Apple) và FCM (Google) |
| OTP SMS cho khách | Theo tin, ước vài trăm đến hơn 1.000 đồng/tin tùy nhà cung cấp | Supabase Auth gửi SMS qua Twilio/Vonage/MessageBird...; giá về Việt Nam cao hơn nhà cung cấp trong nước. Rẻ hơn: OTP qua email (miễn phí) hoặc Zalo ZNS (cần tích hợp riêng). Cần báo giá thực tế |
| Máy test | 0 nếu đã có iPhone + Android | Build iOS chạy trên cloud EAS nên không bắt buộc có Mac; có Mac thì chạy giả lập tiện hơn |
| Supabase | Không tăng nhiều | Thêm người dùng là khách hàng; gói Pro gồm 100.000 người dùng hoạt động/tháng |
| **Ước tổng năm đầu** | **~125 USD cố định + 0-230 USD/năm EAS + tiền SMS** | |

### 13.2 Chi phí công (1 dev)

| Hạng mục | Tuần |
| --- | --- |
| Học React + React Native (nếu chỉ quen Vue) | 2-4 |
| Tách monorepo, đưa `repositories`/types/zod thành package dùng chung | 1 (đã tính trong bước 1 lộ trình) |
| RLS + RPC cho vai trò khách hàng (chỉ thấy dữ liệu của mình, đặt lịch) | 2-3 |
| App khách ~15 màn: đăng nhập OTP, thú cưng, đặt lịch spa, lịch sử, hóa đơn, điểm, thông báo | 8-10 |
| Chuẩn bị store: icon, ảnh màn hình, chính sách quyền riêng tư, xóa tài khoản trong app, khai báo dữ liệu | 1-2 |
| **Tổng** | **~14-20 tuần**, khớp ước tính Phase 3 trong kế hoạch BA (8-10 tuần cho phần app, chưa tính học và chuẩn bị) |

Hằng năm: nâng cấp Expo SDK (~2-3 bản/năm, mỗi lần 1-3 ngày), cập nhật theo yêu cầu mới của Apple/Google.

### 13.3 Rủi ro

| Rủi ro | Mức | Cách giảm |
| --- | --- | --- |
| Hai bộ giao diện (Vue cho web, React cho app) | Trung bình | Chấp nhận: app khách vốn là màn hình mới. Chỉ chia sẻ tầng dữ liệu, kiểu, zod. Nếu không muốn học React thì dùng Capacitor + Vue (đổi lại cảm giác kém native) |
| Bị store từ chối | Trung bình | Apple hay từ chối app quá đơn giản, thiếu chức năng xóa tài khoản, thiếu chính sách quyền riêng tư. Gửi bản test sớm (TestFlight), chuẩn bị đủ giấy tờ. App bán hàng hóa/dịch vụ thật nên không bắt buộc dùng thanh toán trong app của Apple |
| Lỗi khi nâng SDK, thư viện native | Thấp-Trung bình | Dùng thư viện có sẵn trong Expo; tránh thư viện native lạ; nâng SDK theo từng bản |
| Chi phí SMS tăng, bị phá bằng spam OTP | Trung bình | Giới hạn số lần gửi theo SĐT/IP, captcha, ưu tiên OTP email hoặc Zalo |
| Lộ dữ liệu khách khác | Cao nếu làm ẩu | App gọi thẳng Supabase, nên RLS cho khách phải viết và test kỹ trước khi phát hành |
| Một người giữ ba ứng dụng | Trung bình | Làm app sau khi web Shop + Spa ổn định (Phase 3), đúng lộ trình |
| Phụ thuộc dịch vụ Expo | Thấp | Expo là mã nguồn mở; nếu bỏ EAS vẫn build được bằng công cụ chuẩn của Apple/Google |

## 14. Cần chủ dự án quyết

1. Đồng ý phương án B (Supabase lõi + NestJS cạnh) thay vì NestJS làm BE duy nhất.
2. App khách dùng Expo (khuyến nghị) hay Capacitor + Vue (rẻ hơn, kém native hơn).
3. Thời điểm tách monorepo: cùng lúc bắt đầu SePay/GHN (khuyến nghị) hay làm ngay.
