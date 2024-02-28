-- Создание схемы и таблицы для сырых данных
CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id serial PRIMARY KEY, -- Уникальный идентификатор
    auto VARCHAR(50), -- Марка автомобиля
    gasoline_consumption DECIMAL(3,1), -- Расход бензина (десятичная дробь)
    price DECIMAL(19,12), -- Цена автомобиля
    date DATE, -- Дата продажи
    person_name VARCHAR(70), -- Имя покупателя
    phone VARCHAR(50), -- Номер телефона покупателя
    discount DECIMAL(4,2), -- Скидка (до сотых)
    brand_origin VARCHAR(50) -- Страна производителя
);

-- Копирование данных из CSV файла в таблицу
copy raw_data.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
from '/tmp/cars.csv' 
DELIMITER ','
null 'null'
csv header;

-- Создание схемы и таблиц для магазина автомобилей
CREATE SCHEMA car_shop;

CREATE TABLE car_shop.person (
    id serial PRIMARY KEY, -- Уникальный идентификатор покупателя
    person_name VARCHAR(70) NOT NULL, -- Имя покупателя
    phone VARCHAR(50) NOT NULL -- Номер телефона покупателя
);

CREATE TABLE car_shop.spr_country (
    id serial PRIMARY KEY, -- Уникальный идентификатор страны производителя
    country_name VARCHAR(50) UNIQUE NOT NULL -- Название страны производителя (уникальное)
);

CREATE TABLE car_shop.brand (
    id serial PRIMARY KEY, -- Уникальный идентификатор бренда
    id_country INT, -- Внешний ключ для связи с справочником стран
    name_brand VARCHAR(50) NOT NULL CHECK (name_brand NOT LIKE ''), -- Название бренда (не пустое)
    FOREIGN KEY (id_country) REFERENCES car_shop.spr_country(id) -- Связь с справочником стран
);

CREATE TABLE car_shop.model (
    id serial PRIMARY KEY, -- Уникальный идентификатор модели
    id_brand INT, -- Внешний ключ для связи с брендом
    name_model VARCHAR(50) NOT NULL, -- Название модели (не пустое)
    gasoline_consumption DECIMAL(3,1) CHECK (gasoline_consumption >= 0 AND gasoline_consumption <= 99.9) DEFAULT NULL, -- Расход бензина с проверкой и дефолтным значением NULL
    FOREIGN KEY (id_brand) REFERENCES car_shop.brand(id) -- Связь с брендом
);

CREATE TABLE car_shop.sett (
    id serial PRIMARY KEY, -- Уникальный идентификатор комплектации
    id_model INT, -- Внешний ключ для связи с моделью
    color VARCHAR(50) NOT NULL, -- Цвет комплектации
    FOREIGN KEY (id_model) REFERENCES car_shop.model(id) -- Связь с моделью
);

CREATE TABLE car_shop.sale (
    id serial PRIMARY KEY, -- Уникальный идентификатор продажи
    id_person INT, -- Внешний ключ для связи с покупателем
    id_sett INT, -- Внешний ключ для связи с комплектацией
    price DECIMAL(19,12) NOT NULL CHECK (price >= 0 AND price < 9999999.999999999999), -- Цена продажи с проверкой
    discount DECIMAL(4,2) CHECK (discount >= 0 AND discount <= 99.99), -- Скидка с проверкой
    date DATE, -- Дата продажи
    FOREIGN KEY (id_sett) REFERENCES car_shop.sett(id), -- Связь с комплектацией
    FOREIGN KEY (id_person) REFERENCES car_shop.person(id) -- Связь с покупателем
);

-- Заполнение таблиц данными

