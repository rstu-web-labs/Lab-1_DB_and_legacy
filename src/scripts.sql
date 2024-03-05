CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id INTEGER,
    auto VARCHAR(100),
    gasoline_consumption float4,
    price NUMERIC(7, 2),
    date DATE,
    person VARCHAR(100),
    phone VARCHAR(25),
    discount INTEGER,
    brand_origin VARCHAR(50)
);

COPY raw_data.sales FROM '/data/cars.csv' WITH CSV HEADER NULL 'null';

CREATE SCHEMA car_shop;

CREATE TABLE car_shop.persons (  -- таблица клиентов
  person_id SERIAL PRIMARY KEY,  -- первичный ключ
  person_name VARCHAR(100),  -- символьный тип для имени
  phone VARCHAR(25) UNIQUE  -- символьный тип для телефона
);

CREATE TABLE car_shop.colors (  -- таблица цветов
  id SERIAL PRIMARY KEY, -- первичный ключ
  color VARCHAR(30) UNIQUE -- символьный тип для названия цвета
);

CREATE TABLE car_shop.country (  -- таблица стран
  country_id SERIAL PRIMARY KEY,  -- первичный ключ
  country_name VARCHAR(70) UNIQUE  -- символьный тип для названия страны
);

CREATE TABLE car_shop.brands (  -- таблица брендов
  brand_id SERIAL PRIMARY KEY,  -- первичный ключ
  brand_name VARCHAR(20) UNIQUE, -- символьный тип для названия бренда
  brand_country_id INTEGER,  -- целочисленный тип для внешнего ключа страны бренда
  constraint fk_brand_country_id foreign key (brand_country_id) REFERENCES car_shop.country (country_id) ON DELETE SET NULL
);

CREATE TABLE car_shop.models_list (  -- таблица моделей
  model_id SERIAL PRIMARY KEY,  -- первичный ключ
  model VARCHAR(15) unique,  -- символьный тип для названия модели
  brand_id INTEGER,  -- целочисленный тип для внешнего ключа бренда
  gasoline_consumption DECIMAL(5, 2), -- вещественный тип для расхода топлива
  CONSTRAINT fk_brand_id FOREIGN KEY (brand_id) REFERENCES car_shop.brands (brand_id) ON DELETE SET NULL
);

CREATE TABLE car_shop.cars (  -- таблица машин
  car_id SERIAL PRIMARY KEY,  -- первичный ключ
  model_list_id INTEGER,  -- целочисленный тип для внешнего ключа моделей
  color_id INTEGER,  -- целочисленный тип для внешнего ключа цветов
  CONSTRAINT fk_model_id FOREIGN KEY (model_list_id) REFERENCES car_shop.models_list (model_id)ON DELETE SET NULL,
  CONSTRAINT fk_color FOREIGN KEY (color_id) REFERENCES car_shop.colors (id) ON DELETE SET NULL
);

CREATE TABLE car_shop.sales (  -- таблица продаж
  sales_id SERIAL PRIMARY KEY,  -- первичный ключ
  sold_car_id INTEGER,  -- целочисленный тип для внешнего ключа машин
  price NUMERIC(7, 2),  -- числовой тип для хранения цены
  discount NUMERIC(4, 2),  -- числовой тип для скидки
  date DATE,  -- тип даты для даты
  person_id INTEGER,  -- целочисленный тип для внешнего ключа клиента
  CONSTRAINT fk_sold_car_id FOREIGN KEY (sold_car_id) REFERENCES car_shop.cars (car_id) ON DELETE NO ACTION,
  CONSTRAINT fk_person_id FOREIGN KEY (person_id) REFERENCES car_shop.persons (person_id) ON DELETE SET NULL
);

INSERT INTO car_shop.persons (person_name, phone) -- заполняем таблицу клиентов
SELECT DISTINCT person, phone
FROM raw_data.sales;

INSERT INTO car_shop.country (country_name) -- заполняем таблицу стран
select DISTINCT brand_origin
FROM raw_data.sales
where brand_origin is not null;

INSERT INTO car_shop.colors (color) -- заполняем таблицу цветов машин
SELECT DISTINCT split_part(substring(s.auto from '[^,]+$'), ' ', 2) AS color
FROM raw_data.sales s;

