import type { Session } from "./db";

export type Attendance = {
  branch: string;
  manager: string;
  staff: string;
  other: string;
  /** Staff of a different branch. */
  outsider: string;
  monday: string;
};

/** A branch with a manager (attendance permission) and two staff, plus a role the manager holds. */
export const setUpAttendance = async (db: Session): Promise<Attendance> => {
  await db.rows("insert into public.roles (name) values ('t_hr') on conflict do nothing");
  await db.rows(
    `insert into public.role_permissions (role, permission, methods)
     values ('t_hr', 'attendance', array['CREATE','VIEW','UPDATE','DELETE','EXPORT','SETTING'])
     on conflict do nothing`
  );
  const branch = await db.scalar<string>("select tests.create_branch('ATC')");
  const manager = await db.scalar<string>("select tests.create_staff('att-hr@test.local', $1, 't_hr')", [branch]);
  const staff = await db.scalar<string>("select tests.create_staff('att-s1@test.local', $1, 'cashier')", [branch]);
  const other = await db.scalar<string>("select tests.create_staff('att-s2@test.local', $1, 'cashier')", [branch]);
  const outsider = await db.scalar<string>("select tests.create_staff('att-out@test.local', tests.create_branch('ATD'), 'cashier')");
  const monday = await db.scalar<string>("select (date_trunc('week', current_date)::date + 7)::text");
  return { branch, manager, staff, other, outsider, monday };
};
