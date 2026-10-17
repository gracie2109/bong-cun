# Y tế: ba việc còn lại

**Tiến độ:** bước 1 xong (nhãn Nội trú trên bảng chuồng, chặn trả chuồng, gia hạn, dịch vụ thêm với lượt nội trú; migration `20261023010000`). Bước 2 xong (sửa giờ, ngày kết thúc, số lượng, liều, ghi chú của y lệnh; đổi thuốc; dừng có lý do; nhật ký y lệnh; mỗi liều lưu số lượng của nó; khóa y lệnh và liều khi bệnh án đã ký; migration `20261023020000` và `20261024040000` cho bảng nội trú). Màn hình sửa có ô "Từ ngày" chỉ bật khi y lệnh chưa bắt đầu. Bước 3 xong (đánh dấu thú đã mất kèm ngày và ghi chú, hủy lịch spa, lưu trú, lượt khám hẹn còn chờ, chặn khi thú đang trong chuồng, khôi phục; migration `20261025010000`). Chưa làm ở bước 3: cột "Ngày mất" khi xuất danh sách thú (view `pet_overview` chưa có ngày mất).

Kế hoạch cho ba việc còn thiếu sau khi module Y tế (`docs/ho-so-benh-an.md`, 8 bước, migration `20261021*`) đã xong:

1. Nhãn **Nội trú** trên bảng chuồng lưu trú.
2. **Sửa y lệnh** nội trú (hiện chỉ thêm hoặc dừng), giữ quy tắc khóa của bệnh án đã ký.
3. **Ghi thú đã mất**: một thao tác có kiểm soát, kèm ảnh hưởng tới lịch spa, lưu trú, lượt khám hẹn, nhắc lịch, phía khách và báo cáo.

Không nằm trong đợt này: checkout bước 9–11 (GHN API, VietQR, SePay), tạm ứng nội trú, hoàn tác liều đã cho, gửi tin cho khách.

## 1. Hiện trạng (đã kiểm tra trong code)

| Việc | Đang có | Còn thiếu |
| --- | --- | --- |
| Bảng chuồng | `boarding_board` trả mọi chuồng đang hoạt động, kể cả chuồng `purpose = medical / isolation`. Thú nội trú hiện như thú lưu trú thường. | Không có `kind`, `visit_id`, `purpose` trong JSON. Bấm thú nội trú mở trang lưu trú, ở đó có nút Trả chuồng, Gia hạn, Dịch vụ thêm. `check_out_boarding` không chặn lượt `kind = 'inpatient'`, nên trả chuồng từ màn lưu trú bỏ qua bước dừng y lệnh của `discharge_inpatient`. Bấm chuồng y tế trống mở dialog đặt lưu trú, rồi `save_boarding_stay` báo lỗi vì chỉ nhận loại chuồng `purpose = boarding`. Dòng thời gian và danh sách lượt lưu trú cũng không phân biệt nội trú. |
| Y lệnh | `save_inpatient_order` (tạo, sinh liều theo ngày × giờ), `stop_inpatient_order` (dừng, xóa liều chờ trong tương lai), `give_inpatient_dose` cộng `qty_per_dose` vào một dòng `medical_visit_items`. Lượt khám không ký được khi thú còn nằm (`medical_visits_inpatient_guard`). | Không sửa được liều, giờ, ngày kết thúc. Không có nhật ký thay đổi. Liều đã cho không lưu số lượng của chính nó. Không có trigger khóa y lệnh khi lượt khám đã ký (hiện chỉ dựa vào việc RPC đòi lượt lưu trú `checked_in`). |
| Thú đã mất | Cột `pets.status` (`active / deceased / archived`) và `pets.deceased_on`. Ký với kết luận `deceased` đặt cả hai. Menu "Đánh dấu đã mất" ở chi tiết thú gọi `update pets set status` trực tiếp (`packages/supabase/src/pets/pets.ts`, `setPetStatus`): không ghi ngày, không xác nhận, không dọn lịch. `check_in_medical_visit` chặn thú đã mất (`pet_deceased`). `medical_reminders` đã lọc `p.status = 'active'`, nên nhắc tiêm và tái khám đã tự tắt. `save_boarding_stay` và `check_in_boarding` đòi thú `active` (lỗi `no_pet`). `my_pets` và `my_pet_health` chỉ trả thú `active`, nên thú đã mất biến mất khỏi trang khách. | `save_appointment` (spa ở quầy) và `book_my_appointment` (khách đặt online) không kiểm tra trạng thái thú. Lịch spa, lượt lưu trú đã đặt và lượt khám hẹn trước của thú vẫn còn. Trả về `active` không xóa `deceased_on`. |

