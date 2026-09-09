export type Result<Value, ErrorValue> =
  | Readonly<{ ok: true; value: Value }>
  | Readonly<{ ok: false; error: ErrorValue }>;

export const ok = <Value>(value: Value): Result<Value, never> => ({
  ok: true,
  value,
});

export const err = <ErrorValue>(
  error: ErrorValue,
): Result<never, ErrorValue> => ({
  ok: false,
  error,
});

