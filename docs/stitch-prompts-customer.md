# Prompt Stitch: giao diện khách hàng (shop + spa online)

> Ngày: 14/10/2026 · Dựa trên docs/giao-dien-khach-hang.md.

## Cách dùng
- Dán **Prompt 0** trước, rồi từng prompt màn hình trong **cùng một project Stitch**.
- Prompt bằng tiếng Anh; chữ trên giao diện là tiếng Việt (đã ghi trong ngoặc kép).
- Mỗi lần một màn. Lệch thì chỉnh bằng câu ngắn.
- Đây là web công khai cho khách (khác admin teal): giữ theme **cam**.

## Prompt 0: Bối cảnh và phong cách chung
```
Design system for "Bông Cún", a public website of a pet shop + grooming spa in Vietnam. Users are pet owners on phones (most) and desktops. All UI text is Vietnamese.

Layout: top header with logo, menu ("Trang chủ", "Sản phẩm", "Dịch vụ spa", "Giới thiệu", "Liên hệ"), search icon, cart icon with count badge, and either a "Đăng nhập" button or a user avatar menu ("Tài khoản", "Đơn hàng", "Thú cưng", "Lịch hẹn", "Đăng xuất"). Footer with 3 columns: about, quick links, contact (address, hotline, opening hours). Mobile: hamburger menu and sticky bottom action bar where needed.

Visual style: warm, friendly, trustworthy, lots of whitespace, big photos. Light theme. Primary orange #FF8906, dark text #1F2937, soft cream background #FFF8F0, soft green for "còn hàng"/success. Rounded corners 12px, soft shadows on cards. Font: Be Vietnam Pro (Vietnamese diacritics must render well). Prices as "350.000đ". Buttons min height 44px. Skeleton loading, friendly empty states with a small pet illustration, error states with a "Thử lại" button.
```

## Prompt 1: Trang chủ
```
Home page. Hero banner with headline "Chăm sóc thú cưng của bạn như người nhà", subtitle, two buttons "Mua sắm ngay" (primary) and "Đặt lịch spa" (outline). Below: row of 6 category tiles (e.g. "Thức ăn cho chó", "Thức ăn cho mèo", "Phụ kiện", "Đồ chơi", "Vệ sinh", "Thuốc & vitamin"); section "Sản phẩm mới" with a horizontal grid of 8 product cards; a call-to-action block "Đặt lịch spa online" with photo of a groomed dog, 3 short benefits (đặt trong 1 phút, chọn giờ còn trống, hủy dễ dàng) and a button "Đặt lịch ngay"; short "Vì sao chọn Bông Cún" strip with 4 icons; footer.
```

## Prompt 2: Danh sách sản phẩm
```
Product listing page "Sản phẩm". Desktop: left filter column with a collapsible category tree (parent and child categories), brand checkboxes, and "Xóa bộ lọc" link. Top bar: search input "Tìm sản phẩm, SKU...", result count "134 sản phẩm", sort dropdown ("Mới nhất", "Giá tăng dần", "Giá giảm dần", "Tên A-Z"). Grid of product cards, 4 per row: image, name, brand, price "Từ 120.000đ", small "Hết hàng" badge with dimmed card for one item, quick "Thêm vào giỏ" button. Bottom: button "Xem thêm" (load more) with "Đang hiển thị 24 / 134". Mobile: filters open in a bottom sheet from a "Bộ lọc" button, grid 2 per row. Include empty state "Không tìm thấy sản phẩm phù hợp".
```

## Prompt 3: Chi tiết sản phẩm
```
Product detail page. Breadcrumb "Trang chủ / Thức ăn cho chó / Hạt Royal Canin". Left: image gallery with thumbnails. Right: name, brand, price "Từ 120.000đ", variant selectors as chips (e.g. "Trọng lượng": 1kg / 2kg / 5kg; "Vị": gà / bò), unit selector ("Gói" / "Thùng 10 gói"), stock text "Còn hàng", quantity stepper, primary button "Thêm vào giỏ", secondary "Mua ngay". Below: tabs or sections "Mô tả", "Thông tin sản phẩm" (brand, category, unit). Then "Sản phẩm cùng danh mục" with 8 cards. Also a variant of the page for a discontinued product: friendly message "Sản phẩm đã ngừng bán" with a button back to "Sản phẩm". Mobile: sticky bottom bar with price and "Thêm vào giỏ".
```

