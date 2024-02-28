-- копирование сырых данных
create schema raw_data; -- создание схемы сырых данных
 
create table raw_data.sales( -- создание таблицы с сырыми данными 
	id serial primary key not null, -- id с автоинкрементом
	auto varchar(80) not null, -- модель, название, цвет - может занимать много места
	gasoline_consumption decimal(4,2), -- потребление бензина - двузначное число, с округлением до сотых, возможно null
	price decimal(11,3) not null, -- цена - семизначное число с округлением до тысячных 
	date DATE not null, -- дата 
	person_Name varchar(60) not null, -- ФИО покупателя - может занять много места
	phone varchar(26) not null, -- телефон - может быть иностранным, сделаем больше
	discount decimal(3,1) not null, -- скидка - число от 0 до 100 c округлением до десятых
	brand_Origin varchar(25) -- страна марки - может быть null
);

COPY raw_data.sales (id, auto, gasoline_Consumption, price, date, person_name, phone, discount, brand_origin) -- копирование сырых данных
from 'С:/cars.csv' 
WITH CSV HEADER NULL 'null';

-- создание рабочих таблиц
create schema car_shop; -- создание схемы для рабочих таблиц

create table car_shop.colors( -- создание таблицы с цветами
	id serial primary key not null, -- id цвета c автоинкрементом
	color varchar(20) not null -- цвет из поля auto сырой таблицы (первое слово после запятой)
);

create table car_shop.countries( -- создание таблицы со странами
	id serial primary key not null, -- id страны c автоинкрементом		
	country varchar(25) -- название страны из сырой таблицы
);

create table car_shop.buyers( -- создание таблицы с покупателями
	id serial primary key not null, -- id покупателя c автоинкрементом
	buyer_name varchar(60), -- ФИО из сырой таблицы
	phone varchar(26) -- телефон из сырой таблицы
);

create table car_shop.cars( -- создание таблицы с моделями машин
	id serial primary key not null, -- id машины c автоинкрементом
	car_name varchar(30) not null -- название модели машины из поля auto сырой таблицы (между маркой и цветом) 
);

create table car_shop.brands( -- создание таблицы с марками автомобилей
	id serial primary key not null, -- id марки c автоинкрементом
	brand_name varchar(30) not null, -- название марки из поля auto сырой таблицы (первое слово)
	country_id int references car_shop.countries(id) -- страна происхождение марки (ВК на таблицу countries), возможен null
);

create table car_shop.cars_info( -- создание таблицы с информацией о машинах
	id serial primary key not null, -- id информации о машине c автоинкрементом
	car_id int not null references car_shop.cars(id), -- машина (ВК на таблицу cars)
	brand_id int not null references car_shop.brands(id), -- марка (ВК на таблицы brands)
	gasoline_consumption decimal(4,2), -- потребление бензина (двузначное числом, с округлением до сотых, возможен null) из сырой таблицы
	color_id int not null references car_shop.colors(id) -- цвет машины (ВК на таблицу colors)
);

create table car_shop.sales_info( -- создание таблицы с информацией о продажах машин
	id serial primary key not null, -- id продажи c автоинкрементом
	car_info_id int not null references car_shop.cars_info(id), -- информация о машине (ВК на таблицу cars_info)
	buyer_id int not null references car_shop.buyers(id), -- покупатель (ВК на таблицу buyers)
	date date not null, -- дата продажи машины
	price decimal(11,4) not null, -- цена продажи машины
	discount decimal(3,1) not null -- скидка продажи
);

-- заполнение рабочих таблиц
INSERT INTO car_shop.buyers(buyer_name, phone) -- таблица с покупателями
select distinct person_name, phone
from raw_data.sales;

insert into car_shop.countries(country) -- таблица со странами
select distinct brand_origin
from raw_data.sales
where brand_origin is not null;

insert into car_shop.colors (color) -- таблица с цветами
select distinct split_part(auto, ', ', 2)
from raw_data.sales;

insert into car_shop.cars (car_name) -- таблица с моделями машин
select distinct trim(split_part(split_part(auto, ', ', 1), ' ', 2) || ' ' || split_part(split_part(auto, ', ', 1), ' ', 3))
from raw_data.sales;

insert into car_shop.brands (brand_name, country_id) -- таблица с марками автомобилей
select distinct split_part(raw_data.sales.auto, ' ', 1), car_shop.countries.id
from raw_data.sales
left join car_shop.countries on raw_data.sales.brand_origin = car_shop.countries.country; 

insert into car_shop.cars_info (car_id, brand_id, gasoline_consumption, color_id) -- таблица с информацией о машинах
select distinct car_shop.cars.id, car_shop.brands.id, raw_data.sales.gasoline_consumption, car_shop.colors.id
from raw_data.sales
left join car_shop.cars on trim(split_part(split_part(auto, ', ', 1), ' ', 2) || ' ' || split_part(split_part(auto, ', ', 1), ' ', 3)) = car_shop.cars.car_name
left join car_shop.brands on split_part(auto, ' ', 1) = car_shop.brands.brand_name
left join car_shop.colors on split_part(raw_data.sales.auto, ', ', 2) = car_shop.colors.color;

insert into car_shop.sales_info (car_info_id, buyer_id, date, price, discount) -- таблица с информацией о продажах машин
select distinct ci.id, b.id, date, price, discount
from raw_data.sales r
join car_shop.cars_info ci on ci.brand_id = (select id from car_shop.brands where brand_name = split_part(r.auto, ' ', 1))
and ci.car_id = (select id from car_shop.cars where car_name = trim(split_part(split_part(r.auto, ', ', 1), ' ', 2) || ' ' || split_part(split_part(r.auto, ', ', 1), ' ', 3)))
and ci.color_id = (select id from car_shop.colors where color = split_part(r.auto, ', ', 2))
join car_shop.buyers b on b.buyer_name = r.person_name and b.phone = r.phone;

-- задание 1
select round (count (case when gasoline_consumption is null then 1 end) * 100.0 / count(*), 2 ) as nulls_percentage_gasoline_consumption
from car_shop.cars_info;


-- задание 2
select br.brand_name as brand_name, extract(year from s.date) as year, round(avg(s.price * (1 - s.discount / 100)), 2) as price_avg
from car_shop.cars_info ci, car_shop.brands br, car_shop.sales_info s
where s.car_info_id = ci.id and ci.brand_id = br.id
group by br.brand_name, extract(year from s.date)
order by br.brand_name, year;


-- задание 3
select extract(month from s.date) as month, '2022' as year, round(avg(s.price),2) as price_avg
from car_shop.sales_info s
where extract(year from s.date) = 2022
group by month
order by month;


-- задание 4
select b.buyer_name as person, string_agg(br.brand_name || ' ' || c.car_name, ', ') as cars
from car_shop.sales_info s, car_shop.buyers b, car_shop.cars_info ci, car_shop.cars c, car_shop.brands br
where s.buyer_id = b.id and s.car_info_id = ci.id and ci.car_id = c.id and ci.brand_id = br.id
group by b.buyer_name
order by b.buyer_name;


-- задание 5
select ctr.country as brand_origin, max(s.price) as price_max, min(s.price) as price_min
from car_shop.countries ctr, car_shop.sales_info s, car_shop.cars_info ci, car_shop.brands br
where s.car_info_id = ci.id and ci.brand_id = br.id and br.country_id = ctr.id
group by ctr.country;


-- задание 6
select count(*) as persons_from_usa_count
from car_shop.buyers b
where b.phone like '+1%';