USE [Reports]
GO
/****** Object:  StoredProcedure [dbo].[p_rpt8074_CC_DailyCallDetail_Summar2]    Script Date: 10/28/2015 5:38:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
			-- Stored Procedure Name:		p_rpt8074_CC_DailyCallDetail_Summary
			-- SSRS Report:                 8074 ? Purple Care Daily Call Detail
			-- [Server].Database & Tables:  CallDataDWProd
			--                              - cc_calldata_report				
			--                              aresVRS 
			--                              - Whitelabels	    
                           
			-- Functions:                   -
			--                              -
			-- Temporary Tables:            #Results,#ccCallData,#CallsDetails,#ccCallDataWTD,#tempccCallData

			-- Permanent Temporary Tables:  --
			-- Historical Tracking:         
			 
			-- =============================================	
/*
 Exec [p_rpt8074_CC_DailyCallDetail_Summary] '2015-06-19','S'
*/
 
 ALTER PROC [dbo].[p_rpt8074_CC_DailyCallDetail_Summary]
 @Startdate datetime=NULL,
 @Mode char(1)
 AS

		SET NOCOUNT ON;
		SET ANSI_WARNINGS OFF;	

		declare @EndDate datetime;						
		declare @FromMTD	datetime
		declare @MTDEndDate	datetime
		declare @FromWTD	datetime

		if @Mode ='S' And (@Startdate is Null OR @Startdate ='')			
			begin
			SET @StartDate =  dateadd(dd,-1,cast(convert(varchar(10),getdate(),101) + ' 00:00:000' as datetime)) 
			end
         else if @Mode = 'I'
		    begin
			SET @StartDate =  dateadd(dd,0,cast(convert(varchar(10),getdate(),101) + ' 00:00:000' as datetime)) 
			end
		set @EndDate = DATEADD(dd,1,@StartDate)
		set @MTDEndDate = DATEADD(dd,1,@StartDate)
		set @FromMTD = convert(datetime, convert(char(4), datepart(year, @StartDate)) + '-' + convert(varchar(2), datepart(month, @StartDate)) + '-01 00:00:00.000')		
		set @FromWTD = DATEADD(dd,-6,@StartDate)


         --=========================================================================

			--Daily Totals Start

		--=========================================================================

        
		--=========================================================================

		--PUT DIRECT CALLS and TRANSFERS FROM VIs into Temp Table -------------------

		--=========================================================================
         

			Select * INTO #ccCallData 
			From CallDataDWProd.dbo.cc_calldata_report CC
			Where
			(datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16)
			AND Handoff_Time >= @FromMTD and Handoff_Time < @EndDate
			AND Parent_SessionID IS NULL
			AND (vrs_cc_xfr = 0 OR vri_cc_xfr = 0)
			AND Incoming = 1

           --=========================================================================

		   -- Add Transfers from VIs to the temp table

	     	--=========================================================================

			INSERT INTO #ccCallData   
			Select * From CallDataDWProd.dbo.cc_calldata_report CC
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromMTD and Handoff_Time < @EndDate
			AND Parent_SessionID NOT IN (Select SessionID From CallDataDWProd.dbo.cc_calldata_report)
			AND (vrs_cc_xfr = 1 OR vri_cc_xfr = 1)

            --=========================================================================

		    --WARM TRANSFERS WITHIN CUSTOMER CARE

	     	--=========================================================================	   	
			

            -----------------------------------------------------------------------------
			--PUT DIRECT CALLS and TRANSFERS FROM VIs into Temp Table for daily Totals
			-----------------------------------------------------------------------------


			Create Table #CallsDetails
		    (
		    Phone varchar(20)		  
		   ,Interval DateTime		   
		   ,Incoming Int
		   ,Answered Int
		   ,Abandon Int
		   ,Inbound Int
		   ,AnswerTime Decimal(18,4)
		   ,AbandonTime Decimal(18,4)		  		   		  
		   ,timecallplaced DateTime
		   ,csOprAcceptTime DateTime
		   ,Call_Type Int
		   ,SessionTime Decimal(18,4)		  		   		  
		   ) 

		   Insert into #CallsDetails
		   Select	
		    WL.callerID AS 'Phone Number'		
			,Case when Datepart(MI,Handoff_Time) <= 29  Then  Cast('1900-01-01 '+ Cast(Datepart(HOUR,Handoff_Time) as varchar(2)) +':'+ '00 ' as Datetime)
			  When Datepart(mi,Handoff_Time) > 29 And Datepart(mi,Handoff_Time) <= 59 Then Cast('1900-01-01 '+ Cast(Datepart(HOUR,Handoff_Time) as varchar(2)) +':'+ '30 ' as Datetime) End as Interval            
			,Incoming	
			,Answered
			,Abandon
			,Inbound
			,AnsweredTime
			,AbandonTime
			,timecallplaced
			,csOprAcceptTime
			,CC.Call_Type
			,SessionTime	

			From #ccCallData CC
			Left JOIN aresVRS.dbo.Whitelabels WL
			ON CC.Branding = WL.ID 
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @Startdate and Handoff_Time < @EndDate
			AND WL.CallerID NOT IN ('8557801091','8552090989','8442568990','8774674877') 
			group by 
			 callerID
			,Handoff_Time
			,Incoming
			,Answered
			,Abandon
			,AnsweredTime
			,AbandonTime
			,Call_Type
			,timecallplaced
			,csOprAcceptTime
			,SessionTime
			,Inbound



	    --=========================================================================

		--Create Temp Table For the Final Result

		--=========================================================================         
		  
		   Create table #Results
			(
			rptStart datetime,
			rptEnd datetime,	
			DataType varchar(28),
			TotalType varchar(128),		
			Interval datetime,
					
			SL20Secs decimal(12,4),
			SL30Secs decimal(12,4),
			SL60Secs decimal(12,4),

			TBL5Secs decimal(12,4),
			TBL10Secs decimal(12,4),
			TBL20Secs decimal(12,4),
			TBLOver20Secs decimal(12,4),

			QueuedTime decimal(17,4),
			AvgMinsPerCall decimal(17,4),			
			STDDev decimal(17,4),
			AnsweredPct decimal(17,4),
			IncomingCalls int,

			SVPCallsPct decimal(17,4),
			P3CallsPct decimal(17,4),
			P3MobileCallsPct decimal(17,4),
			OthersCallsPct decimal(17,4),

			AnsweredCall int,
			AbandonedCall int,
			Incoming Int,
			Inbound Int
			)

        --=========================================================================

		--Inserting the record as per the time frames

		--========================================================================= 

			Insert into #Results
			Select			
			 @StartDate as 'rptStart'
	        ,@StartDate as 'rptEnd'
			,'Daily Totals' as 'DataType'
			,'Grand Total' as 'TotalType'
			,Interval
			,ISNULL(SUM(CASE WHEN (AnswerTime+AbandonTime) <= 20 and Incoming = 1 THEN 1.0 ELSE 0 END),0) AS [SVL20sec]
			,ISNULL(SUM(CASE WHEN (AnswerTime+AbandonTime) <= 30 and Incoming = 1 THEN 1.0 ELSE 0 END),0) AS [SVL30sec]
			,ISNULL(SUM(CASE WHEN (AnswerTime+AbandonTime) <= 60 and Incoming = 1 THEN 1.0 ELSE 0 END),0) AS [SVL60sec]
			,ISNULL(SUM(CASE WHEN (AbandonTime) <= 5 and Abandon = 1 THEN 1.0 ELSE 0 END),0) AS [TBL5Secs]
			,ISNULL(SUM(CASE WHEN (AbandonTime) <= 10 and Abandon = 1 THEN 1.0 ELSE 0 END),0) AS [TBL10Secs]
			,ISNULL(SUM(CASE WHEN (AbandonTime) <= 20 and Abandon = 1 THEN 1.0 ELSE 0 END),0) AS [TBL20Secs]
			,ISNULL(SUM(CASE WHEN (AbandonTime) > 20 and Abandon = 1 THEN 1.0 ELSE 0 END),0) AS [TBLOver20Secs]

			,MAX(datediff(ms,timecallplaced,csOprAcceptTime))/60000.0 as [QueuedTime]
			,SUM(SessionTime)/60.0 / SUM(NULLIF(Inbound,0)) AS [AvgMinsPerCall]
			,ISNULL(STDEV(SessionTime/60.0),0) as [STDDev]
			,ISNULL(SUM(Answered),0) as [AnsweredPct]
			,ISNULL(SUM(Incoming),0) AS [Incoming]

			,SUM(case when Call_Type IN(130,170) then 1 else 0 end) as [SVPCallsPct]
			,SUM(case when Call_Type IN(85,115,120,35,55,185,190) then 1 else 0 end) as [P3CallsPct]
			,SUM(case when Call_Type IN(100,105,140,145,180,200) then 1 else 0 end) as [P3MobileCallsPct]
			,SUM(case when Call_Type IN(130,170,85,115,120,35,55,185,190,100,105,140,145,180,200) then 0 else 1 end) as [OthersCallsPct]
            ,ISNULL(SUM(Answered),0)
			,ISNULL(SUM(Abandon),0)
			,SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END)
			,ISNULL(Sum(Inbound),0) 
			From #CallsDetails
			Group by Interval
					
 
			-------------------------------------------------------------------
			--Daily Totals End
			------------------------------------------------------------------


			--Weekly Totals Start			
			
			--=========================================================================

		   --PUT DIRECT CALLS and TRANSFERS FROM VIs into Temp Table -------------------

		    --=========================================================================
         

			Select * INTO #ccCallDataWTD
			From CallDataDWProd.dbo.cc_calldata_report CC
			Where
			(datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16)
			AND Handoff_Time >= @FromWTD and Handoff_Time < @EndDate
			AND Parent_SessionID IS NULL
			AND (vrs_cc_xfr = 0 OR vri_cc_xfr = 0)
			AND Incoming = 1

           --=========================================================================

		   -- Add Transfers from VIs to the temp table

	     	--=========================================================================

			INSERT INTO #ccCallDataWTD   
			Select * From CallDataDWProd.dbo.cc_calldata_report CC
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromWTD and Handoff_Time < @EndDate
			AND Parent_SessionID NOT IN (Select SessionID From CallDataDWProd.dbo.cc_calldata_report)
			AND (vrs_cc_xfr = 1 OR vri_cc_xfr = 1)

 
            Insert Into #Results
			Select			
			 @FromWTD as 'rptStart'
	        ,@StartDate as 'rptEnd'
			,'Weekly Totals' as 'DataType'
			,'Grand Total' as 'TotalType'
			,'1900-01-01'
			,SUM(CASE WHEN (AnswerTime+AbandonTime) <= 20 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) AS [SVL20sec]
			,SUM(CASE WHEN (AnswerTime+AbandonTime) <= 30 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) AS [SVL30sec]
			,SUM(CASE WHEN (AnswerTime+AbandonTime) <= 60 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) AS [SVL60sec]
			,SUM(CASE WHEN (AbandonTime) <= 5 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) AS [TBL5Secs]
			,SUM(CASE WHEN (AbandonTime) <= 10 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) AS [TBL10Secs]
			,SUM(CASE WHEN (AbandonTime) <= 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) AS [TBL20Secs]
			,SUM(CASE WHEN (AbandonTime) > 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) AS [TBLOver20Secs]

			,MAX(datediff(ms,timecallplaced,csOprAcceptTime))/60000.0 as [QueuedTime]
			,SUM(SessionTime)/60.0 / SUM(NULLIF(Inbound,0)) AS [AvgMinsPerCall]
			,STDEV(SessionTime/60.0) as [STDDev]
			,SUM(Answered)/cast(sum(Incoming) as decimal) as [AnsweredPct]
			,SUM(Incoming) AS [Incoming]
			,case when sum(Incoming) = 0 then 0 else
			 (SUM(case when CC.Call_Type IN(130,170) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END)) end as [SVPCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(85,115,120,35,55,185,190) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3CallsPct]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(case when CC.Call_Type IN(100,105,140,145,180,200) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3MobileCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(130,170,85,115,120,35,55,185,190,100,105,140,145,180,200) then 0 else 1 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [OthersCallsPct]
            ,ISNULL(SUM(Answered),0)
			,ISNULL(SUM(Abandon),0)
			,0
			,0
			 
			From #ccCallDataWTD CC
			Left JOIN aresVRS.dbo.Whitelabels WL
			ON CC.Branding = WL.ID 
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromWTD and Handoff_Time < @EndDate
			AND WL.CallerID NOT IN ('8557801091','8552090989','8442568990','8774674877') 
									
			DROP TABLE #ccCallDataWTD
			
			--=========================================================================

			-- DIRECT CALLS TOTAL TO CUSTOMER CARE

			--=========================================================================

			Insert Into #Results
			Select
			 @FromWTD as 'rptStart'
	        ,@StartDate as 'rptEnd'
			,'Weekly Totals' as 'DataType'
			,'Direct Call Total' as 'TotalType'	
			,'1900-01-01'	
			,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 20 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL20Secs]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 30 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL30Secs]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(CASE WHEN (AnswerTime+AbandonTime) <= 60 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL60Secs]
 
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 5 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL5Secs]
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 10 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL10Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) <= 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL20Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) > 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBLOver20Secs] 

			,MAX(datediff(ms,timecallplaced,csOprAcceptTime))/60000.0 as [QueuedTime]
			,SUM(SessionTime)/60.0 / SUM(NULLIF(Inbound,0)) AS [AvgMinsPerCall]
			,STDEV(SessionTime/60.0) as [STDDev]
			,SUM(Answered)/cast(sum(Incoming) as decimal) as [AnsweredPct]
			,SUM(Incoming) AS [Incoming]
			,case when sum(Incoming) = 0 then 0 else
			 (SUM(case when CC.Call_Type IN(130,170) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END)) end as [SVPCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(85,115,120,35,55,185,190) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3CallsPct]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(case when CC.Call_Type IN(100,105,140,145,180,200) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3MobileCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(130,170,85,115,120,35,55,185,190,100,105,140,145,180,200) then 0 else 1 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [OthersCallsPct]
			,ISNULL(SUM(Answered),0)
			,ISNULL(SUM(Abandon),0)
			,0
			,0

			From CallDataDWProd.dbo.cc_calldata_report CC
			Left JOIN aresVRS.dbo.Whitelabels WL
			ON CC.Branding = WL.ID 
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromWTD and Handoff_Time < @EndDate
			AND Parent_SessionID IS NULL
			AND (vrs_cc_xfr = 0 AND vri_cc_xfr = 0)
			AND Incoming = 1
			AND WL.CallerID NOT IN ('8557801091','8552090989','8442568990','8774674877') 

			--=========================================================================

			-- DIRECT CALLS GROUPED by Phone Number CUSTOMER CARE

			--=========================================================================
 

			Insert Into #Results
            Select 
			 @FromWTD as 'rptStart'
	        ,@StartDate as 'rptEnd'
			,'Weekly Totals' as 'DataType'
			,WL.CallerID as 'TotalType'	
			,'1900-01-01'	
			,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 20 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL20Secs]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 30 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL30Secs]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 60 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL60Secs]
 
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 5 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL5Secs]
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 10 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL10Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) <= 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL20Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) > 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBLOver20Secs]

			,MAX(datediff(ms,timecallplaced,csOprAcceptTime))/60000.0 as [QueuedTime]
			,SUM(SessionTime)/60.0 / SUM(NULLIF(Inbound,0)) AS [AvgMinsPerCall]
			,STDEV(SessionTime/60.0) as [STDDev]
			,SUM(Answered)/cast(sum(Incoming) as decimal) as [AnsweredPct]
			,SUM(Incoming) AS [Incoming]
			,case when sum(Incoming) = 0 then 0 else
			 (SUM(case when CC.Call_Type IN(130,170) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END)) end as [SVPCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(85,115,120,35,55,185,190) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3CallsPct]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(case when CC.Call_Type IN(100,105,140,145,180,200) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3MobileCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(130,170,85,115,120,35,55,185,190,100,105,140,145,180,200) then 0 else 1 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [OthersCallsPct]
			,ISNULL(SUM(Answered),0)
			,ISNULL(SUM(Abandon),0)
			,0
			,0

			From CallDataDWProd.dbo.cc_calldata_report CC
			Left JOIN aresVRS.dbo.Whitelabels WL
			ON CC.Branding = WL.ID 
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromWTD and Handoff_Time < @EndDate
			AND Parent_SessionID IS NULL
			AND (vrs_cc_xfr = 0 AND vri_cc_xfr = 0)
			AND Incoming = 1
			AND WL.CallerID NOT IN ('8557801091','8552090989','8442568990','8774674877')
			Group By WL.CallerID
			Order By Count(Distinct ConvoID) DESC 

			--=========================================================================

			-- TRANSFERS TO CUSTOMER CARE FROM Vis

			--=========================================================================
			
			Insert Into #Results 
			Select
			@FromWTD as 'rptStart'
	        ,@StartDate as 'rptEnd'
			,'Weekly Totals' as 'DataType'
			,'Transferred From VI' as 'TotalType'	
			,'1900-01-01'				
	    	,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 20 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL20Secs]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 30 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL30Secs]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 60 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL60Secs]
 
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 5 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL5Secs]
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 10 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL10Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) <= 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL20Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) > 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBLOver20Secs] 

			,MAX(datediff(ms,timecallplaced,csOprAcceptTime))/60000.0 as [QueuedTime]
			,SUM(SessionTime)/60.0 / SUM(NULLIF(Inbound,0)) AS [AvgMinsPerCall]
			,STDEV(SessionTime/60.0) as [STDDev]
			,SUM(Answered)/cast(sum(Incoming) as decimal) as [AnsweredPct]
			,SUM(Incoming) AS [Incoming]
			,case when sum(Incoming) = 0 then 0 else
			 (SUM(case when CC.Call_Type IN(130,170) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END)) end as [SVPCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(85,115,120,35,55,185,190) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3CallsPct]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(case when CC.Call_Type IN(100,105,140,145,180,200) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3MobileCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(130,170,85,115,120,35,55,185,190,100,105,140,145,180,200) then 0 else 1 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [OthersCallsPct] 
			,ISNULL(SUM(Answered),0)
			,ISNULL(SUM(Abandon),0)
			,0
			,0

			From CallDataDWProd.dbo.cc_calldata_report CC
			Left JOIN aresVRS.dbo.Whitelabels WL
			ON CC.Branding = WL.ID 
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromWTD and Handoff_Time < @EndDate
			AND Parent_SessionID NOT IN (Select SessionID From CallDataDWProd.dbo.cc_calldata_report)
			AND (vrs_cc_xfr = 1 OR vri_cc_xfr = 1)
			AND WL.CallerID NOT IN ('8557801091','8552090989','8442568990','8774674877') 

			--=========================================================================

			-- WARM TRANSFERS WITHIN CUSTOMER CARE - USE DISTINCT CONVOID for Incoming

			--=========================================================================

			insert into #Results
            Select
			@FromWTD as 'rptStart'
	        ,@StartDate as 'rptEnd'
			,'Weekly Totals' as 'DataType'
			,'Warm Transfers' as 'TotalType'
			,'1900-01-01'		 
			,NULL AS [SVL 20 sec]
			,NULL AS [SVL 30 sec]
			,NULL AS [SVL 60 sec]
			,NULL AS [Under 5 sec]
			,NULL AS [Under 10 sec]
			,NULL AS [Under 20 sec]
			,NULL AS [Over 20 sec]
			,NULL as [Longest Wait]
			,SUM(SessionTime)/60.0 / Count(Distinct ConvoID) AS [AvgMinsPerCall]
			,STDEV(SessionTime/60.0) as [STDDev]
			,NULL as [AnsweredPct]
			,Count(Distinct ConvoID) AS [Incoming]
			,CASE WHEN Count(Distinct ConvoID)=0 THEN 0 ELSE SUM(case when Call_Type IN(130,170) then 1 else 0 end)/(Count(Distinct ConvoID)*1.0) END as [SVPCallsPct]
			,CASE WHEN Count(Distinct ConvoID)=0 THEN 0 ELSE SUM(case when Call_Type IN(85,115,120,35,55,185,190) then 1 else 0 end)/(Count(Distinct ConvoID)*1.0) END as [P3CallsPct]
			,CASE WHEN Count(Distinct ConvoID)=0 THEN 0 ELSE SUM(case when Call_Type IN(100,105,140,145,180,200) then 1 else 0 end)/(Count(Distinct ConvoID)*1.0) END as [P3MobileCallsPct]
			,CASE WHEN Count(Distinct ConvoID)=0 THEN 0 ELSE SUM(case when Call_Type IN(130,170,85,115,120,35,55,185,190,100,105,140,145,180,200) then 0 else 1 end)/(Count(Distinct ConvoID)*1.0) END as [OthersCallsPct]
			,NULL [Answered]
			,NULL [Abandon]
			,0
			,0

			From CallDataDWProd.dbo.cc_calldata_report CC
			Left JOIN aresVRS.dbo.Whitelabels WL
			ON CC.Branding = WL.ID 
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromWTD and Handoff_Time < @EndDate
			AND
			(
			Parent_SessionID IN (Select SessionID From CallDataDWProd.dbo.cc_calldata_report)
			OR
			Parent_SessionID LIKE 'OBCC%'
			) 
			AND WL.CallerID NOT IN ('8557801091','8552090989','8442568990','8774674877') 

			--=========================================================================

			--Weekly Totals End

			--=========================================================================				

			--Monthly Totals Start

			--========================================================================= 

            --=========================================================================

		    --PUT DIRECT CALLS and TRANSFERS FROM VIs into Temp Table

		    --=========================================================================
         

			Select * INTO #tempccCallData 
			From CallDataDWProd.dbo.cc_calldata_report CC
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromMTD and Handoff_Time < @MTDEndDate
			AND Parent_SessionID IS NULL
			AND (vrs_cc_xfr = 0 OR vri_cc_xfr = 0)
			AND Incoming = 1

           --=========================================================================

		   -- Add Transfers from VIs to the temp table

	     	--=========================================================================

			INSERT INTO #tempccCallData  
			Select * From CallDataDWProd.dbo.cc_calldata_report CC
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromMTD and Handoff_Time < @MTDEndDate
			AND Parent_SessionID NOT IN (Select SessionID From CallDataDWProd.dbo.cc_calldata_report)
			AND (vrs_cc_xfr = 1 OR vri_cc_xfr = 1)

 
            Insert Into #Results
			Select			
			 @FromMTD as 'rptStart'
	        ,@Startdate as 'rptEnd'
			,'Monthly Totals' as 'DataType'
			,'Grand Total' as 'TotalType'
			,'1900-01-01'
			,SUM(CASE WHEN (AnswerTime+AbandonTime) <= 20 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) AS [SVL20sec]
			,SUM(CASE WHEN (AnswerTime+AbandonTime) <= 30 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) AS [SVL30sec]
			,SUM(CASE WHEN (AnswerTime+AbandonTime) <= 60 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) AS [SVL60sec]
			,SUM(CASE WHEN (AbandonTime) <= 5 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) AS [TBL5Secs]
			,SUM(CASE WHEN (AbandonTime) <= 10 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) AS [TBL10Secs]
			,SUM(CASE WHEN (AbandonTime) <= 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) AS [TBL20Secs]
			,SUM(CASE WHEN (AbandonTime) > 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) AS [TBLOver20Secs]

			,MAX(datediff(ms,timecallplaced,csOprAcceptTime))/60000.0 as [QueuedTime]
			,SUM(SessionTime)/60.0 / SUM(NULLIF(Inbound,0)) AS [AvgMinsPerCall]
			,STDEV(SessionTime/60.0) as [STDDev]
			,SUM(Answered)/cast(sum(Incoming) as decimal) as [AnsweredPct]
			,SUM(Incoming) AS [Incoming]
			,case when sum(Incoming) = 0 then 0 else
			 (SUM(case when CC.Call_Type IN(130,170) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END)) end as [SVPCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(85,115,120,35,55,185,190) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3CallsPct]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(case when CC.Call_Type IN(100,105,140,145,180,200) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3MobileCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(130,170,85,115,120,35,55,185,190,100,105,140,145,180,200) then 0 else 1 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [OthersCallsPct]
			,ISNULL(SUM(Answered),0)
			,ISNULL(SUM(Abandon),0)
			,0
			,0

			From #tempccCallData CC
			Left JOIN aresVRS.dbo.Whitelabels WL
			ON CC.Branding = WL.ID 
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromMTD and Handoff_Time < @MTDEndDate
			AND WL.CallerID NOT IN ('8557801091','8552090989','8442568990','8774674877') 
									
			DROP TABLE #tempccCallData

			--=========================================================================

			-- DIRECT CALLS TOTAL TO CUSTOMER CARE

			--=========================================================================

			Insert Into #Results
			Select
			 @FromMTD as 'rptStart'
	        ,@Startdate as 'rptEnd'
			,'Monthly Totals' as 'DataType'
			,'Direct Call Total' as 'TotalType'		
			,'1900-01-01'
			,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 20 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL20Secs]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 30 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL30Secs]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(CASE WHEN (AnswerTime+AbandonTime) <= 60 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL60Secs]
 
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 5 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL5Secs]
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 10 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL10Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) <= 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL20Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) > 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBLOver20Secs] 

			,MAX(datediff(ms,timecallplaced,csOprAcceptTime))/60000.0 as [QueuedTime]
			,SUM(SessionTime)/60.0 / SUM(NULLIF(Inbound,0)) AS [AvgMinsPerCall]
			,STDEV(SessionTime/60.0) as [STDDev]
			,SUM(Answered)/cast(sum(Incoming) as decimal) as [AnsweredPct]
			,SUM(Incoming) AS [Incoming]
			,case when sum(Incoming) = 0 then 0 else
			 (SUM(case when CC.Call_Type IN(130,170) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END)) end as [SVPCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(85,115,120,35,55,185,190) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3CallsPct]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(case when CC.Call_Type IN(100,105,140,145,180,200) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3MobileCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(130,170,85,115,120,35,55,185,190,100,105,140,145,180,200) then 0 else 1 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [OthersCallsPct]
			,ISNULL(SUM(Answered),0)
			,ISNULL(SUM(Abandon),0)
			,0
			,0

			From CallDataDWProd.dbo.cc_calldata_report CC
			Left JOIN aresVRS.dbo.Whitelabels WL
			ON CC.Branding = WL.ID 
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromMTD and Handoff_Time < @MTDEndDate
			AND Parent_SessionID IS NULL
			AND (vrs_cc_xfr = 0 AND vri_cc_xfr = 0)
			AND Incoming = 1
			AND WL.CallerID NOT IN ('8557801091','8552090989','8442568990','8774674877') 

			--=========================================================================

			-- DIRECT CALLS GROUPED by Phone Number CUSTOMER CARE

			--=========================================================================
 

			Insert Into #Results
            Select 
			 @FromMTD as 'rptStart'
	        ,@Startdate as 'rptEnd'
			,'Monthly Totals' as 'DataType'
			,WL.CallerID as 'TotalType'	
			,'1900-01-01'	
			,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 20 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL20Secs]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 30 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL30Secs]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 60 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL60Secs]
 
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 5 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL5Secs]
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 10 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL10Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) <= 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL20Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) > 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBLOver20Secs]

			,MAX(datediff(ms,timecallplaced,csOprAcceptTime))/60000.0 as [QueuedTime]
			,SUM(SessionTime)/60.0 / SUM(NULLIF(Inbound,0)) AS [AvgMinsPerCall]
			,STDEV(SessionTime/60.0) as [STDDev]
			,SUM(Answered)/cast(sum(Incoming) as decimal) as [AnsweredPct]
			,SUM(Incoming) AS [Incoming]
			,case when sum(Incoming) = 0 then 0 else
			 (SUM(case when CC.Call_Type IN(130,170) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END)) end as [SVPCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(85,115,120,35,55,185,190) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3CallsPct]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(case when CC.Call_Type IN(100,105,140,145,180,200) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3MobileCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(130,170,85,115,120,35,55,185,190,100,105,140,145,180,200) then 0 else 1 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [OthersCallsPct]
			,ISNULL(SUM(Answered),0)
			,ISNULL(SUM(Abandon),0)
			,0
			,0

			From CallDataDWProd.dbo.cc_calldata_report CC
			Left JOIN aresVRS.dbo.Whitelabels WL
			ON CC.Branding = WL.ID 
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromMTD and Handoff_Time < @MTDEndDate
			AND Parent_SessionID IS NULL
			AND (vrs_cc_xfr = 0 AND vri_cc_xfr = 0)
			AND Incoming = 1
			AND WL.CallerID NOT IN ('8557801091','8552090989','8442568990','8774674877')
			Group By WL.CallerID
			Order By Count(Distinct ConvoID) DESC 

			--=========================================================================

			-- TRANSFERS TO CUSTOMER CARE FROM Vis

			--=========================================================================
			
			Insert Into #Results 
			Select
			 @FromMTD as 'rptStart'
	        ,@Startdate as 'rptEnd'
			,'Monthly Totals' as 'DataType'
			,'Transferred From VI' as 'TotalType'
			,'1900-01-01'					
	    	,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 20 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL20Secs]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 30 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL30Secs]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(CASE WHEN (AnswerTime + AbandonTime) <= 60 and Incoming = 1 THEN 1.0 ELSE 0 END)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end AS [SL60Secs]
 
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 5 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL5Secs]
			,case when sum(Abandon) = 0 then 0 else 
			 SUM(CASE WHEN (AbandonTime) <= 10 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL10Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) <= 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBL20Secs]
			,case when sum(Abandon) = 0 then 0 else 
			SUM(CASE WHEN (AbandonTime) > 20 and Abandon = 1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(CASE WHEN Abandon = 1 THEN 1.0 ELSE 0.0 END),0) end AS [TBLOver20Secs] 

			,MAX(datediff(ms,timecallplaced,csOprAcceptTime))/60000.0 as [QueuedTime]
			,SUM(SessionTime)/60.0 / SUM(NULLIF(Inbound,0)) AS [AvgMinsPerCall]
			,STDEV(SessionTime/60.0) as [STDDev]
			,SUM(Answered)/cast(sum(Incoming) as decimal) as [AnsweredPct]
			,SUM(Incoming) AS [Incoming]
			,case when sum(Incoming) = 0 then 0 else
			 (SUM(case when CC.Call_Type IN(130,170) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END)) end as [SVPCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(85,115,120,35,55,185,190) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3CallsPct]
			,case when sum(Incoming) = 0 then 0 else 
			 SUM(case when CC.Call_Type IN(100,105,140,145,180,200) then 1 else 0 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [P3MobileCallsPct]
			,case when sum(Incoming) = 0 then 0 else
			 SUM(case when CC.Call_Type IN(130,170,85,115,120,35,55,185,190,100,105,140,145,180,200) then 0 else 1 end)/SUM(CASE WHEN Incoming = 1 THEN 1.0 ELSE 0.0 END) end as [OthersCallsPct] 
			,ISNULL(SUM(Answered),0)
			,ISNULL(SUM(Abandon),0)
			,0
			,0

			From CallDataDWProd.dbo.cc_calldata_report CC
			Left JOIN aresVRS.dbo.Whitelabels WL
			ON CC.Branding = WL.ID 
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromMTD and Handoff_Time < @MTDEndDate
			AND Parent_SessionID NOT IN (Select SessionID From CallDataDWProd.dbo.cc_calldata_report)
			AND (vrs_cc_xfr = 1 OR vri_cc_xfr = 1)
			AND WL.CallerID NOT IN ('8557801091','8552090989','8442568990','8774674877') 

			--=========================================================================

			-- WARM TRANSFERS WITHIN CUSTOMER CARE - USE DISTINCT CONVOID for Incoming

			--=========================================================================

			insert into #Results
            Select
			  @FromMTD as 'rptStart'
	        ,@Startdate as 'rptEnd'
			,'Monthly Totals' as 'DataType'
			,'Warm Transfers' as 'TotalType'
			,'1900-01-01'		 
			,NULL AS [SVL 20 sec]
			,NULL AS [SVL 30 sec]
			,NULL AS [SVL 60 sec]
			,NULL AS [Under 5 sec]
			,NULL AS [Under 10 sec]
			,NULL AS [Under 20 sec]
			,NULL AS [Over 20 sec]
			,NULL as [Longest Wait]
			,SUM(SessionTime)/60.0 / Count(Distinct ConvoID) AS [AvgMinsPerCall]
			,STDEV(SessionTime/60.0) as [STDDev]
			,NULL as [AnsweredPct]
			,Count(Distinct ConvoID) AS [Incoming]
			,CASE WHEN Count(Distinct ConvoID)=0 THEN 0 ELSE SUM(case when Call_Type IN(130,170) then 1 else 0 end)/(Count(Distinct ConvoID)*1.0) END as [SVPCallsPct]
			,CASE WHEN Count(Distinct ConvoID)=0 THEN 0 ELSE SUM(case when Call_Type IN(85,115,120,35,55,185,190) then 1 else 0 end)/(Count(Distinct ConvoID)*1.0) END as [P3CallsPct]
			,CASE WHEN Count(Distinct ConvoID)=0 THEN 0 ELSE SUM(case when Call_Type IN(100,105,140,145,180,200) then 1 else 0 end)/(Count(Distinct ConvoID)*1.0) END as [P3MobileCallsPct]
			,CASE WHEN Count(Distinct ConvoID)=0 THEN 0 ELSE SUM(case when Call_Type IN(130,170,85,115,120,35,55,185,190,100,105,140,145,180,200) then 0 else 1 end)/(Count(Distinct ConvoID)*1.0) END as [OthersCallsPct]
			,NULL [Answered]
			,NULL [Abandon]
			,0
			,0

			From CallDataDWProd.dbo.cc_calldata_report CC
			Left JOIN aresVRS.dbo.Whitelabels WL
			ON CC.Branding = WL.ID 
			Where
			(
			datepart(dw,Handoff_Time) between 2 and 6 and datepart(hh,Handoff_Time) >= 5 and datepart(hh,Handoff_Time) < 20
			OR
			datepart(dw,Handoff_Time) in (1,7) and datepart(hh,Handoff_Time) >= 7 and datepart(hh,Handoff_Time) < 16
			)
			AND Handoff_Time >= @FromMTD and Handoff_Time < @MTDEndDate
			AND
			(
			Parent_SessionID IN (Select SessionID From CallDataDWProd.dbo.cc_calldata_report)
			OR
			Parent_SessionID LIKE 'OBCC%'
			)
			AND WL.CallerID NOT IN ('8557801091','8552090989','8442568990','8774674877') 

			--=========================================================================

			--Monthly Totals End

			--=========================================================================


			Select * from #Results
			


			


			