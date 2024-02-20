create schema raw_data;

create TABLE sales (
  id int primary key not null,
  auto varchar(50) not null,
  gasoline_consumption float,
  price decimal not null,
  date date not null,
  person_name varchar(50) not null,
  phone varchar(50) not null,
  discount float not null,
  brand_origin varchar(15) 
);

COPY sales FROM 'D:\cars.csv' WITH CSV HEADER NULL 'null';

create schema car_shop;

create table cars (
	cars_id int, 
	brand varchar(50) not null,
	model varchar(50) not null, 
	color varchar(50) not null, 
	constraint cars_id_key primary key(cars_id)
)


create table auto_details (
    auto_id int, 
    cars_id int, 
    gasoline_consumption DECIMAL(10, 2),
    price DECIMAL(15, 2),
    date DATE,
    constraint auto_id_key primary key(auto_id), 
    constraint cars_id_foreign_key foreign key (cars_id) references car_shop.cars(cars_id)
);

create table owners (
	owner_id int, 
	auto_id int, 
	preson_name varchar(50), 
	phone varchar(50), 
	discount int, 
	brand_origin VARCHAR(50),
	constraint owner_id_key primary key(owner_id),
	constraint auto_id_foreign_key foreign key (auto_id) references car_shop.auto_details(auto_id)
)

-- переносим данные из raw_data.sales в cars
insert into cars (cars_id,brand, model, color)
select 
	ROW_NUMBER() over (order by 1) as cars_id,
    SUBSTRING(auto, 1, POSITION(' ' in auto) - 1) as brand,
    SUBSTRING(auto, POSITION(' ' in auto) + 1, POSITION(',' in auto) - POSITION(' ' in auto) - 1) as model,
    SUBSTRING(auto, POSITION(',' in auto) + 2) as color
from raw_data.sales;

-- переносим данные из raw_data.sales в auto_details
insert into auto_details 
select 
	ROW_NUMBER() over (order by 1) as auto_id ,
	ROW_NUMBER() over (order by 1) as cars_id,
	gasoline_consumption as gasoline_consumption,
	price as price,
	date as date
from raw_data.sales;	

-- переносим данные из raw_data.sales в owners
insert into owners  
select 
	ROW_NUMBER() over (order by 1) as owner_id ,
	ROW_NUMBER() over (order by 1) as auto_id ,
	person_name as preson_name,
	phone as phone,
	discount as discount,
	brand_origin as brand_origin
from raw_data.sales;	

--Задание №1
-- Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
SELECT 
    (COUNT(CASE WHEN gasoline_consumption IS NULL THEN 1 END)::decimal / COUNT(*)) * 100 AS percentage
FROM auto_details;

-- Задание №2
-- Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
-- Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. 
-- Среднюю цену округлите до второго знака после запятой.
select c.brand as brand_name,
extract(year from ad.date) as year, 
ROUND(AVG(ad.price), 2) AS price_avg
from cars c
join auto_details ad on c.cars_id  = ad.cars_id 
group by c.brand, year
order by c.brand, year

-- Задание №3
-- Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. 
-- Результат отсортируйте по месяцам в восходящем порядке. 
-- Среднюю цену округлите до второго знака после запятой.
SELECT 
    EXTRACT(month FROM date) AS month,
    EXTRACT(year FROM date) AS year,
    ROUND(AVG(price * (1 - discount)), 2) AS price_avg
FROM auto_details
JOIN owners ON auto_details.auto_id = owners.auto_id
WHERE EXTRACT(year FROM date) = 2022
GROUP BY EXTRACT(month FROM date), EXTRACT(year FROM date)
ORDER BY EXTRACT(month FROM date);

-- Задание №4
-- Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую.
-- Пользователь может купить две одинаковые машины — это нормально.
-- Название машины покажите полное, с названием бренда — например: Tesla Model 3.
-- Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.
SELECT 
    preson_name AS person,
    STRING_AGG(brand || ' ' || model, ', ') AS cars
FROM owners
JOIN auto_details ON owners.auto_id = auto_details.auto_id
JOIN cars ON auto_details.cars_id = cars.cars_id
GROUP BY preson_name
ORDER BY person;

-- Задание №5
-- Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
-- Цена в колонке price дана с учётом скидки.
SELECT 
    brand_origin,
    MAX(price) AS price_max,
    MIN(price) AS price_min
from owners
JOIN auto_details ON owners.auto_id = auto_details.auto_id
JOIN cars ON auto_details.cars_id = cars.cars_id
GROUP BY brand_origin
ORDER BY brand_origin;

-- Задание №6
-- Напишите запрос, который покажет количество всех пользователей из США.
-- Это пользователи, у которых номер телефона начинается на +1.
SELECT 
    COUNT(*) AS persons_from_usa_count
FROM owners
WHERE brand_origin = 'USA' AND phone LIKE '+1%';
















