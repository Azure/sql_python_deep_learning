import sys,os
import numpy as np
import pandas as pd
import pyodbc
import pickle
from lung_cancer.connection_settings import get_connection_string, TABLE_GIF, TABLE_LABELS, TABLE_MODEL
import wget
import datetime
from config_preprocessing import STAGE1_LABELS, LIB_CNTK


def create_table_gifs(table_name, cursor, connector, drop_table=False):
    query = ""
    if drop_table:
        query += "IF OBJECT_ID(\'" + table_name + "\') IS NOT NULL DROP TABLE " + table_name + " "
    query += "CREATE TABLE " + table_name
    query += " ( patient_id varchar(50) not null, gif_url varchar(200) not null )" 
    cursor.execute(query)
    connector.commit()


def create_table_labels(table_name, cursor, connector, drop_table=False):    
    query = ""
    if drop_table:
        query += "IF OBJECT_ID(\'" + table_name + "\') IS NOT NULL DROP TABLE " + table_name + " "
    query += "CREATE TABLE " + table_name
    query += " ( patient_id varchar(50) not null, label integer not null )" 
    cursor.execute(query)
    connector.commit()


def create_table_model(table_name, cursor, connector, drop_table=False):    
    query = ""
    if drop_table:
        query += "IF OBJECT_ID(\'" + table_name + "\') IS NOT NULL DROP TABLE " + table_name + " "
    query += "CREATE TABLE " + table_name
    query += " ( name varchar(50) not null, date datetime not null, library varchar(50) not null, model varbinary(max) not null )"     
    cursor.execute(query)    
    connector.commit()


def get_patients_id(df):
    patient_ids = df['id'].tolist()
    return patient_ids


def generate_gif_url(patient_ids):
    gif_urls = [BASE_URL + p + '.gif' for p in patient_ids]
    return gif_urls


def insert_gifs(table_name, cursor, connector, patient_ids, gif_urls):
    query = "INSERT INTO " + table_name + "( patient_id, gif_url ) VALUES (?,?)"
    for p,g in zip(patient_id, gif_url):
        cursor.execute(q, p, g)
    connector.commit()


def insert_labels(table_name, cursor, connector, df):
    query = "INSERT INTO " + table_name + "( patient_id, label ) VALUES (?,?)"
    for idx, row in df.iterrows():
        cur.execute(q, row["id"], row["cancer"])
    conn.commit()


def maybe_download_model(filename='ResNet_18.model'):
    if(os.path.isfile(filename)):
        print("Model %s already downloaded" % filename)
    else:
        model_name_to_url = {
        'AlexNet.model':   'https://www.cntk.ai/Models/AlexNet/AlexNet.model',
        'AlexNetBS.model': 'https://www.cntk.ai/Models/AlexNet/AlexNetBS.model',
        'VGG_16.model': 'https://www.cntk.ai/Models/Caffe_Converted/VGG16_ImageNet.model',
        'VGG_19.model': 'https://www.cntk.ai/Models/Caffe_Converted/VGG19_ImageNet.model',
        'InceptionBN.model': 'https://www.cntk.ai/Models/Caffe_Converted/BNInception_ImageNet.model',
        'ResNet_18.model': 'https://www.cntk.ai/Models/ResNet/ResNet_18.model',
        'ResNet_50.model': 'https://www.cntk.ai/Models/Caffe_Converted/ResNet50_ImageNet.model',
        'ResNet_101.model': 'https://www.cntk.ai/Models/Caffe_Converted/ResNet101_ImageNet.model',
        'ResNet_152.model': 'https://migonzastorage.blob.core.windows.net/deep-learning/models/cntk/imagenet/ResNet_152.model'
        }
        url = model_name_to_url[filename] 
        wget.download(url)


def read_binary(filename):
    with open(filename, "rb") as binary_file:
    # Read the whole file at once
        data = binary_file.read()
    return data


def generate_insert_query_model(table_name):
    query = "INSERT INTO " + table_name + "( name, date, library, model ) VALUES (?,?,?,?)"
    return query


def insert_model(table_name, cursor, connector, models):
    q_insert = generate_insert_query_model(table_name)
    for i, m in enumerate(models):
        cursor.execute(q_insert, m, datetime.datetime.now(), LIB_CNTK, models_bin[i])
        connector.commit()


if __name__ == "__main__":

    #Create SQL database connection and table
    connection_string = get_connection_string()
    conn = pyodbc.connect(connection_string)
    cur = conn.cursor()
    print("Creating tables {}, {}, {}".format(TABLE_GIF, TABLE_LABELS, TABLE_MODEL))
    create_table_gifs(TABLE_GIF, cur, conn, True)
    create_table_labels(TABLE_LABELS, cur, conn, True)    
    create_table_model(TABLE_MODEL, cur, conn, True)

    #Insert gifs
    df = pd.read_csv(STAGE1_LABELS)
    patient_ids = get_patients_id(df)
    gif_urls = generate_gif_url(patient_ids)
    insert_gifs(TABLE_GIF, cur, conn, patient_ids, gif_urls)

    # Insert labels
    insert_labels(TABLE_LABELS, cur, conn, df)

    # Insert CNTK models
    models = ('ResNet_18.model', 'ResNet_152.model')
    for m in models:
        maybe_download_model(m)
    models_bin = [read_binary(m) for m in models]
    insert_model(TABLE_MODEL, cur, conn, models_bin)



