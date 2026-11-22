import { useEffect, useState } from 'react';
import { formatPrice } from './format.js';

const BUILD_COMMIT = import.meta.env.VITE_APP_COMMIT || 'dev';

export default function App() {
  const [products, setProducts] = useState([]);
  const [error, setError] = useState(null);
  const [backendVersion, setBackendVersion] = useState('...');

  useEffect(() => {
    fetch('/api/products')
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
      .then(setProducts)
      .catch((e) => setError(e.message));
    fetch('/api/version')
      .then((r) => r.json())
      .then((v) => setBackendVersion(v.version))
      .catch(() => setBackendVersion('unknown'));
  }, []);

  return (
    <main style={{ fontFamily: 'sans-serif', maxWidth: 560, margin: '2rem auto' }}>
      <h1>ShopNest</h1>
      {error && <p role="alert">Could not load products: {error}</p>}
      <ul>
        {products.map((p) => (
          <li key={p.id}>
            {p.name} - {formatPrice(p.price_cents)}
          </li>
        ))}
      </ul>
      <footer style={{ color: '#666', fontSize: 12 }}>
        frontend {BUILD_COMMIT.slice(0, 7)} / backend {String(backendVersion).slice(0, 7)}
      </footer>
    </main>
  );
}
