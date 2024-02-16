-- Создание схемы raw_data
CREATE SCHEMA raw_data;

-- Создание таблицы raw_data.sales
CREATE TABLE raw_data.sales (
    id INT PRIMARY KEY,
    auto VARCHAR(255),
    gasoline_consumption INT,
    price DECIMAL(7, 2),
    date DATE,
    person VARCHAR(255),
    phone VARCHAR(15),
    discount DECIMAL(5, 2),
    brand_origin VARCHAR(255)
);

-- Загрузка данных из CSV-файла
COPY raw_data.sales FROM 'C:\Code\back\Lab-1_DB_and_legacy\cars.csv' DELIMITER ',' CSV header NULL 'null';

-- Создание схемы car_shop
CREATE SCHEMA car_shop;

-- 1. auto - разбиваем на бренд, название машины и цвет
CREATE TABLE car_shop.car_details (
    id SERIAL PRIMARY KEY,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(255) NOT NULL,
    color VARCHAR(50) NOT NULL
);

-- 2. brand_origin - выносим в отдельную таблицу brands
CREATE TABLE car_shop.brands (
    id SERIAL PRIMARY KEY,
    brand_name VARCHAR(50) NOT NULL,
    origin_country VARCHAR(50)
);

-- 3. sales - добавляем внешние ключи
ALTER TABLE raw_data.sales
ADD COLUMN car_details_id INT REFERENCES car_shop.car_details(id),
ADD COLUMN brand_id INT REFERENCES car_shop.brands(id);

-- Заполнение таблиц car_details и brands
INSERT INTO car_shop.car_details (brand, model, color)
SELECT DISTINCT
    SPLIT_PART(auto, ' ', 1) AS brand,
    SPLIT_PART(auto, ' ', 2) AS model,
    SPLIT_PART(auto, ',', 2) AS color
FROM raw_data.sales;

-- Обновление внешних ключей в таблице sales
UPDATE raw_data.sales AS s
SET car_details_id = cd.id
FROM car_shop.car_details AS cd
WHERE SPLIT_PART(s.auto, ' ', 1) = cd.brand
    AND SPLIT_PART(s.auto, ' ', 2) = cd.model
    AND SPLIT_PART(s.auto, ',', 2) = cd.color;

UPDATE raw_data.sales AS s
SET brand_id = b.id
FROM car_shop.brands AS b
WHERE s.brand_origin = b.origin_country;

-- Удаление ненужных столбцов из таблицы sales
ALTER TABLE raw_data.sales
DROP COLUMN auto,
DROP COLUMN brand_origin;


Задание №1 
SELECT
    (COUNT(*) FILTER (WHERE gasoline_consumption IS NULL) * 100.0) / COUNT(*) AS nulls_percentage_gasoline_consumption
FROM
    raw_data.sales;

Задание №2
SELECT
    b.brand_name,
    EXTRACT(YEAR FROM s.date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM
    raw_data.sales s
JOIN
    car_shop.brands b ON s.brand_id = b.id
GROUP BY
    b.brand_name, year
ORDER BY
    b.brand_name, year;

Задание №3
-- Создаем таблицу для результатов
CREATE TABLE result_average_price (
    month INT,
    year INT,
    price_avg DECIMAL(10,2)
);

-- Заполняем таблицу средней ценой по месяцам в 2022 году
INSERT INTO result_average_price (month, year, price_avg)
SELECT
    EXTRACT(MONTH FROM date) AS month,
    EXTRACT(YEAR FROM date) AS year,
    ROUND(AVG(price * (1 - discount / 100.0)), 2) AS price_avg
FROM raw_data.sales
WHERE EXTRACT(YEAR FROM date) = 2022
GROUP BY EXTRACT(MONTH FROM date), EXTRACT(YEAR FROM date)
ORDER BY EXTRACT(MONTH FROM date);

-- Выводим результат
SELECT * FROM result_average_price;

Задание №4
SELECT
    person,
    STRING_AGG(car_shop.car_details.brand || ' ' || car_shop.car_details.model, ', ') AS cars
FROM
    raw_data.sales
JOIN
    car_shop.car_details ON raw_data.sales.car_details_id = car_shop.car_details.id
GROUP BY
    person
ORDER BY
    person ASC;


Задание №5
SELECT
    b.origin_country AS brand_origin,
    MAX(s.price) AS price_max,
    MIN(s.price) AS price_min
FROM
    raw_data.sales AS s
JOIN
    car_shop.brands AS b ON s.brand_id = b.id
GROUP BY
    b.origin_country;

Задание №6
SELECT COUNT(*) AS persons_from_usa_count
FROM raw_data.sales
WHERE phone LIKE '+1%';
