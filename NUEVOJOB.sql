--SET DATEFIRST 7
--SET ANSI_NULLS ON
--SET ANSI_WARNINGS ON
--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--SET LOCK_TIMEOUT -1
--SET QUOTED_IDENTIFIER OFF
--SET NOCOUNT ON
--SET IMPLICIT_TRANSACTIONS OFF
--GO
------===========================================================================================================================================================================================
------ NOMBRE        : SpVTASMonXRecomJob
------ AUTOR        : Jonathan Navarro Gutierrez
------ FECHA CREACION : 05/03/2021
------ DESCRIPCION    : Generacion de monedero x recomendado al cliente recomendador, por las compras generadas por su recomendado
------ DESARROLLO    : DM0407 Monedero X Recomendado
------ EJEMPLO        : EXEC SpVTASMonXRecomJob 
------===========================================================================================================================================================================================
------ AUTOR: Mario Rajhib Morales Verduzco	FECHA DE MODIFICACION: 31/08/2021
------ MODIFICACION: Agregar variables para monto, porcentaje de Credilana o Prestamo personal y modificar variables para monto, porcentaje de factura y factura viu,
------               anexar calculo de importes al monedero con movimiento credilana Y prestamo personal
------               Se modifica para aceptar la palabras 'Todos' en las campañas vigentes 
------			   Se modifica para generar las disminuciones del cliente recomendado
------               Se modifica para aceptar los que no tengan serieMonederoRecomendado
------				se modifica para las devoluciones parciales 
------===========================================================================================================================================================================================


