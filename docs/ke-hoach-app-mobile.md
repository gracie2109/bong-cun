# Kế hoạch app mobile cho khách hàng

Ngày: 2026-10-17. Yêu cầu của grace: "giờ bắt đầu lên plan làm app". Tài liệu này chỉ là kế hoạch, **không đổi code**. Thread code (Sonnet) làm theo mục 11, mỗi bước một PR.

Đọc kèm: [ke-hoach-monorepo.md](ke-hoach-monorepo.md) (giai đoạn 6 và câu hỏi Q3), [giao-dien-khach-hang.md](giao-dien-khach-hang.md), [he-thong-giao-dien-shop.md](he-thong-giao-dien-shop.md), PR #53 (phân tích NestJS và app trước đây, vẫn để mở, không merge).

Số liệu đo trên `main` commit `6ec846a`: 96 file `.vue` phía khách trong `features/shop`, `features/home`, `features/auth`; các màn khách nằm dưới `src/pages` ngoài `admin/`; proxy GHN ở `apps/web/server/api/ghn` (5 route).

## 1. Tóm tắt quyết định

| # | Câu hỏi | Chọn | Lý do ngắn |
| --- | --- | --- | --- |
| D1 | App cho ai? | **Khách hàng** | Đúng quyết định cũ ("app khách ở Phase 3", monorepo mục 6: không làm admin trên mobile). Nhân viên đã dùng web trên máy tính/iPad; màn admin toàn bảng lớn, không hợp điện thoại. |
| D2 | Viết bằng gì? (Q3 của kế hoạch monorepo) | **Capacitor bọc phần khách của `apps/web`, build thành SPA tĩnh** | Dùng lại gần như toàn bộ 96 file giao diện khách đã làm và đã test; một bộ UI để sửa; grace đã quen Vue; chi phí thấp. Vẫn học được phần "app thật": dự án Android, plugin native, ký app, CI build, phát hành. |
| D3 | Code app nằm đâu? | `apps/mobile` chỉ chứa vỏ Capacitor (cấu hình, thư mục `android/`). Giao diện vẫn ở `apps/web`, có thêm **đích build `mobile`**. Phần riêng cho app nằm ở `apps/web/src/features/native/` | Không copy màn hình sang app thứ hai, không vi phạm luật "app không import app" (vỏ chỉ lấy thư mục build, không import code). |
| D4 | Đăng nhập trên app | Email + mật khẩu và mã OTP như web; phiên lưu trong `localStorage` của WebView (`useSsrCookies: false` ở đích mobile). Ẩn nút Google ở bản đầu | Luồng xác minh email và quên mật khẩu đã dùng mã (`verifyOtp`), không cần link mở app. Google cần deep link, để bước tuỳ chọn M9. |
| D5 | Proxy GHN (chọn tỉnh/huyện, phí ship) | App gọi thẳng `https://bong-cun.vercel.app/api/ghn/*` qua cấu hình `apiBase`, mở CORS cho origin của app | Không dựng hạ tầng mới. Chuyển sang edge function chỉ khi bỏ Vercel. |
| D6 | Offline | **Không làm chế độ offline**. Có dải báo "Mất kết nối" và nút thử lại | Tồn kho, giờ trống spa, giá đều phải lấy mới; ghi offline rồi đồng bộ dễ sai tiền. |
| D7 | Thông báo | Bản đầu: không. Bản 1.1: **thông báo cục bộ** nhắc lịch spa và ngày gửi lưu trú (không cần server, không tốn tiền). Push từ server (FCM) để sau | Thông báo cục bộ đủ cho nhắc lịch; push server cần bảng token, edge function, trigger, và tài khoản Apple cho iOS. |
| D8 | Nền tảng và phát hành | **Android trước**, file APK do GitHub Actions build (miễn phí vì repo public), grace tải về cài. Lên Google Play và iOS là quyết định sau | Không tốn tiền ở giai đoạn thử. Play tốn 25 USD và tài khoản cá nhân mới phải test kín 12 người trong 14 ngày; iOS tốn 99 USD/năm, cần máy Mac hoặc runner macOS, và Apple hay từ chối app chỉ bọc web (guideline 4.2). |
| D9 | iPad/iPhone trong lúc chưa có app iOS | Tuỳ chọn M10: cho web cài được lên màn hình chính (PWA: manifest, icon) | Rẻ, grace dùng iPad thường xuyên. |
| D10 | Database | **Không thêm migration** ở các bước M1 đến M8 | App dùng đúng RPC và RLS mà web khách đang dùng. Khách vẫn chỉ xem thú cưng (quyết định 2026-10-15), nên app không cần upload ảnh. |

