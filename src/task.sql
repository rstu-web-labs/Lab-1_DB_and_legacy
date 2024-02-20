----- создание схемы raw_data -----
CREATE SCHEMA raw_data;

----- cоздание таблицы sales для сырых данных -----
CREATE TABLE raw_data.sales 
( id smallint PRIMARY KEY,
  auto varchar(255) NOT NULL,
  gasoline_consumption numeric(4,2) CHECK (gasoline_consumption < 100),
  price numeric(50, 20),
  date date,
  person_name varchar(255) NOT NULL,
  phone varchar(255),
  discount numeric(4,2) CHECK (discount >= 0),
  brand_origin varchar(255) 
	CHECK (brand_origin IN ('Russia', 'Germany', 'South Korea', 'USA')));

--заполнение таблицы sales данными
copy raw_data.sales 
FROM '\cars.csv' 
WITH csv header NULL 'null' delimiter ',';

----- cоздание схемы car_shop для нормализованной БД -----
CREATE SCHEMA car_shop;

---создание и заполнение таблицы цветов color
CREATE TABLE car_shop.color (
	id_color serial PRIMARY KEY,
	name_color varchar(255));

INSERT INTO car_shop.color  (name_color)
SELECT DISTINCT substring(auto, position (',' IN auto) + 2 )  FROM raw_data.sales;

---создание и заполнение таблицы стран country
CREATE TABLE car_shop.country (
	id_country serial PRIMARY KEY,
	brand_origin varchar(255));

INSERT INTO car_shop.country  (brand_origin)
SELECT DISTINCT brand_origin FROM raw_data.sales;

---создание и заполнение таблицы клиентов people
CREATE TABLE car_shop.people (
	id_person serial PRIMARY KEY,
	name_person varchar(255),
	phone varchar(255));

INSERT INTO car_shop.people  (name_person, phone)
SELECT DISTINCT person_name, phone  FROM raw_data.sales;

---создание и заполнение таблицы брендов brand связанной вторичным ключом id_country с таблицей country
CREATE TABLE car_shop.brand (
	id_brand serial PRIMARY KEY,
	id_country int,
	name_brand varchar(255),
	CONSTRAINT fk_constraint_country FOREIGN KEY (id_country) 
		REFERENCES car_shop.country(id_country));

INSERT INTO car_shop.brand (name_brand, id_country)
SELECT DISTINCT substring(auto, 1, position(' ' IN auto) - 1), 
coalesce(c.id_country, (SELECT  id_country FROM  car_shop.country WHERE brand_origin IS NULL))
FROM raw_data.sales s
LEFT JOIN car_shop.country c ON c.brand_origin = s.brand_origin;


---создание и заполнение таблицы моделей машин model_car
CREATE TABLE car_shop.model_car (
	id_model serial PRIMARY KEY,
	id_brand int,
	name_model varchar(255),
	gasoline_consumption numeric(4,2) CHECK (gasoline_consumption < 100),
	CONSTRAINT fk_constraint_brand FOREIGN KEY (id_brand)
	REFERENCES car_shop.brand(id_brand));

INSERT INTO car_shop.model_car (id_brand, name_model, gasoline_consumption)
SELECT DISTINCT b.id_brand, 
substring(s.auto, position(' ' IN s.auto)+1, position(',' IN s.auto)-position(' ' IN s.auto)-1), 
s.gasoline_consumption
FROM raw_data.sales s
JOIN car_shop.brand b ON b.name_brand = substring(s.auto, 1, position(' ' IN s.auto)-1); 

---создание и заполнение таблицы cars 
CREATE TABLE car_shop.cars (
	id_car serial PRIMARY KEY,
	id_color int, 
	id_model int,
	CONSTRAINT fk_constraint_color FOREIGN KEY (id_color)
	REFERENCES car_shop.color(id_color),
	CONSTRAINT fk_constraint_model FOREIGN KEY (id_model)
	REFERENCES car_shop.model_car(id_model)
	);

