USE [lung_cancer_database]
GO


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


IF OBJECT_ID('[dbo].[TrainLungCancerModel]', 'P') IS NOT NULL  
    DROP PROCEDURE [dbo].[TrainLungCancerModel];  
GO  

CREATE PROCEDURE [dbo].[TrainLungCancerModel] 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Insert statements for procedure here
	DECLARE @predictScript NVARCHAR(MAX);
	SET @predictScript = N'
import sys
import pyodbc
from lung_cancer.lung_cancer_utils import get_patients_id, generate_set, train_lightgbm, insert_model
from lung_cancer.connection_settings import get_connection_string, TABLE_SCAN_IMAGES, TABLE_LABELS, TABLE_FEATURES, TABLE_MODEL, LIGHTGBM_MODEL_NAME

# Connect to SQL Server
connection_string = get_connection_string()
conn = pyodbc.connect(connection_string)
cur = conn.cursor()

print("Starting routine")

patients_train = get_patients_id(TABLE_LABELS, cur)

trn_x, val_x, trn_y, val_y = generate_set(TABLE_FEATURES, TABLE_LABELS, patients_train, cur)

classifier = train_lightgbm(trn_x, val_x, trn_y, val_y)

insert_model(TABLE_MODEL, cur, conn, classifier, LIGHTGBM_MODEL_NAME)

conn.close()
print("Routine finished")



	'

	EXECUTE sp_execute_external_script
	@language = N'python',
	@script = @predictScript;

END
GO
