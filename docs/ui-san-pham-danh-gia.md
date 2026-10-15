# Đánh giá UI trang danh sách sản phẩm (shop) và hướng làm mới

Phạm vi: trang `/products` của shop công khai (route `products`, `src/pages/products/index.vue`) cùng layout khách hàng, header, ô tìm kiếm, sắp xếp, bộ lọc, chip lọc, thẻ sản phẩm, trạng thái rỗng và nút xem thêm. Tài liệu này chỉ đánh giá và đề xuất, chưa đổi code.

File đã đọc:

- `src/views/client/catalog/Index.vue` và `components/` (CatalogToolbar, CatalogSort, CatalogFilters, CategoryTree, BrandFilter, CatalogGrid, CatalogCard)
- `src/layouts/client.vue`, `src/components/layout/client/MenuLinks.vue`, `MenuExtras.vue`, `src/components/common/Link.vue`, `AppLogo.vue`
- `src/assets/index.css`, `tailwind.config.js`, `nuxt.config.ts` (font), `src/components/ui/{button,input,skeleton}`
- `src/composables/shop/useCatalog.ts`, `src/queries/shopCatalog.ts`

## 1. Vì sao trông cũ (xếp theo mức ảnh hưởng)

### 1.1 Cái gì cũng là một hộp viền trắng trên nền trắng (ảnh hưởng lớn nhất)

- Nền trang trắng tuyệt đối: `--background: 0 0% 100%` (`src/assets/index.css:7`).
- Trên nền đó, mọi khối lại là `rounded-xl border bg-white`: sidebar (`Index.vue:14`), thanh công cụ (`CatalogToolbar.vue:2`), từng thẻ sản phẩm (`CatalogCard.vue:3`), khối lỗi và khối rỗng (`CatalogGrid.vue:6`, `:11`), khối "xem thêm" (`CatalogGrid.vue:20`).
- Kết quả: không có lớp nền, không có chiều sâu, mắt không biết đâu là nội dung chính. Kiểu "form trong admin" hơn là trang mua sắm. Giao diện hiện đại dùng nền ấm nhạt, thẻ không viền, tách lớp bằng bóng mềm và khoảng trắng.

### 1.2 Gần như không có chuyển động

- Thẻ chỉ có `transition-shadow hover:shadow-lg` (`CatalogCard.vue:3`): không nhấc thẻ, không phóng ảnh, không hiện nút.
- Lưới không có hiệu ứng xuất hiện, không stagger, không FLIP khi lọc. Khi đổi bộ lọc, `keepPreviousData` (`src/queries/shopCatalog.ts:21`) giữ dữ liệu cũ và `loading` chỉ theo `isPending` (`useCatalog.ts:30`), nên lưới cũ đứng yên rồi bị thay đột ngột, người dùng không thấy phản hồi.
- Skeleton dùng `animate-pulse bg-primary/10` (`src/components/ui/skeleton/Skeleton.vue`): nhấp nháy màu cam, không phải shimmer.
- Chip lọc hiện/mất không có chuyển tiếp (`CatalogToolbar.vue:15`).
- Header ẩn khi cuộn xuống rồi tự hiện lại sau 500 ms (`src/layouts/client.vue:86-98`): giật, hai trạng thái nhảy qua lại.
- Không có xử lý `prefers-reduced-motion` ở đâu trong `src/`.

### 1.3 Phân cấp chữ yếu, font chưa hợp

- Không có tiêu đề trang (H1); chỉ có breadcrumb nhỏ (`Index.vue:3-11`).
- Tên sản phẩm `text-sm` (14px) (`CatalogCard.vue:23`), giá ở cỡ mặc định 16px (`CatalogCard.vue:30`), số kết quả `text-sm text-muted-foreground` (`CatalogToolbar.vue:19`). Mọi thứ cùng một tầm, không có điểm nhấn.
- Shop dùng Quicksand cho toàn trang (`src/assets/index.css:310`): nét tròn, mảnh, ở cỡ 13–14px dấu tiếng Việt khó đọc và trông "trẻ con". Admin đã dùng Be Vietnam Pro (`index.css:113`), font này đã được tải sẵn (`nuxt.config.ts:40`).

