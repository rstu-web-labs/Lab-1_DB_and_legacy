
 create schema raw_data;
 --создание таблицы с переменнми и ПК
 create table raw_data.sales (
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

 --копирование данных и файла
 COPY raw_data.sales (id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin) FROM 'K:\LabsWeb\Lab-1_DB_and_legacy\cars.csv' WITH CSV HEADER NULL 'null';

 --создание пользоватльских таблиц
 create schema car_shop;

 create table car_shop.automobileModel(
 	id serial primary key,
 	automobileModel varchar(10) not null unique
 );

 create table car_shop.color(
 	id serial primary key,
 	color varchar(10) not null unique
 );

 create table car_shop.country(
 	id serial primary key,
 	country varchar(15) not null unique
 );

 create table car_shop.brand(
 	id serial primary key,
 	brand varchar(20) not null,
 	id_contry int references car_shop.country(id) on delete restrict
 );


 create table car_shop.car(
 	id serial primary key,
 	id_brand int references car_shop.brand(id)on delete restrict not null,
 	id_automobileModel int references car_shop.automobileModel(id)on delete restrict not null,
 	gasoline_consumption float check(gasoline_consumption between 0 and 99)
 );

 create table car_shop.equipment(
 	id serial primary key,
 	id_car int references car_shop.car(id)on delete restrict not null,
 	id_color int references car_shop.color(id)on delete restrict not null
 );


 create table car_shop.buyer(
 	id serial primary key,
 	name varchar(50) not null,
 	phone varchar(50) not null
 );

 create table car_shop.sales(
 	id  serial primary key,
 	id_equipment int references car_shop.equipment (id)on delete restrict not null,
 	id_buyer int references car_shop.buyer(id)on delete restrict not null,
 	price decimal not null,
 	date_sale date not null,
 	discont float not null check(discont between 0 and 100)
 );

 --заполнение таблиц
 insert into car_shop.country (country)
 	select brand_origin 
 	from raw_data.sales
 	group by brand_origin
 	having brand_origin is not null;

 insert into car_shop.buyer (name, phone)
 	select person_name, phone 
 	from raw_data.sales 
 	group by person_name, phone;

 insert into car_shop.color (color)
 	select substring(auto from ', (.*)') as color
 	from raw_data.sales
 	group by color;

 insert into car_shop.brand (brand, id_contry)
 	select 
 	    substring(auto from 1 for position(' ' in auto) - 1) as brand, 
 	    country.id
 	from raw_data.sales
 	left join car_shop.country  ON country.country = raw_data.sales.brand_origin
 	group by brand, country.id;

 insert into car_shop.automobileModel (automobileModel)
 	select
 		substring(auto from position(' ' in auto) + 1 for position(',' in auto) - position(' ' in auto) - 1) as automobileModel
 	from raw_data.sales
 	group by automobileModel;

 insert into car_shop.car (id_brand, id_automobileModel, gasoline_consumption)
 	select 
 		brand.id as b, 
 		automobileModel.id as m1,  
 		gasoline_consumption
 	from raw_data.sales
 	left join car_shop.brand on brand.brand =  substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1) 
 	left join car_shop.automobileModel on automobileModel.automobileModel = substring(raw_data.sales.auto from position(' ' in raw_data.sales.auto) + 1 for position(',' in raw_data.sales.auto) - position(' ' in raw_data.sales.auto) - 1) 
 	group by b, m1, gasoline_consumption;

 insert into car_shop.equipment (id_car, id_color)
 	select 
 		car.id as r,
 		color.id as c
 	from raw_data.sales
 	left join car_shop.color on color.color  =  substring(raw_data.sales.auto from ', (.*)') 
 	left join car_shop.car on concat((select brand from car_shop.brand where brand.id = car.id_brand), (select automobileModel from car_shop.automobileModel where automobileModel.id = car.id_automobileModel)) = concat(substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from position(' ' in raw_data.sales.auto) + 1 for position(',' in raw_data.sales.auto) - position(' ' in raw_data.sales.auto) - 1))
 	group by c, r;

 insert into car_shop.sales (id_equipment, id_buyer, price, date_sale, discont)
 	select 
 		equipment.id, 
 		buyer.id, 
 		raw_data.sales.price,
 		raw_data.sales.date, 
 		raw_data.sales.discount
 	from raw_data.sales
 	left join car_shop.car on concat((select brand from car_shop.brand where brand.id = car.id_brand), (select automobileModel from car_shop.automobileModel where automobileModel.id = car.id_automobileModel)) = concat(substring(raw_data.sales.auto from 1 for position(' ' in raw_data.sales.auto) - 1),substring(raw_data.sales.auto from position(' ' in raw_data.sales.auto) + 1 for position(',' in raw_data.sales.auto) - position(' ' in raw_data.sales.auto) - 1))
 	left join car_shop.color on color.color = substring(raw_data.sales.auto from ', (.*)')
 	left join car_shop.equipment on equipment.id_color = color.id and equipment.id_car = car.id 
 	left join car_shop.buyer on buyer.name = raw_data.sales.person_name 
 	group by equipment.id, buyer.id, raw_data.sales.price, raw_data.sales.date, raw_data.sales.discount;

 --запросы
 --1
 select 100 - (count(gasoline_consumption) * 100) / count(*) as nulls_percentage_gasoline_consumption
 from car_shop.car;

 --2
 select
 	b.brand as brand_name, 
 	extract(year from s.date_sale) as years, 
 	avg(s.price) as price_avg
 from car_shop.sales s
 left join car_shop.equipment e on e.id = s.id_equipment
 left join car_shop.car c on c.id = e.id_car
 left join car_shop.brand b on b.id = c.id_brand
 group by years, brand_name
 order by brand_name;

  --3
 select 
 	extract(month from s.date_sale) as months,
 	extract(year from s.date_sale) as years,
 	round(avg(price), 2) as price_avg
 from car_shop.sales s 
 group by months, years
 having extract(year from s.date_sale) = 2022;

 --4
 select 
 	name as person,
 	string_agg(b2.brand || ' ' ||  m.automobileModel,  ', ') as cars
 from car_shop.sales s
 left join car_shop.buyer b on b.id = s.id_buyer
 left join car_shop.equipment e on e.id = s.id_equipment
 left join car_shop.car c on c.id = e.id_car
 left join car_shop.brand b2 on b2.id = c.id_brand 
 left join car_shop.automobileModel m on m.id =c.id_automobileModel 
 group by person
 order by person;

 --5
 select 
 	country as brand_origin,
 	min(price) as price_min,
 	max(price) as price_max
 from car_shop.sales s 
 left join car_shop.equipment e on e.id = s.id_equipment 
 left join car_shop.car c on c.id = e.id_car 
 left join car_shop.brand b on b.id =c.id_brand 
 left join car_shop.country c2 on c2.id = b.id_contry 
 group by brand_origin
 having country is not null;

 --6
 select count(*) as persons_from_usa_count
 from car_shop.sales s 
 left join car_shop.buyer b on car_shop.buyer.id = s.id_buyer 
 where b.phone like '+1%' 