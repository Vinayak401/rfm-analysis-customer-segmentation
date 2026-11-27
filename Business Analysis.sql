/*
=========================================================================================================================
			                    CUSTOMER SEGMENTATION & RETENTION ANALYSIS
			                              BUSINESS ANALYSIS
=========================================================================================================================

PROJECT       : CUSTOMER SEGMENTATION & RETENTION ANALYSIS
DATASET       : ONLINE RETAIL II (UCI)
DATABASE      : POSTGRESQL
TOOL          : PGADMIN 4

----------------------------------------------------------------------------------------------------------------------------------------
										PROJECT OVERVIEW
----------------------------------------------------------------------------------------------------------------------------------------

THIS SQL SCRIPT PERFORMS EXPLORATORY AND BUSINESS ANALYSIS ON CLEANED RETAIL
TRANSACTION DATA TO IDENTIFY CUSTOMER PURCHASING PATTERNS, REVENUE TRENDS,
CUSTOMER RETENTION, AND BUSINESS GROWTH OPPORTUNITIES.

----------------------------------------------------------------------------------------------------------------------------------------
									BUSINESS OBJECTIVES
----------------------------------------------------------------------------------------------------------------------------------------

1. IDENTIFY THE MOST VALUABLE CUSTOMERS BASED ON REVENUE.
2. MEASURE CUSTOMER REPEAT PURCHASE BEHAVIOUR.
3. IDENTIFY INACTIVE CUSTOMERS.
4. ANALYSE MONTH-OVER-MONTH CUSTOMER RETENTION.
5. ESTIMATE CUSTOMER CHURN USING INACTIVITY.
6. MEASURE REVENUE CONTRIBUTION FROM TOP CUSTOMERS.
7. ANALYSE CUSTOMER PURCHASE FREQUENCY.
8. EVALUATE HISTORICAL CUSTOMER REVENUE VALUE.
9. TRACK MONTHLY NEW CUSTOMER ACQUISITION.
10. PERFORM COHORT-BASED CUSTOMER RETENTION ANALYSIS.

----------------------------------------------------------------------------------------------------------------------------------------
										TABLE USED
----------------------------------------------------------------------------------------------------------------------------------------

SOURCE TABLE : CLEANED_RETAIL

THE CLEANED_RETAIL TABLE CONTAINS VALID POSITIVE SALES TRANSACTIONS.
CANCELLED INVOICES, RETURNS, AND INVALID RECORDS ARE EXCLUDED.

----------------------------------------------------------------------------------------------------------------------------------------
									ANALYSIS STRUCTURE
----------------------------------------------------------------------------------------------------------------------------------------

SECTION 1 : KEY PERFORMANCE INDICATORS (KPIS)
SECTION 2 : CUSTOMER REVENUE ANALYSIS
SECTION 3 : CUSTOMER PURCHASE BEHAVIOUR
SECTION 4 : CUSTOMER RETENTION & INACTIVITY
SECTION 5 : CUSTOMER ACQUISITION & COHORT ANALYSIS

=========================================================================================================================
*/


----------------------------------------------KPIs---------------------------------------------------------------

SELECT 
	count(distinct customerid) as total_customers,
	count(distinct invoice) as total_orders,
	count(distinct stockcode) as total_products,
	sum(quantity) as total_quantity,
	round(sum(salesamount),2) as total_revenue,
	round(avg(salesamount),2) as avg_line_value
	from cleaned_retail;

/*
=================================================================================================
									BUSINESS QUESTION 1 :
 WHO ARE OUR MOST VALUEABLE CUSTOMERS?

 BUSINESS OBJECTIVE:
 IDENTIFY CUSTOMERS WHO GENERATE THE HIGHEST REVENUE FOR THE COMPANY.

 BUSINESS IMPORTANCE :
 INDERSTAND CUSTOMER PURCHASING BEHAVIOUR AND MEASURE CUSTOMER LOYALTY.
 ====================================================================================================
 ==*/

   SELECT *
   FROM(
      select
		  customerid,
	      count( distinct invoice) as totalorders,
		  sum(salesamount) as totalrevenue,
		  round(sum(salesamount)/ count(distinct invoice),2) as average_order_value,
		  dense_rank() over(order by sum(salesamount) desc) as rnk
		  from cleaned_retail
		  group by customerid) as ranked_customers
		  where rnk<=10
		  order by totalrevenue desc;

