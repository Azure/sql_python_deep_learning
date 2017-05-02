from api import app, BAD_PARAM, STATUS_OK, BAD_REQUEST
from flask import request, jsonify, abort, make_response,render_template, json 
import sys
from lung_cancer.connection_settings import get_connection_string, TABLE_SCAN_IMAGES, TABLE_GIF, TABLE_MODEL, TABLE_FEATURES, LIGHTGBM_MODEL_NAME, DATABASE_NAME,NUMBER_PATIENTS
from lung_cancer.lung_cancer_utils import get_patients_id, get_patient_id_from_index, select_entry_where_column_equals_value, get_features, get_lightgbm_model, prediction
import pyodbc
import cherrypy
from paste.translogger import TransLogger



def run_server():
    # Enable WSGI access logging via Paste
    app_logged = TransLogger(app)

    # Mount the WSGI callable object (app) on the root directory
    cherrypy.tree.graft(app_logged, '/')

    # Set the configuration of the web server
    cherrypy.config.update({
        'engine.autoreload_on': True,
        'log.screen': True,
        'log.error_file': "cherrypy.log",
        'server.socket_port': 5000,
        'server.socket_host': '0.0.0.0',
        'server.thread_pool': 50, # 10 is default
    })

    # Start the CherryPy WSGI web server
    cherrypy.engine.start()
    cherrypy.engine.block()

# Connection
connection_string = get_connection_string()
conn = pyodbc.connect(connection_string)
cur = conn.cursor()


# Model
model = get_lightgbm_model(TABLE_MODEL, cur, LIGHTGBM_MODEL_NAME)


# Functions
@app.route("/")
def index():
    cherrypy.log("CHERRYPY LOG: /")
    return render_template('index.html')


@app.route('/gif/<patient_index>')
def patient_gif(patient_index):
    patient_index = int(patient_index)
    if patient_index > NUMBER_PATIENTS:
        abort(BAD_REQUEST)
    cherrypy.log("CHERRYPY LOG: /gif/<patient_index>")
    gif_url = manage_gif(patient_index)
    return make_response(jsonify({'status': STATUS_OK, 'gif_url': gif_url}), STATUS_OK)
     
    
@app.route('/predict/<patient_index>')
def predict_patient(patient_index):
    patient_index = int(patient_index)
    if patient_index > NUMBER_PATIENTS:
        abort(BAD_REQUEST)
    cherrypy.log("CHERRYPY LOG: /predict/<patient_index>")
    prob = manage_prediction(patient_index)
    return make_response(jsonify({'status': STATUS_OK, 'prob': prob}), STATUS_OK)


@app.route('/patient_info', methods=['POST'])
def patient_info():
    cherrypy.log("CHERRYPY LOG: /patient_info")
    patient_index = manage_request_patient_index(request.form['patient_index'])
    gif_url = manage_gif(patient_index)
    return render_template('patient.html', patient_index=patient_index, gif_url=gif_url)


@app.route('/patient_prob', methods=['POST'])
def patient_prob():
    cherrypy.log("CHERRYPY LOG: /patient_prob")
    patient_index = manage_request_patient_index(request.form['patient_index'])
    prob = manage_prediction_store_procedure(patient_index)
    gif_url = manage_gif(patient_index)
    return render_template('patient.html', patient_index=patient_index, prob=round(prob,2), gif_url=gif_url)


def is_integer(s):
    try:
        int(s)
        return True
    except ValueError:
        return False


def manage_request_patient_index(patient_request):   
    patient1 = "Anthony Embleton".lower()
    patient2 = "Ana Fernandez".lower()
    if patient_request.lower() in patient1:
        patient_index = 1
    elif patient_request.lower() in patient2:
        patient_index = 175#1574
    else: 
        if is_integer(patient_request):
            patient_index = int(patient_request)
            if patient_index > NUMBER_PATIENTS:
                patient_index = 199#1500   
        else:
            patient_index = 7
    return patient_index


def manage_gif(patient_index):
    patient_id = get_patient_id_from_index(TABLE_SCAN_IMAGES, cur, patient_index)
    print(patient_id)
    resp = select_entry_where_column_equals_value(TABLE_GIF, cur, 'patient_id', patient_id)
    gif_url = resp[1]
    print("gif_url: ",gif_url)
    return gif_url


def manage_prediction(patient_index):
    patient_id = get_patient_id_from_index(TABLE_SCAN_IMAGES, cur, patient_index)
    feats = get_features(TABLE_FEATURES, cur, patient_id)
    probability_cancer = prediction(model, feats)
    prob = float(probability_cancer)*100
    return prob


def manage_prediction_store_procedure(patient_index):
    query = "DECLARE @PredictionResultSP FLOAT;"
    query += "EXECUTE " + DATABASE_NAME + ".dbo.PredictLungCancer @PatientIndex = ?, @PredictionResult = @PredictionResultSP;"
    cur.execute(query, patient_index)
    prob = cur.fetchone()[0]
    return prob


if __name__ == "__main__":
    run_server()
    conn.close()