### Vì sao không chọn Expo (React Native) lúc này

PR #53 từng đề xuất Expo. Ưu điểm: cảm giác native hơn, học thêm React Native. Nhưng phải viết lại khoảng 25 màn khách (danh sách và chi tiết sản phẩm, giỏ, thanh toán, đơn, đặt lịch spa, lưu trú, thú cưng và sổ sức khỏe, tài khoản, địa chỉ) bằng component khác, rồi giữ hai bộ giao diện khớp nhau. Với dự án cá nhân chưa có doanh thu, đó là phần lớn công sức mà người dùng chưa cần. Vì `packages/core` và `packages/supabase` không phụ thuộc Vue, nếu sau này muốn chuyển sang Expo thì phần kiểu, zod, repository vẫn dùng lại được; chỉ viết lại lớp giao diện.

### Vì sao không trỏ app vào website (`server.url`)

Capacitor cho phép app chỉ mở `https://bong-cun.vercel.app`. Nhanh nhất, không cần build lại khi đổi giao diện, nhưng Capacitor ghi rõ chế độ này dành cho dev, mất kết nối là app trắng trang, và Apple từ chối. Bản build kèm sẵn file web vẫn là cách đúng; đổi giao diện thì build APK mới (CI tự làm).

## 2. Phạm vi bản đầu (v1)

Có trong app (đúng các màn khách đang có trên web):

| Nhóm | Màn | Đường dẫn hiện có |
| --- | --- | --- |
| Trang chủ | Banner, danh mục, hàng mới, spa, ghé cửa hàng | `/` |
| Mua hàng | Danh sách, chi tiết sản phẩm, giỏ, thanh toán (COD/chuyển khoản như web), đơn hàng | `/products`, `/products/[id]`, `/cart`, `/checkout`, `/orders/[code]` |
| Spa | Bảng giá, đặt lịch | `/spa`, `/spa/book` |
| Lưu trú | Giới thiệu, gửi yêu cầu | `/boarding` |
| Tài khoản | Tổng quan, hồ sơ, địa chỉ, đơn, lịch hẹn, lưu trú, thú cưng và sổ sức khỏe | `/account/**` |
| Đăng nhập | Đăng nhập, đăng ký, quên mật khẩu (mã OTP) | `/login`, `/register`, `/forgot-password` |
| Khác | Liên hệ, giới thiệu | `/contact`, `/about-us` |

Không có trong v1: toàn bộ `/admin/**`, đăng nhập Google, thông báo, chế độ offline, iOS, lên store, thanh toán online (VietQR/SePay vẫn hoãn như checkout bước 9 đến 11).

Nhân viên đăng nhập vào app vẫn chỉ thấy phần khách, kèm một dòng "Quản trị dùng trên web" ở trang tài khoản.

## 3. Kiến trúc trong monorepo