/*
=================================================================================================
								KEY FINDINGS & BUSINESS INSIGHTS:
  
•	CUSTOMER 18102 GENERATED THE HIGHEST REVENUE: ₹580,987.04, MAKING THIS CUSTOMER THE TOP REVENUE CONTRIBUTOR IN THE RESULT PREVIOUSLY SHARED.
•	CUSTOMER 14646 RANKED SECOND WITH ₹528,602.52, SHOWING THAT MULTIPLE CUSTOMERS CONTRIBUTE SUBSTANTIAL REVENUE.
•	CUSTOMER 14911 PLACED 398 ORDERS AMONG THE TOP FIVE, INDICATING PARTICULARLY HIGH PURCHASE FREQUENCY.
•	CUSTOMER 17450 HAD THE HIGHEST AVERAGE ORDER VALUE AMONG THE TOP FIVE: ₹4,799.69, INDICATING HIGH-VALUE TRANSACTIONS.

									BUSINESS RECOMMENDATIONS:
 
•	CREATE A VIP RETENTION PROGRAMME FOR THE HIGHEST-REVENUE CUSTOMERS, WITH PERSONALISED SERVICE AND RELEVANT OFFERS.
•	MONITOR ORDER FREQUENCY AND RECENCY FOR THESE CUSTOMERS SO A DROP IN ACTIVITY CAN BE ADDRESSED EARLY.
•	USE CROSS-SELLING OR BUNDLES TO INCREASE AVERAGE ORDER VALUE AMONG FREQUENT BUYERS SUCH AS CUSTOMER 14911.
						
 ====================================================================================================
 ==*/
						
/*
=================================================================================================																													
									BUSINESS QUESTION 2 :
WHO ARE OUR REPEAT CUSTOMERS?

BUSINESS OBJECTIVE:

IDENTIFY CUSTOMERS WHO HAVE MADE PURCHASE MORE THAN ONE DURING THE
ANALYSIS PERIOD.

BUSINESS IMPORTANCE :

INDERSTAND CUSTOMER PURCHASING BEHAVIOUR AND MEASURE CUSTOMER LOYALTY.
===================================================================================================================================================================
 ==*/

with customers_order as(
	select
	    customerid,
        count(distinct invoice) as total_orders
		from cleaned_retail
		group by customerid
	),
	repeated as(
		select
		count(*) as total_customers,
		sum(case when total_orders>1 then 1
		else 0 end) as repeated_customers
		from customers_order
	)
	select
		*,
		round((cast(repeated_customers as numeric)/total_customers)*100,2) as repeat_customer_percentage
		from repeated;
/*
=================================================================================================			
								KEY FINDINGS & BUSINESS INSIGHTS
									
•	TOTAL CUSTOMERS: 5878
•	REPEAT CUSTOMERS: 4255
•	ONE-TIME CUSTOMERS: 1623
•	REPEAT-CUSTOMER RATE: 72.39%. THIS INDICATES THE SHARE OF CUSTOMERS WHO RETURNED FOR ANOTHER PURCHASE.

									BUSINESS RECOMMENDATIONS
									
•	CREATE A SECOND-PURCHASE JOURNEY FOR ONE-TIME CUSTOMERS USING RELEVANT FOLLOW-UP MESSAGES OR OFFERS.
•	COMPARE REPEAT RATES ACROSS PRODUCT CATEGORIES OR CUSTOMER GROUPS, IF THOSE DIMENSIONS ARE AVAILABLE.
•	TRACK REPEAT-CUSTOMER RATE OVER TIME TO ASSESS WHETHER RETENTION INITIATIVES ARE WORKING.


====================================================================================================
 ==*/
