-- 005_functions_views.sql (DOWN) -- veriye dokunmaz; yalnızca fonksiyon ve görünümleri siler.
DROP VIEW IF EXISTS v_integrity_violations;
DROP FUNCTION IF EXISTS anonymize_user(uuid);
DROP FUNCTION IF EXISTS expire_stale_requests(timestamptz);
DROP FUNCTION IF EXISTS process_expired_confirmations(timestamptz);
DROP FUNCTION IF EXISTS finalize_expired_request(uuid, timestamptz);
DROP FUNCTION IF EXISTS confirm_lesson(uuid, uuid, timestamptz);
DROP FUNCTION IF EXISTS settle_request_internal(uuid, text, timestamptz);
DROP FUNCTION IF EXISTS accept_lesson_request(uuid, uuid, timestamptz);
DROP FUNCTION IF EXISTS reject_lesson_request(uuid, uuid, timestamptz);
DROP FUNCTION IF EXISTS verify_auth_token(uuid, text, text, integer);
DROP FUNCTION IF EXISTS issue_auth_token(uuid, text, text, interval);
