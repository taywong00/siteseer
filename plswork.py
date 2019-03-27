# Project SiteSeer
# https://siteseer.firebaseio.com/

from google.cloud import storage
from google.cloud import automl_v1beta1 as automl
import os
import picamera
import datetime
import time as t
import RPi.GPIO as GPIO
from firebase import firebase
import urllib.request, json

# AutoML Vision
project_id = 'siteseer'
compute_region = 'us-central1'
model_id = 'ICN6009315346241016353' # model 3 'ICN626954994675902736'
file_path = '/home/pi/image.jpg'
score_threshold = '0.5'
response_display_name = ""

# Firebase
touch = 11
firebase = firebase.FirebaseApplication('https://siteseer.firebaseio.com', None)
touch_original = firebase.get('restart', 'triggeredPressed')
# firebase.put('restart', 'triggeredPressed', (not touch_original))
firebase.put('restart', 'triggeredPressed', False)

# Directions API
endpoint = 'https://maps.googleapis.com/maps/api/directions/json?'
api_key = 'AIzaSyCQHkbocf6E71_uh-O-6O_bvIj0JKZplBM'
triggerDir_original = firebase.get('maps', 'trigger/1')
firebase.put('maps', 'trigger/1', False)

GPIO.setmode(GPIO.BCM)
GPIO.setup(touch, GPIO.IN)

def get_directions():
    triggerDir_now = firebase.get('maps', 'trigger/1')
    if triggerDir_now == True:
        firebase.put('maps', 'trigger/1', False)
        # origin = "" # lat,long
        # destination = "" # lat,long

        origin = str(firebase.get('maps', 'latitude'))+","+str(firebase.get('maps', 'longitude'))
        destination = firebase.get('maps', 'destination')

        # origin = "Brooklyn"
        # destination = "Queens"
        mode = "walking"
        alternatives = "false" # one
        #Building the URL for the request
        nav_request = 'origin={}&destination={}&mode={}&alternatives={}&key={}'.format(origin.replace(' ','+'),destination.replace(' ','+'),mode,alternatives,api_key)
        request = endpoint + nav_request
        #Sends the request and reads the response.
        response = urllib.request.urlopen(request).read()
        #Loads response as JSON
        directions = json.loads(response.decode('utf-8'))
        try:
            print(origin, destination)
            response = urllib.request.urlopen(request).read()
            directions = json.loads(response.decode('utf-8'))
            steps = directions['routes'][0]['legs'][0]['steps']
            output = ""
            for i in range(len(steps)):
                output += steps[i]['html_instructions']
        except:
            output = "NO POSSIBLE ROUTE"
        firebase.put('maps', 'order/1', output)
        print(output)

def touch_sensor():
    global touch_original
    touch_pressed = GPIO.input(touch)
    if touch_pressed == touch_original:
        touch_original = (not touch_original)
        firebase.put('restart', 'triggeredPressed', (not touch_original))

def repeat_frequently():
    get_directions()
    touch_sensor()

def takephoto():
    touch_sensor()
    camera = picamera.PiCamera()
    camera.capture('image.jpg')
    camera.close()

def analyze():
    repeat_frequently()
    global response_display_name
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"]="/home/pi/siteseer-030a672b14ba.json"
    project = 'siteseer'
    storage_client = storage.Client(project=project)
    bucket = storage_client.get_bucket('siteseer')

    automl_client = automl.AutoMlClient()
    model_full_id = automl_client.model_path(
    project_id, compute_region, model_id) # Get the full path of the model.
    prediction_client = automl.PredictionServiceClient()

    # repeat_frequently()

    with open(file_path, "rb") as image_file:
        content = image_file.read()
        # repeat_frequently()
        payload = {"image": {"image_bytes": content}}

    params = { }

    if score_threshold:
        params = {"score_threshold": score_threshold}

    # repeat_frequently()

    response = prediction_client.predict(model_full_id, payload, params)
    for result in response.payload:
        touch_sensor()
        print("Date: {} Prediction: {} {}".format(str(datetime.datetime.now()), result.display_name, result.classification.score))
        if not result.display_name == response_display_name:
            response_display_name = result.display_name
            firebase.put('sight', 'speech/1', result.display_name)

    # repeat_frequently()

    image = bucket.blob('Sidewalk')
    image.upload_from_filename('image.jpg')

    # repeat_frequently()

def main():
    while True:
        takephoto()
        analyze()
        repeat_frequently()

# t.sleep(5)

main()
