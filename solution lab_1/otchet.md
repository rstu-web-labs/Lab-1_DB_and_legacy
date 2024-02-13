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
 DROP TABLE IF EXISTS cars;

CREATE TABLE cars (
    id SERIAL PRIMARY KEY,
    auto VARCHAR(40) NULL,
    gasoline_consumption DECIMAL NULL,
    price DECIMAL NULL,
    date DATE NULL,
    person_name VARCHAR(50) NULL,
    phone VARCHAR(30) NULL,
    discount INT NULL,
    brand_origin VARCHAR(50) NULL
);
 ```

И загружаем в нее данные из csv с разделителем ',' и если нулевое поле то ставим null:

```
COPY cars FROM '/home/cars.csv' DELIMITER ',' CSV HEADER NULL 'null';
```
Дальше нормализуем нашу БД(Полностью листинг запросов для нормализации ниже. Мне в падлу все это описывать):

```
alter table cars
add column marka varchar(30) NULL;

alter table cars
add column color varchar(20) NULL;

alter table cars
add column number_phone varchar(30) NULL;

alter table cars
add column internal_number varchar(10) NULL;

update cars 
set marka = split_part(auto, ',', 1);

update cars 
set color = split_part(auto, ',', 2);

update cars 
set number_phone = split_part(phone, 'x', 1);

update cars 
set internal_number = null;

UPDATE cars
SET internal_number = split_part(phone, 'x', 2)
WHERE phone LIKE '%x%';

alter table cars 
drop column auto;

alter table cars 
drop column phone;

DROP TABLE IF EXISTS carInfo;

CREATE TABLE carInfo (
    carId SERIAL PRIMARY KEY,
    marka VARCHAR(30) NOT NULL,
    color VARCHAR(20),
    gasoline_consumption DECIMAL,
    price DECIMAL NOT NULL,
    discount INT,
    brand_origin VARCHAR(50)
);

DROP TABLE IF EXISTS salesCar;

CREATE TABLE salesCar (
    salesCarId SERIAL PRIMARY KEY,
    carId INT REFERENCES carInfo(carId),
    date DATE,
    person_name VARCHAR(50),
    number_phone VARCHAR(30),
    internal_phone VARCHAR(10)
);

INSERT INTO carInfo(carId, marka, color, gasoline_consumption, price, discount, brand_origin)
SELECT id, marka, color, gasoline_consumption, price, discount, brand_origin FROM cars;

INSERT INTO salesCar (carId, date, person_name, number_phone, internal_phone)
SELECT id, date, person_name, number_phone, internal_number from cars

drop table cars
```

 #### 5. Задания на запросы
 Листинг полностью:

 ```
 
--Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
select count(*) * 100.0 / (select count(*) from carInfo) as percentage
from carInfo
where gasoline_consumption is null;


--Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.
--Итоговый результат отсортируйте по названию бренда и году в восходящем порядке.
--Среднюю цену округлите до второго знака после запятой. Формат итоговой таблицы:
select split_part(marka, ' ', 1) as "Название бренда",
    extract(year from date) as "Год",
    round(avg(price * (1 - discount / 100.0)), 2) as "Средняя цена с учетом скидки"
from carInfo
join salesCar on carInfo.carId = salesCar.carId
group by split_part(marka, ' ', 1), extract(year from date)
order by "Название бренда", "Год";


--Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
--Результат отсортируйте по месяцам в восходящем порядке. 
--Среднюю цену округлите до второго знака после запятой.
select
    extract(month from date) as "Месяц",
    round(avg(price * (1 - discount / 100.0)), 2) as "Средняя цена с учетом скидки"
from carInfo
join salesCar ON carInfo.carId = salesCar.carId
where extract(year from date) = 2022
group by extract(month from date)
order by "Месяц";


--Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. 
--Пользователь может купить две одинаковые машины — это нормально. Название машины покажите полное, с названием бренда — например: 
--Tesla Model 3. Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.
select
    person_name as "Имя пользователя",
    string_agg(concat(carInfo.marka), ', ') as "Список купленных машин"
from salesCar
join carInfo on salesCar.carId = carInfo.carId
group by person_name
order by "Имя пользователя" asc;


--Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
--Цена в колонке price дана с учётом скидки.
select 
    carInfo.brand_origin as "Страна",
    max(carInfo.price / (1 - carInfo.discount / 100.0)) as "Самая высокая цена",
    min(carInfo.price / (1 - carInfo.discount / 100.0)) as "Самая низкая цена"
from carInfo
join salesCar on salesCar.carId = carInfo.carId
group by carInfo.brand_origin;


--Напишите запрос, который покажет количество всех пользователей из США. 
--Это пользователи, у которых номер телефона начинается на +1.
select count(*) as "Rоличество всех пользователей из США"
from salescar 
where number_phone like '+1%';
 ```

## Вот и все.