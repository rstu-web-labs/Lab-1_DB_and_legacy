create schema raw_data; 
 
create table raw_data.sales( 
	id serial primary key not null, 
	auto varchar(100) not null, 
	gasoline_consumption decimal(4,2), 
	price decimal(11,4) not null, 
	date DATE not null, 
	person_Name varchar(80) not null, 
	phone varchar(30) not null, 
	discount decimal(3,1) not null, 
	brand_Origin varchar(30) 
);

COPY raw_data.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
FROM '/tmp/cars.csv' DELIMITER ',' CSV HEADER
NULL 'null';

create schema shop;

CREATE TABLE shop.model (
    id SERIAL PRIMARY KEY,
    model VARCHAR(255),
    gasoline_consumption NUMERIC(5, 2)
);
INSERT INTO shop.model (model, gasoline_consumption)
SELECT DISTINCT 
    substring(auto from '^[^ ]+ ([^,]+)') AS model,
    gasoline_consumption AS gasoline_consumption 
FROM raw_data.sales;

CREATE TABLE shop.customer (
    id SERIAL PRIMARY KEY,
    person_name VARCHAR(255),
    phone VARCHAR(50)
);
INSERT INTO shop.customer (person_name, phone)
SELECT DISTINCT 
    person_name,
    phone
FROM raw_data.sales;

CREATE TABLE shop.car (
    id SERIAL PRIMARY KEY,
    brand VARCHAR(255),
    model_id INT,
    brand_origin VARCHAR(255),
    FOREIGN KEY (model_id) REFERENCES shop.model(id)
);
INSERT INTO shop.car (brand, model_id, brand_origin)
SELECT DISTINCT 
    split_part(auto, ' ', 1) AS brand,
    m.id AS model_id,
    brand_origin
FROM raw_data.sales
JOIN shop.model m ON substring(auto from '^[^ ]+ ([^,]+)') = m.model;

CREATE TABLE shop.sell (
    id SERIAL PRIMARY KEY,
    car_id INT,
    person_id INT,
    price DECIMAL(10, 2),
    date DATE,
    discount DECIMAL(5, 2),
    color VARCHAR(50), 
    FOREIGN KEY (car_id) REFERENCES shop.car(id),
    FOREIGN KEY (person_id) REFERENCES shop.customer(id)
);
INSERT INTO shop.sell (car_id, person_id, price, date, discount, color)
SELECT 
    c.id AS car_id,
    p.id AS person_id,
    raw_data.sales.price,
    raw_data.sales.date,
    raw_data.sales.discount,
    substring(raw_data.sales.auto from ',\s*(\w+)$') AS color
FROM raw_data.sales
JOIN car c ON split_part(raw_data.sales.auto, ' ', 1) = c.brand AND substring(auto from '^[^ ]+ ([^,]+)') = (SELECT model FROM model WHERE id = c.model_id)
JOIN customer p ON raw_data.sales.person_name = p.person_name AND raw_data.sales.phone = p.phone;

--1 задание
SELECT 
    (COUNT(*) FILTER (WHERE m.gasoline_consumption IS NULL)::NUMERIC / COUNT(*) * 100) AS nulls_percentage_gasoline_consumption 
FROM 
    shop.model m;
   
--2 задание
SELECT 
    c.brand as brand_name,
    EXTRACT(YEAR FROM s.date) AS year,
    ROUND(AVG(s.price - s.price * (0.01 * s.discount)), 2) AS price_avg
FROM 
    shop.sell s
JOIN 
    shop.car c ON s.car_id = c.id
GROUP BY 
    c.brand, year
ORDER BY 
    c.brand ASC, year ASC;

--3 задание
SELECT 
    EXTRACT(MONTH FROM s.date) AS month,
    EXTRACT(YEAR FROM s.date) AS year,
    ROUND(AVG(s.price - s.price * (0.01 * s.discount)), 2) AS price_avg
FROM 
    shop.sell s
WHERE
    EXTRACT(YEAR FROM s.date) = 2022
GROUP BY 
    month, year
ORDER BY 
    month ASC;

--4 задание
SELECT
    p.person_name AS person,
    STRING_AGG(c.brand || ' ' || m.model, ', ') AS cars
FROM
    shop.sell s
JOIN
    shop.car c ON s.car_id = c.id
JOIN
    shop.model m ON c.model_id = m.id
JOIN
    shop.customer p ON s.person_id = p.id
GROUP BY
    p.person_name
ORDER BY
    p.person_name ASC;

--5 задание
SELECT
    c.brand_origin,
    MAX(s.price + s.price * (0.01 * s.discount)) AS price_max,
    MIN(s.price + s.price * (0.01 * s.discount)) AS price_min
FROM
    shop.sell s
JOIN
    shop.car c ON s.car_id = c.id
GROUP BY
    c.brand_origin;
   
 --6 задание
SELECT 
    COUNT(*) AS persons_from_usa_count
FROM 
    shop.customer
WHERE 
    phone LIKE '+1%';

