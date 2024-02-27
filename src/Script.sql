-- Создание БД и схемы через скрипт --

create database life_on_wheels;

create schema raw_data;

-- Создание таблицы для копирования данных --

create table raw_data.sales(
id int primary key not null, -- Пояснение: первичный ключ, запрщены пустые переменные --
auto varchar(100) not null,
gasoline_consumption float,
price float not null,
datе date not null,
person_name varchar(100) not null,
phone varchar(100) not null,
discount int,
brand_origin varchar(100)
);

-- Скрипт для копирования данных --

copy raw_data.sales(
id, auto, gasoline_consumption, price, datе, person_name, phone, discount, brand_origin)
from 'D:\cars.csv' delimiter ',' csv header null 'null'; -- delimiter - разделитель, header - имена столбцов --

create schema car_shop;

-- Создание и заполнение таблиц --

-- 1 --

create table car_shop.model(
id serial primary key, -- Сделал здесь и далее везде serial вместо int потому что выдавал ошибку при вставке данных --
model varchar(20) not null unique
);

insert into car_shop.model (model)
select substring(auto from position(' ' in auto) + 1 for position(',' in auto) - position(' ' in auto) - 1) as model -- Ориентир "запятая" и "пробел" --
from raw_data.sales
group by model;

-- 2 --

create table car_shop.color(
id serial primary key,
color varchar(20) not null unique
);

insert into car_shop.color (color)
select substring(auto from ', (.*)') as color
from raw_data.sales
group by color;

-- 3 --

create table car_shop.country(
id serial primary key,
country varchar(20) not null unique
);

insert into car_shop.country(country)
select brand_origin
from raw_data.sales
group by brand_origin
having brand_origin is not null;

-- 4 --

create table car_shop.brand(
id serial primary key,
brand varchar(20) not null,
id_country int references car_shop.country(id) on delete restrict
);

insert into car_shop.brand (brand, id_country)
select substring(auto from 1 for position(' ' in auto) - 1) as brand,
country.id
from raw_data.sales
left join car_shop.country ON country.country = raw_data.sales.brand_origin
group by brand, country.id;

-- 5 --

create table car_shop.client(
id serial primary key,
name varchar(50),
phone varchar(50)
);

insert into car_shop.client (name, phone)
select person_name, phone
from raw_data.sales
group by person_name, phone;

-- Создание запросов --

-- 1 --

SELECT COUNT(CASE WHEN gasoline_consumption IS NULL THEN 1 END) * 100.0 / COUNT(*) AS percentage_null
FROM raw_data.sales;

-- 2 --
-- Для этого задания потребовались отдельные таблицы, они были созданы и заполнены --

create table car_shop.cars(
id serial primary key,
id_model int references car_shop.model(id) on delete restrict,
id_brand int references car_shop.brand(id) on delete restrict,
id_color int references car_shop.color(id) on delete restrict,
gasoline_consumption float check(gasoline_consumption between 0 and 99)
);

create table car_shop.sales(
id serial primary key,
id_client int references car_shop.client(id) on delete restrict,
id_set int references car_shop.cars(id) on delete restrict,
price numeric not null,
datе date not null,
discount float not null
);

insert into car_shop.cars (id_brand, id_model, id_color, gasoline_consumption)
select car_shop.brand.id as b,
car_shop.model.id as m,
car_shop.color.id as c,
gasoline_consumption
from raw_data.sales
left join car_shop.brand on brand.brand = substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1)
left join car_shop.model on model.model = substring(raw_data.sales.auto from position(' ' in raw_data.sales.auto) + 1 for position(',' in raw_data.sales.auto) - position(' ' in raw_data.sales.auto) - 1)
left join car_shop.color on color.color = substring(raw_data.sales.auto from ', (.*)')
group by b, m, c, gasoline_consumption;

insert into car_shop.sales (id_client, id_set, price, datе, discount)
select
client.id,
cars.id,
raw_data.sales.price,
raw_data.sales.datе,
raw_data.sales.discount
from
raw_data.sales
left join car_shop.cars on concat((select brand from car_shop.brand where brand.id = cars.id_brand), 
(select model from car_shop.model where model.id = cars.id_model), 
(select color from car_shop.color where color.id = cars.id_color)) = concat(substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1),substring
(raw_data.sales.auto from position(' ' in raw_data.sales.auto) + 1 for position(',' in raw_data.sales.auto) - position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from ', (.*)'))
left join car_shop.client on client.name = raw_data.sales.person_name
group by cars.id, client.id, raw_data.sales.price, raw_data.sales.discount, raw_data.sales.datе;

select
b.brand as brand_name,
extract(year from s.datе) as years,
avg(s.price) as price_avg
from car_shop.sales s
left join car_shop.cars c on c.id = s.id_set
left join car_shop.brand b on c.id_brand = b.id
group by years, brand_name
order by brand_name;

-- 3 --

select
extract(month from s.datе) as months,
extract(year from s.datе) as years,
round(avg(price), 2) as price_avg
from car_shop.sales s
group by months, years
having extract(year from s.datе) = 2022;

-- 4 --

select
name as person,
string_agg(b.brand || ' ' || m.model, ', ') as cars
from car_shop.sales s
left join car_shop.client c on c.id = s.id_client
left join car_shop.cars st on st.id = s.id_set
left join car_shop.model m on m.id = st.id_model
left join car_shop.brand b on b.id = st.id_brand
group by person
order by person;

-- 5 --

select
c.country as brand_origin,
max(s.price / (1 - s.discount / 100.0)) as price_max,
min(s.price / (1 - s.discount / 100.0)) as price_min
from car_shop.sales s
left join car_shop.cars s2 on s2.id = s.id_set
left join car_shop.brand b on b.id = s2.id_brand
left join car_shop.country c on c.id = b.id_country
group by brand_origin, c.country
having c.country is not null;

-- 6 --

select count(*) as clients_from_usa_count
from car_shop.client
where phone like '+1%'