--ALTER PROCEDURE [dbo].[SpVTASMonXRecomJob]
--AS
--BEGIN
	
	DECLARE
	@FechaMin DATE,
	@FechaMax DATE,
	@IdMin INT,
	@IdMax INT,

	@Suc varchar(100),
	@UEN varchar(20),
	@CanalV varchar(100),
	@TipoVenta varchar(20),
	@IdCamp int,
	@OrigenVenta varchar(100),

	@Articulo varchar(20),
	@Familia varchar(50),
	@Linea varchar(50),
	@MovId varchar(20),
	@CodigoRecomendado varchar(20),

	@SerieM int,
	@Cliente varchar(20), 
	@SerieMR int,
	@ClienteRec varchar(20),

	@Categoria varchar(20),

	@ImpFactura money,
	@ImpMin money,
    @ImpMax money,

	@MonRecomendadorMcia float,
	@PorcRecomendadorMcia float,
	@MonRecomdadoMcia float,
	@PorcRecomdadoMcia float,
	@MonRecomendadorCred float,
	@PorcRecomendadorCred float,
	@MonRecomdadoCred float,
	@PorcRecomdadoCred float,

	@ImpMonedero float,
	@ImpMonederoR float,
	@impMonederoCred float,
	@ImpMonederoRCred float

	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#Clientes')
	AND TYPE = 'U')
	DROP TABLE #Clientes

	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#CampVigentes')
	AND TYPE = 'U')
	DROP TABLE #CampVigentes

	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#Sucursal')
	AND TYPE = 'U')
	DROP TABLE #Sucursal

	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#UEN')
	AND TYPE = 'U')
	DROP TABLE #UEN

	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#CanalV')
	AND TYPE = 'U')
	DROP TABLE #CanalV

	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#TipoVenta')
	AND TYPE = 'U')
	DROP TABLE #TipoVenta

	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#OrigenVenta')
	AND TYPE = 'U')
	DROP TABLE #OrigenVenta

	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#ConfigCamp')
	AND TYPE = 'U')
	DROP TABLE #ConfigCamp
	
	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#Facturas')
	AND TYPE = 'U')
	DROP TABLE #Facturas
	
	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#FacturasParciales')
	AND TYPE = 'U')
	DROP TABLE #FacturasParciales
	
	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#DetalleFacturas')
	AND TYPE = 'U')
	DROP TABLE #DetalleFacturas

	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#FacturasCamp')
	AND TYPE = 'U')
	DROP TABLE #FacturasCamp

	IF EXISTS (SELECT
	ID
	FROM tempdb.sys.sysobjects
	WHERE id = OBJECT_ID('tempdb.dbo.#FacturasConsideradas')
	AND TYPE = 'U')
	DROP TABLE #FacturasConsideradas

	CREATE TABLE #CampVigentes (
		Id int IDENTITY,
		IdCamp int,
		Nombre varchar(100),
		TipoCte varchar(5),
		UEN varchar(max),
		CanalVenta varchar(max),
		Sucursales varchar(max),
		OrigenVenta varchar(100),
		FechaInicio datetime,
		FechaFin datetime
	)

	CREATE TABLE #OrigenVenta (
		IdCamp int NOT NULL,
		Id int NULL,
		Origen varchar(20),
		Referencia varchar(50)
	)

	CREATE TABLE #Sucursal (
		IdCamp int,
		Sucursal int
	)

	CREATE TABLE #UEN (
		IdCamp int,
		UEN int
	)

	CREATE TABLE #CanalV (
		IdCamp int,
		Canal int
	)

	CREATE TABLE #TipoVenta (
    IdCamp int,
    Tipo varchar(20)
	)

	CREATE TABLE #ConfigCamp (
		Id int IDENTITY,
		IdCamp int,
		TipoCte varchar(20),
		UEN int,
		CanalV int,
		Sucursal int
	)

	CREATE TABLE #Facturas (
		Id int IDENTITY NOT NULL,
		Cliente varchar(20),
		Mov varchar(20),
		MovId varchar(20),
		IdFactura int,
		MaviTipoVenta varchar(10),
		UEN int,
		EnviarA int,
		Sucursal int,
		Referencia varchar(100),
		CodigoRecomendado varchar(20)
	)

	CREATE TABLE #FacturasCamp (
    Id int IDENTITY NOT NULL,
    ClienteRecomendado varchar(20) NULL,
    Mov varchar(20) NULL,
    MovId varchar(20) NULL,
    IdFactura int NULL,
    MaviTipoVenta varchar(10) NULL,
    UEN int NULL,
    CanalV int NULL,
    Sucursal int NULL,
    Referencia varchar(100) NULL,
    Articulo varchar(25) NULL,
    Precio money NULL,
    Cantidad int NULL,
    CodigoRecomendado varchar(20) NULL,
    ClienteRecomendador varchar(20) NULL,
    IdCamp int NULL,
    Bandera int NULL,
    ImpFactura money NULL,
    SerieMonedero int NULL,
    SerieMonederoRecomendado int NULL,
    Rango varchar(30) NULL,
    ImpMonedero money NULL,
    DevEncontrada int NULL,
	MonederoRecomendado FLOAT(53) NULL,
	MonederoRecomendadoR FLOAT(53) NULL
	)

	CREATE TABLE #FacturasConsideradas (
    Id int IDENTITY NOT NULL,
    ClienteMonedero varchar(20) NULL,
    ImporteFactura money NULL,
    SerieMonedero varchar(10) NULL,
    SerieMonederoR varchar(10) NULL,
    Mov varchar(30) NULL,
    MovId varchar(10) NULL,
    EnviarA int NULL,
    ImporteMonedero money NULL,
    ImporteMonederoR money NULL,
    Rango varchar(50) NULL,
    IdCamp int NULL,
    DevEncontrada int NULL,
    UEN int NULL,
	)

	--Consulta los clientes cuyos movimientos conluidos de factura o factura VIU, credilana
	--INSERT INTO #Clientes (Cliente, PrimerCompra, CodigoRecomendado, MonederoRecomAplicado, CanalV)
    SELECT
		ca.cliente AS Cliente,
		min(v.FechaEmision) AS PrimerCompra, 
		CR.Codigo AS CodigoRecomendado, 
		Ca.ID AS CanalV
	INTO #Clientes
	FROM CREDIDCodigoRecomendador CR WITH(NOLOCK)
	JOIN CteEnviarA Ca WITH(NOLOCK)
	ON CR.Codigo = CA.CodigoRecomendado
	JOIN Venta V WITH(NOLOCK)
	ON Ca.Cliente = V.Cliente
	LEFT JOIN VTASHMonederoXRecomendado MR WITH(NOLOCK)
	ON V.Cliente = MR.ClienteRecomendado
	WHERE MR.ClienteRecomendado IS NULL
	AND V.mov in ('factura','factura VIU', 'credilana','prestamo personal')
	AND V.ESTATUS = 'CONCLUIDO'
	GROUP BY 
		ca.cliente,
		CR.Codigo, 
		Ca.MonederoRecomAplicado,
		Ca.ID,
		V.Mov
 
	--Campañas vigentes
	INSERT INTO #CampVigentes (IdCamp, Nombre, TipoCte, UEN, CanalVenta, Sucursales, OrigenVenta, FechaInicio, FechaFin)
    SELECT
      IdMonederoXRecomendadoCamp,
      Nombre,
      TipoCliente,
      UEN,
      CanalesVenta,
      Sucursales,
      OrigenVenta,
      FechaInicio,
      FechaFin
	FROM VTASDMonederoXRecomendadoCamp WITH (NOLOCK)
    WHERE FechaInicio <= GETDATE()
    AND FechaFin >= GETDATE()

	--fechas de la campaña vigente	
	SELECT
	@FechaMin = MIN(FechaInicio)
	FROM #CampVigentes
	SELECT
	@FechaMax = MAX(FechaFin)
	FROM #CampVigentes

	--Borra las compras que sobresalgan de la campaña
	DELETE FROM #Clientes
	WHERE PrimerCompra < @FechaMin
	OR PrimerCompra > @FechaMax

	--rangos de los campañas para acceder a ellos
	SELECT
		@IdMin = MIN(Id)
	FROM #CampVigentes
	SELECT
		@IdMax = MAX(Id)
	FROM #CampVigentes

	--Este While inserta en tablas temporales los datos correspodientes a las campañas que estan dentro del rango de las compras
	WHILE (@IdMin <= @IdMax)
	BEGIN
		SELECT
			@Suc = Sucursales,
			@UEN = UEN,
			@CanalV = CanalVenta,
			@TipoVenta = TipoCte,
			@IdCamp = IdCamp,
			@OrigenVenta = OrigenVenta
		FROM #CampVigentes
		WHERE Id = @IdMin

		IF (@Suc IS NULL
			OR @Suc = '')
		BEGIN
			INSERT INTO #Sucursal (IdCamp, Sucursal)
			SELECT
				C.IdCamp,
				S.Sucursal
			FROM Sucursal S WITH (NOLOCK)
			JOIN #CampVigentes C
				ON C.Id = @IdMin
			WHERE S.Estatus = 'ALTA'
		END

		IF (@Suc IS NOT NULL)
		BEGIN
			INSERT INTO #Sucursal (IdCamp, Sucursal)
			SELECT
				V.IdCamp,
				item
			FROM fnSplit(@Suc, ',') F
			JOIN #CampVigentes V
				ON V.Id = @IdMin
		END

		IF (@UEN IS NULL OR @UEN = '')
		BEGIN
			INSERT INTO #UEN (IdCamp, UEN)
			SELECT
				C.IdCamp,
				U.UEN
			FROM UEN U WITH (NOLOCK)
			JOIN #CampVigentes C
				ON C.Id = @IdMin
			WHERE U.Estatus = 'ALTA'
		END

		IF @UEN = 'TODAS'
			SET @UEN = '1,2,3'

		IF (@UEN IS NOT NULL)
		BEGIN
			INSERT INTO #UEN (IdCamp, UEN)
			SELECT
				V.IdCamp,
				item
			FROM fnSplit(@UEN, ',') F
			JOIN #CampVigentes V
				ON V.Id = @IdMin
		END

		IF (@CanalV IS NULL
			OR @CanalV = '')
		BEGIN
			INSERT INTO #CanalV (IdCamp, Canal)
			SELECT
				C.IdCamp,
				V.ID AS Canal
			FROM VentasCanalMavi V WITH (NOLOCK)
			JOIN #CampVigentes C
				ON C.Id = @IdMin
		END

		IF (@CanalV IS NOT NULL)
		BEGIN
			INSERT INTO #CanalV (IdCamp, Canal)
			SELECT
				V.IdCamp,
				item
			FROM fnSplit(@CanalV, ',') F
			JOIN #CampVigentes V
				ON V.Id = @IdMin
		END

		IF (@TipoVenta IS NULL OR @TipoVenta = '')
		BEGIN
			INSERT INTO #TipoVenta (Tipo, IdCamp)
			SELECT DISTINCT
				V.MaviTipoVenta AS IdCamp,
				C.IdCamp AS Tipo
			FROM Venta V WITH (NOLOCK)
			JOIN #CampVigentes C
				ON C.Id = @IdMin
			WHERE Mov = 'Factura'
			AND Estatus = 'concluido'
			AND MaviTipoVenta IS NOT NULL
		END

		IF (@TipoVenta IS NOT NULL)
		BEGIN
			INSERT INTO #TipoVenta (IdCamp, Tipo)
			SELECT
				IdCamp,
				TipoCte
			FROM #CampVigentes
			WHERE Id = @IdMin
		END

		IF (@OrigenVenta IS NULL
			OR @OrigenVenta = '')
		BEGIN
			INSERT INTO #OrigenVenta (IdCamp, Referencia)
			SELECT
				C.IdCamp,
				T.Nombre AS Referencia
			FROM TablaStD T WITH (NOLOCK)
			JOIN #CampVigentes C
				ON C.Id = @IdMin
			WHERE TablaSt = 'ORIGENVENTA'
		END
	
		IF (@OrigenVenta IS NOT NULL AND @OrigenVenta = 'TODOS')
		BEGIN
			SET @OrigenVenta = '1,2,3'
		END
    
		IF (@OrigenVenta IS NOT NULL)
		BEGIN
			INSERT INTO #OrigenVenta (IdCamp, ID)
			SELECT
				@IdCamp,
				item
			FROM fnSplit(@OrigenVenta, ',') F
			JOIN #CampVigentes V
				ON V.Id = @IdMin

			UPDATE #OrigenVenta
			SET Origen =
						CASE
						WHEN Id = 1 THEN 'APP'
						WHEN id = 2 THEN 'VENTAS PISO'
						WHEN Id = 3 THEN 'WEB'
						END
			WHERE IdCamp = @IdCamp
		END
		SET @IdMin = @IdMin + 1
	END
 
	INSERT INTO #ConfigCamp (IdCamp, TipoCte, UEN, CanalV, Sucursal)
	SELECT
		T.IdCamp,
		T.Tipo,
		U.UEN,
		C.Canal,
		S.Sucursal
	FROM #TipoVenta T
	JOIN #UEN U
		ON U.IdCamp = T.IdCamp
	JOIN #CanalV C
		ON C.IdCamp = T.IdCamp
	JOIN #Sucursal S
		ON S.IdCamp = T.IdCamp

	INSERT INTO #Facturas (Cliente, Mov, MovId, IdFactura, MaviTipoVenta, UEN, EnviarA, Sucursal, Referencia, CodigoRecomendado)
	SELECT DISTINCT
		V.Cliente,
		V.Mov,
		v.MovID,
		V.ID,
		V.MaviTipoVenta,
		V.UEN,
		V.EnviarA,
		V.Sucursal,
		V.Referencia,
		C.CodigoRecomendado
	FROM Venta V WITH (NOLOCK)
	JOIN #Clientes C
		ON V.FechaEmision = C.PrimerCompra
		AND V.Cliente = C.Cliente
		AND V.EnviarA = C.CanalV
	JOIN VentaD VD WITH (NOLOCK)
		ON V.ID = VD.ID
	WHERE V.Mov IN ('Factura', 'Factura Viu', 'Credilana', 'Prestamo Personal')
	AND V.Estatus = 'CONCLUIDO'
	ORDER BY V.Cliente ASC
	
	SELECT 
		VD.ID,
		VD.Articulo,
		VD.Cantidad,
		VD.Precio
	INTO #DetalleFacturas
	FROM #Facturas F
	--DETALLE FACTURA
	JOIN VentaD VD WITH(NOLOCK)
	ON F.IdFactura = VD.ID

	DELETE FROM #Facturas
	WHERE UEN NOT IN (SELECT UEN FROM #UEN)
	OR EnviarA NOT IN (SELECT Canal FROM #CanalV)
    OR Sucursal	NOT IN (SELECT Sucursal FROM #Sucursal)
    OR Referencia NOT IN (SELECT Referencia FROM #OrigenVenta)

	
	INSERT INTO #FacturasCamp (ClienteRecomendado, Mov, MovId, IdFactura, MaviTipoVenta, UEN, CanalV, Sucursal, Referencia, Articulo, Precio, Cantidad, CodigoRecomendado, IdCamp, DevEncontrada)
	SELECT
		F.Cliente,
		F.Mov,
		F.MovId,
		F.IdFactura,
		F.MaviTipoVenta,
		F.UEN,
		F.EnviarA,
		F.Sucursal,
		F.Referencia,
		DF.Articulo,
		DF.Precio,
		DF.Cantidad,
		F.CodigoRecomendado,
		CA.IdCamp,
		0
	FROM #Facturas F
	JOIN #DetalleFacturas DF
	ON F.IdFactura = DF.ID
	JOIN #ConfigCamp CA
	ON F.MaviTipoVenta = CA.TipoCte
	AND F.UEN = CA.UEN
	AND F.EnviarA = CA.CanalV
	AND F.Sucursal = CA.Sucursal

	--------------------------------------------AQUI SE LLENA LA TABLA
	------------------ WHILE -------------------#FacturasCamp
	--------------------------------------------
	SELECT
		@IdMin = MIN(Id)
	FROM #FacturasCamp
	SELECT
		@IdMax = MAX(Id)
	FROM #FacturasCamp

	WHILE (@IdMin <= @IdMax)
	BEGIN--INICIO WHILE

		SELECT
			@Articulo = F.Articulo,
			@Familia = A.Familia,
			@Linea = A.Linea,
			@MovId = F.MovId,
			@IdCamp = IdCamp,
			@CodigoRecomendado = F.CodigoRecomendado,
			@CanalV = CanalV
		FROM #FacturasCamp F
		JOIN Art A WITH (NOLOCK)
		ON F.Articulo = A.Articulo
		WHERE F.Id = @IdMin

		UPDATE F
		SET F.ClienteRecomendador = C.Cliente
		FROM #FacturasCamp F
		JOIN CREDIDCodigoRecomendador C WITH (NOLOCK)
		ON F.CodigoRecomendado = C.Codigo 
		
		IF (SELECT COUNT(*)	FROM VTASDMonederoXRecomendadoFamLin WITH (NOLOCK)	WHERE Familia = @Familia AND NumeroCampania = @IdCamp) > 0
		BEGIN
		---------------------------------
			IF (SELECT COUNT(*)	FROM VTASDMonederoXRecomendadoFamLin WITH (NOLOCK) WHERE Linea = @Linea	AND NumeroCampania = @IdCamp) > 0
			BEGIN
		---------------------------------
				IF (SELECT COUNT(*)	FROM VTASDMonederoXRecomendadoFamLin WITH (NOLOCK) WHERE Articulo = @Articulo AND NumeroCampania = @IdCamp)	> 0
				BEGIN
					UPDATE #FacturasCamp
					SET Bandera = 1
					WHERE Id = @IdMin
				END
			---------------------------------
				IF (SELECT COUNT(*)	FROM VTASDMonederoXRecomendadoFamLin WITH (NOLOCK)	WHERE Articulo IS NULL AND NumeroCampania = @IdCamp) > 0
				BEGIN
					IF (SELECT COUNT(*)	FROM VTASDMonederoXRecomendadoFamExc WITH (NOLOCK) WHERE Articulo = @Articulo) > 0
					BEGIN
						UPDATE #FacturasCamp
						SET Bandera = 0
						WHERE Id = @IdMin
					END
					UPDATE #FacturasCamp
					SET Bandera = 1
					WHERE Id = @IdMin
				END
			---------------------------------
			END
			---------------------------------
			ELSE IF (SELECT COUNT(*) FROM VTASDMonederoXRecomendadoFamLin WITH (NOLOCK) WHERE Familia = @Familia AND Linea IS NULL AND NumeroCampania = @IdCamp) > 0
			BEGIN
				UPDATE #FacturasCamp
				SET Bandera = 1
				WHERE Id = @IdMin
			END
			---------------------------------
		END
		---------------------------------
		ELSE
			UPDATE #FacturasCamp SET Bandera = 0 WHERE Id = @IdMin

		IF (SELECT COUNT(*) FROM #FacturasCamp WHERE Bandera = 1 AND Id = @IdMin) > 0
		BEGIN
			UPDATE #FacturasCamp SET ImpFactura = Precio * Cantidad WHERE Id = @IdMin
		
			--INICIO IF BUSCAR CAMPO EN TABLA Cte
			IF (SELECT COUNT(*)	FROM INFORMATION_SCHEMA.COLUMNS WITH (NOLOCK) WHERE COLUMN_NAME = 'SerieMonedero' AND TABLE_NAME = 'Cte') > 0
			BEGIN
				---------------------------------
				UPDATE #FacturasCamp
				SET SerieMonedero = 
				(
					SELECT 
					CASE
						WHEN CanalV = 3 THEN C.SerieMonedero 
						WHEN CanalV = 7 THEN SerieMonederoVIU
					END
					FROM Cte c WITH (NOLOCK)
					WHERE Cliente = ClienteRecomendador
				)
				WHERE Id = @IdMin
				AND Bandera = 1
				---------------------------------
				UPDATE #FacturasCamp
				SET SerieMonederoRecomendado = 
				(
					SELECT
						CASE
							WHEN CanalV = 3 THEN C.SerieMonedero
							WHEN CanalV = 7 THEN SerieMonederoVIU
						END
					FROM Cte C WITH (NOLOCK)
					WHERE Cliente = ClienteRecomendado
				)
				WHERE Id = @IdMin
				AND Bandera = 1
				---------------------------------
				SELECT
					@SerieM = SerieMonedero,
					@Cliente = ClienteRecomendador,
					@SerieMR = SerieMonederoRecomendado,
					@ClienteRec = ClienteRecomendado,
					@CanalV = CanalV
				FROM #FacturasCamp
				WHERE Id = @IdMin
				---------------------------------
				--INICIO ASIGNACION 
				--SERIE MONEDERO RECOMENDADO
				IF(@SerieM IS NULL)
				BEGIN
					--------------------------------
					IF (@CanalV = 3)
					BEGIN
						SELECT TOP 1
						@SerieM = Serie
						FROM TarjetaMonederoMAVI WITH (NOLOCK)
						WHERE Estatus = 'Activa'
						AND TipoMonedero = 'Virtual'
						AND ISNULL(Apartado, 0) = 0
						AND ISNULL(CategoriaCV,'CREDITO MENUDEO') = 'CREDITO MENUDEO' 
						AND UEN = 1

						UPDATE TarjetaMonederoMAVI WITH (ROWLOCK)
						SET Apartado = 1,
						Cliente = @Cliente,
						CategoriaCV = @Categoria
						WHERE Serie = @SerieM

						UPDATE Cte WITH (ROWLOCK)
						SET SerieMonedero = @SerieM
						WHERE Cliente = @Cliente

						UPDATE #FacturasCamp
						SET SerieMonedero = @SerieM
						WHERE ClienteRecomendador = @Cliente
						AND Id = @IdMin
					END
					--------------------------------
					IF (@CanalV = 7)
					BEGIN
						SELECT TOP 1
						@SerieM = Serie
						FROM TarjetaMonederoMAVI WITH (NOLOCK)
						WHERE Estatus = 'Activa'
						AND TipoMonedero = 'Virtual'
						AND ISNULL(Apartado, 0) = 0
						AND ISnull(CategoriaCV,'CREDITO MENUDEO') = 'CREDITO MENUDEO' 
						AND UEN = 2

						UPDATE TarjetaMonederoMAVI WITH (ROWLOCK)
						SET Apartado = 1,
						Cliente = @Cliente,
						CategoriaCV = @Categoria
						WHERE Serie = @SerieM

						UPDATE Cte WITH (ROWLOCK)
						SET SerieMonederoVIU = @SerieM
						WHERE Cliente = @Cliente

						UPDATE #FacturasCamp
						SET SerieMonedero = @SerieM
						WHERE ClienteRecomendador = @Cliente
						AND Id = @IdMin
					END
				END
				--SERIE MONEDERO RECOMENDADOR
				IF(@SerieMR IS NULL)
				BEGIN
					IF (@CanalV = 3)
					BEGIN
						--------------------------------
						SELECT TOP 1
						@SerieMR = Serie
						FROM TarjetaMonederoMAVI WITH (NOLOCK)
						WHERE Estatus = 'Activa'
						AND TipoMonedero = 'Virtual'
						AND ISNULL(Apartado, 0) = 0
						AND ISnull(CategoriaCV,'CREDITO MENUDEO') = 'CREDITO MENUDEO' 
						AND UEN = 1

						UPDATE TarjetaMonederoMAVI WITH (ROWLOCK)
						SET Apartado = 1,
						Cliente = @ClienteRec,
						CategoriaCV = @Categoria
						WHERE Serie = @SerieMR

						UPDATE Cte WITH (ROWLOCK)
						SET SerieMonedero = @SerieMR
						WHERE Cliente = @ClienteRec

						UPDATE #FacturasCamp
						SET SerieMonederoRecomendado = @SerieMR
						WHERE ClienteRecomendado = @ClienteRec
						AND Id = @IdMin

					END
	
					IF (@CanalV = 7)
					BEGIN
						--------------------------------
						SELECT TOP 1
						@SerieMR = Serie
						FROM TarjetaMonederoMAVI WITH (NOLOCK)
						WHERE Estatus = 'Activa'
						AND TipoMonedero = 'Virtual'
						AND ISNULL(Apartado, 0) = 0
						AND ISnull(CategoriaCV,'CREDITO MENUDEO') = 'CREDITO MENUDEO' 
						AND UEN = 2

						UPDATE TarjetaMonederoMAVI WITH (ROWLOCK)
						SET Apartado = 1,
						Cliente = @ClienteRec,
						CategoriaCV = @Categoria
						WHERE Serie = @SerieMR

						UPDATE Cte WITH (ROWLOCK)
						SET SerieMonederoVIU = @SerieMR
						WHERE Cliente = @ClienteRec

						UPDATE #FacturasCamp
						SET SerieMonederoRecomendado = @SerieMR
						WHERE ClienteRecomendado = @ClienteRec
						AND Id = @IdMin
					END
				END
			END
		END

		DELETE FROM #FacturasCamp
		WHERE Articulo IN 
		(
			SELECT
				EC.Articulo
			FROM VTASDMonederoXRecomendadoFamLin FL WITH (NOLOCK)
			JOIN VTASDMonederoXRecomendadoFamExc EC WITH (NOLOCK)
			ON EC.NumeroFamiliaLinea = FL.NumeroFamiliaLinea
			WHERE NumeroCampania = @IdCamp
		)

		SET @IdMin = @IdMin + 1

	END

	-------------------------------------------------
	----------------- END WHILE ---------------------
	-------------------------------------------------

	INSERT INTO #FacturasConsideradas (ClienteMonedero, ImporteFactura, SerieMonedero, SerieMonederoR, Mov, MovId, EnviarA, IdCamp, DevEncontrada, UEN)
	SELECT
		ClienteRecomendador,
		SUM(ImpFactura),
		SerieMonedero,
		SerieMonederoRecomendado,
		Mov,
		MovId,
		CanalV,
		IdCamp,
		DevEncontrada,
		UEN
	FROM #FacturasCamp
	WHERE BANDERA = 1
	GROUP BY ClienteRecomendador,
				SerieMonedero,
				SerieMonederoRecomendado,
				Mov,
				MovId,
				CanalV,
				IdCamp,
				DevEncontrada,
				UEN

	SELECT
		@IdMin = MIN(Id),
		@IdMax = MAX(Id)
	FROM #FacturasConsideradas

	-------------------------------------------
	------------------ WHILE ------------------
	-------------------------------------------
	WHILE (@IdMin <= @IdMax)
	BEGIN
		SELECT
			@ImpFactura = ImporteFactura
		FROM #FacturasConsideradas
		WHERE Id = @IdMin

		SELECT TOP 1
			@ImpMin = ImporteMinimo,
			@ImpMax = ImporteMaximo,
			@MonRecomendadorMcia = MontoRecomendadorMcia,
			@PorcRecomendadorMcia = PorcRecomendadorMcia,
			@MonRecomdadoMcia = MontoRecomendadoMcia,
			@PorcRecomdadoMcia = PorcRecomendadoMcia,
			@MonRecomendadorCred = MontoRecomendadorCred,
			@PorcRecomendadorCred = PorcRecomendadorCred,
			@MonRecomdadoCred = MontoRecomendadoCred,
			@PorcRecomdadoCred = PorcRecomendadoCred
		FROM VTASDMonederoXRecomendadoRango WITH (NOLOCK)
		WHERE @ImpFactura < ImporteMaximo
		AND @ImpFactura > ImporteMinimo
		
		-- Importe de Mercancia	
		IF (@MonRecomendadorMcia IS NOT NULL)
		BEGIN
			SET @ImpMonedero = @MonRecomendadorMcia
		END
		IF (@PorcRecomendadorMcia IS NOT NULL)
		BEGIN
			SET @ImpMonedero = (@ImpFactura * @PorcRecomendadorMcia) / 100
		END
		IF (@MonRecomdadoMcia IS NOT NULL)
		BEGIN
			SET @ImpMonederoR = @MonRecomdadoMcia
		END
		IF (@PorcRecomdadoMcia IS NOT NULL)
		BEGIN
			SET @ImpMonederoR = (@ImpFactura * @PorcRecomdadoMcia) / 100
		END
	
		-- Importe de credilana
		IF (@MonRecomendadorCred IS NOT NULL)
		BEGIN
		  SET @impMonederoCred = @MonRecomendadorCred
		END
		IF (@PorcRecomendadorCred IS NOT NULL)
		BEGIN
		  SET @impMonederoCred = (@ImpFactura * @PorcRecomendadorCred) / 100
		END
		IF (@MonRecomdadoCred IS NOT NULL)
		BEGIN
		  SET @ImpMonederoRCred = @MonRecomdadoCred
		END
		IF (@PorcRecomdadoCred IS NOT NULL)
		BEGIN
		  SET @ImpMonederoRCred = (@ImpFactura * @PorcRecomdadoCred) / 100
		END

		UPDATE #FacturasConsideradas
		SET ImporteMonedero =  
			CASE 				   
				WHEN mov IN ('credilana','prestamo personal')
				THEN @impMonederoCred
				ELSE @ImpMonedero
			END,
			ImporteMonederoR =
			CASE 				   
				WHEN mov IN ('credilana','prestamo personal')
				THEN @ImpMonederoRCred
				ELSE @ImpMonederoR
			END,
			Rango = CONCAT('$', @ImpMin, '-', '$', @ImpMax),
			CASE 
				WHEN @ImpMonedero
		WHERE Id = @IdMin
		SET @IdMin = @IdMin + 1
	END
	-------------------------------------------
	---------------- END WHILE ----------------
	-------------------------------------------
	
	--AGREGAR EL MONEDERO GENERADO X PRODUCTO A #FacturasCamp
	UPDATE FA 
	--TODO SE REDONDEA PARA CALCULOS CORRECTOS POR ARTICULO
	SET	FA.MonederoRecomendado = ROUND((CONVERT(FLOAT(53),FC.ImporteMonedero)/CONVERT(FLOAT(53),FC.ImporteFactura))*CONVERT(FLOAT(53),FA.ImpFactura),5),
		FA.MonederoRecomendadoR = ROUND((CONVERT(FLOAT(53),FC.ImporteMonederoR)/CONVERT(FLOAT(53),FC.ImporteFactura))*CONVERT(FLOAT(53),FA.ImpFactura),5)
	--TABLA CON DETALLES DE LA FACTURA POR ARTICULO
	FROM #FacturasCamp FA
	--TABLA CON LAS FACTURAS YA CON SUS MONEDEROS GENERADOS
	JOIN #FacturasConsideradas FC
	ON FA.Mov + ' ' + FA.MovId = FC.Mov + ' ' + FC.MovId 

	SELECT * FROM #FacturasCamp
	
	
	
	
	SELECT
	V.*
	FROM VTASHMonederoXRecomendado MR WITH(NOLOCK)
	JOIN Venta V WITH(NOLOCK)
	ON MR.Referencia = V.Referencia AND V.Mov IN ('Devolucion Venta', 'Devolucion VIU', 'Cancela Credilana', 'Cancela Prestamo')
	LEFT JOIN VTASHMonederoXRecomendado MRD WITH(NOLOCK)
	ON 	V.Mov + ' ' + V.MovID = MRD.Referencia 
	WHERE MRD.Referencia IS NULL
