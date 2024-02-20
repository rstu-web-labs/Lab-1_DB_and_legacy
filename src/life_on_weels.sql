create schema if not exists raw_data;

create table if not exists raw_data.sales (
	id smallint primary key,
	auto text,
	gasoline_consumption numeric,
	price numeric,
	date date,
	person_name text,
	phone text,
	discount smallint,
	brand_origin text
);

copy raw_data.sales 
from 'cars.csv' 
with csv header null 'null' delimiter ',';

select * from raw_data.sales s;

create  schema if not exists car_shop;

create table car_shop.colors (
	color_id serial primary key,
	color_name varchar(100) unique not null
);

create table car_shop.countries (
	country_id serial primary key,
	country_name varchar(100) unique
);

create table car_shop.car_brands (
	brand_id serial primary key,
	brand_name varchar(100) unique,
	country_id integer references car_shop.countries (country_id)
);

create table car_shop.car_models (
	model_id serial primary key,
	model_name varchar(100) not null,
	brand_id integer references car_shop.car_brands (brand_id) not null,
	gasoline_consumption numeric
);

create table car_shop.cars (
	car_id serial primary key,
	model_id integer references car_shop.car_models (model_id) not null,
	color_id integer references car_shop.colors (color_id),
	discount integer not null check (discount between 0 and 100),
	price integer check (price > 0)
);

create table car_shop.clients (
	client_id serial primary key,
	client_name varchar(255) not null, 
	phone_num varchar(30) unique not null
);

create table car_shop.car_sales (
	sale_id serial primary key,
	sale_date date not null,
	car_id integer references car_shop.cars (car_id) not null,
	client_id integer references car_shop.clients (client_id) not null
);

insert into car_shop.countries (country_name)
select distinct brand_origin from raw_data.sales

select * from car_shop.countries c;

insert into car_shop.colors (color_name)
select distinct trim(substring(auto, position(',' in auto) + 2))
from raw_data.sales

select * from car_shop.colors c;

insert into car_shop.car_brands (brand_name, country_id)
select distinct trim(substring(auto, 0, position(' ' in auto))), c.country_id
from raw_data.sales as s
left join car_shop.countries as c
on c.country_name = s.brand_origin;

select * from car_shop.car_brands cb;

insert into car_shop.car_models (model_name, brand_id, gasoline_consumption)
select distinct trim(split_part(substring(auto, position(' ' in auto)), ',', 1)),
cb.brand_id, s.gasoline_consumption 
from raw_data.sales as s
left join car_shop.car_brands as cb
on cb.brand_name = trim(substring(auto, 0, position(' ' in auto)));

select * from car_shop.car_models cm;

insert into car_shop.cars (model_id, color_id, discount, price)
select cm.model_id, c.color_id, s.discount, s.price from raw_data.sales as s
left join car_shop.car_models as cm 
on cm.model_name = trim(split_part(substring(auto, position(' ' in auto)), ',', 1))
left join car_shop.colors as c
on c.color_name = trim(substring(auto, position(',' in auto) + 2))

select * from car_shop.cars c;

insert into car_shop.clients (client_name, phone_num)
select distinct person_name, phone  from raw_data.sales;

select * from car_shop.clients c;

insert into car_shop.car_sales (sale_date, car_id, client_id)
select s."date", cars.car_id, clients.client_id from raw_data.sales as s
left join car_shop.cars as cars on s.id = cars.car_id
left join car_shop.clients as clients
on s.person_name = clients.client_name and s.phone = clients.phone_num;

select * from car_shop.car_sales cs;

-- task 1

select count(*)::numeric / (select count(*) from car_shop.car_models) * 100
from car_shop.car_models
where gasoline_consumption is null;

-- task 2

select cb.brand_name, 
extract(year from cs.sale_date)::varchar(4) as year, 
round(avg(cars.price), 2)
from car_shop.car_sales as cs
left join car_shop.cars as cars on cs.car_id = cars.car_id
left join car_shop.car_models as cm on cm.model_id = cars.model_id
left join car_shop.car_brands as cb on cb.brand_id = cm.brand_id
group by cb.brand_name, year
order by brand_name, year;

-- task 3

select
extract (month from sale_date)as month,
2022::varchar(4),
round(avg(cars.price), 2)
from car_shop.car_sales as cs
left join car_shop.cars as cars 
on cs.car_id = cars.car_id and extract(year from cs.sale_date) = 2022
group by month 
order by month;

-- task 4

select 
clients.client_name as client,
string_agg(concat_ws(' ', cb.brand_name, cm.model_name), ', ')
from car_shop.car_sales as cs
left join car_shop.cars as cars on cars.car_id = cs.car_id
left join car_shop.car_models as cm on cm.model_id = cars.model_id
left join car_shop.car_brands as cb on cm.brand_id = cb.brand_id
left join car_shop.clients as clients on cs.client_id = clients.client_id
GROUP BY client
ORDER BY client;

-- task 5

select 
countries.country_name as country,
min(cars.price),
max(cars.price)
from car_shop.cars as cars
left join car_shop.car_models as cm on cm.model_id = cars.model_id
left join car_shop.car_brands as cb on cm.brand_id = cb.brand_id
left join car_shop.countries as countries on countries.country_id = cb.country_id
GROUP BY country;

-- task 6

select count(*)
from car_shop.clients
where phone_num like '+1%';























