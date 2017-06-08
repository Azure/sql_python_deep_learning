
USE lung_cancer_database

DROP TABLE IF EXISTS dbo.features_sp;
CREATE TABLE dbo.features_sp (
                patient_id VARCHAR(50) NOT NULL,
                array VARBINARY(MAX) NOT NULL
);

DECLARE @Model VARBINARY(MAX) = (SELECT TOP(1) model FROM dbo.model WHERE name = 'ResNet_152.model' ORDER BY date DESC);

EXECUTE dbo.GenerateFeatures @Model = @Model;