```
apps/
├─ web/                         # Nuxt 4, như hiện tại, thêm đích build "mobile"
│  ├─ nuxt.config.ts            # đọc appTarget, gộp phần cấu hình riêng của mobile
│  ├─ config/mobileTarget.ts    # MỚI: hàm thuần trả phần cấu hình Nuxt cho đích mobile
│  └─ src/features/native/      # MỚI: mọi thứ chỉ chạy trong app
│     ├─ index.ts               # barrel
│     ├─ plugins/native.client.ts      # chỉ đăng ký khi appTarget = mobile
│     ├─ composables/useAppTarget.ts   # isNativeApp, platform
│     ├─ composables/useBackButton.ts  # nút Back Android
│     ├─ composables/useNetworkStatus.ts
│     ├─ composables/useExternalLinks.ts  # tel:, Zalo, bản đồ mở ra ngoài app
│     ├─ components/AppTabBar.vue      # thanh tab dưới
│     ├─ components/AppTabBarItem.vue
│     ├─ components/OfflineBanner.vue
│     ├─ components/StaffWebNotice.vue
│     ├─ helpers/backButton.ts         # hàm thuần: quyết định back hay thoát
│     ├─ helpers/tabs.ts               # danh sách tab, tab nào đang chọn theo route
│     └─ types.ts
└─ mobile/                      # MỚI: vỏ Capacitor, không có code giao diện
   ├─ package.json              # @capacitor/cli, @capacitor/android, các plugin native
   ├─ capacitor.config.ts       # appId vn.bongcun.app, appName "Bông Cún", webDir ../web/.output/public
   ├─ assets/                   # icon.png, splash.png gốc (sinh ra mọi kích thước bằng @capacitor/assets)
   ├─ android/                  # do `npx cap add android` tạo, có commit
   └─ README.md                 # cách build, cài APK
```

Luồng build:

```
npm run generate:mobile -w @bongcun/web    # NUXT_PUBLIC_APP_TARGET=mobile nuxt generate → apps/web/.output/public
npm run sync -w @bongcun/mobile            # npx cap sync android (copy file web + plugin vào android/)
npm run apk -w @bongcun/mobile             # cd android && ./gradlew assembleDebug
```

### 3.1 Đích build `mobile` của `apps/web`

Biến `NUXT_PUBLIC_APP_TARGET` (`web` mặc định, `mobile` khi build app). `config/mobileTarget.ts` trả phần cấu hình gộp vào `defineNuxtConfig` khi là mobile:

- `ssr: false` toàn bộ (WebView không có server). `useServerPrefetch` dùng `onServerPrefetch`, ở SPA nó không chạy, query vẫn tự lấy dữ liệu ở client, nên không phải sửa màn nào.
- Hook `pages:extend` bỏ mọi route bắt đầu bằng `/admin` (và `admin.vue`), để bundle app không chứa admin. Kiểm bằng cách tìm chuỗi `admin` trong tên chunk sau khi build.
- `plugins`: thêm `features/native/plugins/native.client.ts`.
- `supabase.useSsrCookies: false` để `@nuxtjs/supabase` lưu phiên trong `localStorage` (cookie trên origin của WebView không đáng tin, nhất là iOS sau này).
- `runtimeConfig.public.apiBase = "https://bong-cun.vercel.app"` (ghi đè được bằng `NUXT_PUBLIC_API_BASE`).
- `nitro.preset` không cần đổi: `nuxt generate` với `ssr: false` cho ra `index.html` và `200.html`; Capacitor trả `index.html` cho mọi đường dẫn không có đuôi file, nên `/products/123` mở được.

Bản web trên Vercel không đổi gì: `appTarget` mặc định `web`, plugin native không được đăng ký.

### 3.2 Ranh giới và luật dependency-cruiser

Thêm vào `apps/web/.dependency-cruiser.cjs`:

- `native-only-in-native-feature`: chỉ `src/features/native/**` được import `@capacitor/*`.
- `admin-not-native`: `features/admin` không import `features/native`.
- Feature khác dùng `features/native` qua `index.ts` (đã có luật `feature-via-index`).

`packages/core` và `packages/supabase` không đổi, không được import Capacitor (luật hiện có đã cấm DOM và framework trong `core`).

### 3.3 Phụ thuộc

Plugin Capacitor phải khai ở `package.json` của `apps/mobile` (để `cap sync` thấy và gắn vào dự án Android) **và** ở `apps/web` (vì code web import chúng). Hai nơi giữ cùng một số phiên bản; npm workspaces chỉ cài một bản ở gốc. Ghi chú quy tắc này trong `apps/mobile/README.md`.

