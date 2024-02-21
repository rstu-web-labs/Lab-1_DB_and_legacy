create schema raw_data

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
 
copy sales  (id,auto,gasoline_consumption,price,date,person_name,phone,discount,brand_origin)  
from 'E:\\web\cars.csv' DELIMITER ',' CSV header null 'null';

create schema car_shop

SET search_path TO car_shop;

create table country_origin(
id serial primary key,
country varchar(255) unique not null -- Страна текстовое, тут всё понятно
);

create table brand(
id serial primary key,
name varchar(255) unique not null, --  название бренда текстовое, тут тоже всё понятно (unique делает поле не повторяющимся, поскольку марка авто одна, а моделей может быть много)
brand_origin int,
foreign key (brand_origin) references country_origin(id)
);

create table color (
    id serial primary key,
    name varchar(255) unique not null -- ну у каждого цвета есть своё название, прописываем его текстом
);

create table model(
id serial primary key,
name varchar(255) not null, -- ситуация аналогичная с названием марки авто. Модель одна, но цветов у неё может быть много, поэтому используем unique
brand_id int,
color_id int,
gas_consumption numeric(3,1), -- расход топлива в таблице изначально как десятичная дробью, но есть и значение null у Теслы
foreign key (brand_id) references brand(id),
foreign key (color_id) references color(id)
);

create table buyer (
id serial primary key,
name varchar(255) not null, -- Имя текстом прописывается, не все покупатели дети Илона Маска
phone varchar(255) not null
);

create table sales(
id serial primary key,
sale_date date, -- Нам нужна дата, для даты. Всё логично? Логично...
model_id int,
price numeric(10,2) check (price >= 0), -- там копеечки могут быть
buyer_id int,
discount int check (discount >=0 and discount <=100), -- Скидка просто число
foreign key (model_id) references model(id),
foreign key (buyer_id) references buyer(id)
);


-- Заполнение таблиц

-- Заполняется страна
insert into country_origin (country)
select distinct brand_origin
from raw_data.sales
where brand_origin is not null;

-- Заполняется Цвет
insert into color (name)
select distinct split_part(split_part(auto, ', ', 2), ',', 1)
from raw_data.sales;

-- Заполняется покупатель
insert into buyer (name, phone)
select distinct person_name, phone
from raw_data.sales;

-- Марка авто
insert into brand (name, brand_origin)
select distinct split_part(split_part(auto, ', ', 1), ' ', 1) as brand_name,
               coalesce(c.id, (select id from country_origin where country = 'Unknown')) as country_id
from raw_data.sales s
left join country_origin c on s.brand_origin = c.country;

-- Модель авто
insert into model (brand_id, name, color_id, gas_consumption)
   select  
    b.id,
    substring(auto from position(' ' in auto) + 1 for position(',' in auto) - position(' ' in auto) - 1) as model, 
    c.id,
    s.gasoline_consumption
from  
    raw_data.sales s 
join  
    brand b on b.name = substring(s.auto from 1 for position(' ' in s.auto) - 1) 
join  
    color c on c.name = substring(s.auto from position(',' in s.auto)+ 2) 
group by  
    b.id, model, c.id, s.gasoline_consumption;

   
-- Продажи
insert into sales (model_id, buyer_id, price, discount, sale_date)
  select 
    model.id, 
    buyer.id, 
    raw_data.sales.price,
    raw_data.sales.discount,
    raw_data.sales.date
  from raw_data.sales
  left join model on concat((select name from brand where id = model.brand_id), model.name, (select name from color where id = model.color_id)) = concat(substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from position(' ' in raw_data.sales.auto) + 1 for position(',' in raw_data.sales.auto) - position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from ', (.*)') ) 
  left join buyer on buyer.name = raw_data.sales.person_name 
  group by model.id, buyer.id, raw_data.sales.price, raw_data.sales.discount, raw_data.sales.date;

--
  delete from sales;
truncate table brand, model, country_origin, sales, buyer, color restart identity;

--
-- Запрос 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption. 

SELECT 
    count(*) * 100.0 / (select count(*) FROM model) AS percentage
FROM 
    model
WHERE 
    gas_consumption is null;

--
 -- Запрос 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки. 
 --Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. Среднюю цену округлите до второго знака после запятой. 

select
    b.name as brand_name,
    extract(year from s.sale_date) as year,
    round(avg(s.price * (1 - s.discount / 100.0)) :: numeric, 2) as price_avg
from
    sales s
join
    model m on s.model_id = m.id
join
    brand b on m.brand_id = b.id
group by
    brand_name,
    year
order by
    brand_name,
    year;
   
--     
 -- Запрос 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. Результат отсортируйте по месяцам в восходящем 
 --порядке. Среднюю цену округлите до второго знака после запятой.
   
select
    extract(month from s.sale_date) as month,
    round(avg(s.price * (1 - s.discount / 100.0))::numeric, 2) as average_price
from
    sales s
where
    extract(year from s.sale_date) = 2022
group by
    month
order by
    month;
    
--
   -- Запрос 4.
   --Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. 
   --Пользователь может купить две одинаковые машины — это нормально. 
   --Название машины покажите полное, с названием бренда — например: Tesla Model 3. Отсортируйте по имени пользователя в восходящем порядке. 
   --Сортировка внутри самой строки с машинами не нужна.
   
select
    b.name as person,
    STRING_AGG(concat(b2.name, ' ', m.name), ', ') as cars
from
    sales s
join
    buyer b ON s.buyer_id = b.id
join
    model m ON s.model_id = m.id
join
    brand b2 ON m.brand_id = b2.id
group by
    person
order by
    person;
   
 --   
   
-- Запрос 5.
--Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
--Цена в колонке price дана с учётом скидки.
   
   select
    co.country AS brand_origin,
    max(s.price / (1 - s.discount / 100.0)) AS price_max,
    min(s.price / (1 - s.discount / 100.0)) AS price_min
from
    sales s
join
    model m on s.model_id = m.id
join
    brand b on m.brand_id = b.id
join
    country_origin co ON b.brand_origin = co.id
group by
    co.country;
   
 -- Запрос 6.
--Напишите запрос, который покажет количество всех пользователей из США. Это пользователи, у которых номер телефона начинается на +1.

   select
    count(*) as persons_from_usa_count
from
    buyer
where
    phone like '+1%';
   