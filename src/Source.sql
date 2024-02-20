 create schema raw_data
    create table sales(
    id smallint,
    auto varchar(40), 
    gasoline_consumption real,
    price real,
    date_ date,
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
   
COPY raw_data.sales(id, auto, gasoline_consumption, price, date_, person, phone, discount, brand_origin) FROM '\cars.csv' DELIMITER ',' CSV NULL 'null' HEADER;


create schema car_shop;

create table car_shop.auto(
id serial primary key,
auto_name varchar(20) not null
);

create table car_shop.color(
id serial primary key,
color_name varchar(10) not null
);

create table car_shop.brand_origin(
id serial primary key, 
brand_origin_name varchar(40)
);

create table car_shop.gasoline_consumption(
id serial primary key,
gasoline_consumption real
);

create table car_shop.date_(
id serial primary key,
date_ date not null
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

create table car_shop.auto_purchases(
id serial primary key,
auto_id integer,
color_id integer,
gasoline_consumption_id integer,
price_with_discount_id integer,
date_id integer,
clients_id integer,
brand_origin_id integer,
foreign key (auto_id) references car_shop.auto(id),
foreign key (color_id) references car_shop.color(id),
foreign key (gasoline_consumption_id) references car_shop.gasoline_consumption(id),
foreign key (price_with_discount_id) references car_shop.prices(id),
foreign key (date_id) references car_shop.date_(id),
foreign key (clients_id) references car_shop.clients(id),
foreign key (brand_origin_id) references car_shop.brand_origin(id)
);



INSERT INTO car_shop.auto(auto_name)
SELECT DISTINCT split_part(auto, ', ', 1)
FROM raw_data.sales;

INSERT INTO car_shop.color(color_name)
SELECT DISTINCT split_part(auto, ', ', 2)
FROM raw_data.sales;

INSERT INTO car_shop.brand_origin (brand_origin_name)
SELECT DISTINCT brand_origin
FROM raw_data.sales;

INSERT INTO car_shop.gasoline_consumption(gasoline_consumption)
SELECT DISTINCT gasoline_consumption
FROM raw_data.sales;

INSERT INTO car_shop.date_(date_)
SELECT DISTINCT date_
FROM raw_data.sales;

INSERT INTO car_shop.prices (price, discount)
SELECT price, discount
FROM raw_data.sales;

INSERT INTO car_shop.clients (person, phone)
select distinct person, phone
FROM raw_data.sales;



INSERT INTO car_shop.auto_purchases(auto_id, color_id, gasoline_consumption_id, price_with_discount_id, date_id, clients_id, brand_origin_id)
select car_shop.auto.id, car_shop.color.id, car_shop.gasoline_consumption.id, car_shop.prices.id, car_shop.date_.id, car_shop.clients.id, car_shop.brand_origin.id 
FROM raw_data.sales 
join car_shop.auto on split_part(raw_data.sales.auto, ', ', 1) = car_shop.auto.auto_name
join car_shop.color on split_part(raw_data.sales.auto, ', ', 2) = car_shop.color.color_name
join car_shop.gasoline_consumption on raw_data.sales.gasoline_consumption  = car_shop.gasoline_consumption.gasoline_consumption or (raw_data.sales.gasoline_consumption is null and  car_shop.gasoline_consumption.gasoline_consumption is null)
join car_shop.date_ on raw_data.sales.date_  = car_shop.date_.date_
join car_shop.brand_origin on raw_data.sales.brand_origin  = car_shop.brand_origin.brand_origin_name or (raw_data.sales.brand_origin  is null and car_shop.brand_origin.brand_origin_name is null)
join car_shop.prices on raw_data.sales.price  = car_shop.prices.price and raw_data.sales.discount  = car_shop.prices.discount
join car_shop.clients on raw_data.sales.person  = car_shop.clients.person  and raw_data.sales.phone  = car_shop.clients.phone  ;



SELECT 
  (COUNT(*) FILTER (WHERE car_shop.gasoline_consumption.gasoline_consumption is null ) * 100.0) / COUNT(*) AS nulls_percentage_gasoline_consumption
FROM car_shop.auto_purchases join car_shop.gasoline_consumption on car_shop.gasoline_consumption.id = car_shop.auto_purchases.gasoline_consumption_id;


SELECT auto_name as brand_name, EXTRACT(year FROM date_) AS year, ROUND(AVG(price - discount)::numeric, 2) AS price_avg
from car_shop.auto_purchases
join car_shop.auto on car_shop.auto.id = car_shop.auto_purchases.auto_id 
join car_shop.prices  on car_shop.prices.id = car_shop.auto_purchases.price_with_discount_id
join car_shop.date_ on car_shop.date_.id  = car_shop.auto_purchases.date_id  
GROUP BY brand_name, EXTRACT(year FROM date_)
ORDER BY brand_name, year;


SELECT EXTRACT(month FROM date_) AS month,EXTRACT(year FROM date_) AS year, ROUND(AVG(price - discount)::numeric, 2) AS price_avg
from car_shop.auto_purchases
join car_shop.prices  on car_shop.prices.id = car_shop.auto_purchases.price_with_discount_id
join car_shop.date_ on car_shop.date_.id  = car_shop.auto_purchases.date_id  
where EXTRACT(year FROM date_) = 2022
GROUP by EXTRACT(year FROM date_) ,EXTRACT(month FROM date_)
ORDER BY month;


SELECT 
  person,
  STRING_AGG(auto_name::character varying, ', ' ORDER BY auto_name) AS cars
FROM car_shop.auto_purchases 
join car_shop.auto on car_shop.auto.id = car_shop.auto_purchases.auto_id 
join car_shop.clients on car_shop.clients.id  = car_shop.auto_purchases.clients_id 
GROUP BY person
ORDER BY person;



SELECT 
  brand_origin_name,
  MAX(price) AS price_max,
  MIN(price) AS price_min
FROM car_shop.auto_purchases
join car_shop.prices on car_shop.prices.id  = car_shop.auto_purchases.price_with_discount_id  
join car_shop.brand_origin on car_shop.brand_origin.id  = car_shop.auto_purchases.brand_origin_id 
GROUP BY brand_origin_name;



SELECT 
  COUNT(*) AS persons_from_usa_count
FROM car_shop.auto_purchases
join car_shop.clients on car_shop.clients.id = car_shop.auto_purchases.clients_id  
WHERE phone LIKE '+1%';