/*
=================================================================================================
									BUSINESS QUESTION 3 :
 WHICH CUSTOMERS HAVEN'T PURCHASED RECENTLY?

 BUSINESS OBJECTIVE:
 IDENTIFY INACTIVE CUSTOMERS BASED ON THEIR LAST PURCHASE DATE.

 BUSINESS RULE:
 MORE THAN 90 DAYS WITHOUT A PURCHASE=INACTIVE.
 ====================================================================================================
 ==*/

with latest as(
		select 
		customerid,
		max(invoicedate) as latest_purchase
		from cleaned_retail
	    group by customerid
	),
	reference as(
		select
		max(invoicedate) as reference_date
	    from cleaned_retail
	)
    select
		l.customerid,
	    l.latest_purchase,
		r.reference_date ::date - l.latest_purchase ::date as days_since_purchase,
		case
		when  (r.reference_date- l.latest_purchase)> 90  then 'Inactive'
		else 'Active' end as customer_status
		from latest l cross join 
		reference r
		order by days_since_purchase desc;
/*
=================================================================================================
								KEY FINDINGS & BUSINESS INSIGHTS
								
•	CUSTOMERS INACTIVE FOR MORE THAN 90 DAYS: 2989
•	CUSTOMER WITH THE LONGEST INACTIVITY: CUSTOMERID- 12636 FOR 738 DAYS.
•	THE INACTIVE-CUSTOMER LIST HIGHLIGHTS CUSTOMERS WHO MAY NEED RE-ENGAGEMENT, ESPECIALLY THOSE WITH HIGH HISTORICAL REVENUE.
									
									BUSINESS RECOMMENDATIONS
									
•	PRIORITISE REACTIVATION OUTREACH FOR INACTIVE CUSTOMERS WITH HIGH HISTORICAL REVENUE OR FREQUENT PAST PURCHASES.
•	USE PAST-PURCHASE INFORMATION TO TAILOR RE-ENGAGEMENT OFFERS.
•	REVIEW INACTIVITY BY CUSTOMER SEGMENT RATHER THAN TREATING EVERY INACTIVE CUSTOMER AS EQUALLY VALUABLE.


====================================================================================================
==*/
/*
=================================================================================================
									BUSINESS QUESTION 4 :
 WHAT IS THE MONTHLY CUSTOMER RETENTION RATE?

 BUSINESS OBJECTIVE:
 MEASURE THE PERCENTAGE OF CUSTOMERS FROM THE PREVIOUS MONTH
 WHO RETURNED TO MAKE PURCHASE IN THE CURRENT MONTH

 BUSINESS IMPORTANCE :
 INDERSTAND CUSTOMER PURCHASING BEHAVIOUR AND MEASURE CUSTOMER LOYALTY.
 ====================================================================================================
 ==*/
with monthly_customers as(
		select
		distinct customerid,
		date_trunc('month',invoicedate) as purchase_month
		from cleaned_retail
	),
	monthly_comparison as(
		select
		current_month.purchase_month,
		count(distinct current_month.customerid) as current_customers,
		count(distinct previous_month.customerid) as retained_customers
		from monthly_customers current_month left join
		monthly_customers previous_month on
		current_month.customerid=previous_month.customerid and
		previous_month.purchase_month=current_month.purchase_month - interval '1 month'
		group by current_month.purchase_month
	)
	select
	    purchase_month,
	    current_customers,
	    retained_customers,
	    round((cast(retained_customers as numeric)/lag(current_customers) over(order by purchase_month))*100,2) as retention_percentage
	    FROM monthly_comparison
		ORDER BY purchase_month;
			
