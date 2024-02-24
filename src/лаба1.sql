-- Немного о таблицах:
    --raw.data: Таблица для сырых данных.
    --colors: Цвета автомобилей.
    --countries: Страны происхождения брендов автомобилей.
    --car_brands: Бренды автомобилей с указанием страны происхождения.
    --car_models: Модели автомобилей с указанием бренда и расхода бензина.
    --cars: Конкретные автомобили с указанием модели и цвета.
    --car_prices: Цены на автомобили с указанием валюты.
    --clients: Информация о клиентах с их именем и телефоном.
    --car_sales: Продажи автомобилей с датой покупки, стоимостью, скидкой и связями с клиентом и автомобилем.
    
     
-- Создание схемы для исходных данных
CREATE SCHEMA IF NOT EXISTS raw_data;

-- Таблица для сырых данных
CREATE TABLE IF NOT EXISTS raw_data.sales (
    id SERIAL PRIMARY KEY,
    auto TEXT,
    gasoline_consumption NUMERIC,
    price NUMERIC,
    date DATE,
    person_name TEXT,
    phone TEXT,
    discount INTEGER,
    brand_origin TEXT
);

-- Создание схемы для автомобильного магазина
CREATE SCHEMA IF NOT EXISTS car_shop;

-- Таблица цветов
CREATE TABLE car_shop.colors (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE
);

-- Таблица стран
CREATE TABLE car_shop.countries (
    id SERIAL PRIMARY KEY,
    name VARCHAR(60) NOT NULL UNIQUE
);

-- Таблица брендов
CREATE TABLE car_shop.car_brands (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    country_id INTEGER REFERENCES car_shop.countries (id) ON DELETE SET NULL,
    UNIQUE(name, country_id)
);

-- Таблица моделей автомобилей
CREATE TABLE car_shop.car_models (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(100) NOT NULL,
    brand_id INTEGER NOT NULL REFERENCES car_shop.car_brands (id) ON DELETE RESTRICT,
    gasoline_consumption NUMERIC(5, 2) CHECK(gasoline_consumption > 0),
    UNIQUE(model_name, brand_id)
);

-- Таблица конкретных автомобилей
CREATE TABLE car_shop.cars (
    id SERIAL PRIMARY KEY,
    car_model_id INTEGER NOT NULL REFERENCES car_shop.car_models (id) ON DELETE RESTRICT,
    color_id INTEGER NOT NULL REFERENCES car_shop.colors (id) ON DELETE RESTRICT
);

