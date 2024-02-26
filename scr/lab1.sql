-- создание схемы raw_dataa
create schema raw_dataa;
-- создание таблицы с переменными
create table raw_dataa.sales (
id SERIAL PRIMARY KEY,
auto VARCHAR(255) not null,
gasoline_consumption FLOAT,
price FLOAT not null,
date DATE not null,
person_name VARCHAR(255) not null,
phone VARCHAR(255) not null,
discount int,
brand_origin VARCHAR(70)
);


-- заполнение таблицы данными из файла cars.csv
COPY raw_dataa.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin) 
FROM 'C:\Dbeaver\cars.csv'
WITH (format csv, HEADER, NULL 'null');


-- создание схемы car_shop
create schema car_shop;

-- создание таблиц
CREATE TABLE car_shop.model (
id SERIAL PRIMARY KEY, 
model VARCHAR(20) not null unique
);

CREATE TABLE car_shop.color (
id SERIAL PRIMARY KEY, 
color VARCHAR(20) not null unique
);

CREATE TABLE car_shop.country (
id SERIAL PRIMARY KEY, 
country VARCHAR(20) not null
);

CREATE TABLE car_shop.brand (
id SERIAL PRIMARY KEY, 
brand VARCHAR(20) not null,
id_country int references car_shop.country(id) on delete restrict
);

create table car_shop.Cars(
id serial primary key,
id_brand int references car_shop.brand(id)on delete restrict not null,
id_model int references car_shop.model(id)on delete restrict not null,
gasoline_consumption float check(gasoline_consumption between 0 and 50)
);

create table car_shop.complete_set(
id serial primary key,
id_Cars int references car_shop.Cars(id)on delete restrict not null,
id_color int references car_shop.color(id)on delete restrict not null
);


create table car_shop.buyers(
id serial primary key,
fio varchar(50) not null,
phone varchar(50) not null
);

create table car_shop.saless(
id serial primary key,
id_complete_set int references car_shop.complete_set (id)on delete restrict not null,
id_buyers int references car_shop.buyers(id)on delete restrict not null,
price float not null,
date_sales date not null,
discount int not null check(discount between 0 and 70)
);


-- заполнение таблиц с помощью insert into

insert into car_shop.country (country)
select brand_origin 
from raw_dataa.sales
group by brand_origin
having brand_origin is not null;


insert into car_shop.buyers (fio, phone)
select person_name, phone 
from raw_dataa.sales 
group by person_name, phone;


insert into car_shop.color (color)
select substring(auto from ', (.*)') as color
from raw_dataa.sales
group by color;


insert into car_shop.brand (brand, id_country)
select 
substring(auto from 1 for position(' ' in auto) - 1) as brand, 
country.id
from raw_dataa.sales
left join car_shop.country ON country.country = raw_dataa.sales.brand_origin
group by brand, country.id;


insert into car_shop.model (model)
select
substring(auto from position(' ' in auto) + 1 for position(',' in auto) - position(' ' in auto) - 1) as model
from raw_dataa.sales
group by model;


insert into car_shop.Cars (id_brand, id_model, gasoline_consumption)
select 
brand.id as b, 
model.id as c, 
gasoline_consumption
from raw_dataa.sales
left join car_shop.brand on brand.brand = substring(raw_dataa.sales.auto from 1 for position(' ' in raw_dataa.sales.auto) - 1) 
left join car_shop.model on model.model = substring(raw_dataa.sales.auto from position(' ' in raw_dataa.sales.auto) + 1 for position(',' in raw_dataa.sales.auto) - position(' ' in raw_dataa.sales.auto) - 1) 
group by b, c, gasoline_consumption;


insert into car_shop.complete_set (id_Cars, id_color)
select 
Cars.id as m,
color.id as n
from raw_dataa.sales
left join car_shop.color on color.color = substring(raw_dataa.sales.auto from ', (.*)') 
left join car_shop.Cars on concat((select brand from car_shop.brand where brand.id = Cars.id_brand), (select model from car_shop.model where model.id = Cars.id_model)) = concat(substring(raw_dataa.sales.auto from 1 for position(' ' in raw_dataa.sales.auto) - 1),substring(raw_dataa.sales.auto from position(' ' in raw_dataa.sales.auto) + 1 for position(',' in raw_dataa.sales.auto) - position(' ' in raw_dataa.sales.auto) - 1))
group by m, n;


