-- ============ LANGKAH 1: DATABASE & TABEL ============
DROP DATABASE IF EXISTS bioskop_db;
CREATE DATABASE bioskop_db;
USE bioskop_db;

CREATE TABLE film (
  id INT AUTO_INCREMENT PRIMARY KEY,
  judul VARCHAR(100) NOT NULL,
  genre VARCHAR(50) NOT NULL,
  durasi INT NOT NULL,
  harga DECIMAL(10,2) NOT NULL
);

CREATE TABLE kursi (
  id INT AUTO_INCREMENT PRIMARY KEY,
  film_id INT NOT NULL,
  nomor_kursi VARCHAR(5) NOT NULL,
  status ENUM('available','booked') NOT NULL DEFAULT 'available',
  UNIQUE KEY uq_film_kursi (film_id, nomor_kursi),
  FOREIGN KEY (film_id) REFERENCES film(id)
);

CREATE TABLE transaksi (
  id INT AUTO_INCREMENT PRIMARY KEY,
  kode_transaksi VARCHAR(50) NOT NULL UNIQUE,
  nama_pemesan VARCHAR(100) NOT NULL,
  film_id INT NOT NULL,
  kursi_id INT NOT NULL UNIQUE,            -- 1 kursi hanya bisa 1 transaksi
  total_harga DECIMAL(10,2) NOT NULL,
  waktu TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (film_id) REFERENCES film(id),
  FOREIGN KEY (kursi_id) REFERENCES kursi(id)
);

CREATE TABLE log_transaksi (
  id INT AUTO_INCREMENT PRIMARY KEY,
  aktivitas VARCHAR(255) NOT NULL,
  waktu TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO film (judul, genre, durasi, harga) VALUES
('Avenger: Secret Wars','Action',150,50000),
('Fast Rush','Action',125,45000),
('Laskar Pelangi Reborn','Drama',120,40000),
('Kuntilanak Terakhir','Horror',100,40000),
('Galaxy Odyssey','Sci-Fi',140,55000),
('Si Kancil Petualang','Animation',95,35000);

-- 5 baris (A-E) x 8 kursi per film
INSERT INTO kursi (film_id, nomor_kursi)
SELECT f.id, CONCAT(r.b, n.k)
FROM film f
CROSS JOIN (SELECT 'A' b UNION SELECT 'B' UNION SELECT 'C' UNION SELECT 'D' UNION SELECT 'E') r
CROSS JOIN (SELECT 1 k UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8) n
ORDER BY f.id, r.b, n.k;

-- ============ LANGKAH 2: INDEX ============
-- EXPLAIN SELECT * FROM film WHERE genre = 'Action';   (sebelum)
CREATE INDEX idx_genre ON film(genre);
-- EXPLAIN SELECT * FROM film WHERE genre = 'Action';   (sesudah)

-- ============ LANGKAH 3: STORED PROCEDURE ============
DELIMITER //
CREATE PROCEDURE sp_pesan_tiket(
  IN p_kode VARCHAR(50), IN p_nama VARCHAR(100),
  IN p_film_id INT, IN p_kursi_id INT, IN p_total DECIMAL(10,2))
BEGIN
  DECLARE v_status VARCHAR(10);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  START TRANSACTION;
  SELECT status INTO v_status FROM kursi
    WHERE id = p_kursi_id AND film_id = p_film_id FOR UPDATE;
  IF v_status IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Kursi tidak ditemukan untuk film ini';
  END IF;
  IF v_status = 'booked' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Kursi sudah dipesan (double booking dicegah)';
  END IF;
  INSERT INTO transaksi (kode_transaksi, nama_pemesan, film_id, kursi_id, total_harga)
  VALUES (p_kode, p_nama, p_film_id, p_kursi_id, p_total);
  COMMIT;
END //

-- ============ LANGKAH 4: TRIGGER ============
CREATE TRIGGER tg_setelah_pesan AFTER INSERT ON transaksi
FOR EACH ROW
BEGIN
  UPDATE kursi SET status = 'booked' WHERE id = NEW.kursi_id;
  INSERT INTO log_transaksi (aktivitas)
  VALUES (CONCAT('Tiket dipesan: ', NEW.kode_transaksi));
END //
DELIMITER ;

-- ============ USER UNTUK APLIKASI WEB ============
CREATE USER IF NOT EXISTS 'bioskop'@'localhost' IDENTIFIED BY 'bioskop123';
CREATE USER IF NOT EXISTS 'bioskop'@'127.0.0.1' IDENTIFIED BY 'bioskop123';
GRANT ALL PRIVILEGES ON bioskop_db.* TO 'bioskop'@'localhost';
GRANT ALL PRIVILEGES ON bioskop_db.* TO 'bioskop'@'127.0.0.1';
FLUSH PRIVILEGES;
