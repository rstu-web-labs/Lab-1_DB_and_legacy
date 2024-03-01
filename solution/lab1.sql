-- Создание схемы raw_data
CREATE SCHEMA raw_data;

-- Создание таблицы sales для сырых данных о продажах автомобилей
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

-- Копирование данных из csv файла в таблицу sales
COPY raw_data.sales(id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin) FROM 'C:\Study\cars.csv' WITH CSV header NULL 'null';

-- Создание схемы car_shop с таблицами содержащими данные о магазине и всем, что с ним связано
CREATE SCHEMA car_shop;

 -- Создание таблицы брендов автомобилей
CREATE TABLE car_shop.brands (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL  
    brand_origin VARCHAR(50) UNIQUE
);

-- Создание таблицы моделей автомобилей
CREATE TABLE car_shop.car_models (
    id SERIAL PRIMARY KEY, 
    brand_id INTEGER REFERENCES car_shop.brands(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    color VARCHAR(50) UNIQUE
);

-- Создание таблицы покупателей
CREATE TABLE car_shop.customers (
    id SERIAL PRIMARY KEY, 
    name VARCHAR(100) NOT NULL, 
    phone VARCHAR(50) UNIQUE 
);

-- Создание таблицы покупок
CREATE TABLE car_shop.purchases (
    id SERIAL PRIMARY KEY,
    sales_id INTEGER UNIQUE REFERENCES raw_data.sales(id) ON DELETE CASCADE, 
    customer_id INTEGER REFERENCES car_shop.customers(id) ON DELETE CASCADE, 
    discount smallint UNIQUE, 
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


-- Аналитические скрипты:

-- Задание 1
-- Запрос для вычисления процента моделей автомобилей, у которых отсутствует параметр gasoline_consumption.
SELECT   (COUNT(*) * 100.0 /  (SELECT COUNT(*)
FROM car_shop.model
    JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
    JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id)) AS nulls_percentage_gasoline_consumption
FROM car_shop.model
JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id
WHERE gasoline_consumption IS null;

--проверить количество авто с таким параметром на сырых данных
SELECT COUNT(*)
from raw_data.sales
where gasoline_consumption isnull ;

-- Задание 2
-- Запрос для вычисления средней цены автомобилей бренда по всем годам с учетом скидки.
SELECT  name_brand as brand_name, to_char(date, 'YYYY') as year, ROUND(AVG(price), 2) as price_avg
FROM car_shop.brand
JOIN car_shop.model ON car_shop.brand.id = car_shop.model.id_brand
JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id
GROUP BY name_brand, to_char(date, 'YYYY')
ORDER BY name_brand asc,  year
;

--Задание 3
-- Запрос для вычисления средней цены всех автомобилей с разбивкой по месяцам в 2022 году с учетом скидки.
SELECT  to_char(date, 'mm') as month, to_char(date, 'yyyy') as year, ROUND(AVG(price), 2) as price_avg
FROM car_shop.brand
JOIN car_shop.model ON car_shop.brand.id = car_shop.model.id_brand
JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id
where to_char(date, 'YYYY') = '2022'
GROUP BY to_char(date, 'mm'), to_char(date, 'yyyy')
ORDER BY to_char(date, 'mm') ASC
;

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