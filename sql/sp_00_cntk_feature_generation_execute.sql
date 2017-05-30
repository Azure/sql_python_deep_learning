--Test
--DECLARE @Features VARBINARY(MAX);
--DECLARE @Model VARBINARY(MAX) = (SELECT model FROM dbo.model WHERE name = 'ResNet_152.model');
--EXECUTE lung_cancer_database.dbo.GenerateFeatures @PatientIndex = 0, @Model = @Model, @Features = @Features;

USE lung_cancer_database

DROP TABLE IF EXISTS dbo.features_sp;
CREATE TABLE dbo.features_sp (
                patient_id VARCHAR(50) NOT NULL,
                array VARBINARY(MAX) NOT NULL
);

DECLARE @Model VARBINARY(MAX) = (SELECT TOP(1) model FROM dbo.model WHERE name = 'ResNet_152.model' ORDER BY date DESC);

DECLARE @i INT;
DECLARE @numrows INT;
DECLARE @Features VARBINARY(MAX);
SET @i = 0
SET @numrows = (SELECT COUNT(*) FROM dbo.patients)
--WHILE (@i < @numrows)
WHILE (@i < 1)
BEGIN
	EXECUTE lung_cancer_database.dbo.GenerateFeatures @PatientIndex = @i, @Model = @Model, @Features = @Features;
    SET @i = @i + 1
END


