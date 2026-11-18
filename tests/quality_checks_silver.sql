/*
================================================================================
Qaulity Checks
================================================================================
Script Purpose:
    This script performs various quality checks for data consistency, accurary
    and standardization across the 'silver' schemas. It included checks for:
    - Null or duplicate primary keys.
    - Unwanted spaces in string fields.
    - Data standardization and consistency.
    - Invalid date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run this checks after data loading Silver layer.
    - Investigate and resolve any descripencies found during the checks
================================================================================
*/

SELECT * FROM silver.crm_prd_info;

SELECT cst_id,
COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1

SELECT * 
FROM bronze.crm_cust_info
WHERE cst_key IS NULL

SELECT cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)


SELECT cst_lastname
FROM bronze.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname)

SELECT DISTINCT cst_marital_status
FROM bronze.crm_cust_info

SELECT DISTINCT cst_gndr
FROM bronze.crm_cust_info

SELECT cst_create_date
FROM bronze.crm_cust_info
WHERE cst_create_date IS NULL;

--------------------------------------------------------------------------------

SELECT * FROM bronze.crm_prd_info;

SELECT prd_id
FROM bronze.crm_prd_info
WHERE prd_id IS NULL;

SELECT prd_key
FROM bronze.crm_prd_info
WHERE prd_key IS NULL OR prd_key != TRIM(prd_key);

SELECT prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

SELECT prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost IS NULL;

SELECT DISTINCT prd_line
FROM bronze.crm_prd_info;

SELECT *
FROM bronze.crm_prd_info
WHERE TRY_CONVERT(DATE,prd_start_dt,105) > TRY_CONVERT(DATE,prd_end_dt,105) OR prd_end_dt IS NULL

--------------------------------------------------------------------------------

SELECT * FROM silver.crm_sales_details;

SELECT sls_ord_num
FROM bronze.crm_sales_details
WHERE sls_ord_num IS NULL

SELECT sls_prd_key
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)

SELECT sls_cust_id
FROM bronze.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info)

SELECT sls_cust_id
FROM bronze.crm_sales_details
WHERE sls_cust_id IS NULL;

SELECT
	TRY_CONVERT(DATE, sls_order_dt) AS sls_order_dt,
	TRY_CONVERT(DATE, sls_ship_dt) AS sls_ship_dt,
	TRY_CONVERT(DATE, sls_due_dt) AS sls_due_dt
FROM bronze.crm_sales_details
WHERE TRY_CONVERT(DATE, sls_ship_dt)<'1990-01-01' OR TRY_CONVERT(DATE, sls_ship_dt) > GETDATE();
TRY_CONVERT(DATE, sls_ship_dt) > TRY_CONVERT(DATE, sls_due_dt) 
OR TRY_CONVERT(DATE, sls_order_dt) > TRY_CONVERT(DATE, sls_ship_dt)
OR TRY_CONVERT(DATE, sls_order_dt) > TRY_CONVERT(DATE, sls_due_dt)

SELECT 
	CASE
		WHEN LEN(sls_order_dt) < 8 THEN NULL
		ELSE TRY_CONVERT(DATE,sls_order_dt)
	END AS sls_order_dt,
	TRY_CONVERT(DATE,sls_ship_dt) AS sls_ship_dt,
	TRY_CONVERT(DATE,sls_due_dt) AS sls_due_dt
FROM bronze.crm_sales_details

SELECT *
FROM
(SELECT 
	CASE
		WHEN sls_sales IS NULL OR sls_sales = 0 THEN ABS(sls_price)*ABS(sls_quantity)
		WHEN ABS(sls_sales) != ABS(sls_price)*ABS(sls_quantity) THEN ABS(sls_price)*ABS(sls_quantity)
		ELSE ABS(sls_sales)
	END AS sls_sales_new,
	CASE
		WHEN sls_price IS NULL OR sls_price = 0 THEN ABS(sls_sales)/ABS(sls_quantity)
		ELSE ABS(sls_price)
	END AS sls_price_new,
	sls_quantity
	
FROM bronze.crm_sales_details)t
WHERE
	sls_sales_new <=0 OR sls_sales_new IS NULL

-------------------------------------------------------------------------------

SELECT * FROM silver.erp_CUST_AZ12

SELECT CID
FROM silver.erp_CUST_AZ12
WHERE CID IS NULL OR CID != TRIM(CID);

SELECT CID
FROM silver.erp_CUST_AZ12
WHERE CID NOT IN (SELECT cst_key FROM bronze.crm_cust_info)

SELECT BDATE
FROM silver.erp_CUST_AZ12
WHERE TRY_CONVERT(DATE,BDATE,105) > GETDATE()

SELECT DISTINCT GEN
FROM silver.erp_CUST_AZ12

-----------------------------------------------------------------------------

SELECT * FROM silver.erp_LOC_A101

SELECT COUNT(CID)
FROM silver.erp_LOC_A101
WHERE CID NOT IN (SELECT cst_key FROM bronze.crm_cust_info)

SELECT DISTINCT CNTRY
FROM silver.erp_LOC_A101

-----------------------------------------------------------------------------

SELECT * FROM silver.erp_PX_CAT_G1V2

SELECT ID
FROM bronze.erp_PX_CAT_G1V2
WHERE ID IS NULL

SELECT ID
FROM bronze.erp_PX_CAT_G1V2
WHERE ID NOT IN (SELECT cat_id FROM silver.crm_prd_info)

SELECT cat_id
FROM silver.crm_prd_info
WHERE cat_id NOT IN (SELECT ID FROM bronze.erp_PX_CAT_G1V2)


SELECT DISTINCT CAT
FROM bronze.erp_PX_CAT_G1V2

SELECT DISTINCT SUBCAT
FROM bronze.erp_PX_CAT_G1V2

SELECT DISTINCT MAINTENANCE
FROM bronze.erp_PX_CAT_G1V2
