-- Создание базы данных
CREATE DATABASE life_on_wheels;

-- Создание схемы для сырых данных
CREATE SCHEMA raw_data;

-- Создание таблицы для сырых данных
CREATE TABLE raw_data.sales (
    id SERIAL PRIMARY KEY,
    auto TEXT,
    gasoline_consumption FLOAT,
    price MONEY,
    date DATE,
    person_name TEXT,
    phone TEXT,
    discount INT,
    brand_origin TEXT
);

-- Загрузка данных из CSV-файла в таблицу sales
COPY raw_data.sales(auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
FROM '/cars.csv' DELIMITER ',' CSV HEADER;

-- Создание схемы
CREATE SCHEMA car_shop;

-- Создание таблицы в схеме
CREATE TABLE car_shop.brands (
    brand_id SERIAL PRIMARY KEY,
    brand_name TEXT NOT NULL,
    brand_origin TEXT
);

-- Создание таблицы cars
CREATE TABLE car_shop.cars (
    car_id SERIAL PRIMARY KEY,
    brand_id INT REFERENCES car_shop.brands(brand_id),
    model TEXT NOT NULL,
    color TEXT NOT NULL,
    gasoline_consumption FLOAT
);

-- Создание таблицы sales
CREATE TABLE car_shop.sales (
    sale_id SERIAL PRIMARY KEY,
    car_id INT REFERENCES car_shop.cars(car_id),
    customer_id INT REFERENCES car_shop.customers(customer_id),
    sale_date DATE NOT NULL,
    price MONEY NOT NULL,
    discount INT
);

CREATE TABLE car_shop.customers (
    customer_id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone TEXT UNIQUE NOT NULL
);


-- Заполнение нормализованных таблиц данными
INSERT INTO car_shop.brands (brand_name, brand_origin)
SELECT DISTINCT split_part(auto, ' ', 1), brand_origin
FROM raw_data.sales;

INSERT INTO car_shop.cars (brand_id, model, color, gasoline_consumption)
SELECT b.brand_id, split_part(auto, ' ', 2), split_part(auto, ',', 2), gasoline_consumption
FROM raw_data.sales s
JOIN car_shop.brands b ON b.brand_name = split_part(s.auto, ' ', 1);

INSERT INTO car_shop.customers (full_name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;

INSERT INTO car_shop.sales (car_id, customer_id, sale_date, price, discount)
SELECT c.car_id, cu.customer_id, s.date, s.price, s.discount
FROM raw_data.sales s
JOIN car_shop.cars c ON c.model = split_part(s.auto, ' ', 2) AND c.color = split_part(s.auto, ',', 2)
JOIN car_shop.customers cu ON cu.phone = s.phone;

-- Запрос для аналитики
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
