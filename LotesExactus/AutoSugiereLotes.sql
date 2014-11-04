



CREATE PROCEDURE FNICA.usp_AutoSugiereLotesExactus @Articulo AS NVARCHAR(20),
													@Bodega AS NVARCHAR(10),
													@BodegaDestino AS NVARCHAR(10),
													@Cantidad AS DECIMAL(20,8)

AS 
/*SET @Articulo='FE00012'
SET @Bodega='AL01'
SET @BodegaDestino='JT01'
SET @Cantidad=3200*/

--Verificar Existencias
IF NOT EXISTS(SELECT sum(CANT_DISPONIBLE)  FROM fnica.EXISTENCIA_LOTE WHERE Articulo=@Articulo AND Bodega=@Bodega
				HAVING SUM(CANT_DISPONIBLE)>=@Cantidad)
BEGIN
	RAISERROR( 'No hay suficientes existencias para suplir el pedido' ,16,1)
	RETURN
END


declare @Lote NVARCHAR(15),
		@i INT,  
		@CantidadLote decimal (28,8), 
		@Completado bit, 
		@CantidadOrden DECIMAL(28,8),
		@CantidadAsignada decimal(28,8)

declare @iRwCnt int 

Create Table #Resultado (
	Bodega nvarchar(20), --COLLATE Latin1_General_CI_AS, 
	Articulo nvarchar(20),-- COLLATE Latin1_General_CI_AS, 
	Lote NVARCHAR(15), 
	Cantidad decimal(28,8) default 0 
)
		
Create Table #ProductoLote ( 
	ID int identity(1,1), 
	Bodega nvarchar(20), 
	Articulo nvarchar(20), 
	Lote NVARCHAR(15), 
	Existencia decimal(28,8) default 0  
)

create clustered index idx_tmp on #ProductoLote(ID) WITH FILLFACTOR = 100

/*Existencias*/
insert #ProductoLote (BODEGA, ARTICULO, Lote, Existencia)
SELECT A.BODEGA,A.ARTICULO,A.LOTE,A.CANT_DISPONIBLE
  FROM fnica.EXISTENCIA_LOTE A
INNER JOIN fnica.LOTE B ON B.ARTICULO = A.ARTICULO AND B.LOTE = A.LOTE 
WHERE A.ARTICULO=@Articulo AND BODEGA=@Bodega AND A.CANT_DISPONIBLE>0 
ORDER BY B.FECHA_VENCIMIENTO ASC 


SET @iRwCnt=@@ROWCOUNT
SET @CantidadOrden=@Cantidad
set @i = 1
set @Completado = 0
set @CantidadLote = 0
set @CantidadAsignada = 0
while @i <= @iRwCnt and @Completado = 0
begin
	select @Lote = Lote, @CantidadLote = Existencia from #ProductoLote where ID = @i
	if @CantidadOrden  <= @CantidadLote
	begin
		set @CantidadAsignada = @CantidadOrden
		insert #Resultado ( Bodega, Articulo, Lote, Cantidad )
		values ( @Bodega, @Articulo, @Lote, @CantidadAsignada )
		set @Completado = 1

	end
	else
	begin
		set @CantidadAsignada = @CantidadLote
	
		insert #Resultado ( Bodega, Articulo, Lote, Cantidad )
		values ( @Bodega, @Articulo, @Lote, @CantidadAsignada )
		set @CantidadOrden = @CantidadOrden - @CantidadLote

	end
		set @i = @i + 1
END

SELECT Bodega, Articulo, Lote, Cantidad FROM #Resultado


drop table #Resultado
drop table #ProductoLote



					