# Hệ thống giao diện shop công khai (pet shop + spa)

Tài liệu đi kèm đợt làm mới toàn bộ giao diện khách hàng (sau bản đánh giá [ui-san-pham-danh-gia.md](ui-san-pham-danh-gia.md)). Ghi lại quyết định thiết kế, bộ component dùng chung và những gì còn phải làm, để các màn sau làm theo cùng một kiểu.

## 1. Định hướng

- Ấm áp, sạch, đáng tin: nền kem, bề mặt trắng, chữ nâu đậm thay vì đen tuyền. Không gradient lòe loẹt, không bóng đậm.
- Hai giọng màu: **cam** cho mua sắm (nút chính, giá, điểm nhấn), **xanh sage** cho chăm sóc và niềm tin (spa, cam kết, trạng thái hoàn thành).
- Phân cấp bằng chữ và khoảng trắng: mỗi trang có một H1 lớn, eyebrow nhỏ in hoa phía trên tiêu đề khu, thẻ ít viền.
- Mobile-first: gutter 16px trên điện thoại, nội dung tối đa 1240px trên desktop, vùng chạm tối thiểu 40px.
- Không khác gì admin "đổi màu": shop có token riêng trên `html.shop-theme`, admin giữ `admin-theme`.

## 2. Token (`src/assets/shop.css`)

| Token | Giá trị | Dùng cho |
| --- | --- | --- |
| `--background` | kem `36 45% 97%` | nền trang |
| `--primary` | cam cháy `20 88% 40%` | nút chính, link, focus ring. Chữ trắng trên nền này đạt WCAG AA (~5:1) |
| `--brand` | cam tươi `#F97316` | mảng màu không chứa chữ nhỏ (logo, icon, thanh tiến trình) |
| `--sage` / `--sage-soft` | xanh `154 33% 28%` / nền nhạt | spa, cam kết, bước đã xong |
| `--destructive` | đỏ `0 72% 45%` | lỗi, giá khuyến mãi |
| `--radius` | 0.75rem | bo góc mặc định; khối lớn dùng `rounded-3xl` |

Tailwind có thêm `bg-brand`, `bg-brand-soft`, `bg-sage`, `bg-sage-soft`, `shadow-card`, `shadow-lift`, `ease-out-quart`, `ease-pop`.

Lớp tiện ích: `shop-container` (bề rộng trang), `shop-eyebrow`, `shop-display` (tiêu đề lớn), `shop-reveal` (hiện dần, `--i` là thứ tự), `shop-skeleton` (shimmer), `shop-scroll-row` (hàng cuộn ngang trên mobile). Có khối `prefers-reduced-motion` tắt hết chuyển động.

Font: Be Vietnam Pro (thêm độ đậm 800) cho toàn shop, thay Quicksand.

## 3. Component dùng chung (`src/components/shop/`)

| Component | Việc |
| --- | --- |
| `ProductCard` / `ProductCardSkeleton` | thẻ sản phẩm: ảnh vuông, hãng, tên, giá, tồn kho, nút chọn mua nhanh (quick view tải lười) |
| `PriceDisplay` | giá, giá gốc gạch ngang và % giảm khi có `compareAt`, "Từ ..." khi nhiều biến thể, "Liên hệ để biết giá" khi chưa có giá |
| `StockBadge` | còn hàng / sắp hết / hết hàng |
| `EmptyState` | trạng thái rỗng, không tìm thấy và lỗi (tone `error`), nút hành động trong slot |
| `SectionHeading` | eyebrow + tiêu đề + link "Xem tất cả" |
| `QuantityStepper` | chọn số lượng dạng viên thuốc |
| `PillGroup` | hàng nút chọn một (chi nhánh, loài thú) |
| `ShopImage` | ảnh marketing có srcset, hiện dần, rơi về ô hình bàn chân khi link hỏng |
| `checkout/CheckoutSteps` | Giỏ hàng → Thanh toán → Hoàn tất |
| `checkout/FreeShipProgress` | "Mua thêm X để được miễn phí giao hàng", theo cài đặt bán online |
| `spa/ComboCard`, `spa/BookingHowTo` | thẻ combo spa và 3 bước đặt lịch |

