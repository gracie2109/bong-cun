# Ảnh thú cưng: kế hoạch

Bản 1, 2026-10-16. Kế hoạch cho việc nhân viên tải ảnh cho từng thú cưng và hiển thị ảnh đó ở
admin, POS, spa, lưu trú, y tế và trang "Thú cưng của tôi" của khách (khách chỉ xem).

## 1. Hiện trạng (đã kiểm tra trong repo)

- Bảng `public.pets` đã có cột `photo_url text` từ đầu, nhưng **không có chỗ nào để tải ảnh**:
  `PetFields.vue` không có ô ảnh, `toPetColumns()` trong `packages/supabase/src/pets/pets.ts`
  vẫn gửi `photo_url: input.photoUrl || null` mỗi lần sửa thú cưng (nghĩa là sửa hồ sơ sẽ xoá ảnh
  nếu form không gửi lại `photoUrl`).
- Đã hiển thị `photoUrl` (nếu có) ở `PetRow.vue` (danh sách) và `PetProfileHeader.vue` (chi tiết).
  `pet_overview` và `get_medical_visit` đã trả `photo_url`. Các RPC khác (lưu trú, spa, POS,
  khách) chưa trả.
- Có sẵn ba cách dùng Storage để học theo:
  - bucket `images` (công khai, 5 MB, PNG/JPEG/WebP/GIF), thư mục `catalog/` cho ảnh sản phẩm,
    policy theo `can_products(...)` (`20261015020000_product_images.sql`);
  - bucket `medical` (riêng tư, 10 MB, link ký 10 phút), file đăng ký qua RPC
    `add_medical_attachment`, nếu RPC lỗi thì client xoá file vừa tải
    (`packages/supabase/src/medical/attachments.ts`);
  - `compressImage()` trong `apps/web/src/features/admin/products/images/compressImage.ts`: thu
    nhỏ về 1600px và đổi sang WebP ngay trên trình duyệt.
- Quyền thú cưng là `has_permission('pets', <method>)` không theo chi nhánh (thú cưng dùng chung
  mọi chi nhánh), giống policy hiện có trên bảng `pets`.
- Gói Supabase **Free**: 1 GB Storage, 5 GB băng thông/tháng, **không có Image Transformations**
  (chỉ gói Pro), nên phải tự thu nhỏ ảnh trên trình duyệt. Bản backup hằng tuần
  (`docs/sao-luu-du-lieu.md`) chỉ có database, **không có file trong Storage**.

## 2. Quyết định (mặc định đã chọn)

