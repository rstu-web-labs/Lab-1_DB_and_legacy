-- id - integer - Уникальный идентификатор, обычно целое число.

-- auto - text -- Строковое значение, так как может содержать различные значения, например, "Audi A4 2018".

-- gasoline_consumption - numeric -- Числовое значение с плавающей запятой, так как это параметр, который может быть представлен в виде десятичной дроби.

-- price - numeric -- Цена обычно представлена числовым значением с плавающей запятой.

-- date - date -- Дата имеет формат даты без времени.

-- person_name - text -- Строковое значение, так как это имя пользователя.

-- phone - text -- Номеры телефонов могут содержать как цифры, так и дефисы или плюсы, поэтому лучше всего использовать строковое значение.

-- discount - integer -- Целое число, поскольку скидка обычно выражается в процентах или в денежном знаке.

-- brand_origin - text -- Строковое значение, так как это название страны или производителя машины.

-- Создание схемы и таблицы для сырых данных

CREATE SCHEMA raw_data;
CREATE TABLE raw_data.sales (
   id integer PRIMARY KEY,
   auto text NOT NULL,
   gasoline_consumption numeric,
   price numeric NOT NULL,
   date date NOT NULL,
   person_name text NOT NULL,
   phone text NOT NULL,
   discount integer NOT NULL,
   brand_origin text
);

-- Загрузка сырых данных в таблицу sales с помощью команды COPY
COPY raw_data.sales(id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin) FROM 'D:\cars.csv' DELIMITER ',' CSV NULL 'null' HEADER;

CREATE SCHEMA car_shop;

CREATE TABLE car_shop.brand (
   id serial PRIMARY KEY,
   brand_name text NOT NULL
);

CREATE TABLE car_shop.model (
   id serial PRIMARY KEY,
   brand_id integer,
   model_name text NOT NULL
);

CREATE TABLE car_shop.color (
   id serial PRIMARY KEY,
   color_name text NOT NULL
);

CREATE TABLE car_shop.gasoline_consumption (
   id serial PRIMARY KEY,
   consumption_value numeric NOT NULL
);

CREATE TABLE car_shop.brand_origin (
   id serial PRIMARY KEY,
   brand_id integer,
   brand_origin_name text NOT NULL,
   FOREIGN KEY (brand_id) REFERENCES car_shop.brand(id)
);

CREATE TABLE car_shop.customer (
   id serial PRIMARY KEY,
   person_name text NOT NULL,
   phone text NOT NULL
);

CREATE TABLE car_shop.car (
    id serial PRIMARY KEY,
    brand_id integer,
    model_id integer,
    color_id integer,
    gasoline_consumption_id integer,
    FOREIGN KEY (brand_id) REFERENCES car_shop.brand(id),
    FOREIGN KEY (model_id) REFERENCES car_shop.model(id),
    FOREIGN KEY (color_id) REFERENCES car_shop.color(id),
    FOREIGN KEY (gasoline_consumption_id) REFERENCES car_shop.gasoline_consumption(id)
);

CREATE TABLE car_shop.purchase (
    id serial PRIMARY KEY,
    car_id integer,
    customer_id integer,
    purchase_date date NOT NULL,
    price numeric NOT NULL,
    discount integer NOT NULL,
    FOREIGN KEY (car_id) REFERENCES car_shop.car(id),
    FOREIGN KEY (customer_id) REFERENCES car_shop.customer(id)
);

-- Вставка данных в нормализованные таблицы
-- Вставка данных из таблицы raw_data.sales в нормализованные таблицы

INSERT INTO car_shop.brand (brand_name)
SELECT DISTINCT split_part(auto, ' ', 1)
FROM raw_data.sales
ON CONFLICT DO NOTHING;

INSERT INTO car_shop.model (brand_id, model_name)
SELECT car_shop.brand.id, trim(split_part(auto, ', ', 1))
FROM raw_data.sales
JOIN car_shop.brand ON car_shop.brand.brand_name = split_part(raw_data.sales.auto, ' ', 1)
ON CONFLICT DO NOTHING;

INSERT INTO car_shop.color (color_name)
SELECT DISTINCT trim(split_part(split_part(auto, ', ', 2),' ',1))
FROM raw_data.sales
ON CONFLICT DO NOTHING;

INSERT INTO car_shop.gasoline_consumption (consumption_value)
SELECT DISTINCT raw_data.sales.gasoline_consumption
FROM raw_data.sales
WHERE raw_data.sales.gasoline_consumption IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO car_shop.brand_origin (brand_origin_name)
SELECT DISTINCT raw_data.sales.brand_origin 
FROM raw_data.sales
WHERE raw_data.sales.brand_origin IS NOT NULL
ON CONFLICT DO NOTHING;

INSERT INTO car_shop.customer (person_name, phone)
SELECT DISTINCT raw_data.sales.person_name, raw_data.sales.phone 
FROM raw_data.sales
ON CONFLICT DO NOTHING;

INSERT INTO car_shop.car (model_id)
SELECT car_shop.model.id
FROM raw_data.sales
JOIN car_shop.model ON car_shop.model.brand_id = (SELECT id FROM car_shop.brand WHERE car_shop.brand.brand_name = split_part(raw_data.sales.auto, ' ', 1)) AND car_shop.model.model_name = trim(split_part(raw_data.sales.auto, ', ', 1))
ON CONFLICT DO NOTHING;

INSERT INTO car_shop.purchase (car_id, customer_id, purchase_date, price, discount)
SELECT car.id, customer.id, raw_data.sales.date, raw_data.sales.price, raw_data.sales.discount
FROM raw_data.sales
JOIN car_shop.model ON car_shop.model.brand_id = (SELECT id FROM car_shop.brand WHERE car_shop.brand.brand_name = split_part(raw_data.sales.auto, ' ', 1)) AND car_shop.model.model_name = trim(split_part(raw_data.sales.auto, ', ', 1))
JOIN car_shop.car ON car_shop.car.model_id = car_shop.model.id
JOIN car_shop.customer ON car_shop.customer.person_name = raw_data.sales.person_name AND car_shop.customer.phone = raw_data.sales.phone;

--1
SELECT 
  (COUNT(*) FILTER (WHERE gasoline_consumption IS NULL) * 100.0) / COUNT(*) AS nulls_percentage_gasoline_consumption
FROM raw_data.sales;

--2
SELECT 
  brand_origin AS brand_name,
  EXTRACT(year FROM date) AS year,
  ROUND(AVG(price - discount)::numeric, 2) AS price_avg
FROM raw_data.sales
GROUP BY brand_origin, EXTRACT(year FROM date)
ORDER BY brand_origin, year;

--3
SELECT 
  EXTRACT(month FROM date) AS month,
  EXTRACT(year FROM date) AS year,
  ROUND(AVG(price - discount)::numeric, 2) AS price_avg
FROM raw_data.sales
WHERE EXTRACT(year FROM date) = 2022
GROUP BY EXTRACT(month FROM date), EXTRACT(year FROM date)
ORDER BY EXTRACT(month FROM date);

--4
SELECT 
  person_name AS person,
  STRING_AGG(auto, ', ' ORDER BY auto) AS cars
FROM raw_data.sales
GROUP BY person_name
ORDER BY person_name;

--5
SELECT 
  brand_origin,
  MAX(price) AS price_max,
  MIN(price) AS price_min
FROM raw_data.sales
GROUP BY brand_origin;

--6
SELECT 
  COUNT(*) AS persons_from_usa_count
FROM raw_data.sales
WHERE phone LIKE '+1%';