Không làm `Rating`: database chưa có đánh giá sản phẩm, không hiển thị số sao giả. Khi có bảng đánh giá thì thêm component này và gắn vào `ProductCard`, `ProductBuyBox`.

`FilterBar` của trang danh sách là bộ `CatalogToolbar` + `CatalogChips` + `CatalogFilters` / `CatalogFilterSheet` trong `src/views/client/catalog/components/`.

## 4. Màn đã làm mới

- **Khung**: header mới (logo, menu có gạch chân động, ô tìm kiếm, VI/EN, tài khoản, giỏ có số), thanh trên cùng (giờ mở cửa, địa chỉ, điện thoại), menu mobile dạng drawer, link "Bỏ qua tới nội dung chính", footer tối có khối CTA đặt lịch.
- **Trang chủ**: hero hai lối (mua sắm / đặt spa), dải cam kết, hai thẻ điều hướng Cửa hàng và Spa, danh mục thật, sản phẩm mới về, khu spa (combo thật + 3 bước), khu ghé cửa hàng có chỉ đường.
- **Danh sách sản phẩm**: hero có danh mục dạng viên thuốc, thanh công cụ dính khi cuộn, chip lọc xoá nhanh, bộ lọc trong sheet trên mobile, số kết quả, thanh tiến trình khi đổi lọc, skeleton, rỗng và lỗi rõ ràng. Ô tìm kiếm không còn mất focus khi gõ (`keepOnQuery` ở `app.vue`).
- **Chi tiết sản phẩm**: gallery có nút trước/sau và thumbnail, khối mua (giá, tồn kho, biến thể dạng viên, số lượng, Thêm vào giỏ, Mua ngay), thông tin giao hàng lấy từ cài đặt bán online, thanh mua cố định dưới đáy trên mobile, sản phẩm liên quan.
- **Giỏ hàng và thanh toán**: thanh bước, thanh miễn phí giao hàng, các khối đánh số (cách nhận, địa chỉ, sản phẩm), lỗi nằm trong một hộp cảnh báo, nút đặt hàng to.
- **Theo dõi đơn**: lời cảm ơn có bước "Hoàn tất", tiến trình đơn màu sage.
- **Spa**: hero, bảng giá theo loài, combo, bảng giá dịch vụ lẻ theo cân nặng, 3 bước đặt lịch. Wizard đặt lịch: bước có dấu tích, lựa chọn dạng thẻ, khung giờ dạng viên.
- **Giới thiệu, Liên hệ**: hero có ảnh, sứ mệnh, giá trị; liên hệ có nút gọi và chỉ đường.

Không đổi logic nghiệp vụ, API, validation, đăng nhập hay luồng thanh toán. Không thêm dependency.

## 5. Kỹ thuật đáng nhớ

- Trang công khai chạy SSR. Các query của trang chủ và danh sách sản phẩm được chờ trên server qua `useServerPrefetch` (`src/composables/shop/useServerPrefetch.ts`), nên HTML server có sẵn dữ liệu và không còn lỗi "hydration mismatch". Bảng giá spa cần chi nhánh trước nên nằm trong `<ClientOnly>` với skeleton.
- Chuyển động chỉ dùng `transform` và `opacity`; danh sách hiện dần giới hạn độ trễ (`revealIndex`).

## 6. Còn phải làm

- **Ảnh**: `src/config/shopImagery.ts` đang trỏ ảnh Unsplash (hero, spa, cửa hàng). Nên thay bằng ảnh thật của cửa hàng (đổi `src`).
- **Dữ liệu chưa có**: đánh giá sản phẩm, giá khuyến mãi cho sản phẩm (giá gạch ngang hiện chỉ dùng cho combo spa), sản phẩm bán chạy (trang chủ đang dùng "mới về").
- **Dịch vụ chưa có trong app**: khám thú y, lưu chuồng (pet hotel). Khi làm module, thêm thẻ vào khu "Bạn đang cần gì?" ở trang chủ.
- **Khu tài khoản và đăng nhập/đăng ký**: mới hưởng token màu và font, chưa làm lại bố cục.
