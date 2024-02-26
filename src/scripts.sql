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

CREATE TABLE car_shop.persons ( -- таблица клиентов
  person_id SERIAL PRIMARY KEY, -- первичный ключ
  person_name VARCHAR(100), -- символьный тип для имени
  phone VARCHAR(25) -- символьный тип для телефона
);

CREATE TABLE car_shop.colors ( -- таблица цветов
  id SERIAL PRIMARY KEY, -- первичный ключ
  color VARCHAR(20) -- символьный тип для названия цвета
);

CREATE TABLE car_shop.country ( -- таблица стран
  country_id SERIAL PRIMARY KEY, -- первичный ключ
  country_name VARCHAR(20) -- символьный тип для названия страны
);

CREATE TABLE car_shop.models_list ( -- таблица моделей
  model_id SERIAL PRIMARY KEY, -- первичный ключ
  model VARCHAR(15), -- символьный тип для названия модели
);

CREATE TABLE car_shop.brands ( -- таблица брендов
  brand_id SERIAL PRIMARY KEY, -- первичный ключ
  brand_name VARCHAR(20),  -- символьный тип для названия бренда
  brand_country_id INTEGER, -- целочисленный тип для внешнего ключа страны бренда
  constraint fk_brand_country_id foreign key (brand_country_id) REFERENCES country (country_id)
);

CREATE TABLE car_shop.cars ( -- таблица машин
  car_id SERIAL PRIMARY KEY, --  первичный ключ
  model_list_id INTEGER, -- целочисленный тип для внешнего ключа моделей
  brand_id INTEGER, -- целочисленный тип для внешнего ключа бренда
  CONSTRAINT fk_model_id FOREIGN KEY (model_list_id) REFERENCES models_list (model_id),
  CONSTRAINT fk_brand_id FOREIGN KEY (brand_id) REFERENCES brands (brand_id)
);

CREATE TABLE car_shop.cars_eque ( -- таблица комплектаций машин
  car_eque_id SERIAL PRIMARY KEY,  --  первичный ключ
  car_id INTEGER,  -- целочисленный тип для внешнего ключа машины
  color_id INTEGER, -- целочисленный тип для внешнего ключа цветов
  gasoline_consumption float4, -- вещественный тип для расхода топлива
  CONSTRAINT fk_car_id FOREIGN KEY (car_id) REFERENCES cars (car_id),
  CONSTRAINT fk_color FOREIGN KEY (color_id) REFERENCES colors (id)
);

CREATE TABLE car_shop.sales ( -- таблица продаж
  sales_id SERIAL PRIMARY KEY, -- первиычный ключ
  sold_car_id INTEGER, -- целочисленный тип для внешнего ключа машин
  price NUMERIC(7, 2), -- числовой тип для хранения цены
  discount INTEGER, -- целочисленный тип для скидки
  date DATE, -- тип даты для даты
  person_id INTEGER, -- целочисленный тип для внешнего ключа клиента
  CONSTRAINT fk_sold_car_id FOREIGN KEY (sold_car_id) REFERENCES cars (car_id),
  CONSTRAINT fk_person_id FOREIGN KEY (person_id) REFERENCES persons (person_id)
);

INSERT INTO car_shop.persons (person_name, phone) -- заполняем таблицу клиентов
SELECT DISTINCT person, phone
FROM raw_data.sales;

INSERT INTO car_shop.country (country_name) -- заполняем таблицу стран
select DISTINCT brand_origin
FROM raw_data.sales
where brand_origin is not null;

INSERT INTO car_shop.colors (color) -- заполняем таблицу цветов машин
SELECT DISTINCT split_part(substring(auto from '[^,]+$'), ' ', 2) AS color
FROM raw_data.sales;

INSERT INTO car_shop.models_list (model, gasoline_consumption) -- заполняем таблицу моделей машин
SELECT DISTINCT substring(auto from '\w+\s(.*?),') AS model
FROM raw_data.sales;

INSERT INTO car_shop.brands (brand_name, brand_country_id)  -- заполняем таблицу брендов
SELECT
	DISTINCT split_part(auto, ' ', 1) AS brand_name,
	(SELECT country_id FROM country WHERE country_name = s.brand_origin)
FROM raw_data.sales s;

