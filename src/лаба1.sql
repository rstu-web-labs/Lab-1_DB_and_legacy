
-- Создание схемы raw_data
CREATE SCHEMA raw_data;

-- Таблица для сырых данных о продажах автомобилей
CREATE TABLE raw_data.sales (
    id SERIAL PRIMARY KEY, -- Уникальный идентификатор продажи
    auto VARCHAR(100), -- Марка, модель и цвет автомобиля
    gasoline_consumption NUMERIC, -- Потребление бензина, л/100км (для электромобилей - NULL)
    price NUMERIC, -- Цена автомобиля с учетом скидки
    date DATE, -- Дата покупки
    person_name VARCHAR(100), -- ФИО покупателя
    phone VARCHAR(50), -- Телефон покупателя
    discount SMALLINT, -- Размер скидки в процентах
    brand_origin VARCHAR(50) -- Страна происхождения бренда
);

-- Таблица для хранения информации о брендах автомобилей
CREATE TABLE car_shop.brands (
    id SERIAL PRIMARY KEY, -- Уникальный идентификатор бренда
    name VARCHAR(50) NOT NULL -- Название бренда
);

-- Таблица для хранения информации о моделях автомобилей, включая цвет
CREATE TABLE car_shop.car_models (
    id SERIAL PRIMARY KEY, -- Уникальный идентификатор модели
    brand_id INTEGER REFERENCES car_shop.brands(id), -- Ссылка на уникальный идентификатор бренда
    name VARCHAR(100) NOT NULL, -- Название модели
    color VARCHAR(50) -- Цвет автомобиля
);

-- Таблица для хранения информации о покупателях автомобилей
CREATE TABLE car_shop.customers (
    id SERIAL PRIMARY KEY, -- Уникальный идентификатор покупателя
    name VARCHAR(100) NOT NULL, -- ФИО покупателя
    phone VARCHAR(50) UNIQUE -- Телефон покупателя (уникальный)
);

-- Таблица для хранения информации о покупках автомобилей, включая связи с покупателями и сырыми данными о продажах
CREATE TABLE car_shop.purchases (
    id SERIAL PRIMARY KEY, -- Уникальный идентификатор покупки
    sales_id INTEGER UNIQUE REFERENCES raw_data.sales(id), -- Ссылка на уникальный идентификатор продажи (сырые данные)
    customer_id INTEGER REFERENCES car_shop.customers(id), -- Ссылка на уникальный идентификатор покупателя
    discount SMALLINT, -- Размер скидки в процентах
    date DATE -- Дата покупки
);
-- Немного о самих таблицах
--  raw_data.sales: Таблица для сырых данных о продажах автомобилей.
--  car_shop.brands: Таблица для хранения информации о брендах автомобилей.
--  car_shop.car_models: Таблица для хранения информации о моделях автомобилей, включая цвет.
--  car_shop.customers: Таблица для хранения информации о покупателях автомобилей.
--  car_shop.purchases: Таблица для хранения информации о покупках автомобилей, включая связи с покупателями и сырыми данными о продажах

-- Загрузка данных из CSV-файла в таблицу raw_data.sales
COPY raw_data.sales FROM 'C:\Users\avb97\Desktop\cars.csv' DELIMITER ',' CSV HEADER NULL 'null';

-- Загрузка данных в таблицу brands
INSERT INTO car_shop.brands (name)
SELECT DISTINCT substring(auto from 1 for position(' ' in auto) - 1)
FROM raw_data.sales;

-- Загрузка данных в таблицу car_models
INSERT INTO car_shop.car_models (brand_id, name, color)
SELECT b.id, substring(auto from position(' ' in auto) + 1), substring(auto from position(',' in auto) + 2)
FROM raw_data.sales r
JOIN car_shop.brands b ON substring(r.auto from 1 for position(' ' in r.auto) - 1) = b.name;

-- Загрузка данных в таблицу customers
INSERT INTO car_shop.customers (name, phone)
SELECT DISTINCT person_name, phone FROM raw_data.sales;

-- Загрузка данных в таблицу purchases
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


