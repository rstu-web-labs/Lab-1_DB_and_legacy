CREATE DATABASE life_on_wheels;

CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id SERIAL PRIMARY KEY,
    auto TEXT,
    gasoline_consumption FLOAT CHECK (gasoline_consumption >= 0),
    price MONEY CHECK (price >= 0),
    date DATE,
    person_name TEXT,
    phone TEXT,
    discount INT CHECK (discount >= 0),
    brand_origin TEXT
);

COPY raw_data.sales(auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
FROM '/cars.csv' DELIMITER ',' CSV HEADER;

CREATE SCHEMA car_shop;

CREATE TABLE car_shop.brands (
    brand_id SERIAL PRIMARY KEY,
    brand_name VARCHAR(100) NOT NULL,
    brand_origin VARCHAR(100),
    UNIQUE(brand_name, brand_origin)
);

CREATE TABLE car_shop.colors (
    color_id SERIAL PRIMARY KEY,
    color_name VARCHAR(50) NOT NULL,
    UNIQUE(color_name)
);

CREATE TABLE car_shop.cars (
    car_id SERIAL PRIMARY KEY,
    brand_id INT REFERENCES car_shop.brands(brand_id),
    model VARCHAR(100) NOT NULL,
    color_id INT REFERENCES car_shop.colors(color_id),
    gasoline_consumption DECIMAL(5, 2) CHECK (gasoline_consumption >= 0),
    UNIQUE(model, color_id)
);

CREATE TABLE car_shop.sales (
    sale_id SERIAL PRIMARY KEY,
    car_id INT REFERENCES car_shop.cars(car_id) ON DELETE CASCADE,
    customer_id INT REFERENCES car_shop.customers(customer_id) ON DELETE CASCADE,
    sale_date DATE NOT NULL,
    price MONEY NOT NULL CHECK (price >= 0),
    discount DECIMAL(5, 2) NOT NULL CHECK (discount >= 0),
    UNIQUE(car_id, customer_id, sale_date)
);

CREATE TABLE car_shop.customers (
    customer_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL
);

INSERT INTO car_shop.brands (brand_name, brand_origin)
SELECT DISTINCT split_part(auto, ' ', 1), brand_origin
FROM raw_data.sales;

INSERT INTO car_shop.colors (color_name)
SELECT DISTINCT split_part(auto, ',', 2)
FROM raw_data.sales;

INSERT INTO car_shop.cars (brand_id, model, color_id, gasoline_consumption)
SELECT b.brand_id, split_part(auto, ' ', 2), c.color_id, gasoline_consumption
FROM raw_data.sales s
JOIN car_shop.brands b ON b.brand_name = split_part(s.auto, ' ', 1)
JOIN car_shop.colors c ON c.color_name = split_part(s.auto, ',', 2);

INSERT INTO car_shop.customers (full_name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;

INSERT INTO car_shop.sales (car_id, customer_id, sale_date, price, discount)
SELECT c.car_id, cu.customer_id, s.date, s.price, s.discount
FROM raw_data.sales s
JOIN car_shop.cars c ON c.brand_id = (SELECT brand_id FROM car_shop.brands WHERE brand_name = split_part(s.auto, ' ', 1))
JOIN car_shop.colors col ON col.color_name = split_part(s.auto, ',', 2)
JOIN car_shop.customers cu ON cu.phone = s.phone;

SELECT ROUND((COUNT(*) FILTER (WHERE gasoline_consumption IS NULL)::decimal / COUNT(*)) * 100, 2) AS nulls_percentage_gasoline_consumption
FROM car_shop.cars;

SELECT
    b.brand_name,
    EXTRACT(YEAR FROM s.sale_date) AS year,
    ROUND(AVG(CAST(s.price AS NUMERIC) * (1 - s.discount / 100.0)), 2) AS price_avg
FROM
    car_shop.sales s
JOIN
    car_shop.cars c ON s.car_id = c.car_id
JOIN
    car_shop.brands b ON c.brand_id = b.brand_id
GROUP BY
    b.brand_name, year
ORDER BY
    b.brand_name, year;

SELECT
    cu.full_name AS person,
    STRING_AGG(b.brand_name || ' ' || c.model, ', ') AS cars
FROM
    car_shop.sales s
JOIN
    car_shop.cars c ON s.car_id = c.car_id
JOIN
    car_shop.brands b ON c.brand_id = b.brand_id
JOIN
    car_shop.customers cu ON s.customer_id = cu.customer_id
GROUP BY
    cu.full_name
ORDER BY
    cu.full_name;

SELECT
    b.brand_origin,
    MAX(s.price / (1 - s.discount / 100.0)) AS price_max,
    MIN(s.price / (1 - s.discount / 100.0)) AS price_min
FROM
    car_shop.sales s
JOIN
    car_shop.cars c ON s.car_id = c.car_id
JOIN
    car_shop.brands b ON c.brand_id = b.brand_id
GROUP BY
    b.brand_origin;

SELECT
    COUNT(*) AS persons_from_usa_count
FROM
    car_shop.customers
WHERE
    phone LIKE '+1%';
