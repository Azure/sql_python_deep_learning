import sys,os
import numpy as np
import dicom
import glob
from sklearn import cross_validation
from sklearn.decomposition import PCA
import pkg_resources
from lightgbm.sklearn import LGBMRegressor
import cv2
from cntk import load_model
from cntk.ops import combine
import pickle
import datetime


######################################################################

def print_library_version():
	print(os.getcwd())
	version_pandas = pkg_resources.get_distribution("pandas").version
	print("Version pandas: {}".format(version_pandas))
	print("Version OpenCV: {}".format(cv2.__version__))
	version_cntk = pkg_resources.get_distribution("cntk").version
	print("Version CNTK: {}".format(version_cntk))


######################################################################
# for feature generation
def get_patients_id(table_name, cursor):
    query = "SELECT patient_id FROM " + table_name 
    cursor.execute(query)
    data = cursor.fetchall()
    data = [d[0] for d in data]
    return data


def get_patient_images(table_name, cursor, patient_id):
    query = "SELECT array FROM " + table_name + " WHERE patient_id = ?"
    cursor.execute(query, patient_id)
    data = cursor.fetchone()
    array = pickle.loads(data[0])
    return array  


def manipulate_images(sample_image):
    batch = []
    cnt = 0
    dx = 40
    ds = 512
    for i in range(0, sample_image.shape[0] - 3, 3):
        tmp = []
        for j in range(3):
            img = sample_image[i + j]
            img = 255.0 / np.amax(img) * img
            img = cv2.equalizeHist(img.astype(np.uint8))
            img = img[dx: ds - dx, dx: ds - dx]
            img = cv2.resize(img, (224, 224))
            tmp.append(img)

        batch.append(tmp)
    batch = np.array(batch, dtype='int')
    return batch


def select_model_layer(model, layer_name):
    node_in_graph = model.find_by_name(layer_name)
    output_nodes  = combine([node_in_graph.owner])
    return output_nodes


def load_cntk_model_from_binary(model_bin, verbose=False):
    model_file = "tmp.model"
    with open(model_file, "wb") as file:
        file.write(model_bin)
    loaded_model = load_model(model_file)
    if verbose:
        print(len(loaded_model.constants))
        node_outputs = get_node_outputs(loaded_model)
        for out in node_outputs: print("{0} {1}".format(out.name, out.shape))
    return loaded_model


def get_cntk_model(model_name):
    node_name = "z.x"
    loaded_model  = load_model(model_name)
    node_in_graph = loaded_model.find_by_name(node_name)
    output_nodes  = combine([node_in_graph.owner])
    return output_nodes


def get_cntk_model_sql(table_name, cursor, model_name):
    query = "SELECT  model FROM " + table_name + " WHERE name = ?"
    cursor.execute(query, model_name)
    result = cursor.fetchone()
    model_bin  = result[0]
    model_file = "tmp.model"
    with open(model_file, "wb") as file:
        file.write(model_bin)
    output_nodes  = get_cntk_model(model_file)
    return output_nodes


def compute_features_with_gpu(model, data, batch_size=50):
    #num_items = data.shape[0]
    #chunks = np.ceil(num_items / batch_size)
    #data_chunks = np.array_split(data, chunks, axis=0)
    #feat_list = []
    #for d in data_chunks:
    #    feat = model.eval(d)#GPU
    #    feat_list.append(feat)
    #feats = np.concatenate(feat_list, axis=0)
    feats = model.eval(data)[0]
    feats = feats.squeeze()
    return feats


def create_table_features(table_name, cursor):
    query = "IF OBJECT_ID(\'" + table_name + "\') IS NOT NULL DROP TABLE " + table_name + " "
    query += "CREATE TABLE " + table_name
    query += " ( patient_id varchar(50) not null, array_rows int not null, array_cols int not null, array varbinary(max) not null )" 
    cursor.execute(query)
    cursor.commit()


