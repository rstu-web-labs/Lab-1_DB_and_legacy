--создание основной таблицы
CREATE TABLE raw_data.sales (
	id int UNIQUE NOT NULL,
	auto varchar(255) NOT NULL,
	gasoline_consumption float4 null check(gasoline_consumption<=99 and gasoline_consumption>=0),
	price float8 NULL,
	"date" date NOT NULL,
	person_name varchar(50) NOT NULL,
	phone varchar(255) NOT NULL,
	discount int NOT NULL,
	brand_origin varchar(255) NULL

);

COPY raw_data.sales(id,auto,gasoline_consumption,price,date,person_name,phone,discount,brand_origin)
FROM '/cars.csv'
with csv header
null 'null';

CREATE SCHEMA car_shop;


-- создание таблицы clients: 

CREATE TABLE car_shop.clients (
	id int GENERATED BY DEFAULT AS IDENTITY NOT NULL,
	"name" varchar(128) NOT NULL,
	surname varchar(128) NOT NULL,
	phone varchar(128) NULL,
	CONSTRAINT clients_pk PRIMARY KEY (id)
);

-- создание таблицы cars: 
CREATE TABLE car_shop.cars (
	id_client int references car_shop.clients(id) NOT null,
	brand_name varchar(128) NOT NULL,
	model varchar(128) NOT NULL,
	color varchar(128) NOT NULL,
	gasoline_consumption float4 null,
	brand_origin varchar(128)

);
-- создание таблицы price: 

CREATE TABLE car_shop.prices (

	id_client int references car_shop.clients(id) NOT null,
	price float8 NOT NULL,
	discount float8 NOT null,
	date_of_purchase date NOT NULL
);


-- добавление данных в таблицу clients: 

INSERT INTO  car_shop.clients (id,"name",surname,phone) 
SELECT id,
SUBSTRING(person_name from 1 FOR POSITION(' ' IN person_name)), --выделение имени из строки
SUBSTRING(person_name from POSITION(' ' IN person_name)), --выделение имени из строки
phone  
FROM raw_data.sales;
-- добавление данных в таблицу cars: 

INSERT INTO  car_shop.cars (id_client,brand_name,model,color,gasoline_consumption,brand_origin) 
SELECT id,  
SUBSTRING(auto from 1 FOR POSITION(' ' IN auto)), -- выделение бренда из строки
SPLIT_PART(SUBSTRING(auto from POSITION(' ' IN auto) ), ',', 1), -- выделение модели ищ строки
SPLIT_PART(SUBSTRING(auto from POSITION(' ' IN auto) ), ',', 2), -- выделение цвета машины из строки
gasoline_consumption,
brand_origin
FROM raw_data.sales;


-- добавление данных в таблицу price: 

INSERT INTO  car_shop.prices (id_client,price,discount,date_of_purchase) 
SELECT id,price ,discount,"date"
FROM raw_data.sales;


--запросы:
--Задание 1:

SELECT COUNT(id_client) * 100.0 / (SELECT COUNT(*) FROM car_shop.cars) as nulls_percentage_gasoline_consumption
FROM car_shop.cars
WHERE car_shop.cars.gasoline_consumption IS NULL;

--Задание 2:

SELECT a.brand_name , EXTRACT(year  FROM  b.date_of_purchase) as year, round(avg(b.price)::numeric,2) as price_avg
FROM car_shop.cars a,car_shop.prices b
where a.id_client =b.id_client 
GROUP BY a.brand_name, date_of_purchase
ORDER BY a.brand_name,date_of_purchase ;

--задание 3
SELECT EXTRACT(month  FROM  b.date_of_purchase) as month , EXTRACT(year  FROM  b.date_of_purchase) as year, round(avg(b.price)::numeric,2) as price_avg
FROM car_shop.prices b
GROUP BY  date_of_purchase
ORDER BY  date_of_purchase ;


-- задание 4

select concat(a.name, a.surname) as person, string_agg(concat(b.brand_name,b.model ),', '  ORDER BY concat(b.brand_name,b.model )) as cars
from car_shop.clients a,car_shop.cars b
where a.id = b.id_client 
GROUP by a.name, a.surname, b.brand_name,b.model;

--задание 5

select a.brand_origin,max(((b.price*100)/100-b.discount)) as price_max, min(((b.price*100)/100-b.discount)) as price_min
from car_shop.cars a, car_shop.prices b
where a.id_client =b.id_client and a.brand_origin  IS NOT null
GROUP by a.brand_origin;

--задание 6

SELECT COUNT(*) as persons_from_usa_count
FROM car_shop.clients c 
WHERE phone LIKE '+1%';


