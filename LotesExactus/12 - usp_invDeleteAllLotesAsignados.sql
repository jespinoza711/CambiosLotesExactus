create procedure fnica.usp_invDeleteAllLotesAsignados @Documento NVARCHAR(20)
AS 
delete FROM fnica.tmpLotesAsignados WHERE Documento=@Documento