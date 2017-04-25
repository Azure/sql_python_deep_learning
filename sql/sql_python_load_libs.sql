IF OBJECT_ID('tempdb..#PythonTest', 'U') IS NOT NULL DROP TABLE #PythonTest
go

CREATE TABLE #PythonTest (
    [DayOfWeek] varchar(10) not null,
    [Amount] float not null
    )
go

insert into #PythonTest values 
('Sunday', 10.0),
('Monday', 11.1),
('Tuesday', 12.2),
('Wednesday', 13.3),
('Thursday', 14.4),
('Friday', 15.5),
('Saturday', 16.6),
('Friday', 17.7),
('Monday', 18.8),
('Sunday', 19.9)
go

DECLARE @ParamINT INT = 1234567
DECLARE @ParamCharN VARCHAR(6) = 'INPUT '

print '------------------------------------------------------------------------'
print 'Output parameters (before):'
print FORMATMESSAGE('ParamINT=%d', @ParamINT)
print FORMATMESSAGE('ParamCharN=%s', @ParamCharN)

print 'Dataset (before):'
select * from #PythonTest

print '------------------------------------------------------------------------'
print 'Dataset (after):'
DECLARE @RowsPerRead INT = 5

execute sp_execute_external_script 
@language = N'python',
@script = N'
import sys,os
import numpy as np
import dicom
import glob
from sklearn import cross_validation
from matplotlib import pyplot as plt
import pandas as pd
import time
import pkg_resources
try:
	import lightgbm
except:
	sys.path.append("C:\MS\installer\lightgbm\python-package")
	from lightgbm.sklearn import LGBMRegressor
import cv2
import cntk


print("*********************************************************************************************")
print(sys.version)
print("!!!Hello World!!!")
print(os.getcwd())
version_pandas = pkg_resources.get_distribution("pandas").version
print("Version pandas: {}".format(version_pandas))
print("Version OpenCV: {}".format(cv2.__version__))
version_cntk = pkg_resources.get_distribution("cntk").version
print("Version CNTK: {}".format(version_cntk))
print("*********************************************************************************************")
if ParamINT == 1234567:
    ParamINT = 1
else:
    ParamINT += 1

ParamCharN="OUTPUT"
OutputDataSet = InputDataSet

global daysMap

daysMap = {
    "Monday" : 1,
    "Tuesday" : 2,
    "Wednesday" : 3,
    "Thursday" : 4,
    "Friday" : 5,
    "Saturday" : 6,
    "Sunday" : 7
    }

OutputDataSet["DayOfWeek"] = pandas.Series([daysMap[i] for i in OutputDataSet["DayOfWeek"]], index = OutputDataSet.index, dtype = "int32")
', 
@input_data_1 = N'select * from #PythonTest', 
@params = N'@r_rowsPerRead INT, @ParamINT INT OUTPUT, @ParamCharN CHAR(6) OUTPUT',
@r_rowsPerRead = @RowsPerRead,
@paramINT = @ParamINT OUTPUT,
@paramCharN = @ParamCharN OUTPUT
with result sets (("DayOfWeek" int null, "Amount" float null))

print 'Output parameters (after):'
print FORMATMESSAGE('ParamINT=%d', @ParamINT)
print FORMATMESSAGE('ParamCharN=%s', @ParamCharN)
go

IF OBJECT_ID('tempdb..#PythonTest', 'U') IS NOT NULL DROP TABLE #PythonTest
go