## 2. Mặc định đã chọn

1. **Nhãn Nội trú** dựa trên `boarding_stays.kind = 'inpatient'`, không dựa trên loại chuồng: chuồng y tế trống hiện nhãn loại chuồng ("Y tế" / "Cách ly"), chuồng có thú nội trú hiện nhãn "Nội trú" kèm mã lượt khám.
2. Bấm thú nội trú trên bảng chuồng mở **màn Nội trú** (`medicalWard`) nếu người dùng có `medical: VIEW`, không thì mở trang lưu trú ở chế độ chỉ xem. Chuồng y tế / cách ly trống **không** mở dialog đặt lưu trú; nhập nội trú chỉ đi từ trang khám.
3. Trang lưu trú của lượt nội trú ẩn Trả chuồng, Gia hạn, Dịch vụ thêm, Hủy, và hiện dòng "Lượt nội trú, quản lý ở màn Nội trú". DB cũng chặn: `check_out_boarding`, `extend_boarding_stay`, `add_boarding_extra` từ chối lượt nội trú (hint `inpatient_stay`). Ra viện chỉ qua `discharge_inpatient`.
4. **Sửa y lệnh** chỉ cho sửa: liều ghi chữ (`dose`), số lượng mỗi liều, giờ trong ngày, ngày kết thúc, ghi chú. Ngày bắt đầu chỉ sửa được khi chưa có liều nào được ghi (cho hoặc bỏ). **Không** đổi loại, thuốc hay dịch vụ: muốn đổi thuốc thì dùng nút "Đổi thuốc", nút này dừng y lệnh cũ và mở form tạo y lệnh mới đã điền sẵn (hai lệnh trong một RPC, xem 4.2).
5. Sửa giờ hoặc ngày chỉ ảnh hưởng **liều chưa tới giờ và chưa ghi**: liều đã cho, đã bỏ, hay đã quá giờ mà chưa ghi (bị lỡ) giữ nguyên để trợ lý vẫn tích được và bệnh án không mất dấu.
6. Sửa số lượng mỗi liều chỉ áp dụng cho liều cho sau đó. Số đã cộng vào dòng tính tiền không đổi. Mỗi liều lưu số lượng của chính nó (`inpatient_doses.qty`).
7. Mọi lần tạo, sửa, dừng, đổi thuốc đều vào **nhật ký y lệnh** (trước / sau, người sửa, lúc sửa, lý do). Lý do **không bắt buộc**; ô lý do có sẵn trong form sửa.
8. **Khóa theo bệnh án đã ký**: khi `medical_visits.signed_at` có giá trị, trigger chặn mọi thêm, sửa, xóa ở `inpatient_orders` và `inpatient_doses` của lượt đó (hint `signed`), giống trigger khóa SOAP. Sau ký, muốn ghi gì thêm thì dùng phần bổ sung (addenda) đã có.
9. Quyền sửa y lệnh: `medical: UPDATE` tại cơ sở của lượt nội trú (giống tạo và dừng).
10. **Ghi thú đã mất** qua RPC mới `mark_pet_deceased`, quyền `pets: UPDATE` (như menu hiện tại). Ngày mất mặc định hôm nay, không được sau hôm nay và không trước ngày sinh. Có ghi chú tùy chọn (`pets.deceased_note`).
11. Khi ghi đã mất, hệ thống **tự hủy**: dòng spa còn `booked` của thú (hết dòng thì hủy cả lịch hẹn), thú trong lượt lưu trú còn `booked` (hết thú thì hủy cả lượt), lượt khám `scheduled` của thú (kể cả tái khám). Lý do hủy: "Thú đã mất". Nhắc tiêm và tái khám tự tắt (đã có nhờ bộ lọc `active`).
12. **Chặn** ghi đã mất khi thú đang ở trong chuồng (lượt lưu trú hoặc nội trú `checked_in`), hint `pet_in_kennel`: trả chuồng hoặc cho ra viện trước để tính đúng tiền đêm. Lịch spa đã check-in hoặc đang làm và lượt khám đang chờ / đang khám **không** tự hủy; hộp xác nhận liệt kê để nhân viên tự xử lý (lượt khám vẫn ký được bình thường).
13. Mọi đường dẫn tới trạng thái đã mất (RPC mới, ký với kết luận "Đã mất", hay update trực tiếp còn sót) đi qua **một trigger** trên `pets`, nên việc dọn lịch luôn xảy ra.
14. **Khôi phục** (ghi nhầm): `restore_pet` đưa về `active`, xóa `deceased_on`, `deceased_note`. Lịch đã hủy không tự mở lại; nhắc lịch tự hiện lại.
15. **Phía khách**: thú đã mất **vẫn hiện** ở "Thú cưng của tôi", xếp cuối, mờ, nhãn "Đã mất · ngày", không có dòng mũi tiêm tiếp theo, không có nút đặt lịch. Sổ sức khỏe vẫn xem được (lịch sử khám, sổ tiêm). Thú đã mất không có trong danh sách chọn thú khi đặt spa. Không gửi tin cho khách (chưa có kênh).
16. **Báo cáo**: không đổi số doanh thu (hóa đơn cũ giữ nguyên). Danh sách thú lọc theo trạng thái như hiện nay; file xuất thú thêm cột "Ngày mất". Không thêm báo cáo mới.