INSERT INTO car_shop.cars (id_model, id_color)
SELECT DISTINCT mc.id_model, c.id_color
FROM raw_data.sales s
JOIN car_shop.model_car mc ON mc.name_model = (SELECT substring(s.auto, position(' ' IN s.auto)+1, position(',' IN s.auto)-position(' ' IN s.auto)-1))
JOIN car_shop.color c ON c.name_color = (SELECT substring(auto, position (',' IN auto) + 2 ))
LEFT JOIN car_shop.cars ca ON ca.id_model = mc.id_model AND ca.id_color = c.id_color
WHERE ca.id_model IS NULL;

---создание и заполнение таблицы покупок purchases
CREATE TABLE car_shop.purchases (
	id_purchases serial PRIMARY KEY,
	id_car int, 
	id_person int,
	date_purch date,
	price numeric(50, 20),
	discount numeric(4,2) CHECK (discount >= 0),
	CONSTRAINT fk_constraint_people FOREIGN KEY (id_person)
	REFERENCES car_shop.people(id_person),
	CONSTRAINT fk_constraint_car FOREIGN KEY (id_car)
	REFERENCES car_shop.cars(id_car));

INSERT INTO car_shop.purchases (id_person, id_car, date_purch, price, discount)
SELECT DISTINCT p.id_person, c.id_car, s.date, s.price, s.discount
FROM raw_data.sales s
JOIN car_shop.people p on p.name_person = s.person_name
JOIN car_shop.cars c on c.id_model = (
    SELECT id_model
    FROM car_shop.model_car mc
    WHERE mc.name_model = substring(s.auto, position(' ' IN s.auto)+1, position(',' IN s.auto)-position(' ' IN s.auto)-1)
)
JOIN car_shop.color col ON col.name_color = substring(auto, position (',' IN auto) + 2)
WHERE c.id_color = col.id_color;

----- создание нормализованной БД завершено -----


-------------------------------
---- аналитические скрипты ----
-------------------------------

--- Задание №1
Напишите запрос, который выведет процент моделей машин, у которых 
нет параметра gasoline_consumption.
--- скрипт
select 100.0 * count(*) / (select count(*) from car_shop.model_car) 
as nulls_percentage_gasoline_consumption 
from car_shop.model_car
where gasoline_consumption is null;
--- вывод:
nulls_percentage_gasoline_consumption
21.0526315789473684

--- Задание №2
Напишите запрос, который покажет название бренда и среднюю цену его автомобилей 
в разбивке по всем годам с учётом скидки. 
Итоговый результат отсортируйте по названию бренда и году в восходящем порядке. 
Среднюю цену округлите до второго знака после запятой. 
--- скрипт
select b.name_brand as  brand_name, 
extract(year from p.date_purch) as year, 
round(avg(p.price), 2) as price_avg from car_shop.purchases p
join car_shop.cars c on c.id_car = p.id_car
join car_shop.model_car mc on mc.id_model = c.id_model
join car_shop.brand b on b.id_brand = mc.id_brand
group by b.name_brand, year
order by brand_name, year asc;
--- вывод:
brand_name year price_avg
Audi	2015	22916.25
Audi	2016	24352.11
Audi	2017	23999.71
Audi	2018	27624.28
Audi	2019	29769.92
Audi	2020	20721.39
Audi	2021	26392.70
Audi	2022	24959.42
BMW	2015	32233.01
BMW	2016	39340.13
BMW	2017	39732.89
BMW	2018	49208.71
BMW	2019	50566.10
BMW	2020	35635.37
BMW	2021	41729.51
BMW	2022	43771.15
Hyundai	2015	29507.85
Hyundai	2016	31478.32
Hyundai	2017	30657.53
Hyundai	2018	38453.55
Hyundai	2019	46019.59
Hyundai	2020	29556.56
Hyundai	2021	38138.73
Hyundai	2022	34661.25
Kia	2015	18511.28
Kia	2016	21261.24
Kia	2017	20653.25
Kia	2018	26570.69
Kia	2019	29145.34
Kia	2020	21572.93
Kia	2021	23141.44
Kia	2022	25629.19
Lada	2015	13371.78
Lada	2016	15135.72
Lada	2017	14793.19
Lada	2018	16625.01
Lada	2019	18126.99
Lada	2020	13209.14
Lada	2021	14427.54
Lada	2022	15525.35
Porsche	2015	47773.73
Porsche	2016	57711.60
Porsche	2017	60424.54
Porsche	2018	75175.51
Porsche	2019	80885.01
Porsche	2020	51828.80
Porsche	2021	68421.81
Porsche	2022	60978.89
Tesla	2015	41302.83
Tesla	2016	43283.91
Tesla	2017	42953.84
Tesla	2018	54885.39
Tesla	2019	58383.72
Tesla	2020	37922.41
Tesla	2021	46284.03
Tesla	2022	43069.42

