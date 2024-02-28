/*create schema raw_data;

create table raw_data.sales (
	id INT ,
	auto VARCHAR(50),
	gasoline_consumption NUMERIC,
	price NUMERIC,
	date DATE,
	person_name VARCHAR(50),
	phone VARCHAR(50),
	discount numeric,
	brand_origin VARCHAR(50)
);
*/
COPY raw_data.sales(id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin) FROM '/home/cars.csv' DELIMITER ',' CSV HEADER NULL 'null';


--select * from raw_data.sales s ;
/*
create schema car_shop;

create table car_shop.country (
	id serial primary key,
	brand_origin varchar(60) not null unique
);


create table car_shop.brand (
	id serial primary key,
	id_country int,
	brand varchar(50) not null unique,
	foreign key (id_country) references car_shop.country(id) on delete restrict
);

create table car_shop.model (
	id serial primary key,
	model varchar(50) not null unique
);

create table car_shop.color (
	id serial primary key,
	color varchar(50) not null unique
);

create table car_shop.cars (
	id serial primary key,
	id_brand int references car_shop.brand(id) on delete restrict,
	id_model int references car_shop.model(id) on delete restrict, 
	id_color int references car_shop.color(id) on delete restrict,
	gasoline_consumption numeric check (gasoline_consumption > 0 and gasoline_consumption<100 )
);

create table car_shop.clients(
	id serial primary key,
	name varchar(30) not null,
	surname varchar(30) not null,
	phone varchar(50) not null unique
);

create table car_shop.sales (
	id serial primary key,
	id_car int references car_shop.cars(id) on delete restrict,
	id_buyer int references car_shop.clients(id) on delete restrict,
	price numeric not null,
	discount numeric check(discount between 0 and 100),
	date date not null
);


-- заполнение данными новых таблиц
insert into car_shop.country  (brand_origin)
select brand_origin as brand_origin 
from raw_data.sales 
where brand_origin is not null
group by brand_origin ;


--select c.brand_origin  from car_shop.country c ;


insert into car_shop.brand(id_country, brand)
select distinct
case
    when s.brand_origin is null then null
    else c.id
  end as id_country,
  substring(s.auto, 1, position(' ' IN s.auto) - 1) as brand
from raw_data.sales s
left join car_shop.country c on c.brand_origin = s.brand_origin or s.brand_origin is null
group by c.id, brand, s.brand_origin, s.auto;

--select * from car_shop.brand b ;


insert into car_shop.model(model)
select SUBSTRING(auto, POSITION(' ' in auto) + 1, POSITION(',' in auto) - POSITION(' ' in auto) - 1) as model
from raw_data.sales 
group by model;

--select * from car_shop.model m ;

insert into car_shop.color(color)
select SUBSTRING(auto, POSITION(',' in auto) + 2) as color
from raw_data.sales 
group by color;

--select * from car_shop.color c ;


insert into car_shop.cars (id_brand, id_model, id_color, gasoline_consumption)
select b.id,  m.id, c.id, s.gasoline_consumption 
from raw_data.sales s
left join car_shop.brand b 
on b.brand = substring(s.auto, 1, position(' ' in s.auto) - 1) 
left join car_shop.model m 
on m.model  = substring (s.auto, position(' ' in s.auto) + 1, position(',' in s.auto) - position(' ' in s.auto) - 1)
left join car_shop.color c 
on c.color = substring(s.auto, position(',' in s.auto) + 2)
group by b.id,  m.id, c.id, s.gasoline_consumption ;

--select * from car_shop.cars c  ;

insert into car_shop.clients (name, surname, phone)
select 
substring(s.person_name, 1, position (' ' in s.person_name) - 1) as name,
substring(s.person_name, position (' ' in s.person_name) + 1) as surname,
s.phone  as phone
from raw_data.sales s
group by 
substring(s.person_name, 1, position (' ' in s.person_name) - 1),
substring(s.person_name, position (' ' in s.person_name) + 1),
s.phone ;

--select *  from car_shop.clients cl ;


insert into car_shop.sales(id_car, id_buyer, price, discount, "date")
select c.id , c3.id, s.price, s.discount , s."date"
from raw_data.sales s 
inner join car_shop.cars c on
	substring(s.auto, 1, position(' ' in s.auto) - 1) = (select brand from car_shop.brand where id = c.id_brand  ) and
	substring (s.auto, position(' ' in s.auto) + 1, position(',' in s.auto) - position(' ' in s.auto) - 1) = (select model from car_shop.model where id = c.id_model) and
	substring(s.auto, position(',' in s.auto) + 2) = (select color from car_shop.color where id = c.id_color) 
inner join car_shop.clients c3 on
	c3.phone = s.phone and c3."name"  = substring(s.person_name, 1, position (' ' in s.person_name) - 1) and
	c3.surname = substring(s.person_name, position (' ' in s.person_name) + 1);
	


--Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
select COUNT(*) * 100.0 / (select COUNT(*) from car_shop.cars) as nulls_percentage_gasoline_consumption
from car_shop.cars
where gasoline_consumption is null;


--Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки. 
--Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. 
--Среднюю цену округлите до второго знака после запятой. Формат итоговой таблицы:

select b.brand as brand_name,
extract (year from s.date) as year,
round(avg(s.price), 2) as price_avg
from car_shop.sales s 
join car_shop.cars c on c.id = s.id_car 
join car_shop.brand b on b.id = c.id_brand 
group by brand_name, year
order by brand_name, year;



--Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. 
--Результат отсортируйте по месяцам в восходящем порядке. Среднюю цену округлите до второго знака после запятой.
select 
	extract(month from s.date) as month,
	extract(year from s.date) as year,
	round(avg(s.price), 2) as price_avg
from car_shop.sales s 
where extract(year from s.date)=2022
group by month, year
order by extract(month from s.date);


---Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. 
---Пользователь может купить две одинаковые машины — это нормально. Название машины покажите полное, с названием бренда — например: Tesla Model 3. 
---Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.

select c."name" , c.surname ,
string_agg(b.brand || ' ' || m.model, ', ' ) as cars
from car_shop.sales s 
join car_shop.clients c  on c.id = s.id_buyer 
join car_shop.cars c2 on c2.id  = s.id_car 
join car_shop.brand b on b.id  = c2.id_brand 
join car_shop.model m on m.id  = c2.id_model 
group by c."name",c.surname 
order by c."name",c.surname;


--Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
--Цена в колонке price дана с учётом скидки.

select c2.brand_origin,
max(s.price) as price_max,
min (s.price) as price_min
from car_shop.sales s 
join car_shop.cars c on c.id = s.id_car 
join car_shop.brand b on b.id = c.id_brand 
left join car_shop.country c2 on c2.id = b.id_country
where c2.brand_origin is not null
group by  c2.brand_origin
order by c2.brand_origin;


--Напишите запрос, который покажет количество всех пользователей из США. 
--Это пользователи, у которых номер телефона начинается на +1.
select count(*) as persons_from_usa_count 
from car_shop.clients 
where phone like '+1%';
*/