-- Таблица цен
CREATE TABLE car_shop.car_prices (
    id SERIAL PRIMARY KEY,
    price NUMERIC(10, 2) NOT NULL CHECK(price > 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    car_id INTEGER UNIQUE REFERENCES car_shop.cars (id) ON DELETE CASCADE
);

-- Таблица клиентов
CREATE TABLE car_shop.clients (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(22) UNIQUE NOT NULL
);

-- Таблица продаж автомобилей
CREATE TABLE car_shop.car_sales (
    id SERIAL PRIMARY KEY,
    date_purchase DATE NOT NULL,
    total_cost NUMERIC(10, 2) NOT NULL CHECK(total_cost > 0),
    discount NUMERIC(5, 2) NOT NULL DEFAULT 0 CHECK(discount BETWEEN 0 AND 100),
    car_id INTEGER UNIQUE NOT NULL REFERENCES car_shop.cars (id) ON DELETE RESTRICT,
    client_id INTEGER NOT NULL REFERENCES car_shop.clients (id) ON DELETE RESTRICT
);

-- Загрузка сырых данных в таблицу raw_data.sales
COPY raw_data.sales (
    id,
    auto,
    gasoline_consumption,
    price,
    date,
    person_name,
    phone,
    discount,
    brand_origin
)
FROM 'C:\Users\avb97\Desktop\cars.csv' CSV HEADER NULL 'null';

-- Загрузка данных в таблицу цветов
INSERT INTO car_shop.colors (name)
SELECT DISTINCT TRIM(SPLIT_PART(auto, ',', 2))
FROM raw_data.sales;

-- Загрузка данных в таблицу стран
INSERT INTO car_shop.countries (name)
SELECT DISTINCT TRIM(brand_origin)
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;

-- Загрузка данных в таблицу брендов
INSERT INTO car_shop.car_brands (name, country_id)
SELECT DISTINCT TRIM(SPLIT_PART(auto, ' ', 1)), c.id
FROM raw_data.sales AS sal
LEFT JOIN car_shop.countries AS c ON c.name = TRIM(sal.brand_origin);

-- Загрузка данных в таблицу моделей автомобилей
INSERT INTO car_shop.car_models (model_name, gasoline_consumption, brand_id)
SELECT
    DISTINCT TRIM(SPLIT_PART(SUBSTRING(auto, STRPOS(auto, ' ') + 1), ',', 1)) AS model_name,
    gasoline_consumption,
    cb.id
FROM raw_data.sales AS sales
LEFT JOIN car_shop.car_brands AS cb ON TRIM(SPLIT_PART(sales.auto, ' ', 1)) = cb.name;

-- Загрузка данных в таблицу конкретных автомобилей
INSERT INTO car_shop.cars (car_model_id, color_id)
SELECT 
    cm.id, colors.id
FROM raw_data.sales AS sales
LEFT JOIN car_shop.car_brands AS cb ON TRIM(SPLIT_PART(sales.auto, ' ', 1)) = cb.name
LEFT JOIN car_shop.car_models AS cm ON (cb.id = cm.brand_id AND TRIM(SPLIT_PART(SUBSTRING(sales.auto, STRPOS(sales.auto, ' ') + 1), ',', 1)) = cm.model_name)
LEFT JOIN car_shop.colors AS colors ON TRIM(SPLIT_PART(sales.auto, ',', 2)) = colors.name
ORDER BY sales.id;

-- Загрузка данных в таблицу цен
INSERT INTO car_shop.car_prices (car_id, price)
SELECT
    cars.id,
    CASE
        WHEN sales.discount = 0 THEN sales.price
        ELSE sales.price / (100 - sales.discount) * 100
    END
FROM raw_data.sales AS sales
LEFT JOIN car_shop.car_brands AS cb ON TRIM(SPLIT_PART(sales.auto, ' ', 1)) = cb.name
LEFT JOIN car_shop.car_models AS cm ON (cb.id = cm.brand_id AND TRIM(SPLIT_PART(SUBSTRING(sales.auto, STRPOS(sales.auto, ' ') + 1), ',', 1)) = cm.model_name)
LEFT JOIN car_shop.colors AS colors ON TRIM(SPLIT_PART(sales.auto, ',', 2)) = colors.name
LEFT JOIN car_shop.cars AS cars ON cars.car_model_id = cm.id AND cars.color_id = colors.id AND sales.id = cars.id
ORDER BY sales.id;

-- Загрузка данных в таблицу клиентов
INSERT INTO car_shop.clients (full_name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;

-- Загрузка данных в таблицу продаж автомобилей
INSERT INTO car_shop.car_sales (date_purchase, total_cost, discount, car_id, client_id)
SELECT 
    date::DATE,
    sales.price,
    sales.discount,
    cars.id,
    clients.id
FROM raw_data.sales AS sales
LEFT JOIN car_shop.cars AS cars ON sales.id = cars.id
LEFT JOIN car_shop.clients AS clients ON clients.full_name = TRIM(sales.person_name) AND clients.phone = TRIM(sales.phone)
ORDER BY sales.id;

--Аналитические скрипты

-- Задание 1:
SELECT 
    (COUNT(*) FILTER (WHERE gasoline_consumption IS NULL) * 100.0) / COUNT(*) AS nulls_percentage_gasoline_consumption
FROM 
    car_shop.car_models;

-- Задание 2:
SELECT
    cb.name AS brand_name,
    EXTRACT(YEAR FROM cs.date_purchase) AS year,
    ROUND(AVG(cp.price * (1 - cs.discount / 100.0)), 2) AS price_avg
FROM
    car_shop.car_sales AS cs
JOIN car_shop.cars AS c ON cs.car_id = c.id
JOIN car_shop.car_models AS cm ON c.car_model_id = cm.id
JOIN car_shop.car_brands AS cb ON cm.brand_id = cb.id
JOIN car_shop.car_prices AS cp ON c.id = cp.car_id
GROUP BY
    cb.name, EXTRACT(YEAR FROM cs.date_purchase)
ORDER BY
    cb.name, year;


-- Задание 3:
SELECT
    EXTRACT(MONTH FROM cs.date_purchase) AS month,
    EXTRACT(YEAR FROM cs.date_purchase) AS year,
    ROUND(AVG(cp.price * (1 - cs.discount / 100.0)), 2) AS price_avg
FROM
    car_shop.car_sales AS cs
JOIN car_shop.cars AS c ON cs.car_id = c.id
JOIN car_shop.car_prices AS cp ON c.id = cp.car_id
WHERE
    EXTRACT(YEAR FROM cs.date_purchase) = 2022
GROUP BY
    EXTRACT(MONTH FROM cs.date_purchase), EXTRACT(YEAR FROM cs.date_purchase)
ORDER BY
    EXTRACT(MONTH FROM cs.date_purchase);

-- Задание 4:
SELECT
    clients.full_name AS person,
    STRING_AGG(car_models.model_name || ' ' || car_brands.name, ', ') AS cars
FROM
    car_shop.car_sales
JOIN car_shop.cars ON car_sales.car_id = cars.id
JOIN car_shop.clients ON car_sales.client_id = clients.id
JOIN car_shop.car_models ON cars.car_model_id = car_models.id
JOIN car_shop.car_brands ON car_models.brand_id = car_brands.id
GROUP BY
    clients.full_name
ORDER BY
    clients.full_name;

-- Задание 5:
SELECT
    cb.name AS brand_origin,
    MAX(cp.price) AS price_max,
    MIN(cp.price) AS price_min
FROM
    car_shop.car_sales AS cs
JOIN car_shop.cars AS c ON cs.car_id = c.id
JOIN car_shop.car_models AS cm ON c.car_model_id = cm.id
JOIN car_shop.car_brands AS cb ON cm.brand_id = cb.id
JOIN car_shop.car_prices AS cp ON c.id = cp.car_id
GROUP BY
    cb.name;

-- Задание 6:
SELECT 
    COUNT(*) AS persons_from_usa_count
FROM 
    car_shop.clients
WHERE 
    phone LIKE '+1%';



