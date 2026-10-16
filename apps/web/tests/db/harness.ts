// Runs a test inside a transaction that is rolled back, signed in as a given user like PostgREST does.
import pg from "pg";

export const DATABASE_URL = process.env.DATABASE_URL;

export type Tx = {
  q: <T = Record<string, unknown>>(sql: string, params?: unknown[]) => Promise<T[]>;
  /** Signs in as the user (claims as the access token hook sets them) and drops to the `authenticated` role. */
  as: (userId: string) => Promise<void>;
  /** Back to the superuser, for fixtures. */
  admin: () => Promise<void>;
  /** The call must fail; returns the Postgres error code and hint. */
  fails: (sql: string, params?: unknown[]) => Promise<{ code?: string; hint?: string }>;
};

export const inTransaction = async (body: (tx: Tx) => Promise<void>): Promise<void> => {
  const client = new pg.Client({ connectionString: DATABASE_URL });
  await client.connect();
  const q: Tx["q"] = async (sql, params) => (await client.query(sql, params)).rows;
  const tx: Tx = {
    q,
    admin: async () => {
      await q("reset role");
      await q("select set_config('request.jwt.claims', '', true)");
    },
    as: async (userId) => {
      await q("reset role");
      const [claims] = await q<{ claims: string }>(
        `select jsonb_build_object(
           'sub', u.id, 'role', 'authenticated', 'user_role', u.role,
           'branch_ids', (select coalesce(jsonb_agg(branch_id), '[]'::jsonb) from public.staff_branches where user_id = u.id)
         )::text as claims from public.users u where u.id = $1`,
        [userId]
      );
      await q("select set_config('request.jwt.claims', $1, true)", [claims!.claims]);
      await q("set local role authenticated");
    },
    fails: async (sql, params) => {
      await q("savepoint attempt");
      try {
        await q(sql, params);
      } catch (error) {
        await q("rollback to savepoint attempt");
        return { code: (error as { code?: string }).code, hint: (error as { hint?: string }).hint };
      }
      throw new Error(`expected the statement to fail: ${sql}`);
    },
  };
  try {
    await q("begin");
    await body(tx);
  } finally {
    await client.query("rollback").catch(() => undefined);
    await client.end();
  }
};