--- Задание №3
Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. 
Результат отсортируйте по месяцам в восходящем порядке. 
Среднюю цену округлите до второго знака после запятой.
--- скрипт
select extract(month from p.date_purch) as month,
       extract(year from p.date_purch) as year,
       round(avg(p.price), 2) as price_avg
from car_shop.purchases p
where extract(year from p.date_purch) = 2022
group by extract(month from p.date_purch), extract(year from p.date_purch)
order by extract(month from p.date_purch) asc;
--- вывод:
month   year   price_avg
1	2022	37388.15
2	2022	35576.02
3	2022	45521.52
4	2022	31545.32
5	2022	32791.81
6	2022	29305.94
7	2022	30202.75
8	2022	37881.63
9	2022	29794.27
10	2022	40999.05
11	2022	22819.33
12	2022	32969.64


--- Задание №4
Используя функцию STRING_AGG, напишите запрос, который выведет 
список купленных машин у каждого пользователя через запятую. 
Пользователь может купить две одинаковые машины — это нормально. 
Название машины покажите полное, с названием бренда — например: Tesla Model 3. 
Отсортируйте по имени пользователя в восходящем порядке. 
Сортировка внутри самой строки с машинами не нужна.
--- скрипт
select p.name_person as person,
       STRING_AGG(b.name_brand || ' ' || mc.name_model, ', ') as cars
from car_shop.people p
join car_shop.purchases pc on pc.id_person = p.id_person
join car_shop.cars c on c.id_car = pc.id_car
join car_shop.model_car mc on mc.id_model = c.id_model
join car_shop.brand b on b.id_brand = mc.id_brand
group by p.id_person, p.name_person
order by p.name_person asc;
--- вывод:
	person 		cars
1	Aaron Montgomery	BMW M3
2	Adam Friedman	Lada Kalina
3	Adam Nicholson	Porsche 911
4	Adam Ryan	Hyundai Sonata
5	Adam Stevens	Hyundai Elantra
6	Adrian Cabrera	Audi S3, Audi S3
7	Adrienne Campbell	Tesla Model Y
...	...	...
892	Zachary Long	Audi A3
893	Zachary Montes	BMW F80, Tesla Model X
894	Zachary Robinson	Kia Rio

--- Задание №5
Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля 
с разбивкой по стране без учёта скидки. Цена в колонке price дана с учётом скидки.
--- скрипт
select co.brand_origin, 
round(MAX(p.price * 100 / (100 - p.discount)), 2) as price_max, 
round(MIN(p.price * 100 / (100 - p.discount)), 2) as price_min
from car_shop.purchases p
join car_shop.cars c on c.id_car = p.id_car
join car_shop.model_car mc on mc.id_model = c.id_model
join car_shop.brand b on b.id_brand = mc.id_brand
join car_shop.country co on co.id_country = b.id_country
group by co.brand_origin;
--- вывод:
brand_origin price_max price_min
	92512.10	29705.40
USA	80663.38	20488.65
Germany	72666.75	11134.26
South Korea	60255.00	9846.75
Russia	25924.80	6198.60

--- Задание №6
Напишите запрос, который покажет количество всех пользователей из США. 
Это пользователи, у которых номер телефона начинается на +1.
--- скрипт
select count(*) as persons_from_usa_count from car_shop.people 
where phone like('+1%');
--- вывод:
persons_from_usa_count
131