### 1.4 Thẻ sản phẩm

- Ảnh `object-contain p-2` trên nền xám (`CatalogCard.vue:7-8`): ảnh nhỏ, viền xám bao quanh, nhìn như ảnh placeholder.
- Nút giỏ là `variant="outline"` 36px màu xám (`CatalogCard.vue:31`): trông như đang bị vô hiệu, không mời bấm.
- Hết hàng làm mờ cả thẻ `opacity-70` (`CatalogCard.vue:4`) và gắn nhãn vuông `bg-red-700` (`CatalogCard.vue:14`): đỏ đậm lệch tông với cam thương hiệu.
- Bấm cả thẻ mở quick view, bấm tên lại sang trang chi tiết (`CatalogCard.vue:5`, `:24`): hai hành vi trên cùng một khối, người dùng không đoán được.

### 1.5 Theme mặc định shadcn, bo góc và màu chưa thống nhất

- Bảng màu là theme "stone" mặc định của shadcn, `--radius: 0.5rem` (`index.css:16-37`): thẻ 12px, input 6px, nút `rounded-md` cao 36px (`src/components/ui/button/index.ts`). Nhìn ra ngay là template.
- Hai màu cam: `--primary` là `#F97316` (`index.css:16`) nhưng link menu hover dùng `custom-primary #ff8906` (`tailwind.config.js:68`, `src/components/common/Link.vue:3`).

### 1.6 Thanh công cụ

- Ô tìm kiếm cao 36px (`src/components/ui/input/Input.vue`) nằm trong một hộp viền; sort cố định 170px (`CatalogSort.vue:3`).
- Không dính (sticky): cuộn xuống vài hàng là mất ô tìm và sắp xếp.
- Số kết quả và chip nằm chung một hàng chữ nhỏ, không có nút "Xóa tất cả" cạnh chip.

### 1.7 Bộ lọc bên trái

- Danh mục là danh sách nút chữ thường, mục con thụt lề với `border-l` (`CategoryTree.vue:20`): giống cây thư mục.
- Thương hiệu dùng checkbox gốc của trình duyệt nhưng chỉ chọn được một (`BrandFilter.vue:5-9`): checkbox mà hành xử như radio, sai kỳ vọng.

### 1.8 Trạng thái rỗng và lỗi

- Ảnh PNG 512px thu còn `w-28 opacity-80` và một dòng chữ xám (`CatalogGrid.vue:11-14`). Không có nút "Xóa bộ lọc", không gợi ý danh mục khác, nằm trong hộp viền.
- Trạng thái lỗi cùng kiểu (`CatalogGrid.vue:6-9`).

### 1.9 "Xem thêm" kiểu cũ

- Một hộp viền chứa câu "Đang hiển thị X trên Y", thanh tiến độ và nút outline (`CatalogGrid.vue:20-27`). Repo đã có `ScrollSentinel` (`src/components/common/ScrollSentinel.vue`) để tải tiếp khi cuộn tới cuối.

### 1.10 Header

- Header cao (~80px, `py-6`, `client.vue:3`) trong khi nội dung chỉ là logo 32px và menu.
- Class `bg-[rgb(255, 255, 255)]` có dấu cách nên Tailwind bỏ qua (`client.vue:3`, `:29`): menu mobile thực tế trong suốt, chỉ còn `backdrop-blur`.
- Logo lấy thẳng từ `pethaven.vn` và `object-cover` (`AppLogo.vue:4-6`): phụ thuộc site ngoài, dễ bị cắt.
- Link đang chọn chỉ đổi màu chữ (`Link.vue:3-5`), không có gạch chân hay pill.

### 1.11 Khoảng cách

- Lưới `gap-4` (16px) (`CatalogGrid.vue:17`) chật cho thẻ nhiều ảnh; khoảng giữa breadcrumb, toolbar và lưới đều `space-y-4`, không có nhịp.

