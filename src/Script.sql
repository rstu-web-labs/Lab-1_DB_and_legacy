CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id INT PRIMARY KEY,
    auto VARCHAR(255) NOT NULL,
    gasoline_consumption DECIMAL(5,2), -- цена, 5 чисел до и 2 после запятой
    price DECIMAL(7,2) NOT NULL CHECK (price > 0), -- цена, 7 чисел до и 2 после запятой
    date DATE NOT NULL, -- Дата в формате дата
    person_name VARCHAR(255) NOT NULL, -- Имя, 255 символов максимально
    phone VARCHAR(40) NOT NULL, -- Телефон 40 символов максимально
    discount INT NOT NULL CHECK (discount BETWEEN 0 AND 100), -- Скидка просто число
    brand_origin VARCHAR(50) -- Страна происхождения 50 сиволов макисмум
);

COPY raw_data.sales FROM '/tmp/cars.csv' DELIMITER ',' CSV HEADER NULL 'null';

CREATE SCHEMA car_shop;

CREATE TABLE car_shop.brands (
    brand_id SERIAL PRIMARY KEY,
    brand_name VARCHAR(50) UNIQUE NOT NULL,
    brand_origin VARCHAR(50)
);

INSERT INTO car_shop.brands (brand_name, brand_origin)
SELECT DISTINCT
    TRIM(SPLIT_PART(auto, ' ', 1)) AS brand_name,
    brand_origin
FROM raw_data.sales;

CREATE TABLE car_shop.colors (
    color_id SERIAL PRIMARY KEY,
    color_name VARCHAR(50) UNIQUE NOT NULL
);

INSERT INTO car_shop.colors (color_name)
SELECT DISTINCT TRIM(SPLIT_PART(auto, ',', 2))
FROM raw_data.sales
ON CONFLICT (color_name) DO NOTHING;

