create schema raw_data;

create table raw_data.sales (
  id SERIAL primary key not null,
  auto varchar(200) not null,
  gasoline_consumption DECIMAL(3,1),
  price DECIMAL(15, 8) not null,
  data date not null,
  person_name VARCHAR(200) not null,
  phone VARCHAR(20) not null,
  discount DECIMAL(4,2),
  brand_origin VARCHAR(60)
);

copy raw_data.sales (id, auto, gasoline_consumption, price, data, person_name, phone, discount, brand_origin) FROM 'C:\Users\Vyacheslav\Загрузки\cars.csv' DELIMITER ',' CSV HEADER NULL 'null';


--Создание таблиц--

create schema car_shop;

create table car_shop.color(
       id serial primary key,
       color varchar(10) not null unique
);

create table car_shop.country(
       id serial primary key,
       country varchar(15) not null unique
);

create table car_shop.model(
       id serial primary key,
       model varchar(10) not null unique
);

create table car_shop.client(
       id serial primary key,
       name varchar(50),
       phone varchar(30)
);

create table car_shop.brand(
       id serial primary key,
       brand varchar(20) not null,
       id_country int references car_shop.country(id) on delete restrict

);

create table car_shop.set(
       id serial primary key,
       id_model int references car_shop.model(id) on delete restrict,
       id_brand int references car_shop.brand(id) on delete restrict,
       id_color int references car_shop.color(id) on delete restrict,
       gasoline_consumption DECIMAL(3,1) check(gasoline_consumption between 0 and 99)
);

create table car_shop.sale(
       id serial primary key,
       id_client int references car_shop.client(id) on delete restrict,
       id_set int references car_shop.set(id) on delete restrict,
       price numeric not null,
       data date not null,
       discount DECIMAL(5,2) not null
);


--Заполнение таблиц--

insert into car_shop.country(country)
	select brand_origin 
	from raw_data.sales
	group by brand_origin
	having brand_origin is not null;


insert into car_shop.client (name, phone)
	select person_name, phone 
	from raw_data.sales 
	group by person_name, phone;

insert into car_shop.color (color)
	select substring(auto from ', (.*)') as color
	from raw_data.sales
	group by color;

insert into car_shop.brand (brand, id_country)
	select substring(auto from 1 for position(' ' in auto) - 1) as brand, 
	    country.id
	from raw_data.sales
	left join car_shop.country  ON country.country = raw_data.sales.brand_origin
	group by brand, country.id;

insert into car_shop.model (model)
	select
		substring(auto from position(' ' in auto) + 1 for position(',' in auto) - position(' ' in auto) - 1) as model
	from raw_data.sales
	group by model;

insert into car_shop.set (id_brand, id_model, id_color, gasoline_consumption)
    select car_shop.brand.id as br,
       car_shop.model.id as md,
       car_shop.color.id as cl,
       gasoline_consumption
    from raw_data.sales 
    left join car_shop.brand on brand.brand =  substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1) 
	left join car_shop.model on model.model = substring(raw_data.sales.auto from position(' ' in raw_data.sales.auto) + 1 for position(',' in raw_data.sales.auto) - position(' ' in raw_data.sales.auto) - 1)
	left join car_shop.color on color.color  =  substring(raw_data.sales.auto from ', (.*)') 
	group by br, md, cl, gasoline_consumption;
    
insert into car_shop.sale (id_client, id_set, price, data, discount)
	select 
		client.id, 
		set.id,
		raw_data.sales.price,
		raw_data.sales.data,
		raw_data.sales.discount	
from
	raw_data.sales
left join car_shop.set on concat((select brand from car_shop.brand where brand.id = set.id_brand), (select model from car_shop.model where model.id = set.id_model), (select color from car_shop.color where color.id = set.id_color)) = concat(substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from position(' ' in raw_data.sales.auto) + 1 for position(',' in raw_data.sales.auto) - position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from ', (.*)'))
left join car_shop.client on client.name = raw_data.sales.person_name
group by set.id, client.id, raw_data.sales.price, raw_data.sales.discount, raw_data.sales.data;

--Запросы--

--№1

SELECT COUNT(CASE WHEN gasoline_consumption IS NULL THEN 1 END) * 100.0 / COUNT(*) AS percentage_null
FROM car_shop.set;


--#2

select
	b.brand as brand_name, 
	extract(year from s.data) as years, 
	avg(s.price) as price_avg
from car_shop.sale s
left join car_shop.set c on c.id = s.id_set
left join car_shop.brand b on c.id_brand = b.id
group by years, brand_name
order by brand_name;

--#3

select 
	extract(month from s.data) as months,
	extract(year from s.data) as years,
	round(avg(price), 2) as price_avg
from car_shop.sale s 
group by months, years
having extract(year from s.data) = 2022;

--#4

select 
	name as person,
	string_agg(b.brand || ' ' ||  m.model,  ', ') as cars
from car_shop.sale s
left join car_shop.client c on c.id = s.id_client
left join car_shop.set st on st.id = s.id_set
left join car_shop.model m on m.id = st.id_model 
left join car_shop.brand b on b.id = st.id_brand 
group by person
order by person;

--#5

select 
	c.country as brand_origin,
	max(s.price / (1 - s.discount / 100.0)) as price_max,
	min(s.price / (1 - s.discount / 100.0)) as price_min
from car_shop.sale s 
left join car_shop.set s2 on s2.id = s.id_set 
left join car_shop.brand b on b.id = s2.id_brand 
left join car_shop.country c on c.id = b.id_country 
group by brand_origin, c.country
having c.country is not null;

--№6

select count(*) as clients_from_usa_count
from car_shop.client
where phone like '+1%' 