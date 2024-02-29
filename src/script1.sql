CREATE DATABASE life_on_wheels;

-- ����� ������

CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id SERIAL PRIMARY KEY, -- ���������� �������������, ���������
    auto VARCHAR(63) NOT NULL, -- �����, ������ � ����
    gasoline_consumption DECIMAL(3,1), -- ����� �� ����� ���� �����������
    	-- ����� � ��������� ������, ������������ �� 1 ����� ����� ,
    price DECIMAL(19,12), -- ����� �� ����� ���� ������ ����������� �����
    	-- ����� � ��������� ������, ������������ �� 12 ������ ����� ,
    date DATE NOT NULL, -- ����, ������� �������� � ��������� ����
    person_name VARCHAR(127) NOT NULL, -- ���
    phone VARCHAR(63) NOT NULL, -- ����� ��������
    discount DECIMAL(5,2) CHECK (discount >= 0 AND discount <= 100), 
    	-- ������ � ���������, ����� �� ������ 100, ������������ �� ���� ������ ����� ,
    brand_origin VARCHAR(127)
);

COPY raw_data.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
FROM 'C:/cars.csv' 
DELIMITER ','
null 'null'
CSV HEADER;

-- ��������������� ������

CREATE SCHEMA car_shop;

CREATE TABLE car_shop.brands (
    id SERIAL PRIMARY KEY, -- ���������� �������������, ���������
    brand VARCHAR(63) NOT NULL, -- �����
    origin VARCHAR(127) -- ������
);

CREATE TABLE car_shop.models (
	id SERIAL PRIMARY KEY, -- ���������� �������������, ���������
	model VARCHAR(63) NOT NULL, -- ������
	brand_id INT NOT NULL, -- ������������� ������, �� �� brands
	gasoline_consumption DECIMAL(3,1),
	FOREIGN KEY (brand_id) REFERENCES car_shop.brands(id)
);

CREATE TABLE car_shop.colors (
    id SERIAL PRIMARY KEY, -- ���������� �������������, ���������
    color VARCHAR(63) NOT NULL -- ���� ����
);

CREATE TABLE car_shop.persons (
    id SERIAL PRIMARY KEY, -- ���������� �������������, ���������
    person_name VARCHAR(127) NOT NULL, -- ���
    phone VARCHAR(63) NOT NULL -- ����� ��������
);

CREATE TABLE car_shop.sale (
    id SERIAL PRIMARY KEY, -- ���������� �������������, ���������
    model_id INT, -- ������������� ������, �� �� models
    color_id INT, -- ������������� �����, �� �� colors
    price DECIMAL(19,12), -- ���� ����
    date DATE NOT NULL, -- ����
    person_name VARCHAR(127) NOT NULL, -- ��� ����������
    discount DECIMAL(5,2), -- ������ � ���������
    FOREIGN KEY (model_id) REFERENCES car_shop.models(id),
    FOREIGN KEY (color_id) REFERENCES car_shop.colors(id)
);

-- ���������� ������ �������

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

-- ������� �1
SELECT 
    ROUND((COUNT(*) FILTER (WHERE gasoline_consumption IS NULL) * 100.0) / COUNT(*), 2) AS nulls_percentage_gasoline_consumption
FROM 
    raw_data.sales;
;

-- ������� �2
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

-- ������� �3
SELECT 
    EXTRACT(MONTH FROM s.date) AS month,
    EXTRACT(YEAR FROM s.date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM car_shop.sale s
WHERE EXTRACT(YEAR FROM s.date) = 2022
GROUP BY month, year
ORDER BY month, year;
;
   
-- ������� �4
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
   
-- ������� �5
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
   
-- ������� �6
SELECT 
    COUNT(*) AS persons_from_usa_count
FROM 
    car_shop.persons
WHERE 
    phone LIKE '+1%';