USE [Reports]
GO

/****** Object:  StoredProcedure [dbo].[p_rpt2012NCD_GenerateReport]    Script Date: 11/18/14 5:35:39 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Stored Procedure Name:	p_rpt2012NCD_GenerateReport
-- Data Base/Tables:            Reports/vrs_calldata_report
-- Functions:                   satVRS/fn_rpt2012NCD_priorMonth
-- SSRS Report:                 Test_2012(NCD) - Monthly CSS Report
-- Temporary Tables:            #UserScore,#TerpScore,#OutBoundCalls,#TerpUserScore,
-- History:                        
--                              11/10/2014   Updated the table information 'satVRS..rptCallDetail' to 'Reports..vrs_calldata_Report' 
--                              11/10/2014   Used a function 'fn_rpt2012NCD_priorMonth' for getting previous month data
-- =============================================



CREATE PROCEDURE [dbo].[p_rpt2012NCD_GenerateReport]
@EndDate datetime
AS 
 



--###########################################################################--

----------------------------USER SCORE---------------------------------------

--###########################################################################--  
        set @EndDate=DateAdd(month,1,@EndDate)

        
		declare @UserScoreStart date;set @UserScoreStart= dbo.fn_rpt2012NCD_priorMonth(0,'start',@EndDate)
		declare @UserScoreEnd date;set @UserScoreEnd= dbo.fn_rpt2012NCD_priorMonth(0,'end',@EndDate)

		declare @PriorMo1Start date;set @PriorMo1Start= dbo.fn_rpt2012NCD_priorMonth(1,'start',@EndDate)
		declare @PriorMo1End date;set @PriorMo1End= dbo.fn_rpt2012NCD_priorMonth(1,'end',@EndDate)

		declare @PriorMo2Start date;set @PriorMo2Start= dbo.fn_rpt2012NCD_priorMonth(2,'start',@EndDate)
		declare @PriorMo2End date;set @PriorMo2End= dbo.fn_rpt2012NCD_priorMonth(2,'end',@EndDate)	
		
						
			Create table #UserScore
			(
			[UserID] int,
			[prior month 100] int,
			[prior month 200] int,
			[UserScore] int
			)

			
--####################### Start Create index on column UserID #####################################--

         create index ix_UserScore on #UserScore([UserID])

--####################### End Create index on column UserID #######################################-- 

			

			Insert into #UserScore
			Select
			UserID_Caller
			,COUNT(case when timeWait between @PriorMo1Start and @PriorMo1End then UserID_Caller end) as [Prior Month 1]
			,COUNT(case when timeWait between @PriorMo2Start and @PriorMo2End then UserID_Caller end) as [Prior Month 2]
			,(CASE when (COUNT(case when timeWait between @PriorMo2Start and @PriorMo2End then UserID_Caller end)) = 0 then 0
			when ((CONVERT(DECIMAL(15,10),COUNT(case when timeWait between @PriorMo1Start and @PriorMo1End then UserID_Caller end))
			-(CONVERT(DECIMAL(15,10),COUNT(case when timeWait between @PriorMo2Start and @PriorMo2End then UserID_Caller end))))
			/(CONVERT(DECIMAL(15,10),COUNT(case when timeWait between @PriorMo2Start and @PriorMo2End then UserID_Caller end)))) >= -0.05 then 3 else 2 end) as [UserScore]
			from Reports..vrs_calldata_report 
			where timeWait between @UserScoreStart and @UserScoreEnd
			and Outbound = 1
			and isReport = 1
			and UserID_Caller > 1
			Group by UserID_Caller
			Order by UserID_Caller ASC 
 
 
           --Select * from #UserScore
　
 
--################################################################################

--------------------------TERP SCORE----------------------------------------------

--################################################################################
 

				declare @TerpScoreStart date; set @TerpScoreStart= dbo.fn_rpt2012NCD_priorMonth(0,'start',@EndDate)
				declare @TerpScoreEnd date; set @TerpScoreEnd= dbo.fn_rpt2012NCD_priorMonth(0,'end',@EndDate)

				--SET @TerpScoreEnd=DATEADD(DAY,-1,@TerpScoreEnd)
				

				Create Table #TerpScore
				(
				AgentID int,
				UserID int,
				TerpScore int
				)

--####################### Start Create index on column UserID,AgentID #####################################--

         create index ix_TerpScore on #TerpScore([UserID],[AgentID])

--####################### End Create index on column UserID,AgentID #######################################-- 
				

				Insert into #Terpscore 
				select 
				OperatorID, UserID_Caller, b.UserScore
				from Reports..vrs_calldata_report  as a
				Left Join #UserScore as b
				ON a.UserID_Caller = b.UserID
				where timeWait between @TerpScoreStart and @TerpScoreEnd
				and Outbound = 1
				and isReport = 1
				and UserID_Caller > 1
				Group by UserID_Caller, OperatorID, b.UserScore
				Order by OperatorID, UserID_Caller
 
--Select * from #TerpScore
 
 
--################################################################################

--------------------------Prior Month Outbound Calls------------------------------

--################################################################################

  
--declare @StartDateSummary date; set @StartDateSummary = '04/01/2014 00:00'

--declare @EndDateSummary date; set @EndDateSummary = '06/01/2014 00:00'


			Create Table #OutBoundCalls
			(
			AgentID int,
			[OB calls] int
			)

			--create index ix_OutBoundCalls on #OutBoundCalls([OB calls],[AgentID])

			Insert into #OutBoundCalls 
			select 
			OperatorID 
			,COUNT(case when timeWait between @PriorMo1Start and @PriorMo1End then UserID_Caller end) as [# of OB Calls CUrrent Month]
			from Reports..vrs_calldata_report 
			where timeWait between @PriorMo1Start and @PriorMo1End
			and Outbound = 1
			and isReport = 1
			and UserID_Caller > 1
			Group by OperatorID
			Order by OperatorID ASC 
 
--Select * from #OutBoundCalls
--where #OutBoundCalls.AgentID <> 8021

 
--################################################################################

--------------------------TERP USER SCORE-----------------------------------------

--################################################################################
 

			Create Table #TerpUserScore
			(
			AgentID int,
			OutboundCalls int,
			TerpUserScore int,
			PerfectScore int,
			VIScore FLOAT
			)　 

			--create index ix_TerpUserScore on #TerpUserScore([AgentID])

			Insert into #TerpUserScore 
			select 
			c.AgentID, d.[OB calls]
			,SUM(c.TerpScore)
			,((COUNT(case when c.TerpScore = 2 then 2 end) + COUNT(case when c.TerpScore = 3 then 3 end))*3)
			,CONVERT(DECIMAL(15,10),(CONVERT(DECIMAL(15,10),SUM(c.TerpScore)))/ISNULL(NULLIF(((CONVERT(DECIMAL(15,10), COUNT(case when c.TerpScore = 2 then 2 end)) + CONVERT(DECIMAL(15,10), COUNT(case when c.TerpScore = 3 then 3 end)))*3),0),1))
			from #terpscore as c
			Left Join #OutBoundCalls as d
			ON c.AgentID = d.AgentID
			Group by c.AgentID, d.[OB calls]
			Order by c.AgentID

	   Select dbo.fn_rpt2012NCD_priorMonth(2,'start',@EndDate) StartDate,@EndDate EndDate,AgentID,OutboundCalls,TerpUserScore,PerfectScore,VIScore 
	   from #TerpUserScore where OutboundCalls is not NULL order by AgentID
	 
Drop table #OutBoundCalls
Drop table #TerpScore
Drop Table #UserScore
Drop table #TerpUserScore

GO
