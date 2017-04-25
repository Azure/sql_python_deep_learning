
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
from lightgbm.sklearn import LGBMRegressor
import cv2
import cntk
import lung_cancer


print("*********************************************************************************************")
print(sys.version)
print("!!!Hello World!!!")
print(os.getcwd())
version_pandas = pkg_resources.get_distribution("pandas").version
print("Version pandas: {}".format(version_pandas))
print("Version OpenCV: {}".format(cv2.__version__))
version_cntk = pkg_resources.get_distribution("cntk").version
print("Version CNTK: {}".format(version_cntk))
version_lightgbm = pkg_resources.get_distribution("lightgbm").version
print("Version LightGBM: {}".format(version_lightgbm))
print("Version Lung Cancer: {}".format(lung_cancer.VERSION))

print("*********************************************************************************************")



'