CREATE TABLE car_shop.cars (
    car_id SERIAL PRIMARY KEY,
    brand_id INT,
    color_id INT,
    model VARCHAR(255),
    gasoline_consumption DECIMAL(5,2),
    CONSTRAINT fk_brand FOREIGN KEY (brand_id) REFERENCES car_shop.brands(brand_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_color FOREIGN KEY (color_id) REFERENCES car_shop.colors(color_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

INSERT INTO car_shop.cars (brand_id, color_id, model, gasoline_consumption)
SELECT 
    b.brand_id,
    c.color_id,
    TRIM(',' FROM TRIM(SPLIT_PART(auto, ',', 2) FROM TRIM(SPLIT_PART(auto, ' ', 1) FROM auto))) AS model,
    gasoline_consumption
FROM 
    raw_data.sales r
    INNER JOIN car_shop.brands b ON TRIM(SPLIT_PART(auto, ' ', 1)) = b.brand_name
    INNER JOIN car_shop.colors c ON TRIM(SPLIT_PART(auto, ',', 2)) = c.color_name
ON CONFLICT DO NOTHING;

CREATE TABLE car_shop.customers (
    customer_id SERIAL PRIMARY KEY,
    full_name VARCHAR(255),
    phone VARCHAR(40),
    CONSTRAINT unique_customer_info UNIQUE (full_name, phone)
);

INSERT INTO car_shop.customers (full_name, phone)
SELECT DISTINCT 
    person_name,
    phone
FROM raw_data.sales
ON CONFLICT ON CONSTRAINT unique_customer_info DO NOTHING;

CREATE TABLE car_shop.purchases (
    purchase_id SERIAL PRIMARY KEY,
    car_id INT NOT NULL,
    customer_id INT NOT NULL,
    price DECIMAL(7,2),
    date DATE,
    discount INT,
    FOREIGN KEY (car_id) REFERENCES car_shop.cars(car_id),
    FOREIGN KEY (customer_id) REFERENCES car_shop.customers(customer_id)
);

INSERT INTO car_shop.purchases (car_id, customer_id, price, date, discount)
SELECT DISTINCT ON (r.id)
    c.car_id,
    cu.customer_id,
    r.price,
    r.date,
    r.discount
FROM 
    raw_data.sales r
    INNER JOIN car_shop.cars c ON 
        TRIM(',' FROM TRIM(SPLIT_PART(r.auto, ',', 2) FROM TRIM(SPLIT_PART(r.auto, ' ', 1) FROM r.auto))) = c.model
        AND TRIM(SPLIT_PART(r.auto, ' ', 1)) = (SELECT brand_name FROM car_shop.brands WHERE brand_id = c.brand_id)
        AND TRIM(SPLIT_PART(r.auto, ',', 2)) = (SELECT color_name FROM car_shop.colors WHERE color_id = c.color_id)
    INNER JOIN car_shop.customers cu ON cu.full_name = r.person_name AND r.phone = cu.phone
ORDER BY 
    r.id, r.date;

-- Задание №1
-- Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
   
SELECT 
    (COUNT(DISTINCT c.model) FILTER (WHERE c.gasoline_consumption IS NULL) * 100.0) / COUNT(DISTINCT c.model) AS nulls_percentage_gasoline_consumption
FROM 
    car_shop.cars c;
   

-- Задание №2
-- Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки. 
-- Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. Среднюю цену округлите до второго знака после запятой. 
   
SELECT 
    b.brand_name AS brand_name,
    EXTRACT(YEAR FROM p.date) AS year,
    ROUND(AVG(p.price * (1 - p.discount / 100)), 2) AS price_avg
FROM 
    car_shop.purchases p
    JOIN car_shop.cars c ON p.car_id = c.car_id
    JOIN car_shop.brands b ON c.brand_id = b.brand_id
WHERE 
    p.discount IS NOT NULL -- учитываем только скидки, которые не равны NULL
GROUP BY 
    b.brand_name, EXTRACT(YEAR FROM p.date)
ORDER BY 
    b.brand_name, year;

   
--2015 22к что-то там

-- Задание №3
-- Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
-- Результат отсортируйте по месяцам в восходящем порядке. 
-- Среднюю цену округлите до второго знака после запятой.
   
SELECT 
    EXTRACT(MONTH FROM p.date) AS month,
    EXTRACT(YEAR FROM p.date) AS year,
    ROUND(AVG(p.price * (1 - p.discount / 100)), 2) AS price_avg
FROM 
    car_shop.purchases p
WHERE 
    EXTRACT(YEAR FROM p.date) = 2022
GROUP BY 
    EXTRACT(MONTH FROM p.date), EXTRACT(YEAR FROM p.date)
ORDER BY 
    EXTRACT(MONTH FROM p.date);

-- Задание №4
-- Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. 
-- Пользователь может купить две одинаковые машины — это нормально. Название машины покажите полное, с названием бренда — например: Tesla Model 3. 
-- Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.
 
SELECT 
    c.full_name AS person,
    STRING_AGG(CONCAT(b.brand_name, ' ', ca.model), ', ') AS cars
FROM 
    car_shop.purchases AS p
JOIN 
    car_shop.customers AS c ON p.customer_id = c.customer_id
JOIN 
    car_shop.cars AS ca ON p.car_id = ca.car_id
JOIN 
    car_shop.brands AS b ON ca.brand_id = b.brand_id
GROUP BY 
    c.full_name
ORDER BY 
    c.full_name;

-- Задание №5
-- Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
-- Цена в колонке price дана с учётом скидки.

SELECT 
    b.brand_origin,
    MAX(p.price) AS price_max,
    MIN(p.price) AS price_min
FROM 
    car_shop.purchases AS p
JOIN 
    car_shop.cars AS c ON p.car_id = c.car_id
JOIN 
    car_shop.brands AS b ON c.brand_id = b.brand_id
GROUP BY 
    b.brand_origin
ORDER BY 
    b.brand_origin;

-- Задание №6
-- Напишите запрос, который покажет количество всех пользователей из США. 
-- Это пользователи, у которых номер телефона начинается на +1.
   
SELECT 
    COUNT(*) AS persons_from_usa_count
FROM 
    car_shop.customers
WHERE 
    phone LIKE '+1%';

--DROP SCHEMA IF EXISTS car_shop CASCADE;
--DROP SCHEMA IF EXISTS raw_data CASCADE;