## 3. Bước 1: nhãn Nội trú trên bảng chuồng

**Migration** `supabase/migrations/20261023010000_inpatient_on_kennel_board.sql` (chạy lại được):

- `boarding_board`: thêm vào mỗi chuồng `purpose` (từ `kennel_types.purpose`), vào mỗi thú `kind`, `visit_id`, `visit_code` (join `medical_visits`). Giữ nguyên chữ ký hàm. Bắt đầu từ định nghĩa hiện tại trong `supabase/schema.sql`.
- `boarding_timeline`: thêm `kind`, `visit_code` cho mỗi thanh.
- `list_boarding_stays`: thêm `kind`, `visit_code` vào mỗi dòng (không đổi tham số; không thêm bộ lọc mới).
- `get_boarding_stay` (hoặc `boarding_stay_json`): thêm `kind`, `visit_id`, `visit_code`.
- `check_out_boarding`, `extend_boarding_stay`, `add_boarding_extra`: từ chối `kind = 'inpatient'` với hint `inpatient_stay`. `move_boarding_pet` đã đòi cùng loại chuồng; bước này chỉ kiểm tra lại và ghi vào test.
- Thêm `inpatient_stay` vào danh sách mã lỗi ở `packages/core/src/boarding` (test mã lỗi đọc `schema.sql`).

**Code** (mỗi file dưới ~300 dòng):

| File | Việc |
| --- | --- |
| `packages/core/src/boarding/` (type `BoardKennel`, `BoardPet`) | Thêm `purpose`, `kind`, `visitId`, `visitCode` |
| `packages/supabase/src/boarding/board.ts`, mapper của stay và timeline | Đọc trường mới |
| `apps/web/src/features/admin/boarding/board/KennelPetLine.vue` (mới) | Một dòng thú trong thẻ chuồng, có chip "Nội trú · KB…" màu tím, tách khỏi `KennelCard.vue` |
| `apps/web/src/features/admin/boarding/board/KennelPurposeChip.vue` (mới) | Chip "Y tế" / "Cách ly" cho chuồng trống loại y tế |
| `apps/web/src/features/admin/boarding/board/useBoardingBoard.ts` | `openKennel`: thú nội trú thì `router.push({ name: 'medicalWard' })` khi có quyền, không thì trang lưu trú; chuồng y tế trống không mở dialog |
| `apps/web/src/features/admin/boarding/board/BoardStats.vue` | Thêm số "Nội trú" |
| `apps/web/src/features/admin/boarding/detail/InpatientNotice.vue` (mới) + `StayHeader.vue` | Dòng thông báo và link sang màn Nội trú / lượt khám; ẩn nút thao tác |
| `apps/web/src/features/admin/boarding/timeline/TimelineRow.vue` | Thanh nội trú có viền tím và chữ "Nội trú" |
| `apps/web/src/features/admin/boarding/stays/StayRow.vue` | Chip "Nội trú" |
| `i18n` `admin.json` (vi, en) | `boarding.board.inpatient`, `boarding.board.purpose.*`, `boarding.detail.inpatientNotice`, lỗi `inpatient_stay` |

