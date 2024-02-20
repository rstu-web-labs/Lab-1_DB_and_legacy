-- Создаем схему raw_data
CREATE SCHEMA raw_data;

--Создаем базу данных
CREATE DATABASE life_on_wheels;

-- Создаем таблицу sales в схеме raw_data
CREATE TABLE raw_data.sales (
    id SERIAL PRIMARY KEY, -- id
    auto VARCHAR(200) NOT NULL, -- Машина(марка, модель, цвет)
    gasoline_consumption FLOAT, -- Потребление бензина
    price FLOAT NOT NULL, -- Цена с учетом скидки
    date DATE NOT NULL, -- Дата сделки
    person_name VARCHAR(200) NOT NULL, -- Клиент(фио)
    phone VARCHAR(30) NOT NULL, -- Телефон клиента
    discount INT, -- Скидка
    brand_origin VARCHAR(200) -- Страна бренда
);

-- Копируем данные из CSV файла в таблицу sales
COPY raw_data.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
FROM 'J:\study\3-036\web-prog\Lab_01\cars.csv'
WITH CSV HEADER DELIMITER ',' NULL 'null';

-- Создаем схему car_shop, а в ней нормализованные таблицы
CREATE SCHEMA car_shop;

CREATE TABLE car_shop.brands (
    id SERIAL PRIMARY KEY, -- id выбрал сериал, потому что сам заполняет значение
    name VARCHAR(50) NOT NULL -- Имя VARCHAR(50) - строка с максимальным значение 50 символов
    brand_origin VARCHAR(50)
);

CREATE TABLE car_shop.car_models (
    id SERIAL PRIMARY KEY,
    brand_id INTEGER REFERENCES car_shop.brands(id), -- id бренда, целочисленное значение с ссылкой
    name VARCHAR(100) NOT NULL,
    color VARCHAR(50)
);

CREATE TABLE car_shop.customers (
    id SERIAL PRIMARY KEY, 
    name VARCHAR(100) NOT NULL, 
    phone VARCHAR(50) UNIQUE 
);

CREATE TABLE car_shop.purchases (
    id SERIAL PRIMARY KEY,
    sales_id INTEGER UNIQUE REFERENCES raw_data.sales(id), 
    customer_id INTEGER REFERENCES car_shop.customers(id), 
    discount INT, 
    date DATE 
);

INSERT INTO car_shop.brands (name, brand_origin)
SELECT DISTINCT substring(auto from 1 for position(' ' in auto) - 1), substring(auto from position('" ' in auto) + 2)
FROM raw_data.sales;

INSERT INTO car_shop.car_models (brand_id, name, color)
SELECT b.id, substring(auto from position(' ' in auto) + 1), substring(auto from position(',' in auto) + 2)
FROM raw_data.sales r
JOIN car_shop.brands b ON substring(r.auto from 1 for position(' ' in r.auto) - 1) = b.name;

INSERT INTO car_shop.customers (name, phone)
SELECT DISTINCT person_name, phone FROM raw_data.sales;

INSERT INTO car_shop.purchases (sales_id, customer_id, discount, date)
SELECT s.id, c.id, discount, date
FROM raw_data.sales s
JOIN car_shop.customers c ON s.person_name = c.name AND s.phone = c.phone;


--Аналитические скрипты:

-- Задание 1
-- Запрос для вычисления процента моделей автомобилей, у которых отсутствует параметр gasoline_consumption.
SELECT 
    ROUND(COUNT(CASE WHEN gasoline_consumption IS NULL THEN 1 END) * 100.0 / COUNT(*), 2) AS nulls_percentage_gasoline_consumption
FROM 
    raw_data.sales;

-- Задание 2
-- Запрос для вычисления средней цены автомобилей бренда по всем годам с учетом скидки.
-- Результат сгруппирован по бренду и году, отсортирован по бренду и году.
SELECT
    b.name AS brand_name,
    EXTRACT(YEAR FROM s.date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM
    raw_data.sales s
JOIN
    car_shop.brands b ON substring(s.auto from 1 for position(' ' in s.auto) - 1) = b.name
GROUP BY
    b.name, EXTRACT(YEAR FROM s.date)
ORDER BY
    b.name, year;

--Задание 3
-- Запрос для вычисления средней цены всех автомобилей с разбивкой по месяцам в 2022 году с учетом скидки.
-- Результат сгруппирован по месяцам и году, отсортирован по месяцам.
SELECT
    EXTRACT(MONTH FROM s.date) AS month,
    EXTRACT(YEAR FROM s.date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM
    raw_data.sales s
WHERE
    EXTRACT(YEAR FROM s.date) = 2022
GROUP BY
    EXTRACT(MONTH FROM s.date), EXTRACT(YEAR FROM s.date)
ORDER BY
    EXTRACT(MONTH FROM s.date);

-- Задание 4
-- Запрос для получения списка купленных машин у каждого пользователя через запятую.
-- Результат сгруппирован по имени пользователя и отсортирован по имени пользователя.
SELECT
    c.name AS person,
    STRING_AGG(substring(s.auto from position(' ' in s.auto) + 1), ', ' ORDER BY s.date) AS cars
FROM
    raw_data.sales s
JOIN
    car_shop.customers c ON s.person_name = c.name AND s.phone = c.phone
GROUP BY
    c.name;

-- Задание 5
-- Запрос для нахождения самой большой и самой маленькой цены продажи автомобиля с разбивкой по стране без учета скидки.
-- Результат сгруппирован по стране.
SELECT
    brand_origin,
    MAX(price) AS price_max,
    MIN(price) AS price_min
FROM
    raw_data.sales
GROUP BY
    brand_origin;


-- Задание 6
-- Запрос для вычисления количества всех пользователей из США (пользователей с номерами телефонов, начинающихся на +1).
SELECT
    COUNT(*) AS persons_from_usa_count
FROM
    car_shop.customers
WHERE
    phone LIKE '+1%';