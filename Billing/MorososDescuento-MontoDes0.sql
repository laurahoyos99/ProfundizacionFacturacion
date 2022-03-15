WITH 

MorososConDescuento AS(
SELECT DISTINCT Numero_Tiquete, Monto_Descuento, Fecha_Tiquete AS FechaTiquete
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-02-02_DESCUENTOS_OVAL_ADJ_T` 
WHERE Monto_Descuento=0.0
GROUP BY Numero_Tiquete, Monto_Descuento, Fecha_Tiquete),

TiquetesServicio AS(
SELECT DISTINCT TIQUETE_ID,CONTRATO,m.Monto_Descuento,m.FechaTiquete
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_TIQUETES_SERVICIO_2021-01_A_2021-11_D` t
INNER JOIN MorososConDescuento m ON m.Numero_Tiquete=t.TIQUETE_ID
GROUP BY TIQUETE_ID,CONTRATO,m.Monto_Descuento,m.FechaTiquete),

Churners AS(
SELECT NOMBRE_CONTRATO,FECHA_FINALIZACION as FechaChurn
FROM `gcp-bia-tmps-vtr-dev-01.gcp_temp_cr_dev_01.2022-01-12_CR_ORDENES_SERVICIO_2021-01_A_2021-11_D` h
INNER JOIN TiquetesServicio t ON h.NOMBRE_CONTRATO=t.CONTRATO
WHERE FECHA_FINALIZACION>t.FechaTiquete AND DATE_DIFF(FECHA_FINALIZACION,t.FechaTiquete,DAY)<=60
),

ChurnFlagResult AS(
SELECT DISTINCT t.TIQUETE_ID,t.CONTRATO,t.Monto_Descuento,t.FechaTiquete, c.FechaChurn,
CASE WHEN c.FechaChurn IS NOT NULL THEN "Churner"
WHEN c.FechaChurn IS NULL THEN "NonChurner" end as ChurnFlag
FROM TiquetesServicio t LEFT JOIN Churners c ON c.NOMBRE_CONTRATO=t.CONTRATO
GROUP BY t.TIQUETE_ID,t.CONTRATO,t.Monto_Descuento,t.FechaTiquete, c.FechaChurn)

SELECT EXTRACT (MONTH FROM f.FechaTiquete) as MesTiquete, COUNT(DISTINCT f.TIQUETE_ID)
FROM ChurnFlagResult f 
--WHERE ChurnFlag="Churner"
--WHERE ChurnFlag="NonChurner"
GROUP BY MesTiquete ORDER BY MesTiquete
