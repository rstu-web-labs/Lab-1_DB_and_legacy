-- Сырые данные
create table sales(
id integer primary key,
auto varchar(30),
gasoline_consumption numeric(4, 1),
price numeric(10, 2),
date date,
person_name varchar(30),
phone varchar(30),
discount integer,
brand_origin varchar(30)
);

copy sales  (id,auto,gasoline_consumption,price,date,person_name,phone,discount,brand_origin) 
from 'E:\git proj\Lab-1_DB_and_legacy\cars.csv' delimiter ',' csv header null 'null';

-- Упорядоченные данные

create schema car_shop

create table country(
	id serial primary key, -- идентификатор, автоинкремент, первичный ключ
	name varchar(30) unique not null -- название страны, поле, состоящие из символов, поэтому выбор пал на varchar; названия стран - уникальные (unique), неповторяющиеся, и не могут быть пустым полем
);

create table color(
	id serial primary key, -- идентификатор, автоинкремент, первичный ключ
	name varchar(30) unique not null -- название цвета, состоит из символов, уникальное и не может быть пустым полем
);

create table buyer(
	id serial primary key, -- идентификатор, автоинкремент, первичный ключ
	name varchar(30) not null, -- имя и фамилия клиента (соответственно, строковый тип), поле не может быть пустым
	phone varchar(30) -- номер телефона покупателя; т.к. нет определенного шаблона в сырых данных, то берём строковый тип 
);

create table brand (
	id serial primary key, -- идентификатор, автоинкремент, первичный ключ
	name varchar(30) unique not null, -- название бренда => используем строковый тип; названия не должны повторяться, т.к. от бренда следуют различные модели авто (поэтому unique); не может быть пустым полем
	country_origin_id integer, -- идентификатор, внешний ключ, используем integer, т.к. берём целочисленный тип от первичного ключа из таблицы "Country"
	foreign key (country_origin_id) references Country(id) on delete restrict
);

create table model (
	id serial primary key, -- идентификатор, автоинкремент, первичный ключ
	brand_id integer, -- идентификатор, внешний ключ, используем integer, т.к. берём целочисленный тип от первичного ключа из таблицы "Brand"
	name varchar(30) not null, -- название модели автомобиля -> пишем символами, поэтому строковый varchar; поле не может быть пустым
	color_id integer, -- идентификатор, внешний ключ, используем integer, т.к. берём целочисленный тип от первичного ключа из таблицы "Color"
	gas_consumption numeric(4, 1) check (gas_consumption > 0), -- просто число с плавающей точкой (дано изначально в исходном файле); P.S. отел юзать тип DECIMAL с параметрами (2, 2), но не срослось, не хотело работать
	foreign key (brand_id) references Brand(id) on delete restrict,
	foreign key (color_id) references Color(id) on delete restrict
);

create table sales(
	id serial primary key, -- идентификатор, автоинкремент, первичный ключ
	model_id integer, -- идентификатор, внешний ключ, используем integer, т.к. берём целочисленный тип от первичного ключа из таблицы "Model"
	buyer_id integer, -- идентификатор, внешний ключ, используем integer, т.к. берём целочисленный тип от первичного ключа из таблицы "Buyer"
	price numeric(10, 2) check (price >= 0), -- цена - используем число с плавающей точкой; P.S. хотел использовать тип MONEY, но он жёстко и жестоко ругался при импорте данных
	discount integer check (discount between 0 and 100), -- скидка, в исходном файле не содержит дробных чисел, следовательно, достаточно использовать целочисленный тип
	sell_date date, -- поле с датой, соответственно, содержит тип даты
	foreign key (model_id) references Model(id) on delete restrict,
	foreign key (buyer_id) references Buyer(id) on delete restrict
);

-- Заполнение таблиц 

-- Страна

insert into country (name)
select distinct brand_origin
from raw_data.sales 
where brand_origin is not null;

-- Цвет

insert into car_shop.color (name)
select distinct split_part(auto, ', ', 2)
from raw_data.sales;

-- Покупатель

insert into buyer (name, phone)
select distinct person_name, phone 
from raw_data.sales;

-- Бренд

insert into brand (name, country_origin_id)
select distinct split_part(split_part(auto, ', ', 1), ' ', 1) as brand_name,
				coalesce (country.id, (select id from country where name is null)) as country_id
from raw_data.sales
left join country on raw_data.sales.brand_origin = country.name;

-- Модель

insert into model (brand_id, name, color_id, gas_consumption)
	select
		brand.id,
		substring(auto from position(' ' in auto) + 1 for position(',' in auto) - position(' ' in auto) - 1) as model,
		color.id,
		s.gasoline_consumption
from 
	raw_data.sales s
join brand on brand.name = substring(s.auto from 1 for position(' ' in s.auto) - 1)
join color on color.name = substring(s.auto from position(',' in s.auto) + 2)
group by brand.id, model, color.id, s.gasoline_consumption;

-- Продажи

insert into sales (model_id, buyer_id, price, discount, sell_date)
	select 
		model.id, 
		buyer.id, 
		raw_data.sales.price,
		raw_data.sales.discount,
		raw_data.sales.date
from
	raw_data.sales
left join 
	model on concat((select name from brand where id = model.brand_id), model.name, (select name from color where id = model.color_id)) = concat(substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from position(' ' in raw_data.sales.auto) + 1 for position(',' in raw_data.sales.auto) - position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from ', (.*)') ) 
left join buyer on buyer.name = raw_data.sales.person_name 
group by model.id, buyer.id, raw_data.sales.price, raw_data.sales.discount, raw_data.sales.date;

-- Аналитические запросы

-- Запрос 1. Вывод процента автомобилей, у которых отсутствует параметр gasoline_consumption

select 
	count(*) * 100.0 / (select count(*) from model) as nulls_percentage_gasoline_consumption
from model
where gas_consumption is null;

-- Запрос 2. Запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.

select 
	b.name as brand_name,
	extract(year from s.sell_date) as year,
	round(avg(s.price * (1 - s.discount / 100.0)) :: numeric, 2) as price_avg
from
	sales s
join 
	model m on s.model_id = m.id
join
	brand b on m.brand_id = b.id
group by
	b.name,
	extract(year from s.sell_date)
order by
	brand_name,
	year;

-- Запрос 3. Посчитать среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. 

select 
	extract(month from s.sell_date) as month,
	extract(year from s.sell_date) as year,
	round(avg(s.price * (1 - s.discount / 100.0))::numeric, 2) as avg_price
from
	sales s 
where
	extract(year from s.sell_date) = 2022
group by
	extract(month from s.sell_date),
	extract(year from s.sell_date)
order by
	month;
	
-- Запрос 4. Запрос, который выведет список купленных машин у каждого пользователя через запятую.

select
	b.name as person,
	string_agg(br.name || ' ' || m.name, ', ') as cars
from
	sales s 
join
	buyer b on s.buyer_id = b.id 
join 
	model m on s.model_id = m.id 
join
	brand br on m.brand_id = br.id 
group by 
	b.name 
order by 
	b.name;
	
-- Запрос 5. Запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки.

select
	c.name as brand_origin,
	max(s.price / (1 - s.discount / 100.0)) as price_max,
	min(s.price / (1 - s.discount / 100.0)) as price_min
from
	sales s
join
	model m on s.model_id = m.id
join 
	brand b on m.brand_id = b.id
join 
	country c on b.country_origin_id = c.id
group by 
	c.name;
	
-- Запрос 6. Запрос, который покажет количество всех пользователей из США.

select 
	count(*) as persons_from_usa_count
from 
	buyer b
where
	phone like '+1%';