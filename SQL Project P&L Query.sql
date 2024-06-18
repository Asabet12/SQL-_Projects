USE H_accounting;

SET @fn_year = 2016;

-- dropping temporary table if already exists
DROP TEMPORARY TABLE IF EXISTS BS_TMP;
CREATE TEMPORARY TABLE BS_TMP
SELECT	DATE_FORMAT(entry_date, '%Y') AS YEAR_OF
			,entry_date
			,base.journal_entry_id 
			,journal_entry
			,line_item
			,account
			,description
			,journal_type
			,CASE WHEN s.statement_section != '' THEN s.statement_section ELSE s2.statement_section END AS statement
			,debit
			,credit
  FROM	journal_entry_line_item AS BASE
NATURAL JOIN account
NATURAL JOIN company
  INNER JOIN journal_entry AS J
	 ON	BASE.journal_entry_id = J.journal_entry_id
  INNER JOIN	journal_type AS t
 	 ON	J.journal_type_id = t.journal_type_id
  INNER JOIN	statement_section AS s
    ON	account.profit_loss_section_id = s.statement_section_id
   INNER JOIN	statement_section AS s2
    ON	account.balance_sheet_section_id = s2.statement_section_id
 WHERE	visible_for_posting = 1 
 			AND debit_credit_balanced = 1
 			AND cancelled = 0
 			AND closing_type = 0
            AND  DATE_FORMAT(entry_date, '%Y') =2016
;
 		

 	 		
SELECT	journal_type
			,statement
			,description
			,account
			,journal_entry_id
			,line_item
			,ROUND(SUM(debit), 0)
			,ROUND(SUM(credit), 0)
FROM	BS_TMP
WHERE	YEAR_OF = @fn_year


 GROUP
 	 BY	journal_type
	  		,statement
 	 		,description
 	 		,account
			,journal_entry_id
			,line_item
ORDER
	 BY	journal_entry_id, line_item;
     
     CALL team_10_account(2019);



-- stored procedure
DELIMITER $$