/*
=================================================================================================
								KEY FINDINGS & BUSINESS INSIGHTS
								
•	AVERAGE MONTH-OVER-MONTH RETENTION (EXCLUDING THE FIRST MONTH): 37.84%.
•	NOVEMBER 2011 HAD THE HIGHEST RETENTION: 45.60%.
•	DECEMBER 2011 HAD THE LOWEST RETENTION: 22.30%, REPRESENTING A NOTABLE DECLINE.
•	THE MONTH-TO-MONTH VARIATION SUGGESTS CONSECUTIVE-MONTH REPEAT PURCHASING WAS NOT CONSISTENT THROUGHOUT THE PERIOD.
									
									BUSINESS RECOMMENDATIONS
									
•	INVESTIGATE THE DECEMBER 2011 DECLINE, WHILE CHECKING WHETHER THE FINAL MONTH CONTAINS A COMPLETE SET OF TRANSACTIONS.
•	USE TIMELY, RELEVANT REMINDERS OR OFFERS TO ENCOURAGE CUSTOMERS TO RETURN THE FOLLOWING MONTH.
•	TRACK THE SAME RETENTION DEFINITION CONSISTENTLY SO FUTURE PERIODS CAN BE COMPARED FAIRLY.

====================================================================================================
 ==*/	   
 
/*
====================================================================================================
									BUSINESS QUESTION 5:
WHAT IS THE CUSTOMER CHURN RATE USING A 90-DAY INACTIVITY RULE?

OBJECTIVE: 
CALCULATE AN INACTIVITY-BASED CHURN PROXY BY IDENTIFYING CUSTOMERS
WHOSE LAST PURCHASE WAS MORE THAN 90 DAYS BEFORE THE DATASET'S LATEST TRANSACTION DATE.

====================================================================================================
 ==*/
with customer_activity as(
		select
		customerid,
		max(invoicedate) as last_purchase
		from cleaned_retail
		group by customerid
	),
	churn_data as(
		select customerid,
		(max(last_purchase) over()) ::date - last_purchase ::date as inactivity_days
		from customer_activity
	)
	select
		count(*) as total_customer,
		sum(case when inactivity_days> 90 then 1 else 0 end ) as churned_customers,
		round((cast(sum(case when inactivity_days> 90  then 1 else 0 end )
		as numeric)/count(*))*100 ,2) 
		as churn_percentage
		from churn_data;

/*
=================================================================================================
								KEY FINDINGS & BUSINESS INSIGHTS
								
•	THE ANALYSIS INCLUDES 5,878 CUSTOMERS.
•	2,989 CUSTOMERS MEET THE MORE-THAN-90-DAY INACTIVITY RULE.
•	THE INACTIVITY-BASED CHURN RATE IS 50.85%, MEANING ROUGHLY HALF OF THE CUSTOMERS HAD NOT PURCHASED WITHIN THE 90-DAY WINDOW.
•	THIS IS AN INACTIVITY PROXY, NOT CONFIRMED CANCELLATION OR PERMANENT CUSTOMER LOSS.
								
								BUSINESS RECOMMENDATIONS
									
•	PRIORITISE REACTIVATION EFFORTS FOR INACTIVE CUSTOMERS WITH HIGH HISTORICAL REVENUE AND ORDER FREQUENCY.
•	SEGMENT INACTIVE CUSTOMERS BEFORE ALLOCATING CAMPAIGN BUDGET.
•	MONITOR THE 90-DAY INACTIVITY MEASURE REGULARLY AND COMPARE LIKE-FOR-LIKE REPORTING PERIODS.


====================================================================================================
 ==*/

/*
=================================================================================================
									BUSINESS QUESTION 6: 
WHAT PERCENTAGE OF TOTAL REVENUE COMES FROM THE TOP 10 CUSTOMERS?

OBJECTIVE:
MEASURE REVENUE CONCENTRATION BY COMPARING THE COMBINED REVENUE OF THE TEN HIGHEST-REVENUE CUSTOMERS WITH TOTAL REVENUE.

====================================================================================================
 ==*/
