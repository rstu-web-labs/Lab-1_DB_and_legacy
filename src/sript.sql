create schema raw_data;

CREATE TABLE raw_data.sales (
    id int not NULL,
    auto varchar(255) not NULL,
    gasoline_consumption real,
    price real not NULL,
    date date not NULL,
    person_name varchar(255) not NULL,
    phone varchar(255) not NULL,
    discount int not NULL,
    brand_origin varchar(255)
);

copy raw_data.sales FROM 'D:\cars.csv' WITH CSV HEADER NULL 'null';

create schema car_shop;

-- Цвета
CREATE TABLE car_shop.colors (
	colorId serial primary key,
    color varchar(255)
);

insert into car_shop.colors (color)
	select distinct substring(auto, position (',' in auto) + 2 ) from raw_data.sales;

-- Страны
CREATE TABLE car_shop.country (
	countryId serial primary key,
    brand_origin varchar(255)
);

insert into car_shop.country (brand_origin)
	select distinct brand_origin from raw_data.sales;

-- Марки авто
CREATE TABLE car_shop.brands (
	brandId serial primary key,
    brand varchar(255),
    brand_Country_Id int,
    foreign key (brand_Country_Id) references car_shop.country(countryId)
);

insert into car_shop.brands (brand, brandCountryId)
	select distinct substring(auto, 1, position(' ' in auto) - 1), 
	coalesce(c.countryId, (select countryId from car_shop.country where brand_origin is null))
		from raw_data.sales s
	left join car_shop.country c on c.brand_origin = s.brand_origin;

-- мафынки :3
CREATE TABLE car_shop.autos (
    carId SERIAL PRIMARY KEY,
    model varchar(255) NOT NULL, -- model rename 
    consumption real,
    brandId int,
    colorId int,
    FOREIGN KEY (brandId) REFERENCES car_shop.brands(brandId),
    FOREIGN KEY (colorId) REFERENCES car_shop.colors(colorId)
);

INSERT INTO car_shop.autos (brand, model, color, consumption)
SELECT DISTINCT b.brandId, 
       substring(s.auto, position(' ' in s.auto) + 1, position(',' in s.auto) - position(' ' in s.auto) - 1), 
       c.colorId,
       s.gasoline_consumption
FROM raw_data.sales s
JOIN car_shop.colors c ON c.color = substring(s.auto from position(',' in s.auto) + 2)
JOIN car_shop.brands b ON b.brand = substring(s.auto from 1 for position(' ' in s.auto) - 1);

-- Люди
CREATE TABLE car_shop.persons (
    personId SERIAL PRIMARY KEY,
    person varchar(255) NOT NULL,
    phone varchar(255) NOT NULL
);

insert into car_shop.persons (person, phone)
	select distinct person_name, phone from raw_data.sales;

-- Сделки
CREATE TABLE car_shop.deals (
    dealId SERIAL PRIMARY KEY,
    publicDay date NOT NULL,
    price real NOT NULL,
    discount int NOT NULL,
    carId int,
    personId int,
    FOREIGN KEY (carId) REFERENCES car_shop.autos(carId),
    FOREIGN KEY (personId) REFERENCES car_shop.persons(personId)
);


insert into car_shop.deals(personId, carId, publicDay, price, discount)
	select distinct p.personId, c.carId, s.date, s.price, s.discount
	from raw_data.sales s
	join car_shop.persons p on p.person = s.person_name
	JOIN car_shop.autos c ON c.model = substring(s.auto, position(' ' in s.auto) + 1, position(',' in s.auto) - position(' ' in s.auto) - 1),
	join car_shop.colors col on col.color = substring(auto, position (',' in auto) + 2)
	where c.color = col.colorId;

-- По идее это все конкретно по таблицам

-- АНАЛИТИКА и все что с ней связано --

---- ЗАДАНИЕ 1 ----
select 100 * count(*) / (select count(*) from car_shop.autos)
as cars_with_no_consumption 
from car_shop.autos
where consumption is null;

---- ЗАДАНИЕ 2 ----
select b.brand as brand, 
extract(year from p.publicDay) as year, 
round(avg(p.price)::numeric, 2) as average_price from car_shop.deals p
join car_shop.autos a on a.carId = p.carId
--join car_shop.model_car mc on mc.id_model = c.id_model
join car_shop.brands b on b.brandId = a.brand
group by b.brand, year
order by brand, year asc; 

---- ЗАДАНИЕ 3 ----
select extract(month from p.publicDay) as month,
       extract(year from p.publicDay) as year,
       round(avg(p.price)::numeric, 2) as average_price
from car_shop.deals p
where extract(year from p.publicDay) = 2022
group by extract(month from p.publicDay), extract(year from p.publicDay)
order by extract(month from p.publicDay) asc;

---- ЗАДАНИЕ 4 ----
select p.person as person,
       STRING_AGG(b.brand || ' ' || a.model, ', ') as cars
from car_shop.persons p
join car_shop.deals d on d.personId = p.personId
join car_shop.autos a on a.carId = d.carId
join car_shop.brands b on b.brandId = a.brand
group by p.personId, p.person
order by p.person asc;

---- ЗАДАНИЕ 5 ----
select co.brand_origin, 
round(MAX(p.price * 100 / (100 - p.discount))::numeric, 2) as price_max, 
round(MIN(p.price * 100 / (100 - p.discount))::numeric, 2) as price_min
from car_shop.deals p
join car_shop.autos c on c.carid = p.carid
join car_shop.brands b on b.brandid = c.brand
join car_shop.country co on co.countryid = b.brand_country_id
group by co.brand_origin;

---- ЗАДАНИЕ 6 ----
select count(*) as persons_from_usa_count from car_shop.persons
where phone like('+1%');