INSERT INTO car_shop.cars (brand_id, model_list_id)  -- заполняем таблицу машин
select DISTINCT
    (SELECT brand_id FROM brands WHERE brand_name = split_part(auto, ' ', 1)),
    (SELECT model_id FROM models_list WHERE model = substring(auto from '\w+\s(.*?),'))
FROM
    raw_data.sales s;

INSERT INTO car_shop.cars_eque (car_id, color_id, gasoline_consumption) -- заполняем таблицу комплектаций машин
select DISTINCT
    (SELECT car_id FROM cars ca
    	inner join car_shop.brands br ON ca.brand_id = br.brand_id
    	inner join car_shop.models_list ml ON ca.model_list_id = ml.model_id
    	WHERE br.brand_name = split_part(s.auto, ' ', 1)
    	AND ml.model = substring(auto from '\w+\s(.*?),')),
    (SELECT id FROM colors WHERE color = split_part(substring(auto from '[^,]+$'), ' ', 2)),
    gasoline_consumption
FROM
    raw_data.sales s;

INSERT INTO car_shop.sales (sold_car_id, price, discount, date, person_id) -- заполняем таблицу продаж
select
	(select car_eque_id from cars_eque eq
		inner join car_shop.colors cl ON eq.color_id = cl.id
		inner join car_shop.cars ca ON eq.car_id = ca.car_id
		inner join car_shop.brands br ON ca.brand_id = br.brand_id
    	inner join car_shop.models_list ml ON ca.model_list_id = ml.model_id
    	WHERE br.brand_name = split_part(s.auto, ' ', 1)
    	and ml.model = substring(auto from '\w+\s(.*?),')
    	and cl.color = split_part(substring(auto from '[^,]+$'), ' ', 2)),
	s.price,
	s.discount,
	s.date,
	(SELECT person_id FROM persons WHERE
		persons.person_name = s.person)
FROM
    raw_data.sales s;

-- заполнение выполнено, можно начинать аналитические скрипты (─‿‿─)
-- сприпт 1:
SELECT
    (COUNT(model_id) FILTER (WHERE gasoline_consumption IS NULL) * 100 / COUNT(model_id)) AS percent
FROM
    car_shop.cars_eque eq
    inner join car_shop.cars ca ON eq.car_id = ca.car_id
    inner join car_shop.models_list ml ON ca.model_list_id = ml.model_id;

-- сприпт 2:
SELECT
    brand_name,
    EXTRACT(year FROM date) AS year,
    ROUND(AVG(price)::numeric, 2) AS price_avg
from car_shop.sales, car_shop.cars_eque eq
	inner join car_shop.cars ca ON eq.car_id = ca.car_id
	inner join car_shop.brands br ON ca.brand_id = br.brand_id
GROUP by brand_name, year
ORDER by brand_name, year ASC;

-- сприпт 3:
SELECT
    EXTRACT(month FROM date) AS month,
    EXTRACT(year FROM date) AS year,
    ROUND(AVG(price)::numeric, 2) AS price_avg
from car_shop.sales
where EXTRACT(year FROM date) = 2022
GROUP by month, year
order by month ASC;

-- сприпт 4:
SELECT p.person_name AS person,
STRING_AGG(b.brand_name || ' ' || m.model, ', ') AS cars
FROM sales s
JOIN cars_eque ce ON s.sold_car_id = ce.car_eque_id
JOIN cars c ON ce.car_id = c.car_id
JOIN models_list m ON c.model_list_id = m.model_id
JOIN brands b ON c.brand_id = b.brand_id
JOIN persons p ON s.person_id = p.person_id
GROUP BY p.person_name
ORDER BY p.person_name;

-- сприпт 5:
SELECT
	co.country_name as brand_origin,
	MAX(s.price + (s.price * s.discount / 100)) AS price_max,
	MIN(s.price + (s.price * s.discount / 100)) AS price_min
FROM sales s
JOIN cars_eque eq ON s.sold_car_id = eq.car_eque_id
JOIN cars c ON eq.car_id = c.car_id
JOIN brands b ON c.brand_id = b.brand_id
JOIN country co ON b.brand_country_id = co.country_id
GROUP BY co.country_name
ORDER BY co.country_name ASC;

-- сприпт 6:
SELECT COUNT(person_id) AS persons_from_usa_count
FROM persons
WHERE phone LIKE '+1%';