Gói dự kiến (Capacitor 8, bản hiện tại 8.5.x): `@capacitor/core`, `@capacitor/app` (nút back, mở lại app), `@capacitor/status-bar`, `@capacitor/splash-screen`, `@capacitor/keyboard`, `@capacitor/network`, `@capacitor/browser` (mở link ngoài). Bản 1.1 thêm `@capacitor/local-notifications`. Dev: `@capacitor/cli`, `@capacitor/android`, `@capacitor/assets`.

Android build cần JDK 21 và Android SDK (runner `ubuntu-latest` có sẵn SDK; JDK cài bằng `actions/setup-java`). `minSdk` theo mặc định của Capacitor 8.

## 4. Đăng nhập và phiên

- Phiên Supabase lưu trong `localStorage` của WebView, tự làm mới token như web. Xoá dữ liệu app thì phải đăng nhập lại; chấp nhận được.
- Middleware `auth.global.ts` giữ nguyên (đã chờ `auth.init()` trước khi kiểm quyền).
- Đăng ký và quên mật khẩu dùng mã OTP trong email, gõ vào app, không có link phải mở lại app. M1 phải kiểm hai template `supabase/templates/confirm-signup.html` và `recovery.html` chỉ hiện mã; nếu có link thì link đó mở web, vẫn không hỏng gì.
- Nút "Đăng nhập bằng Google" và "Liên kết Google" ẩn khi `isNativeApp` (OAuth đang chuyển cả trang về `window.location.origin`, trong app sẽ không quay về được).
- Nếu sau này thấy app hay bị đăng xuất (WebView xoá `localStorage`), chuyển sang lưu phiên bằng `@capacitor/preferences` qua `clientOptions.auth.storage`. Không làm trước.

## 5. Gọi API ngoài Supabase

Chỉ có proxy GHN (`location.service.ts`, `shipment.service.ts` đang gọi `/api/ghn/...` đường tương đối).

- Thêm helper thuần `apiUrl(base, path)` (một file, có test) và composable nhỏ đọc `runtimeConfig.public.apiBase`. Bản web để `apiBase` rỗng nên vẫn gọi đường tương đối như cũ.
- Ở `nuxt.config.ts`, `routeRules["/api/ghn/**"]` thêm header CORS cho đúng các origin của app: `https://localhost` (Android) và `capacitor://localhost` (iOS sau này). Không mở `*`.
- Token GHN vẫn chỉ nằm ở biến môi trường Vercel, app không chứa.

## 6. Giao diện cho cảm giác app

Không vẽ lại màn nào; chỉ đổi khung:

- `layouts/client.vue`: khi `isNativeApp`, thay `ClientFooter` bằng `AppTabBar` (Trang chủ, Sản phẩm, Spa, Giỏ hàng có số lượng, Tài khoản) và chừa khoảng `env(safe-area-inset-bottom)`. `ShopHeader` giữ, ẩn các link trùng với tab nếu cần (làm ở M6, xem trên máy thật rồi quyết).
- Thanh trạng thái màu cam của shop; splash và icon từ một ảnh gốc 1024px (grace đưa logo, nếu chưa có thì dùng chữ "BC" trên nền cam tạm).
- Nút Back Android: có lịch sử thì lùi trang, đang ở trang chủ thì thoát app; đang mở sheet/dialog thì đóng sheet trước (đọc trạng thái mở từ `AppDialog`/`Sheet` qua một store nhỏ, hoặc bỏ phần này nếu tốn, Esc hiện có đã đóng được dialog).
- Link `tel:`, Zalo, Google Maps và mọi link `target="_blank"` mở bằng hệ thống (`@capacitor/browser` hoặc `App.openUrl`), không mở trong WebView. 10 file đang có link loại này (vd. `StoreContactList.vue`, `contact/Index.vue`, `AppointmentCard.vue`).
- Bàn phím: `Keyboard.setResizeMode("body")` để ô nhập ở checkout không bị che.
- Mất mạng: `OfflineBanner` cố định trên cùng, ẩn khi có mạng lại, kèm gọi `queryClient.refetchQueries()`.

Theme giữ đúng token shop hiện có (cam, font của shop). Nếu grace muốn thiết kế khung app trên Stitch, M6 viết thêm prompt vào `pet-care-plan/stitch-prompts-mobile.md`; không bắt buộc.

