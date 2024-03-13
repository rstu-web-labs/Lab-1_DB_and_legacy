create schema if not exists raw_data;

create table if not exists raw_data.sales (
id int primary key not null,
auto varchar(40) not null,
gasoline_consumption numeric null check (gasoline_consumption >= 0),
price numeric not null check (price >= 0),
date date not null,
person_name varchar(50) not null,
phone varchar(30) not null,
discount numeric null check (discount >= 0),
brand_origin varchar(60) null
);

copy raw_data.sales(id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
from '/home/cars.csv' delimiter ',' csv header null 'null';

create schema if not exists car_shop;

create table if not exists car_shop.colors (
idColor serial primary key,
color varchar(20) unique not null
);

create table if not exists car_shop.marks(
idMarka serial primary key,
marka varchar(30) unique not null 
);

create table if not exists car_shop.country (
idCountry serial primary key,
country varchar(60) unique not null
);


create table if not exists car_shop.models(
idModel serial primary key,
model varchar(30) unique not null,
gasoline_consumption numeric(3, 1) unique null check (gasoline_consumption >= 0)
);

create table if not exists car_shop.cars(
idCars serial primary key,
idColor int not null references car_shop.colors(idColor) ON DELETE RESTRICT,
idMarka int not null references car_shop.marks(idMarka) ON DELETE RESTRICT,
idModel int not null references car_shop.models(idModel) ON DELETE RESTRICT,
idCountry int references car_shop.country(idCountry)
);

create table if not exists car_shop.clients (
idClient serial primary key,
person_name varchar(50) not null,
phone varchar(30) not null
);

create table if not exists car_shop.sales(
idSales serial primary key,
idClient int not null references car_shop.clients(idClient) ON DELETE RESTRICT,
price numeric(7, 2) not null check (price >= 0),
discount numeric(2, 0) null check (discount >= 0),
date date not null
);

create table if not exists car_shop.autoInfo (
idAuto serial primary key,
idCars int not null references car_shop.cars(idCars) ON DELETE RESTRICT ,
idSales int not null references car_shop.sales(idSales) ON DELETE RESTRICT
);

insert into car_shop.colors(color)
select distinct split_part(auto, ',', 2)
from raw_data.sales;

insert into car_shop.clients(person_name, phone)
select distinct person_name, phone
from raw_data.sales;

insert into car_shop.marks(marka) 
select distinct split_part(auto, ' ', 1)
from raw_data.sales;

insert into car_shop.country(country)
select distinct brand_origin
from raw_data.sales
where brand_origin is not null;

insert into car_shop.models(model, gasoline_consumption) 
select distinct trim(substring(auto, char_length(split_part(auto, ' ', 1)) + 1, char_length(auto) - char_length(split_part(auto, ' ', 1)) - char_length(split_part(auto, ',', 2)) - 1)), gasoline_consumption
from raw_data.sales;

insert into car_shop.cars (idColor, idMarka, idModel, idCountry)
select distinct col.idColor, mar.idMarka, md.idModel, co.idCountry
from raw_data.sales sal
join car_shop.colors col on col.color = split_part(sal.auto, ',', 2)
join car_shop.marks mar on mar.marka = split_part(sal.auto, ' ', 1)
join car_shop.models md on md.model = trim(substring(sal.auto, char_length(split_part(sal.auto, ' ', 1)) + 1, char_length(sal.auto) - char_length(split_part(sal.auto, ' ', 1)) - char_length(split_part(sal.auto, ',', 2)) - 1))
left join car_shop.country co on sal.brand_origin = co.country;

insert into car_shop.sales (price, discount, date, idClient)
select distinct price, discount, date, c.idClient
from raw_data.sales s
join car_shop.clients c on s.phone = c.phone;

insert into car_shop.autoInfo (idCars, idSales)
select b.idCars, s2.idSales
from raw_data.sales s 
join car_shop.cars b on 
trim(split_part(s.auto, ' ', 1)) = trim((select marka from car_shop.marks m where m.idmarka = b.idmarka)) and
trim(split_part(s.auto, ',', 2)) = trim((select color from car_shop.colors c2 where c2.idcolor = b.idcolor)) and
trim(substring(auto, char_length(split_part(auto, ' ', 1)) + 1, char_length(auto) - char_length(split_part(auto, ' ', 1)) - char_length(split_part(auto, ',', 2)) - 1)) = trim((select model from car_shop.models m where m.idmodel = b.idmodel))
join car_shop.sales s2 on s.price  = s2.price and s."date" = s2."date";

-- Аналитические скрипты


--Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
select count(*) * 100.0 / (select count(*) from car_shop.cars) as nulls_percentage_gasoline_consumption
from car_shop.models m 
where gasoline_consumption is null;

--Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
--Итоговый результат отсортируйте по названию бренда и году в восходящем порядке.
--Среднюю цену округлите до второго знака после запятой. Формат итоговой таблицы:
select
    m.marka as "brand_name",
    extract(year from s."date") as "year",
    round(avg(s.price * (1 - s.discount / 100)), 2) AS "price_avg"
from car_shop.autoInfo a
join car_shop.cars b ON a.idCars = b.idCars
join car_shop.sales s ON a.idSales = s.idSales
join car_shop.marks m ON b.idMarka = m.idMarka
group by m.marka, EXTRACT(YEAR FROM s."date")
order by m.marka ASC, "price_avg" ASC;

-- Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
-- Результат отсортируйте по месяцам в восходящем порядке.
-- Среднюю цену округлите до второго знака после запятой.
select
    extract(MONTH from s."date") as month,
    extract(YEAR from s."date") as "year",
    round(avg(s.price * (1 - s.discount / 100)), 2) as average_price
from car_shop.sales s
where extract(YEAR from s."date") = 2022
group by extract(MONTH from s."date"), extract(YEAR from s."date")
order by month asc;

   
   --Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. 
--Пользователь может купить две одинаковые машины — это нормально. Название машины покажите полное, с названием бренда — например: 
--Tesla Model 3. Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.
select
    c.person_name as "person",
    string_agg(concat(m.marka, ' ', md.model), ', ') as "cars"
from car_shop.sales s
join car_shop.autoInfo a on s.idSales = a.idSales
join car_shop.clients c on s.idClient = c.idClient
join car_shop.cars b on a.idCars = b.idCars
join car_shop.marks m on b.idMarka = m.idMarka
join car_shop.models md on b.idModel = md.idModel
group by c.person_name
order by c.person_name asc;




--Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
--Цена в колонке price дана с учётом скидки.
select
    co.country as "brand_origin",
    MAX(s.price) as "price_max",
    MIN(s.price) as "price_min"
from car_shop.autoInfo a
join car_shop.sales s on a.idSales = s.idSales
left join car_shop.country co on a.idCars = co.idCountry
group by co.country;





   --Напишите запрос, который покажет количество всех пользователей из США. 
--Это пользователи, у которых номер телефона начинается на +1.
select count(*) AS usa_users_count
from car_shop.clients
where phone LIKE '+1%';
