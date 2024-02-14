create database life_on_wheels;

create schema raw_data;

CREATE TABLE raw_data.sales (
    id INT,
    auto VARCHAR(255),
    gasoline_consumption DECIMAL(10, 2),
    price DECIMAL(15, 2),
    date DATE,
    person_name VARCHAR(255),
    phone VARCHAR(50), 
    discount INT,
    brand_origin VARCHAR(50)
);


COPY sales(id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin) FROM '/home/user/Загрузки/cars.csv' DELIMITER ',' CSV HEADER NULL 'null';


create schema car_shop;


create table car_shop.cars (
	cars_id int, 
	brand varchar(50) not null,
	model varchar(50) not null, 
	color varchar(50) not null, 
	constraint cars_id_key primary key(cars_id)
)


create table car_shop.auto_details (
    auto_id int, 
    cars_id int, 
    gasoline_consumption DECIMAL(10, 2),
    price DECIMAL(15, 2),
    date DATE,
    constraint auto_id_key primary key(auto_id), 
    constraint cars_id_foreign_key foreign key (cars_id) references car_shop.cars(cars_id)
);

create table car_shop.owners (
	owner_id int, 
	auto_id int, 
	preson_name varchar(50), 
	phone varchar(50), 
	discount int, 
	brand_origin VARCHAR(50),
	constraint owner_id_key primary key(owner_id),
	constraint auto_id_foreign_key foreign key (auto_id) references car_shop.auto_details(auto_id)
)


insert into car_shop.cars (cars_id,brand, model, color)
select 
	ROW_NUMBER() over (order by 1) as cars_id,
    SUBSTRING(auto, 1, POSITION(' ' in auto) - 1) as brand,
    SUBSTRING(auto, POSITION(' ' in auto) + 1, POSITION(',' in auto) - POSITION(' ' in auto) - 1) as model,
    SUBSTRING(auto, POSITION(',' in auto) + 2) as color
from raw_data.sales;

insert into car_shop.auto_details 
select 
	ROW_NUMBER() over (order by 1) as auto_id ,
	ROW_NUMBER() over (order by 1) as cars_id,
	gasoline_consumption as gasoline_consumption,
	price as price,
	date as date
from raw_data.sales;	


insert into car_shop.owners  
select 
	ROW_NUMBER() over (order by 1) as owner_id ,
	ROW_NUMBER() over (order by 1) as auto_id ,
	person_name as preson_name,
	phone as phone,
	discount as discount,
	brand_origin as brand_origin
from raw_data.sales;	

--Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
SELECT COUNT(*) * 100.0 / (SELECT COUNT(*) FROM car_shop.auto_details) AS nulls_percentage_gasoline_consumption
FROM car_shop.auto_details
WHERE gasoline_consumption IS NULL;
--Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки. 
--Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. 
--Среднюю цену округлите до второго знака после запятой. Формат итоговой таблицы:
select c.brand as brand_name,
extract(year from ad.date) as year, 
ROUND(AVG(ad.price), 2) AS price_avg
from car_shop.cars c
join car_shop.auto_details ad on c.cars_id  = ad.cars_id 
group by c.brand, extract(year from ad.date)
order by c.brand, extract(year from ad.date)

--Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. 
--Результат отсортируйте по месяцам в восходящем порядке. Среднюю цену округлите до второго знака после запятой.
select 
extract (month from  ad.date ) as month,
extract (year from  ad.date ) as year,
ROUND(AVG(ad.price), 2) AS price_avg
from  car_shop.auto_details ad 
where extract (year from  ad.date ) = 2022
group by extract (month from  ad.date ), extract (year from  ad.date )
order by extract (month from  ad.date )

---Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. 
---Пользователь может купить две одинаковые машины — это нормально. Название машины покажите полное, с названием бренда — например: Tesla Model 3. 
---Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.

select  o.preson_name as person, 
string_agg(c.brand || ' ' || c.model, ', ' order by c.brand, c.model) as cars
from car_shop.owners o
join car_shop.auto_details ad  on o.auto_id = ad.auto_id 
join car_shop.cars c on ad.cars_id  = c.cars_id 
group by o.preson_name
order by o.preson_name

--Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
--Цена в колонке price дана с учётом скидки.

select 
o.brand_origin as brand_origin, 
max(ad.price) as price_max,
min(ad.price) as price_min
from
car_shop.auto_details ad 
join car_shop.owners o on ad.auto_id  = o.auto_id 
where o.brand_origin is not null
group by o.brand_origin
order by o.brand_origin

--Напишите запрос, который покажет количество всех пользователей из США. 
--Это пользователи, у которых номер телефона начинается на +1.
select count(*) as persons_from_usa_count 
from car_shop.owners o 
where phone like '+1%';



