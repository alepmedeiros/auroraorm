INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com');
INSERT INTO users (name, email) VALUES ('Bob', 'bob@example.com');

INSERT INTO profiles (user_id, bio) VALUES (1, 'Bio Alice');
INSERT INTO profiles (user_id, bio) VALUES (2, 'Bio Bob');

INSERT INTO orders (user_id, total) VALUES (1, 100.00);
INSERT INTO orders (user_id, total) VALUES (1, 50.50);
INSERT INTO orders (user_id, total) VALUES (2, 25.00);
