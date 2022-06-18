-- get sales month
CREATE OR REPLACE FUNCTION rental_month(rental_transaction_date timestamp)
RETURNS int
LANGUAGE plpgsql
AS
$$
DECLARE month_of_rental int;
BEGIN
    SELECT EXTRACT (MONTH FROM rental_transaction_date) INTO month_of_rental;
    RETURN month_of_rental;
END;
$$

-- get sales year
CREATE OR REPLACE FUNCTION rental_year(rental_transaction_date timestamp)
RETURNS int
LANGUAGE plpgsql
AS
$$
DECLARE year_of_rental int;
BEGIN
    SELECT EXTRACT (YEAR FROM rental_transaction_date) INTO year_of_rental;
    RETURN year_of_rental;
END;
$$

-- Test the functions to ensure that they work.
-- below function should return `2108`
SELECT rental_year('2108-08-21')

-- below function should return `8`
SELECT rental_month('2108-08-21')

-- query to get data and use functions. This will return the detailed view results.
SELECT COUNT(CAT.NAME) as number_of_rentals,
    CAT.NAME, --distinct(f.title)
    rental_month (RENT.rental_date),
    rental_year (RENT.rental_date)
FROM RENTAL AS RENT
JOIN INVENTORY AS INV ON INV.INVENTORY_ID = RENT.INVENTORY_ID
JOIN FILM AS F ON F.FILM_ID = INV.FILM_ID
JOIN FILM_CATEGORY AS FC ON FC.FILM_ID = F.FILM_ID
JOIN CATEGORY AS CAT ON CAT.CATEGORY_ID = FC.CATEGORY_ID
GROUP BY CAT.NAME, rental_month, rental_year
ORDER BY number_of_rentals desc;


-- create table to hold data for detailed view
CREATE TABLE rental_by_category_detailed(
    number_of_rentals bigint, 
    category_name varchar(25), 
    rental_month int, 
    rental_year int);

-- create table to hold data for summary view
CREATE TABLE rental_by_category_summary(
    number_of_rentals bigint, 
    category_name varchar(25), 
    rental_year int);


-- use query from line 35 to populate the detailed table with data
INSERT INTO rental_by_category_detailed
SELECT COUNT(CAT.NAME) as number_of_rentals,
    CAT.NAME, --distinct(f.title)
    rental_month (RENT.rental_date),
    rental_year (RENT.rental_date)
FROM RENTAL AS RENT
JOIN INVENTORY AS INV ON INV.INVENTORY_ID = RENT.INVENTORY_ID
JOIN FILM AS F ON F.FILM_ID = INV.FILM_ID
JOIN FILM_CATEGORY AS FC ON FC.FILM_ID = F.FILM_ID
JOIN CATEGORY AS CAT ON CAT.CATEGORY_ID = FC.CATEGORY_ID
GROUP BY CAT.NAME, rental_month, rental_year
ORDER BY number_of_rentals desc ;


-- Use the data from the detailed view to create the desired sumary query, and populate the summary table.
INSERT INTO rental_by_category_summary
SELECT sum(number_of_rentals) as total_rental_count,
	   category_name,
	   rental_year
FROM rental_by_category_detailed
WHERE rental_year = '2006'
Group by category_name, rental_year
ORDER BY total_rental_count DESC;
	   

-- This will create a stored procedure that will do the following:
-- clear the data on the detailed and summary view, and
-- then refresh the data with the desired data in the detailed view, 
-- Once that is done it will update the summary view with the newly found
-- data from the detailed table. This will provide a fresh report for both
-- detailed and summary reports.
CREATE OR REPLACE PROCEDURE reload_report_data()
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE rental_by_category_detailed;

    INSERT INTO rental_by_category_detailed
    SELECT COUNT(CAT.NAME) as number_of_rentals,
        CAT.NAME, 
        rental_month (RENT.rental_date),
        rental_year (RENT.rental_date)
    FROM RENTAL AS RENT
    JOIN INVENTORY AS INV ON INV.INVENTORY_ID = RENT.INVENTORY_ID
    JOIN FILM AS F ON F.FILM_ID = INV.FILM_ID
    JOIN FILM_CATEGORY AS FC ON FC.FILM_ID = F.FILM_ID
    JOIN CATEGORY AS CAT ON CAT.CATEGORY_ID = FC.CATEGORY_ID
    GROUP BY CAT.NAME, rental_month, rental_year
    ORDER BY number_of_rentals desc ;

    Truncate rental_by_category_summary;

    INSERT INTO rental_by_category_summary
    SELECT sum(number_of_rentals) as total_rental_count,
	   category_name,
	   rental_year
    FROM rental_by_category_detailed
    WHERE rental_year = '2006'
    Group by category_name, rental_year
    ORDER BY total_rental_count DESC;
END; $$

-- create trigger function that will call the stored procedure.
CREATE OR REPLACE FUNCTION rental_trigger_function()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
	call reload_report_data();
	RETURN NEW;
END; $$


-- create trigger that will call the trigger function anytime new data is inserted into the main table.
CREATE TRIGGER rental_data_updated
AFTER INSERT
ON rental
FOR EACH STATEMENT
EXECUTE PROCEDURE rental_trigger_function();


-- testing the trigger by inserting data into the original table. once data is inserted in to the source
-- table it update the detailed and summary view.
INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
VALUES ('2006-05-24 22:53:26', 9, 130, '2006-05-26 22:04:32', 1, '2006-02-15 21:30:54');

INSERT INTO rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)