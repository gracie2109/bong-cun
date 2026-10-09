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

## 12. Cần chủ dự án quyết

1. Đồng ý phương án B (Supabase lõi + NestJS cạnh) thay vì NestJS làm BE duy nhất.
2. App khách dùng Expo (khuyến nghị) hay Capacitor + Vue (rẻ hơn, kém native hơn).
3. Thời điểm tách monorepo: cùng lúc bắt đầu SePay/GHN (khuyến nghị) hay làm ngay.