## 2. Hướng hiện đại đề xuất

Giữ cam thương hiệu `#F97316`. Tinh thần: nền ấm nhạt, thẻ trắng không viền nổi bằng bóng mềm, chữ rõ tầng, bo góc lớn, chuyển động ngắn và có mục đích. Không thêm thư viện animation: dùng CSS transition, `<Transition>`/`<TransitionGroup>` của Vue và `useIntersectionObserver` của VueUse (đã có).

### 2.1 Token (giá trị cụ thể)

Đặt token cho shop trong một file CSS mới `src/assets/shop.css` (vì `index.css` đã 342 dòng), áp dụng qua class `shop-theme` trên `<html>` giống cách admin dùng `admin-theme`.

| Nhóm | Giá trị |
| --- | --- |
| Nền trang | `#FAF7F2` (`36 33% 97%`) |
| Bề mặt thẻ | `#FFFFFF`, không viền |
| Nền ảnh sản phẩm | `#F5F1EA` |
| Cam chính / hover / nền nhạt | `#F97316` / `#EA580C` / `#FFF7ED` |
| Chữ chính / phụ | `#1C1917` / `#78716C` |
| Hết hàng | chữ `#78716C` trên nền `#F5F5F4` (không dùng đỏ) |
| Giảm giá / mới | `#DC2626` nền `#FEF2F2`; `#0F766E` nền `#F0FDFA` |
| Bo góc | thẻ 20px, khung ảnh 16px, input và nút 12px, chip và nút tròn 9999px |
| Bóng nghỉ | `0 1px 2px rgb(28 25 23 / .04), 0 4px 12px rgb(28 25 23 / .04)` |
| Bóng hover | `0 16px 32px -12px rgb(28 25 23 / .16)` |
| Bóng nút cam | `0 8px 20px -6px rgb(249 115 22 / .45)` |
| Khoảng cách | thang 4/8: lưới 16px (mobile), 20px (md), 24px (xl); padding thẻ 16px; giữa các khối 32px, đầu trang 48px |

### 2.2 Chữ

Đổi font shop sang Be Vietnam Pro (đã tải), bỏ Quicksand ở body; có thể giữ Quicksand cho logo hoặc tiêu đề hero nếu muốn nét mềm.

| Vai trò | Cỡ / dòng | Độ đậm | Ghi chú |
| --- | --- | --- | --- |
| H1 trang | 32/40 (md 40/48) | 700 | `letter-spacing: -0.02em` |
| Tiêu đề khối | 20/28 | 600 | |
| Tên sản phẩm | 15/22 | 500 | 2 dòng |
| Giá | 18/24 | 700 | `tabular-nums`, màu chữ chính, "Từ" nhỏ 12px |
| Nhãn thương hiệu | 11/16 | 600 | in hoa, `letter-spacing: 0.06em` |
| Phụ, chip | 13/18 | 500 | |

### 2.3 Bố cục màn