**Test**: thêm vào `supabase/tests/boarding.test.sql`: bảng chuồng trả `kind = 'inpatient'` và `visit_code` cho thú nội trú, `purpose` cho chuồng; `check_out_boarding`, `extend_boarding_stay`, `add_boarding_extra` trên lượt nội trú báo `inpatient_stay`; lượt lưu trú thường không đổi. Typecheck, build, Vitest.

## 4. Bước 2: sửa y lệnh

### 4.1 Dữ liệu

Migration `supabase/migrations/20261023020000_inpatient_order_edits.sql`:

- `inpatient_doses.qty numeric(10,2)` (null cho liều chưa cho). Điền lại cho liều đã cho: `qty = order.qty_per_dose` khi `given_at is not null and qty is null`.
- Bảng `inpatient_order_changes`: `id`, `order_id` (cascade), `visit_id`, `action` (`create`, `update`, `stop`, `replace`), `before jsonb`, `after jsonb`, `reason text`, `changed_by`, `changed_by_name`, `changed_at`. RLS đọc `can_medical('VIEW')`; không ai insert / update / delete trực tiếp.
- Trigger `inpatient_orders_signed_lock` (BEFORE INSERT, UPDATE, DELETE trên `inpatient_orders`) và `inpatient_doses_signed_lock` (trên `inpatient_doses`): lượt khám đã ký thì báo `signed`. Ngoại lệ: không có (ra viện xảy ra trước khi ký, nên `discharge_inpatient` không bị chặn).

### 4.2 RPC

| RPC | Việc | Lỗi |
| --- | --- | --- |
| `update_inpatient_order(p_id uuid, p jsonb)` | `p`: `dose?`, `qty_per_dose?`, `times?`, `start_on?`, `end_on?`, `note?`, `reason?`. Khóa dòng y lệnh. Kiểm tra: lượt lưu trú `checked_in`, y lệnh chưa dừng, `medical: UPDATE`, giờ đúng dạng `HH:MM` (1 đến 8 giờ), `end_on ≥ hôm nay`, `end_on ≥ start_on`, `end_on ≤ start_on + 30`, `start_on` chỉ đổi khi chưa có liều được ghi. Trường `kind`, `product_id`, `service_id`, `name` có mặt và khác hiện tại thì báo `replace_order`. Xóa liều chưa ghi có `due_at > now()`, sinh lại liều từ `greatest(start_on, hôm nay)` tới `end_on` theo giờ mới, bỏ các mốc đã quá giờ và mốc trùng (`on conflict do nothing`). Ghi `inpatient_order_changes` (`update`, trước / sau). Trả `{ id, doses_added, doses_removed }` | `not_found`, `not_editable`, `order_stopped`, `bad_input`, `replace_order`, `signed` |
| `replace_inpatient_order(p_id uuid, p jsonb)` | Dừng y lệnh cũ (như `stop_inpatient_order`) rồi tạo y lệnh mới từ `p` (cùng định dạng `save_inpatient_order`), trong một giao dịch. Ghi `replace` vào nhật ký của y lệnh cũ, `create` cho y lệnh mới. Trả id mới | như trên |
| `save_inpatient_order` | Bản mới: thêm dòng nhật ký `create` | |
| `stop_inpatient_order(p_id uuid, p_reason text default null)` | Bản mới: thêm lý do, ghi `stop`. Bản một tham số cũ được `drop` trong migration và tạo lại với tham số mặc định để client cũ vẫn gọi được | |
| `give_inpatient_dose` | Bản mới: ghi `qty` của liều | |
| `inpatient_order_history(p_order uuid)` | Danh sách thay đổi, mới nhất trước | |
| `inpatient_ward` | Mỗi y lệnh thêm `edited` (số lần sửa) và `missed` (số liều quá giờ chưa ghi trong ngày) | |

Thêm `replace_order`, `order_stopped` vào `packages/core/src/medical/errors.ts`. Thêm zod contract cho đầu vào `update_inpatient_order` vào `packages/core` (giống contract của luồng tiền).

### 4.3 Màn hình

