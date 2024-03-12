CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id serial PRIMARY KEY,
    auto VARCHAR(50),
    gasoline_consumption DECIMAL(3,1),
    price DECIMAL(19,12),
    date DATE,
    person_name VARCHAR(70),
    phone VARCHAR(50),
    discount DECIMAL(4,2),
    brand_origin VARCHAR(50)
);

COPY raw_data.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
FROM '/tmp/cars.csv'
DELIMITER ','
NULL 'null'
CSV HEADER;

CREATE SCHEMA car_shop;

CREATE TABLE car_shop.person (
    id serial PRIMARY KEY,
    person_name VARCHAR(70) NOT NULL,
    phone VARCHAR(50) NOT NULL
);

CREATE TABLE car_shop.spr_country (
    id serial PRIMARY KEY,
    country_name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE car_shop.brand (
    id serial PRIMARY KEY,
    id_country INT,
    name_brand VARCHAR(50) NOT NULL CHECK (name_brand NOT LIKE ''),
    UNIQUE (name_brand),
    FOREIGN KEY (id_country) REFERENCES car_shop.spr_country(id) 
    ON UPDATE CASCADE
    ON DELETE RESTRICT
);

CREATE TABLE car_shop.model (
    id serial PRIMARY KEY,
    id_brand INT,
    name_model VARCHAR(50) UNIQUE NOT NULL,
    gasoline_consumption DECIMAL(3,1) CHECK (gasoline_consumption >= 0 AND gasoline_consumption <= 99.9) DEFAULT NULL,
    FOREIGN KEY (id_brand) REFERENCES car_shop.brand(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
);

CREATE TABLE car_shop.sett (
    id serial PRIMARY KEY,
    id_model INT,
    color VARCHAR(50) NOT NULL,
    FOREIGN KEY (id_model) REFERENCES car_shop.model(id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
);

CREATE TABLE car_shop.sale (
    id serial PRIMARY KEY,
    id_person INT,
    id_sett INT,
    price DECIMAL(19,12) NOT NULL CHECK (price >= 0 AND price < 9999999.99),
    discount DECIMAL(4,2) CHECK (discount >= 0 AND discount <= 99.99),
    date DATE,
    FOREIGN KEY (id_sett) REFERENCES car_shop.sett(id),
    FOREIGN KEY (id_person) REFERENCES car_shop.person(id)
);

-- Таблица person
INSERT INTO car_shop.person (person_name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;

-- Таблица spr_country
INSERT INTO car_shop.spr_country (country_name)
SELECT DISTINCT brand_origin
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;

-- Заменить id_country на значение по умолчанию (3)
UPDATE car_shop.brand
SET id_country = 3
WHERE id_country IS NULL;

-- Таблица brand
INSERT INTO car_shop.brand (id_country, name_brand)
SELECT csc.id, split_part(rds.auto, ' ', 1)
FROM car_shop.spr_country csc
JOIN raw_data.sales rds ON csc.country_name = rds.brand_origin
GROUP BY split_part(rds.auto, ' ', 1), csc.id;

-- Таблица model
INSERT INTO car_shop.model (id_brand, name_model, gasoline_consumption)
SELECT csb.id, SUBSTRING(rds.auto FROM POSITION(' ' IN rds.auto) + 1 FOR POSITION(',' IN rds.auto) - POSITION(' ' IN rds.auto) - 1), rds.gasoline_consumption
FROM car_shop.brand csb
JOIN raw_data.sales rds ON csb.name_brand = split_part(rds.auto, ' ', 1)
GROUP BY SUBSTRING(rds.auto FROM POSITION(' ' IN rds.auto) + 1 FOR POSITION(',' IN rds.auto) - POSITION(' ' IN rds.auto) - 1), csb.id, rds.gasoline_consumption;

-- Таблица sett
INSERT INTO car_shop.sett (id_model, color)
SELECT csm.id, split_part(rds.auto, ', ', 2)
FROM car_shop.model csm
JOIN raw_data.sales rds ON csm.name_model = SUBSTRING(rds.auto FROM POSITION(' ' IN rds.auto) + 1 FOR POSITION(',' IN rds.auto) - POSITION(' ' IN rds.auto) - 1)
GROUP BY csm.id, split_part(rds.auto, ', ', 2);

-- Таблица sale
INSERT INTO car_shop.sale (id_person, id_sett, price, discount, date)
SELECT csp.id, css.id, rds.price, rds.discount, rds.date
FROM raw_data.sales rds
JOIN car_shop.person csp ON rds.phone = csp.phone
JOIN car_shop.sett css ON split_part(rds.auto, ', ', 2) = css.color
JOIN car_shop.model csm ON csm.id = css.id_model
JOIN car_shop.brand csb ON csb.id = csm.id_brand
WHERE split_part(rds.auto, ', ', 2) = css.color AND css.id_model = csm.id AND csm.name_model = SUBSTRING(rds.auto FROM POSITION(' ' IN rds.auto) + 1 FOR POSITION(',' IN rds.auto) - POSITION(' ' IN rds.auto) - 1);

--- Задание 1 ---
SELECT
    (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM car_shop.model)) AS nulls_percentage_gasoline_consumption
FROM
    car_shop.model
WHERE
    gasoline_consumption IS NULL;

--- Задание 2 ---
SELECT
    csb.name_brand AS brand_name,
    EXTRACT(YEAR FROM cs.date) AS year,
    ROUND(AVG(cs.price - (cs.price * cs.discount / 100)), 2) AS price_avg
FROM
    car_shop.sale cs
JOIN
    car_shop.sett css ON cs.id_sett = css.id
JOIN
    car_shop.model csm ON css.id_model = csm.id
JOIN
    car_shop.brand csb ON csm.id_brand = csb.id
GROUP BY
    csb.name_brand, EXTRACT(YEAR FROM cs.date)
ORDER BY
    csb.name_brand, EXTRACT(YEAR FROM cs.date);


--- Задание 3 ---
SELECT
    EXTRACT(MONTH FROM date) AS month,
    EXTRACT(YEAR FROM date) AS year,
    ROUND(AVG(price - (price * discount / 100)), 2) AS price_avg
FROM
    car_shop.sale
WHERE
    EXTRACT(YEAR FROM date) = 2022
GROUP BY
    EXTRACT(MONTH FROM date), EXTRACT(YEAR FROM date)
ORDER BY
    EXTRACT(MONTH FROM date);


--- Задание 4 ---
SELECT
    csp.person_name AS person,
    STRING_AGG(CONCAT(csb.name_brand, ' ', csm.name_model), ', ') AS cars
FROM
    car_shop.sale cs
JOIN
    car_shop.person csp ON cs.id_person = csp.id
JOIN
    car_shop.sett css ON cs.id_sett = css.id
JOIN
    car_shop.model csm ON css.id_model = csm.id
JOIN
    car_shop.brand csb ON csm.id_brand = csb.id
GROUP BY
    csp.person_name
ORDER BY
    csp.person_name;


--- Задание 5 ---
SELECT
    csc.country_name AS brand_origin,
    MAX(cs.price) AS price_max,
    MIN(cs.price) AS price_min
FROM
    car_shop.sale cs
JOIN
    car_shop.sett css ON cs.id_sett = css.id
JOIN
    car_shop.model csm ON css.id_model = csm.id
JOIN
    car_shop.brand csb ON csm.id_brand = csb.id
JOIN
    car_shop.spr_country csc ON csb.id_country = csc.id
GROUP BY
    csc.country_name
ORDER BY
    csc.country_name;

--- Задание 6 ---
   SELECT
    COUNT(*) AS persons_from_usa_count
FROM
    car_shop.person
WHERE
    phone LIKE '+1%';