with customer_revenue as(
		select
		customerid,
		sum(salesamount) as total_revenue
		from cleaned_retail
		group by customerid
	),
	top_customers as(
		select * from customer_revenue
		order by total_revenue desc,customerid
		limit 10
	),
	overall_revenue as(
		select
		sum(salesamount) as company_revenue
		from cleaned_retail
	)
	select
		sum(c.total_revenue) as top10revenue,
		o.company_revenue,
		round((sum(c.total_revenue)/o.company_revenue)*100,2) as percentage_share
		from top_customers c cross join overall_revenue o
		group by o.company_revenue;

/*
=================================================================================================
								KEY FINDINGS & BUSINESS INSIGHTS
								
•	THE TOP 10 CUSTOMERS GENERATED ₹2,787,079.44 IN COMBINED REVENUE.
•	TOTAL COMPANY REVENUE WAS ₹17,374,804.25.
•	THE TOP 10 CONTRIBUTED 16.04% OF TOTAL REVENUE; THE REMAINING CUSTOMERS CONTRIBUTED 83.96%.
•	REVENUE IS NOT DOMINATED BY THE TOP 10 ALONE, ALTHOUGH THOSE CUSTOMERS REMAIN IMPORTANT ACCOUNTS.
									
									BUSINESS RECOMMENDATIONS
									
•	MAINTAIN STRONG RELATIONSHIPS WITH THE TOP 10 CUSTOMERS THROUGH PERSONALISED ACCOUNT MANAGEMENT.
•	CONTINUE DEVELOPING THE BROADER CUSTOMER BASE, WHICH CONTRIBUTES 83.96% OF REVENUE.
•	MONITOR REVENUE CONCENTRATION OVER TIME TO IDENTIFY INCREASING DEPENDENCE ON A SMALL CUSTOMER GROUP.


====================================================================================================
 ==*/

/*
=================================================================================================
									BUSINESS QUESTION 7:
HOW FREQUENTLY DO CUSTOMERS PLACE ORDERS?

OBJECTIVE: 
UNDERSTAND CUSTOMER PURCHASE FREQUENCY BY CALCULATING THE NUMBER OF DISTINCT
INVOICES PER CUSTOMER AND SUMMARISING THE DISTRIBUTION.

====================================================================================================
 ==*/
with customer_frequency as(
		select
		customerid,
		count( distinct invoice) as total_orders 
		from cleaned_retail
		group by customerid
	),
	customer_count as(
		select
		count(case when total_orders = 1 then 1 end) as non_repeated_customer,
		count(case when total_orders >=2 and total_orders<=5 then 1 end) mid_frequency_customers,
		count(case when total_orders>5 then 1 end  ) high_frequency_customers
		from customer_frequency
	)
	select
		c.*,
		count(*) as total_customers,
		Round(avg(f.total_orders),2) as avg_order_per_customer,
		max(f.total_orders) as highest_order,
		min(f.total_orders) as lowest_order
		from customer_frequency f  cross join
		customer_count c
		group by c.non_repeated_customer,
	    c.mid_frequency_customers,
	    c.high_frequency_customers;

/*
=================================================================================================
								KEY FINDINGS & BUSINESS INSIGHTS
								
•	CUSTOMERS PLACED AN AVERAGE OF 6.29 ORDERS EACH DURING THE DATASET PERIOD.
•	1,623 CUSTOMERS PLACED ONLY ONE ORDER, INDICATING A SIZEABLE ONE-TIME-BUYER GROUP.
•	2,454 CUSTOMERS PLACED 2–5 ORDERS, WHILE 1,801 CUSTOMERS PLACED MORE THAN FIVE ORDERS.
•	THE ORDER-COUNT RANGE IS 1 TO 398 ORDERS PER CUSTOMER, SHOWING A WIDE VARIATION IN PURCHASE FREQUENCY.
									
									BUSINESS RECOMMENDATIONS
									
•	ENCOURAGE ONE-TIME BUYERS TO MAKE A SECOND PURCHASE WITH RELEVANT FOLLOW-UP COMMUNICATION.
•	RECOGNISE FREQUENT BUYERS WITH LOYALTY BENEFITS OR PERSONALISED RECOMMENDATIONS.
•	USE PURCHASE HISTORY TO IDENTIFY PRODUCTS AND TIMING THAT MAY ENCOURAGE CUSTOMERS TO BUY AGAIN.


====================================================================================================
 ==*/

