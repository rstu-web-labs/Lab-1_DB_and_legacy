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
  gasoline_consumption float4 -- вещественный тип для расхода топлива
);


CREATE TABLE car_shop.cars ( -- таблица машин
  car_id SERIAL PRIMARY KEY, --  первичный ключ
  brand_name VARCHAR(30), -- символьный тип для имени бренда
  model_list_id INTEGER, -- целочисленный тип для внешнего ключа моделей
  brand_original_id INTEGER, -- целочисленный тип для внешнего ключа стран
  color_id INTEGER, -- целочисленный тип для внешнего ключа цветов
  CONSTRAINT fk_model_id FOREIGN KEY (model_list_id) REFERENCES models_list (model_id),
  CONSTRAINT fk_brand_original FOREIGN KEY (brand_original_id) REFERENCES country (country_id),
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
SELECT DISTINCT substring(auto from '\w+\s(.*?),') AS model, gasoline_consumption
FROM raw_data.sales;

INSERT INTO car_shop.cars (brand_name, model_list_id, brand_original_id, color_id) -- крестимся и заполняем таблицу машин
SELECT
    distinct split_part(auto, ' ', 1) AS brand_name,
    (SELECT model_id FROM models_list WHERE model = substring(auto from '\w+\s(.*?),')),
    (SELECT country_id FROM country WHERE country_name = s.brand_origin),
    (SELECT id FROM colors WHERE color = split_part(substring(auto from '[^,]+$'), ' ', 2))
FROM
    raw_data.sales s;

INSERT INTO car_shop.sales (price, discount, date, person_id) -- заполняем таблицу продаж
select
	s.price,
	s.discount,
	s.date,
	(SELECT person_id FROM persons WHERE
		persons.person_name = s.person)
FROM
    raw_data.sales s;

UPDATE car_shop.sales SET sold_car_id = ( -- всё ещё заполняем таблицу продаж, но теперь только id проданной машины
    SELECT c.car_id
    FROM car_shop.cars c
    JOIN car_shop.models_list ml ON c.model_list_id = ml.model_id
    JOIN car_shop.colors cl ON c.color_id = cl.id
    WHERE c.brand_name = split_part(auto, ' ', 1)
    AND ml.model = substring(auto from '\w+\s(.*?),')
    AND cl.color = split_part(substring(auto from '[^,]+$'), ' ', 2)
)
FROM raw_data.sales
WHERE car_shop.sales.sales_id = raw_data.sales.id;
-- заполнение выполнено, можно начинать аналитические скрипты (─‿‿─)
-- сприпт 1:
SELECT
    (COUNT(model_id) FILTER (WHERE gasoline_consumption IS NULL) * 100 / COUNT(model_id)) AS percent
FROM
    models_list;

-- сприпт 2:
SELECT
    brand_name,
    EXTRACT(year FROM date) AS year,
    ROUND(AVG(price)::numeric, 2) AS price_avg
from car_shop.sales, car_shop.cars
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
CREATE OR REPLACE VIEW car_shop.person_auto_view AS -- создаём вьюшку и радуемся
SELECT s.sold_car_id, c.brand_name, m.model, p.person_name
FROM car_shop.sales s
JOIN cars c ON s.sold_car_id = c.car_id
JOIN models_list m ON c.model_list_id = m.model_id
join persons p on s.person_id = p.person_id;

select person_name as person,
STRING_AGG(CONCAT(brand_name, ' ', model), ', ') AS cars
FROM person_auto_view pa
GROUP BY person
ORDER BY person ASC;

-- сприпт 5:  Тут я не захотел делать вьюшку
SELECT
	co.country_name as brand_origin,
	MAX(s.price + (s.price * s.discount / 100)) AS price_max,
	MIN(s.price + (s.price * s.discount / 100)) AS price_min
FROM car_shop.sales s
JOIN cars c ON s.sold_car_id = c.car_id
JOIN country co ON c.brand_original_id = co.country_id
GROUP BY co.country_name
ORDER BY co.country_name ASC;

-- сприпт 6:
SELECT COUNT(person_id) AS persons_from_usa_count
FROM persons
WHERE phone LIKE '+1%';