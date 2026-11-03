-- SADECE TEST VERİTABANI İÇİN. Gerçek kuruluma (scripts/setup_db.sh) ASLA girmez.
-- Gerçek ders/kafe listesi gelene kadar testlerin ilan açabilmesi için uydurma kayıtlardır;
-- adları "TEST_FIXTURE" ile başlar ki gerçek veriyle karışmasın.
INSERT INTO courses (department_id, course_name)
SELECT department_id, 'TEST_FIXTURE Ders' FROM departments;

INSERT INTO locations (name, description) VALUES
  ('TEST_FIXTURE Kafe A', 'yalnızca test'),
  ('TEST_FIXTURE Kafe B', 'yalnızca test');
