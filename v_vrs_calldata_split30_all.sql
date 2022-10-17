USE [Reports]
GO

/****** Object:  View [dbo].[v_vrs_calldata_split30_all]    Script Date: 1/18/2016 5:31:36 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [dbo].[v_vrs_calldata_split30_all]
/* Helper view to map all the flavors of VRS together
   into one so it can be easily reported on.

Usage:

select * from Reports.dbo.v_vrs_calldata_split30_all
where handoff_time between '11/1/2015' and '11/2/2015'
--and CallData_Type in ('VRS','VRI')
order by convoid

select handoff_time, * from calldataDWProd.dbo.vrs_calldata_split30
where handoff_time between '11/1/2015' and '11/2/2015'
order by convoid

select * from calldataDWConvo.dbo.vrs_calldata_split30
select * from calldataDWProd.dbo.vri_calldata_split30


*/
as

	select 
		CallData_Type = 'VRS',
		Handoff_Date = cast(Handoff_Time as date),
		Interval_Time, 
		CallID, 
		First_Interval, 
		Last_Interval, 
		SessionID, 
		ConvoID, 
		RLSA_ConvoID, 
		Teaming, 
		csOprSessionID, 
		oclOprSessionID, 
		OperatorID, 
		LocationCode, 
		CenterID, 
		Handoff_time, 
		Abandon, 
		LostAbandon, 
		Answered, 
		Incoming, 
		Outbound, 
		isCoreHours, 
		isNonCoreHours, 
		is6to12Hours, 
		is12to18Hours, 
		isWeekdayHours, 
		isSaturdayHours, 
		isSundayHours, 
		isEnglishCall, 
		IsSpanishCall, 
		AbandonTime, 
		AnsweredTime, 
		VI_AnswerTime, 
		csoprAcceptTime, 
		SessionStart, 
		SessionStart_RL, 
		ConvoStart, 
		ConvoEnd, 
		SessionEnd_RL, 
		SessionEnd, 
		SessionTime_Total, 
		SessionTime, 
		ConvoTime, 
		RLSA_ConvoTime, 
		BillableTime,
		Branding, 
		[LANGUAGE], 
		Call_Type, 
		UserID_Caller, 
		UserID_Caller_TDN     = cast(UserID_Caller as varchar(64)),
		Voice_PhoneNumber, 
		PhoneNumber, 
		DeviceID, 
		RLSA_Disp, 
		RLSA_Disp_Reason
	from CallDataDWProd.dbo.vrs_calldata_split30

	union all

	select
		CallData_Type = 'VRI',
		Handoff_Date = cast(Handoff_Time as date),
		Interval_Time,
		CallID,
		First_Interval,
		Last_Interval,
		SessionID,
		ConvoID,
		RLSA_ConvoID,
		Teaming,
		csOprSessionID,
		oclOprSessionID,
		OperatorID,
		LocationCode,
		CenterID,
		Handoff_time,
		Abandon,
		LostAbandon,
		Answered,
		Incoming,
		Outbound,
		isCoreHours,
		isNonCoreHours,
		is6to12Hours,
		is12to18Hours,
		isWeekdayHours,
		isSaturdayHours,
		isSundayHours,
		isEnglishCall,
		IsSpanishCall,
		AbandonTime,
		AnsweredTime,
		VI_AnswerTime,
		csoprAcceptTime,
		SessionStart          = ConvoStart,
		SessionStart_RL       = ConvoStart_RL,
		ConvoStart            = ConvoStart_RL,
		ConvoEnd              = ConvoEnd_RL,
		SessionEnd_RL         = ConvoEnd_RL,
		SessionEnd            = ConvoEnd,
		SessionTime_Total     = ConvoTime,
		SessionTime           = r_ConvoTime,
		ConvoTime             = r_ConvoTime,
		RLSA_ConvoTime        = NULL, --iif(ConvoStart=ConvoStart_RL,cast(ConvoTime/60.0 as decimal(12,1)),0),  -- first row only, this is just an approximation of the RLSA calc!
		BillableTime          = NULL, --iif(ConvoStart=ConvoStart_RL,ConvoTime,0),  -- first row only
		Branding,
		[LANGUAGE],
		Call_Type,
		UserID_Caller,
		UserID_Caller_TDN     = cast(UserID_Caller as varchar(64)),
		Voice_PhoneNumber,
		PhoneNumber           = Video_PhoneNumber,
		DeviceID,
		RLSA_Disp             = 'C',  --all vri is billable
		RLSA_Disp_Reason      = 'VRI'
	from CallDataDWProd.dbo.vri_calldata_split30

	union all

	select 
		CallData_Type = 'ConvoRelay',
		Handoff_Date = cast(Handoff_Time as date),
		Interval_Time, 
		CallID, 
		First_Interval, 
		Last_Interval, 
		SessionID, 
		ConvoID, 
		RLSA_ConvoID, 
		Teaming, 
		csOprSessionID, 
		oclOprSessionID, 
		OperatorID, 
		LocationCode, 
		CenterID, 
		Handoff_time, 
		Abandon, 
		LostAbandon, 
		Answered, 
		Incoming, 
		Outbound, 
		isCoreHours, 
		isNonCoreHours, 
		is6to12Hours, 
		is12to18Hours, 
		isWeekdayHours, 
		isSaturdayHours, 
		isSundayHours, 
		isEnglishCall, 
		IsSpanishCall, 
		AbandonTime, 
		AnsweredTime, 
		VI_AnswerTime, 
		csoprAcceptTime, 
		SessionStart, 
		SessionStart_RL, 
		ConvoStart, 
		ConvoEnd, 
		SessionEnd_RL, 
		SessionEnd, 
		SessionTime_Total, 
		SessionTime, 
		ConvoTime, 
		RLSA_ConvoTime, 
		BillableTime, 
		Branding, 
		[LANGUAGE], 
		Call_Type, 
		UserID_Caller, 
		UserID_Caller_TDN = iif(UserID_Caller<1 and isnull(PhoneNumber,'')<>'', 'tdn_' + PhoneNumber, cast(UserID_Caller as varchar(64))),
		Voice_PhoneNumber, 
		PhoneNumber, 
		DeviceID, 
		RLSA_Disp, 
		RLSA_Disp_Reason
	from CallDataDWConvo.dbo.vrs_calldata_split30



GO


