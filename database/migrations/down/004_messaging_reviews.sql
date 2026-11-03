-- 004_messaging_reviews.sql (DOWN) -- YIKICI: mesaj ve değerlendirme verisini siler.
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS messages;
DROP TABLE IF EXISTS conversations;
DROP FUNCTION IF EXISTS reviews_before_insert();
DROP FUNCTION IF EXISTS messages_before_insert();
DROP FUNCTION IF EXISTS is_conversation_participant(uuid, uuid);
DROP FUNCTION IF EXISTS conversations_before_insert();
