create schema sales;

create table sales(
id SERIAL primary key,
auto varchar(30),
gasoline_consumption float,
price numeric,
date date,
person varchar(30),
phone varchar(30),
discount smallint,
brand_origin varchar(30)
);

copy sales
from 'C:/cars.csv'
with csv header
null 'null';

create schema car_shop;

create table car_shop.vendors 
(
id serial primary key not null,
vendor_name varchar(30),
vendor_country varchar(50) unique
);

create table car_shop.models
(
id serial not null primary key,
vendor_id int references car_shop.vendors(id),
model_name varchar (50),
gasoline_consumption numeric(18,2) 
(gasoline_consumption >= 0 and gasoline_consumption <= 99.9) default null
);

create table car_shop.colors(
id serial not null primary key,
color_name varchar(255) unique
);

create table car_shop.customers(
id serial not null primary key,
person_name varchar(255),
phone_number varchar(30)
);

create table car_shop.deals 
(
id serial not null primary key,
customer_id int references car_shop.customers(id),
model_id int references car_shop.models(id) on delete cascade,
color_id int references car_shop.colors(id) on delete cascade,
price numeric,
discount smallint,
date date
);

insert into car_shop.customers (person_name , phone_number)
select distinct person, phone
from sales.sales;

insert into car_shop.colors (color_name)
select distinct 
	split_part (auto, ',', 2)
from sales.sales;

insert into car_shop.vendors ( vendor_country, vendor_name)
select distinct 
	brand_origin, 
	split_part (auto, ' ', 1) 
from sales.sales;

insert into car_shop.models (vendor_id, model_name, gasoline_consumprion)
select distinct 
	b.id,
	substring(auto from position (' ' in auto) + 1 for position(',' in auto) - position(' ' in auto)-1),
	gasoline_consumption 
from sales.sales s  
join car_shop.vendors b on split_part(s.auto, ' ', 1) = b.vendor_name;

insert into car_shop.deals (customer_id, model_id, color_id, price, discount, date)
select distinct 
	cus.id,
	m.id,
	c.id,
	price,
	discount, 
	date
from sales.sales s 
join car_shop.colors c on c.color_name  = split_part(s.auto, ',', 2) 
join car_shop.models m on m.model_name = substring(auto from position (' ' in auto) + 1 for position(',' in auto) - position(' ' in auto)-1)
join car_shop.customers cus on cus.person_name = s.person; 


--задание 1
select 
	count(*)*100.0/(select count(*) from car_shop.models)  as nulls_percentage_gasoline_consumption
from 
	car_shop.models m 
where 
	gasoline_consumprion is null;
	
--задание 2
select 
	v.vendor_name as vendor_name,
	extract (year from d."date") as years,
	round(avg(d.price),2) as average_price
from car_shop.deals d 
join car_shop.models m on m.id = d.model_id 
join car_shop.vendors v on v.id = m.vendor_id 
group by  vendor_name, years
order by vendor_name;

--задание 3
select 
	extract (month from d."date") as months,
	extract (year from d."date") as years,
	round(avg(d.price),2) as average_price
from car_shop.deals d 
group by years, months 
order by years, months;

--задание 4
select 
	c.person_name as person, 
	--m.model_name as m,
	--v.vendor_name as v
	string_agg(v.vendor_name || ' ' || m.model_name, ', ')
from car_shop.deals d 
join car_shop.customers c on c.id = d.customer_id 
join car_shop.models m on m.id = d.model_id 
join car_shop.vendors v on v.id = m.vendor_id 
group by person
order by person;

--задание 5
select 
	v.vendor_country as country,
	min(d.price/(1-d.discount/100)) as min_price,
	max(d.price/(1-d.discount/100)) as max_price
from car_shop.deals d 
join car_shop.models m on m.id = d.model_id 
join car_shop.vendors v on v.id = m.vendor_id 
group by country


--задание 6
select
count(*) as persons_from_usa_count
from car_shop.customers
where phone_number like '+1%';
