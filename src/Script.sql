CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id INT PRIMARY KEY,
    auto VARCHAR(255) NOT NULL,
    gasoline_consumption DECIMAL(6,2), -- цена, 6 чисел до и 2 после запятой
    price DECIMAL(10,2) NOT NULL, -- цена, 10 чисел до и 2 после запятой
    date DATE NOT NULL, -- Дата в формате дата
    person_name VARCHAR(255) NOT NULL, -- Имя, 255 символов максимально
    phone VARCHAR(40) NOT NULL, -- Телефон 40 символов максимально
    discount INT NOT NULL, -- Скидка просто число
    brand_origin VARCHAR(50) -- Страна происхождения 50 сиволов макисмум
);

COPY raw_data.sales FROM '/tmp/cars.csv' DELIMITER ',' CSV HEADER NULL 'null';

CREATE SCHEMA car_shop;

CREATE TABLE car_shop.cars ( -- Таблица машин
    car_id SERIAL PRIMARY KEY,
    brand VARCHAR(50),
    model VARCHAR(255),
    color VARCHAR(50),
    gasoline_consumption DECIMAL(6,2),
    brand_origin VARCHAR(50)
);

INSERT INTO car_shop.cars (brand, model, color, gasoline_consumption, brand_origin)
SELECT 
    SPLIT_PART(auto, ' ', 1) AS brand,
    TRIM(SPLIT_PART(auto, ' ', -2)) AS model,
    TRIM(SPLIT_PART(auto, ',', 2)) AS color,
    gasoline_consumption,
    brand_origin
FROM raw_data.sales;

CREATE TABLE car_shop.customers ( -- Таблица клиентов
    customer_id SERIAL PRIMARY KEY,
    full_name VARCHAR(255),
    phone VARCHAR(40)
);

INSERT INTO car_shop.customers (full_name, phone)
SELECT DISTINCT 
	person_name,
	phone
FROM raw_data.sales;

CREATE TABLE car_shop.purchases ( -- Таблица покупок
    purchase_id SERIAL PRIMARY KEY,
    car_id INT,
    customer_id INT,
    price DECIMAL(10,2),
    date DATE,
    discount INT,
    FOREIGN KEY (car_id) REFERENCES car_shop.cars(car_id),
    FOREIGN KEY (customer_id) REFERENCES car_shop.customers(customer_id)
);

INSERT INTO car_shop.purchases (car_id, customer_id, price, date, discount)
SELECT 
    c.car_id,
    cu.customer_id,
    r.price,
    r.date,
    r.discount
FROM 
    raw_data.sales r
    INNER JOIN car_shop.cars c ON r.auto LIKE CONCAT('%', c.brand, '%', c.model, '%')
    INNER JOIN car_shop.customers cu ON r.person_name = cu.full_name AND r.phone = cu.phone;
	

-- Задание №1
-- Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
   
SELECT 
    (COUNT(*) FILTER (WHERE c.gasoline_consumption IS NULL) * 100.0) / COUNT(*) AS nulls_percentage_gasoline_consumption
FROM 
    car_shop.cars c;

-- Задание №2
-- Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки. 
-- Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. Среднюю цену округлите до второго знака после запятой. 
   
SELECT 
    c.brand AS brand_name,
    EXTRACT(YEAR FROM p.date) AS year,
    ROUND(AVG(p.price * (1 - p.discount / 100)), 2) AS price_avg
FROM 
    car_shop.purchases p
    JOIN car_shop.cars c ON p.car_id = c.car_id
GROUP BY 
    c.brand, EXTRACT(YEAR FROM p.date)
ORDER BY 
    c.brand, year;

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
    STRING_AGG(CONCAT(cars.brand, ' ', cars.model), ', ') AS cars
FROM 
    car_shop.purchases AS p
JOIN 
    car_shop.customers AS c ON p.customer_id = c.customer_id
JOIN 
    car_shop.cars AS cars ON p.car_id = cars.car_id
GROUP BY 
    c.full_name
ORDER BY 
    c.full_name;

-- Задание №5
-- Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
-- Цена в колонке price дана с учётом скидки.

SELECT 
    brand_origin,
    MAX(price) AS price_max,
    MIN(price) AS price_min
FROM 
    car_shop.purchases AS p
JOIN 
    car_shop.cars AS c ON p.car_id = c.car_id
GROUP BY 
    brand_origin
ORDER BY 
    brand_origin;

   
-- Задание №6
-- Напишите запрос, который покажет количество всех пользователей из США. 
-- Это пользователи, у которых номер телефона начинается на +1.
   
SELECT 
    COUNT(*) AS persons_from_usa_count
FROM 
    car_shop.customers
WHERE 
    phone LIKE '+1%';


DROP SCHEMA IF EXISTS car_shop CASCADE;
DROP SCHEMA IF EXISTS raw_data CASCADE;
