import { describe, test, expect, vi, afterEach } from 'vitest';
import { render, screen, waitFor, cleanup } from '@testing-library/react';
import App from '../src/App.jsx';
import { formatPrice } from '../src/format.js';

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

describe('formatPrice', () => {
  test('formats cents as dollars', () => {
    expect(formatPrice(1200)).toBe('$12.00');
    expect(formatPrice(5)).toBe('$0.05');
  });
  test('rejects invalid values', () => {
    expect(formatPrice(-1)).toBe('N/A');
    expect(formatPrice('x')).toBe('N/A');
  });
});

describe('App', () => {
  test('renders products from the API', async () => {
    vi.stubGlobal('fetch', vi.fn((url) =>
      Promise.resolve({
        ok: true,
        json: () =>
          Promise.resolve(
            url === '/api/products' ? [{ id: 1, name: 'Nest Mug', price_cents: 1200 }] : { version: 'abc1234' }
          ),
      })
    ));
    render(<App />);
    await waitFor(() => expect(screen.getByText(/Nest Mug/)).toBeTruthy());
    expect(screen.getByText(/\$12\.00/)).toBeTruthy();
  });

  test('shows an error when the API fails', async () => {
    vi.stubGlobal('fetch', vi.fn(() => Promise.resolve({ ok: false, status: 500, json: () => Promise.resolve({}) })));
    render(<App />);
    await waitFor(() => expect(screen.getByRole('alert')).toBeTruthy());
  });
});