/*
=================================================================================================
									BUSINESS QUESTION 8:
WHAT IS THE HISTORICAL REVENUE VALUE OF EACH CUSTOMER?

OBJECTIVE: 
ESTIMATE EACH CUSTOMER'S HISTORICAL VALUE USING TOTAL REVENUE GENERATED
ACROSS THE AVAILABLE DATASET, ALONGSIDE ORDER COUNT AND AVERAGE ORDER VALUE.

====================================================================================================
 ==*/
with revenue as(
	select
		customerid,
		sum(salesamount) as lifetime_revenue,
		count(distinct invoice) as total_orders,
		round(sum(salesamount)/count(distinct invoice),2)as avg_order_value
		from cleaned_retail
		group by customerid
	)
	select
		*,
		dense_rank() over( order by lifetime_revenue desc) as rnk,
		round(avg(lifetime_revenue) over(),2)as lifetime_avg
		from revenue;
		
/*
=================================================================================================
								KEY FINDINGS & BUSINESS INSIGHTS
								
•	CUSTOMER 18102 HAD THE HIGHEST HISTORICAL REVENUE: ₹580,987.04.
•	AVERAGE HISTORICAL REVENUE PER CUSTOMER WAS ₹2,955.55.
•	THE RESULTS SHOW SUBSTANTIAL DIFFERENCES IN CUMULATIVE REVENUE ACROSS CUSTOMERS.
•	THIS IS HISTORICAL REVENUE-BASED CUSTOMER VALUE, NOT A PREDICTION OF FUTURE REVENUE OR PROFIT.
									
									BUSINESS RECOMMENDATIONS
									
•	PRIORITISE RETENTION OF CUSTOMERS WITH HIGH HISTORICAL REVENUE, WHILE ALSO CONSIDERING RECENCY AND ORDER FREQUENCY.
•	USE AVERAGE ORDER VALUE AND ORDER COUNT TOGETHER TO DISTINGUISH HIGH-TICKET CUSTOMERS FROM FREQUENT PURCHASERS.
•	DO NOT TREAT HISTORICAL REVENUE AS A FORECAST; A PREDICTIVE CLV MODEL WOULD REQUIRE ADDITIONAL ASSUMPTIONS AND DATA.

====================================================================================================
 ==*/
 
/*
=================================================================================================
									BUSINESS QUESTION 9:
									
HOW MANY NEW CUSTOMERS WERE ACQUIRED EACH MONTH?

OBJECTIVE:
IDENTIFY EACH CUSTOMER'S FIRST RECORDED PURCHASE AND COUNT NEW CUSTOMERS BY ACQUISITION MONTH.

====================================================================================================
 ==*/
with first_purchase as(
	select
		customerid,
		min(invoicedate) as first_purchase_date
		from cleaned_retail
		group by customerid
	)
		select 
		date_trunc('month',first_purchase_date) as acquisition_month,
		count(*) as new_customers
		from first_purchase
		group by acquisition_month
		order by acquisition_month;
