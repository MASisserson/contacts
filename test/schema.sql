CREATE TABLE contacts (
  id serial PRIMARY KEY,
  "name" text NOT NULL,
  phone varchar(14) UNIQUE CHECK (phone ~ '^[0-9]{10}$'),
  email text UNIQUE CHECK (email LIKE '%@%'),
  category text
);

INSERT INTO contacts ("name", phone, email, category)
VALUES ('Hank Hill', '1111111111', 'king@hill.com', 'Friend'),
       ('Socrates', '1234567890', 'philosopher@forms.com', 'Work');
