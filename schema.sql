CREATE TABLE users (
  id serial PRIMARY KEY,
  username varchar(30) UNIQUE,
  "password" text
);

INSERT INTO users (id, username, "password")
VALUES (1, 'admin', '$2a$12$wZEWwTmygfVvpchJQ56lT.j8VMNloUfrIAK/rWArL/deD7y9sZf4y');

CREATE TABLE contacts (
  id serial PRIMARY KEY,
  "name" text NOT NULL,
  phone varchar(14) UNIQUE DEFAULT NULL,
  email text DEFAULT NULL,
  category text DEFAULT NULL,
  "user_id" integer REFERENCES users(id)
);

ALTER TABLE contacts ADD UNIQUE ("user_id", phone);

INSERT INTO contacts ("name", phone, email, category, "user_id")
VALUES ('Hank Hill', '1111111111', 'king@hill.com', 'Friend', 1),
       ('Socrates', '1234567890', 'philosopher@forms.com', 'Work', 1),
       ('Paul', NULL, NULL, NULL, 1),
       ('Frank', '4444444444', NULL, NULL, 1);
