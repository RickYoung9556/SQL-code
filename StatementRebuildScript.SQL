/* This script can be used to verify the statement amount and find 
the incorrect statement(s) Once they are found you can change a flag to have it
update the statements correctly 

The flag is:
Change from (This checks only):
Select  @Update = 1 -- Update Table 
--Select  @Update = 0 -- It means No Update ; only Report

To (This will update the incorrect statement and roll balances forward):
Select  @Update = 1 -- Update Table 
--Select  @Update = 0 -- It means No Update ; only Report 
You will need to enter the location and customer
 as well where it says 'LocationID'and 'CustomerNumber*/

if exists (select * from sysobjects where id = object_id(N'[dbo].[DOCROUTE]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
drop table [dbo].[DOCROUTE]
GO

CREATE TABLE [dbo].[DOCROUTE] (
	[umStatementDocNo] [int] NULL ,
	[umLocationID] [char] (15) NULL ,
	[CUSTNMBR] [char] (15) NULL ,
	[umStatementAmount] [numeric](19, 5) NULL 
) ON [PRIMARY]
GO
insert  into DOCROUTE
	select umStatementDocNo,umLocationID,CUSTNMBR,umStatementAmount from UM00701 
	where umLocationID = 'LocationID' and CUSTNMBR = 'CustomerID' 
GO

DECLARE       @Loc01  char(15), 
       @Loc02  char(15),
       @Cust01 char(15),
       @Cust02 char(15),
       @StatDocNo01 int,
       @StatDocNo02 int


SET NOCOUNT ON
DECLARE @strLASTDOCNO char(15)
DECLARE @umAccumType smallint
DECLARE @AccumMasterID char(15)
DECLARE @umAppDEPSAmt numeric(19,5)
DECLARE @umLocationID char(15)
DECLARE @CUSTNMBR char(15)
DECLARE @umDocumentNumber char(15)
DECLARE @umDocAmt money 
DECLARE @umDocLoc smallint
DECLARE @UMDOCTYPE smallint
DECLARE @LastDocNo int,@umStatementDocNo int
DECLARE @TempAmount  money
DECLARE @TempCust   char(15)
DECLARE @TempLoc    char(15)

DECLARE @umPrevStatementAmount numeric(19,5)
declare @umArchivedStatementAmount numeric(19,5)
declare @minStateNum int

DECLARE  @umMISCAmtW money,@umMISCAmtO money,@umMISCAmtH money
DECLARE  @umMISCAmtOV money
DECLARE  @umMISCAmtHV money
DECLARE  @umBillAmtW money,@umBillAmtO money,@umBillAmtH money
DECLARE  @umBillAmtOV money
DECLARE  @umBillAmtHV money

DECLARE @umPymtAmtW money,@umPymtAmtO money,@umPymtAmtH money
DECLARE @umPymtAmtV money

DECLARE @umPymtDEPSAmtO money
DECLARE @umPymtDEPSAmtH money
DECLARE @umPymtDEPSAmtV money,@umMISCAmtV money,@umBillAmtV money
DECLARE @umAppDEPSAmt_A money,@umAppDEPSAmt_H money
Declare @umStat_Repl_CHEQ_Amt money,@umStat_Repl_DEPS_Amt money,@umStat_Repl_INTR_Amt money
Declare @StatDocNoBEGIN int,@StatDocNoEND int,
@LocationID CHAR(15),
@STATLocationID CHAR(15),
@MaxiStatementDocNo int,
@StatementAmount money,
@DocVoided tinyint,@PrevStatementDocNo int
Declare @MemLocationID char(15),@MemCUSTNMBR char(15)
Declare @StatDocNo int,@umStatementAmount numeric(19,5)

DECLARE @umPymtDEPSAmtH_V money
DECLARE @umPymtDEPSAmtV_H money

Select @umAppDEPSAmt_A=0
Select @umAppDEPSAmt_H=0
SELECT @umDocAmt=0
Select @umMISCAmtV=0
Select @umBillAmtV=0

 
Declare @Text char(90)

/* ------------------------------ */
Select @StatDocNo01 = 0
Select @StatDocNo02 = 999999999 
Select @Loc01 ='' 
Select @Loc02 ='zzzzzzzzzzzzzzz' 
Select @Cust01 = ''
Select @Cust02 = 'zzzzzzzzzzzzzzz'
/* --------------------------------- */

Declare @Update bit
--Select  @Update = 1 -- Update Table 
Select  @Update = 0 -- It means No Update ; only Report 


--///////////////////////

DECLARE allTran CURSOR FOR
Select DISTINCT umStatementDocNo,umLocationID,CUSTNMBR,umStatementAmount
        From DOCROUTE
        ORDER BY umLocationID,CUSTNMBR,umStatementDocNo


/* ------------Create Temp table -----------*/ 
CREATE TABLE DOCTEMP(
        umComment char(3),
	umLocationID char(15), 
	CUSTNMBR char(15),
	umDocAmt money NULL,
	umStatementDocNo int PRIMARY KEY,
	umStatementAmount numeric(19,5) NULL,
        umDifference money NULL)

Select @umAppDEPSAmt_A=0
Select @umAppDEPSAmt_H=0
SELECT @umDocAmt=0
Select @umMISCAmtV=0
Select @umBillAmtV=0


OPEN allTran
FETCH NEXT FROM allTran INTO
      @umStatementDocNo,@umLocationID,@CUSTNMBR,@umStatementAmount
select @umPrevStatementAmount = 0
WHILE (@@FETCH_STATUS <> -1)
BEGIN
/* Select @umStatementDocNo */

If (Select Count(*) From UM42300 Where 
    umLocationID = @umLocationID and CUSTNMBR=@CUSTNMBR and
    (UMDOCTYPE=2 or UMDOCTYPE=3 or UMDOCTYPE=4 or
     UMDOCTYPE=5 or UMDOCTYPE=15 or UMDOCTYPE=16) and
    (umDocLoc=1)) > 999
Begin
   Select @Text =  'Loc.ID: '+@umLocationID + ' Cust.No: '+@CUSTNMBR+' Stat_No: '+ CONVERT(CHAR(10),@umStatementDocNo) + ' has documents in WORK'
   Print @Text
End
Else
Begin
 
/*  ---------- Take Stat.Doc.No in Statement MSTR -----------------*/
	  SELECT @umMISCAmtW = 0
          SELECT @umMISCAmtO = 0
          SELECT @umMISCAmtH = 0
          SELECT @umMISCAmtHV = 0
          SELECT @umBillAmtW = 0
          SELECT @umBillAmtO = 0
          SELECT @umBillAmtH = 0
          SELECT @umBillAmtV = 0
	  SELECT @umPymtAmtW = 0
	  SELECT @umPymtAmtO = 0
	  SELECT @umPymtAmtH = 0
	  SELECT @umPymtAmtV = 0
	  SELECT @umPymtDEPSAmtO = 0
	  SELECT @umPymtDEPSAmtH = 0
	  SELECT @umPymtDEPSAmtV = 0
		select @umArchivedStatementAmount = 0
		
		select @minStateNum = min(umStatementDocNo) From DOCROUTE where umLocationID = @umLocationID and CUSTNMBR = @CUSTNMBR
		if @minStateNum = @umStatementDocNo 
		begin 
			if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[UM00701L]') and OBJECTPROPERTY(id, N'IsUserTable') = 1)
			begin
				select @umArchivedStatementAmount = umStatementAmount from UM00701L where umLocationID = @umLocationID and CUSTNMBR = @CUSTNMBR
			end
		end
/* ----------Total from Misc_WRKN Non Void ------------- */
	   SELECT @umMISCAmtW = sum(umTotalMiscCharges)
                  FROM UM10400 
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                               UM00702.umDocVoided=0) 


/* ----------Total from Misc_OPEN Non Void ------------- */
	   SELECT @umMISCAmtO = sum(umTotalMiscCharges)
                  FROM UM20400 
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                               UM00702.umDocVoided=0) 

