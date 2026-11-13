# CineBook — Aplikasi Pemesanan Tiket Bioskop (Basis Data 2)

Stack: Node.js + Express + MariaDB/MySQL.

## Cara menjalankan

1. Pastikan MariaDB aktif, lalu import database (sudah termasuk tabel, index, stored procedure, trigger, dan user aplikasi):
   sudo mysql < schema.sql
2. Install dan jalankan:
   npm install
   npm start
3. Buka http://localhost:3000

## Pemetaan ke dokumen tugas
| Langkah di dokumen | Di aplikasi |
|---|---|
| 1. Tabel & relasi (film, kursi, transaksi, log_transaksi) | schema.sql, dan denah kursi di halaman Film |
| 2. Index idx_genre + EXPLAIN | tab "Uji Index" dan filter genre |
| 3. Stored procedure sp_pesan_tiket | tombol "Pesan Sekarang" memanggil `CALL sp_pesan_tiket(...)` |
| 4. Trigger tg_setelah_pesan | kursi otomatis "booked" dan tab "Log Trigger" terisi sendiri |
| 5. Laporan JOIN 3 tabel | tab "Laporan (JOIN)" |

Catatan: procedure memakai START TRANSACTION, SELECT ... FOR UPDATE, dan SIGNAL, sehingga double booking ditolak. Kolom kursi_id di tabel transaksi juga UNIQUE.
