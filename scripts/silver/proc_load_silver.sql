/*
=================================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
=================================================================================
Script Purpose:
    This stored procedure perform the ETL (Extract, Transfrom, Load) process
    to populate the 'silver' schema tables from the 'bronze' schema.
  Actions Performed:
    - Truncate Silver Tables
    - Inserst transformed and cleansed data from Bronze into Silver Tables.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    EXEC silver.laod_proc
*/

CREATE OR ALTER PROC silver.load_proc
AS
BEGIN
	DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME, @start_time DATETIME, @end_time DATETIME;
	BEGIN TRY
		SET @start_time = GETDATE();
		PRINT 'Loading Initiated...';
		PRINT '==============================================================';

		SET @batch_start_time = GETDATE();
		TRUNCATE TABLE silver.crm_cust_info
		INSERT INTO silver.crm_cust_info(
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date
		)
		SELECT
			cst_id,
			TRIM(cst_key) AS cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,
			CASE cst_marital_status
				WHEN 'S' THEN 'Single' 
				WHEN 'M' THEN 'Married'
				ELSE 'N/A'
			END AS cst_marital_status,
			CASE cst_gndr
				WHEN 'F' THEN 'Female'
				WHEN 'M' THEN 'Male'
				ELSE 'N/A'
			END AS cst_gndr,
			TRY_CONVERT(DATE,cst_create_date,105) AS cst_create_date
		FROM
		(SELECT *,
		ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_id
		FROM bronze.crm_cust_info)t
		WHERE flag_id = 1 AND cst_id IS NOT NULL
		SET @batch_end_time = GETDATE();
		PRINT 'Load Duration--> ' + CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS VARCHAR) + ' seconds'
		PRINT '----------------------------------------------------'

		SET @batch_start_time = GETDATE();
		TRUNCATE TABLE silver.crm_prd_info;
		INSERT INTO silver.crm_prd_info(
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt,
			prd_end_dt
		)
		SELECT
			prd_id,
			REPLACE(SUBSTRING(prd_key,1,5),'-','_') AS cat_id,
			TRIM(SUBSTRING(prd_key,7,LEN(prd_key))) AS prd_key,
			TRIM(prd_nm) AS prd_nm,
			ISNULL(prd_cost,0) AS prd_cost,
			CASE prd_line
				WHEN 'M' THEN 'Mountain'
				WHEN 'R' THEN 'Road'
				WHEN 'S' THEN 'Other Sales'
				WHEN 'T' THEN 'Touring'
				ELSE 'N/A'
			END AS prd_line,
			TRY_CONVERT(DATE,prd_start_dt,105) AS prd_start_dt,
			DATEADD(DAY, -1, LEAD(TRY_CONVERT(DATE,prd_start_dt,105)) OVER(PARTITION BY prd_key ORDER BY TRY_CONVERT(DATE,prd_start_dt,105))) AS prd_end_dt
		FROM bronze.crm_prd_info;
		SET @batch_end_time = GETDATE();
		PRINT 'Load Duration--> ' + CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS VARCHAR) + ' seconds'
		PRINT '----------------------------------------------------'

		SET @batch_start_time = GETDATE();
		TRUNCATE TABLE silver.crm_sales_details
		INSERT INTO silver.crm_sales_details(
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			sls_order_dt,
			sls_ship_dt,
			sls_due_dt,
			sls_sales,
			sls_quantity,
			sls_price
		)
		SELECT
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,
			CASE
				WHEN LEN(sls_order_dt) < 8 THEN NULL
				ELSE TRY_CONVERT(DATE,sls_order_dt)
			END AS sls_order_dt,
			TRY_CONVERT(DATE,sls_ship_dt) AS sls_ship_dt,
			TRY_CONVERT(DATE,sls_due_dt) AS sls_due_dt,
			CASE
				WHEN sls_sales IS NULL OR sls_sales = 0 THEN ABS(sls_price)*ABS(sls_quantity)
				WHEN ABS(sls_sales) != ABS(sls_price)*ABS(sls_quantity) THEN ABS(sls_price)*ABS(sls_quantity)
				ELSE ABS(sls_sales)
			END AS sls_sales,
			sls_quantity,
			CASE
				WHEN sls_price IS NULL OR sls_price = 0 THEN ABS(sls_sales)/ABS(sls_quantity)
				ELSE ABS(sls_price)
			END AS sls_price
		FROM bronze.crm_sales_details
		SET @batch_end_time = GETDATE();
		PRINT 'Load Duration--> ' + CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS VARCHAR) + ' seconds'
		PRINT '----------------------------------------------------'

		SET @batch_start_time = GETDATE();
		TRUNCATE TABLE silver.erp_CUST_AZ12
		INSERT INTO silver.erp_CUST_AZ12(
			CID,
			BDATE,
			GEN
		)
		SELECT
			REPLACE(CID,'NAS','') AS CID,
			CASE
				WHEN TRY_CONVERT(DATE,BDATE,105) > GETDATE() THEN NULL
				ELSE TRY_CONVERT(DATE,BDATE,105)
			END AS BDATE,
			CASE
				WHEN UPPER(TRIM(GEN)) IS NULL OR UPPER(TRIM(GEN)) = '' THEN 'N/A'
				WHEN UPPER(TRIM(GEN)) IN ('M','MALE') THEN 'Male'
				WHEN UPPER(TRIM(GEN)) IN ('F','FEMALE') THEN 'Female'
				ELSE GEN
			END AS GEN
		FROM bronze.erp_CUST_AZ12
		SET @batch_end_time = GETDATE();
		PRINT 'Load Duration--> ' + CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS VARCHAR) + ' seconds'
		PRINT '----------------------------------------------------'

		SET @batch_start_time = GETDATE();
		TRUNCATE TABLE silver.erp_LOC_A101
		INSERT INTO silver.erp_LOC_A101(
			CID,
			CNTRY
		)
		SELECT
			REPLACE(CID,'-','') AS CID,
			CASE
				WHEN UPPER(TRIM(CNTRY)) =  'DE' THEN 'Germany'
				WHEN UPPER(TRIM(CNTRY)) = 'USA' OR UPPER(TRIM(CNTRY)) = 'US' THEN 'United States'
				WHEN UPPER(TRIM(CNTRY)) IS NULL OR UPPER(TRIM(CNTRY)) = '' THEN 'N/A'
				ELSE CNTRY
			END AS CNTRY
		FROM bronze.erp_LOC_A101
		SET @batch_end_time = GETDATE();
		PRINT 'Load Duration--> ' + CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS VARCHAR) + ' seconds'
		PRINT '----------------------------------------------------'

		SET @batch_start_time = GETDATE();
		TRUNCATE TABLE silver.erp_PX_CAT_G1V2
		INSERT INTO silver.erp_PX_CAT_G1V2(
			ID,
			CAT,
			SUBCAT,
			MAINTENANCE
		)
		SELECT
			TRIM(ID) AS ID,
			TRIM(CAT) AS CAT,
			TRIM(SUBCAT) AS SUBCAT,
			TRIM(MAINTENANCE) AS MAINTENANCE
		FROM bronze.erp_PX_CAT_G1V2
		SET @batch_end_time = GETDATE();
		PRINT 'Load Duration--> ' + CAST(DATEDIFF(second,@batch_start_time,@batch_end_time) AS VARCHAR) + ' seconds'
		PRINT '----------------------------------------------------'

		SET @end_time = GETDATE();
		PRINT '==============================================================';
		PRINT 'Loading Completed.'
		PRINT 'Total Load Duration--> ' + CAST(DATEDIFF(second,@start_time,@end_time) AS VARCHAR) + ' seconds';
	END TRY
	BEGIN CATCH
		PRINT '****************ERROR***************'
		PRINT 'ERROR OCCURED IN LOADING SILVER LAYER'
		PRINT 'ERROR MESSAGE: ' + ERROR_MESSAGE()
		PRINT 'ERROR NUMBER: ' + CAST(ERROR_NUMBER() AS NVARCHAR)
		PRINT 'ERROR STATE: ' + CAST(ERROR_STATE() AS NVARCHAR)
		PRINT '************************************'
	END CATCH
END;
GO
