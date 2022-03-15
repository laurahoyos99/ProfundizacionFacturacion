WITH

RetenidosConOferta AS(
SELECT DISTINCT Contrato, NO_DE_TIQUETE, DATE(FECHA_FINALIZACION) as FechaTiquete
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-02_TIQUETES_GENERALES_DE_DESCONEXIONES_T` 
WHERE
Contrato IS NOT NULL AND FECHA_FINALIZACION IS NOT NULL
AND SOLUCION_FINAL="RETENIDO"
AND AGRUPACION_SUBAREA = "OFERTA"
GROUP BY Contrato, NO_DE_TIQUETE, FechaTiquete),

PorcentajesDescuento AS(
SELECT DISTINCT Numero_Tiquete, Porcentaje_Descuento, r.Contrato, r.FechaTiquete
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-02_DESCUENTOS_OVAL_ADJ_T` p
INNER JOIN RetenidosConOferta r ON r.NO_DE_TIQUETE=p.Numero_Tiquete
WHERE Porcentaje_Descuento=0.0
GROUP BY Numero_Tiquete, Porcentaje_Descuento, r.Contrato, r.FechaTiquete),

Churners AS(
SELECT DISTINCT NOMBRE_CONTRATO, FECHA_FINALIZACION as FechaChurn
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_ORDENES_SERVICIO_2021-01_A_2021-11_D` c
INNER JOIN PorcentajesDescuento p ON c.NOMBRE_CONTRATO=p.Contrato
WHERE TIPO_ORDEN = "DESINSTALACION" AND ESTADO = "FINALIZADA" 
AND FECHA_FINALIZACION IS NOT NULL AND FECHA_APERTURA IS NOT NULL
AND FECHA_FINALIZACION > p.FechaTiquete AND DATE_DIFF ( FECHA_FINALIZACION,p.FechaTiquete, DAY) <= 60
GROUP BY NOMBRE_CONTRATO, FECHA_FINALIZACION
),

ChurnFlagResult AS(
SELECT DISTINCT p.Numero_Tiquete, p.Porcentaje_Descuento, p.Contrato, p.FechaTiquete, c.FechaChurn,
CASE WHEN c.FechaChurn IS NOT NULL THEN "Churner"
WHEN c.FechaChurn IS NULL THEN "NonChurner" end as ChurnFlag
FROM PorcentajesDescuento p LEFT JOIN Churners c ON c.NOMBRE_CONTRATO=p.Contrato
GROUP BY p.Numero_Tiquete, p.Porcentaje_Descuento, p.Contrato, p.FechaTiquete, c.FechaChurn)

SELECT EXTRACT (MONTH FROM t.FechaTiquete) as MesTiquete, 
COUNT(DISTINCT t.Numero_Tiquete) AS Registros, ROUND(AVG(t.Porcentaje_Descuento),2) as PorcentajeProm
FROM ChurnFlagResult t
--WHERE ChurnFlag="Churner"
--WHERE ChurnFlag="NonChurner"
GROUP BY MesTiquete ORDER BY MesTiquete
