USE [SetecCDR]


GO
/****** Object:  StoredProcedure [dbo].[p_rpt5996_GenerateCSC]    Script Date: 05/12/15 10:59:21 AM ******/
SET ANSI_NULLS ON
GO
  SET QUOTED_IDENTIFIER ON
GO

--===============================================================
			-- Stored Procedure Name:		p_rpt5996_GenerateCSC
			-- SSRS Report:                 TEST_5996-Report
			-- [Server].Database & Tables:  [10.0.25.50].SetecCDR			
			--                              - ProblemReport
			--                              - ProblemReportCategory
			--                              [10.0.25.50].SetecCallHist
			--                              - captions_calldata
			--                              - captions_calldata_intervals30_ByCenter_New
			--                              [10.0.25.50].CallDataDWProd
			--                              - Captions_XRef
			-- Functions:                   --			                           			
			-- Temporary Tables:            --

			-- Permanent Temporary Tables:  -- 
			
-- ================================================================	
/*
 exec [p_rpt5996_GenerateCSC] '2015-12-01','2015-12-02',NULL,'PROD',1 
*/

 ALTER PROCEDURE [dbo].[p_rpt5996_GenerateCSC]
 @StartDate DATETIME = NULL ,               -- Report Run Start Date.
 @EndDate DATETIME =NULL ,                  -- Report Run End Date.
 @CompanyName  VARCHAR(100),                -- NULL For All 
								            -- Allorica 
								            -- Stellar
								            -- West 
 @runflag  varchar(10) = 'TEST',            -- 'TEST','PROD'  Specifies use of test or production allocation.
 @MannualTest INT = NULL                    -- For Manual Testing purposes only(@MannualTest=1 for server side execution
                                            -- and everything else for unit test) 
 
 AS
 
		SET NOCOUNT ON  

		 --============================================================================================
	    Declare @unitTest_CurrentDate DATETIME  
	    SET @unitTest_CurrentDate = '12-03-2015' --'11-23-2015' --Set the date value for any first day of month/any day for of month Default Settings
       --============================================================================================

		DECLARE @FirstDate VARCHAR(12)
		DECLARE @LastDate VARCHAR(12)

		DECLARE @FDate DATETIME
		DECLARE @LDate DATETIME

        DECLARE @SQL VARCHAR(MAX)
		

	  If(@MannualTest=1)
	  BEGIN
	    If(@StartDate Is Null AND @EndDate Is Null)--Check Dates if the report launches first time
	  Begin
	    Set @FDate = DATEADD(MONTH, DATEDIFF(month, 0, GETDATE()), 0)
		Set @LDate = DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 1)

		If(Day(@FDate)=1 And Day(@LDate)=1 And Month(@FDate)=Month(@LDate))
	    Begin
		     Set @FDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE())-1, 0)
			 Set @LDate = DATEADD(MONTH, DATEDIFF(MONTH, -1, GETDATE())-1, -1)
		 End
		 Else
		 Begin
		     Set @FDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
			 Set @LDate = DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
		 End
		   SET @FirstDate=@FDate
		   SET @LastDate=@LDate
	   End 
	  Else 
	    Begin
		     Set @FDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @StartDate)-1, 0)
			 Set @LDate = DATEADD(MONTH, DATEDIFF(MONTH, -1, @EndDate)-1, -1)
			 
			 SET @FirstDate = @StartDate
		     SET @LastDate = @EndDate
		End	  
		 END
	  ELSE
	   BEGIN
		 --Testing the date for the First Day of Month	
		  IF(Day(@unitTest_CurrentDate) = 1)
		  BEGIN
				 Set @FDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, @unitTest_CurrentDate)-1, 0)
				 Set @LDate = DATEADD(MONTH, DATEDIFF(MONTH, -1, @unitTest_CurrentDate)-1, -1)

			 
			  SET @FirstDate=@FDate
			  SET @LastDate=@LDate
		  END
		  ELSE
		  BEGIN
		      Set @FDate = CAST(DATEADD(DAY,-DAY(@unitTest_CurrentDate)+1, CAST(@unitTest_CurrentDate AS DATE)) AS DATETIME)
			  Set @LDate = DATEADD(DAY,-1,@unitTest_CurrentDate)
		  
			  SET @FirstDate=@FDate
			  SET @LastDate=@LDate
		  END
        END
		

	    if object_id('tempdb..#Company') is not null
		drop table #Company

		--Creating the table for getting all company of data 
		CREATE TABLE #Company
		(
		 companyname VARCHAR(100)
		,locationcode VARCHAR(100)
		)
		INSERT INTO #Company
		select distinct 
		companyname, locationcode 
		from SetecCallHist..captions_calldata_intervals30_ByCenter_New 
		Where CompanyName !=''

		
	  --Checking the variable value 
      IF(@CompanyName IS NOT NULL)
	     BEGIN
		    --Select all Company Code with comma as per the company is coming from parameter
			SET @CompanyName=(SELECT STUFF((SELECT ',' + ''''+A.[locationcode]+'''' FROM #Company  A
			 Where A.[companyname]=B.[companyname] FOR XML PATH('')),1,1,'') As value
			 From #Company  B
			 Where companyname=@CompanyName
			 Group By [companyname])
		 END	
      ELSE
	    BEGIN
		   --Select all Company Code with comma if company code is null
		   SET @CompanyName=(SELECT STUFF((SELECT ',' + ''''+ [locationcode]+'''' FROM #Company FOR XML PATH('')),1,1,'') As value)
		   SET @CompanyName=@CompanyName+','+''''''+','+'NULL'
		END

		-------------Creating the temperory table for the captions_calldata-------------

		 Select * into  #captions_calldata from 
	     [SetecCallHist].[dbo].[captions_calldata] 
	      where Handoff_Time 
		  between @FirstDate And DATEADD(DD,1,@LastDate) 

       -------------Creating the temperory table for the captions_calldata-------------

	   -------------Creating the temperory table for the final result-------------

	    CREATE TABLE #result
		(
		 StartDate Datetime,
		 EndDate Datetime,
		 csOprSessionID varchar(50),
		 DateCreated Datetime,
		 ProblemReportID int,
		 SessionID varchar(50),
		 OperatorID varchar(20),
		 locationcode varchar(10),
		 AssistedUserTelephoneNumber varchar(40),
		 DialedorReceivedTelephoneNumber varchar(40),
		 CallType varchar(40),
		 CategoryName varchar(100),
		 Notes varchar(max),
		 UserID_Caller varchar(40),
		 ErrorCode varchar(50)
		)

		-------------Creating the temperory table for the final result-------------

		-------------Creating the index on the final result-------------

		CREATE INDEX ix_result ON #result (csOprSessionID,DateCreated)

		-------------Creating the index on the final result--------------


		--====================================================================================================
		               -- Pulls in all data where PR.SessionID = CD.SessionID 
		               -- Accomplishes this using the XREF Table 
		--====================================================================================================
		
		
		SET @SQL='INSERT INTO #result
		 SELECT DISTINCT
		 '''+ @FirstDate +''' AS StartDate,
		 '''+ @LastDate +''' AS EndDate
		 ,CD.csOprSessionID		   
		 ,DateCreated
		 ,PR.ProblemReportID
		 ,PR.SessionID		 
		 ,CD.OperatorID AS [OperatorID]
		 ,CD.locationcode as [locationcode]
		 ,CD.Caption_PhoneNumber_Clean  AS [AssistedUserTelephoneNumber]
		 ,CD.Voice_PhoneNumber_Clean  AS [DialedorReceivedTelephoneNumber]
		 ,CD.Call_Type_Label AS [CallType]
		 ,CAT.CategoryName
		 ,PR.ProblemReportData as [Notes]
		 ,CD.UserID_Caller as [UserID_Caller]
		 ,PR.ErrorCode    
       
		 FROM SetecCDR..ProblemReport AS PR
		 INNER JOIN SetecCDR..ProblemReportCategory as cat 
		 ON PR.ProblemReportCategoryID = CAT.ProblemReportCategoryID
		 JOIN CallDataDWProd.dbo.Captions_XRef AS XRef on
		 PR.SessionID = XRef.SessionID
		 JOIN #captions_calldata AS CD on
		 XREF.CallID = CD.CallID 
		 where DateCreated  >= '''+ @FirstDate +''' And DateCreated < DATEADD(DD,1,'''+ @LastDate +''') 
		 AND CD.locationcode IN('+@CompanyName+')
		 AND ErrorCode=''PR4000''
		 AND (Answered = 1 OR Abandon = 1)
		 
			
		UNION			
		
		--====================================================================================================
		               -- Pulls in all data where PR.SessionID = CD.SessionID 
		               -- Accomplishes this using the XREF Table 
		--====================================================================================================	


		 SELECT DISTINCT 
		  '''+ @FirstDate +''' AS StartDate
		  ,'''+ @LastDate +''' AS EndDate
		  ,CD.csOprSessionID
	      ,(DateCreated)
		  ,ProblemReportID
		  ,'''' AS [SessionID]				
		  ,CD.OperatorID AS [OperatorID]
		  ,CD.locationcode as [locationcode]
		  ,''''  AS [AssistedUserTelephoneNumber]
		  ,''''  AS [DialedorReceivedTelephoneNumber]
		  ,'''' AS CallType
		  ,CAT.CategoryName
		  ,ProblemReportData as [Notes]
	      ,'''' as [UserID_Caller]
		  ,ErrorCode         

		  FROM SetecCDR..ProblemReport AS PR
		  INNER JOIN SetecCDR..ProblemReportCategory as cat
		  ON PR.ProblemReportCategoryID = CAT.ProblemReportCategoryID
		  LEFT JOIN #captions_calldata AS CD on
		  CD.csOprSessionID = PR.SessionID
		  where DateCreated  >= '''+ @FirstDate +''' And DateCreated < DATEADD(DD,1,'''+ @LastDate +''') 
		  AND CD.locationcode IN('+@CompanyName+')
		  AND ErrorCode=''PR4000''
		  AND (Answered = 1 OR Abandon = 1)
		  Group By DateCreated
		  ,ProblemReportID
		  ,PR.SessionID
		  ,CD.csOprSessionID
		  ,CD.OperatorID
		  ,CD.locationcode
		  ,CAT.CategoryName
		  ,ProblemReportData
		  ,CD.UserID_Caller
		  ,ErrorCode   
          ORDER BY DateCreated'        
		  

		EXEC (@SQL	)

		Select * from #result Order by DateCreated
		
				
	 SET NOCOUNT OFF