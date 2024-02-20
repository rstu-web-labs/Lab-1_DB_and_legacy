CREATE TABLE sales (
    id INT PRIMARY KEY,
    auto VARCHAR(100),
    gasoline_consumption FLOAT,
    price FLOAT,
    date DATE,
    person_name VARCHAR(100),
    phone VARCHAR(100),
    discount INT,
    brand_origin VARCHAR(100)
);

COPY sales (id,
    auto,
    gasoline_consumption,
    price,
    date,
    person_name,
    phone,
    discount,
    brand_origin)
FROM 'cars.csv'
DELIMITER ','
CSV HEADER;
--------создание таблиц--------
CREATE TABLE car_shop.auto (
    id SERIAL PRIMARY KEY,
    brand_id INT NOT NULL,
    model_id INT NOT NULL,
    color VARCHAR(50) NOT NULL,
    gasoline_consumption FLOAT,
    price FLOAT NOT NULL
);

CREATE TABLE car_shop.brand (
    id SERIAL PRIMARY KEY,
    brand_name VARCHAR(50) NOT NULL,
    country_id INT
);

CREATE TABLE car_shop.model (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(50) NOT NULL
);

CREATE TABLE car_shop.deal (
    id SERIAL PRIMARY KEY,
    auto_id INT NOT NULL,
    person_id INT NOT NULL,
    date DATE NOT NULL
);

CREATE TABLE car_shop.person (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    discount INT NOT NULL
);

CREATE TABLE car_shop.country (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50)
);

--------создание ключей----------

ALTER TABLE car_shop.brand
ADD CONSTRAINT brand_country_id
FOREIGN KEY (country_id)
REFERENCES car_shop.country(id);

ALTER TABLE car_shop.auto
ADD CONSTRAINT auto_brand_id
FOREIGN KEY (brand_id)
REFERENCES car_shop.brand(id);

ALTER TABLE car_shop.auto
ADD CONSTRAINT auto_model_id
FOREIGN KEY (model_id)
REFERENCES car_shop.model(id);

ALTER TABLE car_shop.deal
ADD CONSTRAINT deal_auto_id
FOREIGN KEY (auto_id)
REFERENCES car_shop.auto(id);

ALTER TABLE car_shop.deal
ADD CONSTRAINT deal_person_id
FOREIGN KEY (person_id)
REFERENCES car_shop.person(id);

--------заполнение данных--------

INSERT INTO car_shop.country  (name)
SELECT brand_origin FROM sales;

INSERT INTO car_shop.brand (brand_name, country_id)
SELECT split_part(auto, ' ', 1), car_shop.country.id 
FROM sales 
JOIN car_shop.country ON sales.id  = car_shop.country.id;

INSERT INTO car_shop.model  (model_name)
SELECT split_part(auto, ' ', 2) FROM sales;

INSERT INTO car_shop.person  (name, phone, discount)
SELECT person_name, phone, discount  FROM sales;

INSERT INTO car_shop.auto (brand_id, model_id, color, gasoline_consumption, price)
SELECT car_shop.brand.id, car_shop.model.id, split_part(auto, ', ', 2), gasoline_consumption, price
FROM sales 
JOIN car_shop.brand  ON sales.id  = car_shop.brand.id
JOIN car_shop.model ON sales.id  = car_shop.model.id;

INSERT INTO car_shop.deal (auto_id, person_id, date)
SELECT car_shop.auto.id, car_shop.person.id, date
FROM sales 
JOIN car_shop.auto  ON sales.id  = car_shop.auto.id
JOIN car_shop.person ON sales.id  = car_shop.person.id;

--------задание 1--------

SELECT COUNT(car_shop.model.id) * 100.0 / (SELECT COUNT(*) FROM car_shop.model) as nulls_percentage_gasoline_consumption
FROM car_shop.model
LEFT JOIN car_shop.auto ON car_shop.model.id = car_shop.auto.model_id
WHERE car_shop.auto.gasoline_consumption IS NULL;

--------задание 2--------

SELECT b.brand_name as brand_name,
       EXTRACT(year FROM d.date) AS year,
       ROUND(AVG(a.price)::numeric, 2) as price_avg
FROM car_shop.deal d
JOIN car_shop.auto a ON d.auto_id = a.id
JOIN car_shop.brand b ON a.brand_id = b.id
JOIN car_shop.person p ON d.person_id = p.id
GROUP BY b.brand_name, year
ORDER BY b.brand_name, year;

--------задание 3--------

SELECT 
    EXTRACT(month FROM d.date) AS month,
    ROUND(AVG(a.price::numeric), 2) AS price_avg
FROM car_shop.deal d
JOIN car_shop.auto a ON d.auto_id = a.id
WHERE EXTRACT(year FROM d.date) = 2022
GROUP BY EXTRACT(month FROM d.date)
ORDER BY EXTRACT(month FROM d.date) ASC;

--------задание 4--------

SELECT p.name as person,
       STRING_AGG(b.brand_name || ' ' || m.model_name, ', ') AS cars
FROM car_shop.person p
JOIN car_shop.deal d ON p.id = d.person_id
JOIN car_shop.auto a ON d.auto_id = a.id
JOIN car_shop.brand b ON a.brand_id = b.id
JOIN car_shop.model m ON a.model_id = m.id
GROUP BY p.name
ORDER BY p.name ASC;

--------задание 5--------

SELECT c.name as brand_origin,
       MAX(a.price) as price_max,
       MIN(a.price) as price_min
FROM car_shop.deal d
JOIN car_shop.auto a ON d.auto_id = a.id
JOIN car_shop.brand b ON a.brand_id = b.id
JOIN car_shop.country c ON b.country_id = c.id
WHERE c.name IS NOT NULL
GROUP BY c.name;

--------задание 6--------

SELECT COUNT(*) as persons_from_usa_count
FROM car_shop.person
WHERE phone LIKE '+1%'