/* ----------Total from Misc_HIST Non Void  --------------*/
	   SELECT @umMISCAmtH = sum(umTotalMiscCharges)
                  FROM UM30400 
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                               UM00702.umDocVoided=0)  

/* ---------------Total from Misc_HIST Void --------------- */
	   SELECT @umMISCAmtV = sum(umTotalMiscCharges)
                  FROM UM30400 
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                         UM00702.umDocVoided=1)  

/* ---------------Total from Bill_WORK Non Void  -------------*/
	   SELECT @umBillAmtW = sum(umDocAmt)
                  FROM UM10100 
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                         UM00702.umDocVoided=0) 


/* ---------------Total from Bill_OPEN Non Void  -------------*/
	   SELECT @umBillAmtO = sum(umDocAmt)
                  FROM UM20100 
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                         UM00702.umDocVoided=0) 


/* ----------------Total from Bill_HIST Non Void ------------ */
	   SELECT @umBillAmtH = sum(umDocAmt)
                  FROM UM30100 
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                         UM00702.umDocVoided=0) 


/* ----------------Total from Bill_HIST Void  -----------------*/
	   SELECT @umBillAmtV = sum(umDocAmt)
                  FROM UM30100 
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                         UM00702.umDocVoided=1) 

/* ----------------Total from Cash_WRK Non Void  -------------*/
	   SELECT @umPymtAmtW = sum(umPaymentAmount)
                  FROM UM10800 
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                         UM00702.umDocVoided=0) 

