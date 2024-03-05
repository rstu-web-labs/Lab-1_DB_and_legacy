create database life_on_wheels;

create schema raw_data;

create table raw_data.sales(
id int primary key,
auto varchar(50),
gasoline_consumption float,
price decimal , 
date date,
person_name varchar(100),
phone varchar(50),
discount float,
brand_origin varchar(50)
);

copy sales (id, auto, gasoline_consumption, 
price, date, person_name, phone, discount, brand_origin)
from 'C:\Users\User\Desktop\labs\cars.csv' 
delimiter ','
csv header null 'null';

create schema car_shop;

--таблица покупатель
create table car_shop.buyer(
id serial primary key,
person_name varchar(100) not null,
phone varchar(30) not null
);
--таблица страна
 create table car_shop.country(
 id serial primary key,
 brand_origin varchar(100)
 );
--таблица характеристика машины
create table car_shop.characteristic_car(
id serial primary key,
color varchar(20) not null,
gasoline_consumption float null
);
--таблица бренд
create table car_shop.brand(
id serial primary key,
id_country int references car_shop.country(id) on delete restrict,
brand varchar(50) not null
);
-- таблица машина
create table car_shop.car(
id serial primary key,
id_brand int references car_shop.brand(id) on delete restrict,
id_characteristic int references car_shop.characteristic_car(id) on delete restrict,
model varchar(50) not null,
price decimal not null
);
--таблица продажи
create table car_shop.sale(
id serial primary key,
id_car int references car_shop.car(id) on delete restrict,
id_buyer int references car_shop.buyer(id) on delete restrict,
date date not null,
discount float not null
);

--заполнение таблиц 
insert into car_shop.buyer(person_name, phone)
select person_name , phone 
from raw_data.sales 
group by person_name, phone;

insert into car_shop.country (brand_origin)
select brand_origin
from raw_data.sales 
where brand_origin is not null
group by brand_origin ;

insert into car_shop.characteristic_car (color, gasoline_consumption)
select split_part(auto, ',', 2) as color, gasoline_consumption 
from raw_data.sales 
group by color, gasoline_consumption;

insert into car_shop.brand (brand, id_country)
select
split_part(auto, ' ', 1) as brand , country.id
from raw_data.sales 
left join car_shop.country on country.brand_origin = sales.brand_origin
group by brand, country.id ;

insert into car_shop.car ( model, price, id_brand, id_characteristic)
select 
substring(auto, '([^ ]*)\,[^,]*$') as model , price ,
brand.id, characteristic_car.id
from raw_data.sales
left join car_shop.brand  on brand.brand = 
split_part(auto, ' ', 1) 
left join car_shop.characteristic_car on concat(characteristic_car.color, characteristic_car.gasoline_consumption) =
concat(split_part(auto, ',', 2), sales.gasoline_consumption)
group by brand.id,characteristic_car.id, model , price

insert into car_shop.sale (date, discount, id_car, id_buyer)
select date, discount, car.id, buyer.id
from raw_data.sales 
left join car_shop.car on concat((select brand from 
car_shop.brand where brand.id = car.id_brand), car.model, car.price) = 
concat(split_part(auto, ' ', 1), substring(auto, '([^ ]*)\,[^,]*$'), 
sales.price)
left join car_shop.buyer on concat(buyer.person_name, buyer.phone) =
concat(sales.person_name, sales.phone) 
group by car.id, buyer.id, date, discount

--Аналитические скрипты
--Задание 1
select  COUNT (CASE WHEN gasoline_consumption IS NULL THEN 1 END) * 100.0 / COUNT(*) AS percentage
from car_shop.characteristic_car cc

--Задание 2
select b.brand as brand_name,
extract (year from s.date) as years,
round (avg(c.price), 2) as price_avg
from car_shop.car c 
left join car_shop.brand b on c.id_brand = b.id 
left join car_shop.sale s on c.id  = s.id_car 
group by years, brand_name
order by brand_name;

--Задание 3
select
extract(month from s.date) as months,
extract(year from s.date) as years,
round(avg(c.price), 2) as price_avg
from car_shop.sale s
left join car_shop.car c on c.id = s.id_car
group by months, years
having extract(year from s.date) = 2022;

--Задание 4.
select
b2.person_name  as person,
string_agg(br.brand || ' ' || c.model, ', ') as cars
from car_shop.sale s
left join car_shop.buyer b2 on b2.id = s.id_buyer 
left join car_shop.car c on c.id = s.id_car 
left join car_shop.brand br on br.id = c.id_brand
group by person
order by person;

-- Задание 5.
select 
c.brand_origin,
max(c2.price) as price_max,
min(c2.price) as price_min
from car_shop.country c 
left join car_shop.brand b on b.id_country  = c.id 
left join car_shop.car c2 on c2.id_brand  = b.id 
group by brand_origin
order by brand_origin;

--Задание 6.
select count(*) as clients_from_usa_count
from car_shop.buyer b
where phone like '+1%'


select * from car_shop.sale s 