## Prompt 4: Tài khoản (khung + tổng quan)
```
Account area. Desktop: left vertical nav "Tổng quan", "Hồ sơ", "Địa chỉ", "Đơn hàng", "Thú cưng", "Lịch hẹn"; mobile: horizontal scrolling tabs. Overview content: greeting "Xin chào, Lan", three cards: "Đơn hàng gần đây" (3 rows with code, date, status badge, total), "Lịch hẹn sắp tới" (date, time, pet name, service, status) with button "Đặt lịch mới", and "Thú cưng của tôi" (count + avatars) with button "Thêm thú cưng".
```

## Prompt 5: Hồ sơ
```
Profile page inside the account area. Card "Thông tin cá nhân": avatar, form fields "Họ và tên", "Số điện thoại", "Email" (read-only), button "Lưu thay đổi". Inline error example for phone already used: "Cửa hàng đã có hồ sơ với số này. Nhờ nhân viên liên kết khi bạn đến, hoặc gọi hotline". Card "Liên kết đăng nhập" with a single row "Google" showing connected state and a "Liên kết" / "Hủy liên kết" button.
```

## Prompt 6: Thú cưng của tôi
```
"Thú cưng của tôi" page. Grid of pet cards: photo placeholder, name "Bông", species/breed "Chó · Poodle", gender, age "2 tuổi 3 tháng", latest weight "4,5 kg", small kebab menu (Sửa, Ẩn). Button "Thêm thú cưng". Dialog "Thêm thú cưng" with fields: Tên, Loài (Chó/Mèo/Khác), Giống, Giới tính (segmented), Ngày sinh, Cân nặng (kg), Ghi chú; buttons "Hủy", "Lưu". Empty state: "Bạn chưa có thú cưng nào" with button.
```

## Prompt 7: Bảng giá dịch vụ spa
```
Page "Dịch vụ spa". Intro banner with a short sentence and button "Đặt lịch". Species tabs ("Chó", "Mèo"). A price table: rows = services ("Tắm", "Cắt tỉa lông", "Cạo vôi răng"...), columns = weight brackets ("Dưới 3 kg", "3-6 kg", "6-10 kg", "Trên 10 kg"), cells like "150.000đ". Below: "Combo" cards with included services and combo price. For guests, the button reads "Đăng nhập để đặt lịch". Mobile: table becomes expandable cards per service.
```

## Prompt 8: Đặt lịch spa (wizard 4 bước)
```
Booking wizard "Đặt lịch spa" with a 4-step progress bar: "Cơ sở", "Thú cưng & dịch vụ", "Ngày & giờ", "Xác nhận". Design all four steps:
1. Branch cards (skipped if only one branch).
2. For each pet (avatar + name), checkbox list of services and combos filtered by species, with price; services depending on weight show "Báo giá khi nhận thú" if no weight; running summary on the side (bottom on mobile).
3. Date strip for the next 30 days (disabled before now + 2 hours) and a grid of time chips every 15 minutes, some disabled/full; text "Các dịch vụ sẽ được làm liền nhau, tổng thời lượng 1 giờ 30 phút".
4. Review card: branch, date/time, per pet services, estimated total "Tạm tính 450.000đ", notes textarea, button "Xác nhận đặt lịch". Add a success toast "Đặt lịch thành công, mã SPA-000123".
Buttons "Quay lại" / "Tiếp tục" sticky at the bottom on mobile.
```

## Prompt 9: Lịch hẹn của tôi
```
"Lịch hẹn của tôi" page with tabs "Sắp tới" and "Đã qua". Appointment card: code, branch, date and time, per pet list with services, status badge (Đã đặt / Hoàn thành / Đã hủy), estimated total, button "Hủy lịch" (outline red). Show one card where the time is under 2 hours away: button replaced by text "Gọi cửa hàng để hủy". Cancel confirmation dialog "Bạn chắc chắn muốn hủy lịch này?". Empty state with button "Đặt lịch spa".
```

## Prompt 10: Giới thiệu và Liên hệ
```
Two pages. "Giới thiệu": story section with photo, mission, 3 numbers (years, pets cared for, happy customers), team photos. "Liên hệ": branch card with address, hotline, opening hours table, embedded map placeholder, and a small contact form-free layout (no form, just call/Zalo buttons).
```
