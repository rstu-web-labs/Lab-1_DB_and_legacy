-- Создание схемы для сырых данных
CREATE SCHEMA raw_data;

-- Создание таблицы для сырых данных
CREATE TABLE raw_data.sales (
    id smallint PRIMARY KEY,
    auto varchar(55) NOT NULL,
    gasoline_consumption numeric(4,2) CHECK (gasoline_consumption < 100),
    price numeric(50, 20) NOT NULL,
    date DATE NOT NULL,
    person_name varchar(55) NOT NULL,
    phone varchar(55),
    discount numeric(4,2) CHECK (discount >= 0),
    brand_origin varchar(55) 
);


-- Заполнение таблицы сырыми данными
COPY raw_data.sales 
FROM '/cars.csv' 
WITH CSV HEADER NULL 'null' DELIMITER ',';


-- Создание схемы для нормализованной БД
CREATE SCHEMA car_shop;

-- Создание таблицы стран
CREATE TABLE car_shop.country (
    id_country SERIAL PRIMARY KEY,
    brand_origin varchar(55) UNIQUE
);

-- Заполнение таблицы стран
INSERT INTO car_shop.country (brand_origin)
SELECT DISTINCT brand_origin FROM raw_data.sales;

-- Создание таблицы цветов
CREATE TABLE car_shop.color (
    id_color SERIAL PRIMARY KEY,
    name_color varchar(55) UNIQUE
);

-- Заполнение таблицы цветов
INSERT INTO car_shop.color (name_color)
SELECT DISTINCT SUBSTRING(auto, POSITION(',' IN auto) + 2) FROM raw_data.sales;


-- Создание таблицы клиентов
CREATE TABLE car_shop.people (
    id_person SERIAL PRIMARY KEY,
    name_person varchar(55) NOT NULL,
    phone varchar(55)
);

-- Заполнение таблицы клиентов
INSERT INTO car_shop.people (name_person, phone)
SELECT DISTINCT person_name, phone FROM raw_data.sales;


-- Создание таблицы брендов
CREATE TABLE car_shop.brand (
    id_brand SERIAL PRIMARY KEY,
    id_country INT,
    name_brand varchar(55),
    CONSTRAINT fk_constraint_country FOREIGN KEY (id_country) 
        REFERENCES car_shop.country(id_country)
);

-- Заполнение таблицы брендов
INSERT INTO car_shop.brand (name_brand, id_country)
SELECT DISTINCT SUBSTRING(auto, 1, POSITION(' ' IN auto) - 1), 
COALESCE(c.id_country, (SELECT id_country FROM car_shop.country WHERE brand_origin IS NULL))
FROM raw_data.sales s
LEFT JOIN car_shop.country c ON c.brand_origin = s.brand_origin;


-- Создание таблицы моделей машин
CREATE TABLE car_shop.model_car (
    id_model SERIAL PRIMARY KEY,
    id_brand INT,
    name_model varchar(55),
    gasoline_consumption numeric(4,2) CHECK (gasoline_consumption BETWEEN 0 and 100),
    CONSTRAINT fk_constraint_brand FOREIGN KEY (id_brand)
    REFERENCES car_shop.brand(id_brand)
    ON DELETE CASCADE
);

-- Заполнение таблицы моделей машин
INSERT INTO car_shop.model_car (id_brand, name_model, gasoline_consumption)
SELECT DISTINCT b.id_brand, 
SUBSTRING(s.auto, POSITION(' ' IN s.auto)+1, POSITION(',' IN s.auto)-POSITION(' ' IN s.auto)-1), 
s.gasoline_consumption
FROM raw_data.sales s
JOIN car_shop.brand b ON b.name_brand = SUBSTRING(s.auto, 1, POSITION(' ' IN s.auto)-1); 


-- Создание таблицы автомобилей
CREATE TABLE car_shop.cars (
    id_car SERIAL PRIMARY KEY,
    id_color INT, 
    id_model INT,
    CONSTRAINT fk_constraint_color FOREIGN KEY (id_color)
    REFERENCES car_shop.color(id_color),
    CONSTRAINT fk_constraint_model FOREIGN KEY (id_model)
    REFERENCES car_shop.model_car(id_model)
);

