CREATE SCHEMA raw_data;

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


-- создание таблицы car_country: 

CREATE TABLE car_shop.car_country (
	id serial PRIMARY KEY,
 	country_name VARCHAR(255) unique not null 

);

-- создание таблицы brand: 

CREATE TABLE car_shop.brand (
	id serial PRIMARY KEY,
	id_country int,
	name_brand VARCHAR(50),
  	FOREIGN KEY (id_country) REFERENCES car_shop.car_country(id)  ON DELETE CASCADE

);

-- создание таблицы model: 

CREATE TABLE car_shop.model (
 id serial PRIMARY KEY,
 id_brand int, 
 name_model VARCHAR(50) not null, 
 gasoline_consumption float4 null,
 FOREIGN KEY (id_brand) REFERENCES car_shop.brand(id) 
);

-- создание таблицы cars: 

CREATE TABLE car_shop.cars (
 id serial PRIMARY KEY,
 id_model int, 
 color VARCHAR(50) not null, 
 FOREIGN KEY (id_model) REFERENCES car_shop.model(id) ON DELETE CASCADE
);
-- создание таблицы clients: 

CREATE TABLE car_shop.clients (
	id serial PRIMARY KEY,
	"name" varchar(128) NOT NULL,
	surname varchar(128) NOT NULL,
	phone varchar(128) NULL
);

-- создание таблицы sale: 

CREATE TABLE car_shop.sale (
	id serial PRIMARY KEY,
	id_client int,
	id_car int,
	price float8,
 	discount int,
 	date DATE,
 	FOREIGN KEY (id_car) REFERENCES car_shop.cars(id),
   	FOREIGN KEY (id_client) REFERENCES car_shop.clients(id)
);

-- добавление данных в таблицу car_country: 

INSERT INTO  car_shop.car_country (country_name) 
select distinct  brand_origin  
FROM raw_data.sales
where brand_origin is not null;

-- добавление данных в таблицу brand: 

INSERT INTO car_shop.brand (id_country, name_brand)
SELECT car_shop.car_country.id, SUBSTRING(raw_data.sales.auto from 1 FOR POSITION(' ' IN raw_data.sales.auto))
FROM car_shop.car_country
right JOIN raw_data.sales ON car_shop.car_country.country_name = raw_data.sales.brand_origin
GROUP by SUBSTRING(raw_data.sales.auto from 1 FOR POSITION(' ' IN raw_data.sales.auto)), car_shop.car_country.id;


-- добавление данных в таблицу model: 

INSERT INTO  car_shop.model (id_brand, name_model,gasoline_consumption) 
SELECT car_shop.brand.id,
SPLIT_PART(SUBSTRING(raw_data.sales.auto from POSITION(' ' IN raw_data.sales.auto) ), ',', 1),
raw_data.sales.gasoline_consumption 
FROM car_shop.brand
right JOIN raw_data.sales ON car_shop.brand.name_brand  = SUBSTRING(raw_data.sales.auto from 1 FOR POSITION(' ' IN raw_data.sales.auto))
GROUP BY SPLIT_PART(SUBSTRING(auto from POSITION(' ' IN auto) ), ',', 1), car_shop.brand.id,
gasoline_consumption;


-- добавление данных в таблицу cars: 

INSERT INTO  car_shop.cars (id_model, color) 
SELECT car_shop.model.id, SPLIT_PART(SUBSTRING(raw_data.sales.auto from POSITION(' ' IN raw_data.sales.auto) ), ',', 2) -- выделение цвета машины из строки
FROM car_shop.model 
 right JOIN raw_data.sales ON car_shop.model.name_model  = SPLIT_PART(SUBSTRING(raw_data.sales.auto from POSITION(' ' IN raw_data.sales.auto) ), ',', 1)
GROUP BY  car_shop.model.id, SPLIT_PART(SUBSTRING(raw_data.sales.auto from POSITION(' ' IN raw_data.sales.auto) ), ',', 2);

-- добавление данных в таблицу clients: 

INSERT INTO  car_shop.clients ("name",surname,phone) 
SELECT SUBSTRING(person_name from 1 FOR POSITION(' ' IN person_name)), --выделение имени из строки
SUBSTRING(person_name from POSITION(' ' IN person_name)), --выделение имени из строки
phone  
FROM raw_data.sales;

-- добавление данных в таблицу sale: 

INSERT INTO  car_shop.sale (id_client, id_car, price, discount,"date") 
SELECT car_shop.clients.id, car_shop.cars.id, raw_data.sales.price,
       raw_data.sales.discount,
       raw_data.sales."date"
FROM  raw_data.sales join car_shop.clients  on raw_data.sales.phone  = car_shop.clients.phone
join car_shop.cars on SPLIT_PART(SUBSTRING(raw_data.sales.auto from POSITION(' ' IN raw_data.sales.auto) ), ',', 2) = car_shop.cars.color
join car_shop.model on car_shop.model.id = car_shop.cars.id_model
join car_shop.brand on car_shop.brand.id = car_shop.model.id_brand
where SPLIT_PART(SUBSTRING(raw_data.sales.auto from POSITION(' ' IN raw_data.sales.auto) ), ',', 2)= car_shop.cars.color
and car_shop.cars.id_model = car_shop.model.id 
and car_shop.model.name_model =SPLIT_PART(SUBSTRING(raw_data.sales.auto from POSITION(' ' IN raw_data.sales.auto) ), ',', 1)
;

