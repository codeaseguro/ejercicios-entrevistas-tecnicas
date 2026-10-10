-- ============================================================
-- Sistema de Reseñas — Script de creación de base de datos
-- PostgreSQL 14+
-- Repo: ejercicios-entrevistas-tecnicas
-- ============================================================
-- Ejecutar con: psql -U postgres -d tu_db -f reviews-schema.sql
-- ============================================================

-- Limpieza (útil para poder correr el script varias veces en local)
DROP TABLE IF EXISTS rating_stats CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ============================================================
-- Tablas de soporte (mínimas, solo para que el script sea
-- autocontenido y los FK de reviews tengan a qué apuntar)
-- ============================================================

CREATE TABLE users (
    id          BIGINT PRIMARY KEY,
    name        TEXT NOT NULL
);

CREATE TABLE products (
    id          BIGINT PRIMARY KEY,
    name        TEXT NOT NULL
);

-- ============================================================
-- Tabla principal: reviews
-- ============================================================

CREATE TABLE reviews (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id  BIGINT NOT NULL REFERENCES products(id),
    user_id     BIGINT NOT NULL REFERENCES users(id),
    rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ NULL,

    -- Un usuario no puede dejar más de una reseña por producto.
    -- Esta es la restricción central del ejercicio de entrevista.
    CONSTRAINT uq_user_product UNIQUE (user_id, product_id)
);

-- Índices para los patrones de lectura más comunes
CREATE INDEX idx_reviews_product_created
    ON reviews (product_id, created_at DESC);

CREATE INDEX idx_reviews_user_created
    ON reviews (user_id, created_at DESC);

-- ============================================================
-- Tabla de estadísticas precalculadas
-- (evita hacer AVG(rating) en runtime sobre toda la tabla reviews)
-- ============================================================

CREATE TABLE rating_stats (
    product_id     BIGINT PRIMARY KEY REFERENCES products(id),
    sum_rating     BIGINT NOT NULL DEFAULT 0,
    total_reviews  INT NOT NULL DEFAULT 0,
    dist_1         INT NOT NULL DEFAULT 0,
    dist_2         INT NOT NULL DEFAULT 0,
    dist_3         INT NOT NULL DEFAULT 0,
    dist_4         INT NOT NULL DEFAULT 0,
    dist_5         INT NOT NULL DEFAULT 0,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- avg_rating no se guarda como columna física: se deriva siempre
-- de sum_rating / total_reviews. Se expone como vista para no
-- tener que repetir la cuenta en cada query de la aplicación.
CREATE VIEW rating_stats_view AS
SELECT
    product_id,
    total_reviews,
    CASE WHEN total_reviews = 0
         THEN 0
         ELSE ROUND(sum_rating::NUMERIC / total_reviews, 2)
    END AS avg_rating,
    dist_1, dist_2, dist_3, dist_4, dist_5,
    updated_at
FROM rating_stats;

-- ============================================================
-- Trigger: mantiene rating_stats sincronizada automáticamente
-- en cada INSERT/UPDATE/DELETE sobre reviews, dentro de la
-- misma transacción (así nunca quedan desincronizadas).
-- ============================================================

CREATE OR REPLACE FUNCTION fn_refresh_rating_stats()
RETURNS TRIGGER AS $$
DECLARE
    v_product_id BIGINT;
BEGIN
    v_product_id := COALESCE(NEW.product_id, OLD.product_id);

    INSERT INTO rating_stats (product_id)
    VALUES (v_product_id)
    ON CONFLICT (product_id) DO NOTHING;

    UPDATE rating_stats SET
        sum_rating    = (SELECT COALESCE(SUM(rating), 0) FROM reviews WHERE product_id = v_product_id AND deleted_at IS NULL),
        total_reviews = (SELECT COUNT(*) FROM reviews WHERE product_id = v_product_id AND deleted_at IS NULL),
        dist_1        = (SELECT COUNT(*) FROM reviews WHERE product_id = v_product_id AND deleted_at IS NULL AND rating = 1),
        dist_2        = (SELECT COUNT(*) FROM reviews WHERE product_id = v_product_id AND deleted_at IS NULL AND rating = 2),
        dist_3        = (SELECT COUNT(*) FROM reviews WHERE product_id = v_product_id AND deleted_at IS NULL AND rating = 3),
        dist_4        = (SELECT COUNT(*) FROM reviews WHERE product_id = v_product_id AND deleted_at IS NULL AND rating = 4),
        dist_5        = (SELECT COUNT(*) FROM reviews WHERE product_id = v_product_id AND deleted_at IS NULL AND rating = 5),
        updated_at    = now()
    WHERE product_id = v_product_id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reviews_refresh_stats
AFTER INSERT OR UPDATE OR DELETE ON reviews
FOR EACH ROW EXECUTE FUNCTION fn_refresh_rating_stats();

-- Nota para el repo: esta implementación con trigger recalcula
-- con SUM()/COUNT() por simplicidad didáctica. En producción,
-- conviene hacer el incremento/decremento directo sobre
-- sum_rating y total_reviews (sin releer toda la tabla), que es
-- justo el patrón que se explica en el guión del video.

-- ============================================================
-- Datos de ejemplo (seed)
-- ============================================================

INSERT INTO users (id, name) VALUES
    (2312,  'Usuario 2312'),
    (3212,  'Usuario 3212'),
    (33411, 'Usuario 33411'),
    (4410,  'Usuario 4410');

INSERT INTO products (id, name) VALUES
    (101, 'Notebook'),
    (102, 'Mouse inalámbrico');

-- Mismo ejemplo usado en el diagrama: tres usuarios distintos,
-- mismo product_id (101), tres reseñas diferentes.
INSERT INTO reviews (id, product_id, user_id, rating, comment) OVERRIDING SYSTEM VALUE VALUES
    (231, 101, 2312,  5, 'Excelente'),
    (232, 101, 3212,  4, 'Muy buena'),
    (233, 101, 33411, 2, 'Podría ser mejor');

-- Una reseña sobre otro producto, para mostrar que rating_stats
-- se calcula por producto y no se mezcla entre ellos.
INSERT INTO reviews (id, product_id, user_id, rating, comment) OVERRIDING SYSTEM VALUE VALUES
    (234, 102, 4410, 3, 'Cumple lo que promete');

-- Reajustar la secuencia de identidad después de insertar IDs manuales
SELECT setval(pg_get_serial_sequence('reviews', 'id'), (SELECT MAX(id) FROM reviews));

-- ============================================================
-- Queries de verificación (opcional, para probar el script)
-- ============================================================

-- Debería fallar por el constraint uq_user_product:
-- INSERT INTO reviews (product_id, user_id, rating, comment)
-- VALUES (101, 2312, 1, 'Intento de segunda reseña del mismo usuario');

-- Ver el rating ya calculado sin tocar la tabla reviews:
-- SELECT * FROM rating_stats_view WHERE product_id = 101;

-- Listado paginado por cursor (created_at + id), no por OFFSET:
-- SELECT * FROM reviews
-- WHERE product_id = 101 AND deleted_at IS NULL
-- ORDER BY created_at DESC, id DESC
-- LIMIT 10;