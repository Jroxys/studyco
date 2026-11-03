-- =====================================================================
-- 004_messaging_reviews.sql (UP): konuşma, mesaj, değerlendirme
-- =====================================================================
-- G12: DB'nin "kolay" zorlayabildiği bütünlük kuralları trigger ile DB'de tutulur;
--      OKUMA yetkisi (kim hangi konuşmayı okuyabilir) DB'de değil, backend'de kontrol edilir.
--      Yardımcı olarak is_conversation_participant() sağlanır.
-- ---------------------------------------------------------------------

CREATE TABLE conversations (
  conversation_id   uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_request_id uuid        NOT NULL REFERENCES lesson_requests(request_id) ON DELETE RESTRICT,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT conversations_request_uq UNIQUE (lesson_request_id)   -- talep başına en fazla 1 oda
);

CREATE FUNCTION conversations_before_insert() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM lesson_requests
                  WHERE request_id = NEW.lesson_request_id AND request_status = 'ACCEPTED') THEN
    RAISE EXCEPTION 'CONVERSATION_REQUIRES_ACCEPTED_REQUEST' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER conversations_before_insert BEFORE INSERT ON conversations
  FOR EACH ROW EXECUTE FUNCTION conversations_before_insert();

CREATE TABLE messages (
  message_id      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid        NOT NULL REFERENCES conversations(conversation_id) ON DELETE RESTRICT,
  sender_id       uuid        NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  body            text        NOT NULL,
  sent_at         timestamptz NOT NULL DEFAULT now(),
  read_at         timestamptz,
  CONSTRAINT messages_body_ck CHECK (btrim(body) <> '')
);
-- Sohbet ekranı: "bu konuşmanın mesajlarını zamana göre getir"
CREATE INDEX messages_conv_sent_idx ON messages (conversation_id, sent_at);

CREATE FUNCTION is_conversation_participant(p_user_id uuid, p_conversation_id uuid)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
      FROM conversations c
      JOIN lesson_requests lr ON lr.request_id = c.lesson_request_id
     WHERE c.conversation_id = p_conversation_id
       AND p_user_id IN (lr.student_id, lr.teacher_id));
$$;

CREATE FUNCTION messages_before_insert() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NOT is_conversation_participant(NEW.sender_id, NEW.conversation_id) THEN
    RAISE EXCEPTION 'NOT_A_PARTICIPANT' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER messages_before_insert BEFORE INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION messages_before_insert();

CREATE TABLE reviews (
  review_id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_request_id uuid        NOT NULL REFERENCES lesson_requests(request_id) ON DELETE RESTRICT,
  reviewer_id       uuid        NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  reviewee_id       uuid        NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  rating            smallint    NOT NULL,
  comment           text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reviews_rating_ck CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT reviews_not_self_ck CHECK (reviewer_id <> reviewee_id),
  -- Her taraf, aynı ders için karşı tarafı en fazla bir kez değerlendirir.
  CONSTRAINT reviews_once_per_reviewer_uq UNIQUE (lesson_request_id, reviewer_id)
);
CREATE INDEX reviews_reviewee_idx ON reviews (reviewee_id);   -- "bu kullanıcının puanları"

CREATE FUNCTION reviews_before_insert() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE lr lesson_requests%ROWTYPE;
BEGIN
  SELECT * INTO lr FROM lesson_requests WHERE request_id = NEW.lesson_request_id;
  IF NOT FOUND OR lr.completion_status <> 'COMPLETED' THEN
    RAISE EXCEPTION 'REVIEW_REQUIRES_COMPLETED_LESSON' USING ERRCODE = 'P0001';
  END IF;
  IF NOT ((NEW.reviewer_id = lr.student_id AND NEW.reviewee_id = lr.teacher_id)
       OR (NEW.reviewer_id = lr.teacher_id AND NEW.reviewee_id = lr.student_id)) THEN
    RAISE EXCEPTION 'REVIEW_PARTIES_MISMATCH' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER reviews_before_insert BEFORE INSERT ON reviews
  FOR EACH ROW EXECUTE FUNCTION reviews_before_insert();
