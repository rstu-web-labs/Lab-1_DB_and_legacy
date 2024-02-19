CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales ( 
    id SERIAL PRIMARY KEY,
    auto VARCHAR(255), -- информация о авто (символьное значение)
    gasoline_consumption DECIMAL(5,2), -- расход бензина (до 5 цифр, из которых 2 после десятичной точки)
    price DECIMAL(10,2), -- цена (до 10 цифр, из которых 2 после десятичной точки)
    date DATE, -- дата
    person VARCHAR(255), -- имя покупателя (символьное значение)
    phone VARCHAR(30), -- номер телефона (длинное и символьное значение)
    discount DECIMAL(5,2), -- скидка (до 5 цифр, из которых 2 после десятичной точки)
    brand_origin VARCHAR(50), -- происхождение марки автомобиля (символьное значение)
    CONSTRAINT positive_gasoline CHECK (gasoline_consumption >= 0),
    CONSTRAINT sales_discount CHECK (discount >= 0 AND discount <= 100),
    CONSTRAINT sales_auto_check CHECK (auto ~ '^[^,]+ [^,]+,[^,]+$') 
);

copy raw_data.sales FROM '/Users/evgenij/Desktop/papka/backend/Lab-1_DB_and_legacy/cars.csv' DELIMITER ',' CSV HEADER NULL 'null';


  CREATE SCHEMA car_shop;
   
CREATE TABLE car_shop.origins( -- таблица производителей авто
    id SERIAL PRIMARY KEY,
    name VARCHAR(255)-- имя символьное значение
);

INSERT INTO car_shop.origins (name)
SELECT DISTINCT brand_origin
FROM raw_data.sales;

CREATE TABLE car_shop.colors ( -- таблица цветов авто
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL-- имя символьное значение
);

INSERT INTO car_shop.colors (name)
SELECT DISTINCT split_part(substring(auto from '\s+[^,]+$'), ',', 1) AS color_name
FROM raw_data.sales;

CREATE TABLE car_shop.brands ( --таблица брендов
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL, -- имя символьное значение
    origin_id INTEGER REFERENCES car_shop.origins(id) ON DELETE cascade 
);

INSERT INTO car_shop.brands (name, origin_id)
SELECT DISTINCT 
    split_part(auto, ' ', 1) AS brand_name,
    o.id AS origin_id
FROM raw_data.sales r
JOIN car_shop.origins o ON r.brand_origin = o.name;

CREATE TABLE car_shop.models (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,-- имя символьное значение
    brand_id INT REFERENCES car_shop.brands(id) ON DELETE cascade
);

INSERT INTO car_shop.models (name, brand_id)
SELECT DISTINCT
    substring(auto FROM '\s+(.*)\s+[^,]+') AS model_name,
    b.id AS brand_id
FROM raw_data.sales r
JOIN car_shop.brands b ON split_part(r.auto, ' ', 1) = b.name;

CREATE TABLE car_shop.auto( --таблица машин
    id SERIAL PRIMARY KEY,
    brand_id INTEGER REFERENCES car_shop.brands(id) ON DELETE cascade, 
    model_id INTEGER REFERENCES car_shop.models(id) ON DELETE cascade,
    color_id INTEGER REFERENCES car_shop.colors(id) ON DELETE cascade,
    origin_id INTEGER REFERENCES car_shop.origins(id) ON DELETE cascade,
    gasoline_consumption DECIMAL(5,2), 
    CONSTRAINT positive_gasoline CHECK (gasoline_consumption >= 0)
);

INSERT INTO car_shop.auto (brand_id, model_id, color_id, origin_id, gasoline_consumption)
SELECT DISTINCT
    b.id AS brand_id,
    m.id AS model_id,
    c.id AS color_id,
    o.id AS origin_id,
    r.gasoline_consumption
FROM raw_data.sales r
JOIN car_shop.brands b ON split_part(r.auto, ' ', 1) = b.name
JOIN car_shop.models m ON substring(r.auto FROM '\s+(.*)\s+[^,]+') = m.name
JOIN car_shop.colors c ON split_part(substring(auto from '\s+[^,]+$'), ',', 1) = c.name
JOIN car_shop.origins o ON r.brand_origin = o.name;