| # | Câu hỏi | Chọn | Lý do |
| --- | --- | --- | --- |
| D1 | Bucket | Bucket mới `pet-photos`, **công khai đọc**, không cho liệt kê | Ảnh hiện ở rất nhiều màn (cả trang khách); URL công khai cache được, không phải làm mới link ký. Đường dẫn chứa UUID nên không đoán được. Tách khỏi `images` để có giới hạn và policy riêng. |
| D2 | Đường dẫn file | `<pet_id>/<uuid>.webp` | Policy và RPC kiểm tra được thư mục đầu là đúng thú cưng; tên mới mỗi lần nên cache 1 năm không bị ảnh cũ. |
| D3 | Giới hạn | Bucket: tối đa **2 MB**, chỉ `image/webp`, `image/jpeg`, `image/png` | Sau khi thu nhỏ ảnh thường 40-150 KB. Không nhận GIF (ảnh động không hợp làm avatar). |
| D4 | Thu nhỏ trên trình duyệt | Cạnh dài tối đa **800px**, WebP chất lượng 0,82, giữ tỉ lệ, không cắt | Ảnh lớn nhất trên giao diện khoảng 160px (x2 cho màn retina, x2 dư). 1 GB đủ cho khoảng 10.000 ảnh. Không làm khung cắt ảnh lần này; giao diện dùng `object-cover`. |
| D5 | Ảnh từ iPhone (HEIC) | Chọn bằng `accept="image/*"`; Safari tự chuyển sang JPEG, sau đó vẫn thu nhỏ sang WebP. Nếu trình duyệt không đọc được ảnh và loại file không thuộc D3 thì báo "Định dạng ảnh không hỗ trợ" | Không thêm thư viện đọc HEIC. |
| D6 | Mỗi thú cưng mấy ảnh | **Một ảnh đại diện**. Album nhiều ảnh: chưa làm | Ảnh khám bệnh đã có ở đính kèm bệnh án (bucket `medical`). |
| D7 | Lưu gì trong DB | Thêm cột `pets.photo_path text`; giữ `photo_url` là URL công khai để mọi màn đọc như cũ | Có đường dẫn để xoá file và để đối chiếu khi khôi phục backup; không phải sửa mapper của các màn đang đọc `photo_url`. |
| D8 | Ai tải, đổi, xoá | Người có `pets` + `UPDATE` (hoặc `CREATE` lúc vừa tạo thú cưng). Khách **chỉ xem** | Đúng quyết định "chỉ nhân viên thêm thú cưng, khách chỉ xem" (PR #104, #105). |
| D9 | Đổi ảnh | Tải file mới, gọi RPC `set_pet_photo`, RPC trả đường dẫn cũ, client xoá file cũ (không báo lỗi nếu xoá hỏng) | Giống luồng `remove_medical_attachment`. Supabase không cho xoá file Storage bằng SQL, nên việc xoá file nằm ở client. |
| D10 | Thú cưng bị xoá/lưu trữ | Lưu trữ hoặc đánh dấu đã mất: **giữ ảnh**. Xoá hẳn thú cưng: client xoá file sau khi xoá dòng | Ảnh là kỷ niệm của khách; xoá hẳn hiếm khi xảy ra. File mồ côi tìm được bằng truy vấn ở mục 6. |
| D11 | Chỗ tải ảnh ở admin | Nút trên ảnh đại diện ở `PetProfileHeader` (Đổi ảnh / Xoá ảnh), và ô ảnh tuỳ chọn trong `RegisterPetSheet` (tải sau khi tạo xong thú cưng) | Không thêm ô ảnh vào form sửa (`PetEditSheet`), để form sửa không đụng tới ảnh. |
| D12 | Sao lưu ảnh | Bước tuỳ chọn cuối kế hoạch: workflow backup tải thêm bucket `pet-photos`. Mặc định **có làm** vì ảnh của khách không tạo lại được | Ảnh nhỏ (D4) nên file nén vẫn nhỏ. |

## 3. Database

### 3.1 Migration `20261024010000_pet_photos.sql`

Forward-only, chạy lại được nhiều lần.

- Bucket:

  ```sql
  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  values ('pet-photos', 'pet-photos', true, 2097152, array['image/webp', 'image/jpeg', 'image/png'])
  on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;
  ```

- Hàm phụ `public.can_edit_pet_photos()` (stable, security definer, `search_path = ''`):
  `has_permission('pets','UPDATE') or has_permission('pets','CREATE')`.
- Policy trên `storage.objects` (`drop policy if exists` trước mỗi `create policy`):
  - `pet-photos: upload` (insert): `bucket_id = 'pet-photos'` và `can_edit_pet_photos()` và thư
    mục đầu là UUID của một thú cưng có thật
    (`exists (select 1 from public.pets where id::text = (storage.foldername(name))[1])`).
  - `pet-photos: read` (select, cho `authenticated`): `bucket_id = 'pet-photos'` và
    `can_edit_pet_photos()`. Cần vì `remove()` đọc dòng trước khi xoá. Ảnh vẫn xem được qua URL
    công khai mà không cần policy này; không có policy cho `anon` nên không ai liệt kê được bucket.
  - `pet-photos: delete` (delete): như read.
  - Không có policy update: không ghi đè file (tải với `upsert: false`).
- Cột: `alter table public.pets add column if not exists photo_path text;`
- RPC `public.set_pet_photo(p_pet uuid, p_path text, p_url text) returns text` (security
  definer, `search_path = ''`):
  - thú cưng không có: `P0002`, hint `not_found`;
  - không có quyền `can_edit_pet_photos()`: `42501`;
  - `p_path` khác null mà không bắt đầu bằng `p_pet || '/'`, hoặc `p_url` không kết thúc bằng
    `'/storage/v1/object/public/pet-photos/' || p_path`: `22023`, hint `bad_input`;
  - `p_path` null thì `p_url` phải null (xoá ảnh);
  - khoá dòng (`for update`), lưu `photo_path`, `photo_url`, `updated_at = now()`, trả
    `photo_path` cũ (null nếu trước đó không có hoặc chỉ có `photo_url` nhập tay).
  - `revoke execute ... from public, anon; grant execute ... to authenticated;`
- `notify pgrst, 'reload schema';`

Không đụng tới policy update sẵn có của bảng `pets`; app chỉ đổi ảnh qua RPC (xem bước 2).

### 3.2 Migration `20261024020000_pet_photo_in_staff_rpcs.sql`

Thêm khoá `photo_url` vào JSON thú cưng của các RPC màn nhân viên. Mỗi hàm phải chép từ định
nghĩa **hiện tại** trong `supabase/schema.sql` rồi chỉ thêm một dòng `'pet_photo_url', p.photo_url`
(hoặc `'photo_url'` nếu object đó là object thú cưng). Danh sách (kiểm tra lại khi code):

- Lưu trú: `boarding_stay_json`, `boarding_board`, `list_boarding_stays`, `inpatient_ward`.
- Spa: `spa_day_board`, `list_appointments`.
- Y tế: `medical_visit_json`, `list_medical_visits` (`get_medical_visit` đã có).
- POS: `billable_appointment_items`, `billable_boarding_charges`, `billable_medical_items` (để
  thẻ phiếu spa / lưu trú / khám trong POS có ảnh nhỏ).

Nếu một hàm dài và chỉ dùng cho một màn ít quan trọng thì được phép bỏ, ghi lại trong PR.

### 3.3 Migration `20261024030000_pet_photo_in_customer_rpcs.sql`

Như 3.2 cho các hàm của khách: `my_pets`, `my_pet_health`, `my_appointments`,
`my_boarding_stay_json`. Các hàm này vẫn chỉ đọc, không thêm hàm ghi nào cho khách.

## 4. Code

Tuân thủ luật chia file: mỗi file dưới khoảng 300 dòng; giao diện, logic (composable), hàm thuần
và kiểu nằm ở file riêng.

| File | Việc |
| --- | --- |
| `apps/web/src/lib/images/compressImage.ts` (chuyển từ `features/admin/products/images/`) | Thêm tham số `{ maxEdge, quality }` (mặc định giữ 1600 / 0,85 cho ảnh sản phẩm). Sản phẩm import lại đường dẫn mới. Test Vitest sẵn có (nếu có) đi theo; thêm test cho `fitWithin`. |
| `packages/supabase/src/pets/petPhotos.ts` | `PET_PHOTO_BUCKET`, `MAX_PET_PHOTO_BYTES`, `PET_PHOTO_TYPES`, `validatePetPhoto(file)` trả `"type" \| "size" \| null`, `uploadPetPhoto(client, petId, file)` (đường dẫn D2, `cacheControl: "31536000"`, `upsert: false`), `setPetPhoto(client, petId, file)` (tải, gọi RPC, RPC lỗi thì xoá file vừa tải, thành công thì xoá file cũ không báo lỗi), `removePetPhoto(client, petId)`. Xuất qua barrel `@bongcun/supabase/pets`. |
| `packages/supabase/src/pets/pets.ts` | Bỏ `photo_url` khỏi `toPetColumns()` và `photoUrl` khỏi `PetInput`, để sửa hồ sơ không xoá ảnh. `register_pet` vẫn nhận `photo_url` null như hiện nay. |
| `packages/supabase/src/db/database.types.ts` | Sinh lại kiểu (cột `photo_path`, RPC `set_pet_photo`). |
| `packages/core` | Không đổi: hint `bad_input` / `not_found` đã có trong danh sách mã lỗi. |
| `apps/web/src/features/admin/pets/photo/usePetPhoto.ts` | Composable: `uploading`, `error`, `change(file)` (validate, `compressImage({ maxEdge: 800, quality: 0.82 })`, `setPetPhoto`), `remove()`; sau khi xong làm mới query chi tiết và danh sách thú cưng. |
| `apps/web/src/features/admin/pets/photo/PetPhotoButton.vue` | Ảnh đại diện + menu "Đổi ảnh" / "Xoá ảnh" (ẩn khi không có quyền `pets` UPDATE), input file ẩn `accept="image/*"`, trạng thái đang tải. |
| `apps/web/src/features/admin/pets/detail/PetProfileHeader.vue` | Thay `Avatar` bằng `PetPhotoButton`. |
| `apps/web/src/features/admin/pets/components/RegisterPetSheet.vue` (+ section) | Ô ảnh tuỳ chọn; giữ `File` trong form, sau khi `registerPet` trả id thì gọi `setPetPhoto`. Nếu tải ảnh lỗi thì thú cưng vẫn được tạo, báo "Đã tạo thú cưng, chưa lưu được ảnh". |
| `apps/web/src/components/common/PetAvatar.vue` | Component dùng chung: ảnh tròn `object-cover`, `loading="lazy"`, khi không có ảnh thì hiện icon loài hoặc chữ cái đầu. Dùng ở mọi màn bên dưới. |
| Các mapper trong `packages/supabase/src/{boarding,medical,spa,pos}` và `shop` | Đọc thêm `pet_photo_url` / `photo_url` thành `petPhotoUrl` / `photoUrl` (`strOrNull`). |
| Màn hiển thị | `PetRow`, `StayHeader`/`PetCard` (lưu trú), `VisitHeader` (y tế), thẻ lịch spa (`schedule/board`, `schedule/appointments`), `SpaTicketsPanel` / `MedicalVisitsPanel` / phiếu lưu trú trong POS, `shop/account/pets` (thẻ và trang sức khoẻ), lịch hẹn và lưu trú của khách. |
| i18n `vi` + `en` | Chuỗi: Đổi ảnh, Xoá ảnh, Đang tải ảnh, Ảnh tối đa 2 MB, Định dạng ảnh không hỗ trợ, Đã tạo thú cưng nhưng chưa lưu được ảnh. |

Khi xoá hẳn một thú cưng (nếu màn có nút xoá): đọc `photo_path` trước, xoá dòng, rồi xoá file
không báo lỗi.

## 5. Các bước code (mỗi bước một PR nhỏ)

| Bước | Nội dung | Migration | Test |
| --- | --- | --- | --- |
| 1 | Bucket, policy Storage, cột `photo_path`, RPC `set_pet_photo`; sinh lại `schema.sql` và kiểu DB | `20261024010000_pet_photos.sql` | pgTAP `supabase/tests/pet_photos.test.sql` + Vitest DB (bên dưới) |
| 2 | `petPhotos.ts`, bỏ `photo_url` khỏi `toPetColumns`, chuyển `compressImage` sang `lib/images` có tham số; test Vitest cho `fitWithin` và `validatePetPhoto` | không | `npm test`, typecheck |
| 3 | `PetAvatar`, `usePetPhoto`, `PetPhotoButton` ở chi tiết thú cưng, ô ảnh khi đăng ký thú cưng, `PetRow` dùng `PetAvatar` | không | typecheck, build |
| 4 | Ảnh ở lưu trú, spa, y tế, POS | `20261024020000_pet_photo_in_staff_rpcs.sql` | pgTAP: mỗi hàm đã sửa trả khoá ảnh; typecheck |
| 5 | Ảnh ở trang khách | `20261024030000_pet_photo_in_customer_rpcs.sql` | pgTAP: `my_pets` trả `photo_url`; khách không gọi được `set_pet_photo` |
| 6 | Backup ảnh: `supabase-backup.yml` tải bucket `pet-photos` (Storage API với khoá service role đã có trong secret, hoặc `supabase storage cp -r --experimental`), nén chung vào file backup đã mã hoá; cập nhật `docs/sao-luu-du-lieu.md` | không | chạy tay workflow một lần (`workflow_dispatch`) |

Thứ tự bắt buộc: 1 trước 2-5. Bước 4, 5, 6 độc lập với nhau.

### Test ở bước 1

pgTAP (`tests.login(user)` + `set local role authenticated`, như các test khác):

- người có `pets` UPDATE: insert vào `storage.objects` với `bucket_id = 'pet-photos'`,
  `name = '<pet id>/x.webp'` thành công; gọi `set_pet_photo` lưu được và lần hai trả đường dẫn cũ;
- người không có quyền `pets` (ví dụ chỉ có quyền bán hàng) và khách: insert vào
  `storage.objects` bị chặn, `set_pet_photo` lỗi `42501`;
- thư mục đầu không phải id thú cưng có thật: insert bị chặn;
- `p_path` của thú cưng khác hoặc `p_url` không khớp: lỗi hint `bad_input`;
- `p_path` null: xoá `photo_url` và `photo_path`;
- bucket `pet-photos` có `public = true`, `file_size_limit = 2097152`.

Vitest DB (`apps/web/tests/db`, chạy trong job `db` của CI): thêm một ca vào
`permissions.parity.test.ts` hoặc file mới `petPhotos.contract.test.ts`: quyền gọi
`set_pet_photo` khớp `has_permission('pets','UPDATE')` theo từng vai trò.

Không test được trong CI: tải file thật qua Storage API (CI chỉ chạy Postgres). Kiểm tra bằng
tay ở mục 7.

## 6. Dung lượng, chi phí, dọn file

- 1 ảnh khoảng 40-150 KB sau khi thu nhỏ; 1 GB (gói Free) đủ cho khoảng 7.000-25.000 ảnh. Băng
  thông 5 GB/tháng: ảnh được cache 1 năm và tải `lazy`, nên với một cửa hàng là đủ.
- Không có Image Transformations ở gói Free; nếu sau này lên Pro có thể dùng `transform` để lấy
  ảnh nhỏ hơn cho danh sách, không phải đổi dữ liệu.
- Truy vấn tìm file mồ côi (chạy tay trong SQL Editor khi cần, chỉ đọc):

  ```sql
  select o.name, o.created_at
  from storage.objects o
  where o.bucket_id = 'pet-photos'
    and not exists (select 1 from public.pets p where p.photo_path = o.name)
  order by o.created_at;
  ```

  Xoá file mồ côi thì làm trong trang Storage của Supabase, không xoá bằng SQL.
- Ảnh không có trong backup database cho tới khi xong bước 6. Database chỉ giữ `photo_path`, đủ
  để biết thiếu file nào khi khôi phục.

## 7. grace cần làm

- Không phải chạy SQL: migration tự chạy khi merge (workflow "Supabase migrate").
- Không phải tạo bucket bằng tay: migration tạo.
- Kiểm tra quyền: vai trò nào được đổi ảnh thì cần tick `pets` + Sửa (UPDATE) trong Phân quyền.
- Test bằng tay sau bước 3: mở chi tiết một thú cưng, đổi ảnh bằng ảnh chụp từ điện thoại
  (cả iPhone), xoá ảnh, đăng ký thú cưng mới có ảnh; sau bước 4-5: xem ảnh ở lưu trú, spa, y tế,
  POS và đăng nhập tài khoản khách xem "Thú cưng của tôi".
- Sau bước 6: chạy tay workflow backup một lần trong GitHub > Actions.

## 8. Chưa làm (cố ý)

- Album nhiều ảnh cho một thú cưng, khung cắt ảnh, khách tự tải ảnh.
- Ảnh thú cưng trên hoá đơn in.
- Dọn file mồ côi tự động (cần Edge Function hoặc job có khoá service role).

## 9. Tiến độ (2026-10-16)

| Bước | PR | Ghi chú |
| --- | --- | --- |
| 1 | #161 | Migration `20261024010000`. Lỗi đã gặp: trong policy upload, `name` trần bị hiểu là cột `name` của bảng `pets` nên phải viết `objects.name`. |
| 2 | #163 | `compressImage` đã chuyển sang `lib/images` (có tham số). `PetInput` không còn `photoUrl`. |
| 3 | #164 | `PetAvatar`, `PetPhotoButton`, `PetPhotoField`, `usePetPhoto`, `useRegisterPhoto`. |
| 4 | #165 | Migration `20261024020000`: chín hàm (`list_boarding_stays` và `list_medical_visits` nhận ảnh qua `boarding_stay_json`, `medical_visit_json`). Ảnh hiện ở kho/kennel, danh sách và chi tiết lưu trú, nội trú, hàng đợi và danh sách khám, vé spa, phiếu spa/khám trong POS. Chưa hiện ở khối lịch spa (ô nhỏ) và phiếu lưu trú trong POS (dữ liệu đã có `petPhotoUrl`, chưa vẽ). |
| 5 | #167 | Migration `20261024030000`. Ảnh ở thẻ thú cưng, sổ sức khoẻ, lịch hẹn, lưu trú của khách. |
| 6 | xem PR backup | Workflow backup tải thêm bucket `pet-photos` vào cùng file mã hoá. |

Cả ba migration chạy tự động qua workflow "Supabase migrate". Phần giao diện mới chỉ qua typecheck và build, chưa bấm thử trên trình duyệt (xem mục 7).