insert into car_shop.saless (id_complete_set, id_buyers, price, date_sales, discount)
select 
complete_set.id, 
buyers.id, 
raw_dataa.sales.price,
raw_dataa.sales.date, 
raw_dataa.sales.discount
from raw_dataa.sales
left join car_shop.Cars on concat((select brand from car_shop.brand where brand.id = Cars.id_brand), (select model from car_shop.model where model.id = Cars.id_model)) = concat(substring(raw_dataa.sales.auto from 1 for position(' ' in raw_dataa.sales.auto) - 1),substring(raw_dataa.sales.auto from position(' ' in raw_dataa.sales.auto) + 1 for position(',' in raw_dataa.sales.auto) - position(' ' in raw_dataa.sales.auto) - 1))
left join car_shop.color on color.color = substring(raw_dataa.sales.auto from ', (.*)')
left join car_shop.complete_set on complete_set.id_color = color.id and complete_set.id_Cars = Cars.id 
left join car_shop.buyers on buyers.fio = raw_dataa.sales.person_name 
group by complete_set.id, buyers.id, raw_dataa.sales.price, raw_dataa.sales.date, raw_dataa.sales.discount;



-- Задание 1
--Напишите запрос, который выведет процент моделей машин, 
--у которых нет параметра gasoline_consumption.

select 100 - (count(gasoline_consumption) * 100) / count(*) as nulls_percentage_gasoline_consumption from car_shop.Cars;


-- Задание 2
--Напишите запрос, который покажет название бренда 
--и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки. 
--Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. 
--Среднюю цену округлите до второго знака после запятой.


select
br.brand as brand_naz, 
to_char(p.date_sales, 'YYYY-MM-DD') as date_sales_formatted, 
ROUND(AVG(price::numeric), 2) as price_avg
from car_shop.saless p
left join car_shop.complete_set com on com.id = p.id_complete_set
left join car_shop.Cars c on c.id = com.id_Cars
left join car_shop.brand br on br.id = c.id_brand
group by date_sales_formatted, brand_naz
order by brand_naz;


-- Задание 3
--Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. 
--Результат отсортируйте по месяцам в восходящем порядке. 
--Среднюю цену округлите до второго знака после запятой.


select 
extract(month from p.date_sales) as months,
extract(year from p.date_sales) as years, 
ROUND(AVG(price::numeric), 2) as price_avg
from car_shop.saless p 
group by months, years
having extract(year from p.date_sales) = 2022;



-- Задание 4
-- Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. 
-- Пользователь может купить две одинаковые машины — это нормально. 

select 
fio as person,
string_agg(br.brand || ' ' || mod.model, ', ') as cars
from car_shop.saless p
left join car_shop.buyers b on b.id = p.id_buyers
left join car_shop.complete_set com on com.id = p.id_complete_set
left join car_shop.Cars c on c.id = com.id_Cars
left join car_shop.brand br on br.id = c.id_brand 
left join car_shop.model mod on mod.id =c.id_model 
group by person
order by person;


-- Задание 5
-- Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
-- Цена в колонке price дана с учётом скидки.

select 
country as brand_origin,
min(price) as price_min,
max(price) as price_max
from car_shop.saless p
left join car_shop.complete_set com on com.id = p.id_complete_set 
left join car_shop.Cars c on c.id = com.id_Cars 
left join car_shop.brand br on br.id =c.id_brand 
left join car_shop.country st on st.id = br.id_country
group by brand_origin
having country is not null;


-- Задание 6
-- Напишите запрос, который покажет количество всех пользователей из США. 
-- Это пользователи, у которых номер телефона начинается на +1.

select count(*) as person_from_usa
from car_shop.saless p 
left join car_shop.buyers b on b.id = p.id_buyers 
where b.phone like '+1%' 