CREATE TABLE car_shop.buyers ( -- таблица покупателей
 id serial PRIMARY KEY,
 name VARCHAR(255) NOT NULL, -- имя символьное значение
 phone VARCHAR(50) NOT NULL  -- телефон длинное и символьное значение
);

INSERT INTO car_shop.buyers (name, phone)
SELECT DISTINCT person as name, phone
FROM raw_data.sales
WHERE phone NOT IN (SELECT phone FROM car_shop.buyers);

CREATE TABLE car_shop.sales_report( --таблица отчета по продажам
    id SERIAL PRIMARY KEY,
    auto_id INTEGER REFERENCES car_shop.auto(id) ON DELETE CASCADE, 
    person_id INTEGER REFERENCES car_shop.buyers(id) ON DELETE CASCADE,
    price DECIMAL(10,2) NOT NULL,
    date DATE NOT NULL,
    discount DECIMAL(5,2),
    CONSTRAINT sales_report_discount CHECK (discount >= 0 AND discount <= 100)
);

INSERT INTO car_shop.sales_report (auto_id, person_id, price, date, discount)
SELECT
    a.id AS auto_id,
    b.id AS person_id,
    r.price,
    r.date,
    r.discount
FROM raw_data.sales r
JOIN car_shop.auto a ON 
    a.brand_id = (SELECT id FROM car_shop.brands WHERE name = split_part(r.auto, ' ', 1))
JOIN car_shop.buyers b ON
    b.name = r.person AND b.phone = r.phone
JOIN car_shop.models m ON substring(r.auto FROM '\s+(.*)\s+[^,]+') = m.name;

-- 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
SELECT
    (COUNT(DISTINCT CASE WHEN a.gasoline_consumption IS NULL THEN m.id END) * 100.0) / COUNT(DISTINCT m.id) AS nulls_percentage_gasoline_consumption
FROM
    car_shop.models m
LEFT JOIN
    car_shop.auto a ON m.id = a.model_id;

-- 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки. 
-- Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. Среднюю цену округлите до второго знака после запятой.
SELECT
    b.name AS brand_name,
    EXTRACT(YEAR FROM sr.date) AS sales_year,
    ROUND(AVG(sr.price),2) AS average_price
FROM
    car_shop.brands b
LEFT JOIN
    car_shop.auto a ON b.id = a.brand_id
LEFT JOIN
    car_shop.sales_report sr ON a.id = sr.auto_id
GROUP BY
    b.name, sales_year
ORDER BY
    b.name, sales_year;
 
-- 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. 
-- Результат отсортируйте по месяцам в восходящем порядке. 
-- Среднюю цену округлите до второго знака после запятой.
SELECT
    EXTRACT(MONTH FROM sr.date) AS sales_month,
    ROUND(AVG(sr.price), 2) AS average_price
FROM
    car_shop.sales_report sr
WHERE
    EXTRACT(YEAR FROM sr.date) = 2022
GROUP BY
    sales_month
ORDER BY
    sales_month;
   

-- 4.Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. 
-- Пользователь может купить две одинаковые машины. Название машины покажите полное, с названием бренда. 
-- Отсортируйте по имени пользователя в восходящем порядке.
SELECT
    b.name AS user_name,
    STRING_AGG(distinct CONCAT(br.name, ' ', m.name), ', ') AS purchased_cars
FROM car_shop.sales_report sr
JOIN car_shop.auto a ON sr.auto_id = a.id
JOIN car_shop.buyers b ON sr.person_id = b.id
JOIN car_shop.models m ON a.model_id = m.id
JOIN car_shop.brands br ON m.brand_id = br.id
GROUP BY b.name
ORDER BY b.name ASC;
  
--5.Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
--Цена в колонке price дана с учётом скидки.
SELECT
   	o.name AS country,
    MAX(p.price + (p.price * p.discount  / 100))  AS max_sale_price,
    MIN(p.price + (p.price * p.discount / 100)) AS min_sale_price
FROM
    car_shop.sales_report p
JOIN
    car_shop.auto a ON p.auto_id = a.id
JOIN
    car_shop.origins o ON a.origin_id = o.id
GROUP BY o.name;

-- 6.Напишите запрос, который покажет количество всех пользователей из США. 
-- Это пользователи, у которых номер телефона начинается на +1.
SELECT
    COUNT(*) AS persons_from_usa_count
FROM
    car_shop.buyers 
WHERE
    phone LIKE '+1%';