## 7. Thông báo (bản 1.1, M8)

Thông báo cục bộ, không cần server:

- Khi khách đặt lịch spa thành công, và mỗi lần mở app (đọc danh sách "Lịch hẹn của tôi" và "Lưu trú của tôi" có sẵn trong `packages/supabase/src/account`), app đặt lịch nhắc: tối hôm trước 19:00 và 2 giờ trước giờ hẹn; lưu trú nhắc sáng ngày gửi.
- Lịch đã huỷ hoặc đã qua thì huỷ nhắc. Id thông báo suy ra từ id lịch (hàm thuần, có test) để đặt lại không bị trùng.
- Android 13 trở lên phải xin quyền; xin lúc khách vừa đặt lịch xong (có ngữ cảnh), không xin ngay khi mở app.
- Hạn chế: nhân viên đổi giờ trên admin thì app chỉ cập nhật nhắc ở lần mở app tiếp theo. Chấp nhận ở bản này.

Push từ server (sau, ngoài kế hoạch này): bảng `device_tokens`, edge function gửi qua FCM, trigger `pg_net` khi đơn đổi trạng thái hoặc lịch bị đổi. Supabase Free đủ dùng (edge function 500 nghìn lượt/tháng). iOS cần thêm khoá APNs của tài khoản Apple.

## 8. Build, CI và phát hành

### 8.1 CI cho mọi PR (`ci.yml`, job `app`)

Thêm một bước `npm run generate:mobile` sau `npm run build`, để PR nào làm hỏng bản SPA (ví dụ code chỉ chạy được trên server) đều bị chặn. Không build Android ở đây cho nhanh.

### 8.2 Workflow mới `mobile-android.yml`

- Chạy khi: `workflow_dispatch`, push lên `main` có đổi `apps/web/src/**`, `apps/mobile/**`, `packages/**`; và trên PR có đổi `apps/mobile/**`.
- Bước: checkout, Node 22, JDK 21 (`actions/setup-java`, temurin), `npm ci`, `npm run generate:mobile` (với biến `SUPABASE_URL`, `SUPABASE_KEY` lấy từ **GitHub repository variables**, là khoá anon công khai giống bản web, không phải secret), `npx cap sync android`, `./gradlew assembleDebug`, upload `app-debug.apk` làm artifact (giữ 14 ngày), tên kèm số commit.
- Không có secret nào trong bước này. APK debug ký bằng khoá debug, cài được bằng cách cho phép "cài từ nguồn không xác định".

### 8.3 Việc grace phải làm (một lần)

1. GitHub > Settings > Secrets and variables > Actions > **Variables**: thêm `SUPABASE_URL` và `SUPABASE_KEY` (cùng giá trị đang đặt trên Vercel). Đây là khoá anon, công khai.
2. Sau M4: vào Actions > "Mobile Android" > lần chạy mới nhất > tải artifact, giải nén, cài APK lên điện thoại Android. Nếu grace không có máy Android, báo lại để đổi thứ tự (làm M10 PWA trước cho iPad).

### 8.4 Lên store (sau, cần grace quyết và trả phí)

- Google Play: tài khoản developer 25 USD một lần; tạo keystore release (lưu base64 trong GitHub **secrets** do grace tự nhập), build AAB, trang chính sách quyền riêng tư (thêm route `/privacy` trên web), ảnh chụp màn hình. Tài khoản cá nhân mới phải chạy closed testing với ít nhất 12 người trong 14 ngày trước khi phát hành công khai.
- iOS: 99 USD/năm, `npx cap add ios`, build trên runner `macos-latest` (miễn phí vì repo public) hoặc máy Mac, TestFlight. Rủi ro bị từ chối theo guideline 4.2 nếu app chỉ như website; thông báo và tab bar native giúp giảm rủi ro này.

## 9. Kiểm thử