--запросы:
--Задание 1:

SELECT   (COUNT(*) * 100.0 /  (SELECT COUNT(*)
FROM car_shop.model
    JOIN car_shop.cars ON car_shop.cars.id_model = car_shop.model.id
    JOIN car_shop.sale ON car_shop.sale.id_car  = car_shop.cars.id)) AS nulls_percentage_gasoline_consumption
FROM car_shop.model
JOIN car_shop.cars ON car_shop.cars.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_car = car_shop.cars.id
WHERE gasoline_consumption IS null;
--Задание 2:

SELECT name_brand , EXTRACT(year  FROM  car_shop.sale."date") as year, round(avg(car_shop.sale.price)::numeric,2) as price_avg
FROM car_shop.brand
JOIN car_shop.model ON car_shop.brand.id = car_shop.model.id_brand
JOIN car_shop.cars ON car_shop.cars.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_car = car_shop.cars.id
GROUP BY name_brand,EXTRACT(year  FROM  car_shop.sale."date") 
ORDER BY name_brand asc,  year ;

--задание 3
SELECT EXTRACT(month  FROM car_shop.sale."date") as month , EXTRACT(year  FROM car_shop.sale."date") as year, round(avg(car_shop.sale.price)::numeric,2) as price_avg
FROM car_shop.brand
JOIN car_shop.model ON car_shop.brand.id = car_shop.model.id_brand
JOIN car_shop.cars ON car_shop.cars.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_car = car_shop.cars.id
where  EXTRACT(year  FROM  car_shop.sale."date") = '2022'
GROUP BY EXTRACT(month  FROM car_shop.sale."date"),EXTRACT(year  FROM car_shop.sale."date")
ORDER BY EXTRACT(month  FROM car_shop.sale."date") ASC
;

-- задание 4

select concat(car_shop.clients.name, car_shop.clients.surname) as person, string_agg(concat(car_shop.brand.name_brand, car_shop.model.name_model  ),', '  ORDER BY concat(car_shop.brand.name_brand, car_shop.model.name_model  )) as cars
FROM car_shop.sale
JOIN car_shop.clients ON car_shop.sale.id_client = car_shop.clients.id
JOIN car_shop.cars ON car_shop.cars.id = car_shop.sale.id_car
join car_shop.model on car_shop.model.id = car_shop.cars.id_model
join car_shop.brand on car_shop.model.id_brand  = car_shop.brand.id
GROUP BY concat(car_shop.clients.name, car_shop.clients.surname)
ORDER BY concat(car_shop.clients.name, car_shop.clients.surname)
;
--задание 5

SELECT
    car_shop.car_country.country_name,
    min_price.price_min + (min_price.price_min*car_shop.sale.discount / 100) as price_min ,
    max_price.price_max + (max_price.price_max*car_shop.sale.discount / 100) as price_max
FROM car_shop.sale
JOIN car_shop.cars ON car_shop.cars.id = car_shop.sale.id_car
JOIN car_shop.model ON car_shop.model.id = car_shop.cars.id_model
JOIN car_shop.brand ON car_shop.model.id_brand = car_shop.brand.id
JOIN car_shop.car_country ON car_shop.car_country.id = car_shop.brand.id_country
JOIN (
    SELECT
        car_shop.brand.id_country as country_id,
        min(car_shop.sale.price) as price_min
    FROM car_shop.sale
    JOIN car_shop.cars ON car_shop.cars.id = car_shop.sale.id_car
    JOIN car_shop.model ON car_shop.model.id = car_shop.cars.id_model
    JOIN car_shop.brand ON car_shop.model.id_brand = car_shop.brand.id
    GROUP BY car_shop.brand.id_country
) min_price ON min_price.country_id = car_shop.brand.id_country AND min_price.price_min = car_shop.sale.price
JOIN (
    SELECT
        car_shop.brand.id_country as country_id,
        max(car_shop.sale.price) as price_max
    FROM car_shop.sale
    JOIN car_shop.cars ON car_shop.cars.id = car_shop.sale.id_car
    JOIN car_shop.model ON car_shop.model.id = car_shop.cars.id_model
    JOIN car_shop.brand ON car_shop.model.id_brand = car_shop.brand.id
    GROUP BY car_shop.brand.id_country
) max_price ON max_price.country_id = car_shop.brand.id_country
where car_shop.car_country.country_name is not null
;
--задание 6

SELECT COUNT(*) as persons_from_usa_count
FROM car_shop.sale
JOIN car_shop.clients  ON car_shop.sale.id_client  = car_shop.clients.id and car_shop.clients.phone like '+1%'
;

