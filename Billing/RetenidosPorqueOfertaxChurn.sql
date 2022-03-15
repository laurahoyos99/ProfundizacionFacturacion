/*Gente que se quería ir por razones de oferta*/
WITH

RetenidosConDescuentos AS(
SELECT DISTINCT Contrato, DATE(FECHA_FINALIZACION) as FechaTiquete
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-02_TIQUETES_GENERALES_DE_DESCONEXIONES_T` 
WHERE
Contrato IS NOT NULL AND FECHA_FINALIZACION IS NOT NULL
AND SOLUCION_FINAL="RETENIDO"
AND AGRUPACION_SUBAREA = "OFERTA"
GROUP BY Contrato, FechaTiquete),

Churners AS(
SELECT DISTINCT NOMBRE_CONTRATO, FECHA_FINALIZACION as FechaChurn
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_ORDENES_SERVICIO_2021-01_A_2021-11_D` c
INNER JOIN RetenidosConDescuentos r ON c.NOMBRE_CONTRATO=r.Contrato
WHERE TIPO_ORDEN = "DESINSTALACION" AND ESTADO = "FINALIZADA" 
AND FECHA_FINALIZACION IS NOT NULL AND FECHA_APERTURA IS NOT NULL
AND FECHA_FINALIZACION > r.FechaTiquete AND DATE_DIFF ( FECHA_FINALIZACION,r.FechaTiquete, DAY) <= 60
--AND DATE_DIFF ( FECHA_FINALIZACION,r.FechaTiquete, DAY) > 90
GROUP BY NOMBRE_CONTRATO, FECHA_FINALIZACION
),

ChurnFlagResult AS(
SELECT DISTINCT r.Contrato, c.NOMBRE_CONTRATO,r.FechaTiquete, c.FechaChurn,
CASE WHEN c.FechaChurn IS NOT NULL THEN "Churner"
WHEN c.FechaChurn IS NULL THEN "NonChurner" end as ChurnFlag
FROM RetenidosConDescuentos r LEFT JOIN Churners c ON c.NOMBRE_CONTRATO=r.Contrato
GROUP BY r.Contrato, c.NOMBRE_CONTRATO,r.FechaTiquete, c.FechaChurn)

SELECT EXTRACT(MONTH FROM t.FechaTiquete) AS MesTiquete, COUNT(DISTINCT t.Contrato) AS Registros
FROM ChurnFlagResult t 
--WHERE ChurnFlag="Churner"
--WHERE ChurnFlag="NonChurner"
GROUP BY MesTiquete ORDER BY MesTiquete