1. **Đầu trang**: breadcrumb nhỏ, H1 "Sản phẩm" và một dòng phụ "128 sản phẩm cho chó mèo"; hàng pill danh mục gốc cuộn ngang (có icon) ngay dưới, để chọn nhanh trên cả mobile.
2. **Thanh công cụ dính** (`sticky top-16`): ô tìm dạng pill cao 44px, nút sắp xếp dạng pill, nút "Bộ lọc" trên mobile. Khi đã cuộn, thanh có nền `bg-white/80 backdrop-blur-md` và bóng nhẹ; chưa cuộn thì trong suốt.
3. **Hàng chip**: chip đang lọc dạng pill cam nhạt, nút "Xóa tất cả" ở cuối; số kết quả nằm bên phải.
4. **Sidebar** (lg trở lên): không viền, dính theo thanh công cụ; danh mục là danh sách có thanh chỉ báo cam trượt theo mục đang chọn; thương hiệu là radio dạng pill có ô tìm khi trên 8 hãng.
5. **Lưới**: 2 cột mobile, 3 cột md, 4 cột xl, khoảng cách như bảng trên.
6. **Thẻ sản phẩm**: khung ảnh 1:1 bo 16px nền `#F5F1EA`, ảnh lấp 85%; nhãn pill góc trên trái (Hết hàng, Mới, -x%); nút tim hoặc "xem nhanh" góc trên phải hiện khi hover; dưới là thương hiệu, tên, giá và nút giỏ tròn 40px nền cam có bóng cam. Bấm thẻ sang trang chi tiết; nút "xem nhanh" mới mở quick view. Hết hàng chỉ làm xám ảnh và nút, không mờ cả thẻ.
7. **Rỗng**: không hộp viền; minh họa SVG thú cưng (chó tìm đồ) 160px, tiêu đề 20px "Chưa có sản phẩm khớp", câu gợi ý, nút "Xóa bộ lọc" và 3–4 pill danh mục phổ biến. Lỗi cùng khung, nút "Thử lại".
8. **Tải thêm**: tự tải khi cuộn tới cuối bằng `ScrollSentinel`, hiện một hàng skeleton; giữ nút "Xem thêm" làm dự phòng khi người dùng tắt JS hoặc lỗi.
9. **Header**: cao 64px, `bg-white/80 backdrop-blur-md` và viền dưới chỉ hiện khi đã cuộn; bỏ cơ chế ẩn/hiện bằng timeout, thay bằng thu gọn mượt; link đang chọn có gạch chân cam trượt; logo đặt trong repo (`src/assets/logo.svg` đã có) và `object-contain`.

### 2.4 Kế hoạch chuyển động

Token:

| Tên | Thời lượng | Easing |
| --- | --- | --- |
| micro (nút, chip, màu) | 150ms | `cubic-bezier(0.2, 0, 0, 1)` |
| state (hover thẻ, dropdown) | 220ms | `cubic-bezier(0.25, 1, 0.5, 1)` (ease-out-quart) |
| enter (thẻ, khối) | 320ms | `cubic-bezier(0.25, 1, 0.5, 1)` |
| move (sắp xếp lại lưới) | 320ms | `cubic-bezier(0.65, 0, 0.35, 1)` |
| pop (thêm vào giỏ) | 260ms | `cubic-bezier(0.34, 1.56, 0.64, 1)` |

Áp dụng:

- **Thẻ xuất hiện**: mờ dần và trượt lên 12px, stagger 40ms theo thứ tự, tối đa 12 thẻ mỗi đợt (thẻ sau xuất hiện cùng lúc), kích hoạt khi vào khung nhìn.
- **Lọc và sắp xếp**: `<TransitionGroup>` với `move-class` để thẻ trượt về chỗ mới (FLIP); thẻ rời đi mờ và thu 0.96. Trong lúc đang tải với dữ liệu cũ (`isFetching` mà không `isPending`), lưới mờ còn 0.6 và một vạch tiến độ cam chạy dưới thanh công cụ.
- **Hover thẻ** (chỉ thiết bị có chuột): thẻ nhấc `translateY(-4px)` và đổi sang bóng hover, ảnh phóng 1.04, nút "xem nhanh" trượt vào.
- **Thêm vào giỏ**: nút co 0.92 rồi bật lại (pop), icon đổi thành dấu tích 1.2s; số trên icon giỏ ở header nảy 1.15.
- **Chip**: vào bằng scale 0.9 → 1 và mờ dần; ra ngược lại; các chip còn lại trượt khép lại.
- **Bộ lọc**: thanh chỉ báo danh mục trượt dọc giữa các mục; Sheet mobile giữ animation của shadcn nhưng đổi easing sang ease-out-quart.
- **Skeleton**: shimmer gradient chạy ngang 1.4s, màu `#F5F1EA` → `#FBF8F3`, không dùng cam.
- **Trạng thái rỗng**: minh họa trôi nhẹ lên xuống 4px, chu kỳ 3s.
- **Thanh công cụ dính**: nền và bóng chuyển 220ms khi bắt đầu cuộn.
- **Giảm chuyển động**: trong `@media (prefers-reduced-motion: reduce)` bỏ mọi translate/scale và stagger, chỉ giữ đổi độ mờ 150ms.
- Chỉ animate `transform` và `opacity` để giữ 60fps.

