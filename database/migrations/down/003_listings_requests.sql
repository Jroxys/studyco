-- 003_listings_requests.sql (DOWN) -- YIKICI: ilan, talep ve zaman dilimi verisini siler.
DROP VIEW IF EXISTS v_listing_state;
ALTER TABLE wallet_transactions DROP CONSTRAINT IF EXISTS wtx_request_fk;
DROP TABLE IF EXISTS accepted_slots;
DROP TABLE IF EXISTS lesson_requests;
DROP TABLE IF EXISTS listings;
DROP FUNCTION IF EXISTS lr_after_update();
DROP FUNCTION IF EXISTS lr_before_update();
DROP FUNCTION IF EXISTS lr_before_insert();
DROP FUNCTION IF EXISTS listings_before_update();
DROP FUNCTION IF EXISTS listings_before_insert();