| File | Việc |
| --- | --- |
| `apps/web/src/features/admin/medical/ward/OrderDialog.vue` | Chế độ sửa: nhận `order`, khóa ô thuốc / dịch vụ, khóa ngày bắt đầu khi đã có liều được ghi, thêm ô lý do. Nếu file vượt ~300 dòng thì tách `OrderTimesField.vue`, `OrderDatesField.vue` |
| `apps/web/src/features/admin/medical/ward/orderDraft.ts` | `draftFromOrder(order)`, hàm so sánh để chỉ gửi trường đã đổi |
| `apps/web/src/features/admin/medical/ward/useOrderEdit.ts` (mới) | Mutation sửa, đổi thuốc, dừng có lý do; làm mới bảng y lệnh |
| `apps/web/src/features/admin/medical/ward/OrderActions.vue` (mới) | Menu ba chấm của y lệnh: Sửa, Đổi thuốc, Dừng; tách khỏi `WardCard.vue` |
| `apps/web/src/features/admin/medical/ward/OrderHistoryPopover.vue` (mới) | Chip "Đã sửa n lần" mở danh sách thay đổi (giờ, người, trước → sau, lý do) |
| `apps/web/src/features/admin/medical/ward/StopOrderDialog.vue` (mới) | Xác nhận dừng, ô lý do |
| `packages/supabase/src/medical/inpatientOrders.ts` (mới) | `updateInpatientOrder`, `replaceInpatientOrder`, `stopInpatientOrder(id, reason)`, `inpatientOrderHistory`; giữ `inpatient.ts` dưới 300 dòng |
| `packages/core/src/medical/inpatient.ts` | Type `InpatientOrderChange`, trường `edited`, `missed` |
| `i18n` | Nhãn sửa, đổi thuốc, lịch sử, lỗi mới |

**Test** `supabase/tests/inpatient_orders.test.sql` (mới): sửa giờ thì liều tương lai đổi, liều đã cho và liều lỡ còn nguyên; rút ngày kết thúc xóa liều sau đó; đổi ngày bắt đầu sau khi đã cho một liều báo `bad_input`; đổi thuốc qua `update` báo `replace_order`; `replace` dừng cũ, tạo mới, nhật ký có hai dòng; đổi số lượng rồi cho liều thì dòng tính tiền cộng số mới, liều cũ giữ số cũ; bác sĩ cơ sở khác hoặc thu ngân báo `42501`; sau ra viện và ký, update thẳng vào `inpatient_orders` (vai `postgres` giả lập) báo `signed`.

## 5. Bước 3: ghi thú đã mất (DB và admin)

### 5.1 Dữ liệu và trigger

Migration `supabase/migrations/20261025010000_pet_deceased.sql`:

- `pets.deceased_note text`.
- `pets_deceased_before` (BEFORE UPDATE OF status trên `pets`):
  - Sang `deceased`: chặn nếu thú có lượt lưu trú hoặc nội trú `checked_in` (hint `pet_in_kennel`); `deceased_on` mặc định ngày làm việc hiện tại; chặn ngày mất sau hôm nay hoặc trước `birth_date` (`bad_input`).
  - Rời `deceased`: xóa `deceased_on`, `deceased_note`.
- `pets_deceased_after` (AFTER UPDATE OF status, khi sang `deceased`) gọi `pet_deceased_cleanup(pet_id)` (security definer, không cấp cho client):
  - `appointment_items` của thú trong lịch `booked` → `cancelled`; lịch không còn dòng nào khác `cancelled` → `appointments.status = 'cancelled'`, `cancel_reason = 'Thú đã mất'`. Nếu lịch lưu tổng tiền hay thời lượng, tính lại theo cách `save_appointment` đang tính khi bỏ dòng (luồng code kiểm tra trong `schema.sql`).
  - `boarding_stay_pets` của thú trong lượt `booked` → `cancelled`; lượt không còn thú `active` → `cancelled` với cùng lý do.
  - `medical_visits` `scheduled` của thú → `cancelled` với cùng lý do.
