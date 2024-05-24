/* 1. Provide the list of markets in which customer "Atliq Exclusive" operates its
business in the APAC region. */

	select market
	from dim_customer 
	where customer = "Atliq Exclusive" and region = "apac";

/* 2. What is the percentage of unique product increase in 2021 vs. 2020? The
final output contains these fields,
	unique_products_2020
	unique_products_2021
	percentage_c */

	with unique_products_2020 as (
	    select
		  COUNT(distinct product_code) as unique_product_2020
	    from 
		  fact_gross_price
	    where 
		  fiscal_year = 2020
	), 
	unique_products_2021 as (
	    select 
		  COUNT(distinct product_code) as unique_product_2021
	    from 
		  fact_gross_price
	    where 
		  fiscal_year = 2021
	)
	select 
	    up2020.unique_product_2020,
	    up2021.unique_product_2021,
	    ROUND(
		  (up2021.unique_product_2021 - up2020.unique_product_2020) / up2020.unique_product_2020 * 100,
		  2
	    ) as percentage_change
	from 
	    unique_products_2020 up2020,
	    unique_products_2021 up2021;

/* 3. Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains
	2 fields,
	segment
	product_count */
 
	select segment, count(distinct product_code) as product_count
	from dim_product
	group by segment
	order by product_count desc;
      
/* 4. Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields,
	segment
	product_count_2020
	product_count_2021
	difference */
 
	WITH product_count_2020 AS ( 
	    SELECT 
		  p.segment,
		  s.fiscal_year,
		  COUNT(p.product) AS product_count_2020
	    FROM fact_sales_monthly s
	    JOIN dim_product p 
		  ON s.product_code = p.product_code 
	    WHERE s.fiscal_year = 2020
	    GROUP BY 
		  p.segment,
		  s.fiscal_year
	), 
	product_count_2021 AS (
	    SELECT 
		  p.segment,
		  s.fiscal_year,
		  COUNT(p.product) AS product_count_2021
	    FROM fact_sales_monthly s
	    JOIN dim_product p 
		  ON s.product_code = p.product_code 
	    WHERE s.fiscal_year = 2021
	    GROUP BY 
		  p.segment,
		  s.fiscal_year
	) 
	SELECT 
	    pc2020.segment,
	    pc2020.product_count_2020,
	    pc2021.product_count_2021
	FROM 
	    product_count_2020 AS pc2020
	JOIN 
	    product_count_2021 AS pc2021
	    ON pc2020.segment = pc2021.segment;
          
/* 5. Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields,
	product_code
	product
	manufacturing_cost */
 
	 select 
		p.product_code, p.product, 
		mc.manufacturing_cost
	 from fact_manufacturing_cost mc
	 join dim_product p 
	 on mc.product_code = p.product_code
	where manufacturing_cost in (
		select max(manufacturing_cost) from fact_manufacturing_cost 
		union
		select min(manufacturing_cost) from fact_manufacturing_cost 
	)
	order by manufacturing_cost desc;

/* 6. Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
	customer_code
	customer
	average_discount_percentage */

	select 
		pre.customer_code, c.customer , 
		avg(pre.pre_invoice_discount_pct) as avg_discount_pct
	from fact_pre_invoice_deductions pre 
	join dim_customer c 
	on pre.customer_code = c.customer_code
	where pre.fiscal_year = 2021 and market = 'india' 
	group by pre.customer_code , c.customer
	order by c.customer 
	limit	5;

/* 7. Get the complete report of the Gross sales amount for the customer “Atliq
Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns:
	Month
	Year
	Gross sales Amount */

	with cte1 as(
		select 
			monthname(s.date) as months,
			month(s.date) as month_number,
			year(s.date) as years,
                  (s.sold_quantity * gp.gross_price)  AS gross_sales
		from fact_sales_monthly s 
		join fact_gross_price gp 
		on s.product_code = gp.product_code 
		join dim_customer c 
		on c.customer_code = s.customer_code 
		where customer = 'Atliq Exclusive'
	)  
		select 
			months, years,
                  concat(round(sum(gross_sales)/1000000, 2), "m" ) as gross_sales
            from cte1
            group by years,months,month_number
		order by years,month_number;

/* 8. In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity,
	Quarter
	total_sold_quantity */

select 
case
    when date between '2019-09-01' and '2019-11-01' then 1  
    when date between '2019-12-01' and '2020-02-01' then 2
    when date between '2020-03-01' and '2020-05-01' then 3
    when date between '2020-06-01' and '2020-08-01' then 4
    end as Quarters,
    sum(sold_quantity) as total_sold_quantity
from fact_sales_monthly
where fiscal_year = 2020
group by  Quarters
order by total_sold_quantity DESC;

/* 9. Which channel helped to bring more gross sales in the fiscal year 2021
and the percentage of contribution? The final output contains these fields,
	channel
	gross_sales_mln
	percentage */

	 with cte1 as (
		 select 
			c.channel as channels,
			sum(s.sold_quantity * g.gross_price )as total_sales
		 from fact_sales_monthly s
		 join 
			fact_gross_price g 
			on s.product_code = g.product_code
		 join 
			dim_customer c 
			on s.customer_code = c.customer_code
		 where s.fiscal_year = '2021'
		 group by c.channel 
		 order by total_sales 
	) 
	select 
		channels,
		round(total_sales/1000000,2) as gross_sales_mln,
		round(total_sales/(sum(total_sales) over())*100,2) as percentage
	from cte1;

/* 10. Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these
	fields,
	division
	product_code
	product
	total_sold_quantity
	rank_order */

with output1 as 
(
    select p.division, fs.product_code, p.product, sum(fs.sold_quantity) as total_sold_quantity
    from dim_product p 
    join fact_sales_monthly fs
    on p.product_code = fs.product_code
    where fs.fiscal_year = 2021 
    group by fs.product_code, p.division, p.product
),
output2 as 
(
    select division, product_code, product, total_sold_quantity,
           rank() over(partition by division order by total_sold_quantity desc) as rank_order
    from output1
)
select output1.division, output1.product_code, output1.product, output2.total_sold_quantity, output2.rank_order
from output1 
join output2
on output1.product_code = output2.product_code
where output2.rank_order in (1, 2, 3);









