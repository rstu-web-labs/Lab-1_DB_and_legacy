--== ВСТАВКА СЫРЫХ ДАННЫХ ==--

create schema raw_data;

create table raw_data.sales(
	id serial primary key not null, -- id с автоинкрементом
	auto varchar(100) not null, -- модель, название, цвет может понадобиться больше места
	gasoline_consumption decimal(4,2), -- может быть двузначным числом с округлением до сотых -- может быть null
	price decimal(11,4) not null, -- может быть семизначным числом с округлением до десятитысячных 
	date DATE not null, -- просто дата
	person_Name varchar(80) not null, -- ФИ или ФИО, можно выделить больше места
	phone varchar(30) not null, -- телефон может быть иностранным, на всякий случай сделаем побольше
	discount decimal(3,1) not null, -- скидка [0.0..100] (%) c округлением до десятых
	brand_Origin varchar(30) -- страна марки -- может быть null
);

COPY raw_data.sales (id, auto, gasoline_Consumption, price, date, person_name, phone, discount, brand_origin)
from 'F:/cars.csv'
WITH CSV HEADER 
NULL 'null';


--== СОЗДАНИЕ СХЕМЫ С ТАБЛИЦАМИ 3НФ ==--

create schema car_shop;

create table car_shop.colors( -- таблица цветов
	id serial primary key not null, -- id цвета с автоинкрементом
	color varchar(30) not null -- цвет, берётся из поля auto сырой таблицы (всегда первое слово после запятой) (может быть только одним словом)
);

create table car_shop.countries( -- таблица стран
	id serial primary key not null, -- id страны с автоинкрементом
	country varchar(30) -- название страны, берётся из поля сырой таблицы
);

create table car_shop.people( -- таблица покупателей
	id serial primary key not null, -- id покупателя с автоинкрементом
	name varchar(80), -- ФИ или ФИО, берётся из поля сырой таблицы
	phone varchar(30) -- телефон, берётся из поля сырой таблицы
);

create table car_shop.cars( -- таблица машин
	id serial primary key not null, -- id машины с автоинкрементом
	car_name varchar(40) not null, -- название машины, берётся из поля auto сырой таблицы 
								   -- (второе-третье слово до запятой)
	color_id int not null references car_shop.colors(id) on delete cascade -- цвет машины - внешний ключ на таблицу colors с 
);

create table car_shop.brands( -- таблица марок
	id serial primary key not null, -- id марки с автоинкрементом
	brand_name varchar(30) not null, -- название марки, берётся из поля auto сырой таблицы (всегда первое слово поля)
	country_id int references car_shop.countries(id) on delete cascade -- страна происхождение марки - внешний ключ на таблицу countries
																					     -- может быть null
);

create table car_shop.cars_info( -- таблица с информацией о машинах
	id serial primary key not null, -- id информации о машине с автоинкрементом
	car_id int not null references car_shop.cars(id) on delete cascade, -- машина - внешний ключ на таблицу cars
	brand_id int not null references car_shop.brands(id) on delete cascade, -- марка - внешний ключ на таблицы brands
	gasoline_consumption decimal(4,2) -- потребление бензина -- может быть двузначным числом с округлением до сотых 
									-- может быть null
);

create table car_shop.sales_info( -- таблица с информацией о продажах
	id serial primary key not null, -- id продажи с автоинкрементом
	car_info_id int not null references car_shop.cars_info(id) on delete cascade, -- внешний ключ на таблицу cars_info
	person_id int not null references car_shop.people(id) on delete cascade, -- внешний ключ на таблицу people
	date date not null, -- дата продажи
	price decimal(11,4) not null, -- цена продажи
	discount decimal(3,1) not null -- скидка продажи
);


--== ЗАПОЛНЕНИЕ ДАННЫМИ ТАБЛИЦ 3НФ ==--

INSERT INTO car_shop.people(name, phone) -- таблица покупателей
select distinct person_name, phone
from raw_data.sales;

