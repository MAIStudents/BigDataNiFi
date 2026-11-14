# BigDataNiFi
Анализ больших данных - лабораторная работа №5 - Low-code с помощью NiFi и визуализация данных в Metabase

Выполнил: Крючков Артемий Владимирович, группа М8О-205СВ-25.

## Как запустить лабораторную работу

Требуется установленный Docker (при первом запуске нужен интернет: качаются образы Kafka, PostgreSQL, NiFi, Metabase и JDBC-драйвер PostgreSQL для NiFi).

Из корня репозитория:

```bash
docker compose up -d
```

При старте автоматически выполняется:

1. Поднимается Apache Kafka 3.9 (KRaft, без ZooKeeper).
2. Запускается приложение-продюсер (Python): читает 10 файлов `MOCK_DATA*.csv`, каждую строку преобразует в JSON и отправляет сообщением в топик `mock_data` (всего 10000 сообщений), после чего завершается.
3. Поднимается PostgreSQL 17 (порт на хосте 5436, база `bigdatanifi`): создается таблица `mock_data` и 6 представлений-отчетов.
4. Поднимается Apache NiFi 2.1 (Web UI на https://localhost:8443) с уже загруженным готовым flow (3 процессора и 4 контрол-сервиса, процессоры остановлены — запуск описан ниже).
5. Поднимается Metabase (http://localhost:3000).

Дождитесь статуса `healthy` всех сервисов (`docker compose ps`; NiFi стартует около минуты). Затем запустите NiFi-приложение по инструкции ниже — данные из Kafka потекут в PostgreSQL в режиме streaming.

## Запуск NiFi-приложения

1. Откройте https://localhost:8443/nifi (браузер предупредит о самоподписанном сертификате — продолжите переход).
2. Войдите: логин `admin`, пароль `bigdatanifi12`.
3. На холсте уже загружен flow «Kafka → PostgreSQL»:

   - процессор `Consume Kafka` — читает топик `mock_data` (группа `nifi-lab5`, смещение `earliest`), сообщения парсятся как записи JSON;
   - процессор `Write to PostgreSQL` — вставляет записи в таблицу `public.mock_data` (batch INSERT через пул соединений);
   - процессор `Log Failures` — пишет в лог отфильтрованные ошибки разбора и записи;
   - контрол-сервисы: `JsonTreeReader`, `JSON Record Set Writer`, `Kafka Connection` (kafka:9092), `PostgreSQL Connection Pool` (postgres:5432/bigdatanifi) — все включены.

4. Нажмите кнопку `Start` на панели Operate слева (или правой кнопкой по холсту → Start) — запустятся все процессоры.
5. Следите за счетчиками In/Out на процессорах: ~30 секунд, и в PostgreSQL будет 10000 строк (`docker compose exec postgres psql -U postgres -d bigdatanifi -c "SELECT count(*) FROM mock_data"`).
6. Кнопка `Stop` останавливает поток.

## Приложение для отправки данных в Kafka

Запускается автоматически при `docker compose up -d`. Читает файлы `исходные данные/MOCK_DATA*.csv`, каждую строку CSV преобразует в JSON (числовые поля — числа, даты — в формате ISO `YYYY-MM-DD`) и отправляет в топик `mock_data`. Результат: `docker compose logs producer` → `sent messages: 10000`.

Повторная отправка тех же данных:

```bash
docker compose run --rm producer
```

Внимание: `Write to PostgreSQL` делает обычные INSERT без дедупликации, поэтому повторный запуск продюсера добавит дубликаты. Для чистого прогона с нуля:

```bash
docker compose down -v && docker compose up -d
```

## Визуализация в Metabase

1. Откройте http://localhost:3000 (после старта контейнера Metabase отвечает через ~1 минуту).
2. Первичная настройка: выберите язык, укажите имя организации и создайте учетную запись администратора (email и пароль любые).
3. Подключите базу (Administration → Databases → Add database):
   - Database type: `PostgreSQL`
   - Name: `bigdatanifi`
   - Host: `postgres`, Port: `5432`, Database name: `bigdatanifi`
   - Username: `postgres`, Password: `postgres`
4. Создавайте вопросы: New → SQL Query, база `bigdatanifi`. Примеры вопросов и графиков:
   - Топ-10 продуктов по выручке (Bar chart): `SELECT product_name, product_brand, total_revenue FROM rpt_product_sales ORDER BY total_revenue DESC LIMIT 10`
   - Выручка по категориям (Pie chart): `SELECT product_category, sum(total_revenue) AS revenue FROM rpt_product_sales GROUP BY product_category ORDER BY revenue DESC`
   - Тренд продаж по месяцам (Line chart): `SELECT month_name, total_revenue FROM rpt_time_sales ORDER BY year, month`
   - Топ-10 клиентов по сумме покупок (Bar chart / Table): `SELECT first_name, last_name, email, country, total_revenue FROM rpt_customer_sales ORDER BY total_revenue DESC LIMIT 10`
   - Топ-5 магазинов по выручке (Bar chart): `SELECT store_name, store_city, total_revenue FROM rpt_store_sales ORDER BY total_revenue DESC LIMIT 5`
   - Средняя цена товаров по топ-5 поставщикам (Table): `SELECT supplier_name, supplier_country, sales_cnt, total_revenue, avg_product_price FROM rpt_supplier_sales ORDER BY total_revenue DESC LIMIT 5`
5. Соберите дашборд: New → Dashboard «Лабораторная работа №5» и добавьте в него созданные вопросы.

## Подключение (DBeaver)

| БД         | URL / Host                    | Пользователь | Пароль     |
| ---------- | ----------------------------- | ------------ | ---------- |
| PostgreSQL | localhost:5436, база bigdatanifi | postgres   | postgres   |
| NiFi       | https://localhost:8443        | admin        | bigdatanifi12 |
| Metabase   | http://localhost:3000         | задается при настройке | — |

## Проверка результата

Сырые данные в PostgreSQL (таблица `mock_data`, без агрегаций, заполняется NiFi в streaming-режиме):

```sql
SELECT count(*), sum(sale_total_price) FROM mock_data;
```

Ожидается: 10000, 2529852.12.

Строки отчетов-представлений (ожидается 3233, 10000, 12, 10000, 10000, 3233):

```sql
SELECT (SELECT count(*) FROM rpt_product_sales),
       (SELECT count(*) FROM rpt_customer_sales),
       (SELECT count(*) FROM rpt_time_sales),
       (SELECT count(*) FROM rpt_store_sales),
       (SELECT count(*) FROM rpt_supplier_sales),
       (SELECT count(*) FROM rpt_product_quality);
```

Топ-10 самых продаваемых продуктов по выручке:

```sql
SELECT product_name, product_brand, sales_cnt, total_revenue, avg_price, avg_rating, avg_reviews
FROM rpt_product_sales
ORDER BY total_revenue DESC
LIMIT 10;
```

Выручка по категориям продуктов:

```sql
SELECT product_category, sum(total_revenue) AS revenue, sum(sales_cnt) AS sales_cnt
FROM rpt_product_sales
GROUP BY product_category
ORDER BY revenue DESC;
```

Топ-10 клиентов по сумме покупок и распределение по странам:

```sql
SELECT first_name, last_name, email, country, sales_cnt, total_revenue, avg_check
FROM rpt_customer_sales
ORDER BY total_revenue DESC
LIMIT 10;

SELECT country, count(*) AS customers, sum(sales_cnt) AS sales_cnt
FROM rpt_customer_sales
GROUP BY country
ORDER BY customers DESC;
```

Месячные тренды продаж и средний размер заказа:

```sql
SELECT year, month, month_name, sales_cnt, total_revenue, avg_order_size
FROM rpt_time_sales
ORDER BY year, month;
```

Топ-5 магазинов и топ-5 поставщиков:

```sql
SELECT store_name, store_city, store_country, sales_cnt, total_revenue, avg_check
FROM rpt_store_sales
ORDER BY total_revenue DESC
LIMIT 5;

SELECT supplier_name, supplier_city, supplier_country, sales_cnt, total_revenue, avg_product_price
FROM rpt_supplier_sales
ORDER BY total_revenue DESC
LIMIT 5;
```

Корреляция между рейтингом и объемом продаж:

```sql
SELECT round(corr(avg_rating, sales_cnt)::numeric, 4) FROM rpt_product_quality;
```

Продукты с наивысшим и наименьшим рейтингом:

```sql
SELECT * FROM rpt_product_quality ORDER BY avg_rating DESC LIMIT 5;
SELECT * FROM rpt_product_quality ORDER BY avg_rating ASC LIMIT 5;
```

Качество данных: даты продаж — 2021 год, 364 уникальных дат (`count(DISTINCT sale_date)`), рейтинг в диапазоне 1–5, количество отзывов до 1000, строки с незаполненными `*_postal_code`/`store_state` приходят пустыми строками (пустые значения исходных CSV).

## Управление

```bash
docker compose stop
docker compose down
docker compose down -v && docker compose up -d
```

`down -v` удаляет все данные (Kafka, PostgreSQL, настройки Metabase) и запускает полную переинициализацию с нуля (после этого заново запустить процессоры в NiFi и заново настроить Metabase).

## Состав решения

| Файл                        | Назначение                                                            |
| --------------------------- | --------------------------------------------------------------------- |
| `docker-compose.yml`        | Kafka 3.9, PostgreSQL 17, NiFi 2.1, Metabase и запуск продюсера CSV → JSON → Kafka |
| `init/postgres/01_raw.sql`  | Таблица `mock_data` в PostgreSQL                                      |
| `init/postgres/02_reports.sql` | 6 представлений-отчетов в PostgreSQL                               |
| `producer/Dockerfile`       | Образ приложения-продюсера (Python + kafka-python)                    |
| `producer/produce.py`       | Преобразование строк CSV в JSON и отправка в топик Kafka              |
| `nifi/Dockerfile`           | Образ NiFi 2.1 с JDBC-драйвером PostgreSQL                            |
| `nifi/flow/flow.json.gz`    | Готовый flow NiFi (Consume Kafka → Write to PostgreSQL + сервисы)     |

---

## Исходное задание

Анализ больших данных - лабораторная работа №5 - Low-code с помощью NiFi и визуализация данных в Metabase

Ещё один популярный ETL-фреймворк с low-code парадигмой Apache NiFi. Apache NiFi - low-code фреймворк, который предлагает без написания кода (или с минимальным кодом) описать pipeline обработки данных.

Что необходимо сделать? 

Необходимо реализовать потоковую обработку данных с помощью NiFi, который читает топик Kafka, пишет данные в режиме streaming в PostgreSQL. Данные в Kafka-топиках хранятся в формате json. Данные в топик kafka нужно отправлять самостоятельно, эмулируя источник данных. Построить с помощью SQL отчеты и визуализировать их в Metabase.

Какие данные отправляются в Kafka?
 - Каждое сообщение в Kafka-топике - это строчка из csv файлов, преобразованная в формат json.

Какие данные отправляются в PostgreSQL?
 - Данные без агрегаций

Какие отчеты надо создать?
1. Витрина продаж по продуктам
Цель: Анализ выручки, количества продаж и популярности продуктов.
 - Топ-10 самых продаваемых продуктов.
 - Общая выручка по категориям продуктов.
 - Средний рейтинг и количество отзывов для каждого продукта.
2. Витрина продаж по клиентам
Цель: Анализ покупательского поведения и сегментация клиентов.
 - Топ-10 клиентов с наибольшей общей суммой покупок.
 - Распределение клиентов по странам.
 - Средний чек для каждого клиента.
3. Витрина продаж по времени
Цель: Анализ сезонности и трендов продаж.
 - Месячные и годовые тренды продаж.
 - Сравнение выручки за разные периоды.
 - Средний размер заказа по месяцам.
4. Витрина продаж по магазинам
Цель: Анализ эффективности магазинов.
 - Топ-5 магазинов с наибольшей выручкой.
 - Распределение продаж по городам и странам.
 - Средний чек для каждого магазина.
5. Витрина продаж по поставщикам
Цель: Анализ эффективности поставщиков.
 - Топ-5 поставщиков с наибольшей выручкой.
 - Средняя цена товаров от каждого поставщика.
 - Распределение продаж по странам поставщиков.
6. Витрина качества продукции
Цель: Анализ отзывов и рейтингов товаров.
 - Продукты с наивысшим и наименьшим рейтингом.
 - Корреляция между рейтингом и объемом продаж.
 - Продукты с наибольшим количеством отзывов.

![Лабораторная работа №5](https://github.com/user-attachments/assets/94bde719-9082-43b3-9925-0774166e7bd8)


Алгоритм:

1. Клонируете к себе этот репозиторий.
2. Устанавливаете инструмент для работы с запросами SQL (рекомендую DBeaver).
3. Устанавливаете базу данных PostgreSQL (рекомендую установку через docker).
4. Устанавливаете Apache Kafka (рекомендую установку через Docker).
5. Устанавливаете Apache NiFi (рекомендую установку через Docker).
6. Устанавливаете Metabase (рекомендую установку через Docker).
7. Скачиваете файлы с исходными данными mock_data( * ).csv, где ( * ) номера файлов. Всего 10 файлов, каждый по 1000 строк.
8. Реализуете приложение (можно с помощью NiFi), которое каждую строчку из исходных csv-файлов преобразует в json и отправляет в виде сообщения в Kafka-топик.
9. Реализуете приложение на NiFi, которое читает Kafka-топик и сохраняет в PostgreSQL в режиме streaming.
10. Реализуете SQL-скрипты в PostgreSQL для реализации отчетов.
11. Визуализируете данные PostgreSQL в Metabase.
12. Проверяете качество данных.

Что должно быть результатом работы?

1. Репозиторий, в котором есть исходные данные mock_data().csv, где () номера файлов. Всего 10 файлов, каждый по 1000 строк.
2. Файл docker-compose.yml с установкой PostgreSQL, NiFi, Kafka, Metabase и запуском приложения, которое из файлов mock_data(*).csv создает сообщения json в Kafka.
3. Инструкция, как запускать NiFi-приложение и приложение для отправки данных в Kafka для проверки лабораторной работы.
4. Инструкция, как визуализировать данные в Metabase
5. Решение на NiFi.
6. Код SQL для формирования отчетов.
