USE [Reports]
GO

/****** Object:  View [dbo].[v_vrsOperatorActivityTime]    Script Date: 1/15/2016 5:47:54 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



ALTER VIEW [dbo].[v_vrsOperatorActivityTime]
--WITH SCHEMABINDING
/* Helper view to map VRS and VRI call data together
   into one so it can be easily reported on.

Usage:

select * from Reports.dbo.v_vrsOperatorActivityTime
where Activity_Date between '3/1/2015' and '3/2/2015'

--select * from satVRS.dbo.rptOprSessionHistory

*/
as

	select
	  sh.OperatorID,
	  sh.CallCenterCode,
	  Activity_Date = [Date],

	  Activity_Begin_Time = AdjStartTime,
	  Activity_End_Time = AdjEndTime,

	  LoginTime_Secs = LoginTime,
	  TeamingTime_Secs = TeamingTime,
	  BreakTime_Secs = BreakTime,

	  --TaskType = TaskType,
	  --IsBenchMarkTask = isnull(IsBenchMarkTask,0)

	  isCoreHours = iif(datepart(hour,AdjStartTime) >= 6 and datepart(hour,AdjStartTime) < 18, 1, 0),
	  isNonCoreHours = iif(datepart(hour,AdjStartTime) < 6 or datepart(hour,AdjStartTime) >= 18, 1, 0),
	  is6to12Hours = iif(datepart(hour,AdjStartTime) >= 6 and datepart(hour,AdjStartTime) < 12, 1, 0),
	  is12to18Hours = iif(datepart(hour,AdjStartTime) >= 12 and datepart(hour,AdjStartTime) < 18, 1, 0),
	  isWeekdayHours = iif(datename(dw,AdjStartTime) not in ('saturday','sunday'), 1, 0),
	  isSaturdayHours = iif(datename(dw,AdjStartTime) in ('saturday'), 1, 0),
	  isSundayHours = iif(datename(dw,AdjStartTime) in ('sunday'), 1, 0)

	from satVRS.dbo.rptOprSessionHistory sh
	--left join v_vrsOperatorLaborTime as os on
	--	os.OperatorID = sh.OperatorID and (os.ShiftStart <= AdjStartTime and AdjStartTime < os.ShiftEnd)



GO