INSERT INTO car_shop.brands (brand_name, brand_country_id)  -- заполняем таблицу брендов
SELECT
	DISTINCT split_part(s.auto, ' ', 1) AS brand_name,
	(SELECT country_id FROM car_shop.country WHERE country_name = s.brand_origin)
FROM raw_data.sales s;

INSERT INTO car_shop.models_list (model, brand_id, gasoline_consumption) -- заполняем таблицу моделей машин
SELECT DISTINCT
    substring(s.auto from '\w+\s(.*?),') AS model,
    (SELECT brand_id FROM car_shop.brands WHERE brand_name = split_part(auto, ' ', 1)),
    gasoline_consumption
FROM raw_data.sales s;

INSERT INTO car_shop.cars (model_list_id, color_id)  -- заполняем таблицу машин
select DISTINCT
    (SELECT model_id FROM car_shop.models_list WHERE model = substring(s.auto from '\w+\s(.*?),')),
    (SELECT id FROM car_shop.colors WHERE color = split_part(substring(s.auto from '[^,]+$'), ' ', 2))
FROM
    raw_data.sales s;

INSERT INTO car_shop.sales (sold_car_id, price, discount, date, person_id) -- заполняем таблицу продаж
select
	(select car_id from car_shop.cars ca
		inner join car_shop.colors cl ON ca.color_id = cl.id
    	inner join car_shop.models_list ml ON ca.model_list_id = ml.model_id
    	WHERE ml.model = substring(s.auto from '\w+\s(.*?),')
    	and cl.color = split_part(substring(s.auto from '[^,]+$'), ' ', 2)),
	s.price,
	s.discount,
	s.date,
	(SELECT person_id FROM car_shop.persons WHERE
		persons.person_name = s.person)
FROM
    raw_data.sales s;

-- заполнение выполнено, можно начинать аналитические скрипты (─‿‿─)
-- сприпт 1:
SELECT
    (COUNT(ml.model_id) FILTER (WHERE ml.gasoline_consumption IS NULL) * 100 / COUNT(ml.model_id)) AS percent
FROM
    car_shop.models_list ml;

-- сприпт 2:
SELECT
    br.brand_name,
    EXTRACT(year FROM date) AS year,
    ROUND(AVG(price)::numeric, 2) AS price_avg
from car_shop.sales, car_shop.cars ca
	inner join car_shop.models_list ml ON ca.model_list_id = ml.model_id
	inner join car_shop.brands br ON ml.brand_id = br.brand_id
GROUP by br.brand_name, year
ORDER by br.brand_name, year ASC;

-- сприпт 3:
SELECT
    EXTRACT(month FROM date) AS month,
    EXTRACT(year FROM date) AS year,
    ROUND(AVG(s.price)::numeric, 2) AS price_avg
from car_shop.sales s
where EXTRACT(year FROM date) = 2022
GROUP by month, year
order by month ASC;

-- сприпт 4:
SELECT p.person_name AS person,
STRING_AGG(br.brand_name || ' ' || m.model, ', ') AS cars
FROM car_shop.sales s
JOIN car_shop.cars c ON s.sold_car_id = c.car_id
JOIN car_shop.models_list m ON c.model_list_id = m.model_id
join car_shop.brands br ON m.brand_id = br.brand_id
JOIN car_shop.persons p ON s.person_id = p.person_id
GROUP BY p.person_name
ORDER BY p.person_name;

-- сприпт 5:
SELECT
	co.country_name as brand_origin,
	MAX(s.price + (s.price * s.discount / 100)) AS price_max,
	MIN(s.price + (s.price * s.discount / 100)) AS price_min
FROM car_shop.sales s
JOIN car_shop.cars c ON s.sold_car_id = c.car_id
JOIN car_shop.models_list m ON c.model_list_id = m.model_id
join car_shop.brands br ON m.brand_id = br.brand_id
JOIN car_shop.country co ON br.brand_country_id = co.country_id
GROUP BY co.country_name
ORDER BY co.country_name ASC;

-- сприпт 6:
SELECT COUNT(p.person_id) AS persons_from_usa_count
FROM car_shop.persons p
WHERE p.phone LIKE '+1%';