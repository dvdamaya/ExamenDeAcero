/***********************************************************************************************************
1. Insertar un registro en la tabla Tbl_Recuperacion
*************************************************************************************************************/
create procedure Tbl_Recuperacion_Inserta
	@AnioMes			char(6),
	@ClaCliente			int,
	@ImpRecuperacion	money

as

begin

/*Declaracion de variables*/
declare	@banderacliente	int

/*Declaracion de constantes*/
declare	@vacio		char(1),
		@cero		smallint,
		@montocero	money

/*Asignacion de constantes*/
select	@vacio		= '',			/*	Cadena vacia	*/
		@cero		= 0,			/*	Cero			*/
		@montocero	= 0.00			/*	Monto cero		*/

if @AnioMes = @vacio begin

	select	'El dato año/mes es incorrecto'
	return

end

select	@banderacliente	= count(ClaCliente)
	from dbo.Dim_Cliente
	where	ClaCliente	= @ClaCliente

if @banderacliente = @cero begin

	select	'Numero de cliente incorrecto o inexistente'
	return

end

if @ImpRecuperacion <= @montocero begin

	select	'El monto de la recuperación debe ser mayor a cero'
	return

end

insert into Tbl_Recuperacion (AnioMes, ClaCliente, ImpRecuperacion)
     values (@AnioMes,@ClaCliente,@ImpRecuperacion)

	 select	'Registro insertado correctamente'

end

/******EJECUCION  DE STORE ANTERIOR******/
exec Tbl_Recuperacion_Inserta @AnioMes = '202202', @ClaCliente	= 101,	@ImpRecuperacion	= 120500.50


/***********************************************************************************************************
2. Eliminar de la tabla Dim_Cliente los registros de los clientes que pertenezcan al AgrupadorCliente 543.
*************************************************************************************************************/
--Con el inner join nos aseguramos que el cliente realmente exista en el catalogo de clientes, esto por que no tenemos indices en las tablas
delete Dim_Cliente
from Dim_Cliente
inner join Dim_AgrupadorCliente on Dim_Cliente.ClaAgrupadorCliente	= Dim_AgrupadorCliente.ClaAgrupadorCliente
where	Dim_Cliente.ClaAgrupadorCliente	= 543

/***********************************************************************************************************
3. Conocer el valor Total de ImpRecuperacion e ImpObjetivo por cliente correspondiente al año anterior (2020).
*************************************************************************************************************/
create procedure Totales_Recuperacion_Objetivo
	@Anio			char(4)
as

begin

/*Declaracion de variables*/
declare	@banderacliente	int

/*Declaracion de constantes*/
declare	@vacio		char(1)

/*Asignacion de constantes*/
select	@vacio		= ''			/*	Cadena vacia	*/

if @Anio = @vacio begin

	select	'El año es incorrecto'
	return

end

select	totalRecuperacion	= sum(ImpRecuperacion),
		cliente				= ClaCliente
	from Tbl_Recuperacion
	where	substring(AnioMes,1,4)	= @Anio
	group by ClaCliente

select	totalObjetivo	= sum(ImpObjetivo),
		cliente			= ClaCliente
	from Tbl_Objetivo
	where	substring(AnioMes,1,4)	= @Anio
	group by ClaCliente

end

/******EJECUCION  DE STORE ANTERIOR******/
exec Totales_Recuperacion_Objetivo @Anio = '2020'


/***********************************************************************************************************
4. Conocer el valor de %ImpRecuperacion utilizando la fórmula:
ImpRecuperacion/(ImpObjetivo(Mes Anterior)-ImpBonificacion)
*************************************************************************************************************/

/*Declaracion de variables*/
declare	@ConsecutivoMaximo	int,
		@ConsecutivoMinimo	int,
		@Periodo			smalldatetime,
		@Totalrecuperacion	money,
		@Totalbonificacion	money,
		@Totalobjetivo		money,
		@Porcentajerecuperacion	decimal(18,2)

/*Declaracion de constantes*/
declare	@Decimalcero	decimal(18,2),
		@Fechavacia		smalldatetime,
		@Monedacero		money

/*Asignacion de constantes*/
select	@Decimalcero	= 0.00,				/*	Decimal cero		*/
		@Fechavacia		= '1900/01/01',		/*	Fecha Vacia			*/
		@Monedacero		= 0.00				/*	Moneda cero			*/

