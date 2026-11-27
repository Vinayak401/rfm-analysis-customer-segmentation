/*
==========================================================================================================
			                  CUSTOMER SEGMENTATION & RETENTION ANALYSIS
			                     RFM ANALYSIS & CUSTOMER SEGMENTATION
========================================================================================================================

PROJECT       : CUSTOMER SEGMENTATION & RETENTION ANALYSIS
DATASET       : ONLINE RETAIL II (UCI)
DATABASE      : POSTGRESQL
TOOL          : PGADMIN 4

------------------------------------------------------------------------------------------------------------------------------------------
										PROJECT OVERVIEW
------------------------------------------------------------------------------------------------------------------------------------------

THIS SCRIPT PERFORMS RFM (RECENCY, FREQUENCY, MONETARY) ANALYSIS TO
EVALUATE CUSTOMER PURCHASING BEHAVIOUR AND SEGMENT CUSTOMERS BASED ON
THEIR HISTORICAL TRANSACTION ACTIVITY.

------------------------------------------------------------------------------------------------------------------------------------------
										OBJECTIVES
------------------------------------------------------------------------------------------------------------------------------------------

1. CALCULATE RECENCY, FREQUENCY AND MONETARY METRICS FOR EACH CUSTOMER.
2. ASSIGN RFM SCORES TO CUSTOMERS.
3. CREATE CUSTOMER SEGMENTS BASED ON RFM SCORES.
4. ANALYSE CUSTOMER DISTRIBUTION ACROSS SEGMENTS.
5. CALCULATE REVENUE CONTRIBUTION BY CUSTOMER SEGMENT.
6. COMPARE PURCHASING BEHAVIOUR ACROSS CUSTOMER SEGMENTS.
7. IDENTIFY HIGH-VALUE, LOYAL, AT-RISK AND LOW-VALUE CUSTOMERS.
8. GENERATE ACTIONABLE BUSINESS RECOMMENDATIONS.

------------------------------------------------------------------------------------------------------------------------------------------
										TABLES USED
------------------------------------------------------------------------------------------------------------------------------------------

SOURCE TABLE : CLEANED_RETAIL

OUTPUT TABLES:
CUSTOMER_RFM
CUSTOMER_RFM_SCORES
CUSTOMER_SEGMENTS

========================================================================================================================
*/


/*
===========================================================================================================
								 CUSTOMER-LEVEL RFM CALCULATION

									BUSINESS OBJECTIVE:
CALCULATE RECENCY, FREQUENCY AND MONETARY VALUE FOR EVERY CUSTOMER.

==============================================================================================================
*/

With customer_rfm as(
		select 
		customerid,
		max(invoicedate) as last_purchase_date,
		count(distinct invoice) as frequency,
		Round(sum(salesamount),2) as monetary
		from cleaned_retail
		group by customerid
	),
	reference_date as(
		select
		max(invoicedate):: DATE + 1 as analysis_date
		from cleaned_retail
	)
		select
		c.customerid,
		c.last_purchase_date,
		r.analysis_date,
		r.analysis_date-c.last_purchase_date:: DATE as recency,
		c.frequency,
		c.monetary
		from customer_rfm c cross join
		reference_date r
		order by c.customerid;


DROP TABLE IF EXISTS CUSTOMER_RFM_SCORES;

CREATE TABLE CUSTOMER_RFM_SCORES AS
with customer_metrics as(
		select
		customerid,
		max(invoicedate) as last_purchase_date,
		count(distinct invoice) as frequency,
		sum(salesamount) as monetary
		from cleaned_retail
		group by customerid
	),
	reference_date as(
		select
		max(invoicedate):: DATE + 1  as analysis_date
		from cleaned_retail
	),
	rfm as(
	    select
		c.customerid,
		r.analysis_date-c.last_purchase_date:: DATE	 as recency,
		c.frequency,
		c.monetary
		from customer_metrics c cross join
		reference_date r
	)
		select
		customerid,
		recency,
		frequency,
		monetary,
		ceil(cume_dist() over(order by recency desc)*5) as r_score,
		ceil(cume_dist() over(order by frequency asc)*5) as f_score,
		ceil(cume_dist() over(order by monetary asc)*5) as m_score
		from rfm;


