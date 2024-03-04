# Отчет по лабораторной работе №1

* *Целью было перенести в базу данных сырую информацию и привести ее к 3 нормальной форме(3НФ).*

## Что я делал....

#### 1. Скачать все необходимое:
* **Docker** - что-то вроде мини виртуальной машины. Он нам позволяет быстро развертывать и маштабировать наши приложения и тд.(Т.е. с его помощью приложения должны запускаться без доп настройки на сервере или другом компьютере) ~~*Ну по крайней мере я так понял*~~
* **Postgres** - наша база данных.
* **DBeaver** - это приложение, которое помогает взаимодействовать с нашими БД, писать скрипты и тд.(аналоги: pgAdmin, SQL SMS и тд.)

#### 2. Создать контейнер в Docker, где будет храниться БД:

* Для создания контейнера я создал файл **docker-compose** с расширением **yaml** и в него поместил данный код:

```
version: '2.24.3' #Версия нашего Docker`a 

services:
    db_cars:
        container_name: db_cars #Имя контейнера
    ports:
        - "6060:5432" #Порты подключения
    enviroment: #Наши зависимости
        - POSTGRES_PASSWORD=1234554321
        - POSTGRES_USER=kirill
    image: postgres:15.5 #image постгреса для контенера
 ```

 * Далее я открыл терминал и прописал команду:
 ```
 docker-compose up --build # Тут скачается наш image для Docker контейнера, а также создастся наш контейнер
 ```
 
 #### 3. Подключение к БД через DBeaver и работа с ней:

 Есть несколько способов подключиться к БД, но я здесь расскажу о двух:

 * **Через консоль** 
   

   Для этого запускаем нашу cmd и пишем следующее:
   ```
   docker ps -a # Для просмотра всех имеющихся контейнеров
   ```
    В моем случае Вывело следующее
   ```
    CONTAINER ID   IMAGE           COMMAND                  CREATED        STATUS                   PORTS     NAMES
    26c4d5d108b1   postgres:15.5   "docker-entrypoint.s…"   26 hours ago   Exited (0) 4 hours ago             db_cars
   ```
   Тут мы узнали id контейнера, имя, последний запуск, порты и тд.

   Далее Вводим следующую команду для попадения внутрь контейнера в саму postgres:

   ```
   docker exec -it db_cars psql -U kirill life_on_wheels
   ```

    где

    * db_cars - имя контейнера
    * kirill - мой юзер
    * life_on_wheels - моя база данных в контейнере

    Все тут мы можем писать sql запросы. Но это не очень удобно, поэтому я подключился через DBeaver.

    ```
    psql (15.5 (Debian 15.5-1.pgdg120+1))
    Type "help" for help.

    life_on_wheels=#

    ```
* **Через DBeaver** 

    При подключении через DBeaver обязательно нужно ввести своего юзера, пароль, порт подключения( мы их писали в файле docker-compose в пункте 2)

    **Все Мы подключились к БД**

    Также забыл упамянуть, что я перенес файл cars.csv также в докер, чтобы было удобнее через консольную команду:

    ```
    docker cp cars.csv 26c4d5d108b1:/home/cars.csv # Тут я сохраняю csv файл по адресу /home/cars.csv
    ```

 #### 4. Запросы и SQL

 Тут мы создаем новую схему через графический интерфейс, подключаемся к ней.


 Далее делаем запрос на создание сырой таблицы: 
 ```
create schema if not exists raw_data;

create table if not exists raw_data.sales (
id int primary key not null,
auto varchar(40) not null,
gasoline_consumption numeric null check (gasoline_consumption >= 0),
price numeric not null check (price >= 0),
date date not null,
person_name varchar(50) not null,
phone varchar(30) not null,
discount numeric null check (discount >= 0),
brand_origin varchar(60) null
);

 ```

И загружаем в нее данные из csv с разделителем ',' и если нулевое поле то ставим null:

```
copy raw_data.sales(id, auto, gasoline_consumption, price, date, person_name, phone, discount, brand_origin)
from '/home/cars.csv' delimiter ',' csv header null 'null';
```
Дальше нормализуем нашу БД(Полностью листинг запросов для нормализации ниже. Мне в падлу все это описывать):

```
create schema if not exists car_shop;

create table if not exists car_shop.colors (
idColor serial primary key,
color varchar(20) unique null
);

create table if not exists car_shop.marks(
idMarka serial primary key,
marka varchar(30) unique not null 
);

create table if not exists car_shop.country (
idCountry serial primary key,
country varchar(60) null
);


create table if not exists car_shop.models(
idModel serial primary key,
model varchar(30) unique not null,
gasoline_consumption numeric unique null check (gasoline_consumption >= 0)
);

create table if not exists car_shop.cars(
idCars serial primary key,
idColor int not null references car_shop.colors(idColor) ON DELETE CASCADE,
idMarka int not null references car_shop.marks(idMarka) ON DELETE CASCADE,
idModel int not null references car_shop.models(idModel) ON DELETE CASCADE,
idCountry int references car_shop.country(idCountry)
);

create table if not exists car_shop.clients (
idClient serial primary key,
person_name varchar(50) not null,
phone varchar(30) not null
);

create table if not exists car_shop.sales(
idSales serial primary key,
idClient int not null references car_shop.clients(idClient) ON DELETE CASCADE,
price numeric not null check (price >= 0),
discount numeric null check (discount >= 0),
date date not null
);