def insert_features(table_name, cursor, connector, patient_id, patient_feat):
    feat_serialized = pickle.dumps(patient_feat, protocol=0)# protocol 0 is printable ASCII
    query = "INSERT INTO " + table_name + "( patient_id, array_rows, array_cols, array ) VALUES (?,?,?,?)"
    cursor.execute(query, patient_id, patient_feat.shape[0], patient_feat.shape[1], feat_serialized)
    connector.commit()
    

######################################################################
# for lightgbm training 

#Get the feature size of the network penultimante layer 
def get_feature_shape(table_name, cursor):
    feat_shape = select_top_value_of_column(table_name, cursor, "array_cols")
    feat_shape = int(feat_shape)
    return feat_shape


def get_features(table_name, cursor, patient_id):
    query = "SELECT array FROM " + table_name + " WHERE patient_id = ?"
    cursor.execute(query, patient_id)
    results = cursor.fetchone()
    result_array = pickle.loads(results[0])
    return result_array
   

def get_labels(table_name, cursor):
    query = "SELECT label FROM " + table_name
    cursor.execute(query)
    data = cursor.fetchall()
    data = [d[0] for d in data]
    data = np.array(data, np.int8)
    return data


def generate_set(table_features, table_labels, patients, cursor):
    y = get_labels(table_labels, cursor)
    feat_shape = get_feature_shape(table_features, cursor)
    x = np.zeros((y.shape[0], feat_shape))
    for i,p in enumerate(patients):
        feat = get_features(table_features, cursor, p)
        feat_pca = PCA(n_components=1).fit_transform(feat.transpose())
        x[i,:] = feat_pca.squeeze()    
    trn_x, val_x, trn_y, val_y = cross_validation.train_test_split(x, y, random_state=42, stratify=y, test_size=0.20)
    return trn_x, val_x, trn_y, val_y


def train_lightgbm(trn_x, val_x, trn_y, val_y):
    clf = LGBMRegressor(max_depth=50,
                        num_leaves=21,
                        n_estimators=5000,
                        min_child_weight=9,
                        learning_rate=0.01,
                        nthread=24,
                        subsample=0.80,
                        colsample_bytree=0.80,
                        seed=42)
    clf.fit(trn_x, trn_y, eval_set=[(val_x, val_y)], verbose=True, eval_metric='l2', early_stopping_rounds=300)
    return clf


def insert_model(table_name, cursor, connector, classifier, name, library='lightgbm'):
    query = "INSERT INTO " + table_name + "( name, date, library, model ) VALUES (?,?,?,?)"
    model_serialized = pickle.dumps(classifier, protocol=0)
    cursor.execute(query, name, datetime.datetime.now(), library, model_serialized)
    connector.commit()


#########################################################################
#for scoring
def get_patient_id_from_index(table_name, cursor, patient_index):
	patients = get_patients_id(table_name, cursor)#FIXME: this could be faster with a new table with (idx, id)
	return patients[patient_index]


def get_lightgbm_model(table_name, cursor, model_name):
    query = "SELECT TOP(1) model FROM " + table_name + " WHERE name = ? ORDER BY date DESC"
    cursor.execute(query, model_name)
    result = cursor.fetchone()
    data = pickle.loads(result[0])
    return data


def prediction(model, x):
    x_pca = PCA(n_components=1).fit_transform(x.transpose())
    pred = model.predict(x_pca.transpose())
    return pred[0]

#########################################################################
# for API
#code from https://github.com/miguelgfierro/codebase/blob/master/python/database/sql_server/select_values.py
def select_entry_where_column_equals_value(table_name, cursor, column_name, value):
    query = "SELECT * FROM " + table_name + " WHERE " + column_name + " = ?"
    cursor.execute(query, value)
    data = cursor.fetchone()
    return data

def select_top_value_of_column(table_name, cursor, column_name):
    query = "SELECT TOP(1) " + column_name + " FROM " + table_name 
    cursor.execute(query)
    data = cursor.fetchone()
    return data[0]    

