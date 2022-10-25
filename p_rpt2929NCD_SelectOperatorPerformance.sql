USE [Reports]
GO
/****** Object:  StoredProcedure [dbo].[p_rpt2929NCD_SelectOperatorPerformance]    Script Date: 8/31/2014 6:37:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
			-- Stored Procedure Name:	p_rpt2929NCD_SelectOperatorPerformance
			-- SSRS Report:                 TEST_2929(NCD)-Ops Management Report
			-- [Server].Database & Tables:  [10.0.25.50].Reports			
			--                              - SS_EmployeeDataList	
			--                              [10.0.25.50].satVRS			
			--                              - rptOprSchedSource,			
			--                              - rptOprSessionHistory
			--                              [10.0.25.50].CallDataDWProd
			--                              - vrs_calldata_split30
			--                              - vri_calldata_split30  
			--                              [10.0.25.50].CallDataDWConvo
			--                              - vrs_calldata_split30			                       
			-- Functions:                   
			--                              
			-- Temporary Tables:            #OperatorSessions,#SessionSummary,#vrsvri_calldata_split,#CallData,#OprLaborSchedSource,#OprLoginSession,#SS_EmployeeData
			-- Permanent Temporary Tables:  satVRS/temp_rpt2929_Results 
			-- Historical Tracking:                     
			--                              10/10/2014 Added “Year Tenure” Column
			--                              10/10/2014 Added “Teaming Min” Column
			--                              10/10/2014 Added “Teaming Min Pct” Column
			--                              10/11/2014 Added “Blended LogIn expectation” Column
			--                              10/11/2014 Add column “Ratio, Login To Labor Time”
			--                              10/11/2014 Add column “Ratio, Ratio,Login To Labor Time” 
			--                              10/11/2014 Update column to “Convo” where “Billable” exists  
			--                              10/12/2014 Updated the table information 'satVRS..rptCallDetail' to 'Reports..vrs_calldata_Report'   
			--                              12/19/2014 Add Columns For Saturday 12am to 12am
			--                                Labor Hour, Convo Mins,Convo Min Pct,Login Mins,Logn Min Pct			
			--                              12/19/2014 Add Columns For Sunday 12am to 12am
			--                                Labor Hour,Convo Mins,Convo Min Pct,Login Mins,Logn Min Pct
			--                              01/08/2015 Add Columns For 12am to 6am and 6pm to 12am
			--                                Labor Hour,Convo Mins,Convo Min Pct,Login Mins,Logn Min Pct
			--                              01/28/2015 Added columns Teamed Minute and Break Minutes(Not available mins)
			--                              from the table information aresVRS..OperatorSessions,satVRS..OperatorSessions 
			--                              02/26/2015 Added Performance Columns 
			--                                “BillablePerfMins12to12a”,“SessionPerfMins12to12a”,“BillPerfMins12am6am6pm12am”,“BillMinsPerfToNoon”,“BillMinsPerfNoonTo”,“BillSatPerf12ato12a”,“BillMinsPerfSat”,“BillSunPerf12ato12a”,“BillMinsPerfSun” 
			--                                “VRSLaborPerfMins12to12a”,“VRSLaborPerfMins12am6am6pm12am”,“VRSLaborMinsPerfToNoon”,“VRSLaborMinsPerfNoonTo” ,“VRSLaborMinsPerfSat12aTo12a” ,“VRSLaborMinsPerfSat6aTo6p”,“VRSLaborMinsPerfSun12aTo12a”,“VRSLaborMinsPerfSun6aTo6p” 
			--                                “SessionPerfMins12to12a”
			--                                “PerfLoginMins”,“PerfAwayMins”,"PerfReadyMins"
			--                              03/23/2015 Added Columns  ,SessionMins12am6am6pm12am ,SessionMins6amToNoon ,SessionMins12pmTo6pm ,SessionMinsSat12to12 ,SessionMinsSat6amTo6pm ,SessionMinsSun12amTo12am ,SessionMinsSun6amTo6pm 
			--                             Added table information vrs_calldata_report and vri_calldata_report  for columns "ConvoMins" and "SessionMins"
			--                             Added function f_rpt2929_vrsvri_calldata_split
			--                             10/28/2015 Move all databases IP to [10.0.25.50]
			-- =============================================		
			
			/*	 
			 exec p_rpt2929NCD_SelectOperatorPerformance
			  @StartDate = '12/01/2015'
			  ,@endDate = '12/02/2015'
			  ,@RunForMTD = 1
			  ,@RunForNDaysAgo = 1
			*/	



			ALTER PROCEDURE [dbo].[p_rpt2929NCD_SelectOperatorPerformance]
					@StartDate	DATETIME = NULL,
					@EndDate	DATETIME = NULL,
					@RunForMTD  bit      = 0,   -- 'MTD'=Month To Date
					@RunForNDaysAgo INT  = 1    -- Number of days ago to run report for.
			AS

	                    SET NOCOUNT ON;
						SET ANSI_WARNINGS OFF;
						SET DEADLOCK_PRIORITY NORMAL;

						if @StartDate is null
						begin
						  if @RunForMTD = 1
						  begin
							set @endDate = cast(dateadd(d,-1,getdate()) as date)
							set @StartDate = Reports.dbo.f_GetBeginningOfMonthDate(@endDate)							
						  end
						  else
						  begin
							set @StartDate = cast(dateadd(d,-1*isnull(@RunForNDaysAgo,1),getdate()) as date)
							set @endDate = @StartDate							
						  end
						end						

	                    					     
						 --Move the startdate back one day in order to capture any calls that may have started the day before
						 --We will run the report for the wider date range but only update results from the startdate requested 
						 --DECLARE @StartDate_ForResults datetime = @StartDate
						 --SET @StartDate = dateadd(d,-1,@StartDate)  
						                    						
						Set @enddate = DATEADD(dd,1,@enddate)
						--===============================================================================================
						--                        Teaming Mins and Break Mins Calculation Start
						--===============================================================================================

						
						CREATE TABLE #OperatorSessions
						(
						Date Datetime,
						CallCenterCode VARCHAR(20),
						OperatorID INT,
						BreakMins DECIMAL(17,4),
						TeamedMins DECIMAL(17,4),
						AvailableMins DECIMAL(17,4)
						)	
						INSERT INTO #OperatorSessions				 
                        SELECT	
							CAST(CONVERT (varchar(10), Date, 101) + ' 00:00:000' AS DATETIME),	
							CallCenterCode,
							OperatorID,		
							Sum(Case When EntryType = 2 Then DATEDIFF(ss, AdjStartTime, AdjEndTime)/60.0 ELSE 0 END) AS 'BreakMins',
							Sum(Case When EntryType = 6 Then DATEDIFF(ss, AdjStartTime, AdjEndTime)/60.0 ELSE 0 END) AS 'TeamedMins',
							Sum(Case When EntryType IN (1,6) Then DATEDIFF(ss, AdjStartTime, AdjEndTime)/60.0 ELSE 0 END) AS 'AvailableMins'							
						FROM satVRS..rptOprSessionHistory WITH (NOLOCK)
						WHERE Date BETWEEN @startdate AND @enddate					
						Group By Date
						,OperatorID
						,CallCenterCode
												

					      CREATE TABLE #SessionSummary
							(
							Handoff_Date DATETIME,
							CallCenterCode VARCHAR(4),
							OperatorID INT,
							BreakMins DECIMAL(17,4),
							TeamedMins DECIMAL(17,4),
							AvailableMins DECIMAL(17,4)
							)

						  INSERT INTO #SessionSummary
							SELECT
							Handoff_Date=Date,
							CallCenterCode,
							OperatorID,
							SUM(BreakMins),
							SUM(TeamedMins),
							SUM(AvailableMins)
							FROM  #OperatorSessions
							GROUP BY Date,CallCenterCode,OperatorID
							
                        			--===============================================================================================
						--                        Teaming Mins and Break Mins Calculation End
						--===============================================================================================



						--===============================================================================================
						--                        Fetch VRS and VRI Data --Start
						--===============================================================================================

						CREATE TABLE #vrsvri_calldata_split
						(
						 CallCenterCode VARCHAR(5),
						 OperatorID INT,
						 Handoff_Date DATETIME,
						 AllDays_12to12_ConvoTime_Mins DECIMAL(17,4),          
					     AllDays_12to12_SessionTime_Mins DECIMAL(17,4),       
					     MtoF_NonCore_ConvoTime_Mins DECIMAL(17,4),  
					     MtoF_NonCore_SessionTime_Mins DECIMAL(17,4),
					     MtoF_6to12_ConvoTime_Mins DECIMAL(17,4),    
					     MtoF_6to12_SessionTime_Mins DECIMAL(17,4),        
  					     MtoF_12to6_ConvoTime_Mins DECIMAL(17,4),      
					     MtoF_12to6_SessionTime_Mins DECIMAL(17,4),
					     Sat_12to12_ConvoTime_Mins DECIMAL(17,4),
					     Sat_12to12_SessionTime_Mins DECIMAL(17,4),
					     Sat_6to6_ConvoTime_Mins DECIMAL(17,4),
					     Sat_6to6_SessionTime_Mins DECIMAL(17,4), 
					     Sun_12to12_ConvoTime_Mins DECIMAL(17,4),
					     Sun_12to12_SessionTime_Mins DECIMAL(17,4),
					     Sun_6to6_ConvoTime_Mins DECIMAL(17,4),
					     Sun_6to6_SessionTime_Mins DECIMAL(17,4),
						 MtoF_6to6_ConvoTime_Mins as isnull(MtoF_6to12_ConvoTime_Mins,0) + isnull(MtoF_12to6_ConvoTime_Mins,0),
					     MtoF_6to6_SessionTime_Mins as isnull(MtoF_6to12_SessionTime_Mins,0) + isnull(MtoF_12to6_SessionTime_Mins,0) 
						)

						--Create the Index on table #vrsvri_calldata_split
						CREATE INDEX ix_vrsvri_calldata_split ON #vrsvri_calldata_split(CallCenterCode,OperatorID,Handoff_Date)

						INSERT INTO #vrsvri_calldata_split
					     SELECT
					     CallCenterCode = LocationCode,
					     OperatorID,
					     Handoff_Date_adj, 
					     AllDays_12to12_ConvoTime_Mins          = sum(convotime)/60.0,
					     AllDays_12to12_SessionTime_Mins        = sum(sessiontime)/60.0, 
					     MtoF_NonCore_ConvoTime_Mins            = sum(iif(isWeekdayHours=1 and isNonCoreHours=1, convotime, 0))/60.0,
					     MtoF_NonCore_SessionTime_Mins          = sum(iif(isWeekdayHours=1 and isNonCoreHours=1, sessiontime, 0))/60.0, 
					     MtoF_6to12_ConvoTime_Mins              = sum(iif(isWeekdayHours=1 and is6to12Hours=1, convotime, 0))/60.0,
					     MtoF_6to12_SessionTime_Mins            = sum(iif(isWeekdayHours=1 and is6to12Hours=1, sessiontime, 0))/60.0, 
					     MtoF_12to6_ConvoTime_Mins              = sum(iif(isWeekdayHours=1 and is12to18Hours=1, convotime, 0))/60.0,
					     MtoF_12to6_SessionTime_Mins            = sum(iif(isWeekdayHours=1 and is12to18Hours=1, sessiontime, 0))/60.0, 
					     Sat_12to12_ConvoTime_Mins              = sum(iif(isSaturdayHours=1, convotime, 0))/60.0,
					     Sat_12to12_SessionTime_Mins            = sum(iif(isSaturdayHours=1, sessiontime, 0))/60.0, 
					     Sat_6to6_ConvoTime_Mins                = sum(iif(isSaturdayHours=1 and isCoreHours=1, convotime, 0))/60.0,
					     Sat_6to6_SessionTime_Mins              = sum(iif(isSaturdayHours=1 and isCoreHours=1, sessiontime, 0))/60.0, 
					     Sun_12to12_ConvoTime_Mins              = sum(iif(isSundayHours=1, convotime, 0))/60.0,
					     Sun_12to12_SessionTime_Mins            = sum(iif(isSundayHours=1, sessiontime, 0))/60.0, 
					     Sun_6to6_ConvoTime_Mins                = sum(iif(isSundayHours=1 and isCoreHours=1, convotime, 0))/60.0,
					     Sun_6to6_SessionTime_Mins              = sum(iif(isSundayHours=1 and isCoreHours=1, sessiontime, 0))/60.0						
 
					   FROM Reports.dbo.v_vrs_calldata_split30_all
					   WHERE @StartDate <= Handoff_time_adj and Handoff_time_adj < @EndDate
					    AND OperatorID IS NOT NULL
					   GROUP BY locationcode, operatorid, Handoff_Date_adj
					   
					--===============================================================================================
						--                        Fetch VRS and VRI Data --Start
					--===============================================================================================

					--===============================================================================================
						--Merging two temp table '#vrsvri_calldata_split' and '#SessionSummary' in to one table '#CallData'--Start 
					--===============================================================================================

					    CREATE TABLE #CallData
						(
						 CallCenterCode VARCHAR(5),
						 OperatorID INT,
						 Handoff_Date DATETIME,
						 BreakMins DECIMAL(17,4),
						 TeamedMins DECIMAL(17,4),
						 AvailableMins DECIMAL(17,4),
						 AllDays_12to12_ConvoTime_Mins DECIMAL(17,4),          
					     AllDays_12to12_SessionTime_Mins DECIMAL(17,4),       
					     MtoF_NonCore_ConvoTime_Mins DECIMAL(17,4),  
					     MtoF_NonCore_SessionTime_Mins DECIMAL(17,4),
					     MtoF_6to12_ConvoTime_Mins DECIMAL(17,4),    
					     MtoF_6to12_SessionTime_Mins DECIMAL(17,4),        
  					     MtoF_12to6_ConvoTime_Mins DECIMAL(17,4),      
					     MtoF_12to6_SessionTime_Mins DECIMAL(17,4),
					     Sat_12to12_ConvoTime_Mins DECIMAL(17,4),
					     Sat_12to12_SessionTime_Mins DECIMAL(17,4),
					     Sat_6to6_ConvoTime_Mins DECIMAL(17,4),
					     Sat_6to6_SessionTime_Mins DECIMAL(17,4), 
					     Sun_12to12_ConvoTime_Mins DECIMAL(17,4),
					     Sun_12to12_SessionTime_Mins DECIMAL(17,4),
					     Sun_6to6_ConvoTime_Mins DECIMAL(17,4),
					     Sun_6to6_SessionTime_Mins DECIMAL(17,4),
						 MtoF_6to6_ConvoTime_Mins DECIMAL(17,4),
					     MtoF_6to6_SessionTime_Mins DECIMAL(17,4)
						 )

						 INSERT INTO #CallData
						 SELECT
						  vrsvri.CallCenterCode,
						  vrsvri.OperatorID,
						  vrsvri.Handoff_Date,
						  BreakMins,
						  TeamedMins,
						  AvailableMins,
						  AllDays_12to12_ConvoTime_Mins,          
					      AllDays_12to12_SessionTime_Mins,       
					      MtoF_NonCore_ConvoTime_Mins,  
					      MtoF_NonCore_SessionTime_Mins,
					      MtoF_6to12_ConvoTime_Mins,    
					      MtoF_6to12_SessionTime_Mins,        
  					      MtoF_12to6_ConvoTime_Mins,      
					      MtoF_12to6_SessionTime_Mins,
					      Sat_12to12_ConvoTime_Mins,
					      Sat_12to12_SessionTime_Mins,
					      Sat_6to6_ConvoTime_Mins,
					      Sat_6to6_SessionTime_Mins, 
					      Sun_12to12_ConvoTime_Mins,
					      Sun_12to12_SessionTime_Mins,
					      Sun_6to6_ConvoTime_Mins,
					      Sun_6to6_SessionTime_Mins,
						  MtoF_6to6_ConvoTime_Mins,
					      MtoF_6to6_SessionTime_Mins

						  FROM #vrsvri_calldata_split as vrsvri
						  INNER JOIN #SessionSummary sm
						  ON vrsvri.CallCenterCode = sm.CallCenterCode
						  AND vrsvri.OperatorID = sm.OperatorID
						  AND vrsvri.Handoff_Date = sm.Handoff_Date
						  					

					--===============================================================================================
						--Merging two temp table '#vrsvri_calldata_split' and '#SessionSummary' in to one table '#CallData'--End
					--===============================================================================================

					--===============================================================================================
						--Fetch Labor Hour into temp table '#OprLaborSchedSource'--Start
					--===============================================================================================
					

					    CREATE TABLE #OprLaborSchedSource
						(
						 Handoff_Date DATETIME,
						 OperatorID INT,
						 OperatorName VARCHAR(250),
						 CallCenterCode VARCHAR(5),
						 AllDays_12to12_LaborTime_Hours DECIMAL(17,4),          					     
					     MtoF_NonCore_LaborTime_Hours DECIMAL(17,4),  					     
					     MtoF_6to12_LaborTime_Hours DECIMAL(17,4),    					     
  					     MtoF_12to6_LaborTime_Hours DECIMAL(17,4),      					     
					     Sat_12to12_LaborTime_Mins DECIMAL(17,4),					     
					     Sat_6to6_LaborTime_Hours DECIMAL(17,4),					     
					     Sun_12to12_LaborTime_Hours DECIMAL(17,4),					     
					     Sun_6to6_LaborTime_Hours DECIMAL(17,4),
						 MtoF_6to6_LaborTime_Hours as isnull(MtoF_6to12_LaborTime_Hours,0) + isnull(MtoF_12to6_LaborTime_Hours,0)
						 					     
						)

						 INSERT INTO #OprLaborSchedSource						 
						  SELECT
						  ShiftDate,
						  OperatorID,
						  OperatorName = min(OperatorName),
						  CallCenterCode = min(CallCenterCode),

						  AllDays_12to12_LaborTime_Hours	= sum(LaborTime_Secs)/3600.0,
						  MtoF_NonCore_LaborTime_Hours		= sum(iif(isWeekdayHours=1 and isNonCoreHours=1, LaborTime_Secs, 0))/3600.0,
						  MtoF_6to12_LaborTime_Hours		= sum(iif(isWeekdayHours=1 and is6to12Hours=1, LaborTime_Secs, 0))/3600.0,
						  MtoF_12to6_LaborTime_Hours		= sum(iif(isWeekdayHours=1 and is12to18Hours=1, LaborTime_Secs, 0))/3600.0,
						  Sat_12to12_LaborTime_Hours		= sum(iif(isSaturdayHours=1, LaborTime_Secs, 0))/3600.0,
						  Sat_6to6_LaborTime_Hours			= sum(iif(isSaturdayHours=1 and isCoreHours=1, LaborTime_Secs, 0))/3600.0,
						  Sun_12to12_LaborTime_Hours		= sum(iif(isSundayHours=1, LaborTime_Secs, 0))/3600.0,	
						  Sun_6to6_LaborTime_Hours			= sum(iif(isSundayHours=1 and isCoreHours=1, LaborTime_Secs, 0))/3600.0		
						  						
						FROM Reports.dbo.v_vrsOperatorLaborTime
						WHERE @StartDate <= ShiftDate and ShiftDate < @EndDate
						  and IsBenchmarkTask=1
                        			GROUP BY ShiftDate,OperatorID, CallCenterCode


					--===============================================================================================
						--Fetch Labor Hour into temp table '#OprLaborSchedSource'--End
					--===============================================================================================

					--===============================================================================================
						--Fetch Labor Hour into temp table '#OprLoginSession'--Start
					--===============================================================================================
					
					 CREATE TABLE #OprLoginSession
					 (
					  Handoff_Date DATETIME,
					  OperatorID INT, 
					  CallCenterCode VARCHAR(5),
					  AllDays_12to12_ActivityTime_Mins	DECIMAL(17,4),
					  MtoF_NonCore_ActivityTime_Mins	DECIMAL(17,4),
					  MtoF_6to12_ActivityTime_Mins		DECIMAL(17,4),
					  MtoF_12to6_ActivityTime_Mins		DECIMAL(17,4),
					  Sat_12to12_ActivityTime_Mins		DECIMAL(17,4),
					  Sat_6to6_ActivityTime_Mins		DECIMAL(17,4),
					  Sun_12to12_ActivityTime_Mins		DECIMAL(17,4),
					  Sun_6to6_ActivityTime_Mins		DECIMAL(17,4),
					  MtoF_6to6_ActivityTime_Mins as isnull(MtoF_6to12_ActivityTime_Mins,0) + isnull(MtoF_12to6_ActivityTime_Mins,0)
					 )


					 INSERT INTO #OprLoginSession
					 SELECT
					 Activity_Date,
					 OperatorID,
					 CallCenterCode,
					 AllDays_12to12_ActivityTime_Mins	= sum(LoginTime_Secs + TeamingTime_Secs - BreakTime_Secs) / 60.0,
					 MtoF_NonCore_ActivityTime_Mins	    = sum(iif(isWeekdayHours=1 and isNonCoreHours=1, LoginTime_Secs + TeamingTime_Secs - BreakTime_Secs, 0))/60.0,
					 MtoF_6to12_ActivityTime_Mins		= sum(iif(isWeekdayHours=1 and is6to12Hours=1, LoginTime_Secs + TeamingTime_Secs - BreakTime_Secs, 0))/60.0,
					 MtoF_12to6_ActivityTime_Mins		= sum(iif(isWeekdayHours=1 and is12to18Hours=1, LoginTime_Secs + TeamingTime_Secs - BreakTime_Secs, 0))/60.0,
					 Sat_12to12_ActivityTime_Mins		= sum(iif(isSaturdayHours=1, LoginTime_Secs + TeamingTime_Secs - BreakTime_Secs, 0))/60.0,
					 Sat_6to6_ActivityTime_Mins		    = sum(iif(isSaturdayHours=1 and isCoreHours=1, LoginTime_Secs + TeamingTime_Secs - BreakTime_Secs, 0))/60.0,
					 Sun_12to12_ActivityTime_Mins		= sum(iif(isSundayHours=1, LoginTime_Secs + TeamingTime_Secs - BreakTime_Secs, 0))/60.0,
					 Sun_6to6_ActivityTime_Mins		    = sum(iif(isSundayHours=1 and isCoreHours=1, LoginTime_Secs + TeamingTime_Secs - BreakTime_Secs, 0))/60.0

					 FROM Reports.dbo.v_vrsOperatorActivityTime sh
					 WHERE @StartDate <= Activity_Date and Activity_Date < @EndDate
					 --  and IsBenchmarkTask = 1
					 GROUP BY Activity_Date, OperatorID, CallCenterCode					 

					--===============================================================================================
						--Fetch Labor Hour into temp table '#OprLoginSession'--End
					--===============================================================================================
					
					
					--	=====================================================================================================					
					--  GET SCHEDULE SOURCE EMPLOYEE DATA from Reports.dbo.SS_EmployeeDataList
					--	=====================================================================================================						
						
						 
					   CREATE TABLE #SS_EmployeeData
							(
							Emp_RowNum INT IDENTITY
							,Employee_Name VARCHAR(255)
							,OperatorID INT
							,ADP_ID INT
							,DefaultLocation VARCHAR(50)
							,StaffType VARCHAR(255)
							,LanguageSkill VARCHAR(50)
							,HireDate DATETIME
							,MnthsTenure INT
							,Yeartenure Decimal(17,4)
							,TermDate DATETIME
							,Active VARCHAR(50)
							)
						INSERT INTO #SS_EmployeeData
							(
							Employee_Name
							,OperatorID
							,ADP_ID
							,DefaultLocation
							,StaffType
							,LanguageSkill
							,HireDate
							,MnthsTenure
							,YearTenure
							,TermDate
							,Active
							)
						SELECT DISTINCT
							ED.EmployeeName
							,OS.OperatorID
							,CAST(ED.ADP_ID AS INT)
							,ED.DefaultLocation
							,ED.StaffType
							,ED.[Language]
							,CAST(ED.HireDate AS DATETIME)
							,CAST(DATEDIFF(month,ED.HireDate,@EndDate) AS INT)
							,DATEDIFF(hour,ED.HireDate,@EndDate)/8766.0 --OR  DATEDIFF(DD,@dob,GetDate())/365.25 
							,CAST(ED.TermDate AS DATETIME)
							,ED.Active
						FROM (SELECT DISTINCT OperatorID FROM #CallData) OS
							LEFT JOIN Reports.dbo.SS_EmployeeDataList ED ON OS.OperatorID = ED.ExternalID
							WHERE EmployeeName IS NOT NULL
						ORDER BY ED.EmployeeName

      
					
						--	=====================================================================================================
						--	END GET SCHEDULE SOURCE EMPLOYEE DATA from Reports.dbo.SS_EmployeeDataList
						--	=====================================================================================================
						--	=====================================================================================================
						--	END GET SCHEDULE SOURCE EMPLOYEE DATA  
						--	=====================================================================================================

						--========================================================================================================
						--START SELECT *  FROM #oprSessionHist,#SS_EmployeeData,#oprSchedSource
						--========================================================================================================	
						   CREATE TABLE #Results
						   (
							[StartDate] [datetime],
							[EndDate] [datetime],
							[rptDate] [datetime],
							[HomeLocation]	[varchar](20),
							[CallCenterCode] [varchar](50),
							[OperatorID] [int],
							[ADP_ID] [int],
							[Emp_RowNum] [int],
							[employee_name] [varchar](255),
							[StaffType] [varchar](255),
							[LanguageSkill] [varchar](50),
							[HireDate] [datetime],
							[MnthsTenure] [int],
							[BreakMins] [decimal](17, 4),
							[TeamedMins] [decimal](17, 4),
							[AvailableMins] [decimal](17, 4),
							[AllDays_12to12_LaborTime_Hours] [decimal](17, 4),
							[AllDays_12to12_ConvoTime_Mins] [decimal](17, 4),
							[AllDays_12to12_SessionTime_Mins] [decimal](17, 4),
							[AllDays_12to12_ActivityTime_Mins] [decimal](17, 4),
							[MtoF_6to12_LaborTime_Hours] [decimal](17, 4),
							[MtoF_6to12_ConvoTime_Mins] [decimal](17, 4),
							[MtoF_6to12_SessionTime_Mins] [decimal](17, 4),
							[MtoF_6to12_ActivityTime_Mins] [decimal](17, 4),
							[MtoF_12to6_LaborTime_Hours] [decimal](17, 4),
							[MtoF_12to6_ConvoTime_Mins] [decimal](17, 4),
							[MtoF_12to6_SessionTime_Mins] [decimal](17, 4),
							[MtoF_12to6_ActivityTime_Mins] [decimal](17, 4),
							[Sat_12to12_LaborTime_Mins] [decimal](17, 4),
							[Sat_12to12_ConvoTime_Mins] [decimal](17, 4),
							[Sat_12to12_SessionTime_Mins] [decimal](17, 4),
							[Sat_12to12_ActivityTime_Mins] [decimal](17, 4),
							[Sun_12to12_LaborTime_Hours] [decimal](17, 4),
							[Sun_12to12_ConvoTime_Mins] [decimal](17, 4),
							[Sun_12to12_SessionTime_Mins] [decimal](17, 4),
							[Sun_12to12_ActivityTime_Mins] [decimal](17, 4),
							[Sat_6to6_LaborTime_Hours] [decimal](17, 4),
							[Sat_6to6_ConvoTime_Mins] [decimal](17, 4),
							[Sat_6to6_SessionTime_Mins] [decimal](17, 4),
							[Sat_6to6_ActivityTime_Mins] [decimal](17, 4),
							[Sun_6to6_LaborTime_Hours] [decimal](17, 4),
							[Sun_6to6_ConvoTime_Mins] [decimal](17, 4),
							[Sun_6to6_SessionTime_Mins] [decimal](17, 4),
							[Sun_6to6_ActivityTime_Mins] [decimal](17, 4),
							[MtoF_NonCore_LaborTime_Hours] [decimal](17, 4),
							[MtoF_NonCore_ConvoTime_Mins] [decimal](17, 4),
							[MtoF_NonCore_SessionTime_Mins] [decimal](17, 4),
							[MtoF_NonCore_ActivityTime_Mins] [decimal](17, 4),
							[MtoF_6to6_LaborTime_Hours] [decimal](18, 4),
							[MtoF_6to6_ConvoTime_Mins] [decimal](17, 4),
							[MtoF_6to6_SessionTime_Mins] [decimal](17, 4),
							[MtoF_6to6_ActivityTime_Mins] [decimal](18, 4),
							[MtoF_NonCore_SatSun_LaborTime_Hours] [decimal](18, 4),
							[MtoF_NonCore_SatSun_ConvoTime_Mins] [decimal](18, 4),
							[MtoF_NonCore_SatSun_SessionTime_Mins] [decimal](18, 4),
							[MtoF_NonCore_SatSun_ActivityTime_Mins] [decimal](18, 4)
							 )	



							INSERT INTO #Results
							(
							StartDate,
							EndDate,
							rptDate,
							HomeLocation,
							CallCenterCode,
							OperatorID,
							ADP_ID,
							Emp_RowNum,
							employee_name,
							StaffType,
							LanguageSkill,
							HireDate,
							MnthsTenure,
							BreakMins,
						    TeamedMins,
						    AvailableMins,
							AllDays_12to12_LaborTime_Hours,
							AllDays_12to12_ConvoTime_Mins,
							AllDays_12to12_SessionTime_Mins,
							AllDays_12to12_ActivityTime_Mins,
							MtoF_6to12_LaborTime_Hours,
							MtoF_6to12_ConvoTime_Mins,
							MtoF_6to12_SessionTime_Mins,
							MtoF_6to12_ActivityTime_Mins,
							MtoF_12to6_LaborTime_Hours,
							MtoF_12to6_ConvoTime_Mins,
							MtoF_12to6_SessionTime_Mins,
							MtoF_12to6_ActivityTime_Mins,

							Sat_12to12_LaborTime_Mins,
							Sat_12to12_ConvoTime_Mins,
							Sat_12to12_SessionTime_Mins,
							Sat_12to12_ActivityTime_Mins,

							Sun_12to12_LaborTime_Hours,
							Sun_12to12_ConvoTime_Mins,
							Sun_12to12_SessionTime_Mins,
							Sun_12to12_ActivityTime_Mins,

							Sat_6to6_LaborTime_Hours,
							Sat_6to6_ConvoTime_Mins,
							Sat_6to6_SessionTime_Mins,
							Sat_6to6_ActivityTime_Mins,

							Sun_6to6_LaborTime_Hours,
							Sun_6to6_ConvoTime_Mins,
							Sun_6to6_SessionTime_Mins,
							Sun_6to6_ActivityTime_Mins,

							MtoF_NonCore_LaborTime_Hours,
							MtoF_NonCore_ConvoTime_Mins,
							MtoF_NonCore_SessionTime_Mins,
							MtoF_NonCore_ActivityTime_Mins,

							MtoF_6to6_LaborTime_Hours,
							MtoF_6to6_ConvoTime_Mins,
							MtoF_6to6_SessionTime_Mins,
							MtoF_6to6_ActivityTime_Mins,

							MtoF_NonCore_SatSun_LaborTime_Hours,
							MtoF_NonCore_SatSun_ConvoTime_Mins,
							MtoF_NonCore_SatSun_SessionTime_Mins,
							MtoF_NonCore_SatSun_ActivityTime_Mins
							)
							
							SELECT	
							 @StartDate 'StartDate',
							 CAST(CONVERT(VARCHAR(10),@EndDate,101) + ' 00:00:000' AS DATETIME) 'EndDate'
							,CD.Handoff_Date 'rptDate'			
							,isnull(ED.DefaultLocation, CD.CallCenterCode) 'HomeLocation'
							,CD.CallCenterCode	
							,CD.OperatorID
							,ED.ADP_ID
							,ED.Emp_RowNum
							,ISNULL(ED.employee_name,SS.OperatorName) 'employee_name'							
							,ED.StaffType
							,ED.LanguageSkill
							,CASE WHEN ED.Active = 'False' THEN NULL ELSE CONVERT(DATETIME,ED.HireDate) END 'HireDate'
							,CASE WHEN ED.Active = 'False' THEN 0 ELSE ED.MnthsTenure END AS 'MnthsTenure'
							,BreakMins
						    ,TeamedMins
						    ,AvailableMins
							,ISNULL(SS.AllDays_12to12_LaborTime_Hours,0) 'AllDays_12to12_LaborTime_Hours'
							,ISNULL(CD.AllDays_12to12_ConvoTime_Mins,0) 'AllDays_12to12_ConvoTime_Mins'
							,ISNULL(CD.AllDays_12to12_SessionTime_Mins,0) 'AllDays_12to12_SessionTime_Mins'
							,ISNULL(OSH.AllDays_12to12_ActivityTime_Mins,0) 'AllDays_12to12_ActivityTime_Mins'
														
							,ISNULL(SS.MtoF_6to12_LaborTime_Hours,0) 'MtoF_6to12_LaborTime_Hours'
							,ISNULL(CD.MtoF_6to12_ConvoTime_Mins,0) 'MtoF_6to12_ConvoTime_Mins'
							,ISNULL(CD.MtoF_6to12_SessionTime_Mins,0) 'MtoF_6to12_SessionTime_Mins'
							,ISNULL(OSH.MtoF_6to12_ActivityTime_Mins,0) 'MtoF_6to12_ActivityTime_Mins'
							
							,ISNULL(SS.MtoF_12to6_LaborTime_Hours,0) 'MtoF_12to6_LaborTime_Hours'
							,ISNULL(CD.MtoF_12to6_ConvoTime_Mins,0) 'MtoF_12to6_ConvoTime_Mins'
							,ISNULL(CD.MtoF_12to6_SessionTime_Mins,0) 'MtoF_12to6_SessionTime_Mins'
							,ISNULL(OSH.MtoF_12to6_ActivityTime_Mins,0) 'MtoF_12to6_ActivityTime_Mins'

							,ISNULL(SS.Sat_12to12_LaborTime_Mins,0) 'Sat_12to12_LaborTime_Mins'
							,ISNULL(CD.Sat_12to12_ConvoTime_Mins,0) 'Sat_12to12_ConvoTime_Mins'
							,ISNULL(CD.Sat_12to12_SessionTime_Mins,0) 'Sat_12to12_SessionTime_Mins'
							,ISNULL(OSH.Sat_12to12_ActivityTime_Mins,0) 'Sat_12to12_ActivityTime_Mins'

							,ISNULL(SS.Sun_12to12_LaborTime_Hours,0) 'Sun_12to12_LaborTime_Hours'
							,ISNULL(CD.Sun_12to12_ConvoTime_Mins,0) 'Sun_12to12_ConvoTime_Mins'
							,ISNULL(CD.Sun_12to12_SessionTime_Mins,0) 'Sun_12to12_SessionTime_Mins'
							,ISNULL(OSH.Sun_12to12_ActivityTime_Mins,0) 'Sun_12to12_ActivityTime_Mins'

							,ISNULL(SS.Sat_6to6_LaborTime_Hours,0) 'Sat_6to6_LaborTime_Hours'
							,ISNULL(CD.Sat_6to6_ConvoTime_Mins,0) 'Sat_6to6_ConvoTime_Mins'
							,ISNULL(CD.Sat_6to6_SessionTime_Mins,0) 'Sat_6to6_SessionTime_Mins'
							,ISNULL(OSH.Sat_6to6_ActivityTime_Mins,0) 'Sat_6to6_ActivityTime_Mins'

							,ISNULL(SS.Sun_6to6_LaborTime_Hours,0) 'Sun_6to6_LaborTime_Hours'
							,ISNULL(CD.Sun_6to6_ConvoTime_Mins,0) 'Sun_6to6_ConvoTime_Mins'
							,ISNULL(CD.Sun_6to6_SessionTime_Mins,0) 'Sun_6to6_SessionTime_Mins'
							,ISNULL(OSH.Sun_6to6_ActivityTime_Mins,0) 'Sun_6to6_ActivityTime_Mins'

							,ISNULL(SS.MtoF_NonCore_LaborTime_Hours,0) 'MtoF_NonCore_LaborTime_Hours'
							,ISNULL(CD.MtoF_NonCore_ConvoTime_Mins,0) 'MtoF_NonCore_ConvoTime_Mins'
							,ISNULL(CD.MtoF_NonCore_SessionTime_Mins,0) 'MtoF_NonCore_SessionTime_Mins'
							,ISNULL(OSH.MtoF_NonCore_ActivityTime_Mins,0) 'MtoF_NonCore_ActivityTime_Mins'

							,ISNULL(SS.MtoF_6to6_LaborTime_Hours,0) 'MtoF_6to6_LaborTime_Hours'
							,ISNULL(CD.MtoF_6to6_ConvoTime_Mins,0) 'MtoF_6to6_ConvoTime_Mins'
							,ISNULL(CD.MtoF_6to6_SessionTime_Mins,0) 'MtoF_6to6_SessionTime_Mins'
							,ISNULL(OSH.MtoF_6to6_ActivityTime_Mins,0) 'MtoF_6to6_ActivityTime_Mins'
							
							,ISNULL(SS.MtoF_NonCore_LaborTime_Hours,0) + ISNULL(SS.Sat_12to12_LaborTime_Mins,0) +  ISNULL(SS.Sun_12to12_LaborTime_Hours,0) 'MtoF_NonCore_SatSun_LaborTime_Hours'
							,ISNULL(CD.MtoF_NonCore_ConvoTime_Mins,0) + ISNULL(CD.Sat_12to12_ConvoTime_Mins,0) + ISNULL(CD.Sun_12to12_ConvoTime_Mins,0)  'MtoF_NonCore_SatSun_ConvoTime_Mins'
							,ISNULL(CD.MtoF_NonCore_SessionTime_Mins,0) + ISNULL(CD.Sat_12to12_SessionTime_Mins,0) + ISNULL(CD.Sun_12to12_SessionTime_Mins,0)  'MtoF_NonCore_SatSun_SessionTime_Mins'
							,ISNULL(OSH.MtoF_NonCore_ActivityTime_Mins,0) + ISNULL(OSH.Sat_12to12_ActivityTime_Mins,0) + ISNULL(OSH.Sun_12to12_ActivityTime_Mins,0)  'MtoF_NonCore_SatSun_ActivityTime_Mins'

							FROM #CallData CD 
							LEFT JOIN #OprLoginSession OSH ON CD.Handoff_Date = OSH.Handoff_Date AND CD.OperatorID = OSH.OperatorID AND CD.CallCenterCode = OSH.CallCenterCode
							LEFT JOIN #SS_EmployeeData ED ON CD.OperatorID = ED.OperatorID
							LEFT JOIN #OprLaborSchedSource SS ON SS.Handoff_Date = CD.Handoff_Date AND SS.OperatorID = CD.OperatorID AND CD.CallCenterCode = SS.CallCenterCode	

													
							
						--========================================================================================================
						--END SELECT *  FROM #oprSessionHist,#SS_EmployeeData,#oprSchedSource
						--========================================================================================================
						
						--========================== creating table for calculating the convomins group by date =======================
						
							DECLARE @TotalConvoPctVSEntDaily TABLE
							(
							 rptDate DATETIME
							,AllDays_12to12_ConvoPctVSEnt decimal(12,4)		
							,MtoF_6ato12_ConvoPctVSEnt decimal(12,4)
							,MtoF_12to6_ConvoPctVSEnt decimal(12,4)
							,Sat_12to12_ConvoPctVSEnt decimal(12,4)
							,Sat_6to6_ConvoPctVSEnt decimal(12,4)
							,Sun_12to12_ConvoPctVSEnt decimal(12,4)
							,Sun_6to6_ConvoPctVSEnt decimal(12,4)
							,MtoF_NonCore_ConvoPctVSEnt decimal(12,4)
							,MtoF_NonCore_SatSun_ConvoPctVSEnt decimal(12,4)
							)		
			
		
							INSERT INTO @TotalConvoPctVSEntDaily
							(
							 rptDate
							,AllDays_12to12_ConvoPctVSEnt
							,MtoF_6ato12_ConvoPctVSEnt
							,MtoF_12to6_ConvoPctVSEnt
							,Sat_12to12_ConvoPctVSEnt
							,Sat_6to6_ConvoPctVSEnt
							,Sun_12to12_ConvoPctVSEnt
							,Sun_6to6_ConvoPctVSEnt
							,MtoF_NonCore_ConvoPctVSEnt
							,MtoF_NonCore_SatSun_ConvoPctVSEnt
							)
							SELECT rptdate
							,case when sum(AllDays_12to12_LaborTime_Hours) = 0 then 0 else (sum(AllDays_12to12_ConvoTime_Mins) /(nullif(sum(AllDays_12to12_LaborTime_Hours)*60.0,0))) end
							,case when sum(MtoF_6to12_LaborTime_Hours) = 0 then 0 else sum(MtoF_6to12_ConvoTime_Mins) /(nullif(sum(MtoF_6to12_LaborTime_Hours)*60.0,0)) end
							,case when sum(MtoF_12to6_LaborTime_Hours) = 0 then 0 else sum(MtoF_12to6_ConvoTime_Mins) /(nullif(sum(MtoF_12to6_LaborTime_Hours)*60.0,0)) end
							,case when sum(Sat_12to12_LaborTime_Mins) = 0 then 0 else sum(Sat_12to12_ConvoTime_Mins) /(nullif(sum(Sat_12to12_LaborTime_Mins)*60.0,0)) end		
							,case when sum(Sat_6to6_LaborTime_Hours) = 0 then 0 else sum(Sat_6to6_ConvoTime_Mins) /(nullif(sum(Sat_6to6_LaborTime_Hours)*60.0,0)) end
							,case when sum(Sun_12to12_LaborTime_Hours) = 0 then 0 else sum(Sun_12to12_ConvoTime_Mins) /(nullif(sum(Sun_12to12_LaborTime_Hours)*60.0,0)) end
							,case when sum(Sun_6to6_LaborTime_Hours) = 0 then 0 else sum(Sun_6to6_ConvoTime_Mins) /(nullif(sum(Sun_6to6_LaborTime_Hours)*60.0,0)) end		
							,case when sum(MtoF_NonCore_LaborTime_Hours) = 0 then 0 else sum(MtoF_NonCore_ConvoTime_Mins) /(nullif(sum(MtoF_NonCore_LaborTime_Hours)*60.0,0)) end           
							,case when sum(MtoF_NonCore_SatSun_LaborTime_Hours) = 0 then 0 else sum(MtoF_NonCore_SatSun_ConvoTime_Mins) /(nullif(sum(MtoF_NonCore_SatSun_LaborTime_Hours)*60.0,0)) end

							FROM #Results
							WHERE  rptDate between @StartDate and @endDate And AllDays_12to12_LaborTime_Hours > 0
							group by rptDate						
	 
				         --================================ select final record from table  ============================================

               				 
								Select
								StartDate,
								EndDate,
								RS.rptDate 'rptDate',
								HomeLocation,
								CallCenterCode,
								OperatorID,
								ADP_ID,
								Emp_RowNum,
								employee_name,
								StaffType,
								LanguageSkill,
								HireDate,
								MnthsTenure,
								BreakMins,
								TeamedMins,
								AvailableMins,
								AllDays_12to12_LaborTime_Hours,
								AllDays_12to12_ConvoTime_Mins,
								AllDays_12to12_SessionTime_Mins,
								AllDays_12to12_ActivityTime_Mins,
								MtoF_6to12_LaborTime_Hours,
								MtoF_6to12_ConvoTime_Mins,
								MtoF_6to12_SessionTime_Mins,
								MtoF_6to12_ActivityTime_Mins,
								MtoF_12to6_LaborTime_Hours,
								MtoF_12to6_ConvoTime_Mins,
								MtoF_12to6_SessionTime_Mins,
								MtoF_12to6_ActivityTime_Mins,
								Sat_12to12_LaborTime_Mins,
								Sat_12to12_ConvoTime_Mins,
								Sat_12to12_SessionTime_Mins,
								Sat_12to12_ActivityTime_Mins,
								Sun_12to12_LaborTime_Hours,
								Sun_12to12_ConvoTime_Mins,
								Sun_12to12_SessionTime_Mins,
								Sun_12to12_ActivityTime_Mins,
								Sat_6to6_LaborTime_Hours,
								Sat_6to6_ConvoTime_Mins,
								Sat_6to6_SessionTime_Mins,
								Sat_6to6_ActivityTime_Mins,
								Sun_6to6_LaborTime_Hours,
								Sun_6to6_ConvoTime_Mins,
								Sun_6to6_SessionTime_Mins,
								Sun_6to6_ActivityTime_Mins,
								MtoF_NonCore_LaborTime_Hours,
								MtoF_NonCore_ConvoTime_Mins,
								MtoF_NonCore_SessionTime_Mins,
								MtoF_NonCore_ActivityTime_Mins,
								MtoF_6to6_LaborTime_Hours,
								MtoF_6to6_ConvoTime_Mins,
								MtoF_6to6_SessionTime_Mins,
								MtoF_6to6_ActivityTime_Mins,
								MtoF_NonCore_SatSun_LaborTime_Hours,
								MtoF_NonCore_SatSun_ConvoTime_Mins,
								MtoF_NonCore_SatSun_SessionTime_Mins,
								MtoF_NonCore_SatSun_ActivityTime_Mins,

								case when AllDays_12to12_LaborTime_Hours = 0 then 0 else AllDays_12to12_ConvoPctVSEnt end 'AllDays_12to12_ConvoPctVSEnt',
								case when MtoF_6to12_LaborTime_Hours = 0 then 0 else MtoF_6ato12_ConvoPctVSEnt end 'MtoF_6ato12_ConvoPctVSEnt',
								case when MtoF_12to6_LaborTime_Hours = 0 then 0 else MtoF_12to6_ConvoPctVSEnt end 'MtoF_12to6_ConvoPctVSEnt',
								case when Sat_12to12_LaborTime_Mins = 0 then 0 else Sat_12to12_ConvoPctVSEnt end 'Sat_12to12_ConvoPctVSEnt',
								case when Sat_6to6_LaborTime_Hours = 0 then 0 else Sat_6to6_ConvoPctVSEnt end 'Sat_6to6_ConvoPctVSEnt',
								case when Sun_12to12_LaborTime_Hours = 0 then 0 else Sun_12to12_ConvoPctVSEnt end 'Sun_12to12_ConvoPctVSEnt',
								case when Sun_6to6_LaborTime_Hours = 0 then 0 else Sun_6to6_ConvoPctVSEnt end 'Sun_6to6_ConvoPctVSEnt',
								case when MtoF_NonCore_LaborTime_Hours = 0 then 0 else MtoF_NonCore_ConvoPctVSEnt end 'MtoF_NonCore_ConvoPctVSEnt',
								case when MtoF_NonCore_SatSun_LaborTime_Hours = 0 then 0 else MtoF_NonCore_SatSun_ConvoPctVSEnt end 'MtoF_NonCore_SatSun_ConvoPctVSEnt'
	       
								FROM #Results RS 				
								INNER JOIN @TotalConvoPctVSEntDaily TS
								ON RS.rptDate=TS.rptDate				 
								WHERE RS.rptDate 
								between @StartDate and @endDate and AllDays_12to12_LaborTime_Hours > 0 
								order by RS.CallCenterCode,rptDate	


				
								--================================================================================================
								--  end SELECT ALL DATA FROM Temp_rpt2929_Results
								--================================================================================================


				
