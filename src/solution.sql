CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
    id serial PRIMARY KEY,
    auto VARCHAR(50),
    gasoline_consumption DECIMAL(3,1),
    price DECIMAL(19,12),

    date DATE,
    person_name VARCHAR(70),
    phone VARCHAR(50),
    discount DECIMAL(4,2),
    brand_origin VARCHAR(50)
);

copy raw_data.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
from '/tmp/cars.csv'
DELIMITER ','
null 'null'
csv header;

CREATE SCHEMA car_shop;

CREATE TABLE car_shop.person (
 id serial PRIMARY KEY,
 person_name VARCHAR(70) not NULL,
 phone VARCHAR(50) NOT null
);

CREATE TABLE car_shop.spr_country (
 id serial PRIMARY KEY, 
 country_name VARCHAR(50) unique NOT null 
);

CREATE TABLE car_shop.brand (
 id serial PRIMARY KEY, 
 id_country int, 
 name_brand VARCHAR(50) not null check (name_brand NOT LIKE ''), 
 FOREIGN KEY (id_country) REFERENCES car_shop.spr_country(id)
);

CREATE TABLE car_shop.model (
 id serial PRIMARY KEY, 
 id_brand int, 
 name_model VARCHAR(50) not null, 
 gasoline_consumption DECIMAL(3,1) CHECK (gasoline_consumption >= 0 AND gasoline_consumption <= 99.9) DEFAULT null,
 FOREIGN KEY (id_brand) REFERENCES car_shop.brand(id)
);

CREATE TABLE car_shop.sett (
 id serial PRIMARY KEY, 
 id_model int, 
 color VARCHAR(50) not null, 
 FOREIGN KEY (id_model) REFERENCES car_shop.model(id)
);


CREATE TABLE car_shop.sale (
 id serial PRIMARY KEY, 
 id_person int, 
 id_sett int, 
 price DECIMAL(19,12) not null CHECK (price >= 0 AND price < 9999999.999999999999),
 discount DECIMAL(4,2) CHECK (discount >= 0 AND discount <= 99.99),
 date DATE, 
   FOREIGN KEY (id_sett) REFERENCES car_shop.sett(id),
   FOREIGN KEY (id_person) REFERENCES car_shop.person(id)
);



INSERT INTO car_shop.person (person_name, phone)
SELECT DISTINCT person_name, phone
FROM raw_data.sales;
;
INSERT into car_shop.spr_country  (country_name)
select distinct brand_origin  
from raw_data.sales
where brand_origin is not null;

INSERT INTO car_shop.brand (id_country, name_brand)
SELECT car_shop.spr_country.id, split_part(raw_data.sales.auto, ' ', 1)
FROM car_shop.spr_country
 right JOIN raw_data.sales ON car_shop.spr_country.country_name = raw_data.sales.brand_origin
GROUP BY split_part(raw_data.sales.auto, ' ', 1), car_shop.spr_country.id;

INSERT INTO car_shop.model (id_brand , name_model, gasoline_consumption)
SELECT car_shop.brand.id,  SUBSTRING(raw_data.sales.auto FROM POSITION(' ' IN raw_data.sales.auto) + 1 FOR POSITION(',' IN raw_data.sales.auto) - POSITION(' ' IN raw_data.sales.auto) - 1), gasoline_consumption
FROM car_shop.brand
 right JOIN raw_data.sales ON car_shop.brand.name_brand  = split_part(raw_data.sales.auto, ' ', 1)
GROUP BY  SUBSTRING(raw_data.sales.auto FROM POSITION(' ' IN raw_data.sales.auto) + 1 FOR POSITION(',' IN raw_data.sales.auto) - POSITION(' ' IN raw_data.sales.auto) - 1), car_shop.brand.id, gasoline_consumption;

INSERT INTO car_shop.sett (id_model, color)
SELECT car_shop.model.id, split_part(raw_data.sales.auto, ', ', 2)
FROM car_shop.model
 right JOIN raw_data.sales ON car_shop.model.name_model  = SUBSTRING(raw_data.sales.auto FROM POSITION(' ' IN raw_data.sales.auto) + 1 FOR POSITION(',' IN raw_data.sales.auto) - POSITION(' ' IN raw_data.sales.auto) - 1)
GROUP BY  car_shop.model.id, split_part(raw_data.sales.auto, ', ', 2);

