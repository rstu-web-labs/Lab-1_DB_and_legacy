--Создание базы даннх
create database life_on_wheels;

--Схема для сырых данных
create schema raw_data;

--Схема для нормализованных таблиц
create schema car_shop;

--Создание таблицы с сырыми данными 

create table raw_data.sales (
	id int primary key,
	auto varchar(50),
	gasoline_consumption decimal,
	price decimal,
	date date,
	person_name varchar(30),
	phone varchar(30),
	discount int,
	brand_origin text
);

--СОЗДАНИЕ

--создание таблицы страна производства

CREATE TABLE car_shop.country (
  id_brand_origin serial primary key not null,
  name_country varchar(39)
);

--создание таблицы покупатель

CREATE TABLE car_shop.person (
  id_person serial primary key not null,
  name_person varchar(40) not null,
  surname_person varchar(40) not null,
  phone_person varchar(40) not null
);

--создание таблицы цвет

create table car_shop.color (
	id_color serial primary key not null,
	color varchar(50) unique not null
);


--создание таблицы бренд
create table car_shop.brand (
	id_brand serial primary key not null,
	id_country integer unique references car_shop.country (id_brand_origin)
	on update cascade
	on delete restrict,
	brand_name varchar(30) unique not null
);


--создание таблицы модель
create table car_shop.model (
	id_model serial primary key not null,
	id_brand integer references car_shop.brand (id_brand)
	on update cascade
	on delete restrict,
	model varchar(30) not null,
	gasoline_consumtion decimal (5,2)
);


--создание таблицы авто
create table car_shop.auto (
	id_auto serial primary key not null,
	id_model integer references car_shop.model (id_model)
	on update cascade
	on delete restrict,
	id_color integer references car_shop.color (id_color)
	on update cascade
	on delete restrict
);

--создание таблицы сделка
create table car_shop.transaction (
	id_transaction serial primary key not null,
	price decimal (10,2) not null,
	data_transaction date not null,
	discount decimal (3,1)
);


--создание таблицы продажи
create table car_shop.sale (
	id_sale serial primary key not null,
	id_transaction integer references car_shop.transaction (id_transaction)
	on update cascade
	on delete restrict,
	id_auto integer references car_shop.auto (id_auto)
	on update cascade
	on delete restrict,
	id_person integer references car_shop.person (id_person)
	on update cascade
	on delete restrict
);


--копирование данных из .csv файла
copy raw_data.sales (id,auto,gasoline_consumption,price,date,person_name,phone, discount, brand_origin)
from '/cars.csv'
with csv header
null 'null';


--ЗАПОЛНЕНИЕ

--заполнение страны производителя
INSERT INTO car_shop.country (name_country)
SELECT DISTINCT brand_origin
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;


--заполнение бренда 
insert into car_shop.brand (id_country, brand_name)
select distinct 
	t2.id_brand_origin,
	TRIM(SPLIT_PART(t1.auto, ' ', 1)) as brand_name
from 
	raw_data.sales t1 
	left join car_shop.country t2 on t2.name_country = t1.brand_origin;

--заполнение модели
insert into car_shop.model (model, id_brand, gasoline_consumtion)
select distinct
	TRIM(SUBSTRING(auto, POSITION(' ' IN auto) + 1, POSITION(',' IN auto) - POSITION(' ' IN auto) - 1)) AS model,
	t2.id_brand,
	t1.gasoline_consumption 
from 
	raw_data.sales t1
	left join car_shop.brand t2 on TRIM(SPLIT_PART(t1.auto, ' ', 1)) = t2.brand_name;

-- заполнение цвета
insert into car_shop.color (color)
select distinct split_part(auto, ',', 2) as color 
from raw_data.sales 

--заполнение транзакции
insert into car_shop."transaction"(price, data_transaction, discount)
select  
	price,
	date,
	discount 
from 
	raw_data.sales
	order by id;

--заполнение авто 
insert into car_shop.auto (id_model, id_color)
select  
	t2.id_model,
	t3.id_color 
from 
	life_on_wheels.raw_data.sales t1
	left join car_shop.model t2 on t2.model  = TRIM(SUBSTRING(auto, POSITION(' ' IN auto) + 1, POSITION(',' IN auto) - POSITION(' ' IN auto) - 1))
	left join car_shop.color t3 on t3.color = split_part(t1.auto, ',', 2)
order by t1.id;