/* ----------------Total from Cash_OPEN Non Void  -------------*/
	   SELECT @umPymtAmtO = sum(umPaymentAmount)
                  FROM UM20800 PO
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                         UM00702.umDocVoided=0) 
					and umDocumentNumber not in (select umPaymentNumber from UMLN007 
							where PO.umDocumentNumber = umPaymentNumber and umDocumentNumber = 'LOAN_PREPAYMENT')


/* --------------- Take a total for Deposits in Cash Receipt Apply Active ----*/
		   SELECT @umAppDEPSAmt_A = 0
		   SELECT @umAppDEPSAmt_A = SUM(umApplyToAmount) from UM10801 
			  Where 
                                (umApplyFromPayment IN 
                                (SELECT umDocumentNumber FROM UM00702 
                                        WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                                              UM00702.umDocVoided=0)) AND
                                (Substring(umApplyToBill,1,4) = 'DEPS')  

/* ----------------Total from Cash_OPEN Non Void  --------------*/
	   SELECT @umPymtAmtH = sum(umPaymentAmount)
                  FROM UM30800 PO
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                         UM00702.umDocVoided=0) 
					and umDocumentNumber not in (select umPaymentNumber from UMLN007 
						where PO.umDocumentNumber = umPaymentNumber and umDocumentNumber = 'LOAN_PREPAYMENT')


/* ---------------Total from Cash_Hist Void  ----------------------------------*/
	   SELECT @umPymtAmtV = sum(umPaymentAmount)
                  FROM UM30800 PO
	          WHERE umDocumentNumber IN 
                        (SELECT umDocumentNumber FROM UM00702 
                         WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                         UM00702.umDocVoided=1) 
				and umDocumentNumber not in (select umPaymentNumber from UMLN007 
					where PO.umDocumentNumber = umPaymentNumber and umDocumentNumber = 'LOAN_PREPAYMENT')


/* --------------- Take a total for Deposits in Cash Receipt Apply Voided ----*/
		   SELECT @umAppDEPSAmt_H = 0
		   SELECT @umAppDEPSAmt_H = SUM(umApplyToAmount) from UM10801 
			  Where 
                           (umApplyFromPayment IN 
                           (SELECT umDocumentNumber FROM UM00702 
                                   WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                                   UM00702.umDocVoided=1)) AND
                           (Substring(umApplyToBill,1,4) = 'DEPS') 

