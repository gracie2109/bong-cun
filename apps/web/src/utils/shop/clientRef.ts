// Idempotency key for placing an order (checkout sends it as client_ref). Browser-only, so it stays in the app.
export const newClientRef = (): string => crypto.randomUUID();
