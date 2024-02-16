CREATE SCHEMA raw_data;
CREATE TABLE raw_data.sales ( 
    id SERIAL PRIMARY KEY,
    auto VARCHAR(255) NOT NULL, -- инфа про авто символьное значение
    gasoline_consumption DECIMAL(5,2), -- бензин до 5 цифр из которых 2 цифры будут после десятичной точки
    price DECIMAL(10,2) NOT NULL, -- цена до 10 цифр из которых 2 цифры будут после десятичной точки
    date DATE NOT NULL, --дата
    person VARCHAR(255) NOT NULL, -- имена покупателей символьное значение
    phone VARCHAR(30),-- номер длинное и символьное значение
    discount DECIMAL(5,2), -- скидка до 5 цифр из которых 2 цифры будут после десятичной точки
    brand_origin VARCHAR(50), -- названия стран символьное значение
    CONSTRAINT positive_gasoline CHECK (gasoline_consumption >= 0),
    CONSTRAINT sales_discount CHECK (discount >= 0 AND discount <= 100),
    CONSTRAINT sales_auto_check CHECK (auto ~ '^[^,]+ [^,]+,[^,]+$') 
);

COPY raw_data.sales FROM 'C:/web/cars.csv' DELIMITER ',' CSV HEADER
   NULL 'null';
   
CREATE SCHEMA car_shop;
   
CREATE TABLE car_shop.auto( --таблица машин
    id SERIAL PRIMARY KEY,
    brand VARCHAR(50) NOT NULL, -- бренд символьное значение
    models VARCHAR(50) not null, --модель символьное значение
    color VARCHAR(50) not null, -- цвет символьное значение
    origin VARCHAR(50) -- производитель символьное значение
);

INSERT INTO car_shop.auto (brand, models, color, origin)
SELECT DISTINCT 
    split_part(auto, ' ', 1) AS brand,
    substring(auto from '\s+(.*)\s+[^,]+') AS model_name,
    split_part(substring(auto from '\s+[^,]+$'), ',', 1) AS color,
    brand_origin
FROM raw_data.sales;
   
CREATE TABLE car_shop.brands ( --таблица брендов
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL, -- имя символьное значение
    origin VARCHAR(50) -- производитель символьое значение
);

INSERT INTO car_shop.brands (name, origin)
SELECT DISTINCT 
    split_part(auto, ' ', 1) AS brand_name,
    brand_origin
FROM raw_data.sales;

CREATE TABLE car_shop.models (-- таблица моделей
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,-- имя символьное значение
    brand_id INTEGER REFERENCES car_shop.brands(id) ON DELETE cascade
);

INSERT INTO car_shop.models (name, brand_id)
SELECT DISTINCT
    substring(auto from '\s+(.*)\s+[^,]+') AS model_name,
    b.id
FROM raw_data.sales r
JOIN car_shop.brands b ON split_part(r.auto, ' ', 1) = b.name;

CREATE TABLE car_shop.colors ( -- таблица цветов авто
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,-- имя символьное значение
    model_id INTEGER REFERENCES car_shop.models(id) ON DELETE cascade
);

INSERT INTO car_shop.colors (name, model_id)
SELECT DISTINCT 
    split_part(substring(auto from '\s+[^,]+$'), ',', 1) AS color_name,
    c.id
FROM raw_data.sales r
JOIN car_shop.models c ON substring(r.auto from '\s+(.*)\s+[^,]+') = c.name;

CREATE TABLE car_shop.sales_report( --таблица отчета по продажам
    id SERIAL PRIMARY KEY,
    auto_id INTEGER REFERENCES car_shop.auto(id) ON DELETE CASCADE, 
    gasoline_consumption DECIMAL(5,2), 
    price DECIMAL(10,2) NOT NULL,
    date DATE NOT NULL,
    person_id INTEGER REFERENCES car_shop.buyers(id) ON DELETE CASCADE,
    discount DECIMAL(5,2)
);

INSERT INTO car_shop.sales_report(auto_id, gasoline_consumption, price, date, person_id, discount)
SELECT
    a.id AS auto_id,
    r.gasoline_consumption,
    r.price,
    r.date,
    n.id as person_id,
    r.discount
FROM raw_data.sales r
JOIN car_shop.auto a ON a.brand = split_part(r.auto, ' ', 1) AND a.models = substring(r.auto FROM '\s+(.*)\s+[^,]+')
JOIN car_shop.buyers n ON n.name = r.person;

CREATE TABLE car_shop.buyers ( -- таблица покупателей
 id serial PRIMARY KEY,
 name VARCHAR(255) NOT NULL, -- имя символьное значение
 phone VARCHAR(50) NOT NULL  -- телефон длинное и символьное значение
);

INSERT INTO car_shop.buyers (name, phone)
SELECT DISTINCT person as name, phone
FROM raw_data.sales
WHERE phone NOT IN (SELECT phone FROM car_shop.buyers);

-- 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
SELECT
    (COUNT(DISTINCT CASE WHEN sr.gasoline_consumption IS NULL THEN m.id END) * 100.0) / COUNT(DISTINCT m.id) AS nulls_percentage_gasoline_consumption
FROM
    car_shop.models m
LEFT JOIN
    car_shop.sales_report sr ON m.id = sr.auto_id;

-- 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки. 
-- Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. Среднюю цену округлите до второго знака после запятой.
SELECT
    b.name AS brand_name,
    EXTRACT(YEAR FROM sr.date) AS sales_year,
   ROUND(AVG(sr.price),2) AS average_price
FROM
    car_shop.brands b
JOIN
    car_shop.auto a ON b.name = a.brand
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
    b.name AS buyer_name,
    STRING_AGG(distinct a.brand || ' ' || a.models, ', ') AS purchased_cars
FROM
    car_shop.buyers b
LEFT JOIN
    car_shop.sales_report sr ON b.id = sr.person_id
LEFT JOIN
    car_shop.auto a ON sr.auto_id = a.id
GROUP BY
    b.name
ORDER BY
    b.name;
  
--5.Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
--Цена в колонке price дана с учётом скидки.
SELECT
    b.origin AS country,
    MAX(p.price + (p.price * p.discount  / 100))  AS max_sale_price,
    MIN(p.price + (p.price * p.discount / 100))AS min_sale_price
FROM
    car_shop.sales_report p
JOIN
    car_shop.auto a ON p.auto_id = a.id
JOIN
    car_shop.brands b ON a.brand = b.name
GROUP BY
    b.origin;
   
-- 6.Напишите запрос, который покажет количество всех пользователей из США. 
-- Это пользователи, у которых номер телефона начинается на +1.
SELECT
    COUNT(*) AS persons_from_usa_count
FROM
    car_shop.buyers 
WHERE
    phone LIKE '+1%';
