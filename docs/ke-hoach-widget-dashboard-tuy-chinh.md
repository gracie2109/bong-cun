# Kế hoạch: widget dashboard tùy chỉnh

Ngày: 2026-10-23. Trạng thái: đã code xong D1 đến D8 (xem mục 15), chờ grace test tay trên trình duyệt/iPad.

Tài liệu nền: [audit Multi-Dashboard](audit-multi-dashboard.md), bản nghiên cứu `pet-care-plan/nghien-cuu-dashboard-widget.md`, và bộ kit đã merge ở `apps/web/src/features/admin/dashboard` (PR #225 đến #228).

## 1. Tóm tắt

grace muốn admin tự sắp xếp dashboard. Làm theo ba bước, mỗi bước dùng được ngay khi xong:

1. **Bố cục**: kéo đổi chỗ, kéo đổi kích thước, chế độ "Tùy chỉnh" có Lưu / Hủy / Về mặc định. Bố cục lưu theo từng người, từng dashboard, trong bảng `dashboard_layouts`.
2. **Danh mục số liệu và nút "Thêm widget"**: chọn một số liệu trong **danh sách cố định viết trong code** (doanh thu, số hóa đơn, tồn kho thấp, hết hàng, đơn chờ xử lý...), chọn kiểu hiển thị (thẻ KPI, biểu đồ cột, danh sách), thêm nhiều widget cùng kiểu với cấu hình khác nhau. Không bao giờ có SQL tự do. Mỗi số liệu kiểm quyền theo chi nhánh.
3. **Khoảng ngày riêng cho từng widget** (tùy chọn): "Hôm nay", "7 ngày qua", "Tháng này"... hoặc một khoảng cố định.

Nguyên tắc chia việc giữa code và DB (điều chỉnh so với bản nghiên cứu trước, vốn khuyên không lưu cấu hình trong DB):

| Ở đâu | Chứa gì |
| --- | --- |
| **Code** | Định nghĩa kiểu widget (component, kích thước mặc định/nhỏ nhất/lớn nhất, quyền, phạm vi), danh mục số liệu (RPC nào, tham số hợp lệ, quyền), bố cục mặc định của từng dashboard |
| **DB** | Chỉ bố cục của từng người: widget nào, ở ô nào, to bao nhiêu, cấu hình gì (khóa số liệu + tham số đã kiểm). Không chứa tên RPC, không chứa SQL, không cấp quyền gì |

Vì bố cục trong DB chỉ trỏ tới khóa trong code, một khóa lạ (widget đã bỏ, số liệu đã đổi tên) chỉ làm widget đó hiện "Mục này không còn dùng được" kèm nút xóa, không làm hỏng trang.

**SQL cần chạy**: một migration mới `supabase/migrations/20261103010000_dashboard_layouts.sql` (số mới hơn mọi migration đã chạy; mới nhất hiện tại là `20261102030000`). Workflow "Supabase migrate" tự chạy khi merge, grace không phải dán tay. Bước 2 và 3 **không cần migration** vì chỉ dùng RPC báo cáo có sẵn.

## 2. Hiện trạng (đã đọc code)

- `dashboards.ts`: mảng `DASHBOARDS` gồm 2 dashboard (`today`, `business`), mỗi widget `{ key, component, permissions, scopes, span }`.
- `dashboardRules.ts`: `widgetAccess` kiểm quyền **tại chi nhánh đang xem** qua `auth.canAt`, có trạng thái `needsBranch` khi phạm vi "Tất cả chi nhánh" mà widget chỉ trả lời được cho một chi nhánh.
- `kit/WidgetCard.vue`, `kit/widgetState.ts`: khung và 7 trạng thái (`hidden`, `needsBranch`, `loading`, `forbidden`, `error`, `empty`, `ready`).
- `kit/widgetScope.ts`: `provideWidgetScope` / `useWidgetAccess` / `useBranchIfAllowed`.
- `DashboardView.vue` (92 dòng): lưới CSS `lg:grid-cols-2`, `span` 1 hoặc 2.
- 9 widget, mỗi widget là `Xxx.vue` + `useXxx.ts` + hàm thuần. Hai widget có nút đổi kỳ ngay trên thẻ (doanh thu: hôm nay / 7 ngày / tháng này; xu hướng: 7 / 30 ngày), trạng thái này không lưu.
- RPC dùng được: `report_overview`, `report_revenue_series`, `report_top_items` (nhận `p_branch null` = mọi chi nhánh được phép, qua `report_branch_ids`), `stock_alert_counts`, `shop_order_badge`, `spa_day_board`, `boarding_board`, `medical_queue`, `medical_reminders` (chỉ một chi nhánh).
- Admin chạy `ssr: false` (`nuxt.config.ts`), nên thư viện kéo thả không vướng SSR.
- Tailwind 3.4: chưa có container query, nên widget đọc kích thước bằng `useElementSize` của VueUse (đã có sẵn), không thêm plugin.
- Chưa có bảng nào lưu tùy chọn giao diện theo người dùng.

## 3. Quyết định chính

| # | Quyết định | Lý do |
| --- | --- | --- |
| K1 | Bố cục lưu **theo người dùng và theo dashboard**, không theo chi nhánh | Một người làm ở hai chi nhánh vẫn muốn một bố cục. Widget không có quyền ở chi nhánh đang xem thì ẩn, lưới tự dồn lên khi hiển thị |
| K2 | Mọi nhân viên vào được dashboard đều tùy chỉnh được **bố cục của mình** | Không ảnh hưởng ai khác. "Admin đặt mặc định cho vai trò" để sau (mục 12) |
| K3 | Lưới 4 cột từ màn `md` (768px, iPad dọc) trở lên; dưới 768px xếp 1 cột theo thứ tự | 4 cột ở 768px là ~180px mỗi cột, đủ cho thẻ KPI. Ít cột thì kéo đổi cỡ thô hơn nhưng dễ chạm hơn trên iPad |
| K4 | Thư viện `grid-layout-plus@1.1.1` (Vue 3, dựa trên interact.js, hỗ trợ chạm), ghim đúng phiên bản, bọc trong **một** component `DashboardGrid.vue` | Kéo + đổi cỡ + dồn ô + chống chồng ô tự viết rất tốn công và dễ lỗi trên cảm ứng. Bọc một chỗ để đổi được sang tự viết (Pointer Events) nếu thư viện có vấn đề |
| K5 | Chỉ kéo bằng **tay nắm** (nút có icon grip) trên đầu thẻ, không kéo cả thẻ | Trên iPad, vuốt trong thẻ vẫn cuộn trang được. Tay nắm và góc đổi cỡ có vùng chạm ít nhất 44×44px, chỉ hiện ở chế độ Tùy chỉnh |
| K6 | Có cách sửa **không cần kéo**: mỗi thẻ ở chế độ Tùy chỉnh có menu "Lên / Xuống / Nhỏ / Vừa / Lớn / Cài đặt / Xóa" | Dùng được trên điện thoại (1 cột), bằng bàn phím, và khi kéo trên iPad khó chính xác |
| K7 | Ghi qua RPC `save_dashboard_layout` (kiểm hình dạng, giới hạn kích thước, kiểm phiên bản); đọc thẳng bảng qua RLS "chỉ dòng của mình" | Không cấp INSERT/UPDATE trực tiếp nên không ai ghi được JSON quá lớn hay sai hình |
| K8 | Chống ghi đè giữa hai tab/thiết bị bằng cột `version` (optimistic) | grace dùng cả iPad và máy tính |
| K9 | Danh mục số liệu là `Record<MetricKey, MetricDef>` trong code; tham số kiểm bằng zod; không có chuỗi SQL hay tên bảng nào đi từ client lên | Đúng yêu cầu "code whitelist" |
| K10 | Không thêm thư viện biểu đồ: dùng `StackedBarChart` có sẵn cho biểu đồ cột | Đã đủ cho bước 2. Biểu đồ đường để sau |
| K11 | Nhiều widget cùng một RPC cùng tham số dùng chung cache của vue-query | Ba thẻ KPI "doanh thu / số HĐ / TB mỗi HĐ" cùng kỳ chỉ gọi `report_overview` một lần |
| K12 | Khóa query bố cục có `user_id` | Tránh lỗi đã ghi trong audit: đăng xuất, đăng nhập người khác vẫn thấy cache cũ |

## 4. Mô hình dữ liệu

### 4.1 Bố cục (JSON trong cột `layout`)

```ts
// packages/core/src/dashboard/layout.ts (zod, nguồn sự thật cho hình dạng)
type SavedLayout = {
  v: 1;                       // phiên bản hình dạng JSON, để đổi về sau
  items: SavedItem[];         // tối đa 24
};
type SavedItem = {
  id: string;                 // ngẫu nhiên, 8-24 ký tự [a-z0-9]; nhiều widget cùng kiểu thì khác id
  type: string;               // khóa kiểu widget trong code, vd "actions", "kpi", "barChart"
  x: number; y: number;       // ô bắt đầu, cột 0..3, hàng 0..199
  w: number; h: number;       // số cột 1..4, số hàng 1..12 (1 hàng = 88px)
  config?: Record<string, unknown>; // chỉ widget có cấu hình; kiểm bằng zod của kiểu đó khi đọc
};
```

`config` của widget theo số liệu (bước 2, 3):

```ts
type MetricConfig = {
  metric: MetricKey;                    // vd "revenue.net"
  params?: Record<string, string | number>; // vd { segment: "spa" }, kiểm bằng zod của số liệu
  title?: string;                       // tên tự đặt, tối đa 60 ký tự
  range?: RangeConfig;                  // bước 3
  compare?: boolean;                    // KPI: so với kỳ trước
};
type RangeConfig =
  | { kind: "preset"; preset: "today" | "yesterday" | "last7" | "last30" | "thisMonth" | "lastMonth" }
  | { kind: "fixed"; from: string; to: string }; // yyyy-MM-dd, tối đa 366 ngày
```

Đọc bố cục: `parseLayout(json)` trả danh sách mục hợp lệ + danh sách mục hỏng (để hiện thẻ "không còn dùng được"). Không bao giờ ném lỗi làm trắng trang; JSON hỏng hoàn toàn thì dùng bố cục mặc định và ghi `console.warn`.

### 4.2 Hiển thị một bố cục

1. Không có dòng trong DB → `defaultLayout(dashboardKey)` sinh từ code.
2. Có dòng → `parseLayout`.
3. Lọc mục theo quyền ở phạm vi đang xem (`widgetAccess`, như hiện nay).
4. `compactLayout(items)` dồn lên trên để không có lỗ (hàm thuần, có test). Kết quả này **chỉ dùng để hiển thị**, không tự lưu.
5. Dưới 768px: sắp theo `(y, x)` thành một cột, chiều cao theo nội dung.

Khi bấm Lưu, mục bị ẩn vì quyền vẫn được giữ nguyên trong JSON (chỉ mục đang thấy đổi chỗ), để đổi sang chi nhánh khác không mất widget.

## 5. Migration (bước 1)

File: `supabase/migrations/20261103010000_dashboard_layouts.sql`. Nếu lúc code đã có migration số lớn hơn trên `main` thì lấy số mới hơn nữa. Viết idempotent (`if not exists`, `create or replace`, `drop policy if exists`), chỉ thêm mới, không sửa file cũ.

```sql
-- Personal dashboard layouts. Widget and metric definitions live in code; a row only says which
-- widgets a person placed where, how big, and with which whitelisted settings.
create table if not exists public.dashboard_layouts (
  user_id       uuid        not null references auth.users (id) on delete cascade,
  dashboard_key text        not null check (dashboard_key ~ '^[a-z][a-z0-9_]{0,31}$'),
  layout        jsonb       not null,
  version       integer     not null default 1,
  updated_at    timestamptz not null default now(),
  primary key (user_id, dashboard_key)
);

alter table public.dashboard_layouts enable row level security;
revoke all on public.dashboard_layouts from anon, authenticated;
grant select on public.dashboard_layouts to authenticated;

drop policy if exists "own layout read" on public.dashboard_layouts;
create policy "own layout read" on public.dashboard_layouts
  for select to authenticated using (user_id = (select auth.uid()));

-- Shape check only: the app decides which widget types and metrics exist.
create or replace function public.dashboard_layout_problem(p_layout jsonb)
returns text language sql immutable set search_path = '' as $$
  select case
    when jsonb_typeof(p_layout) <> 'object' or (p_layout ->> 'v') is distinct from '1' then 'shape'
    when jsonb_typeof(p_layout -> 'items') <> 'array' then 'shape'
    when jsonb_array_length(p_layout -> 'items') > 24 then 'too_many'
    when pg_column_size(p_layout) > 32768 then 'too_big'
    when exists (
      select 1 from jsonb_array_elements(p_layout -> 'items') i
      where jsonb_typeof(i) <> 'object'
         or coalesce(i ->> 'id', '')   !~ '^[a-z0-9]{8,24}$'
         or coalesce(i ->> 'type', '') !~ '^[a-zA-Z][a-zA-Z0-9]{0,31}$'
         or jsonb_typeof(i -> 'x') <> 'number' or jsonb_typeof(i -> 'y') <> 'number'
         or jsonb_typeof(i -> 'w') <> 'number' or jsonb_typeof(i -> 'h') <> 'number'
         or (i ->> 'x')::numeric not between 0 and 3   or (i ->> 'w')::numeric not between 1 and 4
         or (i ->> 'y')::numeric not between 0 and 199 or (i ->> 'h')::numeric not between 1 and 12
         or (i ->> 'x')::numeric % 1 <> 0 or (i ->> 'y')::numeric % 1 <> 0
         or (i ->> 'w')::numeric % 1 <> 0 or (i ->> 'h')::numeric % 1 <> 0
         or (i ->> 'x')::int + (i ->> 'w')::int > 4
         or (i ? 'config' and (jsonb_typeof(i -> 'config') <> 'object' or pg_column_size(i -> 'config') > 2048))
    ) then 'item'
    when (select count(distinct i ->> 'id') from jsonb_array_elements(p_layout -> 'items') i)
         <> jsonb_array_length(p_layout -> 'items') then 'duplicate_id'
    else null
  end;
$$;

create or replace function public.save_dashboard_layout(
  p_dashboard text, p_layout jsonb, p_expected_version integer
) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_problem text;
  v_version integer;
begin
  if v_user is null or not (select public.is_staff()) then
    raise exception 'only staff can save a dashboard layout' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_dashboard is null or p_dashboard !~ '^[a-z][a-z0-9_]{0,31}$' then
    raise exception 'bad dashboard key' using errcode = '22023', hint = 'bad_input';
  end if;
  v_problem := public.dashboard_layout_problem(p_layout);
  if v_problem is not null then
    raise exception 'invalid dashboard layout: %', v_problem using errcode = '22023', hint = 'layout_invalid';
  end if;

  if p_expected_version is null or p_expected_version = 0 then
    insert into public.dashboard_layouts (user_id, dashboard_key, layout)
    values (v_user, p_dashboard, p_layout)
    on conflict (user_id, dashboard_key) do nothing
    returning version into v_version;
  else
    update public.dashboard_layouts
    set layout = p_layout, version = version + 1, updated_at = now()
    where user_id = v_user and dashboard_key = p_dashboard and version = p_expected_version
    returning version into v_version;
  end if;

  if v_version is null then
    raise exception 'the layout was changed somewhere else' using errcode = 'P0001', hint = 'layout_conflict';
  end if;
  return v_version;
end;
$$;

create or replace function public.reset_dashboard_layout(p_dashboard text)
returns void language sql security definer set search_path = '' as $$
  delete from public.dashboard_layouts
  where user_id = (select auth.uid()) and dashboard_key = p_dashboard;
$$;

revoke all on function public.save_dashboard_layout(text, jsonb, integer) from public, anon;
revoke all on function public.reset_dashboard_layout(text) from public, anon;
revoke all on function public.dashboard_layout_problem(jsonb) from public, anon;
grant execute on function public.save_dashboard_layout(text, jsonb, integer) to authenticated;
grant execute on function public.reset_dashboard_layout(text) to authenticated;
```

Ghi chú cho thread code:

- `is_staff()` đã có (`schema.sql:5477`): đọc claim `user_role` (admin, superAdmin, cashier) hoặc `branch_ids` trong JWT, nên đã gồm admin. Test pgTAP phải đặt các claim này qua helper đăng nhập; nếu `tests.login` chưa đặt `branch_ids` thì kiểm thêm `exists (select 1 from public.staff_branches where user_id = v_user)`.
- `version = 0` nghĩa là "chưa có dòng" (client đọc không thấy dòng thì gửi 0).
- Thứ tự điều kiện trong `case` quan trọng: các phép ép kiểu `::numeric` chỉ chạy sau khi đã kiểm `jsonb_typeof = 'number'` trong cùng `or`. Postgres không bảo đảm thứ tự đánh giá `or`; nếu test pgTAP báo lỗi ép kiểu, tách thành hàm plpgsql lặp từng mục.
- Không cần index thêm: khóa chính `(user_id, dashboard_key)` đủ cho mọi truy vấn.
- Cột `updated_at` hiện "Đã lưu lúc..." ở thanh công cụ.

### 5.1 Test pgTAP: `supabase/tests/dashboard_layouts.test.sql`

Dùng `tests.login(user)` + `set local role authenticated` như các test khác.

1. Nhân viên lưu lần đầu với version 0 → trả 1; lưu tiếp với 1 → trả 2.
2. Lưu với version cũ → lỗi hint `layout_conflict`.
3. Người A không đọc được dòng của người B (RLS), không xóa được dòng của B bằng `reset_dashboard_layout`.
4. `insert`/`update`/`delete` thẳng vào bảng bị từ chối (`42501`).
5. Khách (không phải nhân viên) gọi `save_dashboard_layout` → `42501`.
6. JSON sai: `v` khác 1, quá 24 mục, `x + w > 4`, `w = 0`, `x = 1.5`, id trùng, `config` quá 2KB, `type` có ký tự lạ → hint `layout_invalid`.
7. `anon` không gọi được hàm nào.

Sau đó `npm run db:start`, `npm run db:test`, `npm run db:schema`, commit `supabase/schema.sql` (theo CLAUDE.md).

## 6. Cấu trúc code

Giữ đúng quy tắc chia file của grace: mỗi file dưới ~300 dòng, UI / logic (composable) / hàm thuần / kiểu tách riêng.

```
packages/core/src/dashboard/
  layout.ts                 zod SavedLayout, SavedItem, giới hạn (MAX_ITEMS, COLS=4, MAX_H=12)
  metricConfig.ts           zod MetricConfig, RangeConfig (bước 2, 3)
  errors.ts                 mã lỗi "layout_invalid" | "layout_conflict" cho toAppError
  index.ts
packages/supabase/src/dashboard/
  layouts.ts                fetchLayout(dashboardKey), saveLayout(...), resetLayout(...)
  index.ts
apps/web/src/features/admin/dashboard/
  DashboardView.vue         vỏ mỏng: header, switcher, scope picker, <DashboardToolbar>, <DashboardGrid>
  dashboards.ts             DASHBOARDS: key, title, scopes, requires, defaultItems (thay `widgets`)
  layout/
    gridConfig.ts           COLS, ROW_HEIGHT=88, GAP=16, breakpoint 768
    layoutMath.ts           compactLayout, clampItem, placeNewItem, moveBy, resizeTo, stackOrder (thuần, có test)
    layoutCodec.ts          parseLayout (zod → mục hợp lệ + mục hỏng), serializeLayout, defaultLayout
    useDashboardLayout.ts   vue-query: đọc dòng (key có userId), trả items + version + updatedAt
    useLayoutEditor.ts      chế độ sửa: draft, isDirty, start/cancel/save/reset, xử lý conflict
    useUnsavedGuard.ts      onBeforeRouteLeave + beforeunload khi isDirty
    DashboardGrid.vue       bọc grid-layout-plus (chỉ file này import thư viện)
    StackedList.vue         hiển thị 1 cột dưới 768px
    GridItemFrame.vue       khung một ô: tay nắm, menu sửa, thẻ "không còn dùng được"
    ItemEditMenu.vue        Lên/Xuống/Nhỏ/Vừa/Lớn/Cài đặt/Xóa
    DashboardToolbar.vue    Tùy chỉnh | Thêm widget | Về mặc định | Hủy | Lưu
  widgetTypes/
    types.ts                WidgetTypeDef, WidgetSize
    registry.ts             WIDGET_TYPES: Record<WidgetTypeKey, WidgetTypeDef>
  metrics/                  (bước 2)
    types.ts                MetricDef, MetricShape, MetricKey
    catalogue.ts            METRICS (chỉ dữ liệu, không logic)
    sources/                mỗi nguồn một composable nhỏ, dùng lại hook có sẵn của từng feature
      useOverviewSource.ts  report_overview  → number theo field
      useSeriesSource.ts    report_revenue_series → điểm biểu đồ
      useTopItemsSource.ts  report_top_items → danh sách
      useStockSource.ts     stock_alert_counts → number
      useOrdersSource.ts    shop_order_badge → number
      useBoardSources.ts    spa_day_board / boarding_board / medical_queue / medical_reminders → number
    useMetric.ts            chọn nguồn theo MetricDef, trả WidgetState + value
    metricAccess.ts         metricAllowed(def, scope, canAt) (thuần, có test)
  widgets/
    (9 widget hiện có giữ nguyên thư mục)
    metric/                 (bước 2)
      KpiMetricWidget.vue   BarMetricWidget.vue   ListMetricWidget.vue
      useMetricWidget.ts    đọc config, tính range, gọi useMetric
      kpiFormat.ts          định dạng tiền/số/phần trăm so sánh
  addWidget/                (bước 2)
    AddWidgetDialog.vue     AppDialog 2 bước: chọn số liệu → chọn kiểu + tham số
    MetricPicker.vue        danh sách theo nhóm (Doanh thu, Kho, Đơn online, Spa, Lưu trú, Y tế), có ô tìm
    MetricParamsForm.vue    tham số của số liệu (select từ enum trong MetricDef)
    WidgetSettingsDialog.vue sửa config của widget đã đặt (dùng lại MetricParamsForm, RangeFields)
    useAddWidget.ts         trạng thái dialog, tạo SavedItem (id mới, placeNewItem)
  range/                    (bước 3)
    RangeFields.vue         chọn preset hoặc khoảng cố định
    widgetRange.ts          resolveRange(config, today), rangeLabel (thuần, có test)
```

`WidgetTypeDef`:

```ts
type WidgetSize = { w: number; h: number };
type WidgetTypeDef = {
  key: WidgetTypeKey;                 // "actions" | "salesPanel" | "trend" | ... | "kpi" | "barChart" | "list"
  titleKey: string;
  component: Component;               // nhận props { config, size }
  permissions: readonly string[];     // kiểu cố định; kiểu theo số liệu thì lấy quyền của số liệu
  scopes: readonly ScopeKind[];
  defaultSize: WidgetSize;
  minSize: WidgetSize;
  maxSize: WidgetSize;
  configurable: boolean;              // có nút Cài đặt không
  multiple: boolean;                  // thêm được nhiều lần không (widget cố định: không)
  dashboards: readonly DashboardKey[];// hiện trong "Thêm widget" của dashboard nào
};
```

Kích thước gợi ý (lưới 4 cột, 1 hàng = 88px):

| Kiểu | Mặc định | Nhỏ nhất | Lớn nhất |
| --- | --- | --- | --- |
| `actions` (Việc cần xử lý) | 2×4 | 2×3 | 4×6 |
| `salesPanel` (doanh thu hôm nay / theo kỳ) | 4×3 | 2×3 | 4×4 |
| `trend` (xu hướng doanh thu) | 4×4 | 2×3 | 4×6 |
| `spaToday`, `boardingToday`, `medicalToday` | 2×3 | 1×3 | 4×5 |
| `topProducts` | 2×4 | 2×3 | 4×8 |
| `onlineOrders` | 2×3 | 1×2 | 4×4 |
| `kpi` | 1×2 | 1×2 | 2×2 |
| `barChart` | 2×4 | 2×3 | 4×6 |
| `list` | 2×4 | 1×3 | 4×8 |

Widget nhận `size` (từ ô lưới) và dùng `useElementSize` để chọn bản gọn khi hẹp, ví dụ thẻ doanh thu 2 cột thì giấu dòng 4 mảng, biểu đồ 2 cột thì giấu chú thích. `WidgetCard` đổi thành `h-full` với thân `overflow-auto` để nội dung không tràn ô.

## 7. Bước 1: bố cục kéo thả

### 7.1 Luồng người dùng

1. Mặc định: dashboard như hiện nay (bố cục mặc định sinh từ code).
2. Bấm **Tùy chỉnh** ở thanh công cụ → viền nét đứt quanh mỗi thẻ, hiện tay nắm ⠿ ở góc trái trên, góc đổi cỡ ở góc phải dưới, nút ⋯ (menu sửa). Thanh công cụ đổi thành **Thêm widget** (bước 2) · **Về mặc định** · **Hủy** · **Lưu**. Dữ liệu trong thẻ vẫn chạy để thấy kết quả thật.
3. Kéo tay nắm để đổi chỗ, kéo góc để đổi cỡ (bám theo ô, không nhỏ hơn `minSize`, không lớn hơn `maxSize`). Hoặc dùng menu ⋯.
4. **Lưu** → gọi RPC, toast "Đã lưu bố cục", thoát chế độ sửa. **Hủy** → bỏ bản nháp, về bố cục đã lưu (hỏi xác nhận nếu có thay đổi). **Về mặc định** → hỏi xác nhận, xóa dòng trong DB.
5. Rời trang khi còn thay đổi chưa lưu → hộp xác nhận (`useUnsavedGuard`). Esc trong chế độ sửa = Hủy.
6. Xung đột (đã sửa ở thiết bị khác): toast "Bố cục đã đổi ở nơi khác" kèm hai nút **Tải bản mới** / **Ghi đè bằng bản của tôi** (ghi đè = đọc version mới rồi lưu lại).

### 7.2 iPad và cảm ứng

- Tay nắm và góc đổi cỡ: vùng chạm 44×44px (nhìn thấy 24px), màu primary, chỉ hiện khi sửa.
- `drag-allow-from` = tay nắm; phần còn lại của thẻ giữ `touch-action: pan-y` để vẫn cuộn trang.
- Khi đang kéo: thẻ nổi bóng, ô đích có nền mờ; gần mép trên/dưới màn thì trang tự cuộn (interact.js có `autoScroll`).
- Dưới 768px không kéo; chỉ dùng menu ⋯ (Lên/Xuống, cỡ). Kích thước đổi ở điện thoại vẫn lưu vào cùng bố cục 4 cột (`w`), chỉ hiển thị khác.
- Test chạm bằng Playwright với `devices["iPad (gen 7)"]` (`hasTouch: true`): kéo tay nắm đổi hai thẻ, đổi cỡ một thẻ, cuộn trang bằng vuốt trong thẻ không làm thẻ di chuyển.

### 7.3 PR của bước 1

| PR | Nội dung | Kiểm |
| --- | --- | --- |
| D1 | Migration + pgTAP + `schema.sql`; `packages/core/dashboard/layout.ts` (zod), `packages/supabase/dashboard/layouts.ts`, mã lỗi `layout_invalid`/`layout_conflict` cho `toAppError` | `db:test`, `test`, typecheck |
| D2 | `widgetTypes/registry.ts` thay `widgets` trong `DASHBOARDS` bằng `defaultItems`; `layoutMath.ts`, `layoutCodec.ts` + unit test (dồn ô, kẹp cỡ, đặt mục mới, mục hỏng, thứ tự 1 cột). Trang vẫn hiển thị như cũ | `test`, `deps:check` |
| D3 | Cài `grid-layout-plus@1.1.1` (ghim đúng bản); `DashboardGrid.vue`, `StackedList.vue`, `useDashboardLayout.ts`; `WidgetCard` cao đầy ô; widget dùng `size`. Chỉ hiển thị, chưa sửa | build, Playwright chụp desktop + iPad + điện thoại |
| D4 | Chế độ sửa: `DashboardToolbar`, `GridItemFrame`, `ItemEditMenu`, `useLayoutEditor`, `useUnsavedGuard`, xung đột phiên bản, i18n vi/en | unit test `useLayoutEditor` (dirty, cancel, conflict), Playwright chạm iPad |

Nếu ở D3 thấy `grid-layout-plus` lỗi trên Safari cảm ứng (kiểm bằng Playwright WebKit với touch), phương án lùi: tự viết `usePointerDrag` + `usePointerResize` (Pointer Events, `setPointerCapture`) trên lưới CSS, dùng lại toàn bộ `layoutMath.ts`. Vì chỉ `DashboardGrid.vue` biết thư viện nên đổi không lan ra chỗ khác.

## 8. Bước 2: danh mục số liệu và "Thêm widget"

### 8.1 `MetricDef`

```ts
type MetricShape = "money" | "count" | "series" | "list";
type MetricDef = {
  key: MetricKey;                      // "revenue.net", "stock.out", ...
  group: "revenue" | "stock" | "orders" | "spa" | "boarding" | "medical";
  labelKey: string;
  shape: MetricShape;
  permission: string;                  // một quyền VIEW, kiểm tại chi nhánh bằng canAt
  scopes: readonly ScopeKind[];        // ["branch","all"] chỉ với RPC báo cáo đi qua report_branch_ids
  usesRange: boolean;                  // có nhận khoảng ngày không (bước 3)
  defaultRange?: RangePreset;
  params?: Record<string, readonly (string | number)[]>; // giá trị cho phép, vd { segment: ["all","shop",...] }
  widgetTypes: readonly ("kpi" | "barChart" | "list")[];
  source: SourceKey;                   // nguồn nào trong metrics/sources
  to?: (params) => RouteLocationRaw;   // link "Mở" tới màn chi tiết
};
```

### 8.2 Danh mục ban đầu (chỉ RPC có sẵn)

| Khóa | Hiển thị | RPC / trường | Quyền | Phạm vi | Khoảng ngày | Tham số |
| --- | --- | --- | --- | --- | --- | --- |
| `revenue.net` | KPI | `report_overview.netRevenue` (hoặc `segments.<x>`) | `reports` | branch, all | có | `segment`: all/shop/spa/boarding/medical |
| `revenue.invoiceCount` | KPI | `report_overview.invoiceCount` | `reports` | branch, all | có | |
| `revenue.avgTicket` | KPI | `report_overview.avgTicket` | `reports` | branch, all | có | |
| `revenue.refunds` | KPI | `report_overview.refunds` | `reports` | branch, all | có | |
| `revenue.pendingCod` | KPI | `report_overview.pendingCod.amount` (+ count) | `reports` | branch, all | có | |
| `revenue.grossProfit` | KPI | `report_overview.grossProfit` | `reports` | branch, all | có | |
| `revenue.series` | Biểu đồ cột | `report_revenue_series` | `reports` | branch, all | có | `bucket`: day/week/month; `stack`: segment/payment |
| `revenue.topItems` | Danh sách | `report_top_items` | `reports` | branch, all | có | `kind`: all/product/service; `sort`: revenue/qty/profit; `limit`: 5/10 |
| `stock.low` | KPI | `stock_alert_counts.low` | `inventory` | branch | không | |
| `stock.out` | KPI | `stock_alert_counts.out` | `inventory` | branch | không | |
| `stock.expiring` | KPI | `stock_alert_counts.expiring` | `inventory` | branch | không | `days`: 30/60/90 |
| `stock.expired` | KPI | `stock_alert_counts.expired` | `inventory` | branch | không | |
| `orders.pending` | KPI | `shop_order_badge` | `shop_orders` | branch | không | |
| `spa.today` | KPI | `spa_day_board` (đếm theo trạng thái, dùng `spaStats.ts`) | `schedule` | branch | không | `status`: total/waiting/inProgress/done |
| `boarding.today` | KPI | `boarding_board` (dùng `boardingStats.ts`) | `boarding` | branch | không | `count`: in/arriving/leaving/overdue |
| `medical.queue` | KPI | `medical_queue` | `medical` | branch | không | `status`: waiting/inExam |
| `medical.vaccineOverdue` | KPI | `medical_reminders(scope='overdue').total` | `medical` | branch | không | |

Tên trường cụ thể (`spa_day_board`, `boarding_board`, `medical_queue`) thread code lấy từ hàm thuần đang có trong `widgets/spa/spaStats.ts`, `widgets/boarding/boardingStats.ts`, `widgets/medical/`, không tính lại công thức.

### 8.3 Quyền

- `metricAllowed(def, scope, canAt)` dùng lại `widgetAccess` với `permissions: [def.permission]`, `scopes: def.scopes`. Không có quyền ở chi nhánh đang xem → widget ẩn (như widget cố định). Phạm vi "Tất cả" mà số liệu chỉ có `branch` → trạng thái `needsBranch` sẵn có.
- Dialog "Thêm widget" chỉ liệt kê số liệu người đó có quyền **ở ít nhất một chi nhánh được giao**; số liệu không xem được ở chi nhánh hiện tại có nhãn "Chỉ hiện ở chi nhánh có quyền".
- Server vẫn là nơi chặn: mỗi RPC tự kiểm quyền; RPC báo cáo với `p_branch null` mở rộng thành danh sách chi nhánh được phép qua `report_branch_ids` (đúng quy tắc trong CLAUDE.md). Không thêm RPC mới nào nhận `null` = mọi chi nhánh ở bước này.
- Bố cục trong DB không cấp quyền gì: sửa tay JSON thành `metric: "revenue.net"` cũng chỉ làm client gọi `report_overview`, và RPC từ chối nếu không có quyền (thẻ hiện "Bạn không có quyền xem mục này").
- `metric` không có trong `METRICS`, hoặc `params` không qua zod → thẻ "Mục này không còn dùng được" + nút Xóa (chế độ sửa).

### 8.4 Dialog "Thêm widget"

`AppDialog` (Esc đóng, Enter xác nhận), 2 bước:

1. **Chọn nội dung**: hai nhóm. "Widget có sẵn" (các kiểu cố định chưa có trên dashboard, vì `multiple: false`) và "Số liệu" theo nhóm, có ô tìm (không dấu, dùng lại helper chuẩn hóa tiếng Việt đang có).
2. **Cấu hình** (chỉ số liệu): kiểu hiển thị (chỉ các kiểu trong `widgetTypes`), tham số (select theo `params`), tên tự đặt, khoảng ngày (bước 3), so với kỳ trước (KPI). Có xem trước nhỏ dùng đúng component widget.

Bấm **Thêm** → `placeNewItem` đặt ở hàng trống đầu tiên đủ chỗ, cuộn tới, nháy viền. Mục mới nằm trong bản nháp, chỉ lưu khi bấm Lưu.

Nút **Cài đặt** trong menu ⋯ mở `WidgetSettingsDialog` dùng lại form bước 2 (không đổi được số liệu, đổi được tham số / kiểu / tên / khoảng ngày).

Giới hạn: tối đa 24 widget mỗi dashboard (khớp DB); nút Thêm mờ và có chú thích khi đủ.

### 8.5 PR của bước 2

| PR | Nội dung | Kiểm |
| --- | --- | --- |
| D5 | `packages/core/dashboard/metricConfig.ts`; `metrics/types.ts`, `catalogue.ts`, `metricAccess.ts`, `sources/*`, `useMetric.ts` + unit test (mọi khóa có quyền và nguồn, tham số lạ bị loại, quyền theo chi nhánh, `all` chỉ cho số liệu báo cáo) | `test`, `deps:check` |
| D6 | `widgets/metric/` (KPI, cột, danh sách), đăng ký `kpi`/`barChart`/`list` trong `WIDGET_TYPES` | unit test `kpiFormat`; Playwright chụp |
| D7 | `addWidget/` (dialog thêm, dialog cài đặt), nút trên thanh công cụ và menu ⋯, i18n | unit test `useAddWidget`; Playwright: thêm 2 KPI doanh thu khác mảng, lưu, tải lại vẫn còn |

## 9. Bước 3: khoảng ngày riêng cho từng widget

- Chỉ số liệu có `usesRange: true` (nhóm doanh thu). Không chọn gì → `defaultRange` của số liệu (KPI: hôm nay, biểu đồ: 7 ngày qua, danh sách: tháng này).
- Preset lưu dạng **tương đối** (`last7`), tính lại mỗi ngày từ `useToday()` (giờ Việt Nam, helper sẵn có). Khoảng cố định lưu `from`/`to`, kiểm `from <= to` và tối đa `MAX_REPORT_DAYS = 366` (giống DB).
- Thêm `last30` vào `presetRange` của reports (hiện có today, yesterday, last7, thisMonth, lastMonth). Test kèm.
- Thẻ hiện nhãn khoảng ngày nhỏ dưới tiêu đề ("7 ngày qua", "01/10 đến 15/10"). KPI có `compare: true` thì hiện % so với kỳ trước (`report_overview.previous` đã trả sẵn, không gọi thêm).
- Hai widget cố định đang có nút đổi kỳ trên thẻ (`salesPanel`, `trend`) giữ nút đó; lựa chọn trên thẻ vẫn tạm thời như hiện nay, còn kỳ mặc định khi mở trang lấy từ `config.range` nếu đã đặt trong Cài đặt. Như vậy không đổi thói quen đang dùng.
- Biểu đồ: `bucket` tự gợi ý theo độ dài (≤ 31 ngày: ngày; ≤ 120: tuần; còn lại: tháng) nếu người dùng không chọn.

| PR | Nội dung | Kiểm |
| --- | --- | --- |
| D8 | `range/RangeFields.vue`, `range/widgetRange.ts` (+ test: preset, cố định, quá 366 ngày, nhãn), nối vào dialog và `useMetricWidget`; `last30` | `test`, Playwright |
| D9 | Cập nhật tài liệu này (mục "Đã làm"), `docs/README.md`, ghi chú test tay cho grace | |

## 10. Kiểm thử tổng hợp

- **DB (pgTAP)**: mục 5.1.
- **Unit (Vitest)**: `layoutMath`, `layoutCodec`, `useLayoutEditor`, `metricAccess`, danh mục (mỗi khóa có quyền, nguồn, kiểu hiển thị; không trùng khóa), `widgetRange`, `kpiFormat`. Giữ test `dashboardRules.test.ts` xanh.
- **Playwright** (Chromium có sẵn trong môi trường; WebKit nếu cài được): desktop 1440px, iPad 820×1180 có chạm, điện thoại 390px. Đăng nhập tài khoản test, không cần dữ liệu thật vì chỉ kiểm bố cục.
- **CI**: typecheck, build, `deps:check`, `db:test`, `schema.sql` không cũ.
- **grace test tay cuối ngày**: trên iPad bật Tùy chỉnh, kéo đổi chỗ và đổi cỡ, Lưu, tải lại; thêm 2 KPI doanh thu (spa tháng này, shop hôm nay); đổi chi nhánh xem widget không có quyền ẩn đi; Về mặc định.

## 11. Rủi ro

| Rủi ro | Cách giảm |
| --- | --- |
| Thư viện lưới lỗi trên iPad Safari | Bọc một file, test chạm ở D3, có phương án tự viết (mục 7.3) |
| Widget hiện tại không co giãn tốt khi đổi cỡ | `minSize` đặt đủ lớn, `WidgetCard` `overflow-auto`, bản gọn qua `useElementSize` |
| Nhiều widget làm tăng số request | Cache chung theo khóa query (K11); giới hạn 24 widget |
| Đổi tên khóa số liệu làm hỏng bố cục đã lưu | Khóa là hợp đồng: không đổi tên, chỉ thêm. Nếu buộc phải đổi, thêm bảng `METRIC_ALIASES` trong `layoutCodec` |
| JSON lưu quá lớn hoặc sai | Kiểm ở cả zod (client) và `dashboard_layout_problem` (server) |
| Cache bố cục của người trước sau khi đăng xuất | Khóa query có `userId` (K12) |
| Lưu đè giữa iPad và máy tính | `version` + thông báo xung đột (K8) |

## 12. Không làm trong đợt này

- SQL / truy vấn tự do, chọn bảng hay cột từ giao diện.
- RPC mới, bảng tổng hợp, realtime.
- Bố cục mặc định theo vai trò do admin đặt cho người khác (làm sau nếu cần: thêm bảng `dashboard_role_defaults`, dùng chung `dashboard_layout_problem`).
- Tạo dashboard mới do người dùng đặt tên (hiện chỉ `today`, `business`). `dashboard_key` trong DB đã là chuỗi nên sau này không cần đổi bảng.
- Biểu đồ đường, tròn; xuất/nhập bố cục JSON; chia sẻ bố cục.
- Bố cục riêng cho từng cỡ màn hình (chỉ một bố cục 4 cột, điện thoại xếp 1 cột).

## 13. Thứ tự và phụ thuộc

```
D1 (migration) ─┐
D2 (kiểu + toán bố cục) ─┴─ D3 (lưới chỉ xem) ── D4 (chế độ sửa)   ← xong bước 1, dùng được
                                                   │
D5 (danh mục) ── D6 (widget số liệu) ── D7 (dialog) ← xong bước 2
                                                   │
                                     D8 (khoảng ngày) ── D9 (docs) ← xong bước 3
```

D1 và D2 làm song song được. D5 có thể bắt đầu sau D2 (không cần lưới). Mỗi PR squash-merge riêng, commit/PR bằng tiếng Anh.

## 14. Tóm tắt SQL

| Bước | Migration | Ai chạy |
| --- | --- | --- |
| 1 | `20261103010000_dashboard_layouts.sql`: bảng `dashboard_layouts` + RLS chỉ đọc dòng của mình, hàm `dashboard_layout_problem`, RPC `save_dashboard_layout`, `reset_dashboard_layout` | Workflow "Supabase migrate" tự chạy khi merge; bản sao để dán tay ở `pet-care-plan/migration-dashboard-layouts.sql` |
| 2 | Không có | |
| 3 | Không có | |

## 15. Đã làm

| PR | Nội dung |
| --- | --- |
| #230 (D1) | Migration `20261103010000_dashboard_layouts.sql` (bảng, RLS, `save_dashboard_layout`, `reset_dashboard_layout`), pgTAP `dashboard_layouts.test.sql`, hợp đồng zod `packages/core/dashboard`, `packages/supabase/dashboard`. Migrate đã chạy khi merge |
| #231 (D2 đến D8) | Kiểu widget và toán bố cục, lưới 4 cột (`grid-layout-plus@1.1.1`), chế độ Tùy chỉnh, danh mục số liệu, widget KPI / cột / danh sách, hộp Thêm widget và Cài đặt, khoảng ngày riêng từng widget |

Khác với kế hoạch:

- D2 và D3 gộp chung một PR; D4 đến D8 cùng nằm trong PR #231 (nhiều commit, mỗi bước một commit).
- Giữ nguyên khóa kiểu widget cố định đang có (`salesToday`, `salesPeriod`, `trend`...), không gộp thành `salesPanel`.
- `last30` xử lý trong `range/widgetRange.ts`, không thêm vào `presetRange` của báo cáo (tránh hiện thêm nút ở màn Báo cáo).
- Tùy chọn "So với kỳ trước" chỉ có với số liệu doanh thu, hóa đơn, TB mỗi hóa đơn, hoàn trả; riêng doanh thu chỉ khi chọn nhóm "Tất cả" (báo cáo chỉ trả kỳ trước cho tổng).
- Widget cố định đã xóa khỏi bảng thì thêm lại ở mục "Widget có sẵn" trong hộp Thêm widget.

Chưa làm: biểu đồ đường, bố cục mặc định theo vai trò (mục 12 vẫn đúng).

### Test tay cho grace

1. Trên iPad mở Dashboard, bấm **Tùy chỉnh**: kéo tay nắm (góc trái trên) đổi chỗ hai thẻ, kéo góc phải dưới đổi cỡ, vuốt trong thẻ vẫn cuộn trang. Bấm **Lưu**, tải lại: bố cục còn.
2. **Thêm widget**: thêm 2 thẻ "Doanh thu", một chọn nhóm Spa + Tháng này, một chọn Bán hàng + Hôm nay. Lưu, tải lại.
3. Menu ⋯ của thẻ: Lên / Xuống / Nhỏ / Vừa / Lớn / Cài đặt / Xóa.
4. Mở hai tab, sửa ở tab 1 và lưu, rồi lưu ở tab 2: phải hiện hộp "Bố cục đã đổi ở nơi khác".
5. Đổi chi nhánh sang chi nhánh không có quyền xem một số liệu: thẻ đó ẩn đi, đổi lại thì hiện.
6. **Về mặc định** đưa bảng về như cũ. Điện thoại (dưới 768px): các thẻ xếp một cột, vẫn dùng menu ⋯ để đổi thứ tự.