insert into car_shop.countries(country) -- таблица стран
select distinct brand_origin
from raw_data.sales
where brand_origin is not null;

insert into car_shop.colors (color) -- таблица цветов
select distinct split_part(auto, ', ', 2)
from raw_data.sales;

insert into car_shop.brands (brand_name, country_id) -- таблица марок
select distinct split_part(raw_data.sales.auto, ' ', 1), car_shop.countries.id
from raw_data.sales
left join car_shop.countries on raw_data.sales.brand_origin = car_shop.countries.country; 

insert into car_shop.cars (car_name, color_id) -- таблица машин
select distinct trim(split_part(split_part(auto, ', ', 1), ' ', 2) || ' ' || split_part(split_part(auto, ', ', 1), ' ', 3)), car_shop.colors.id
from raw_data.sales
left join car_shop.colors on split_part(raw_data.sales.auto, ', ', 2) = car_shop.colors.color;

insert into car_shop.cars_info (car_id, brand_id, gasoline_consumption) -- таблица с информацией о машинах
select distinct car_shop.cars.id, car_shop.brands.id, raw_data.sales.gasoline_consumption
from raw_data.sales
left join car_shop.cars on trim(split_part(split_part(auto, ', ', 1), ' ', 2) || ' ' || split_part(split_part(auto, ', ', 1), ' ', 3)) = car_shop.cars.car_name
left join car_shop.brands on split_part(auto, ' ', 1) = car_shop.brands.brand_name;

insert into car_shop.sales_info (car_info_id, person_id, date, price, discount) -- таблица с информацией о продажах
select distinct ci.id, p.id, date, price, discount
from raw_data.sales r
join car_shop.cars_info ci on 
	ci.brand_id = (select id from car_shop.brands where brand_name = split_part(r.auto, ' ', 1))
	and ci.car_id = (select id from car_shop.cars where 
			car_name = trim(split_part(split_part(r.auto, ', ', 1), ' ', 2) || ' ' || split_part(split_part(r.auto, ', ', 1), ' ', 3))
			and color_id = (select id from car_shop.colors where color = split_part(r.auto, ', ', 2)))
join car_shop.people p on p.name = r.person_name and p.phone = r.phone;


--== ЗАДАНИЕ 1 ==--

select round(count (case when gasoline_consumption is null then 1 end) * 100.0 / count(*), 2 ) || '%' as nulls_percentage_gasoline_consumption
from car_shop.cars_info;


--== ЗАДАНИЕ 2 ==--

select b.brand_name as brand_name, extract(year from s.date) as year, round(avg(s.price * (1 - s.discount / 100)), 2) as price_avg
from car_shop.cars_info ci, car_shop.brands b, car_shop.sales_info s
where s.car_info_id = ci.id and ci.brand_id = b.id
group by b.brand_name, extract(year from s.date)
order by b.brand_name, year;


--== ЗАДАНИЕ 3 ==--

select extract(month from s.date) as month, '2022' as year, round(avg(s.price),2) as price_avg
from car_shop.sales_info s
where extract(year from s.date) = 2022
group by month
order by month;


--== ЗАДАНИЕ 4 ==--

select p.name as person, string_agg( b.brand_name || ' ' || c.car_name, ', ') as cars
from car_shop.sales_info s, car_shop.people p, car_shop.cars_info ci, car_shop.cars c, car_shop.brands b
where s.person_id = p.id and s.car_info_id = ci.id and ci.car_id = c.id and ci.brand_id = b.id
group by p.name
order by p.name;


--== ЗАДАНИЕ 5 ==--

select ctr.country as brand_origin, max(s.price) as price_max, min(s.price) as price_min
from car_shop.countries ctr, car_shop.sales_info s, car_shop.cars_info ci, car_shop.brands b
where s.car_info_id = ci.id and ci.brand_id = b.id and b.country_id = ctr.id
group by ctr.country;


--== ЗАДАНИЕ 6 ==--

select count(*) as persons_from_usa_count
from car_shop.people p
where p.phone like '+1%';

-------------------