----- создание схемы raw_data -----
create schema raw_data;

----- cоздание таблицы sales для сырых данных -----
create table raw_data.sales 
( id smallint primary key,
  auto varchar(255) not null,
  gasoline_consumption numeric(4,2) check (gasoline_consumption < 100),
  price numeric(50, 20),
  date date,
  person_name varchar(255) not null,
  phone varchar(255),
  discount numeric(4,2) check (discount >= 0),
  brand_origin varchar(255) 
	check (brand_origin in ('Russia', 'Germany', 'South Korea', 'USA')));

--заполнение таблицы sales данными
copy raw_data.sales 
from '\cars.csv' 
with csv header null 'null' delimiter ',';

----- cоздание схемы car_shop для нормализованной БД -----
create schema car_shop;

---создание и заполнение таблицы стран country
create table car_shop.country (
	id_country serial primary key,
	brand_origin varchar(255));

insert into car_shop.country  (brand_origin)
select distinct brand_origin from raw_data.sales;

---создание и заполнение таблицы цветов color
create table car_shop.color (
	id_color serial primary key,
	name_color varchar(255));

insert into car_shop.color  (name_color)
select distinct substring(auto, position (',' in auto) + 2 )  from raw_data.sales;

---создание и заполнение таблицы клиентов people
create table car_shop.people (
	id_person serial primary key,
	name_person varchar(255),
	phone varchar(255));

insert into car_shop.people  (name_person, phone)
select distinct person_name, phone  from raw_data.sales;

---создание и заполнение таблицы брендов brand связанной вторичным ключом id_country с таблицей country
create table car_shop.brand (
	id_brand serial primary key,
	id_country int,
	name_brand varchar(255),
	constraint fk_constraint_country foreign key (id_country) 
		references car_shop.country(id_country));

insert into car_shop.brand (name_brand, id_country)
select distinct substring(auto, 1, position(' ' in auto) - 1), 
coalesce(c.id_country, (select  id_country from  car_shop.country where brand_origin is null))
from raw_data.sales s
left join car_shop.country c on c.brand_origin = s.brand_origin;


---создание и заполнение таблицы моделей машин model_car
create table car_shop.model_car (
	id_model serial primary key,
	id_brand int,
	name_model varchar(255),
	gasoline_consumption numeric(4,2) check (gasoline_consumption < 100),
	constraint fk_constraint_brand foreign key (id_brand)
	references car_shop.brand(id_brand));

insert into car_shop.model_car (id_brand, name_model, gasoline_consumption)
select distinct b.id_brand, 
substring(s.auto, position(' ' in s.auto)+1, position(',' in s.auto)-position(' ' in s.auto)-1), 
s.gasoline_consumption
from raw_data.sales s
join car_shop.brand b on b.name_brand = substring(s.auto, 1, position(' ' in s.auto)-1); 

---создание и заполнение таблицы cars 
create table car_shop.cars (
	id_car serial primary key,
	id_color int, 
	id_model int,
	constraint fk_constraint_color foreign key (id_color)
	references car_shop.color(id_color),
	constraint fk_constraint_model foreign key (id_model)
	references car_shop.model_car(id_model)
	);

insert into car_shop.cars (id_model, id_color)
select distinct mc.id_model, c.id_color
from raw_data.sales s
join car_shop.model_car mc on mc.name_model = (select substring(s.auto, position(' ' in s.auto)+1, position(',' in s.auto)-position(' ' in s.auto)-1))
join car_shop.color c on c.name_color = (select substring(auto, position (',' in auto) + 2 ))
left join car_shop.cars ca on ca.id_model = mc.id_model and ca.id_color = c.id_color
where ca.id_model is null;

---создание и заполнение таблицы покупок purchases
create table car_shop.purchases (
	id_purchases serial primary key,
	id_car int, 
	id_person int,
	date_purch date,
	price numeric(50, 20),
	discount numeric(4,2) check (discount >= 0),
	constraint fk_constraint_people foreign key (id_person)
	references car_shop.people(id_person),
	constraint fk_constraint_car foreign key (id_car)
	references car_shop.cars(id_car));