create table #Recuperacion(
	consecutivo				int identity,
	AnioMes					char(6),
	Periodo					smalldatetime,
	Totalrecuperacion		money,
	Porcentajerecuperacion	decimal(18,2)
)

create table #Objetivo(
	consecutivo			int identity,
	Periodo				smalldatetime,
	Totalobjetivo		money
)

create table #Bonificacion(
	consecutivo			int identity,
	Periodo				smalldatetime,
	Totalbonificacion	money
)

insert into #Recuperacion (AnioMes, Periodo, Totalrecuperacion, Porcentajerecuperacion)
select	AnioMes, (substring(AnioMes,1,4) + '/' + substring(AnioMes,5,2) +'/'+'01'),	sum(ImpRecuperacion),	@Decimalcero
	from Tbl_Recuperacion
	group by AnioMes
	order by AnioMes

insert into #Objetivo (Periodo, Totalobjetivo)
select	(substring(AnioMes,1,4) + '/' + substring(AnioMes,5,2) +'/'+'01'),	sum(ImpObjetivo)
	from Tbl_Objetivo
	group by AnioMes

insert into #Bonificacion (Periodo, Totalbonificacion)
select	(substring(AnioMes,1,4) + '/' + substring(AnioMes,5,2) +'/'+'01'),	sum(ImpBonificaciones)
	from Tbl_Bonificacion
	group by AnioMes

select	@ConsecutivoMaximo	= max(consecutivo),
		@ConsecutivoMinimo	= min(consecutivo)
	from #Recuperacion

while @ConsecutivoMinimo <= @ConsecutivoMaximo begin

	select	@Periodo			= @Fechavacia,
			@Totalrecuperacion	= @Monedacero,
			@Totalobjetivo		= @Monedacero,
			@Totalbonificacion	= @Monedacero

	select	@Periodo			= Periodo,
			@Totalrecuperacion	= Totalrecuperacion
	from #Recuperacion
	where	consecutivo	= @ConsecutivoMinimo

	select	@Periodo			= isnull(@Periodo, @Fechavacia),
			@Totalrecuperacion	= isnull(@Totalrecuperacion, @Monedacero)

	select	@Totalobjetivo	= Totalobjetivo
	from #Objetivo
	where	Periodo	= dateadd(month,-1, @Periodo)

	select	@Totalobjetivo	= isnull(@Totalobjetivo, @Monedacero)

	select	@Totalbonificacion	= Totalbonificacion
	from #Bonificacion
	where	Periodo	= @Periodo

	select	@Totalbonificacion	= isnull(@Totalbonificacion, @Monedacero)

	select	@Porcentajerecuperacion	= @Totalrecuperacion / (@Totalobjetivo - @Totalbonificacion)

	update #Recuperacion
		set Porcentajerecuperacion	= @Porcentajerecuperacion
	from #Recuperacion
	where	consecutivo	= @ConsecutivoMinimo

	select	@ConsecutivoMinimo	= @ConsecutivoMinimo + 1 

end

select	AnioMes, Porcentajerecuperacion
	from #Recuperacion

drop table #Recuperacion, #Objetivo, #Bonificacion

/***********************************************************************************************************
5. Utilizando la herramienta Tableau diseñe un dashboard que represente los datos
de: ImpRecuperacion, ImpObjetivo e ImpBonificaciones de cada cliente y por periodo mensual.
*************************************************************************************************************/
--CODIGO DE SQL UTLIZADO PARA GENERAR LOS DATOS DEL DASHBOARD
create procedure Reporte_Tableau

as

begin

	select	NombreCliente as Cliente,	b.AnioMes as Periodo,	ImpRecuperacion as Recuperacion,	ImpObjetivo as Objetivo,	ImpBonificaciones as Bonificacion
		from Dim_Cliente a
		inner join Tbl_Recuperacion b	on a.ClaCliente	= b.ClaCliente
		inner join Tbl_Objetivo c		on b.ClaCliente	= c.ClaCliente and	b.AnioMes	= c.AnioMes
		inner join Tbl_Bonificacion d	on c.ClaCliente	= d.ClaCliente and	c.AnioMes	= d.AnioMes

end