- `pet_deceased_preview(p_pet uuid)`: trả những gì sẽ hủy (`appointments`, `stays`, `visits`, mỗi dòng có mã, ngày, cơ sở) và những gì cần tự xử lý (`blocking`: lượt đang ở chuồng; `open`: lịch spa đã check-in / đang làm, lượt khám đang chờ / đang khám). Quyền `pets: VIEW`.
- `mark_pet_deceased(p_pet uuid, p jsonb)`: `p`: `deceased_on?`, `note?`. Quyền `pets: UPDATE`. Đã mất rồi thì báo `already_done`. Cập nhật `pets` (trigger làm phần còn lại). Trả `{ cancelled: { appointments, stays, visits } }`.
- `restore_pet(p_pet uuid)`: `deceased` hoặc `archived` → `active`. Quyền `pets: UPDATE`.
- `sign_medical_visit` không đổi: update `pets` của nó đi qua cùng trigger.
- Thêm `pet_in_kennel` vào mã lỗi (`packages/core`).

### 5.2 Màn hình admin

| File | Việc |
| --- | --- |
| `packages/supabase/src/pets/petLifecycle.ts` (mới) | `petDeceasedPreview`, `markPetDeceased`, `restorePet`; `pets.ts` (255 dòng) chỉ thêm `deceasedOn`, `deceasedNote` vào mapper. `setPetStatus` chỉ còn dùng cho lưu trữ |
| `apps/web/src/features/admin/pets/deceased/MarkDeceasedDialog.vue` (mới) | Ngày mất, ghi chú, danh sách sẽ hủy và việc cần tự xử lý; nút xác nhận tắt khi có `blocking` (kèm link tới lượt lưu trú / màn Nội trú) |
| `apps/web/src/features/admin/pets/deceased/useMarkDeceased.ts` (mới) | Query xem trước, mutation, làm mới chi tiết thú, lịch spa, lưu trú, hàng chờ |
| `apps/web/src/features/admin/pets/deceased/RestorePetDialog.vue` (mới) | Xác nhận khôi phục, nói rõ lịch đã hủy không mở lại |
| `apps/web/src/features/admin/pets/detail/PetProfileHeader.vue`, `detail/Index.vue` | Menu mở dialog thay vì đổi trạng thái ngay; nhãn "Đã mất · ngày" và ghi chú |
| `apps/web/src/features/admin/pets/components/PetRow.vue` | Nhãn "Đã mất" |
| `apps/web/src/features/admin/pets/petsExportColumns.ts` | Cột "Ngày mất" |
| Chọn thú ở dialog lịch spa và dialog lưu trú | Bỏ thú không `active` khỏi danh sách (nếu ô chọn đang lấy cả thú đã mất) |
| `i18n` | Nhãn, lỗi `pet_in_kennel`, `pet_deceased` cho spa |

**Test** `supabase/tests/pet_deceased.test.sql` (mới): ghi đã mất hủy dòng spa `booked` (lịch hai thú chỉ hủy dòng của thú này, lịch một thú bị hủy cả), hủy thú trong lượt lưu trú `booked`, hủy lượt khám `scheduled`; lịch spa đã check-in giữ nguyên; thú đang ở chuồng báo `pet_in_kennel`; ngày mất ngày mai báo `bad_input`; ký lượt khám với kết luận "Đã mất" cũng hủy lịch (qua trigger); `medical_reminders` không còn thú; `restore_pet` xóa ngày mất, nhắc hiện lại; nhân viên không có `pets: UPDATE` báo `42501`.

## 6. Bước 4: chặn đặt lịch và phía khách

Migration `supabase/migrations/20261023040000_deceased_pet_bookings_and_customer_view.sql`:

- `save_appointment` và `book_my_appointment`: thú không `active` thì báo `pet_deceased` (đã mất) hoặc `no_pet` (lưu trữ). Bắt đầu từ định nghĩa trong `schema.sql`.
- `my_pets`: trả cả thú `deceased` của khách (vẫn bỏ `archived`), thêm `status`, `deceased_on`; thú đã mất không có `next_vaccine`, `has_open_appointment = false`; xếp thú `active` trước.
- `my_pet_health`: nhận thú `deceased`.

| File | Việc |
| --- | --- |
| `packages/supabase/src/account/pets.ts` | Đọc `status`, `deceasedOn` |
| `apps/web/src/features/shop/account/pets/` (thẻ thú) và `overview/components/PetsTile.vue` | Thẻ mờ, nhãn "Đã mất · ngày", không nút đặt lịch; đếm "thú đang theo dõi" chỉ tính thú `active` |
| Trang sổ sức khỏe của khách | Dòng "Đã mất ngày …" ở đầu, ẩn mũi tiêm tiếp theo |
| Chọn thú khi khách đặt spa | Lọc `status === 'active'` |
| `i18n` `shop.json` | Nhãn |