/*
===========================================================================================================
		
									RFM SCORING INTERPRETATION
									
•	R SCORE: 5 MEANS THE CUSTOMER PURCHASED RELATIVELY RECENTLY; 1 MEANS THE CUSTOMER HAS BEEN INACTIVE FOR LONGER.
•	F SCORE: 5 MEANS RELATIVELY FREQUENT PURCHASING; 1 MEANS RELATIVELY FEW ORDERS.
•	M SCORE: 5 MEANS RELATIVELY HIGH HISTORICAL SPENDING; 1 MEANS RELATIVELY LOW HISTORICAL SPENDING.
•	EXAMPLE: AN RFM SCORE OF 555 REPRESENTS A CUSTOMER SCORING HIGHLY ON ALL THREE DIMENSIONS. A SCORE OF 155 REPRESENTS A CUSTOMER WITH LOW RECENCY SCORE BUT HIGH FREQUENCY AND MONETARY SCORES.
								  
								  RFM KEY FINDINGS AND INSIGHTS
								  
•	RECENCY:  1215 CUSTOMERS FALL INTO THE HIGHEST R-SCORE GROUP, INDICATING THEY PURCHASED RELATIVELY RECENTLY.
•	FREQUENCY: 27.61% OF CUSTOMERS HAVE A LOW FREQUENCY SCORE, SUGGESTING THAT MANY CUSTOMERS HAVE MADE RELATIVELY FEW PURCHASES.
•	MONETARY: THE TOP MONETARY-SCORING GROUP CONTRIBUTES 20.00% OF TOTAL HISTORICAL CUSTOMER REVENUE.
•	COMBINED RFM: 488 CUSTOMERS HAVE STRONG SCORES ACROSS RECENCY, FREQUENCY AND MONETARY VALUE, MAKING THEM A PRIORITY FOR RETENTION.

INSIGHT:-

RFM SCORING HIGHLIGHTS DIFFERENCES IN CUSTOMER ENGAGEMENT AND VALUE.
A CUSTOMER MAY SPEND A LOT BUT HAVE A HIGH NUMBER OF DAYS SINCE THEIR LAST PURCHASE; THIS CUSTOMER MAY NEED A DIFFERENT ACTION FROM A RECENT, FREQUENT PURCHASER.
									
									RFM BUSINESS RECOMMENDATIONS
									
•	PRIORITISE CUSTOMERS WITH HIGH R, F AND M SCORES FOR RETENTION, VIP BENEFITS AND EARLY ACCESS TO NEW PRODUCTS.
•	ENCOURAGE LOW-FREQUENCY CUSTOMERS TO MAKE ANOTHER PURCHASE THROUGH RELEVANT PRODUCT RECOMMENDATIONS AND FOLLOW-UP CAMPAIGNS.
•	REVIEW HIGH-MONETARY BUT LOW-RECENCY CUSTOMERS FOR POSSIBLE WIN-BACK ACTIVITY.
•	USE CUSTOMER-SPECIFIC MESSAGING RATHER THAN SENDING THE SAME PROMOTION TO EVERY CUSTOMER GROUP.

===========================================================================================================
*/

/*
===========================================================================================================

									CUSTOMER SEGMENTATION
									
BUSINESS OBJECTIVE:

TRANSLATE THE NUMERICAL RFM SCORES INTO UNDERSTANDABLE CUSTOMER GROUPS.
THIS HELPS THE BUSINESS IDENTIFY ITS MOST VALUABLE CUSTOMERS, CUSTOMERS WITH GROWTH POTENTIAL 
AND CUSTOMERS WHO MAY BE AT RISK OF BECOMING INACTIVE.

===========================================================================================================
*/

DROP TABLE IF EXISTS CUSTOMER_SEGMENTS;

Create table customer_segments as
	Select
	customerid,
	recency,
	frequency,
	monetary,
	r_score,
	f_score,
	m_score,
	concat(r_score,f_score,m_score) as rfm_score,
	CASE
	WHEN r_score>=4 and f_score>=4 THEN 'Champions'
	WHEN r_score >= 3 and f_score >= 4 THEN 'Loyal Customers'
    WHEN r_score >= 4 AND f_score BETWEEN 2 AND 3 THEN 'Potential Loyalists'
	WHEN r_score = 5 AND f_score = 1 THEN 'New Customers'
    WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'Cannot Lose Them'
    WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
    WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
        ELSE 'Others'
    END AS customer_segment
	FROM customer_rfm_scores;

SELECT * FROM CUSTOMER_SEGMENTS;

/*
===========================================================================================================
						
									SEGMENT DEFINITION
						
•	CHAMPIONS — RECENT CUSTOMERS WITH HIGH PURCHASE FREQUENCY.
•	LOYAL CUSTOMERS — FREQUENT PURCHASERS WHO HAVE PURCHASED REASONABLY RECENTLY.
•	POTENTIAL LOYALISTS — RECENT CUSTOMERS WITH SOME REPEAT-PURCHASE POTENTIAL.
•	NEW CUSTOMERS — CUSTOMERS WITH THE HIGHEST RECENCY SCORE BUT LOW FREQUENCY. THIS IS A SCORE-BASED LABEL, NOT PROOF OF A FIRST-EVER PURCHASE.
•	CANNOT LOSE THEM — CUSTOMERS WITH LOW RECENCY SCORES, HIGH FREQUENCY AND HIGH MONETARY SCORES.
•	AT RISK — CUSTOMERS WITH LOW RECENCY SCORES AND MEANINGFUL PURCHASE FREQUENCY.
•	HIBERNATING — CUSTOMERS WITH LOW RECENCY AND LOW FREQUENCY SCORES.
•	OTHERS — CUSTOMERS WHO DO NOT MEET THE CONDITIONS ABOVE.

===========================================================================================================
*/

