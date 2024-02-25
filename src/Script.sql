create database life_on_wheels;

create schema raw_data;

create table raw_data.sales (
id SERIAL primary key not null,
auto varchar(200) not null,
gasoline_consumption FLOAT,
price float not null,
date date not null,
person_name varchar(200) not null,
phone varchar(50) not null,
discount int not null,
brand_origin varchar(200)
);

copy raw_data.sales (id,auto,gasoline_consumption,price,date, person_name,phone,discount,brand_origin)
from 'D:\projects\cars.csv'
delimiter ','
null 'null'
csv header

create schema car_shop;
create table car_shop.country(
id serial primary key,
country varchar(50) not null
);

create table car_shop.brand(
id serial primary key,
brand varchar(50) not null,
id_country INT REFERENCES car_shop.country(id)
);

create table car_shop.model(
id serial primary key,
id_brand int references car_shop.brand(id) not null,
model_name varchar(50) not null
);

create table car_shop.color(
id serial primary key,
color varchar(50) not null
);
create table car_shop.equipment(
id serial primary key,
gasoline_consumption float,
id_model int references car_shop.model(id) not null,
id_color int references car_shop.color(id) not null
);

create table car_shop.buyer(
id serial primary key,
name varchar(50) not null,
phone varchar(50) not null
);

create table car_shop.sales(
id serial primary key,
id_equipment int references car_shop.equipment(id) not null,
id_buyer int references car_shop.buyer(id) not null,
price decimal not null,
date_sale date not null,
discount float not null
);

 --занесение данных в таблицу country
INSERT INTO car_shop.country (country)
SELECT DISTINCT brand_origin
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;

--занесение данных в таблицу brand
insert into brand (brand, id_country)
select
substring(auto from 1 for position(' ' in auto) - 1) as brand,
country.id
from raw_data.sales
left join country ON country.country = raw_data.sales.brand_origin
group by brand, country.id;

--занесение данных в таблицу model
insert into model (id_brand,model_name)
select
brand.id,
substring(auto from position(' ' in auto) + 1 for position(',' in auto) - position(' ' in auto) - 1) as model
from raw_data.sales
left join brand on brand.brand = substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1)
group by brand.id, model;

--занесение данных в таблицу color
insert into color (color)
select substring(auto from ', (.*)') as color
from raw_data.sales
group by color;

--занесение данных в таблицу equipment
INSERT INTO car_shop.equipment (gasoline_consumption, id_model, id_color)
select s.gasoline_consumption, m.id, c2.id
from raw_data.sales s
left join color c2 on c2.color = substring(s.auto from ', (.*)')
left join model m on concat((select brand from brand b where b.id = m.id_brand),model_name) = concat(substring(s.auto from 1 for position(' ' in s.auto) - 1),substring(s.auto from position(' ' in s.auto) + 1 for position(',' in s.auto) - position(' ' in s.auto) - 1))
group by s.gasoline_consumption, m.id, c2.id;
 
--занесение данных в таблицу buyer
insert into car_shop.buyer (name, phone)
select person_name, phone
from raw_data.sales
group by person_name, phone;

--занесение данных в таблицу sales
 insert into car_shop.sales (id_equipment, id_buyer, price, date_sale, discount)
select
equipment.id,
buyer.id,
raw_data.sales.price,
raw_data.sales.date,
raw_data.sales.discount
from raw_data.sales
left join car_shop.model on concat((select brand from brand where brand.id = model.id_brand), model_name) = concat(substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from position(' ' in raw_data.sales.auto) + 1 for position(',' in raw_data.sales.auto) - position(' ' in raw_data.sales.auto) - 1))
left join car_shop.color on color.color = substring(raw_data.sales.auto from ', (.*)')
left join car_shop.equipment on equipment.id_color = color.id and equipment.id_model = model.id
left join car_shop.buyer on buyer.name = raw_data.sales.person_name
group by equipment.id, buyer.id, raw_data.sales.price, raw_data.sales.date, raw_data.sales.discount;

--1.Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
SELECT 
  (COUNT(*) FILTER (WHERE gasoline_consumption is  NULL) * 100.0 / COUNT(*)) AS percentage_null
FROM car_shop.equipment;


--2.Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки. Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. Среднюю цену округлите до второго знака после запятой. Формат итоговой таблицы:
SELECT b.brand AS brand_name, EXTRACT(YEAR FROM s.date_sale) AS year, ROUND(AVG((s.price * (1.0 - s.discount/100))::numeric), 2) AS price_avg
FROM sales s
JOIN equipment e ON s.id_equipment = e.id
JOIN model m ON e.id_model = m.id
JOIN brand b ON m.id_brand = b.id
GROUP BY b.brand, year
ORDER BY b.brand, year;
--3.Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. Результат отсортируйте по месяцам в восходящем порядке. Среднюю цену округлите до второго знака после запятой.
SELECT EXTRACT(MONTH FROM date_sale) AS month, EXTRACT(YEAR FROM date_sale) AS year, ROUND(AVG((price * (1.0 - discount/100))::numeric), 2) AS price_avg
FROM sales
WHERE EXTRACT(YEAR FROM date_sale) = 2022
GROUP BY month, year
ORDER BY month;
--4.Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. Пользователь может купить две одинаковые машины — это нормально. Название машины покажите полное, с названием бренда — например: Tesla Model 3. Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.

SELECT
buyer.name AS person, 
    STRING_AGG(CONCAT(brand.brand, ' ', model.model_name), ', ') AS cars
FROM sales
JOIN equipment ON sales.id_equipment = equipment.id
JOIN model ON equipment.id_model = model.id
JOIN color ON equipment.id_color = color.id
JOIN brand ON model.id_brand = brand.id
JOIN buyer ON sales.id_buyer = buyer.id
GROUP BY buyer.name
ORDER BY buyer.name;


--5.Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. Цена в колонке price дана с учётом скидки.
 
 SELECT 
  brand_origin AS brandorigin,
  MAX(s.price) AS pricemax,
  MIN(s.price) AS pricemin
FROM 
  raw_data.sales s
JOIN 
  brand b ON b.brand = substring(s.auto from 1 for position(' ' in s.auto) - 1)
WHERE 
  brand_origin IS NOT NULL
GROUP BY 
  brand_origin
ORDER BY 
  brand_origin;
      
--6.Напишите запрос, который покажет количество всех пользователей из США. Это пользователи, у которых номер телефона начинается на +1.
SELECT COUNT(*) as persons_from_usa_count
FROM buyer
WHERE phone LIKE '+1%';

