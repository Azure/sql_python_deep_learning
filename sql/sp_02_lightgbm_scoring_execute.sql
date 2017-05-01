DECLARE @PredictionResultSP FLOAT;
EXECUTE lung_cancer_database.dbo.PredictLungCancer @PatientIndex = 0, @PredictionResult = @PredictionResultSP;


