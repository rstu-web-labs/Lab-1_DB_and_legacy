create schema if not exists raw_data;

create table if not exists raw_data.sales (
id int primary key not null,
auto varchar(40) not null,
gasoline_consumption numeric null,
price numeric not null,
date date not null,
person_name varchar(50) not null,
phone varchar(30) not null,
discount int null,
brand_origin varchar(60) null
);

copy raw_data.sales(id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
from '/home/cars.csv' delimiter ',' csv header null 'null';

create schema if not exists car_shop;

create table if not exists car_shop.colors (
idColor serial primary key,
color varchar(20) null
);

create table if not exists car_shop.marks(
idMarka serial primary key,
marka varchar(30) not null 
);

create table if not exists car_shop.models(
idModel serial primary key,
model varchar(30) not null 
);

create table if not exists car_shop.brends(
idBrend serial primary key,
idColor int not null references car_shop.colors(idColor),
idMarka int not null references car_shop.marks(idMarka),
idModel int not null references car_shop.models(idModel),
gasoline_consumption numeric null
);

create table if not exists car_shop.clients (
idClient serial primary key,
person_name varchar(50) not null,
phone varchar(30) not null
);

create table if not exists car_shop.sales(
idSales serial primary key,
price numeric not null,
discount int null,
date date not null
);

create table if not exists car_shop.country (
idCountry serial primary key,
country varchar(50) null
);

create table if not exists car_shop.auto (
idAuto serial primary key,
idBrend int not null references car_shop.brends(idBrend),
idSales int not null references car_shop.sales(idSales),
idClient int not null references car_shop.clients(idClient),
idCountry int  references car_shop.country(idCountry)
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

insert into car_shop.models(model) 
select distinct trim(substring(auto, char_length(split_part(auto, ' ', 1)) + 1, char_length(auto) - char_length(split_part(auto, ' ', 1)) - char_length(split_part(auto, ',', 2)) - 1))
from raw_data.sales;

insert into car_shop.brends (idColor, idMarka, idModel, gasoline_consumption)
select distinct col.idColor, mar.idMarka, md.idModel, sal.gasoline_consumption
from raw_data.sales sal
join car_shop.colors col on col.color = split_part(sal.auto, ',', 2)
join car_shop.marks mar on mar.marka = split_part(sal.auto, ' ', 1)
join car_shop.models md on md.model = trim(substring(sal.auto, char_length(split_part(sal.auto, ' ', 1)) + 1, char_length(sal.auto) - char_length(split_part(sal.auto, ' ', 1)) - char_length(split_part(sal.auto, ',', 2)) - 1));

insert into car_shop.sales (price, discount, date)
select distinct price, discount, date
from raw_data.sales;

insert into car_shop.country(country)
select distinct brand_origin
from raw_data.sales;

insert into car_shop.auto (idBrend, idSales, idClient, idCountry)
select b.idBrend, s2.idSales, c.idClient, co.idCountry
from raw_data.sales s 
join car_shop.clients c on s.phone = c.phone 
join car_shop.brends b on 
trim(split_part(s.auto, ' ', 1)) = trim((select marka from car_shop.marks m where m.idmarka = b.idmarka)) and
trim(split_part(s.auto, ',', 2)) = trim((select color from car_shop.colors c2 where c2.idcolor = b.idcolor)) and
trim(substring(auto, char_length(split_part(auto, ' ', 1)) + 1, char_length(auto) - char_length(split_part(auto, ' ', 1)) - char_length(split_part(auto, ',', 2)) - 1)) = trim((select model from car_shop.models m where m.idmodel = b.idmodel))
join car_shop.sales s2 on s.price  = s2.price and s."date" = s2."date"
left join car_shop.country co on s.brand_origin = co.country;

-- Аналитические скрипты


--Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
select count(*) * 100.0 / (select count(*) from car_shop.brends) as nulls_percentage_gasoline_consumption
from car_shop.brends
where gasoline_consumption is null;

--Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
--Итоговый результат отсортируйте по названию бренда и году в восходящем порядке.
--Среднюю цену округлите до второго знака после запятой. Формат итоговой таблицы:
select
    m.marka as "brand_name",
    extract(year from s."date") as "year",
    round(avg(s.price * (1 - s.discount / 100)), 2) AS "price_avg"
from car_shop.auto a
join car_shop.brends b ON a.idBrend = b.idBrend
join car_shop.sales s ON a.idSales = s.idSales
join car_shop.marks m ON b.idMarka = m.idMarka
group by m.marka, EXTRACT(YEAR FROM s."date")
order by m.marka ASC, "price_avg" ASC;


--Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
--Результат отсортируйте по месяцам в восходящем порядке. 
--Среднюю цену округлите до второго знака после запятой.
select
    extract(MONTH from date) as month,
    extract(YEAR from date) as "year",
    round(avg(price * (1 - discount / 100)), 2) as average_price
from raw_data.sales
where extract(YEAR from date) = 2022
group by extract(MONTH from date), extract(YEAR from date)
order by month asc;

   
   --Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. 
--Пользователь может купить две одинаковые машины — это нормально. Название машины покажите полное, с названием бренда — например: 
--Tesla Model 3. Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.
select
    c.person_name as "person",
    string_agg(concat(m.marka, ' ', md.model), ', ') as "cars"
from car_shop.auto a
join car_shop.clients c on a.idClient = c.idClient
join car_shop.brends b on a.idBrend = b.idBrend
join car_shop.marks m on b.idMarka = m.idMarka
join car_shop.models md on b.idModel = md.idModel
group by c.person_name
order by c.person_name asc;




--Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
--Цена в колонке price дана с учётом скидки.
select
    co.country as "brand_origin",
    max(s.price) as "price_max",
    min(s.price) as "price_min"
from car_shop.auto a
join car_shop.sales s on a.idSales = s.idSales
left join car_shop.country co on a.idCountry = co.idCountry
group by co.country;


   --Напишите запрос, который покажет количество всех пользователей из США. 
--Это пользователи, у которых номер телефона начинается на +1.
select count(*) AS usa_users_count
from car_shop.clients
where phone LIKE '+1%';