create table if not exists car_shop.autoInfo (
idAuto serial primary key,
idCars int not null references car_shop.cars(idCars) ON DELETE CASCADE,
idSales int not null references car_shop.sales(idSales) ON DELETE CASCADE
);

insert into car_shop.colors(color)
select distinct split_part(auto, ',', 2)
from raw_data.sales;

insert into car_shop.clients(person_name, phone)
select distinct person_name, phone
from raw_data.sales;

insert into car_shop.marks(marka) 
select distinct split_part(auto, ' ', 1)
from raw_data.sales;

insert into car_shop.country(country)
select distinct brand_origin
from raw_data.sales;

insert into car_shop.models(model, gasoline_consumption) 
select distinct trim(substring(auto, char_length(split_part(auto, ' ', 1)) + 1, char_length(auto) - char_length(split_part(auto, ' ', 1)) - char_length(split_part(auto, ',', 2)) - 1)), gasoline_consumption
from raw_data.sales;

insert into car_shop.cars (idColor, idMarka, idModel, idCountry)
select distinct col.idColor, mar.idMarka, md.idModel, co.idCountry
from raw_data.sales sal
join car_shop.colors col on col.color = split_part(sal.auto, ',', 2)
join car_shop.marks mar on mar.marka = split_part(sal.auto, ' ', 1)
join car_shop.models md on md.model = trim(substring(sal.auto, char_length(split_part(sal.auto, ' ', 1)) + 1, char_length(sal.auto) - char_length(split_part(sal.auto, ' ', 1)) - char_length(split_part(sal.auto, ',', 2)) - 1))
left join car_shop.country co on sal.brand_origin = co.country;

insert into car_shop.sales (price, discount, date, idClient)
select distinct price, discount, date, c.idClient
from raw_data.sales s
join car_shop.clients c on s.phone = c.phone;

insert into car_shop.autoInfo (idCars, idSales)
select b.idCars, s2.idSales
from raw_data.sales s 
join car_shop.cars b on 
trim(split_part(s.auto, ' ', 1)) = trim((select marka from car_shop.marks m where m.idmarka = b.idmarka)) and
trim(split_part(s.auto, ',', 2)) = trim((select color from car_shop.colors c2 where c2.idcolor = b.idcolor)) and
trim(substring(auto, char_length(split_part(auto, ' ', 1)) + 1, char_length(auto) - char_length(split_part(auto, ' ', 1)) - char_length(split_part(auto, ',', 2)) - 1)) = trim((select model from car_shop.models m where m.idmodel = b.idmodel))
join car_shop.sales s2 on s.price  = s2.price and s."date" = s2."date"
```

 #### 5. Задания на запросы
 Листинг полностью:

 ```
 -- Аналитические скрипты


--Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
select count(*) * 100.0 / (select count(*) from car_shop.cars) as nulls_percentage_gasoline_consumption
from car_shop.models m 
where gasoline_consumption is null;

--Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
--Итоговый результат отсортируйте по названию бренда и году в восходящем порядке.
--Среднюю цену округлите до второго знака после запятой. Формат итоговой таблицы:
select
    m.marka as "brand_name",
    extract(year from s."date") as "year",
    round(avg(s.price * (1 - s.discount / 100)), 2) AS "price_avg"
from car_shop.autoInfo a
join car_shop.cars b ON a.idCars = b.idCars
join car_shop.sales s ON a.idSales = s.idSales
join car_shop.marks m ON b.idMarka = m.idMarka
group by m.marka, EXTRACT(YEAR FROM s."date")
order by m.marka ASC, "price_avg" ASC;


--Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
--Результат отсортируйте по месяцам в восходящем порядке. 
--Среднюю цену округлите до второго знака после запятой.
select
    extract(MONTH from date) as month,
    extract(YEAR from date) as "year",
    round(avg(price * (1 - discount / 100)), 2) as average_price
from raw_data.sales
where extract(YEAR from date) = 2022
group by extract(MONTH from date), extract(YEAR from date)
order by month asc;

   
   --Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. 
--Пользователь может купить две одинаковые машины — это нормально. Название машины покажите полное, с названием бренда — например: 
--Tesla Model 3. Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.
select
    c.person_name as "person",
    string_agg(concat(m.marka, ' ', md.model), ', ') as "cars"
from car_shop.sales s
join car_shop.autoInfo a on s.idSales = a.idSales
join car_shop.clients c on s.idClient = c.idClient
join car_shop.cars b on a.idCars = b.idCars
join car_shop.marks m on b.idMarka = m.idMarka
join car_shop.models md on b.idModel = md.idModel
group by c.person_name
order by c.person_name asc;




--Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
--Цена в колонке price дана с учётом скидки.
select
    co.country as "brand_origin",
    MAX(s.price) as "price_max",
    MIN(s.price) as "price_min"
from car_shop.autoInfo a
join car_shop.sales s on a.idSales = s.idSales
left join car_shop.country co on a.idCars = co.idCountry
group by co.country;





   --Напишите запрос, который покажет количество всех пользователей из США. 
--Это пользователи, у которых номер телефона начинается на +1.
select count(*) AS usa_users_count
from car_shop.clients
where phone LIKE '+1%';


 ```

## Вот и все.