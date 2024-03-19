 create schema raw_data
    create table sales(
    id smallint,
    auto varchar(40), 
    gasoline_consumption real,
    price real,
    date date,
    person varchar(40),
    phone  varchar(40),
    discount smallint,
    brand_origin varchar(40)
    );

   -- smallint для id выбрано так как нет необходимости использовать большие числа потому что элемент этого столбца - порядковый номер, и наибольший порядковый номер не превышает 1000
   -- varchar использован чтобы ограничить длинну строки, вместо того, чтобы создавать специальные ограничения constrait
   -- date выбрано для более удобной работы с датой, чем если бы это был строковый тип
   -- real выбрано так как в данном случае высокая точность дробных чисел не нужна, достаточно всего нескольких знаков псле запятой.
   -- smallint для discount так как используются только сравнительно маленькие целые числа в диапазоне от 0 до 100
   
COPY raw_data.sales(id, auto, gasoline_consumption, price, date, person, phone, discount, brand_origin) FROM '\cars.csv' DELIMITER ',' CSV NULL 'null' HEADER;


create schema car_shop;

create table car_shop.color(
id serial primary key,
color_name varchar(10) not null
);

create table car_shop.gasoline_consumption(
id serial primary key,
consumption_value real
);

create table car_shop.clients(
id serial primary key,
person varchar(40) not null,
phone varchar(40) not null
);


create table car_shop.prices(
id serial primary key,
price real not null,
discount smallint
);

CREATE TABLE car_shop.brand_origin (
   id serial PRIMARY KEY,
   brand_origin_name text
);

CREATE TABLE car_shop.brand (
   id serial PRIMARY KEY,
   brand_name text,
   brand_origin_id integer,
   FOREIGN KEY (brand_origin_id) REFERENCES car_shop.brand_origin(id)
);

CREATE TABLE car_shop.model (
   id serial PRIMARY KEY,
   brand_id integer,
   model_name text NOT null,
   FOREIGN KEY (brand_id) REFERENCES car_shop.brand(id)
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
    clients_id integer,
    purchase_date date NOT NULL,
    price_id integer,
    FOREIGN KEY (car_id) REFERENCES car_shop.car(id),
    FOREIGN KEY (clients_id) REFERENCES car_shop.clients(id),
    FOREIGN KEY (price_id) REFERENCES car_shop.prices(id)
);

INSERT INTO car_shop.color(color_name)
SELECT DISTINCT split_part(auto, ', ', 2)
FROM raw_data.sales;

INSERT INTO car_shop.gasoline_consumption(consumption_value)
SELECT DISTINCT gasoline_consumption
FROM raw_data.sales;

INSERT INTO car_shop.prices (price, discount)
SELECT price, discount
FROM raw_data.sales;

INSERT INTO car_shop.brand_origin ( brand_origin_name)
SELECT distinct raw_data.sales.brand_origin 
FROM raw_data.sales;

INSERT INTO car_shop.brand(brand_origin_id,brand_name)
SELECT DISTINCT car_shop.brand_origin.id  , split_part(auto, ' ', 1)
FROM raw_data.sales
join car_shop.brand_origin on car_shop.brand_origin.brand_origin_name  = raw_data.sales.brand_origin or (car_shop.brand_origin.brand_origin_name is null and raw_data.sales.brand_origin is null) ;

INSERT INTO car_shop.clients (person, phone)
select distinct person, phone
FROM raw_data.sales;

INSERT INTO car_shop.model(brand_id, model_name)
SELECT distinct car_shop.brand.id, substring(split_part(auto, ', ', 1), strpos(split_part(auto, ', ', 1),' '), length(split_part(auto, ', ', 1)))
FROM raw_data.sales
join car_shop.brand on car_shop.brand.brand_name = split_part(auto, ' ', 1);

INSERT INTO car_shop.car (brand_id, model_id, color_id, gasoline_consumption_id)
select distinct car_shop.brand.id  , car_shop.model.id,  car_shop.color.id ,  car_shop.gasoline_consumption.id  
FROM raw_data.sales
JOIN car_shop.model ON car_shop.model.model_name = substring(split_part(auto, ', ', 1), strpos(split_part(auto, ', ', 1),' '), length(split_part(auto, ', ', 1)))
join car_shop.brand on car_shop.brand.brand_name =  split_part(auto, ' ', 1)
join car_shop.color on car_shop.color.color_name = split_part(auto, ', ', 2)
join car_shop.gasoline_consumption on car_shop.gasoline_consumption.consumption_value = raw_data.sales.gasoline_consumption or (car_shop.gasoline_consumption.consumption_value is null and raw_data.sales.gasoline_consumption is null);