/* --------------- Take a total for Deposits in Cash Receipt Apply Voided ----*/
		   SELECT @umPymtDEPSAmtV_H = 0
		   SELECT @umPymtDEPSAmtV_H = SUM(umApplyToAmount) from UM30801 
			  Where 
                           (umApplyFromPayment IN 
                           (SELECT umDocumentNumber FROM UM00702 
                                   WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                                   UM00702.umDocVoided=1)) AND
                           (Substring(umApplyToBill,1,4) = 'DEPS') 

/* --------------- Take a total for Deposits in Cash Receipt Apply_Hist not voided ----*/
		   SELECT @umPymtDEPSAmtH_V = 0
		   SELECT @umPymtDEPSAmtH_V = SUM(umApplyToAmount) from UM30801 
			  Where 
                           (umApplyFromPayment IN 
                           (SELECT umDocumentNumber FROM UM00702 
                                   WHERE UM00702.umStatementDocNo=@umStatementDocNo AND
                                   UM00702.umDocVoided=0)) AND
                           (Substring(umApplyToBill,1,4) = 'DEPS')
/* ---- */
	Select @umPrevStatementAmount =  0
        Select @LastDocNo = 0

/*-----*/
                  Select @STATLocationID=@umLocationID
                  Select @umAccumType = 0
	          Select @AccumMasterID= ''
                  Select @umAccumType = umAccumType,@AccumMasterID=AccumMasterID
                                        From UM00600 Where umLocationID = @umLocationID
                 /* ----------------------------  Included Location = 3  ------------------------ */
                 If @umAccumType = 3  
                    BEGIN
                       SELECT @STATLocationID=@AccumMasterID
                    END
/*-----*/

	Select @LastDocNo = max(umStatementDocNo) from UM00701 where
               umLocationID = @STATLocationID and CUSTNMBR = @CUSTNMBR AND
               umStatementDocNo<@umStatementDocNo
        If @LastDocNo > 0
        Begin 
	     Select @umPrevStatementAmount = umStatementAmount From UM00701 where 
	            umStatementDocNo = @LastDocNo
        End
/* ---- */

/* ----- Amounts from Statement Repalce file --------------------------------*/
           SELECT @umStat_Repl_CHEQ_Amt = 0
	   SELECT @umStat_Repl_CHEQ_Amt = Sum(umAmount)
                  FROM UM00703
	          WHERE  umStatementDocNo=@umStatementDocNo AND
                         (substring(umDocumentNumber,1,4)='CHEQ')

           SELECT @umStat_Repl_DEPS_Amt = 0
	   SELECT @umStat_Repl_DEPS_Amt = Sum(umAmount)
                  FROM UM00703
	          WHERE  umStatementDocNo=@umStatementDocNo AND
                         (substring(umDocumentNumber,1,4)='DEPS')