- **Tự động (mỗi PR):** typecheck, `deps:check` với luật mới, Vitest cho hàm thuần mới (`apiUrl`, `backButton`, `tabs`, id thông báo, chọn giờ nhắc), `generate:mobile` chạy được và không có route admin trong output.
- **Trên máy thật (grace, cuối ngày):** danh sách ở mục 12. Môi trường cloud không chạy được máy ảo Android, nên giao diện app chỉ được kiểm bằng build và test, chưa bấm thử; báo cáo phải nói rõ điều này.

## 10. Rủi ro

| Rủi ro | Mức | Cách xử lý |
| --- | --- | --- |
| Code phía khách vô tình phụ thuộc SSR (đọc `useRequestHeaders`, dữ liệu chỉ có lúc render server) | Trung bình | M1 build SPA và mở thử từng route bằng `npx serve .output/public` + Playwright (Chromium có sẵn), chụp lỗi console |
| Phiên đăng nhập mất khi WebView dọn bộ nhớ | Thấp | Theo dõi khi grace test; chuyển sang `@capacitor/preferences` (mục 4) |
| Đổi tên miền Vercel làm GHN trong app hỏng | Thấp | `apiBase` là biến build; đổi biến và build lại APK |
| Supabase Free tự tạm dừng sau 1 tuần không có truy cập, app báo lỗi | Trung bình | Giống web hiện nay; `OfflineBanner` phân biệt "mất mạng" với "máy chủ lỗi" bằng thông báo lỗi chung có nút thử lại |
| Mỗi lần sửa giao diện phải cài lại APK | Thấp | CI tự build; live update (Capgo, Appflow) tốn phí, không làm |
| Hai bản `package.json` lệch phiên bản plugin | Thấp | Một script nhỏ trong `apps/mobile` so phiên bản `@capacitor/*` hai bên, chạy trong workflow Android |
| Google Play/Apple chính sách thay đổi | Thấp | Chỉ ảnh hưởng mục 8.4, chưa làm |
| Bundle app chứa admin hoặc thư viện chỉ admin dùng (`read-excel-file`, `write-excel-file`) | Thấp | Bỏ route admin ở M1; kiểm kích thước `.output/public` trước và sau |

## 11. Các bước làm (mỗi bước một PR)

Thứ tự đã tính để mỗi PR merge xong web vẫn chạy như cũ. Không bước nào có migration. Nhánh code của từng thread khác nhau; thread nói tên nhánh trong báo cáo.

