create schema raw_data;

create TABLE raw_data.sales (
  id int primary key not null,
  auto varchar(70),
  gasoline_consumption float,
  price decimal,
  date varchar(50),
  person_name varchar(50),
  phone varchar(50),
  discount float,
  brand_origin varchar(30) 
);

COPY raw_data.sales FROM '/cars.csv' WITH CSV HEADER NULL 'null';

CREATE SCHEMA car_shop;

create table car_shop.color(
  id serial primary key,
  color varchar(50) not null
);

create table car_shop.country(
  id serial primary key,
  country varchar(50) not null
);

create table car_shop.brand(
  id serial primary key,
  brand varchar(50) not null,
  id_country INT REFERENCES country(id) 
);

create table car_shop.model(
  id serial primary key,
  id_brand int references brand(id) not null,
  model_name varchar(50) not null
);

create table car_shop.equipment(
  id serial primary key,
  id_model int references model(id) not null,
  id_color int references color(id) not null,
  gasoline_consumption varchar(50)
);

create table car_shop.buyer(
  id serial primary key,
  name varchar(50) not null,
  phone varchar(50) not null
);
create table car_shop.sales(
  id  serial primary key,
  id_equipment int references equipment (id) not null,
  id_buyer int references buyer(id) not null,
  price decimal not null,
  date_sale varchar(50) not null,
  discont float not null
);



--занесение данных в таблицу color

insert into car_shop.color (color)
  select substring(auto from ', (.*)') as color
  from raw_data.sales
  group by color;
 
 --занесение данных в таблицу country
 
INSERT INTO car_shop.country (country)
SELECT DISTINCT brand_origin
FROM raw_data.sales
WHERE brand_origin IS NOT NULL;

--занесение данных в таблицу buyer
 

insert into car_shop.buyer (name, phone)
select person_name, phone
from raw_data.sales
group by person_name, phone;
  
--занесение данных в таблицу brand

insert into car_shop.brand (brand, id_country)
select
substring(auto from 1 for position(' ' in auto) - 1) as brand,
country.id
from raw_data.sales
left join car_shop.country ON country.country = raw_data.sales.brand_origin
group by brand, country.id;


--занесение данных в таблицу model

insert into car_shop.model (id_brand,model_name)
select
brand.id,
substring(auto from position(' ' in auto) + 1 for position(',' in auto) - position(' ' in auto) - 1) as model
from raw_data.sales
left join car_shop.brand on brand.brand = substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1)
group by model, brand.id;

--занесение данных в таблицу equipment

INSERT INTO car_shop.equipment (gasoline_consumption, id_model, id_color)
select s.gasoline_consumption, m.id, c2.id
from raw_data.sales s
left join color c2 on c2.color = substring(s.auto from ', (.*)')
left join model m on concat((select brand from brand b where b.id = m.id_brand),model_name) = concat(substring(s.auto from 1 for position(' ' in s.auto) - 1),substring(s.auto from position(' ' in s.auto) + 1 for position(',' in s.auto) - position(' ' in s.auto) - 1))
group by s.gasoline_consumption, m.id, c2.id;

--занесение данных в таблицу sales

 insert into car_shop.sales (id_equipment, id_buyer, price, date_sale, discont)
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

--Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.

SELECT 
  (COUNT(*) FILTER (WHERE gasoline_consumption is  NULL) * 100.0 / COUNT(*)) AS percentage_null
FROM car_shop.equipment;

--Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки. Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. Среднюю цену округлите до второго знака после запятой. Формат итоговой таблицы:

SELECT 
    b.brand AS brand_name,
    SUBSTRING(s.date_sale, 1, 4) AS year,
    ROUND(AVG(CAST(s.price * (1 - s.discont/100) AS numeric)), 2) AS average_price
FROM car_shop.brand b
JOIN car_shop.model m ON b.id = m.id_brand
JOIN car_shop.equipment e ON m.id = e.id_model
JOIN car_shop.sales s ON e.id = s.id_equipment
GROUP BY b.brand, year
ORDER BY brand_name, year;

--Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. Результат отсортируйте по месяцам в восходящем порядке. Среднюю цену округлите до второго знака после запятой.

SELECT EXTRACT(MONTH FROM TO_DATE(s.date_sale, 'YYYY-MM-DD')) AS month,
       AVG(s.price * (1 - s.discont/100)) AS avg_price
FROM car_shop.sales s
WHERE EXTRACT(YEAR FROM TO_DATE(s.date_sale, 'YYYY-MM-DD')) = 2022
GROUP BY EXTRACT(MONTH FROM TO_DATE(s.date_sale, 'YYYY-MM-DD'))
ORDER BY month;

--Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. Пользователь может купить две одинаковые машины — это нормально. Название машины покажите полное, с названием бренда — например: Tesla Model 3. Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.

SELECT b.name AS user_name, 
       STRING_AGG(CONCAT(br.brand, ' ', m.model_name), ', ') AS cars_bought
FROM car_shop.buyer b
JOIN car_shop.sales s ON b.id = s.id_buyer
JOIN car_shop.equipment e ON s.id_equipment = e.id
JOIN car_shop.model m ON e.id_model = m.id
JOIN car_shop.brand br ON m.id_brand = br.id
GROUP BY b.name
ORDER BY b.name;

--Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. Цена в колонке price дана с учётом скидки.

SELECT c.country AS country_name,
       MAX(s.price) AS max_sale_price,
       MIN(s.price) AS min_sale_price
FROM car_shop.sales s
JOIN car_shop.equipment e ON s.id_equipment = e.id
JOIN car_shop.model m ON e.id_model = m.id
JOIN car_shop.brand br ON m.id_brand = br.id
JOIN car_shop.country c ON br.id_country = c.id
GROUP BY c.country;

--Напишите запрос, который покажет количество всех пользователей из США. Это пользователи, у которых номер телефона начинается на +1.

SELECT COUNT(*) AS total_us_users
FROM car_shop.buyer
WHERE phone LIKE '+1%';