/* ----- Amounts from Statement Interest file --------------------------------*/
           SELECT @umStat_Repl_INTR_Amt = 0
	   SELECT @umStat_Repl_INTR_Amt = Sum(umStatementAmount)
                  FROM UM00704
	          WHERE  umStatementDocNo=@umStatementDocNo 

         Select @umDocAmt=0
          Select @umDocAmt=
         ISNULL(@umPrevStatementAmount,0)+ ISNULL(@umArchivedStatementAmount,0)+
	 ISNULL(@umBillAmtW,0)  +ISNULL(@umBillAmtO,0)  + ISNULL(@umBillAmtH ,0) - ISNULL(@umBillAmtV,0) +
         ISNULL(@umMISCAmtW,0)  +ISNULL(@umMISCAmtO,0)  + ISNULL(@umMISCAmtH,0)  - ISNULL(@umMISCAmtV,0)  
         -ISNULL(@umPymtAmtW,0) -ISNULL(@umPymtAmtO,0) - ISNULL(@umPymtAmtH,0)  + ISNULL(@umAppDEPSAmt_A,0)
         + ISNULL(@umPymtAmtV,0)- ISNULL(@umAppDEPSAmt_H,0)+ isnull(@umPymtDEPSAmtH_V,0) - isnull(@umPymtDEPSAmtV_H,0)
         + ISNULL(@umStat_Repl_CHEQ_Amt,0)-ISNULL(@umStat_Repl_DEPS_Amt,0) 
         + ISNULL(@umStat_Repl_INTR_Amt,0)
  


	  SELECT @umPymtAmtV = 0
	  SELECT @umPymtDEPSAmtO = 0
          If (Select Count(*) From DOCTEMP Where umStatementDocNo=@umStatementDocNo) = 0
              Begin
                INSERT INTO DOCTEMP
                        (umComment,umLocationID,CUSTNMBR,
			umDocAmt,umStatementDocNo,umStatementAmount,umDifference) 
			SELECT  CASE 
	                        WHEN   (@umStatementAmount-@umDocAmt)<>0 THEN 'Bad'                              
                                ELSE   ''         
                                END,  
                                @umLocationID,@CUSTNMBR,@umDocAmt,@umStatementDocNo,
                                @umStatementAmount,(@umStatementAmount-@umDocAmt)
                        Where   (@umStatementAmount-@umDocAmt) <> 0 -- Only Wrong Statements
              End
              Else
              Begin
                  Update DOCTEMP Set umStatementAmount=@umDocAmt
                            Where umStatementDocNo=@umStatementDocNo
              End 
If @Update = 1 -- Update  
   Begin 
            If (Select Count(*) From UM00701 Where umStatementDocNo=@umStatementDocNo) = 0
               Begin
                  Insert UM00701
                         (umStatementDocNo,umStatementDate,umStatementAmount,umLocationID,CUSTNMBR)  
                  Select @umStatementDocNo,'12/05/1999',@umDocAmt,@umLocationID,@CUSTNMBR   
/*-----*/
                  Select @STATLocationID=@umLocationID
                  Select @umAccumType = 0
	          Select @AccumMasterID= ''
                  Select @umAccumType = umAccumType,@AccumMasterID=AccumMasterID
                                        From UM00600 Where umLocationID = @umLocationID
                 /* ----------------------------  Included Location = 3  ------------------------ */
                 If @umAccumType = 3 Select @STATLocationID=@AccumMasterID
                 If @umAccumType = 3
                    Begin
                      Update UM00701 Set umLocationID=@STATLocationID
                             Where umStatementDocNo=@umStatementDocNo
                    End
/*-----*/
               End
               Else
               Begin
                  Update UM00701 Set umStatementAmount=@umDocAmt
                         Where umStatementDocNo=@umStatementDocNo
               End 
   End
End

           FETCH NEXT FROM allTran INTO 
                 @umStatementDocNo,@umLocationID,@CUSTNMBR,@umStatementAmount
 
END
DEALLOCATE allTran
SET NOCOUNT OFF
/* --------------Create Statement Master and Statement Details --------------------*/
Print '***************************************************************************************'
Print 'All documents from Statement Mstr file that have incorrect Statement Amount            '
Print '***************************************************************************************'
Select 
        /*---umComment As "Comment",---*/
        umStatementDocNo As [Statement Doc.No],
	umLocationID As [LocationID], 
	CUSTNMBR As [CUSTNMBR],
        umStatementAmount   As [Existing Stat_Amt],
	umDocAmt As [Suggest_Stat_Amt],
        umDifference As [Difference]
From DOCTEMP Where umComment ='Bad'
DROP TABLE DOCTEMP


-- drop table DOCTEMPROUTE
 
SET NOCOUNT OFF