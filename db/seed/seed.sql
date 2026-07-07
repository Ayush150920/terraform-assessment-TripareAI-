-- seed.sql
-- Generates realistic sample data:
--   * 200 hotel_bookings (>= the required 100)
--   * 6 cities, 4 organizations, 5 booking statuses
--   * booking_events for a subset of bookings (multiple per booking)
--
-- gen_random_uuid() is built into PostgreSQL 13+ (no extension needed).

BEGIN;

-- 200 bookings spread over the last 60 days so the "last 30 days" filter
-- in the reporting query returns a meaningful subset.
INSERT INTO hotel_bookings (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
SELECT
    gen_random_uuid(),
    (ARRAY[
        '11111111-1111-1111-1111-111111111111'::uuid,
        '22222222-2222-2222-2222-222222222222'::uuid,
        '33333333-3333-3333-3333-333333333333'::uuid,
        '44444444-4444-4444-4444-444444444444'::uuid
    ])[1 + floor(random() * 4)::int]                                    AS org_id,
    'hotel_' || (1 + floor(random() * 40)::int)::text                   AS hotel_id,
    (ARRAY['delhi', 'mumbai', 'bangalore', 'chennai', 'kolkata', 'hyderabad'])[1 + floor(random() * 6)::int] AS city,
    created.d::date                                                     AS checkin_date,
    (created.d + ((1 + floor(random() * 5)::int) || ' days')::interval)::date AS checkout_date,
    round((1000 + random() * 49000)::numeric, 2)                        AS amount,
    (ARRAY['confirmed', 'pending', 'cancelled', 'completed', 'no_show'])[1 + floor(random() * 5)::int] AS status,
    created.d                                                           AS created_at
FROM (
    SELECT (NOW() - (random() * INTERVAL '60 days')) AS d
    FROM generate_series(1, 200)
) AS created;

-- Events for a subset of bookings (roughly 60% chance per attempt, up to 3
-- attempts each -> many bookings get 1-3 events).
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT
    b.id,
    (ARRAY['created', 'payment_captured', 'checked_in', 'checked_out', 'cancelled'])[1 + floor(random() * 5)::int],
    jsonb_build_object(
        'source', 'seed',
        'channel', (ARRAY['web', 'app', 'ota'])[1 + floor(random() * 3)::int],
        'amount', b.amount
    ),
    b.created_at + (random() * INTERVAL '2 days')
FROM hotel_bookings b
CROSS JOIN generate_series(1, 3) AS attempt
WHERE random() < 0.6;

COMMIT;

-- Refresh planner statistics so the new index is costed correctly.
ANALYZE hotel_bookings;
ANALYZE booking_events;