**Test**: `supabase/tests/pet_deceased.test.sql` thêm: `book_my_appointment` và `save_appointment` với thú đã mất báo `pet_deceased`; `my_pets` trả thú đã mất với `deceased_on` và không có mũi tiếp theo; `my_pet_health` mở được. Contract test trong `apps/web/tests/db` không cần đổi.

## 7. Thứ tự làm (mỗi bước một PR)

| Bước | PR | Migration | Phụ thuộc |
| --- | --- | --- | --- |
| 1 | Nhãn Nội trú trên bảng chuồng, chặn thao tác lưu trú với lượt nội trú | `20261023010000_inpatient_on_kennel_board.sql` | |
| 2 | Sửa, đổi thuốc, dừng có lý do, nhật ký y lệnh, khóa khi đã ký | `20261023020000_inpatient_order_edits.sql` | |
| 3 | Ghi thú đã mất, dọn lịch, khôi phục, admin | `20261025010000_pet_deceased.sql` | |
| 4 | Chặn đặt spa cho thú đã mất, khách xem thú đã mất | `20261023040000_deceased_pet_bookings_and_customer_view.sql` | sau bước 3 |

Mỗi PR: `npm run db:start`, `npm run db:test`, `npm run db:schema` và commit `supabase/schema.sql`; typecheck, build, Vitest, `deps:check`. Migration forward-only, chạy lại được (`create or replace`, `if not exists`, `drop ... if exists` cho trigger và policy). Khi merge vào `main`, workflow "Supabase migrate" tự chạy. Bản dán tay (dự phòng): `/mnt/project-files/pet-care-plan/migration-y-te-con-lai-1..4.sql`. Mỗi bước xong cập nhật dòng tiến độ ở đầu file này và ở `docs/ho-so-benh-an.md`.

## 8. grace cần làm

- Không có cài đặt mới. Chỉ cần vai trò nào được ghi thú đã mất thì có quyền **Thú cưng: Sửa** (vai trò bác sĩ đang có `medical: UPDATE` nhưng cần kiểm tra quyền thú).
- Thử trên trình duyệt khi xong:
  1. Nhập nội trú một thú, mở Lưu trú > Sơ đồ chuồng: chuồng hiện "Nội trú", bấm vào sang màn Nội trú; trang lưu trú của lượt đó không có nút Trả chuồng.
  2. Ở màn Nội trú: sửa giờ một y lệnh, đổi số lượng, đổi thuốc, dừng có lý do; xem "Đã sửa" và lịch sử.
  3. Tạo lịch spa và lượt lưu trú tương lai cho một thú, ghi thú đã mất: hai lịch bị hủy, thú biến khỏi Nhắc lịch; trang khách hiện thú mờ "Đã mất" và vẫn mở được sổ sức khỏe; khôi phục thì nhãn mất.

## 9. Trường hợp biên

| Tình huống | Xử lý |
| --- | --- |
| Sửa giờ lúc 10:00 từ 08:00, 20:00 thành 09:00, 21:00 | Liều 08:00 hôm nay giữ (đã cho hoặc lỡ), liều 20:00 hôm nay bị xóa, sinh 21:00 hôm nay và 09:00, 21:00 các ngày sau. 09:00 hôm nay đã qua nên không sinh |
| Kéo dài ngày kết thúc quá 30 ngày từ ngày bắt đầu | `bad_input`; tạo y lệnh mới |
| Hai người sửa cùng lúc | `for update` trên y lệnh; người sau thấy bản mới khi bảng làm mới |
| Thú mất khi đang nội trú | Bác sĩ cho ra viện (tính tiền đêm), rồi ký lượt khám với kết luận "Đã mất" |
| Thú mất trong lúc gửi khách sạn | Trả chuồng ở màn lưu trú, rồi ghi đã mất |
| Khách có hai thú trong một lịch spa, một thú mất | Chỉ hủy dòng của thú đó; lịch giữ lại |
| Ghi nhầm đã mất | Khôi phục; đặt lại lịch bằng tay |
| Lượt khám đang khám khi ghi đã mất | Không hủy; bác sĩ ký như bình thường. Tiếp nhận mới bị chặn (`pet_deceased`, đã có) |
| Chuyển chủ thú đã mất | Không chặn (giữ lịch sử); không cần làm gì thêm |
