CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
	id int NOT NULL,
	auto text NULL,
	gasoline_consumption numeric NULL,
	price double precision NULL,
	"date" date NULL,
	person_name text NULL,
	phone text NULL,
	discount smallint NULL,
	brand_origin text NULL,
	CONSTRAINT sales_pk PRIMARY KEY (id)
);


copy raw_data.sales from 'C:\cars.csv' with csv header null 'null';

CREATE schema car_shop;

-- таблица с производителями
CREATE TABLE car_shop.vendors (
	id serial NOT NULL, -- serial используется для автоинкримента
	vendor_name text NOT NULL,
	vendor_country text NULL,
	CONSTRAINT vendors_pk PRIMARY KEY (id)
);

-- таблица с клиентами
CREATE TABLE car_shop.custromers (
	id serial NOT NULL,
	person_name text NOT NULL,
	phone_number text NULL,
	CONSTRAINT custromers_pk PRIMARY KEY (id)
);

-- таблица с цветами
CREATE TABLE car_shop.colors (
	id serial NOT NULL,
	color_name text NOT NULL,
	CONSTRAINT colors_pk PRIMARY KEY (id)
);

-- таблица с моделями авто
CREATE TABLE car_shop.models (
	id serial NOT NULL,
	vendor_id int NOT NULL,
	model_name text NOT NULL,
	gasoline_consumption numeric NULL,
	CONSTRAINT models_pk PRIMARY KEY (id),
	CONSTRAINT models_vendors_fk FOREIGN KEY (vendor_id) REFERENCES car_shop.vendors(id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- таблица с совершёнными сделками
CREATE TABLE car_shop.deals (
	id serial NOT NULL,
	customer_id serial NOT NULL,
	model_id serial NOT NULL,
	color_id serial NOT NULL,
	price float8 NOT NULL,
	discount smallint DEFAULT 0 NOT NULL, -- smallint так как скидка - небольшое число (от 0 до 100)
	deal_date date NOT NULL,
	CONSTRAINT deals_pk PRIMARY KEY (id),
	CONSTRAINT deals_custromers_fk FOREIGN KEY (customer_id) REFERENCES car_shop.custromers(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT deals_models_fk FOREIGN KEY (model_id) REFERENCES car_shop.models(id) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT deals_colors_fk FOREIGN KEY (color_id) REFERENCES car_shop.colors(id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- вставка данных в таблицу с производителями
insert into car_shop.vendors(vendor_name, vendor_country)
-- разделяем ячейку на массив слов и берём первое слово как название производителя
select distinct (string_to_array(auto, ' '))[1], brand_origin
from raw_data.sales s;

-- вставка данных про каждого клиента
insert into car_shop.custromers(person_name, phone_number)
select distinct person_name, phone
from raw_data.sales s;

-- вставка данных про цвета
insert into car_shop.colors(color_name)
-- разделяем ячейку на массив слов (', ' - разделитель) и берём второе слово как цвет
select distinct (string_to_array(auto, ', '))[2]
from raw_data.sales s;

-- вставка данных в таблицу с моделями
insert into car_shop.models(vendor_id, model_name, gasoline_consumption)
select distinct
-- создаётся ссылка на нужного производителя, сравнивая первое слово из массива ячейки авто и записывается соответствующее айди
(select car_shop.vendors.id from car_shop.vendors where vendor_name=(string_to_array(auto, ' '))[1]),
-- сначала строка с авто делится на массив с делиметром ',', берётся первый элемент этого массива (бренд + модель),
-- затем этот элемент массива делится ещё на 2 или 3 элемента (например, модель тесла в названии имеет 3 слова, а не 2) с делиметром ' ',
-- после чего убирается первый элемент, который является названием модели, и затем массив обратно конвертируется в text
(array_to_string(array_remove((string_to_array((string_to_array(auto, ','))[1], ' ')), (string_to_array(auto, ' '))[1]), ' ')),
s.gasoline_consumption
from raw_data.sales s;

-- вставка данных про заказы
insert into car_shop.deals(customer_id, model_id, color_id, price, discount, deal_date)
select
(select c.id from car_shop.custromers c where c.person_name=s.person_name),
(select m.id from car_shop.models m where m.model_name=(array_to_string(array_remove((string_to_array((string_to_array(s.auto, ','))[1], ' ')), (string_to_array(s.auto, ' '))[1]), ' '))),
(select cl.id from car_shop.colors cl where cl.color_name=(string_to_array(auto, ', '))[2]),
s.price,
s.discount,
s."date"
from raw_data.sales s;

-- задание 1 процент моделей машин без параметра gasoline_consumption
select
	(null_part/total_amount::numeric(3))*100 as nulls_percentage_gasoline_consumption
from
(
	select
	count(*) total_amount,
	sum(case when gasoline_consumption is null then 1 else 0 end) null_part
	from car_shop.models
)

-- задание 2 с названием бренда и средней ценой по годам с округлением до 2 значений после запятой
select v.vendor_name as brand_name, date_part('year', d.deal_date) as year, round(cast((avg(d.price)) as numeric), 2) as price_avg
from car_shop.deals d
inner join car_shop.models m on d.model_id = m.id
inner join car_shop.vendors v on m.vendor_id = v.id 
group by year, brand_name
order by brand_name;

-- задание 3 со средней ценой за каждый месяц в 2022 году с округлением до 2 значений после запятой
select date_part('month', d.deal_date) as month, date_part('year', d.deal_date) as year, round(cast((avg(d.price)) as numeric), 2) as price_avg
from car_shop.deals d
where (date_part('year', d.deal_date))=2022
group by year, month
order by month;

-- задание 4 список купленных машин у каждого покупателя через запятую
select c.person_name as person, string_agg(v.vendor_name || ' ' || m.model_name, ', ') as cars
from car_shop.deals d
inner join car_shop.custromers c on d.customer_id = c.id
inner join car_shop.models m on d.model_id = m.id
inner join car_shop.vendors v on m.vendor_id = v.id 
group by person
order by person;

-- задание 5 минимальные и максимальные цены без учёта скидки
select v.vendor_country as brand_origin, max(d.price / (100 - d.discount) * 100) as price_max, min(d.price / (100 - d.discount) * 100) as price_min 
from car_shop.deals d
inner join car_shop.models m on d.model_id = m.id
inner join car_shop.vendors v on m.vendor_id = v.id 
where v.vendor_country is not null
group by brand_origin;

-- задание 6 кол-во всех пользователей из США
select count(phone_number) persons_from_usa_count
from car_shop.custromers c 
where (substring(phone_number from 1 for 2))='+1';