DROP PROCEDURE IF EXISTS H_Accounting.team_10_account;
CREATE PROCEDURE H_Accounting.team_10_account(IN fn_year INT)
BEGIN

	SET @last_year = fn_year - 1;
	
	-- dropping temporary table if already exists
	DROP TEMPORARY TABLE IF EXISTS BASE_FOR_PNL;
	
	CREATE TEMPORARY TABLE BASE_FOR_PNL 
	SELECT	THIS_YEAR.statement_section AS THIS_YEAR_STATEMENT
				,THIS_YEAR.COST_AMOUNT AS THIS_YEAR_COST
				,THIS_YEAR.REVENUE_AMOUNT AS THIS_YEAR_REVENUE
				,LAST_YEAR.statement_section AS LAST_YEAR_STATEMENT
				,LAST_YEAR.COST_AMOUNT AS LAST_YEAR_COST
				,LAST_YEAR.REVENUE_AMOUNT AS LAST_YEAR_REVENUE
				,debit_is_positive
	  FROM
				(
				SELECT	DISTINCT c.statement_section
							,debit_is_positive
				  FROM	journal_entry_line_item AS a
				  LEFT
				  JOIN	account AS b
				    ON	a.account_id = b.account_id
				  LEFT
				  JOIN	statement_section AS c
				    ON	b.profit_loss_section_id = c.statement_section_id
				  LEFT
				  JOIN	journal_entry AS j
				    ON	a.journal_entry_id = j.journal_entry_id
				 WHERE	c.is_balance_sheet_section = 0
				 			AND c.statement_section != ''
				 			AND j.cancelled = 0
				 			AND j.closing_type = 0
				 			AND b.visible_for_posting = 1
				 ORDER
				 	 BY	debit_is_positive ASC
				) AS statement_tbl -- Define and inspecting Statement categories of P&L in journal Entry
	  LEFT
	  JOIN	(
				SELECT	DATE_FORMAT(entry_date, '%Y') AS YEAR_OF
							,statement_section
							,ROUND(SUM(CASE WHEN CATEGORY = 'COST' THEN debit END), 0) AS COST_AMOUNT
							,ROUND(SUM(CASE WHEN CATEGORY = 'REVENUE' THEN credit END), 0) AS REVENUE_AMOUNT
				  FROM	
						(
						SELECT	entry_date
									,CASE WHEN debit_is_positive = 1 THEN 'COST' ELSE 'REVENUE' END AS CATEGORY
									,statement_section
									,debit
									,credit
									,debit_is_positive
						  FROM	 journal_entry_line_item AS BASE
						  NATURAL JOIN account
						  NATURAL JOIN company
						  INNER JOIN	journal_entry AS J
							 ON	BASE.journal_entry_id = J.journal_entry_id
						  INNER JOIN	journal_type AS t
						 	 ON	J.journal_type_id = t.journal_type_id
						  INNER JOIN	statement_section AS s
						    ON	account.profit_loss_section_id = s.statement_section_id
						 WHERE	s.statement_section != '' -- Exclude Balance_sheet_statement
						 			AND J.cancelled = 0 -- Exclude cancelled Entry
						 			AND J.debit_credit_balanced = 1 -- Exclude unbalanced Entry
						 			AND account.visible_for_posting = 1 -- Exclude unvisible entry
						 			AND J.closing_type = 0 -- Exclude closing type 1
						)	AS BASE
				 WHERE	DATE_FORMAT(entry_date, '%Y') = fn_year
				 GROUP
				 	 BY	YEAR_OF, statement_section
				 ORDER
				 	 BY	YEAR_OF, statement_section
				) AS THIS_YEAR
		 ON	statement_tbl.statement_section = THIS_YEAR.statement_section
	  LEFT
	  JOIN	(
				SELECT	DATE_FORMAT(entry_date, '%Y') AS YEAR_OF
							,statement_section
							,ROUND(SUM(CASE WHEN CATEGORY = 'COST' THEN debit END), 0) AS COST_AMOUNT
							,ROUND(SUM(CASE WHEN CATEGORY = 'REVENUE' THEN credit END), 0) AS REVENUE_AMOUNT
				  FROM	
						(
						SELECT	entry_date
									,CASE WHEN debit_is_positive = 1 THEN 'COST' ELSE 'REVENUE' END AS CATEGORY
									,statement_section
									,debit
									,credit
									,debit_is_positive
						  FROM	 journal_entry_line_item AS BASE
						  NATURAL JOIN account
						  NATURAL JOIN company
						  INNER JOIN	journal_entry AS J
							 ON	BASE.journal_entry_id = J.journal_entry_id
						  INNER JOIN	journal_type AS t
						 	 ON	J.journal_type_id = t.journal_type_id
						  INNER JOIN	statement_section AS s
						    ON	account.profit_loss_section_id = s.statement_section_id
						 WHERE	s.statement_section != '' -- Exclude Balance_sheet_statement
						 			AND J.cancelled = 0 -- Exclude cancelled Entry
						 			AND J.debit_credit_balanced = 1 -- Exclude unbalanced Entry
						 			AND account.visible_for_posting = 1 -- Exclude unvisible entry
						 			AND J.closing_type = 0 -- Exclude closing type 1
						)	AS BASE
				 WHERE	DATE_FORMAT(entry_date, '%Y') = @last_year
				 GROUP
				 	 BY	YEAR_OF, statement_section
				 ORDER
				 	 BY	YEAR_OF, statement_section
				) AS LAST_YEAR
		 ON	statement_tbl.statement_section = LAST_YEAR.statement_section
	;
	
	
	
	
	-- Making Report
	SELECT	'P&L Statement' AS statement_section, '' AS THIS_YEAR, '' AS statement_section, '' AS LAST_YEAR, '' AS YoY_Growth
	UNION
	SELECT	fn_year, '', @last_year, '', ''
	UNION
	SELECT	'Statement Section', 'Amount', 'Statement Section', 'Amount', 'Growth (%)'
	UNION
	SELECT	'----------------', '----------------', '----------------', '----------------', '----------------'
	UNION
	SELECT	IFNULL(THIS_YEAR_STATEMENT, '')
				,IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0) AS THIS_YEAR_AMOUNT
				,IFNULL(LAST_YEAR_STATEMENT, '')
				,IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0) AS LAST_YEAR_AMOUNT
				,IFNULL(ROUND(CASE WHEN THIS_YEAR_COST IS NULL THEN (THIS_YEAR_REVENUE / LAST_YEAR_REVENUE - 1) * 100.0
					ELSE (THIS_YEAR_COST / LAST_YEAR_COST - 1) * 100.0
					END, 2), 0) AS YoY_Growth
	  FROM	BASE_FOR_PNL
	 WHERE	debit_is_positive = 0
	UNION
	SELECT	'Total Revenue'
				,SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) AS THIS_YEAR_AMOUNT
				,'Total Revenue'
				,SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) AS LAST_YEAR_AMOUNT
				,IFNULL(ROUND((SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) 
					/ SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0))
					- 1 ) * 100.0, 2), 0)
				 AS YoY_Growth
	  FROM	BASE_FOR_PNL
	 WHERE	debit_is_positive = 0
	 UNION
	SELECT	'---------------', '----------------', '----------------', '----------------', '----------------'
	 UNION
	SELECT	IFNULL(THIS_YEAR_STATEMENT, '')
				,IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0) AS THIS_YEAR_AMOUNT
				,IFNULL(LAST_YEAR_STATEMENT, '')
				,IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0) AS LAST_YEAR_AMOUNT
				,IFNULL(ROUND(CASE WHEN THIS_YEAR_COST IS NULL THEN (THIS_YEAR_REVENUE / LAST_YEAR_REVENUE - 1) * 100.0
					ELSE (THIS_YEAR_COST / LAST_YEAR_COST - 1) * 100.0
					END, 2), 0) AS YoY_Growth
	  FROM	BASE_FOR_PNL
	 WHERE	debit_is_positive = 1
	UNION
	SELECT	'Direct Cost'
				,SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) AS THIS_YEAR_AMOUNT
				,'Direct Cost'
				,SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) AS LAST_YEAR_AMOUNT
				,IFNULL(ROUND((SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) 
					/ SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0))
					- 1 ) * 100.0, 2), 0)
				 AS YoY_Growth
	  FROM	BASE_FOR_PNL
	 WHERE	debit_is_positive = 1
	  UNION
	SELECT	'---------------', '----------------', '----------------', '----------------', '------------------'
	 UNION
	SELECT	'Gross Profit Margin'
				,(SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)
				,'Gross Profit Margin'
				,(SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)
				,ROUND((((SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0))
					/ ((SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0))
					- 1) * 100.0, 2)
	  FROM	BASE_FOR_PNL
	 WHERE	LAST_YEAR_STATEMENT = 'COST OF GOODS AND SERVICES'
	 UNION
	 SELECT	'Gross Profit Margin %'
				,ROUND(((SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0))
					/ ((SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0)) * 100.0, 2)
				,'Gross Profit Margin %'
				,ROUND(((SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0))
					/ ((SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0)) * 100.0, 2)
				,ROUND((ROUND(((SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0))
					/ ((SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0)) * 100.0, 2))
					- (ROUND(((SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0))
					/ ((SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0)) * 100.0, 2)), 2)
	  FROM	BASE_FOR_PNL
	 WHERE	LAST_YEAR_STATEMENT = 'COST OF GOODS AND SERVICES'
	 UNION
	SELECT	'----------------', '----------------', '----------------', '----------------', '------------------'
	 UNION
	SELECT	'EBITA Margin'
				,((SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0))
					- 
					(SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) AS THIS_YEAR_AMOUNT
					FROM BASE_FOR_PNL WHERE debit_is_positive = 1 AND THIS_YEAR_STATEMENT IN ('SELLING EXPENSES','OTHER EXPENSES'))
				,'EBITA Margin'
				,((SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0))
					- 
					(SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) AS LAST_YEAR_AMOUNT
					FROM BASE_FOR_PNL WHERE debit_is_positive = 1 AND LAST_YEAR_STATEMENT IN ('SELLING EXPENSES','OTHER EXPENSES'))
				,ROUND(((((SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0))
					- 
					(SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) AS THIS_YEAR_AMOUNT
					FROM BASE_FOR_PNL WHERE debit_is_positive = 1 AND THIS_YEAR_STATEMENT IN ('SELLING EXPENSES','OTHER EXPENSES')))
					/ (((SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0))
					- 
					(SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) AS LAST_YEAR_AMOUNT
					FROM BASE_FOR_PNL WHERE debit_is_positive = 1 AND LAST_YEAR_STATEMENT IN ('SELLING EXPENSES','OTHER EXPENSES'))) - 1) * 100.0, 2)
	  FROM	BASE_FOR_PNL
	 WHERE	LAST_YEAR_STATEMENT = 'COST OF GOODS AND SERVICES'
	 UNION
	SELECT	'EBITA %'
				,ROUND(((((SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0))
					- 
					(SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) AS THIS_YEAR_AMOUNT
					FROM BASE_FOR_PNL WHERE debit_is_positive = 1 AND THIS_YEAR_STATEMENT IN ('SELLING EXPENSES','OTHER EXPENSES')))
					/ ((SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0))) * 100.0, 2)
				,'EBITA %'
				,ROUND(((((SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0))
					- 
					(SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) AS LAST_YEAR_AMOUNT
					FROM BASE_FOR_PNL WHERE debit_is_positive = 1 AND LAST_YEAR_STATEMENT IN ('SELLING EXPENSES','OTHER EXPENSES')))
					/ ((SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0))) * 100.0, 2)
				,ROUND((((((SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0))
					- 
					(SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) AS THIS_YEAR_AMOUNT
					FROM BASE_FOR_PNL WHERE debit_is_positive = 1 AND THIS_YEAR_STATEMENT IN ('SELLING EXPENSES','OTHER EXPENSES')))
					/ ((SELECT SUM(IFNULL(CASE WHEN THIS_YEAR_COST IS NULL THEN THIS_YEAR_REVENUE 
					ELSE THIS_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0))) * 100.0)
					- (((((SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0) 
					- IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0))
					- 
					(SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) AS LAST_YEAR_AMOUNT
					FROM BASE_FOR_PNL WHERE debit_is_positive = 1 AND LAST_YEAR_STATEMENT IN ('SELLING EXPENSES','OTHER EXPENSES')))
					/ ((SELECT SUM(IFNULL(CASE WHEN LAST_YEAR_COST IS NULL THEN LAST_YEAR_REVENUE 
					ELSE LAST_YEAR_COST 
					END, 0)) FROM BASE_FOR_PNL WHERE debit_is_positive = 0))) * 100.0), 2)
	  FROM	BASE_FOR_PNL
	 WHERE	LAST_YEAR_STATEMENT = 'COST OF GOODS AND SERVICES'
	
	;

END$$
DELIMITER ;
     
     
     
     
     
     
     