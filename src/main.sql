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

-- Создание таблицы cars
CREATE TABLE car_shop.cars (
    car_id SERIAL PRIMARY KEY,
    brand_name VARCHAR(50) NOT NULL,
    model_name VARCHAR(255) NOT NULL,
    color VARCHAR(50) NOT NULL,
    brand_origin VARCHAR(50),
    CONSTRAINT unique_car_details UNIQUE (brand_name, model_name, color)
);

-- Создание таблицы purchases
CREATE TABLE car_shop.purchases (
    purchase_id SERIAL PRIMARY KEY,
    car_id INT REFERENCES car_shop.cars(car_id),
    gasoline_consumption DECIMAL(4,2),
    price DECIMAL(7,2) NOT NULL,
    purchase_date DATE NOT NULL,
    buyer_name VARCHAR(255) NOT NULL,
    buyer_phone VARCHAR(20) NOT NULL,
    discount INT NOT NULL,
    CONSTRAINT valid_discount CHECK (discount >= 0 AND discount <= 100)
);

-- Заполнение таблиц cars и purchases
INSERT INTO car_shop.cars (brand_name, model_name, color, brand_origin)
SELECT DISTINCT
    SPLIT_PART(auto, ' ', 1) AS brand_name,
    SPLIT_PART(auto, ' ', 2) AS model_name,
    SPLIT_PART(auto, ',', 2) AS color,
    brand_origin
FROM raw_data.sales;

INSERT INTO car_shop.purchases (car_id, gasoline_consumption, price, purchase_date, buyer_name, buyer_phone, discount)
SELECT
    c.car_id,
    s.gasoline_consumption,
    s.price,
    s.date,
    s.person,
    s.phone,
    s.discount
FROM raw_data.sales AS s
JOIN car_shop.cars AS c
ON SPLIT_PART(s.auto, ' ', 1) = c.brand_name
    AND SPLIT_PART(s.auto, ' ', 2) = c.model_name
    AND SPLIT_PART(s.auto, ',', 2) = c.color;


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