-- Заполнение таблицы person данными из sales
INSERT INTO car_shop.person (person_name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;

-- Заполнение таблицы spr_country данными из sales
INSERT INTO car_shop.spr_country (country_name)
SELECT DISTINCT brand_origin
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;

-- Заполнение таблицы brand данными из sales
INSERT INTO car_shop.brand (id_country, name_brand)
SELECT car_shop.spr_country.id, SPLIT_PART(raw_data.sales.auto, ' ', 1)
FROM car_shop.spr_country
 RIGHT JOIN raw_data.sales ON car_shop.spr_country.country_name = raw_data.sales.brand_origin
GROUP BY SPLIT_PART(raw_data.sales.auto, ' ', 1), car_shop.spr_country.id;

-- Заполнение таблицы model данными из sales
INSERT INTO car_shop.model (id_brand, name_model, gasoline_consumption)
SELECT car_shop.brand.id,  SUBSTRING(raw_data.sales.auto FROM POSITION(' ' IN raw_data.sales.auto) + 1 FOR POSITION(',' IN raw_data.sales.auto) - POSITION(' ' IN raw_data.sales.auto) - 1), gasoline_consumption
FROM car_shop.brand
 RIGHT JOIN raw_data.sales ON car_shop.brand.name_brand  = SPLIT_PART(raw_data.sales.auto, ' ', 1)
GROUP BY  SUBSTRING(raw_data.sales.auto FROM POSITION(' ' IN raw_data.sales.auto) + 1 FOR POSITION(',' IN raw_data.sales.auto) - POSITION(' ' IN raw_data.sales.auto) - 1), car_shop.brand.id, gasoline_consumption;

-- Заполнение таблицы sett данными из sales
INSERT INTO car_shop.sett (id_model, color)
SELECT car_shop.model.id, SPLIT_PART(raw_data.sales.auto, ', ', 2)
FROM car_shop.model
 RIGHT JOIN raw_data.sales ON car_shop.model.name_model  = SUBSTRING(raw_data.sales.auto FROM POSITION(' ' IN raw_data.sales.auto) + 1 FOR POSITION(',' IN raw_data.sales.auto) - POSITION(' ' IN raw_data.sales.auto) - 1)
GROUP BY  car_shop.model.id, SPLIT_PART(raw_data.sales.auto, ', ', 2);

--ПЕРЕДЕЛАТЬ ВСТАВКУ
INSERT INTO car_shop.sale  (id_person, id_sett, price, discount, date)
SELECT car_shop.person.id  , car_shop.sett.id, raw_data.sales.price , raw_data.sales.discount , raw_data.sales."date"
from raw_data.sales join car_shop.person on raw_data.sales.phone  = car_shop.person.phone
join car_shop.sett on split_part(raw_data.sales.auto, ', ', 2) = car_shop.sett.color
join car_shop.model on car_shop.model.id = car_shop.sett.id_model
join car_shop.brand on car_shop.brand.id = car_shop.model.id_brand
where split_part(raw_data.sales.auto, ', ', 2) = car_shop.sett.color and car_shop.sett.id_model = car_shop.model.id and car_shop.model.name_model = SUBSTRING(raw_data.sales.auto FROM POSITION(' ' IN raw_data.sales.auto) + 1 FOR POSITION(',' IN raw_data.sales.auto) - POSITION(' ' IN raw_data.sales.auto) - 1)
;
--1
-- Расчет процента моделей с нулевым значением gasoline_consumption
SELECT
    (COUNT(*) * 100.0 / (SELECT COUNT(*)
    FROM car_shop.model
        JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
        JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id)) AS nulls_percentage_gasoline_consumption
FROM car_shop.model
JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id
WHERE gasoline_consumption IS NULL;

-- Проверка количества автомобилей с нулевым gasoline_consumption в сырых данных
SELECT COUNT(*)
FROM raw_data.sales
WHERE gasoline_consumption IS NULL;

--2
-- Средняя цена автомобилей по брендам и годам
SELECT
    name_brand AS brand_name,
    TO_CHAR(date, 'YYYY') AS year,
    ROUND(AVG(price), 2) AS price_avg
FROM car_shop.brand
JOIN car_shop.model ON car_shop.brand.id = car_shop.model.id_brand
JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id
GROUP BY name_brand, TO_CHAR(date, 'YYYY')
ORDER BY name_brand ASC, year;

--3
-- Средняя цена автомобилей по брендам за каждый месяц в 2022 году
SELECT
    TO_CHAR(date, 'mm') AS month,
    TO_CHAR(date, 'yyyy') AS year,
    ROUND(AVG(price), 2) AS price_avg
FROM car_shop.brand
JOIN car_shop.model ON car_shop.brand.id = car_shop.model.id_brand
JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id
WHERE TO_CHAR(date, 'YYYY') = '2022'
GROUP BY TO_CHAR(date, 'mm'), TO_CHAR(date, 'yyyy')
ORDER BY TO_CHAR(date, 'mm') ASC;

--4
-- Список автомобилей, купленных каждым клиентом
SELECT
    car_shop.person.person_name AS person,
    STRING_AGG(CONCAT(car_shop.brand.name_brand, ' ', car_shop.model.name_model), ', ') AS cars
FROM car_shop.sale
JOIN car_shop.person ON car_shop.sale.id_person = car_shop.person.id
JOIN car_shop.sett ON car_shop.sett.id = car_shop.sale.id_sett
JOIN car_shop.model ON car_shop.model.id = car_shop.sett.id_model
JOIN car_shop.brand ON car_shop.model.id_brand = car_shop.brand.id
GROUP BY car_shop.person.person_name
ORDER BY car_shop.person.person_name;

--5
-- Сравнение минимальной и максимальной цены автомобилей с учетом скидок по странам
SELECT
    car_shop.spr_country.country_name,
    min_price.price_min + (min_price.price_min * car_shop.sale.discount / 100) AS price_min,
    max_price.price_max + (max_price.price_max * car_shop.sale.discount / 100) AS price_max
FROM car_shop.sale
JOIN car_shop.sett ON car_shop.sett.id = car_shop.sale.id_sett
JOIN car_shop.model ON car_shop.model.id = car_shop.sett.id_model
JOIN car_shop.brand ON car_shop.model.id_brand = car_shop.brand.id
JOIN car_shop.spr_country ON car_shop.spr_country.id = car_shop.brand.id_country
JOIN (
    SELECT
        car_shop.brand.id_country AS country_id,
        MIN(car_shop.sale.price) AS price_min
    FROM car_shop.sale
    JOIN car_shop.sett ON car_shop.sett.id = car_shop.sale.id_sett
    JOIN car_shop.model ON car_shop.model.id = car_shop.sett.id_model
    JOIN car_shop.brand ON car_shop.model.id_brand = car_shop.brand.id
    GROUP BY car_shop.brand.id_country
) min_price ON min_price.country_id = car_shop.brand.id_country AND min_price.price_min = car_shop.sale.price
JOIN (
    SELECT
        car_shop.brand.id_country AS country_id,
        MAX(car_shop.sale.price) AS price_max
    FROM car_shop.sale
    JOIN car_shop.sett ON car_shop.sett.id = car_shop.sale.id_sett
    JOIN car_shop.model ON car_shop.model.id = car_shop.sett.id_model
    JOIN car_shop.brand ON car_shop.model.id_brand = car_shop.brand.id
    GROUP BY car_shop.brand.id_country
) max_price ON max_price.country_id = car_shop.brand.id_country
WHERE car_shop.spr_country.country_name IS NOT NULL;

--6
-- Количество клиентов с номерами телефонов, начинающихся с +1
SELECT COUNT(car_shop.person.person_name) AS persons_from_usa_count
FROM car_shop.sale
JOIN car_shop.person ON car_shop.sale.id_person = car_shop.person.id AND car_shop.person.phone LIKE '+1%';
