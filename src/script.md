create schema raw_data;

create table sales(
id integer primary key,
auto varchar(30),
gasoline_consumption float,
price float,
date date,
person_name varchar(30),
phone varchar(30),
discount integer,
brand_origin varchar(30)
);

copy sales (id,auto,gasoline_consumption,price,date,person_name,phone,discount,brand_origin) from 'D:\\cars.csv' delimiter ',' csv header null 'null';


create schema car_shop;
SET search_path TO car_shop;

create table country (
id_country serial primary key,
country varchar not null
);

create table brand (
id_brand serial primary key,
brand varchar not null,
id_country int references country(id_country)
);

create table color (
id_color serial primary key,
color varchar not null
);

create table car (
id_car serial primary key,
model varchar,
gasoline_consumption float check (gasoline_consumption > 0),
id_brand int references brand(id_brand),
id_color int references color(id_color)
);

create table person (
id_person serial primary key,
name varchar not null,
phone varchar not null
);

create table sales (
id_sales serial primary key,
id_car int references car(id_car),
date date not null,
price float check (price > 0),
discount float check (discount >= 0),
id_person int references person(id_person)
);

insert into country (country)
select brand_origin
from raw_data.sales
group by brand_origin
having brand_origin is not null;

insert into brand (brand, id_country)
select
substring(auto from 1 for position(' ' in auto) - 1) as brand,
coalesce(country.id_country, NULL) as id_country
from raw_data.sales
left join country on country.country = raw_data.sales.brand_origin
group by brand, id_country;


insert into color(color)
select
substring(auto from position(',' in auto)+ 2) as color
from raw_data.sales
group by color;

insert into car (model, id_brand, id_color,gasoline_consumption)
select
substring(auto from position(' ' in auto) + 1 for position(',' in auto) - position(' ' in auto) - 1) as model,
brand.id_brand,
color.id_color,
raw_data.sales.gasoline_consumption
from
raw_data.sales
join
brand on brand.brand = substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1)
join
color on color.color = substring (raw_data.sales.auto from position(',' in raw_data.sales.auto)+ 2)
group by
model, id_brand, id_color,gasoline_consumption;

insert into person (name, phone)
select person_name, phone
from raw_data.sales
group by person_name, phone;


insert into sales ( id_car, id_person, price, date, discount)
select
car.id_car,
person.id_person,
raw_data.sales.price,
raw_data.sales.date,
raw_data.sales.discount
from raw_data.sales
left join car on concat((select brand from brand where id_brand = car.id_brand), car.model, (select color from color where id_color = car.id_color)) = concat(substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from position(' ' in raw_data.sales.auto) + 1 for position(',' in raw_data.sales.auto) - position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from ', (.*)') )
left join person on person.name = raw_data.sales.person_name
group by car.id_car, person.id_person, raw_data.sales.price, raw_data.sales.date, raw_data.sales.discount;


--1
select
(count(*) filter (where car.gasoline_consumption is null) * 100.0 / count(*)) as percentage_models_without_gasoline_consumption
from
car;

--2
select
brand.brand as brand_name,
extract(year from sales.date) as year,
round(avg(sales.price)::numeric, 2) as price_avg
from
brand
join car on brand.id_brand = car.id_brand
join sales on car.id_car = sales.id_car
group by
brand.brand, extract(year from sales.date)
order by
brand.brand asc, year asc;

--3
select
extract(month from sales.date) as month,
extract(year from sales.date) as year,
round(avg(sales.price::numeric), 2) as price_avg
from
sales
where
extract(year from sales.date) = 2022
group by
extract(month from sales.date), extract(year from sales.date)
order by
extract(month from sales.date) asc;

--4
select
person.name as person,
string_agg(brand.brand || ' ' || car.model, ', ') as cars
from
person
join sales on person.id_person = sales.id_person
join car on sales.id_car = car.id_car
join brand on car.id_brand = brand.id_brand
group by
person.name
order by
person.name asc;

--5
select
country.country as brand_origin,
max(sales.price) as price_max,
min(sales.price) as price_min
from
brand
join country on brand.id_country = country.id_country
join car on brand.id_brand = car.id_brand
join sales on car.id_car = sales.id_car
group by
country.country
order by
country.country;

--6
select
count(*) as persons_from_usa_count
from
person
where
phone like '+1%';