/*
=================================================================================================
								KEY FINDINGS & BUSINESS INSIGHTS
								
•	DECEMBER 2009 RECORDED THE HIGHEST NUMBER OF NEWLY OBSERVED CUSTOMERS: 955.
•	DECEMBER 2011 RECORDED THE LOWEST NUMBER: 28.
•	THE MONTHLY SERIES SHOWS AN OVERALL DECLINING PATTERN WITH OCCASIONAL FLUCTUATIONS.
•	THE FINAL MONTH MAY BE INCOMPLETE, SO ITS COUNT SHOULD NOT BE COMPARED DIRECTLY WITH FULL MONTHS WITHOUT CHECKING DATASET DATE COVERAGE.
									
									BUSINESS RECOMMENDATIONS
									
•	INVESTIGATE PERIODS WITH STRONGER ACQUISITION TO UNDERSTAND POSSIBLE SEASONALITY OR BUSINESS ACTIVITY; MARKETING-CHANNEL DATA IS NOT AVAILABLE IN THIS ANALYSIS.
•	REVIEW WEAK ACQUISITION PERIODS AND TEST DIFFERENT ACQUISITION ACTIVITIES WHERE CHANNEL DATA CAN BE COLLECTED.
•	EVALUATE ACQUISITION TOGETHER WITH RETENTION SO CUSTOMER GROWTH IS NOT JUDGED ONLY BY FIRST PURCHASES.

====================================================================================================
 ==*/

/*
=================================================================================================
									BUSINESS QUESTION 10:
									
HOW DOES CUSTOMER RETENTION VARY BY ACQUISITION COHORT?

OBJECTIVE:
GROUP CUSTOMERS BY THE MONTH OF THEIR FIRST RECORDED PURCHASE,
THEN MEASURE HOW MANY FROM EACH COHORT RETURN IN SUBSEQUENT MONTHS.

====================================================================================================
 ==*/
with customer_cohort as (
   		select
	    customerid,
	    date_trunc('month', MIN(invoicedate)) AS cohort_month
	    FROM cleaned_retail
	    GROUP BY customerid
	),
	customer_activity as (
   		select distinct
	    customerid,
	    date_trunc('month', invoicedate) AS activity_month
	    from cleaned_retail
	),
	cohort_activity as (
   		select
        c.cohort_month,
        a.activity_month,
        (extract(year from age(a.activity_month, c.cohort_month)) * 12
         + extract(month from age(a.activity_month, c.cohort_month))
        ) as cohort_index,
        count(distinct c.customerid) as active_customers
        from customer_cohort c
        join customer_activity a
        on c.customerid = a.customerid
        group by c.cohort_month, a.activity_month
    ),
    cohort_size as (
	    select
	    cohort_month,
	    count(*) as total_cohort_customers
	    from customer_cohort
	    group by cohort_month
     )
    select
	    ca.cohort_month,
	    ca.cohort_index,
	    cs.total_cohort_customers,
	    ca.active_customers,
	    ROUND(
	        100.0 * ca.active_customers / nullif(cs.total_cohort_customers, 0),
	        2
	    ) as retention_percentage
		from cohort_activity ca
		join cohort_size cs
		 on ca.cohort_month = cs.cohort_month
		order by ca.cohort_month, ca.cohort_index;


/*
=================================================================================================
								KEY FINDINGS & BUSINESS INSIGHTS

(1)	COHORT WITH THE STRONGEST MONTH 1 RETENTION: DECEMBER 2009, 35.29%.
(2)	COHORT WITH THE WEAKEST MONTH 1 RETENTION: DECEMBER 2010, 9.21%
(3)	COMPARE MONTH 2 AND MONTH 3 RETENTION ACROSS COHORTS:DECEMBER 2009 HAD 33.40% MONTH 2 RETENTION AND 42.51% MONTH 3 RETENTION.
JANUARY 2010 HAD 31.07% MONTH 2 RETENTION AND 30.55% MONTH 3 RETENTION

									BUSINESS RECOMMENDATIONS:

(1)	STUDY THE ACQUISITION PERIOD AND CUSTOMER EXPERIENCE OF COHORTS WITH STRONGER RETENTION.
(2)	INVESTIGATE WHERE RETENTION DROPS SHARPLY AFTER THE FIRST PURCHASE.
(3)	IMPROVE POST-PURCHASE COMMUNICATION AND ONBOARDING FOR NEWLY ACQUIRED CUSTOMERS.
(4)	USE COHORT TRENDS TO EVALUATE WHETHER RETENTION INITIATIVES ARE IMPROVING CUSTOMER BEHAVIOUR.

====================================================================================================
 ==*/




