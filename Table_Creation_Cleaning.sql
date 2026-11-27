/*
===============================================================================================================================
			                    CUSTOMER SEGMENTATION & RETENTION ANALYSIS
			                         DATA CREATION & CLEANING
===============================================================================================================================

PROJECT       : CUSTOMER SEGMENTATION & RETENTION ANALYSIS
DATASET       : ONLINE RETAIL II (UCI)
DATABASE      : POSTGRESQL
TOOL          : PGADMIN 4

---------------------------------------------------------------------------------------------------------------------------------
										PROJECT OVERVIEW
---------------------------------------------------------------------------------------------------------------------------------

THIS SCRIPT PREPARES RAW RETAIL TRANSACTION DATA FOR BUSINESS ANALYSIS.
IT COVERS TABLE CREATION, DATA EXPLORATION, DATA QUALITY ASSESSMENT,
DUPLICATE IDENTIFICATION, DATA CLEANING, AND CREATION OF A CLEANED DATASET.

---------------------------------------------------------------------------------------------------------------------------------
										OBJECTIVES
---------------------------------------------------------------------------------------------------------------------------------

1. CREATE THE RAW RETAIL TRANSACTION TABLE.
2. IMPORT RETAIL TRANSACTION DATA.
3. CREATE A STAGING TABLE FOR DATA PREPARATION.
4. IDENTIFY MISSING AND INVALID VALUES.
5. DETECT DUPLICATE RECORDS.
6. IDENTIFY CANCELLED INVOICES AND PRODUCT RETURNS.
7. STANDARDISE TEXT FIELDS AND CLEAN TRANSACTION RECORDS.
8. CREATE THE FINAL CLEANED RETAIL TABLE.
9. VALIDATE THE CLEANED DATASET.

---------------------------------------------------------------------------------------------------------------------------------
										TABLES USED
---------------------------------------------------------------------------------------------------------------------------------

SOURCE TABLE  : ONLINE_RETAIL
STAGING TABLE : STAGING_ONLINE_RETAIL
OUTPUT TABLE  : CLEANED_RETAIL

===============================================================================================================================
*/

create table online_retail(
 invoice varchar(20),
 stockcode varchar(20),
 description text,
 quantity int,
 invoicedate timestamp,
 price numeric(10,2),
 customerid int,
 country varchar(50)
)

set datestyle to 'iso,dmy';

--DATA OF YEAR 2009-10

copy online_retail(Invoice,StockCode,Description,Quantity,InvoiceDate,Price,CustomerID,Country)
from 'C:\Users\Public\online_retail_IIA.csv'
with(format CSV,
header,
delimiter ',')

--DATA OF YEAR 2010-11

copy online_retail(Invoice,StockCode,Description,Quantity,InvoiceDate,Price,CustomerID,Country)
from 'C:\Users\Public\online_retail_II.csv'
with(format CSV,
header,
delimiter ',')

------------------------------------------RAW TABLE-------------------------------------------------------------

select * from online_retail;

-------------------------------------STAGING TABLE (TO WORK ON)--------------------------------------------------------

create table staging_online_retail as
select * from online_retail;

--UNIQUE CUSTOMERS

select 
	count(distinct customerid)
	from staging_online_retail;

--DATA RANGE

select
	min(invoicedate) as first_date,
	max(invoicedate) as last_date
	from staging_online_retail;
	
--DISTINCT RECORD

select
	count(distinct customerid) as unique_customer,
	count(distinct invoice) as unique_invoice,
	count(distinct stockcode) as unique_products
	from staging_online_retail;


--FINDING MISSING RECORDS

select 
	sum(case when invoice is null then 1 else 0 end ) as missing_invoice,
	sum(case when description is null then 1 else 0 end) as missing_description,
	sum(case when quantity is null then 1 else 0 end ) as missing_quantity,
	sum(case when stockcode is null then 1 else 0 end ) as missing_stockcode,
	sum(case when invoicedate is null then 1 else 0 end) as missing_date,
	sum(case when price is null then 1 else 0 end ) missing_price,
	sum(case when customerid is null then 1 else 0 end ) missing_customer
	from staging_online_retail;

--IDENTIFYING CANCELLED VALUE

select 
	case
	when invoice like 'C%' then 'Cancelled'
	when quantity<0 then 'Return'
	else 'Normal Sale'
	end as Transaction_type,
	count(*) as total_record
	from staging_online_retail
	group by Transaction_type

--IDENTIFYING DUPLICATE RECORS

with duplicate_records as(
	select *,
	row_number() over(
	partition by invoice,
		stockcode,
		description,
		quantity,
		invoicedate,
		price,
		customerid,
		country
		) as rn
		from staging_online_retail
	    )
		select 
		sum(case when rn>1 then 1 else 0 end) as duplicate_rows,
		sum(case when rn=1 then 1 end) as unique_rows
		from
		duplicate_records;
	

select
	trim(description) as clean_description,
	trim(country)as clean_country
	from staging_online_retail;
		

--VALIDATING NULL AND CANCELLED ENTRIES

Select
	*
	from staging_online_retail
	where customerid is null 
	
	Select
	*
	from staging_online_retail
	where quantity <=0
	select count(quantity) 
	from staging_online_retail
	where invoice  not like 'C%' and
	quantity<0

select
	sum(case
	when quantity =0 then 1 else 0 end),
	sum(case
	when quantity <0 then 1 else 0 end) as neg
	from staging_online_retail

/*
====================================================================================================================

								CREATING CLEANED SALES TABLE

CLEANING RULES:-

1. REMOVE DUPLICATE RECORDS
2. EXCLUDE CANCELLED INVOICE
3. EXCLUDE RETURNS AND NON-POSITIVE QUANTITIES
4. EXCLUDE MISSING CUSTOMER IDs AND INVOICE DATES
5. EXCLUDE MISSING OR NON-POSITIVE PRICES
6. EXCLUDE BLANK PRODUCT DESCRIPTION

MOTE:-
THIS TABLE CONTAINS VALID POSITIVE SALES TRANSACTION.
RETURNS AND CANCELLATIONS ARE EXCLUDED FROM THIS ANALYSIS.

====================================================================================================
==*/

CREATE TABLE CLEANED_RETAIL AS
WITH clean as(
 select *,
 	 row_number() over(
 	 partition by invoice,
	 stockcode,
	 description,
	 quantity,
	 invoicedate,
	 price,
	 customerid,
	 country) as rn
	 from staging_online_retail
	 )
	 select trim(invoice) as invoice,
	 trim(stockcode) as stockcode,
	 trim(description) as description,
	 quantity,
	 invoicedate,
	 price,
     customerid,
	 trim(country) as country,
	 quantity * price as Salesamount
     from clean
	 where rn=1 and
	 invoice is not null and
	 customerid is not null and
	 invoicedate is not null and
	 price is not null and
	 price>0 and
	 quantity >0 and
	 invoice not like 'C%' and
	 nullif(trim (description), '') is not null and
	 nullif(trim(stockcode),'') is not null and
	 nullif(trim(invoice),'') is not null;

	