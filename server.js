const express = require('express');
const mysql = require('mysql2/promise');
const app = express();
app.use(express.json());
app.use(express.static(__dirname + '/public'));

const pool = mysql.createPool({
  host: process.env.DB_HOST || '127.0.0.1',
  user: process.env.DB_USER || 'bioskop',
  password: process.env.DB_PASS || 'bioskop123',
  database: 'bioskop_db'
});
const h = fn => async (req, res) => {
  try { res.json(await fn(req)); }
  catch (e) { res.status(400).json({ error: e.sqlMessage || e.message }); }
};

// Daftar film (memakai idx_genre saat filter genre)
app.get('/api/film', h(async req => {
  const sql = `SELECT f.*, (SELECT COUNT(*) FROM kursi k WHERE k.film_id=f.id AND k.status='available') AS sisa
               FROM film f` + (req.query.genre ? ' WHERE f.genre = ?' : '') + ' ORDER BY f.id';
  const [r] = await pool.query(sql, req.query.genre ? [req.query.genre] : []);
  return r;
}));
app.get('/api/genre', h(async () => (await pool.query('SELECT DISTINCT genre FROM film ORDER BY genre'))[0].map(x => x.genre)));
app.get('/api/film/:id/kursi', h(async req =>
  (await pool.query('SELECT id, nomor_kursi, status FROM kursi WHERE film_id=? ORDER BY nomor_kursi', [req.params.id]))[0]));

// Pemesanan -> CALL sp_pesan_tiket (trigger berjalan otomatis)
app.post('/api/pesan', h(async req => {
  const { nama, film_id, kursi_ids } = req.body;
  if (!nama || !nama.trim() || !Array.isArray(kursi_ids) || !kursi_ids.length) throw new Error('Nama dan kursi wajib diisi');
  const [[film]] = await pool.query('SELECT harga FROM film WHERE id=?', [film_id]);
  if (!film) throw new Error('Film tidak ditemukan');
  const base = 'TRX-' + Date.now().toString(36).toUpperCase();
  const kode = [];
  for (let i = 0; i < kursi_ids.length; i++) {
    const k = kursi_ids.length > 1 ? `${base}-${i + 1}` : base;
    await pool.query('CALL sp_pesan_tiket(?,?,?,?,?)', [k, nama.trim().slice(0, 100), film_id, kursi_ids[i], film.harga]);
    kode.push(k);
  }
  return { kode, total: film.harga * kursi_ids.length };
}));

// Laporan JOIN multi-tabel
app.get('/api/laporan', h(async () => (await pool.query(
  `SELECT t.kode_transaksi, t.nama_pemesan, f.judul AS film, k.nomor_kursi, t.total_harga, t.waktu
   FROM transaksi t JOIN film f ON t.film_id=f.id JOIN kursi k ON t.kursi_id=k.id
   ORDER BY t.id DESC`))[0]));
app.get('/api/log', h(async () => (await pool.query('SELECT * FROM log_transaksi ORDER BY id DESC LIMIT 100'))[0]));

// Demo EXPLAIN: tanpa vs dengan index
app.get('/api/explain', h(async req => {
  const g = req.query.genre || 'Action';
  const [tanpa] = await pool.query('EXPLAIN SELECT * FROM film IGNORE INDEX (idx_genre) WHERE genre = ?', [g]);
  const [dengan] = await pool.query('EXPLAIN SELECT * FROM film FORCE INDEX (idx_genre) WHERE genre = ?', [g]);
  return { genre: g, tanpa, dengan };
}));

app.listen(3000, () => console.log('Buka http://localhost:3000'));
