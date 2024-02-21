CREATE DATABASE life_on_wheels;

-- Сырые данные

CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id SERIAL PRIMARY KEY, -- уникальный идентификатор, инкремент
    auto VARCHAR(63) NOT NULL, -- бренд, модель и цвет
    gasoline_consumption DECIMAL(3,1), -- число не может быть трехзначным
    	-- число с плавающей точкой, ограниченное до 1 знака после ,
    price DECIMAL(19,12), -- число не может быть больше семизначной суммы
    	-- число с плавающей точкой, ограниченное до 12 знаков после ,
    date DATE NOT NULL, -- дата, удобное хранение и обработка даты
    person_name VARCHAR(127) NOT NULL, -- фио
    phone VARCHAR(63) NOT NULL, -- номер телефона
    discount DECIMAL(5,2) CHECK (discount >= 0 AND discount <= 100), 
    	-- скидка в процентах, число не больше 100, ограниченное до двух знаков после ,
    brand_origin VARCHAR(127)
);

COPY raw_data.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
FROM 'C:/cars.csv' 
DELIMITER ','
null 'null'
CSV HEADER;

-- Нормализованные данные

CREATE SCHEMA car_shop;

CREATE TABLE car_shop.brands (
    id SERIAL PRIMARY KEY, -- уникальный идентификатор, инкремент
    brand VARCHAR(63) NOT NULL, -- бренд
    origin VARCHAR(127) -- страна
);

CREATE TABLE car_shop.models (
	id SERIAL PRIMARY KEY, -- уникальный идентификатор, инкремент
	model VARCHAR(63) NOT NULL, -- модель
	brand_id INT NOT NULL, -- идентификатор бренда, ВК от brands
	gasoline_consumption DECIMAL(3,1),
	FOREIGN KEY (brand_id) REFERENCES car_shop.brands(id)
);

CREATE TABLE car_shop.colors (
    id SERIAL PRIMARY KEY, -- уникальный идентификатор, инкремент
    color VARCHAR(63) NOT NULL -- цвет авто
);

CREATE TABLE car_shop.persons (
    id SERIAL PRIMARY KEY, -- уникальный идентификатор, инкремент
    person_name VARCHAR(127) NOT NULL, -- фио
    phone VARCHAR(63) NOT NULL -- номер телефона
);

CREATE TABLE car_shop.sale (
    id SERIAL PRIMARY KEY, -- уникальный идентификатор, инкремент
    model_id INT, -- идентификатор модели, ВК от models
    color_id INT, -- идентификатор цвета, ВК от colors
    price DECIMAL(19,12), -- цена авто
    date DATE NOT NULL, -- дата
    person_name VARCHAR(127) NOT NULL, -- фио покупателя
    discount DECIMAL(5,2), -- скидка в процентах
    FOREIGN KEY (model_id) REFERENCES car_shop.models(id),
    FOREIGN KEY (color_id) REFERENCES car_shop.colors(id)
);

-- Заполнение таблиц данными

INSERT INTO car_shop.brands (brand, origin)
SELECT DISTINCT
    split_part(auto, ' ', 1) AS brand,
    brand_origin AS origin
FROM raw_data.sales;
;

INSERT INTO car_shop.models (model, brand_id, gasoline_consumption)
SELECT DISTINCT
    SUBSTRING(s.auto FROM POSITION(' ' IN s.auto) + 1 FOR POSITION(',' IN s.auto) - POSITION(' ' IN s.auto) - 1) AS model,
    b.id AS brand_id,
    s.gasoline_consumption
FROM raw_data.sales s
JOIN car_shop.brands b ON split_part(s.auto, ' ', 1) = b.brand;
;

INSERT INTO car_shop.colors (color)
SELECT DISTINCT
    split_part(auto, ',', 2) AS color
FROM raw_data.sales;
;

INSERT INTO car_shop.persons (person_name, phone)
SELECT DISTINCT
    person_name,
    phone
FROM raw_data.sales;
;

INSERT INTO car_shop.sale (model_id, color_id, price, date, person_name, discount)
SELECT
    m.id AS model_id,
    c.id AS color_id,
    s.price,
    s.date,
    s.person_name,
    s.discount
FROM raw_data.sales s
JOIN car_shop.models m ON SUBSTRING(s.auto FROM POSITION(' ' IN s.auto) + 1 FOR POSITION(',' IN s.auto) - POSITION(' ' IN s.auto) - 1) = m.model
JOIN car_shop.brands b ON m.brand_id = b.id
JOIN car_shop.colors c ON split_part(s.auto, ',', 2) = c.color;
;

-- Задание №1
SELECT 
    ROUND((COUNT(*) FILTER (WHERE gasoline_consumption IS NULL) * 100.0) / COUNT(*), 2) AS nulls_percentage_gasoline_consumption
FROM 
    raw_data.sales;
;

-- Задание №2
SELECT 
    b.brand AS brand_name,
    EXTRACT(year FROM s.date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM 
    car_shop.sale s
JOIN 
    car_shop.models m ON s.model_id = m.id
JOIN 
    car_shop.brands b ON m.brand_id = b.id
GROUP BY 
    b.brand, EXTRACT(year FROM s.date)
ORDER BY 
    b.brand, EXTRACT(year FROM s.date);
;

-- Задание №3
SELECT 
    EXTRACT(MONTH FROM s.date) AS month,
    EXTRACT(YEAR FROM s.date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM car_shop.sale s
WHERE EXTRACT(YEAR FROM s.date) = 2022
GROUP BY month, year
ORDER BY month, year;
;
   
-- Задание №4
SELECT 
    p.person_name AS person,
    STRING_AGG(DISTINCT CONCAT_WS(' ', b.brand, m.model), ', ') AS cars
FROM 
    car_shop.sale s
JOIN 
    car_shop.persons p ON s.person_name = p.person_name
JOIN 
    car_shop.models m ON s.model_id = m.id
JOIN 
    car_shop.brands b ON m.brand_id = b.id
GROUP BY 
    p.person_name
ORDER BY 
    p.person_name;
;
   
-- Задание №5
SELECT 
    b.origin AS brand_origin,
    MAX(s.price * (1 - s.discount / 100.0)) AS price_max,
    MIN(s.price * (1 - s.discount / 100.0)) AS price_min
FROM 
    car_shop.sale s
JOIN 
    car_shop.models m ON s.model_id = m.id
JOIN 
    car_shop.brands b ON m.brand_id = b.id
GROUP BY 
    b.origin;
;
   
-- Задание №6
SELECT 
    COUNT(*) AS persons_from_usa_count
FROM 
    car_shop.persons
WHERE 
    phone LIKE '+1%';