| Bước | Nội dung | File chính | Kiểm |
| --- | --- | --- | --- |
| **M0** | Kế hoạch này | `docs/ke-hoach-app-mobile.md`, `docs/README.md` | |
| **M1** | Đích build `mobile`: `NUXT_PUBLIC_APP_TARGET`, `config/mobileTarget.ts`, bỏ route admin, `ssr:false`, `useSsrCookies:false`, script `generate:mobile`; `features/native` khởi đầu với `useAppTarget` và barrel; bước `generate:mobile` trong `ci.yml`; kiểm mọi route khách mở được ở SPA (Playwright) và sửa chỗ nào lỗi | `apps/web/nuxt.config.ts`, `apps/web/config/mobileTarget.ts`, `apps/web/package.json`, `.github/workflows/ci.yml` | typecheck, build web, generate mobile, không có chunk admin, Playwright mở từng route không có lỗi console |
| **M2** | `apiBase` và CORS cho `/api/ghn/**`; helper `apiUrl` có test; `location.service.ts`, `shipment.service.ts` dùng nó | `apps/web/src/services/*`, `apps/web/src/utils/apiUrl.ts` (web cũng dùng nên để ở `utils`) | Vitest, web vẫn gọi đường tương đối |
| **M3** | Tạo `apps/mobile`: `package.json`, `capacitor.config.ts`, `npx cap add android`, icon và splash từ `assets/`, README; script gốc `mobile:apk`; luật dependency-cruiser mới (mục 3.2); script so phiên bản plugin | `apps/mobile/**`, `package.json` gốc, `apps/web/.dependency-cruiser.cjs` | `cap sync android` chạy, `./gradlew assembleDebug` ra APK trong cloud (cài JDK 21 nếu thiếu) |
| **M4** | Workflow `mobile-android.yml` ra artifact APK | `.github/workflows/mobile-android.yml` | Workflow xanh trên PR; grace thêm 2 variables (mục 8.3) trước khi merge, nếu chưa có thì workflow báo lỗi rõ ràng thay vì build app trỏ sai |
| **M5** | Phần native: plugin `native.client.ts`, status bar, splash, nút Back, bàn phím, mạng (`OfflineBanner`), link ngoài | `apps/web/src/features/native/**` | Vitest cho `backButton`, typecheck, APK build |
| **M6** | Khung app: `AppTabBar` trong `layouts/client.vue` khi là app, safe area, ẩn Google login và link admin, `StaffWebNotice` | `layouts/client.vue`, `features/native/components/*`, `features/auth/*`, `features/shop/layout/AccountMenu.vue` | Vitest cho `tabs`, ảnh chụp Playwright ở khung 390×844 |
| **M7** | Sửa lỗi sau khi grace thử APK trên máy (theo danh sách mục 12) | tuỳ lỗi | |
| **M8** | (v1.1) Thông báo cục bộ nhắc lịch spa và lưu trú | `features/native/composables/useReminders.ts`, `features/native/helpers/reminders.ts` | Vitest cho giờ nhắc và id |
| M9 | (tuỳ chọn) Đăng nhập Google trong app: deep link `vn.bongcun.app://auth/callback`, `@capacitor/browser`, PKCE `exchangeCodeForSession`; grace thêm URL này vào Supabase Auth > Redirect URLs | `features/native`, `stores/modules/auth.ts` | |
| M10 | (tuỳ chọn, rẻ, hợp iPad) PWA cho web: manifest, icon, `apple-mobile-web-app-capable`, không service worker | `apps/web/public/manifest.webmanifest`, `nuxt.config.ts` | Lighthouse "installable" |
| M11 | (cần grace quyết, có phí) Google Play rồi iOS (mục 8.4) | | |

M1 đến M6 là bản dùng được; M7 phụ thuộc grace thử máy; M8 trở đi làm khi grace muốn.

Quy tắc chung khi code: mỗi file `.vue`/`.ts` dưới khoảng 300 dòng; trang là vỏ mỏng; logic ở `useXxx`; hàm thuần ở `helpers`/`utils` có test; kiểu ở `types.ts`. Commit và tiêu đề PR bằng tiếng Anh theo `.claude/skills/commit/SKILL.md`.

## 12. Danh sách grace thử trên máy (sau M6)

1. Cài APK, mở app: splash, icon, thanh trạng thái màu shop.
2. Xem trang chủ, danh sách sản phẩm, chi tiết, thêm giỏ; số trên tab Giỏ hàng đổi.
3. Đăng ký tài khoản mới bằng mã OTP; đăng xuất; đăng nhập lại; tắt hẳn app rồi mở lại vẫn còn đăng nhập.
4. Thanh toán một đơn giao hàng: chọn tỉnh/huyện/xã (GHN), phí ship hiện ra, đặt đơn; xem đơn trong Tài khoản.
5. Đặt lịch spa; xem trong "Lịch hẹn của tôi".
6. Xem thú cưng và sổ sức khỏe (chỉ xem).
7. Bấm số điện thoại và Zalo ở trang Liên hệ: mở ra ứng dụng gọi/Zalo, không mở trong app.
8. Nút Back của Android ở vài trang và ở trang chủ (thoát app).
9. Bật chế độ máy bay: dải "Mất kết nối" hiện; tắt đi: dữ liệu tự tải lại.
10. Đăng nhập bằng tài khoản nhân viên: không thấy admin, có dòng nhắc dùng web.
11. Ô nhập ở checkout không bị bàn phím che.

## 13. Việc cần grace

- Thêm 2 GitHub variables (mục 8.3) trước khi merge M4.
- Cho biết có máy Android để cài APK không; nếu không, làm M10 (PWA) trước để dùng trên iPad.
- Gửi logo/ảnh icon nếu muốn (không có thì dùng icon tạm).
- Quyết sau: có lên Google Play/App Store không (mục 8.4), có cần push từ server không (mục 7).
