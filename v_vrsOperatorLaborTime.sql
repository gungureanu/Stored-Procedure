USE [Reports]
GO

/****** Object:  View [dbo].[v_vrsOperatorLaborTime]    Script Date: 1/15/2016 5:48:04 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [dbo].[v_vrsOperatorLaborTime]
--WITH SCHEMABINDING
/* Helper view to get labor time data for operators

Usage:

select * from Reports.dbo.v_vrsOperatorLaborTime
where ShiftStart between '3/1/2015' and '3/2/2015'
order by ShiftStart -- 1525

*/
as
	select
	  ShiftDate = Date,
	  Interval_Begin = HlfHrStart,
	  ShiftStart = adjShiftStart,
	  ShiftEnd = adjShiftEnd,
	  OperatorID = Emp_ID,
	  OperatorName = Employee_Name,
	  CallCenterCode = Station_Name,
	  LaborTime_Secs = LaborTime,
	  TaskType = TaskName,
	  IsBenchmarkTask = case isnull(TaskName,'VRS')  --Note: Benchmark Tracking Tasks inlude both VRS and VRI
				when 'VRS' then 1	
				--when 'VRI' then 1	-- requested to be removed by Nick AN-58
				when 'Bench Time' then 1
				when 'Corporate Events' then 1
				when 'Professional Development' then 1
				when 'ISAS Rating' then 1
				when 'Management' then 1
				else 0 
			  end
	  ,isCoreHours = iif(datepart(hour,adjShiftStart) >= 6 and datepart(hour,adjShiftStart) < 18, 1, 0)
	  ,isNonCoreHours = iif(datepart(hour,adjShiftStart) < 6 or datepart(hour,adjShiftStart) >= 18, 1, 0)
	  ,is6to12Hours = iif(datepart(hour,adjShiftStart) >= 6 and datepart(hour,adjShiftStart) < 12, 1, 0)
	  ,is12to18Hours = iif(datepart(hour,adjShiftStart) >= 12 and datepart(hour,adjShiftStart) < 18, 1, 0)
	  ,isWeekdayHours = iif(datename(dw,adjShiftStart) not in ('saturday','sunday'), 1, 0)
	  ,isSaturdayHours = iif(datename(dw,adjShiftStart) in ('saturday'), 1, 0)
	  ,isSundayHours = iif(datename(dw,adjShiftStart) in ('sunday'), 1, 0)
	from satVRS.dbo.rptOprSchedSource



GO


