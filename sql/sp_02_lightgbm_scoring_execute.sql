DECLARE @PredictionResultSP FLOAT;
EXECUTE lung_cancer.dbo.PredictLungCancer @PatientIndex = 0, @PredictionResult = @PredictionResultSP;


