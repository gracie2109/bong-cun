import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import pg from "pg";

const DEFAULT_URL = "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const SETUP = fileURLToPath(new URL("../../../../supabase/tests/_helpers/setup.psql", import.meta.url));

/**
 * Runs `body` in a transaction that is always rolled back, with the same fixtures the pgTAP tests use
 * (tests.create_branch, tests.create_cashier...), so nothing a test creates stays in the database.
 */
export const inRolledBackTransaction = async (body: (db: Session) => Promise<void>): Promise<void> => {
  const client = new pg.Client({ connectionString: process.env.DATABASE_URL ?? DEFAULT_URL });
  await client.connect();
  try {
    await client.query("begin");
    await client.query(readFileSync(SETUP, "utf8"));
    await body(new Session(client));
  } finally {
    await client.query("rollback").catch(() => undefined);
    await client.end();
  }
};

export class Session {
  constructor(private readonly client: pg.Client) {}

  /** One statement as the database owner; returns the rows. */
  async rows<T = Record<string, unknown>>(sql: string, params: unknown[] = []): Promise<T[]> {
    return (await this.client.query(sql, params)).rows as T[];
  }

  /** The first column of the first row. */
  async scalar<T = unknown>(sql: string, params: unknown[] = []): Promise<T> {
    const row = (await this.client.query({ text: sql, values: params, rowMode: "array" })).rows[0] as unknown[];
    return row[0] as T;
  }

  /** Acts as the user (the same claims the access token hook puts in a JWT) for the rest of the transaction. */
  async signIn(userId: string): Promise<void> {
    await this.client.query("select tests.logout()");
    await this.client.query("select tests.login($1)", [userId]);
    await this.client.query("set local role authenticated");
  }

  /** Back to the database owner. */
  async signOut(): Promise<void> {
    await this.client.query("reset role");
    await this.client.query("select tests.logout()");
  }

  /** Calls `select public.fn($1)` with one jsonb argument and returns the jsonb result. */
  async rpc(fn: string, arg: unknown): Promise<unknown> {
    return this.scalar(`select public.${fn}($1::jsonb)`, [JSON.stringify(arg)]);
  }
}