-- Заполнение таблицы автомобилей
INSERT INTO car_shop.cars (id_model, id_color)
SELECT DISTINCT mc.id_model, c.id_color
FROM raw_data.sales s
JOIN car_shop.model_car mc ON mc.name_model = SUBSTRING(s.auto, POSITION(' ' IN s.auto)+1, POSITION(',' IN s.auto)-POSITION(' ' IN s.auto)-1)
JOIN car_shop.color c ON c.name_color = SUBSTRING(auto, POSITION(',' IN auto) + 2)
LEFT JOIN car_shop.cars ca ON ca.id_model = mc.id_model AND ca.id_color = c.id_color
WHERE ca.id_model IS NULL;


-- Создание таблицы покупок
CREATE TABLE car_shop.purchases (
    id_purchases SERIAL PRIMARY KEY,
    id_car INT, 
    id_person INT,
    date_purch DATE,
    price numeric(50, 20),
    discount numeric(4,2) CHECK (discount >= 0),
    CONSTRAINT fk_constraint_people FOREIGN KEY (id_person)
    REFERENCES car_shop.people(id_person),
    CONSTRAINT fk_constraint_car FOREIGN KEY (id_car)
    REFERENCES car_shop.cars(id_car)
);

-- Заполнение таблицы покупок
INSERT INTO car_shop.purchases (id_person, id_car, date_purch, price, discount)
SELECT DISTINCT p.id_person, c.id_car, s.date, s.price, s.discount
FROM raw_data.sales s
JOIN car_shop.people p ON p.name_person = s.person_name
JOIN car_shop.cars c ON c.id_model = (
    SELECT id_model
    FROM car_shop.model_car mc
    WHERE mc.name_model = SUBSTRING(s.auto, POSITION(' ' IN s.auto)+1, POSITION(',' IN s.auto)-POSITION(' ' IN s.auto)-1)
)
JOIN car_shop.color col ON col.name_color = SUBSTRING(auto, POSITION(',' IN auto) + 2)
WHERE c.id_color = col.id_color;

------------------------------------------------------------------------------

-- ЗАДАЧА 1

SELECT 
    (COUNT(*) FILTER (WHERE gasoline_consumption IS NULL)::float / COUNT(*)::float) * 100 AS percentage
FROM 
    car_shop.model_car;


-- ЗАДАЧА 2

SELECT 
    b.name_brand, 
    EXTRACT(YEAR FROM p.date_purch) AS year, 
    ROUND(AVG(p.price), 2) AS avg_price 
FROM 
    car_shop.purchases p
JOIN 
    car_shop.cars c USING(id_car)
JOIN 
    car_shop.model_car mc USING(id_model)
JOIN 
    car_shop.brand b USING(id_brand)
GROUP BY 
    name_brand, year
ORDER BY 
    name_brand, year;


-- ЗАДАЧА 3

SELECT 
    EXTRACT(MONTH FROM p.date_purch) AS month,
    EXTRACT(YEAR FROM p.date_purch) AS year,
    ROUND(AVG(p.price), 2) AS price_avg
FROM 
    car_shop.purchases p
WHERE 
    p.date_purch >= '2022-01-01' AND p.date_purch < '2023-01-01'
GROUP BY 
    month, year
ORDER BY 
    month ASC;


-- ЗАДАЧА 4

SELECT 
    p.name_person AS person,
    STRING_AGG(b.name_brand || ' ' || mc.name_model, ', ') AS cars
FROM 
    car_shop.people p
JOIN 
    car_shop.purchases pc USING(id_person)
JOIN 
    car_shop.cars c USING(id_car)
JOIN 
    car_shop.model_car mc USING(id_model)
JOIN 
    car_shop.brand b USING(id_brand)
GROUP BY 
    person
ORDER BY 
    person;


-- ЗАДАЧА 5

SELECT 
    co.brand_origin, 
    ROUND(MAX(p.price / (1 - p.discount/100)), 2) AS max_price,
    ROUND(MIN(p.price / (1 - p.discount/100)), 2) AS min_price
FROM 
    car_shop.purchases p
JOIN 
    car_shop.cars c USING(id_car)
JOIN 
    car_shop.model_car mc USING(id_model)
JOIN 
    car_shop.brand b USING(id_brand)
JOIN 
    car_shop.country co USING(id_country)
GROUP BY 
    co.brand_origin
ORDER BY 
    max_price DESC;


-- ЗАДАЧА 6

SELECT 
    COUNT(*) AS usa_persons_count
FROM 
    car_shop.people 
WHERE 
    phone LIKE '+1%';
