create schema raw_data;--создали схему, где будем хранить сырые данные в таблице

create table raw_data.sales (
  id INT not null,--целочисленный тип данных, т.к. переносим id
  auto VARCHAR(100) not null,--строковый тип, т.к. переносим название, модель и цвет текстом
  gasoline_consumption DECIMAL,--вещественный тип, позволяет хранить данные с плавающей точкой, точнее чем float
  price DECIMAL not null,--цена, дробное число
  date DATE not null,--хранит дату в формате гггг.мм.дд
  person VARCHAR(100) not null,
  phone VARCHAR(100) not null,--подходит varchar, т.к. в сырых данных представлены разные форматы телефонных номеров
  discount INT not null,--размер скидки целый
  brand_origin VARCHAR(50)--название страны-производителя
);

COPY sales --скопировали данные файла в таблицу сырых данных
FROM '/tmp/cars.csv'
WITH csv header 
null 'null';

create schema car_shop;--создали схему с таблицами для нормализации данных

create table car_shop.color (
  id serial primary key not null,
  color VARCHAR(50) not null unique
);


create table car_shop.brand_origin (
  id serial primary key not null,
  country VARCHAR(50) unique not null
);


create table car_shop.brand (
  id serial primary key not null,--serial автоинкремент по умолчанию (нач 1, приращ 1), primary key - уникальный первичный ключ
  brand_name VARCHAR(50) not null unique,--unique гарантирует уникальность данных 
  country_id INT,
  constraint brand_country
  foreign key(country_id)
  references car_shop.brand_origin(id)
  on update cascade 
  on delete cascade
);


create table car_shop.model (
  id serial primary key not null,
  model VARCHAR(50) not null unique,
  brand_id INT,
  constraint model_brand 
  foreign key(brand_id) 
  references car_shop.brand(id)
  on update cascade
  on delete cascade,
  gasoline_consumption DECIMAL 
);


create table car_shop.auto (
  id serial primary key not null,
  model_id INT,
  constraint auto_model 
  foreign key(model_id) 
  references car_shop.model(id)
  on update cascade
  on delete cascade,
  color_id INT,
  constraint auto_color
  foreign key(color_id) 
  references car_shop.color(id)
  on update cascade
  on delete cascade
);

create table car_shop.customer (
  id serial primary key not null,
  name VARCHAR(50) not null,
  surname VARCHAR(50) not null,
  phone_number VARCHAR(50) not null unique
);

create table car_shop.deal (
  id serial primary key not null,
  auto_id int,
  constraint deal_auto
  foreign key(auto_id) 
  references car_shop.auto(id)
  on update cascade
  on delete cascade,
  customer_id int,
  constraint deal_customer 
  foreign key(customer_id) 
  references car_shop.customer(id)
  on update cascade
  on delete cascade,
  date date not null,
  price decimal not null,
  discount int not null
); 


insert into car_shop.color (color)
select distinct split_part(auto, ',', 2)
from raw_data.sales;


insert into car_shop.brand_origin (country)
select distinct brand_origin
from raw_data.sales
where brand_origin is not null;


insert into car_shop.brand (brand_name, country_id)
select distinct split_part(s.auto, ' ', 1), bo.id 
from raw_data.sales s 
left join car_shop.brand_origin bo on bo.country = s.brand_origin;


insert into car_shop.model (model, brand_id, gasoline_consumption)
select distinct substring(s.auto, position(' ' in auto) + 1, position(',' in auto) - position(' ' in auto) - 1), b.id, s.gasoline_consumption
from raw_data.sales s
left join car_shop.brand b on b.brand_name = split_part(s.auto, ' ', 1);


insert into car_shop.customer (name, surname, phone_number)
select distinct split_part(person, ' ', 1), split_part(person, ' ', 2), phone
from raw_data.sales;


insert into car_shop.auto (model_id, color_id)
select m.id, c.id
from raw_data.sales s
left join car_shop.model m on m.model = substring(s.auto, position(' ' in s.auto) + 1, position(',' in s.auto) - position(' ' in s.auto) - 1)
left join car_shop.color c on c.color = split_part(s.auto, ',', 2);


insert into car_shop.deal (auto_id, customer_id, date, price, discount)
select a.id, cus.id, s.date, s.price, s.discount
from raw_data.sales s  
left join car_shop.auto a on a.id = s.id 
left join car_shop.customer cus on cus.phone_number = s.phone;


--задание 1
--Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
select (count(*) * 100.0) / (select count(*) from car_shop.model) as nulls_percentage_gasoline_consumption
from car_shop.model
where gasoline_consumption is null;

--задание 2
/*Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
Итоговый результат отсортируйте по названию бренда и году в восходящем порядке.
Среднюю цену округлите до второго знака после запятой.*/
select b.brand_name as brand_name, 
extract(year from d.date) as year,--extract извлекает год из даты
round(avg(d.price * (1 - d.discount/100.0)), 2) as price_avg--round округляет среднюю цену до 2 знаков после запятой
from car_shop.deal d
join car_shop.auto a on d.auto_id = a.id
join car_shop.model m on a.model_id = m.id
join car_shop.brand b on m.brand_id = b.id
group by b.brand_name, year--группируем по названию бренда и году
order by b.brand_name, year;--сортируем по названию бренда и году

--задание 3
/*Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
Результат отсортируйте по месяцам в восходящем порядке.
Среднюю цену округлите до второго знака после запятой.*/
select extract(month from d.date) as month,
extract(year from d.date) as year,
round(avg(d.price * (1 - d.discount/100.0)), 2) as price_avg
from car_shop.deal d
where extract(year from d.date) = 2022
group by month, year
order by month;

--задание 4
/*Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую.
Пользователь может купить две одинаковые машины — это нормально. 
Название машины покажите полное, с названием бренда — например: Tesla Model 3. 
Отсортируйте по имени пользователя в восходящем порядке.*/
select string_agg(c.name || ' ' || c.surname, ',') as person,
string_agg(b.brand_name || ' ' || m.model, ',') as cars--|| используется для конкатенации строк
from car_shop.deal d 
join car_shop.customer c on c.id = d.customer_id 
join car_shop.auto a on a.id = d.auto_id 
join car_shop.model m on m.id = a.model_id 
join car_shop.brand b on b.id = m.brand_id
group by c.id 
order by person;


--задание 5
/*Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки.
Цена в колонке price дана с учётом скидки.*/
select bo.country as brand_origin, max(d.price) as price_max, min(d.price) as price_min
from car_shop.deal d 
join car_shop.auto a on a.id = d.auto_id 
join car_shop.model m on m.id = a.model_id 
join car_shop.brand b on b.id = m.brand_id 
join car_shop.brand_origin bo on bo.id = b.country_id 
group by brand_origin;


--задание 6
/*Напишите запрос, который покажет количество всех пользователей из США. Это пользователи, у которых номер телефона начинается на +1.*/
select count(*) as persons_from_usa_count
from car_shop.customer 
where customer.phone_number like '+1%';