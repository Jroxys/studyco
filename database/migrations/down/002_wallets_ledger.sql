-- 002_wallets_ledger.sql (DOWN) -- YIKICI: cüzdan ve token defterini siler.
DROP TRIGGER IF EXISTS users_create_wallet ON users;
DROP FUNCTION IF EXISTS users_create_wallet();
DROP TABLE IF EXISTS wallet_transactions;
DROP TABLE IF EXISTS wallets;
DROP FUNCTION IF EXISTS wtx_apply_to_wallet();
DROP FUNCTION IF EXISTS wtx_forbid_change();
DROP FUNCTION IF EXISTS wallets_guard();