INSERT INTO car_shop.sale  (id_person, id_sett, price, discount, date)
SELECT car_shop.person.id  , car_shop.sett.id, raw_data.sales.price , raw_data.sales.discount , raw_data.sales."date"
from raw_data.sales join car_shop.person on raw_data.sales.phone  = car_shop.person.phone
join car_shop.sett on split_part(raw_data.sales.auto, ', ', 2) = car_shop.sett.color
join car_shop.model on car_shop.model.id = car_shop.sett.id_model
join car_shop.brand on car_shop.brand.id = car_shop.model.id_brand
where split_part(raw_data.sales.auto, ', ', 2) = car_shop.sett.color and car_shop.sett.id_model = car_shop.model.id and car_shop.model.name_model = SUBSTRING(raw_data.sales.auto FROM POSITION(' ' IN raw_data.sales.auto) + 1 FOR POSITION(',' IN raw_data.sales.auto) - POSITION(' ' IN raw_data.sales.auto) - 1);

--ЗАДАНИЕ №1
SELECT   (COUNT(*) * 100.0 /  (SELECT COUNT(*)
FROM car_shop.model
    JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
    JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id)) AS nulls_percentage_gasoline_consumption
FROM car_shop.model
JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id
WHERE gasoline_consumption IS null;

SELECT COUNT(*)
from raw_data.sales
where gasoline_consumption isnull ;
;

--ЗАДАНИЕ №2
SELECT  name_brand as brand_name, to_char(date, 'YYYY') as year, ROUND(AVG(price), 2) as price_avg
FROM car_shop.brand
JOIN car_shop.model ON car_shop.brand.id = car_shop.model.id_brand
JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id
GROUP BY name_brand, to_char(date, 'YYYY')
ORDER BY name_brand asc,  year;

--ЗАДАНИЕ №3
SELECT  to_char(date, 'mm') as month, to_char(date, 'yyyy') as year, ROUND(AVG(price), 2) as price_avg
FROM car_shop.brand
JOIN car_shop.model ON car_shop.brand.id = car_shop.model.id_brand
JOIN car_shop.sett ON car_shop.sett.id_model = car_shop.model.id
JOIN car_shop.sale ON car_shop.sale.id_sett = car_shop.sett.id
where to_char(date, 'YYYY') = '2022'
GROUP BY to_char(date, 'mm'), to_char(date, 'yyyy')
ORDER BY to_char(date, 'mm') ASC;

--ЗАДАНИЕ №4
SELECT car_shop.person.person_name as person, STRING_AGG(concat(car_shop.brand.name_brand ,' ', car_shop.model.name_model  )  , ', ') AS cars
FROM car_shop.sale
JOIN car_shop.person ON car_shop.sale.id_person = car_shop.person.id
JOIN car_shop.sett ON car_shop.sett.id = car_shop.sale.id_sett
join car_shop.model on car_shop.model.id = car_shop.sett.id_model
join car_shop.brand on car_shop.model.id_brand  = car_shop.brand.id
GROUP BY car_shop.person.person_name
ORDER BY car_shop.person.person_name
;


--ЗАДАНИЕ №5
SELECT
    car_shop.spr_country.country_name,
    min_price.price_min + (min_price.price_min*car_shop.sale.discount / 100) as price_min ,
    max_price.price_max + (max_price.price_max*car_shop.sale.discount / 100) as price_max
FROM car_shop.sale
JOIN car_shop.sett ON car_shop.sett.id = car_shop.sale.id_sett
JOIN car_shop.model ON car_shop.model.id = car_shop.sett.id_model
JOIN car_shop.brand ON car_shop.model.id_brand = car_shop.brand.id
JOIN car_shop.spr_country ON car_shop.spr_country.id = car_shop.brand.id_country
JOIN (
    SELECT
        car_shop.brand.id_country as country_id,
        min(car_shop.sale.price) as price_min
    FROM car_shop.sale
    JOIN car_shop.sett ON car_shop.sett.id = car_shop.sale.id_sett
    JOIN car_shop.model ON car_shop.model.id = car_shop.sett.id_model
    JOIN car_shop.brand ON car_shop.model.id_brand = car_shop.brand.id
    GROUP BY car_shop.brand.id_country
) min_price ON min_price.country_id = car_shop.brand.id_country AND min_price.price_min = car_shop.sale.price
JOIN (
    SELECT
        car_shop.brand.id_country as country_id,
        max(car_shop.sale.price) as price_max
    FROM car_shop.sale
    JOIN car_shop.sett ON car_shop.sett.id = car_shop.sale.id_sett
    JOIN car_shop.model ON car_shop.model.id = car_shop.sett.id_model
    JOIN car_shop.brand ON car_shop.model.id_brand = car_shop.brand.id
    GROUP BY car_shop.brand.id_country
) max_price ON max_price.country_id = car_shop.brand.id_country
where car_shop.spr_country.country_name is not null
;

--ЗАДАНИЕ №6
SELECT COUNT(car_shop.person.person_name) as persons_from_usa_count
FROM car_shop.sale
JOIN car_shop.person ON car_shop.sale.id_person = car_shop.person.id and car_shop.person.phone like '+1%'
;