/*
===========================================================================================================
							
									SEGMENT PERFORMANCE SUMMARY
							
THIS QUERY MEASURES SEGMENT SIZE, CUSTOMER PERCENTAGE, REVENUE, AVERAGE CUSTOMER REVENUE,
AVERAGE ORDER FREQUENCY AND AVERAGE RECENCY.


===========================================================================================================
*/

SELECT
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS customer_percentage,
    ROUND(SUM(monetary), 2) AS total_revenue,
    ROUND(AVG(monetary), 2) AS avg_customer_revenue,
    ROUND(AVG(frequency), 2) AS avg_orders,
    ROUND(AVG(recency):: NUMERIC, 2) AS avg_recency
	FROM customer_segments
	GROUP BY customer_segment
	ORDER BY total_revenue DESC;

/*
===========================================================================================================

									REVENUE CONTRIBUTION BY SEGMENT
									
THIS QUERY IDENTIFIES THE PERCENTAGE OF TOTAL CUSTOMER REVENUE GENERATED BY EACH SEGMENT.

===========================================================================================================
*/

SELECT
    customer_segment,
    ROUND(SUM(monetary), 2) AS segment_revenue,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER(),2) AS revenue_percentage
	FROM customer_segments
	GROUP BY customer_segment
	ORDER BY segment_revenue DESC;
 
/*
===========================================================================================================

								CUSTOMER SEGMENTATION KEY FINDINGS AND INSIGHTS
								
•	THE LARGEST SEGMENT IS Champions, CONTAINING 1592 CUSTOMERS ( 27.08 OF ALL CUSTOMERS).
•	THE CHAMPIONS SEGMENT GENERATES THE HIGHEST REVENUE OF 12167908.35, CONTRIBUTING 70.03% OF TOTAL REVENUE.
•	THE AT RISK SEGMENT CONTAINS 942 CUSTOMERS, REPRESENTING 16.02% OF THE CUSTOMER BASE.
•	THE CANNOT LOSE THEM SEGMENT HAS THE HIGHEST AVERAGE ORDER FREQUENCY (8.22 ORDERS), INDICATING STRONGER REPEAT-PURCHASE BEHAVIOUR.
•	THE HIBERNATING SEGMENT HAS THE HIGHEST AVERAGE RECENCY (477 DAYS), INDICATING THAT ITS CUSTOMERS HAVE NOT PURCHASED FOR THE LONGEST TIME ON AVERAGE.

BUSINESS INSIGHT:

CUSTOMER COUNT ALONE DOES NOT SHOW A SEGMENT'S IMPORTANCE. COMPARE CUSTOMER PERCENTAGE WITH REVENUE PERCENTAGE. A SMALL SEGMENT MAY CONTRIBUTE A LARGE SHARE OF REVENUE, WHILE A LARGE SEGMENT MAY GENERATE RELATIVELY LITTLE REVENUE.

								CUSTOMER SEGMENT RECOMMENDATIONS

•	CHAMPIONS: PROTECT RELATIONSHIPS THROUGH VIP REWARDS, EARLY ACCESS AND REFERRAL BENEFITS.
•	LOYAL CUSTOMERS: STRENGTHEN REPEAT PURCHASING WITH LOYALTY REWARDS AND RELEVANT CROSS-SELLING.
•	POTENTIAL LOYALISTS: ENCOURAGE ANOTHER PURCHASE WITH PERSONALISED RECOMMENDATIONS AND TIMELY OFFERS.
•	NEW CUSTOMERS: USE A WELCOME JOURNEY AND PRODUCT GUIDANCE TO ENCOURAGE A SECOND PURCHASE. VALIDATE FIRST-PURCHASE DATES BEFORE DESCRIBING CUSTOMERS AS GENUINELY NEW.
•	CANNOT LOSE THEM: PRIORITISE PERSONALISED WIN-BACK CAMPAIGNS BECAUSE THESE CUSTOMERS HAVE HIGH HISTORICAL VALUE AND HAVE NOT PURCHASED RECENTLY.
•	AT RISK: USE TARGETED REACTIVATION OFFERS AND INVESTIGATE POSSIBLE REASONS FOR INACTIVITY.
•	HIBERNATING: TEST LOW-COST RE-ENGAGEMENT CAMPAIGNS AND AVOID SPENDING HEAVILY IF RESPONSE IS LOW.
•	OTHERS: MONITOR FUTURE BEHAVIOUR AND REFINE SEGMENT RULES WHEN MORE DATA IS AVAILABLE.


