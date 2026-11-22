export function formatPrice(cents) {
  if (!Number.isInteger(cents) || cents < 0) return 'N/A';
  return `$${(cents / 100).toFixed(2)}`;
}