--заполнение покупателя
INSERT INTO car_shop.person (name_person, surname_person, phone_person)
select distinct 
    split_part(
        REGEXP_REPLACE(
            TRIM(REGEXP_REPLACE(
                person_name,
                '(\s*(II|MD|Dr\.|Mrs\.|DVM|DDS|Jr\.|Mr\.|Ms\.)\s*|,)',
                ' ',
                'gi'
            )),
            '\s+',
            ' ',
            'g'
        ), ' ', 1) AS name_person,
    split_part(
        REGEXP_REPLACE(
            TRIM(REGEXP_REPLACE(
                person_name,
                '(\s*(II|MD|Dr\.|Mrs\.|DVM|DDS|Jr\.|Mr\.|Ms\.)\s*|,)',
                ' ',
                'gi'
            )),
            '\s+',
            ' ',
            'g'
        ), ' ', 2) AS surname_person,
    phone AS phone_person
FROM raw_data.sales;

--заполнение sale
insert into car_shop.sale (id_transaction, id_auto, id_person)
select  
	t2.id_transaction,
	t3.id_auto,
	t4.id_person 
from
	raw_data.sales t1 
	left join car_shop."transaction" t2 on t1.id  = t2.id_transaction
	left join car_shop.auto t3 on  t1.id = t3.id_auto  
	left join car_shop.person t4 on t1.phone  = t4.phone_person;



--1 ЗАДАНИЕ

select
	(COUNT(t1.id_auto) * 100.0 / (SELECT COUNT(*) FROM car_shop.auto)) as percentage_no_consumption
from 
	car_shop.auto t1 
left join 
	car_shop.model t2 on t1.id_model = t2.id_model 	
where 
	t2.gasoline_consumtion is null;

--2 ЗАДАНИЕ
	
SELECT 
    b.brand_name,
    EXTRACT(year FROM t.data_transaction) as year,
    ROUND(AVG(t.price), 2) as price_avg
FROM 
    car_shop.sale s
JOIN 
    car_shop.transaction t ON s.id_transaction = t.id_transaction
JOIN 
    car_shop.auto a ON s.id_auto = a.id_auto
JOIN 
    car_shop.model m ON a.id_model = m.id_model
JOIN 
    car_shop.brand b ON m.id_brand = b.id_brand
GROUP BY 
    b.brand_name, EXTRACT(year FROM t.data_transaction)
ORDER BY 
    b.brand_name, year ASC;

--3 ЗАДАНИЕ
   
SELECT 
    EXTRACT(month FROM t.data_transaction) as month,
    2022 as year, -- фиксированный год 2022
    ROUND(AVG(t.price), 2) as price_avg
FROM 
    car_shop.transaction t
WHERE 
    EXTRACT(year FROM t.data_transaction) = 2022
GROUP BY 
    EXTRACT(month FROM t.data_transaction)
ORDER BY 
    month ASC;
   
   
--4 ЗАДАНИЕ
   
SELECT
    CONCAT(p.name_person, ' ', p.surname_person) AS person,
    STRING_AGG(CONCAT(b.brand_name, ' ', m.model), ', ') AS cars
FROM
    car_shop.person p
JOIN
    car_shop.sale s ON p.id_person = s.id_person
JOIN
    car_shop.auto a ON s.id_auto = a.id_auto
JOIN
    car_shop.model m ON a.id_model = m.id_model
JOIN
    car_shop.brand b ON m.id_brand = b.id_brand
GROUP BY
    CONCAT(p.name_person, ' ', p.surname_person)
ORDER BY
    person ASC;
   
--5 ЗАДАНИЕ
   
SELECT
    c.name_country as brand_origin,
    MAX(t.price / (1 - t.discount / 100)) as price_max,
    MIN(t.price / (1 - t.discount / 100)) as price_min
FROM
    car_shop.sale s
JOIN
    car_shop.transaction t ON s.id_transaction = t.id_transaction
JOIN 
    car_shop.auto a ON s.id_auto = a.id_auto
JOIN
    car_shop.model m ON a.id_model = m.id_model
JOIN
    car_shop.brand b ON m.id_brand = b.id_brand
JOIN
    car_shop.country c ON b.id_country = c.id_brand_origin
GROUP BY
    c.name_country
ORDER BY
    c.name_country ASC;
   
 --6 ЗАДАНИЕ
   
 SELECT 
    COUNT(*) as persons_from_usa_count
FROM 
    car_shop.person
WHERE 
    phone_person LIKE '+1%';

