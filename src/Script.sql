-- копирование сырых данных

create schema raw_data; -- создание схемы сырых данных
 
create table raw_data.sales( -- создание таблицы с сырыми данными 
	id serial primary key not null, -- id - автоинкрементом
	auto varchar(100) not null, -- модель, название, цвет - может занимать много места
	gasoline_consumption decimal(4,2), -- потребление бензина - двузначное числом, с округлением до сотых. Может быть null
	price decimal(11,4) not null, -- цена - семизначное число с округлением до десятитысячных 
	date DATE not null, -- дата 
	person_Name varchar(80) not null, -- ФИО покупателя - может занять много места
	phone varchar(30) not null, -- телефон - может быть иностранным, сделаем больше
	discount decimal(3,1) not null, -- скидка - число от 0 до 100 c округлением до десятых
	brand_Origin varchar(30) -- страна марки - может быть null
);

COPY raw_data.sales (id, auto, gasoline_Consumption, price, date, person_name, phone, discount, brand_origin) -- копирование сырых данных
from 'D:/cars.csv' 
WITH CSV HEADER 
NULL 'null';

-- создание рабочих таблиц (3нф)

create schema car_shop; -- создание схемы для рабочих таблиц

create table car_shop.colors( -- 		создание таблицы цветов
	id serial primary key not null, -- 	id цвета - автоинкремент
	color varchar(30) not null -- 		цвет, из поля auto сырой таблицы, первое слово после запятой (одно слово)
);

create table car_shop.countries( -- 	создание таблицы стран
	id serial primary key not null, -- 	id страны - автоинкремент
	country varchar(30) -- 				название страны, из поля сырой таблицы
);

create table car_shop.buyers( --	 	создание таблицы покупателей
	id serial primary key not null, -- 	id покупателя - автоинкремент
	buyer_name varchar(80), -- 			ФИО, из поля сырой таблицы
	phone varchar(30) -- 				телефон, из поля сырой таблицы
);

create table car_shop.cars( -- 			создание таблицы машин
	id serial primary key not null, --	id машины - автоинкремент
	car_name varchar(40) not null, -- 	название машины, из поля auto сырой таблицы, между первыми пробелом и запятой 
	color_id int not null references car_shop.colors(id) -- цвет машины - ВК на таблицу colors
);

create table car_shop.brands( -- 		создание таблицы марок
	id serial primary key not null, --	id марки - автоинкремент
	brand_name varchar(30) not null, -- название марки, из поля auto сырой таблицы первое слово
	country_id int references car_shop.countries(id) -- страна происхождение марки - ВК на таблицу countries, может быть null
);

create table car_shop.cars_info( -- 		создание таблицы с информацией о машинах
	id serial primary key not null, --		id информации о машине - автоинкремент
	car_id int not null references car_shop.cars(id), --	 машина - ВК на таблицу cars
	brand_id int not null references car_shop.brands(id), -- марка - ВК на таблицы brands
	gasoline_consumption decimal(4,2) --	потребление бензина - двузначное числом, с округлением до сотых. Может быть null
);

create table car_shop.sales_info( --		создание таблицы с информацией о продажах
	id serial primary key not null, --		id продажи - автоинкремент
	car_info_id int not null references car_shop.cars_info(id), -- 	информация о машине - ВК на таблицу cars_info
	buyer_id int not null references car_shop.buyers(id), -- 		покупатель - ВК на таблицу buyers
	date date not null, -- 					дата продажи
	price decimal(11,4) not null, -- 		цена продажи
	discount decimal(3,1) not null -- 		скидка продажи
);

--заполнение рабочих таблиц

INSERT INTO car_shop.buyers(buyer_name, phone) -- 	таблица покупателей
select distinct person_name, phone
from raw_data.sales;

insert into car_shop.countries(country) -- 			таблица стран
select distinct brand_origin
from raw_data.sales
where brand_origin is not null;

insert into car_shop.colors (color) -- 				таблица цветов
select distinct split_part(auto, ', ', 2)
from raw_data.sales;

insert into car_shop.brands (brand_name, country_id) -- таблица марок
select distinct split_part(raw_data.sales.auto, ' ', 1), car_shop.countries.id
from raw_data.sales
left join car_shop.countries on raw_data.sales.brand_origin = car_shop.countries.country; 

insert into car_shop.cars (car_name, color_id) -- 		таблица машин
select distinct trim(split_part(split_part(auto, ', ', 1), ' ', 2) || ' ' || split_part(split_part(auto, ', ', 1), ' ', 3)), car_shop.colors.id
from raw_data.sales
left join car_shop.colors on split_part(raw_data.sales.auto, ', ', 2) = car_shop.colors.color;

insert into car_shop.cars_info (car_id, brand_id, gasoline_consumption) -- 			таблица с информацией о машинах
select distinct car_shop.cars.id, car_shop.brands.id, raw_data.sales.gasoline_consumption
from raw_data.sales
left join car_shop.cars on trim(split_part(split_part(auto, ', ', 1), ' ', 2) || ' ' || split_part(split_part(auto, ', ', 1), ' ', 3)) = car_shop.cars.car_name
left join car_shop.brands on split_part(auto, ' ', 1) = car_shop.brands.brand_name;

insert into car_shop.sales_info (car_info_id, buyer_id, date, price, discount) -- 	таблица с информацией о продажах
select distinct ci.id, b.id, date, price, discount
from raw_data.sales r
join car_shop.cars_info ci on 
	ci.brand_id = (select id from car_shop.brands where brand_name = split_part(r.auto, ' ', 1))
	and ci.car_id = (select id from car_shop.cars where 
			car_name = trim(split_part(split_part(r.auto, ', ', 1), ' ', 2) || ' ' || split_part(split_part(r.auto, ', ', 1), ' ', 3))
			and color_id = (select id from car_shop.colors where color = split_part(r.auto, ', ', 2)))
join car_shop.buyers b on b.buyer_name = r.person_name and b.phone = r.phone;

--задание 1

select round
	(count (case when gasoline_consumption is null then 1 end) * 100.0 / 
	count(*), 2 ) as nulls_percentage_gasoline_consumption
from car_shop.cars_info;


--задание 2

select br.brand_name as brand_name, extract(year from s.date) as year, round(avg(s.price * (1 - s.discount / 100)), 2) as price_avg
from car_shop.cars_info ci, car_shop.brands br, car_shop.sales_info s
where s.car_info_id = ci.id and ci.brand_id = br.id
group by br.brand_name, extract(year from s.date)
order by br.brand_name, year;


--задание 3

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


--задание 5

select ctr.country as brand_origin, max(s.price) as price_max, min(s.price) as price_min
from car_shop.countries ctr, car_shop.sales_info s, car_shop.cars_info ci, car_shop.brands br
where s.car_info_id = ci.id and ci.brand_id = br.id and br.country_id = ctr.id
group by ctr.country;


--задание 6

select count(*) as persons_from_usa_count
from car_shop.buyers b
where b.phone like '+1%';
