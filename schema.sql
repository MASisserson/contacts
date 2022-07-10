CREATE TABLE users (
  id serial PRIMARY KEY,
  username varchar(30) UNIQUE,
  "password" text
);

CREATE TABLE contacts (
  id serial PRIMARY KEY,
  "name" text NOT NULL,
  phone varchar(14) UNIQUE DEFAULT NULL,
  email text DEFAULT NULL,
  category text DEFAULT NULL,
  "user_id" integer REFERENCES users(id) ON DELETE CASCADE
);

ALTER TABLE contacts ADD UNIQUE ("user_id", phone);

CREATE TABLE contact_ids (
  id serial PRIMARY KEY,
  uuid varchar(20) UNIQUE NOT NULL,
  contact_id integer REFERENCES contacts(id) ON DELETE CASCADE
);
