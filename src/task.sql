
-- Создание схемы raw_data
CREATE SCHEMA raw_data;

-- Создание таблицы sales 
CREATE TABLE raw_data.sales (
    id INT PRIMARY KEY,
    auto VARCHAR(50),
    gasoline_consumtion VARCHAR(50),
    price FLOAT,
    date INT,
    person_name VARCHAR(50),
    phone INT,
    discount INT,
    brand_origin VARCHAR(50)
);

-- Загрузка данных из CSV-файла
COPY raw_data.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin) FROM 'C:\Users\avb97\Desktop\cars.csv' DELIMITER ',' CSV HEADER NULL 'null';

-- Создание схемы car_shop
CREATE SCHEMA car_shop;

-- Создание таблицы cars
CREATE TABLE car_shop.cars (
    car_id SERIAL PRIMARY KEY,
    brand VARCHAR(50) NOT NULL,
    model VARCHAR(255) NOT NULL,
    color VARCHAR(50) NOT NULL
);

-- Создание таблицы purchases
CREATE TABLE car_shop.purchases (
    purchase_id SERIAL PRIMARY KEY,
    car_id INT REFERENCES car_shop.cars(car_id),
    sale_id INT REFERENCES raw_data.sales(id),
    CONSTRAINT unique_purchase UNIQUE(car_id, sale_id)
);

-- Заполнение таблицы cars данными
INSERT INTO car_shop.cars (brand, model, color)
SELECT DISTINCT
    SUBSTRING(auto FROM 1 FOR POSITION(' ' IN auto) - 1) AS brand,
    SUBSTRING(auto FROM POSITION(' ' IN auto) + 1 FOR POSITION(',' IN auto) - POSITION(' ' IN auto) - 1) AS model,
    SUBSTRING(auto FROM POSITION(',' IN auto) + 2) AS color
FROM raw_data.sales;

-- Заполнение таблицы purchases данными
INSERT INTO car_shop.purchases (car_id, sale_id)
SELECT
    c.car_id,
    s.id
FROM
    raw_data.sales s
JOIN
    car_shop.cars c ON SUBSTRING(s.auto FROM 1 FOR POSITION(' ' IN s.auto) - 1) = c.brand
    AND SUBSTRING(s.auto FROM POSITION(' ' IN s.auto) + 1 FOR POSITION(',' IN s.auto) - POSITION(' ' IN s.auto) - 1) = c.model
    AND SUBSTRING(s.auto FROM POSITION(',' IN s.auto) + 2) = c.color;

-- Создание индекса для ускорения JOIN операций
CREATE INDEX idx_car_id ON car_shop.purchases(car_id);
CREATE INDEX idx_sale_id ON car_shop.purchases(sale_id);


-- Task1
SELECT 
    (COUNT(*) FILTER (WHERE gasoline_consumption IS NULL) * 100.0 / COUNT(*)) AS nulls_percentage_gasoline_consumption
FROM 
    raw_data.sales;

-- Task2
SELECT 
    SUBSTRING(s.auto FROM 1 FOR POSITION(' ' IN s.auto) - 1) AS brand_name,
    EXTRACT(YEAR FROM s.date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM 
    raw_data.sales s
GROUP BY 
    brand_name, year
ORDER BY 
    brand_name, year;

-- Task3
SELECT 
    EXTRACT(MONTH FROM s.date) AS month,
    EXTRACT(YEAR FROM s.date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM 
    raw_data.sales s
WHERE 
    EXTRACT(YEAR FROM s.date) = 2022
GROUP BY 
    month, year
ORDER BY 
    month;

-- Task4
SELECT 
    s.person_name AS person,
    STRING_AGG(c.brand || ' ' || c.model, ', ') AS cars
FROM 
    raw_data.sales s
JOIN 
    car_shop.purchases p ON s.id = p.sale_id
JOIN 
    car_shop.cars c ON p.car_id = c.car_id
GROUP BY 
    person
ORDER BY 
    person;

-- Task5
SELECT 
    brand_origin,
    MAX(price) AS price_max,
    MIN(price) AS price_min
FROM 
    raw_data.sales
GROUP BY 
    brand_origin;

-- Task6
SELECT 
    COUNT(*) AS persons_from_usa_count
FROM 
    raw_data.sales
WHERE 
    phone LIKE '+1%';