INSERT INTO car_shop.purchase  (car_id, clients_id, purchase_date, price_id)
select distinct car_shop.car.id , car_shop.clients.id, raw_data.sales."date" , car_shop.prices.id
from raw_data.sales 
join car_shop.clients on car_shop.clients.person = raw_data.sales.person and car_shop.clients.phone = raw_data.sales.phone 
join car_shop.prices on car_shop.prices.price = raw_data.sales.price and car_shop.prices.discount = raw_data.sales.discount 
join car_shop.car on car_shop.car.brand_id = (select id from car_shop.brand where car_shop.brand.brand_name = split_part(auto, ' ', 1))
and car_shop.car.model_id = (select id from car_shop.model where car_shop.model.model_name = substring(split_part(auto, ', ', 1), strpos(split_part(auto, ', ', 1),' '), length(split_part(auto, ', ', 1)))) 
and car_shop.car.color_id = (select id from car_shop.color where car_shop.color.color_name  = split_part(auto, ', ', 2)) 
and car_shop.car.gasoline_consumption_id = (select id from car_shop.gasoline_consumption where car_shop.gasoline_consumption.consumption_value = raw_data.sales.gasoline_consumption or (car_shop.gasoline_consumption.consumption_value is null and raw_data.sales.gasoline_consumption is null)) ;





SELECT 
  (COUNT(*) FILTER (WHERE car_shop.gasoline_consumption.consumption_value  is null ) * 100.0) / COUNT(*) AS nulls_percentage_gasoline_consumption 
FROM car_shop.purchase 
join car_shop.gasoline_consumption on (select gasoline_consumption_id from car_shop.car where car_shop.car.id = car_shop.purchase.car_id) = car_shop.gasoline_consumption.id  ;


SELECT brand_name, EXTRACT(year FROM purchase_date) AS year, ROUND(AVG(price)::numeric, 2) AS price_avg
from car_shop.purchase
join car_shop.car on car_shop.car.id  = car_shop.purchase.car_id 
join car_shop.brand on car_shop.car.brand_id = car_shop.brand.id  
join car_shop.prices  on car_shop.prices.id = car_shop.purchase.price_id 
GROUP BY brand_name, EXTRACT(year FROM purchase_date)
ORDER BY brand_name, year;


SELECT EXTRACT(month FROM purchase_date) AS month,EXTRACT(year FROM purchase_date) AS year, ROUND(AVG(price - discount)::numeric, 2) AS price_avg
from car_shop.purchase
join car_shop.prices  on car_shop.prices.id = car_shop.purchase.price_id 
where EXTRACT(year FROM purchase_date) = 2022
GROUP by EXTRACT(year FROM purchase_date) ,EXTRACT(month FROM purchase_date)
ORDER BY month;


SELECT 
  person,
  STRING_AGG(concat(brand_name, ' ', model_name)::character varying, ', ') AS cars
FROM car_shop.purchase
join car_shop.car on car_shop.purchase.car_id  = car_shop.car.id 
join car_shop.brand on car_shop.car.brand_id = car_shop.brand.id 
join car_shop.model on car_shop.car.model_id = car_shop.model.id  
join car_shop.clients on car_shop.clients.id  = car_shop.purchase.clients_id 
GROUP BY person
ORDER BY person;



SELECT 
  brand_origin_name,
  MAX(price) AS price_max,
  MIN(price) AS price_min
FROM car_shop.purchase
join car_shop.prices on car_shop.prices.id  = car_shop.purchase.price_id  
join car_shop.car on car_shop.purchase.car_id  = car_shop.car.id
join car_shop.brand on car_shop.car.brand_id = car_shop.brand.id  
join car_shop.brand_origin on car_shop.brand.brand_origin_id = car_shop.brand_origin.id  
GROUP BY brand_origin_name;



SELECT 
  COUNT(*) AS persons_from_usa_count        
FROM car_shop.purchase
join car_shop.clients on car_shop.clients.id = car_shop.purchase.clients_id  
WHERE phone LIKE '+1%';

