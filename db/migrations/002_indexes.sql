-- 002_indexes.sql
-- Indexes tuned for the reporting query in Part 5:
--
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi'
--     AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- Design rationale (see README for the full explanation):
--   * Leading column `city` serves the equality predicate.
--   * `created_at` second serves the range predicate and keeps matching
--     rows contiguous within each city.
--   * INCLUDE (org_id, status, amount) makes the query "covering": all
--     columns it reads live in the index, so PostgreSQL can use an
--     index-only scan and skip the heap entirely for the aggregation.

BEGIN;

CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);

-- Speeds up joining/looking up events by their parent booking.
CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id
    ON booking_events (booking_id);

COMMIT;
