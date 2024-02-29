create schema raw_data;
--создание таблицы с переменнми и ПК
create table raw_data.sales (
	id int primary key not null,
	auto varchar(50) not null,
	gasoline_consumption float,
	price decimal not null,
	date date not null,
	person_name varchar(50) not null,
	phone varchar(50) not null,
	discount float not null,
	brand_origin varchar(15) 
);

--копирование данных и файла
COPY raw_data.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
FROM 'D:\Web_Git_Labs\Lab-1_DB_and_legacy\cars.csv' WITH CSV HEADER NULL 'null';


-- Сырье
create schema car_shop;

create table car_shop.country
(
  id_country serial primary key,
  name varchar(30) unique not null
);

create table car_shop.color 
(
  id_color serial primary key,
  name varchar (30) unique not null
);

create table car_shop.client
(
  id_client serial primary key,
  name varchar(30) not null,
  phone varchar(30)
);

create table car_shop.brand
(
  id_brand serial primary key,
  name varchar(30) unique not null,
  country_manufacturer_id integer,
  foreign key (country_manufacturer_id) references car_shop.country(id_country) on delete restrict
);

create table car_shop.model
(
  id_model serial primary key,
  brand_id integer,
  name varchar(30) not null,
  foreign key (brand_id) references car_shop.Brand(id_brand) on delete restrict
);

create table car_shop.equipment
(
  id_equipment serial primary key,
  model_id integer,
  color_id integer,
  gas_consumption numeric(4, 1) check (gas_consumption > 0),
  foreign key (color_id) references car_shop.color(id_color) on delete restrict,
  foreign key (model_id) references car_shop.model(id_model) on delete restrict
);

create table car_shop.sales 
(
  id_sales serial primary key,
  equipment_id integer,
  client_id integer,
  price numeric (10, 2) check (price >=0),
  discount integer check (discount between 0 and 100),
  sale_date date,
  foreign key (equipment_id) references car_shop.equipment (id_equipment) on delete restrict,
  foreign key (client_id) references car_shop.client (id_client) on delete restrict
);


-- Заполнение таблиц

--Страна
insert into car_shop.country (name)
select distinct brand_origin
from raw_data.sales 
where brand_origin is not null;

--Цвет
insert into car_shop.color (name)
select distinct split_part(auto, ', ', 2)
from raw_data.sales;

--Покупатель
insert into car_shop.client (name, phone)
select distinct person_name, phone 
from raw_data.sales;

--Бренд
insert into car_shop.brand (name, country_manufacturer_id)
select distinct
	split_part(split_part(s.auto, ',', 1), ' ', 1),
	c.id_country 
from raw_data.sales s
left join car_shop.country c on c."name" = s.brand_origin;


--Модель
insert into car_shop.model (brand_id, name)
 select distinct 
    b.id_brand,
    split_part(split_part(s.auto, ',', 1), ' ', 2)
from 
  raw_data.sales s
inner join car_shop.brand b on b.name = split_part(split_part(s.auto, ',', 1), ' ', 1);


--Комплектация
--insert into car_shop.equipment (model_id, color_id, gas_consumption)
select distinct
    m.id_model,
    c.id_color,
    s.gasoline_consumption
from
    raw_data.sales s
left join car_shop.model m on TRIM(m."name") = trim(split_part( split_part(s.auto, ',', 1), ' ', 2))
inner join car_shop.brand b on b.id_brand = m.brand_id and b."name" = trim(split_part( split_part(s.auto, ',', 1), ' ', 1))
inner join car_shop.color c on c."name" = trim(split_part(s.auto, ',', 2));


--Продажа

INSERT INTO sales (equipment_id, client_id, price, discount, sale_date)
SELECT
    sub_query.id_equipment,
    c.id_client,
    s.price,
    s.discount,
    s."date"
from raw_data.sales s
left join (
	select
	    e.id_equipment,
		m.name as model,
		b.name as brand,
		COALESCE(c.name, 'Unknown') as country,
		col.name as color
	from car_shop.equipment e
	inner join car_shop.color col on col.id_color = e.color_id
	inner join car_shop.model m on m.id_model = e.model_id
	inner join car_shop.brand b on b.id_brand = m.brand_id
	left join car_shop.country c on c.id_country = b.country_manufacturer_id 
) as sub_query on
sub_query.brand = trim(split_part( split_part(s.auto, ',', 1), ' ', 1)) and
sub_query.model = trim(split_part( split_part(s.auto, ',', 1), ' ', 2)) and
sub_query.color = trim(split_part(s.auto, ',', 2)) and
sub_query.country = COALESCE(s.brand_origin, 'Unknown') 
inner join car_shop.client c on c.name = s.person_name;

-- Задание 1 

SELECT
    100.0 * COUNT(*) / (SELECT COUNT(*) FROM car_shop.model) AS percentage
FROM
    car_shop.model m
WHERE
    NOT EXISTS (
        SELECT 1
        FROM car_shop.equipment e
        WHERE e.model_id = m.id_model AND e.gas_consumption IS NOT NULL
    );


  -- Задание 2
   
   SELECT
    b.name AS brand_name,
    EXTRACT(YEAR FROM s.sale_date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM
    car_shop.brand b
    JOIN car_shop.model m ON b.id_brand = m.brand_id
    JOIN car_shop.equipment e ON m.id_model = e.model_id
    JOIN car_shop.sales s ON e.id_equipment = s.equipment_id
GROUP BY
    b.name, EXTRACT(YEAR FROM s.sale_date)
ORDER BY
    b.name, EXTRACT(YEAR FROM s.sale_date);
   
   
   -- Задание 3
   
   SELECT
    EXTRACT(MONTH FROM s.sale_date) AS month,
    EXTRACT(YEAR FROM s.sale_date) AS year,
    ROUND(AVG(s.price * (1 - s.discount / 100.0)), 2) AS price_avg
FROM
    car_shop.sales s
WHERE
    EXTRACT(YEAR FROM s.sale_date) = 2022
GROUP BY
    EXTRACT(MONTH FROM s.sale_date), EXTRACT(YEAR FROM s.sale_date)
ORDER BY
    EXTRACT(MONTH FROM s.sale_date);

   
   -- Задание 4

   SELECT
    c.name AS person,
    STRING_AGG(b.name || ' ' || m.name, ', ') AS cars
FROM
    car_shop.client c
    JOIN car_shop.sales s ON c.id_client = s.client_id
    JOIN car_shop.equipment e ON s.equipment_id = e.id_equipment
    JOIN car_shop.model m ON e.model_id = m.id_model
    JOIN car_shop.brand b ON m.brand_id = b.id_brand
GROUP BY
    c.name
ORDER BY
    c.name;
   
   
   -- Задание 5
   
   SELECT
    b.country_manufacturer_id AS brand_origin,
    MAX(s.price / (1 - s.discount / 100.0)) AS price_max,
    MIN(s.price / (1 - s.discount / 100.0)) AS price_min
FROM
    car_shop.sales s
    JOIN car_shop.equipment e ON s.equipment_id = e.id_equipment
    JOIN car_shop.model m ON e.model_id = m.id_model
    JOIN car_shop.brand b ON m.brand_id = b.id_brand
GROUP BY
    b.country_manufacturer_id
ORDER BY
    b.country_manufacturer_id;

   
 -- Задание 6
   
   SELECT
    COUNT(*) AS persons_from_usa_count
FROM
    car_shop.client c
WHERE
    c.phone LIKE '+1%';