### 2.5 File sẽ thay đổi (theo quy tắc file nhỏ)

Mỗi file dưới khoảng 300 dòng; giao diện, logic, hàm thuần và kiểu tách riêng.

| File | Việc |
| --- | --- |
| `src/assets/shop.css` (mới) | Token màu, bóng, bo góc, chuyển động của `shop-theme`; khối `prefers-reduced-motion` |
| `tailwind.config.js` | Thêm `boxShadow` (card, card-hover, glow), `transitionTimingFunction` (out-quart, in-out, spring), keyframes `fade-up`, `shimmer`, `pop`, `float` |
| `nuxt.config.ts` | Nạp `shop.css` |
| `src/layouts/client.vue` | Bật `shop-theme`, sửa class nền lỗi, header 64px; logic cuộn chuyển sang `composables/layout/useHeaderScroll.ts` (mới) |
| `src/components/common/Link.vue` | Gạch chân cam trượt cho link đang chọn, bỏ `custom-primary` |
| `views/client/catalog/Index.vue` | Vẫn là vỏ mỏng: thêm `CatalogHeader`, thanh công cụ dính |
| `components/CatalogHeader.vue` (mới) | H1, dòng phụ, hàng pill danh mục |
| `components/CategoryPills.vue` (mới) | Pill danh mục cuộn ngang |
| `components/CatalogToolbar.vue` | Ô tìm pill 44px, trạng thái đã cuộn; chip tách ra `CatalogChips.vue` (mới) với `<TransitionGroup>` |
| `components/CatalogGrid.vue` | Chỉ điều phối trạng thái; lưới dùng `<TransitionGroup>` |
| `components/CatalogCard.vue` | Bố cục mới; tách `CatalogCardMedia.vue`, `CatalogCardBadges.vue`, `CatalogAddButton.vue` (mới) |
| `components/CatalogCardSkeleton.vue` (mới) | Skeleton shimmer riêng cho shop (không sửa `ui/skeleton` admin đang dùng) |
| `components/CatalogEmpty.vue`, `CatalogError.vue` (mới) | Trạng thái rỗng và lỗi có hành động |
| `components/CatalogLoadMore.vue` (mới) | `ScrollSentinel` + nút dự phòng |
| `components/CategoryTree.vue`, `BrandFilter.vue` | Chỉ báo trượt, radio dạng pill |
| `composables/shop/useStaggerReveal.ts` (mới) | Theo dõi thẻ vào khung nhìn, trả về độ trễ |
| `composables/shop/useStickyToolbar.ts` (mới) | Trạng thái "đã cuộn" của thanh công cụ |
| `utils/shop/motion.ts` (mới) | Hàm thuần `staggerDelay(index, step, max)` và hằng số thời lượng |
| `composables/shop/useCatalog.ts` | Thêm `refreshing` (`isFetching && !isPending`) để làm mờ lưới khi lọc |

### 2.6 Thứ tự làm đề xuất

1. Token, font, header (ảnh hưởng mọi trang shop).
2. Thẻ sản phẩm và lưới với chuyển động.
3. Thanh công cụ dính, chip, bộ lọc.
4. Rỗng, lỗi, tải thêm khi cuộn.
5. Đưa cùng ngôn ngữ sang trang chi tiết sản phẩm, trang chủ, giỏ hàng.

Mỗi bước là một PR nhỏ, kiểm tra bằng typecheck, build và chụp màn hình ở 375px, 768px, 1280px.

## 3. Cần chủ dự án xác nhận

- Giao diện tham chiếu (UI công ty đang dùng cho người dùng cuối): gửi link hoặc ảnh chụp để chỉnh token và bố cục cho khớp trước khi code.
- Có giữ Quicksand cho logo hoặc tiêu đề không.
- Bấm thẻ sang trang chi tiết, quick view thành nút riêng: đồng ý không.
