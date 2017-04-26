import os

# Path and variables
LIB_CNTK = 'cntk'
DATA_PATH = os.path.join('..','data')
#STAGE1_LABELS = os.path.join(DATA_PATH, 'stage1_labels.csv') #uncomment this file if you want to use the full dataset
STAGE1_LABELS = os.path.join(DATA_PATH, 'stage1_labels_partial.csv')
STAGE1_FOLDER = 'E:\kaggle\stage1'