insert into car_shop.purchases (id_person, id_car, date_purch, price, discount)
select distinct p.id_person, c.id_car, s.date, s.price, s.discount
from raw_data.sales s
join car_shop.people p on p.name_person = s.person_name
join car_shop.cars c on c.id_model = (
    select id_model
    from car_shop.model_car mc
    where mc.name_model = substring(s.auto, position(' ' in s.auto)+1, position(',' in s.auto)-position(' ' in s.auto)-1)
)
join car_shop.color col on col.name_color = substring(auto, position (',' in auto) + 2)
where c.id_color = col.id_color;

----- создание нормализованной БД завершено -----


-------------------------------
---- аналитические скрипты ----
-------------------------------

--- Задание №1
Напишите запрос, который выведет процент моделей машин, у которых 
нет параметра gasoline_consumption.
--- скрипт
select 100.0 * count(*) / (select count(*) from car_shop.model_car) 
as nulls_percentage_gasoline_consumption 
from car_shop.model_car
where gasoline_consumption is null;
--- вывод:
nulls_percentage_gasoline_consumption
21.0526315789473684

--- Задание №2
Напишите запрос, который покажет название бренда и среднюю цену его автомобилей 
в разбивке по всем годам с учётом скидки. 
Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. 
Среднюю цену округлите до второго знака после запятой. 
--- скрипт
select b.name_brand as  brand_name, 
extract(year from p.date_purch) as year, 
round(avg(p.price), 2) as price_avg from car_shop.purchases p
join car_shop.cars c on c.id_car = p.id_car
join car_shop.model_car mc on mc.id_model = c.id_model
join car_shop.brand b on b.id_brand = mc.id_brand
group by b.name_brand, year
order by brand_name, year asc;

--- Задание №3
Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. 
Результат отсортируйте по месяцам в восходящем порядке. 
Среднюю цену округлите до второго знака после запятой.
--- скрипт
select extract(month from p.date_purch) as month,
       extract(year from p.date_purch) as year,
       round(avg(p.price), 2) as price_avg
from car_shop.purchases p
where extract(year from p.date_purch) = 2022
group by extract(month from p.date_purch), extract(year from p.date_purch)
order by extract(month from p.date_purch) asc;

--- Задание №4
Используя функцию STRING_AGG, напишите запрос, который выведет 
список купленных машин у каждого пользователя через запятую. 
Пользователь может купить две одинаковые машины — это нормально. 
Название машины покажите полное, с названием бренда — например: Tesla Model 3. 
Отсортируйте по имени пользователя в восходящем порядке. 
Сортировка внутри самой строки с машинами не нужна.
--- скрипт
select p.name_person as person,
       STRING_AGG(b.name_brand || ' ' || mc.name_model, ', ') as cars
from car_shop.people p
join car_shop.purchases pc on pc.id_person = p.id_person
join car_shop.cars c on c.id_car = pc.id_car
join car_shop.model_car mc on mc.id_model = c.id_model
join car_shop.brand b on b.id_brand = mc.id_brand
group by p.id_person, p.name_person
order by p.name_person asc;

--- Задание №5
Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля 
с разбивкой по стране без учёта скидки. Цена в колонке price дана с учётом скидки.
--- скрипт
select co.brand_origin, 
round(MAX(p.price * 100 / (100 - p.discount)), 2) as price_max, 
round(MIN(p.price * 100 / (100 - p.discount)), 2) as price_min
from car_shop.purchases p
join car_shop.cars c on c.id_car = p.id_car
join car_shop.model_car mc on mc.id_model = c.id_model
join car_shop.brand b on b.id_brand = mc.id_brand
join car_shop.country co on co.id_country = b.id_country
group by co.brand_origin;
--- вывод:
brand_origin price_max price_min
	92512.10	29705.40
USA	80663.38	20488.65
Germany	72666.75	11134.26
South Korea	60255.00	9846.75
Russia	25924.80	6198.60

--- Задание №6
Напишите запрос, который покажет количество всех пользователей из США. 
Это пользователи, у которых номер телефона начинается на +1.
--- скрипт
select count(*) as persons_from_usa_count from car_shop.people 
where phone like('+1%');