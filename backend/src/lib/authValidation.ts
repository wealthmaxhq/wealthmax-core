export function normalizedEmail(value: unknown): string {
  if (typeof value !== 'string') throw new Error('A valid email is required.');
  const email = value.trim().toLowerCase();
  if (
    email.length > 254
    || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) throw new Error('A valid email is required.');
  return email;
}

export function validPassword(value: unknown): string {
  if (typeof value !== 'string' || value.length < 8 || value.length > 128) {
    throw new Error('Password must be between 8 and 128 characters.');
  }
  return value;
}

export function normalizedName(value: unknown): string | undefined {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value !== 'string') throw new Error('Name must be text.');
  const name = value.trim();
  if (!name || name.length > 100) {
    throw new Error('Name must be between 1 and 100 characters.');
  }
  return name;
}
